// Paruay assistant (v1) — a chat agent for the shopkeeper's finances.
// It ANSWERS questions about money (balance / category summaries / search) and can ADD income/expense.
//
// Security model (same boundary as parse-expense):
//   • ANTHROPIC_API_KEY stays SERVER-SIDE. The client (ships the public anon key) never sees it.
//   • Reads run on data the CLIENT sent (the client already holds RLS-filtered rows) — the edge fn
//     NEVER touches the database. Writes are NOT executed here either: add_transaction returns the
//     proposed row, and the CLIENT persists it under the user's own JWT/RLS. So this function cannot
//     read or write any data the caller couldn't already read or write.
//   • Gated to logged-in users (role "authenticated") so the public anon key can't burn the AI budget.
//
// The tool-use loop runs entirely inside this function (Claude ↔ in-process tools), so the client
// makes ONE round trip per message. Every tool the model calls is returned in `actions` so the UI
// can show "what the AI did" (เห็นการเคลื่อนไหว). add_transaction rows come back in `adds`.
//
// Deploy (self-hosted Supabase on the VPS):
//   place this file at /docker/supabase/docker/volumes/functions/assistant/index.ts
//   then: cd /docker/supabase/docker && docker compose up -d --wait functions
//
// Request body:
//   { messages:[{role:'user'|'assistant', text}], lang,
//     ctx:{ today, primaryCurrency, currencies:[sym], balance, foreign:[{sym,bal}],
//           allTimeIncome, allTimeExpense, windowFrom, transactions:[{d,t,a,c,e,n,cur}],
//           categories:{income:[{label,emoji}],expense:[...]} } }
//   transactions are slimmed: d=date(YYYY-MM-DD) t='i'|'e' a=amount c=categoryLabel e=emoji n=note cur=currency(omit if primary)
// Response:
//   { ok, reply, actions:[{tool,input,result}], adds:[{type,amount,categoryLabel,categoryEmoji,note,currency}] }

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

const json = (obj: unknown, status = 200) =>
  new Response(JSON.stringify(obj), { status, headers: { ...CORS, 'content-type': 'application/json' } });

const MODEL = 'claude-sonnet-5';
const MAX_ROUNDS = 6;     // hard cap on tool-use round-trips → bounds cost per message
const WINDOW_CAP = 600;   // max transactions the model reasons over (client also caps before sending)

// ── period helpers (derive from the client's LOCAL "today" so buckets match the app) ──
const ymd = (s: any) => (typeof s === 'string' ? s : '');
const addDays = (iso: string, n: number) => {
  const d = new Date(iso + 'T00:00:00Z');
  d.setUTCDate(d.getUTCDate() + n);
  return d.toISOString().slice(0, 10);
};
// returns a predicate (date-string) => boolean for the named period, relative to `today`
const periodPred = (period: string, today: string) => {
  const month = today.slice(0, 7);
  const year = today.slice(0, 4);
  if (period === 'today') return (d: string) => d === today;
  if (period === '7d') { const from = addDays(today, -6); return (d: string) => d >= from && d <= today; }
  if (period === '30d') { const from = addDays(today, -29); return (d: string) => d >= from && d <= today; }
  if (period === 'this_month') return (d: string) => d.startsWith(month);
  if (period === 'last_month') {
    let y = +year, m = +month.slice(5) - 1; if (m < 1) { m = 12; y -= 1; }
    const lm = String(y) + '-' + String(m).padStart(2, '0');
    return (d: string) => d.startsWith(lm);
  }
  if (period === 'this_year') return (d: string) => d.startsWith(year);
  return (_d: string) => true; // 'all' (bounded by the window the client sent)
};

const tools = [
  {
    name: 'get_balance',
    description: 'Get the current total balance and all-time income/expense in the primary currency, plus any foreign-currency balances. Use this for "how much do I have", "what is my balance", net worth. These figures are authoritative (they match what the app shows).',
    input_schema: { type: 'object', properties: {}, additionalProperties: false },
  },
  {
    name: 'summarize',
    description: 'Total income or expense grouped by category over a time period, in the primary currency. Use for "how much did I spend on X", "biggest expenses this month", category breakdowns.',
    input_schema: {
      type: 'object',
      properties: {
        type: { type: 'string', enum: ['income', 'expense'] },
        period: { type: 'string', enum: ['today', '7d', '30d', 'this_month', 'last_month', 'this_year', 'all'] },
      },
      required: ['type', 'period'],
      additionalProperties: false,
    },
  },
  {
    name: 'search',
    description: 'List transactions matching filters (keyword in category/note, type, category, period), newest first. Use for "show my food purchases", "what did I buy yesterday", finding specific entries.',
    input_schema: {
      type: 'object',
      properties: {
        keyword: { type: 'string' },
        type: { type: 'string', enum: ['income', 'expense'] },
        category: { type: 'string' },
        period: { type: 'string', enum: ['today', '7d', '30d', 'this_month', 'last_month', 'this_year', 'all'] },
        limit: { type: 'number' },
      },
      required: [],
      additionalProperties: false,
    },
  },
  {
    name: 'add_transaction',
    description: 'Record a new income or expense for the user. Only call this when the user clearly asks to add/record a transaction. The entry is saved on the user\'s device after this turn; confirm what you added.',
    input_schema: {
      type: 'object',
      properties: {
        type: { type: 'string', enum: ['income', 'expense'] },
        amount: { type: 'number', description: 'positive amount, digits only' },
        categoryLabel: { type: 'string' },
        categoryEmoji: { type: 'string' },
        note: { type: 'string' },
        currency: { type: 'string' },
      },
      required: ['type', 'amount', 'categoryLabel'],
      additionalProperties: false,
    },
  },
];

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS });
  if (req.method !== 'POST') return json({ ok: false, error: 'method' }, 405);

  const key = Deno.env.get('ANTHROPIC_API_KEY');
  if (!key) return json({ ok: false, error: 'no_api_key' }, 500);

  // Gate to logged-in users (the public anon key is a valid JWT but not "authenticated").
  try {
    const jwt = (req.headers.get('authorization') || '').replace(/^Bearer\s+/i, '');
    const payload = JSON.parse(atob((jwt.split('.')[1] || '').replace(/-/g, '+').replace(/_/g, '/')));
    if (payload.role !== 'authenticated') return json({ ok: false, error: 'auth_required' }, 401);
  } catch (_) {
    return json({ ok: false, error: 'auth_required' }, 401);
  }

  let body: any = {};
  try { body = await req.json(); } catch (_) { return json({ ok: false, error: 'bad_body' }, 400); }

  const lang = String(body.lang || 'lo');
  const ctx = body.ctx || {};
  const today = ymd(ctx.today) || new Date().toISOString().slice(0, 10);
  const primary = String(ctx.primaryCurrency || '₭');
  const balance = Number(ctx.balance) || 0;
  const allIn = Number(ctx.allTimeIncome) || 0;
  const allOut = Number(ctx.allTimeExpense) || 0;
  const foreign: any[] = Array.isArray(ctx.foreign) ? ctx.foreign : [];
  const windowFrom = ymd(ctx.windowFrom);
  // slimmed rows the model reasons over (primary + foreign, each keeps its own currency)
  const rows: any[] = (Array.isArray(ctx.transactions) ? ctx.transactions : []).slice(0, WINDOW_CAP).map((x: any) => ({
    d: ymd(x && x.d),
    t: x && x.t === 'i' ? 'income' : 'expense',
    a: Math.abs(Number(x && x.a) || 0),
    c: String((x && x.c) || '').trim(),
    e: String((x && x.e) || '').trim(),
    n: String((x && x.n) || '').trim(),
    cur: (x && x.cur) ? String(x.cur).trim() : primary,
  })).filter((x: any) => x.d && x.a > 0);

  const inMsgs: any[] = Array.isArray(body.messages) ? body.messages : [];
  if (!inMsgs.length) return json({ ok: false, error: 'empty' }, 200);

  const cats = ctx.categories || {};
  const catList = (arr: any) => (Array.isArray(arr) ? arr : []).map((c: any) => `${(c && c.emoji) || ''} ${(c && c.label) || ''}`.trim()).filter(Boolean).join(', ');
  const curList = [primary, ...(Array.isArray(ctx.currencies) ? ctx.currencies : [])].map((s: any) => String(s)).filter(Boolean).join(', ');

  // ── in-process tool executors (read from `rows`/ctx only; never a DB) ──
  const primRows = () => rows.filter((x) => x.cur === primary);
  const runSummarize = (input: any) => {
    const type = input && input.type === 'income' ? 'income' : 'expense';
    const period = String((input && input.period) || 'this_month');
    const pred = periodPred(period, today);
    const byCat: Record<string, { label: string; emoji: string; total: number; count: number }> = {};
    let total = 0, count = 0;
    for (const x of primRows()) {
      if (x.t !== type || !pred(x.d)) continue;
      total += x.a; count++;
      const k = x.c + '|' + x.e;
      const g = byCat[k] || (byCat[k] = { label: x.c || '(none)', emoji: x.e, total: 0, count: 0 });
      g.total += x.a; g.count++;
    }
    const categories = Object.values(byCat).sort((a, b) => b.total - a.total);
    return { type, period, currency: primary, total, count, categories };
  };
  const runSearch = (input: any) => {
    const kw = String((input && input.keyword) || '').trim().toLowerCase();
    const type = input && (input.type === 'income' || input.type === 'expense') ? input.type : null;
    const cat = String((input && input.category) || '').trim().toLowerCase();
    const period = String((input && input.period) || 'all');
    const pred = periodPred(period, today);
    const limit = Math.max(1, Math.min(30, Number(input && input.limit) || 12));
    const hits = rows.filter((x) => {
      if (type && x.t !== type) return false;
      if (!pred(x.d)) return false;
      if (cat && x.c.toLowerCase().indexOf(cat) === -1) return false;
      if (kw && (x.c + ' ' + x.n).toLowerCase().indexOf(kw) === -1) return false;
      return true;
    }).sort((a, b) => (a.d < b.d ? 1 : a.d > b.d ? -1 : 0));
    return {
      count: hits.length,
      shown: Math.min(hits.length, limit),
      rows: hits.slice(0, limit).map((x) => ({ date: x.d, type: x.t, amount: x.a, currency: x.cur, category: x.c, note: x.n })),
    };
  };
  const runBalance = () => ({
    currency: primary,
    balance,
    allTimeIncome: allIn,
    allTimeExpense: allOut,
    foreign: foreign.map((f: any) => ({ currency: String(f && f.sym || ''), balance: Number(f && f.bal) || 0 })).filter((f: any) => f.currency),
  });

  const system =
    `You are Paruay's in-app money assistant for a Lao/Thai shopkeeper. You help the user understand their finances and, when asked, add income or expense entries. The user writes in Lao, Thai, English, or Chinese; the current language is "${lang}" — ALWAYS reply in that language, warmly and briefly.\n\n` +
    `Money facts:\n` +
    `- Primary currency: ${primary}. Known currencies: ${curList}.\n` +
    `- Today is ${today}. You can see the user's transactions${windowFrom ? ` from ${windowFrom} onward` : ''} (${rows.length} entries). For the AUTHORITATIVE total balance and all-time totals, call get_balance — those numbers match what the app shows. Period queries older than your window may be incomplete; say so if relevant.\n` +
    `- Expense categories: ${catList(cats.expense) || '(none yet)'}. Income categories: ${catList(cats.income) || '(none yet)'}.\n\n` +
    `How to work:\n` +
    `- To answer questions about money, USE THE TOOLS (get_balance, summarize, search) rather than guessing. Do not invent numbers.\n` +
    `- Format amounts with the currency symbol and thousands separators (e.g. ${primary}50,000). Keep replies short — a sentence or two, plus figures.\n` +
    `- Only call add_transaction when the user clearly wants to record a new income or expense. Pick the best matching category (return its exact label + emoji) or invent a short 1-3 word one in the user's language. Default currency ${primary}. After adding, confirm what you saved in one line.\n` +
    `- If the user just chats or asks something unrelated to their money, answer normally without tools.`;

  // ── the tool-use loop ──
  const messages: any[] = inMsgs
    .map((m: any) => ({ role: m && m.role === 'assistant' ? 'assistant' : 'user', content: String((m && m.text) || '').slice(0, 2000) }))
    .filter((m: any) => m.content);
  if (!messages.length) return json({ ok: false, error: 'empty' }, 200);

  const actions: any[] = []; // read actions, for the activity feed
  const adds: any[] = [];    // proposed writes, for the client to persist

  for (let round = 0; round < MAX_ROUNDS; round++) {
    let r: Response;
    try {
      r = await fetch('https://api.anthropic.com/v1/messages', {
        method: 'POST',
        headers: { 'content-type': 'application/json', 'x-api-key': key, 'anthropic-version': '2023-06-01' },
        body: JSON.stringify({
          model: MODEL,
          max_tokens: 1024,
          thinking: { type: 'disabled' },
          system,
          tools,
          messages,
        }),
      });
    } catch (e) {
      return json({ ok: false, error: 'fetch_failed', detail: String(e).slice(0, 200) }, 200);
    }
    if (!r.ok) {
      const tx = await r.text().catch(() => '');
      return json({ ok: false, error: 'claude_' + r.status, detail: tx.slice(0, 300) }, 200);
    }
    let data: any;
    try { data = await r.json(); } catch (_) { return json({ ok: false, error: 'claude_parse' }, 200); }

    const content: any[] = Array.isArray(data.content) ? data.content : [];
    messages.push({ role: 'assistant', content });

    if (data.stop_reason !== 'tool_use') {
      const reply = content.filter((b) => b && b.type === 'text').map((b) => b.text).join('').trim();
      return json({ ok: true, reply, actions, adds }, 200);
    }

    // execute every tool_use block, collect tool_result blocks for the next turn
    const results: any[] = [];
    for (const b of content) {
      if (!b || b.type !== 'tool_use') continue;
      const input = b.input || {};
      let result: any;
      if (b.name === 'get_balance') { result = runBalance(); actions.push({ tool: 'get_balance', input: {}, result }); }
      else if (b.name === 'summarize') { result = runSummarize(input); actions.push({ tool: 'summarize', input, result: { total: result.total, count: result.count, period: result.period, type: result.type, top: result.categories.slice(0, 5) } }); }
      else if (b.name === 'search') { result = runSearch(input); actions.push({ tool: 'search', input, result: { count: result.count, shown: result.shown } }); }
      else if (b.name === 'add_transaction') {
        const type = input.type === 'income' ? 'income' : 'expense';
        const amount = Math.round(Math.abs(Number(input.amount) || 0));
        const categoryLabel = String(input.categoryLabel || '').trim();
        if (amount > 0 && categoryLabel) {
          const add: any = { type, amount, categoryLabel, categoryEmoji: String(input.categoryEmoji || '').trim(), note: String(input.note || '').trim() };
          const cur = String(input.currency || '').trim();
          if (cur && cur !== primary) add.currency = cur;
          adds.push(add);
          result = { ok: true, saved: 'pending_on_device', type, amount, category: categoryLabel, currency: cur || primary };
        } else {
          result = { ok: false, error: 'need type, positive amount and category' };
        }
      } else {
        result = { error: 'unknown tool' };
      }
      results.push({ type: 'tool_result', tool_use_id: b.id, content: JSON.stringify(result) });
    }
    messages.push({ role: 'user', content: results });
  }

  // ran out of rounds — return whatever text/actions we have
  const lastText = (messages.slice().reverse().find((m: any) => m.role === 'assistant' && Array.isArray(m.content)) || { content: [] })
    .content.filter((b: any) => b && b.type === 'text').map((b: any) => b.text).join('').trim();
  return json({ ok: true, reply: lastText || '', actions, adds, truncated: true }, 200);
});

// Paruay parse-expense (v3.7.247) — turn a spoken/typed sentence into ONE structured transaction.
// The Anthropic API key stays SERVER-SIDE (Edge Function secret ANTHROPIC_API_KEY); the client
// (which ships the public anon key) must never see it. Client calls this via supabase.functions.invoke,
// so Supabase verifies the caller's JWT automatically → only logged-in users can spend the AI budget.
//
// Deploy:
//   supabase secrets set ANTHROPIC_API_KEY=sk-ant-...   (once)
//   SUPABASE_ACCESS_TOKEN=<pat> supabase functions deploy parse-expense --project-ref rilrbflteuwhomrwfcsa
//
// Request body: { text, lang, categories:{income:[{label,emoji}],expense:[...]}, primaryCurrency, currencies:[sym], today }
// Response: { ok, type:'income'|'expense', amount:number, categoryLabel, categoryEmoji, note, currency }

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

const json = (obj: unknown, status = 200) =>
  new Response(JSON.stringify(obj), { status, headers: { ...CORS, 'content-type': 'application/json' } });

// Structured-output schema — guarantees the model's first text block is valid JSON in this shape.
const SCHEMA = {
  type: 'object',
  properties: {
    ok: { type: 'boolean', description: 'true only if the text describes a money income or expense' },
    type: { type: 'string', enum: ['income', 'expense'] },
    amount: { type: 'number', description: 'positive amount in the transaction currency, digits only' },
    categoryLabel: { type: 'string' },
    categoryEmoji: { type: 'string' },
    note: { type: 'string' },
    currency: { type: 'string' },
  },
  required: ['ok', 'type', 'amount', 'categoryLabel', 'categoryEmoji', 'note', 'currency'],
  additionalProperties: false,
};

const catList = (arr: any) =>
  (Array.isArray(arr) ? arr : [])
    .map((c) => `${(c && c.emoji) || ''} ${(c && c.label) || ''}`.trim())
    .filter(Boolean)
    .join(', ');

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS });
  if (req.method !== 'POST') return json({ ok: false, error: 'method' }, 405);

  const key = Deno.env.get('ANTHROPIC_API_KEY');
  if (!key) return json({ ok: false, error: 'no_api_key' }, 500);

  let body: any = {};
  try { body = await req.json(); } catch (_) { return json({ ok: false, error: 'bad_body' }, 400); }

  const text = String(body.text || '').trim().slice(0, 500);
  if (!text) return json({ ok: false, error: 'empty' }, 200);

  const lang = String(body.lang || 'lo');
  const primary = String(body.primaryCurrency || '₭'); // ₭
  const currencies: string[] = Array.isArray(body.currencies) ? body.currencies.map((c: any) => String(c)) : [];
  const cats = body.categories || {};
  const expenseCats = catList(cats.expense) || '(none yet)';
  const incomeCats = catList(cats.income) || '(none yet)';
  const curList = [primary, ...currencies].filter(Boolean).join(', ');

  const system =
    `You convert ONE short spoken sentence about money into a single structured transaction for a Lao/Thai shopkeeper's finance app. Users speak Lao, Thai, English, or Chinese; the input language for this request is "${lang}".\n\n` +
    `Rules:\n` +
    `- type: money going OUT (buy / pay / spend — ຈ່າຍ ຊື້ / จ่าย ซื้อ / bought / paid) = "expense". Money coming IN (receive / salary / sold — ໄດ້ຮັບ ເງິນເດືອນ ຂາຍໄດ້ / ได้ รับ เงินเดือน ขายได้ / got / sold) = "income". If genuinely unclear, use "expense".\n` +
    `- amount: a POSITIVE number, digits only (no separators). Understand spoken numerals in all four languages, including Lao/Thai number words (ຫ້າໝື່ນ / ห้าหมื่น = 50000; ສองພันห้า / สองพันห้า = 2500) and shorthand (50k = 50000, 2m = 2000000).\n` +
    `- currency: default to "${primary}". Use a different symbol ONLY if the user clearly names another currency from this list: ${curList}.\n` +
    `- category: pick the BEST-matching category from the user's existing lists and return that category's EXACT label and its emoji. Expense categories: ${expenseCats}. Income categories: ${incomeCats}. If none fit, invent a short 1-3 word label in the user's language and choose a fitting emoji.\n` +
    `- note: any extra worth keeping (a name, place, count) in the user's language. Keep it short; empty string if none.\n` +
    `- ok: false ONLY when the text is not about a money transaction (e.g. a greeting or a question). When ok is false still fill the other fields with safe defaults (type "expense", amount 0, empty strings, currency "${primary}").\n` +
    `Reply with the structured object only.`;

  let r: Response;
  try {
    r = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: { 'content-type': 'application/json', 'x-api-key': key, 'anthropic-version': '2023-06-01' },
      body: JSON.stringify({
        model: 'claude-sonnet-5',
        max_tokens: 512,
        thinking: { type: 'disabled' }, // trivial extraction — skip thinking for speed/cost
        system,
        output_config: { format: { type: 'json_schema', schema: SCHEMA } },
        messages: [{ role: 'user', content: text }],
      }),
    });
  } catch (e) {
    return json({ ok: false, error: 'fetch_failed', detail: String(e).slice(0, 200) }, 200);
  }

  if (!r.ok) {
    const t = await r.text().catch(() => '');
    return json({ ok: false, error: 'claude_' + r.status, detail: t.slice(0, 300) }, 200);
  }

  let data: any;
  try { data = await r.json(); } catch (_) { return json({ ok: false, error: 'claude_parse' }, 200); }

  const block = (data && Array.isArray(data.content) ? data.content : []).find((b: any) => b && b.type === 'text');
  if (!block || !block.text) return json({ ok: false, error: 'no_content' }, 200);

  let parsed: any;
  try { parsed = JSON.parse(block.text); } catch (_) { return json({ ok: false, error: 'bad_json', detail: String(block.text).slice(0, 200) }, 200); }

  return json(parsed, 200);
});

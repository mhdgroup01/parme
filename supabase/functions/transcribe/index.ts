// Paruay transcribe (v3.7.271) — STT via Gemini, auto-fallback to self-hosted MMS (mms-lao) on quota/failure, for devices where the
// Web Speech API can't deliver (iPhone: WebKit forces Apple's engine, which breaks in PWAs
// and has NO Lao support). The client records audio (MediaRecorder) and posts it here;
// we ask Gemini to transcribe verbatim. GEMINI_API_KEY stays SERVER-SIDE (edge secret).
//
// Deploy (self-hosted Supabase on the VPS):
//   place at /docker/supabase/docker/volumes/functions/transcribe/index.ts
//   add GEMINI_API_KEY to /docker/supabase/docker/.env + functions service env in docker-compose.yml
//   then: cd /docker/supabase/docker && docker compose up -d --wait functions
//
// Request body: { audio: base64 (no data: prefix), mime: 'audio/mp4'|..., lang: 'lo'|'th'|'en'|'zh' }
// Response: { ok, text }

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

const json = (obj: unknown, status = 200) =>
  new Response(JSON.stringify(obj), { status, headers: { ...CORS, 'content-type': 'application/json' } });

const MAX_B64 = 4 * 1024 * 1024; // ~3MB audio ≈ หลายนาทีของเสียงพูด — เกินนี้คือผิดปกติ/abuse

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS });
  if (req.method !== 'POST') return json({ ok: false, error: 'method' }, 405);

  const key = Deno.env.get('GEMINI_API_KEY');
  if (!key) return json({ ok: false, error: 'no_api_key' }, 500);
  // ชั้น 1 = Gemini 2.5-flash (เร็ว/แม่นตอนมีโควตา); ชั้น 2 = MMS self-host (ฟรีถาวร ไม่มีเพดาน) เมื่อ Gemini 429/ล่ม
  const geminiModel = Deno.env.get('GEMINI_MODEL') || 'gemini-2.5-flash';
  const mmsUrl = Deno.env.get('MMS_URL') || 'http://mms-lao:8899';

  // Gate to logged-in users only (the public anon key is a valid JWT but role isn't "authenticated").
  try {
    const jwt = (req.headers.get('authorization') || '').replace(/^Bearer\s+/i, '');
    const payload = JSON.parse(atob((jwt.split('.')[1] || '').replace(/-/g, '+').replace(/_/g, '/')));
    if (payload.role !== 'authenticated') return json({ ok: false, error: 'auth_required' }, 401);
  } catch (_) {
    return json({ ok: false, error: 'auth_required' }, 401);
  }

  let body: any = {};
  try { body = await req.json(); } catch (_) { return json({ ok: false, error: 'bad_body' }, 400); }

  const audio = String(body.audio || '');
  if (!audio) return json({ ok: false, error: 'empty' }, 200);
  if (audio.length > MAX_B64) return json({ ok: false, error: 'too_large' }, 200);
  let mime = String(body.mime || 'audio/mp4').split(';')[0].trim().slice(0, 60);
  // iOS MediaRecorder ให้ audio/mp4 (AAC ใน MP4) — รายการทางการของ Gemini ใช้ audio/aac; ตัว decoder sniff เนื้อไฟล์เองได้
  if (mime === 'audio/mp4' || mime === 'audio/x-m4a' || mime === 'audio/m4a') mime = 'audio/aac';
  if (mime === 'audio/webm') mime = 'audio/ogg';
  const lang = String(body.lang || 'lo');
  const langName = ({ lo: 'Lao', th: 'Thai', en: 'English', zh: 'Chinese' } as Record<string, string>)[lang] || 'Lao';

  const prompt =
    `Transcribe this audio verbatim. The speaker most likely speaks ${langName} (they may mix Lao, Thai, English, or Chinese). ` +
    `Return ONLY the transcribed words in the language actually spoken — no translation, no punctuation cleanup beyond what is natural, no commentary. ` +
    `If there is no intelligible speech, return an empty response.`;

  let text: string | null = null;
  let engine = '';
  let lastErr = '';

  // ── ชั้น 1: Gemini (เร็ว/แม่นสุดตอนมีโควตา) ──
  // timeout 12s กัน Kong ตัดเป็น 500 (เคยเจอ Gemini ค้าง ~58s) → ตกไป MMS ทันที
  try {
    const r = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${geminiModel}:generateContent?key=${key}`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      signal: AbortSignal.timeout(12000),
      body: JSON.stringify({
        contents: [{ parts: [{ inlineData: { mimeType: mime, data: audio } }, { text: prompt }] }],
        // thinkingBudget 0 = ปิด thinking (default เปิด → ช้า ~48s; ปิดแล้ว ~2-3s — งานถอดเสียงไม่ต้องคิด)
        generationConfig: { temperature: 0, maxOutputTokens: 512, thinkingConfig: { thinkingBudget: 0 } },
      }),
    });
    if (r.ok) {
      const data = await r.json();
      text = (((data.candidates || [])[0] || {}).content?.parts || [])
        .map((p: any) => (p && p.text) || '').join('').trim();
      engine = 'gemini';
    } else {
      // 429 = หมดโควตาวันนี้ (เหตุผลหลักที่ต้องมี fallback); อื่นๆ = model ถูกถอน/ค้าง
      lastErr = 'gemini_' + r.status + ':' + (await r.text().catch(() => '')).slice(0, 150);
    }
  } catch (e) {
    lastErr = 'gemini_fetch:' + String(e).slice(0, 120);
  }

  // ── ชั้น 2: MMS self-host (ฟรีถาวร ไม่มีเพดาน) — เมื่อ Gemini 429/ล่ม/timeout ──
  // adapter โหลดเป็นภาษาลาว; ไทย/en/zh ฝั่ง client ไม่เรียก transcribe อยู่แล้ว (guard กันส่งภาษาอื่นมาถอดมั่ว)
  if (text === null && lang === 'lo') {
    try {
      const r = await fetch(`${mmsUrl}/transcribe`, {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        signal: AbortSignal.timeout(25000),
        body: JSON.stringify({ audio, mime }),
      });
      if (r.ok) {
        const d = await r.json();
        if (d && d.ok && typeof d.text === 'string') { text = d.text.trim(); engine = 'mms'; }
        else lastErr += ' | mms:' + ((d && d.error) || 'fail');
      } else {
        lastErr += ' | mms_http_' + r.status;
      }
    } catch (e) {
      lastErr += ' | mms_fetch:' + String(e).slice(0, 120);
    }
  }

  if (text === null) return json({ ok: false, error: 'all_failed', detail: lastErr.slice(0, 300) }, 200);
  return json({ ok: true, text, engine }, 200);
});

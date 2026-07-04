// Paruay login-username (v3.7.255) — resolve username→email SERVER-SIDE and sign in,
// so the email is NEVER returned to an unauthenticated client.
// Fixes the anon get_email_by_username PII-harvesting leak: the client no longer needs the email.
//
// Called pre-auth (anon). The gateway verify_jwt accepts the public anon key the client sends;
// this function intentionally does NOT require the "authenticated" role (login happens before auth).
//
// Request  body: { username, password, captchaToken }
// Response: GoTrue /token response verbatim — { access_token, refresh_token, user, ... } on success,
//           or GoTrue's error JSON (wrong password / captcha) with its status code, passed through.
import { createClient } from 'jsr:@supabase/supabase-js@2'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!            // http://kong:8000
const SERVICE_ROLE = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
const ANON = Deno.env.get('SUPABASE_ANON_KEY')!

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}
const json = (obj: unknown, status = 200) =>
  new Response(JSON.stringify(obj), { status, headers: { ...CORS, 'content-type': 'application/json' } })

const admin = createClient(SUPABASE_URL, SERVICE_ROLE)

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS })
  if (req.method !== 'POST') return json({ error: 'method_not_allowed' }, 405)

  let body: any = {}
  try { body = await req.json() } catch (_) { return json({ error: 'bad_body' }, 400) }
  const username = String(body.username || '').trim()
  const password = String(body.password || '')
  const captchaToken = String(body.captchaToken || '')
  if (!username || !password) return json({ error: 'missing_credentials' }, 400)

  // 1) resolve username → email server-side (service role bypasses RLS; email stays server-side)
  let email = ''
  try {
    const { data, error } = await admin.rpc('get_email_by_username', { uname: username })
    if (error) return json({ error: 'lookup_failed' }, 500)
    email = String(data || '')
  } catch (_) {
    return json({ error: 'lookup_failed' }, 500)
  }
  if (!email) return json({ error: 'user_not_found', code: 'user_not_found' }, 404)

  // 2) sign in with the resolved email — forward the captcha token exactly like supabase-js does
  try {
    const r = await fetch(`${SUPABASE_URL}/auth/v1/token?grant_type=password`, {
      method: 'POST',
      headers: { apikey: ANON, 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, password, gotrue_meta_security: { captcha_token: captchaToken } }),
    })
    const session = await r.json().catch(() => ({}))
    // pass GoTrue's response straight through (session on success, error otherwise) — email is NOT included
    return json(session, r.status)
  } catch (_) {
    return json({ error: 'signin_failed' }, 502)
  }
})

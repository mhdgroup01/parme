// Paruay Edge Function: send-pos-push
// Triggered by a Postgres trigger (trg_notify_new_pos_order) on INSERT into public.pos_qr_orders.
// Sends an order alert to every device registered for that shop, over TWO channels:
//   1. Web Push (PWA / browser)  — table public.push_subscriptions
//   2. FCM HTTP v1 (แอปเนทีฟ)     — table public.fcm_tokens          [v3.7.420]
//
// Required secrets:
//   VAPID_PUBLIC   — VAPID public key
//   VAPID_PRIVATE  — VAPID private key
//   VAPID_SUBJECT  — e.g. mailto:mhdgroup01@gmail.com  (optional, has default)
//   FCM_SERVICE_ACCOUNT — [v3.7.420] JSON ของ service account จาก Firebase (ทั้งก้อน)
//                          ถ้าไม่ตั้ง = ข้ามช่อง FCM เงียบๆ ช่อง Web Push ทำงานเหมือนเดิมทุกอย่าง
// SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are injected automatically.

import webpush from 'npm:web-push@3.6.7'
import { createClient } from 'jsr:@supabase/supabase-js@2'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SERVICE_ROLE = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
const VAPID_PUBLIC = Deno.env.get('VAPID_PUBLIC')!
const VAPID_PRIVATE = Deno.env.get('VAPID_PRIVATE')!
const VAPID_SUBJECT = Deno.env.get('VAPID_SUBJECT') || 'mailto:mhdgroup01@gmail.com'
const FCM_SA_RAW = Deno.env.get('FCM_SERVICE_ACCOUNT') || ''

webpush.setVapidDetails(VAPID_SUBJECT, VAPID_PUBLIC, VAPID_PRIVATE)
const admin = createClient(SUPABASE_URL, SERVICE_ROLE)

// ---------- FCM HTTP v1 ----------
// legacy FCM (server key) ปิดไปแล้วกลางปี 2024 ⇒ ต้องใช้ v1 ซึ่งต้องแลก JWT ของ service account
// เป็น OAuth access token ก่อน. cache token ไว้ 55 นาที (อายุจริง 60) กันขอใหม่ทุกออเดอร์
let fcmSa: { client_email: string; private_key: string; project_id: string } | null = null
// แยก "ไม่ได้ตั้ง secret" ออกจาก "ตั้งแล้วแต่ค่าเสีย" — ตอนติดตั้งครั้งแรกค่าถูก shell กินจนพัง
// แล้วข้อความเดิมบอกว่า "no FCM_SERVICE_ACCOUNT" ทำให้ไล่ผิดทางอยู่พักหนึ่ง
let fcmSaErr = ''
try { if (FCM_SA_RAW) fcmSa = JSON.parse(FCM_SA_RAW) } catch (e: any) { fcmSa = null; fcmSaErr = 'FCM_SERVICE_ACCOUNT ตั้งไว้แล้วแต่ parse ไม่ได้ (' + (e && e.message) + ')' }

let cachedToken = ''
let cachedExp = 0

const pemToDer = (pem: string) => {
  const b64 = pem.replace(/-----(BEGIN|END) PRIVATE KEY-----/g, '').replace(/\s+/g, '')
  const bin = atob(b64)
  const out = new Uint8Array(bin.length)
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i)
  return out
}
const b64url = (buf: ArrayBuffer | Uint8Array) => {
  const b = buf instanceof Uint8Array ? buf : new Uint8Array(buf)
  let s = ''
  for (let i = 0; i < b.length; i++) s += String.fromCharCode(b[i])
  return btoa(s).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '')
}

const fcmAccessToken = async (): Promise<string> => {
  const now = Math.floor(Date.now() / 1000)
  if (cachedToken && now < cachedExp) return cachedToken
  if (!fcmSa || !fcmSa.private_key || !fcmSa.client_email) throw new Error('no service account')
  const header = b64url(new TextEncoder().encode(JSON.stringify({ alg: 'RS256', typ: 'JWT' })))
  const claim = b64url(new TextEncoder().encode(JSON.stringify({
    iss: fcmSa.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  })))
  const key = await crypto.subtle.importKey(
    'pkcs8', pemToDer(fcmSa.private_key),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, false, ['sign'],
  )
  const sig = await crypto.subtle.sign('RSASSA-PKCS1-v1_5', key, new TextEncoder().encode(header + '.' + claim))
  const assertion = header + '.' + claim + '.' + b64url(sig)
  const r = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: 'grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=' + encodeURIComponent(assertion),
  })
  const j = await r.json()
  if (!j || !j.access_token) throw new Error('token: ' + JSON.stringify(j).slice(0, 200))
  cachedToken = j.access_token
  cachedExp = now + 3300
  return cachedToken
}

// ส่งเป็น notification message (ไม่ใช่ data-only): Android โชว์เองตอนแอปอยู่พื้นหลัง/ปิด
// ตอนแอปเปิดอยู่ ระบบไม่โชว์ให้ แต่แอปมี realtime + LocalNotifications เตือนเองอยู่แล้ว (v3.7.419)
// ⇒ แยกหน้าที่กันชัด ไม่เตือนซ้ำ
const sendFcm = async (title: string, body: string, tag: string, shop: string) => {
  if (!fcmSa) return { skipped: fcmSaErr || 'no FCM_SERVICE_ACCOUNT' }
  const { data: toks } = await admin.from('fcm_tokens').select('token').eq('shop_id', shop)
  if (!toks || !toks.length) return { skipped: 'no fcm tokens' }
  const access = await fcmAccessToken()
  const url = 'https://fcm.googleapis.com/v1/projects/' + fcmSa.project_id + '/messages:send'
  let sent = 0, pruned = 0
  await Promise.all(toks.map(async (t: any) => {
    try {
      const r = await fetch(url, {
        method: 'POST',
        headers: { authorization: 'Bearer ' + access, 'content-type': 'application/json' },
        body: JSON.stringify({
          message: {
            token: t.token,
            notification: { title, body },
            android: { priority: 'HIGH', notification: { tag, sound: 'default' } },
            data: { tag },
          },
        }),
      })
      if (r.ok) { sent++; return }
      // 404 UNREGISTERED / 403 SENDER_ID_MISMATCH = token ใช้ไม่ได้อีก → ลบทิ้งกันสะสม
      if (r.status === 404 || r.status === 403) {
        try { await admin.from('fcm_tokens').delete().eq('token', t.token); pruned++ } catch (_) {}
      }
    } catch (_) {}
  }))
  return { sent, pruned, total: toks.length }
}

Deno.serve(async (req) => {
  try {
    const payload = await req.json()
    const row = payload.record || payload.new || payload
    if (!row || !row.shop) return new Response('no shop', { status: 200 })
    if (row.status && row.status !== 'new') return new Response('skip', { status: 200 })

    const note = row.note || ''
    const items = Array.isArray(row.items) ? row.items : []
    const n = items.reduce((s: number, it: any) => s + (parseInt(it && it.qty, 10) || 1), 0)
    const table = (row.table_no ?? '-')

    let title = '🛎 ออเดอร์ใหม่'
    let body: string
    if (note === '__CALL__') { title = '🙋 ลูกค้าเรียกพนักงาน'; body = 'โต๊ะ ' + table }
    else if (note === '__BILL__') { title = '🧾 ลูกค้าขอเช็คบิล'; body = 'โต๊ะ ' + table }
    else { body = 'โต๊ะ ' + table + ' · ' + n + ' รายการ' + (note ? ' · ' + note : '') }

    const tag = 'pos-order-' + table
    const out: Record<string, unknown> = {}

    // ---- ช่อง 1: Web Push (ของเดิม ไม่แตะพฤติกรรม) ----
    try {
      const { data: subs } = await admin
        .from('push_subscriptions').select('*').eq('shop_id', row.shop)
      if (subs && subs.length) {
        const msg = JSON.stringify({ title, body, tag, url: '.' })
        await Promise.all(subs.map(async (s: any) => {
          try {
            await webpush.sendNotification(
              { endpoint: s.endpoint, keys: { p256dh: s.p256dh, auth: s.auth } },
              msg
            )
          } catch (err: any) {
            const code = err && err.statusCode
            if (code === 404 || code === 410) {
              try { await admin.from('push_subscriptions').delete().eq('endpoint', s.endpoint) } catch (_) {}
            }
          }
        }))
        out.webpush = subs.length
      } else {
        out.webpush = 'no subs'
      }
    } catch (e: any) {
      out.webpush = 'err: ' + (e && e.message)
    }

    // ---- ช่อง 2: FCM (v3.7.420) — ครอบ try แยกและรันทีหลัง เพื่อไม่ให้ล้มไปกระทบช่องแรก ----
    try {
      out.fcm = await sendFcm(title, body, tag, row.shop)
    } catch (e: any) {
      out.fcm = 'err: ' + (e && e.message)
    }

    return new Response(JSON.stringify(out), { status: 200, headers: { 'content-type': 'application/json' } })
  } catch (e: any) {
    return new Response('err: ' + (e && e.message), { status: 200 })
  }
})

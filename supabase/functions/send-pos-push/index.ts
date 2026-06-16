// Paruay Edge Function: send-pos-push
// Triggered by a Database Webhook on INSERT into public.pos_qr_orders.
// Sends a Web Push notification to every device subscribed for that shop.
//
// Required secrets (supabase secrets set ...):
//   VAPID_PUBLIC   — VAPID public key
//   VAPID_PRIVATE  — VAPID private key
//   VAPID_SUBJECT  — e.g. mailto:mhdgroup01@gmail.com  (optional, has default)
// SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are injected automatically.

import webpush from 'npm:web-push@3.6.7'
import { createClient } from 'jsr:@supabase/supabase-js@2'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SERVICE_ROLE = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
const VAPID_PUBLIC = Deno.env.get('VAPID_PUBLIC')!
const VAPID_PRIVATE = Deno.env.get('VAPID_PRIVATE')!
const VAPID_SUBJECT = Deno.env.get('VAPID_SUBJECT') || 'mailto:mhdgroup01@gmail.com'

webpush.setVapidDetails(VAPID_SUBJECT, VAPID_PUBLIC, VAPID_PRIVATE)
const admin = createClient(SUPABASE_URL, SERVICE_ROLE)

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

    const { data: subs } = await admin
      .from('push_subscriptions').select('*').eq('shop_id', row.shop)
    if (!subs || !subs.length) return new Response('no subs', { status: 200 })

    const msg = JSON.stringify({ title, body, tag: 'pos-order-' + table, url: '.' })
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
    return new Response('ok', { status: 200 })
  } catch (e: any) {
    return new Response('err: ' + (e && e.message), { status: 200 })
  }
})

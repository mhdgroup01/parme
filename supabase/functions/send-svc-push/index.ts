// Parme Edge Function: send-svc-push
// ยิงจาก trigger trg_notify_svc (INSERT บน public.friend_notifications เฉพาะ type ที่ขึ้นต้นด้วย svc_)
// ส่งหาผู้รับผ่านสองช่องเหมือน send-pos-push: Web Push (PWA) + FCM HTTP v1 (แอปเนทีฟ)
//
// ⚠️ ต่างจาก send-pos-push ตรงที่นั่นส่งตาม "ร้าน" (shop_id) แต่ที่นี่ส่งตาม "ผู้ใช้" (user_id)
//    ⇒ query อุปกรณ์ด้วย user_id และต้องไม่ยิงหาอุปกรณ์ของคนอื่นเด็ดขาด
//
// secrets ที่ต้องมี: VAPID_PUBLIC / VAPID_PRIVATE / VAPID_SUBJECT (ทางเลือก) / FCM_SERVICE_ACCOUNT (ทางเลือก)
// ไม่มี FCM_SERVICE_ACCOUNT = ข้ามช่อง FCM เงียบๆ ช่อง Web Push ยังทำงานปกติ

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

// ---------- FCM HTTP v1 (โครงเดียวกับ send-pos-push) ----------
let fcmSa: { client_email: string; private_key: string; project_id: string } | null = null
let fcmSaErr = ''
try { if (FCM_SA_RAW) fcmSa = JSON.parse(FCM_SA_RAW) } catch (e: any) { fcmSa = null; fcmSaErr = 'FCM_SERVICE_ACCOUNT parse ไม่ได้ (' + (e && e.message) + ')' }

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
  if (!fcmSa || !fcmSa.private_key || !fcmSa.client_email) throw new Error(fcmSaErr || 'no service account')
  const header = b64url(new TextEncoder().encode(JSON.stringify({ alg: 'RS256', typ: 'JWT' })))
  const claim = b64url(new TextEncoder().encode(JSON.stringify({
    iss: fcmSa.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now, exp: now + 3600,
  })))
  const key = await crypto.subtle.importKey('pkcs8', pemToDer(fcmSa.private_key),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, false, ['sign'])
  const sig = await crypto.subtle.sign('RSASSA-PKCS1-v1_5', key, new TextEncoder().encode(header + '.' + claim))
  const jwt = header + '.' + claim + '.' + b64url(sig)
  const r = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: 'grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=' + jwt,
  })
  const j = await r.json()
  if (!j.access_token) throw new Error('oauth: ' + JSON.stringify(j))
  cachedToken = j.access_token
  cachedExp = now + 3300           // อายุจริง 3600 — เผื่อ 5 นาที
  return cachedToken
}

const sendFcm = async (title: string, body: string, tag: string, userId: string) => {
  if (!fcmSa) return fcmSaErr || 'no service account'
  const { data: toks } = await admin.from('fcm_tokens').select('token').eq('user_id', userId)
  if (!toks || !toks.length) return { sent: 0, total: 0 }
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
      if (r.status === 404 || r.status === 403) {
        try { await admin.from('fcm_tokens').delete().eq('token', t.token); pruned++ } catch (_) {}
      }
    } catch (_) {}
  }))
  return { sent, pruned, total: toks.length }
}

// ---------- ข้อความ ----------
// ผู้รับอาจตั้งภาษาอะไรก็ได้ ⇒ อ่านจาก user_settings เหมือน send-loan-due
// ไม่รู้ภาษา = ลาว (ผู้ใช้ส่วนใหญ่ของกระดานนี้)
const TEXT: Record<string, Record<string, [string, string]>> = {
  lo: {
    svc_job_offer:    ['🤝 ມີຄົນຢາກຈ້າງງານ', 'ກົດເບິ່ງໃບງານ ແລ້ວກົດຮັບງານ'],
    svc_job_accepted: ['✅ ອີກຝ່າຍຮັບງານແລ້ວ', 'ເລີ່ມງານໄດ້ເລີຍ'],
    svc_job_done:     ['🏁 ງານຈົບແລ້ວ', 'ໃຫ້ດາວ ແລະ ຄຳຄິດເຫັນກັນໄດ້ແລ້ວ'],
    svc_review:       ['⭐ ໄດ້ຮັບຄະແນນໃໝ່', 'ໃຫ້ດາວກັບຄືນເພື່ອເປີດເບິ່ງຄະແນນຂອງອີກຝ່າຍ'],
    svc_interest:     ['🙋 ມີຄົນສົນໃຈປະກາດຂອງທ່ານ', 'ກົດເບິ່ງໃນ ຮັບເຮັດ'],
  },
  th: {
    svc_job_offer:    ['🤝 มีคนอยากจ้างงาน', 'กดดูใบงานแล้วกดรับงาน'],
    svc_job_accepted: ['✅ อีกฝ่ายรับงานแล้ว', 'เริ่มงานได้เลย'],
    svc_job_done:     ['🏁 งานจบแล้ว', 'ให้ดาวและความเห็นกันได้แล้ว'],
    svc_review:       ['⭐ ได้รับคะแนนใหม่', 'ให้ดาวกลับเพื่อเปิดดูคะแนนของอีกฝ่าย'],
    svc_interest:     ['🙋 มีคนสนใจประกาศของคุณ', 'กดดูในเมนู รับเหมา/หางาน'],
  },
  en: {
    svc_job_offer:    ['🤝 Someone wants to hire you', 'Open Jobs and accept'],
    svc_job_accepted: ['✅ Your job was accepted', 'You can start now'],
    svc_job_done:     ['🏁 Job finished', 'You can rate each other now'],
    svc_review:       ['⭐ You received a rating', 'Rate back to reveal theirs'],
    svc_interest:     ['🙋 Someone is interested in your post', 'Open the work board'],
  },
  zh: {
    svc_job_offer:    ['🤝 有人想雇用您', '打开工单并接受'],
    svc_job_accepted: ['✅ 对方已接受工单', '可以开始了'],
    svc_job_done:     ['🏁 工作已完成', '现在可以互评'],
    svc_review:       ['⭐ 收到新评分', '回评后即可看到对方的评分'],
    svc_interest:     ['🙋 有人对您的发布感兴趣', '打开接活板块'],
  },
}

Deno.serve(async (req) => {
  try {
    const payload = await req.json()
    const row = payload.record || payload.new || payload
    const type = row && row.type
    const to = row && row.recipient_id
    // ยิงเฉพาะประเภทของกระดาน ຮັບເຮັດ — trigger กรองมาแล้วชั้นหนึ่ง นี่คือชั้นที่สอง
    if (!to || !type || String(type).indexOf('svc_') !== 0) return new Response('skip', { status: 200 })

    let lang = 'lo'
    try {
      const { data: st } = await admin.from('user_settings').select('lang').eq('user_id', to).maybeSingle()
      if (st && st.lang && TEXT[st.lang]) lang = st.lang
    } catch (_) {}

    const pack = TEXT[lang] || TEXT.lo
    const pair = pack[type]
    if (!pair) return new Response('unknown type', { status: 200 })

    const meta = row.metadata || {}
    const title = pair[0]
    // ชื่องานอยู่ในบรรทัดสองเสมอ ⇒ ผู้รับรู้ทันทีว่าเป็นงานไหนโดยไม่ต้องเปิดแอป
    const body = (meta.title ? String(meta.title).slice(0, 60) + ' · ' : '') + pair[1]
    const tag = 'svc-' + (meta.job_id || meta.post_id || row.id)

    const out: Record<string, unknown> = { type, lang }

    try {
      const { data: subs } = await admin.from('push_subscriptions').select('*').eq('user_id', to)
      if (subs && subs.length) {
        const msg = JSON.stringify({ title, body, tag, url: '.' })
        await Promise.all(subs.map(async (s: any) => {
          try {
            await webpush.sendNotification({ endpoint: s.endpoint, keys: { p256dh: s.p256dh, auth: s.auth } }, msg)
          } catch (err: any) {
            const code = err && err.statusCode
            if (code === 404 || code === 410) {
              try { await admin.from('push_subscriptions').delete().eq('endpoint', s.endpoint) } catch (_) {}
            }
          }
        }))
        out.webpush = subs.length
      } else out.webpush = 'no subs'
    } catch (e: any) { out.webpush = 'err: ' + (e && e.message) }

    // ช่อง FCM แยก try และรันทีหลัง — ล้มที่นี่ต้องไม่กระทบช่องแรกที่ส่งไปแล้ว
    try { out.fcm = await sendFcm(title, body, tag, to) } catch (e: any) { out.fcm = 'err: ' + (e && e.message) }

    return new Response(JSON.stringify(out), { status: 200, headers: { 'content-type': 'application/json' } })
  } catch (e: any) {
    return new Response('err: ' + (e && e.message), { status: 200 })
  }
})

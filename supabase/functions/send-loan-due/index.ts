// Parme Edge Function: send-loan-due
// เรียกโดย pg_cron วันละครั้ง (02:00 UTC = 09:00 Asia/Vientiane) — ดูงาน 'loan-due-daily' ใน cron.job
//
// หน้าที่: หาเงินกู้ที่ "ครบกำหนดคืนวันนี้" แล้วส่ง Web Push ให้เจ้าของรายการ
//
// 🔴 ทำไมต้องมีตัวนี้ ทั้งที่แอปเนทีฟตั้งเตือนเองได้:
//    LocalNotifications ใช้ได้เฉพาะแอปเนทีฟ (Capacitor) — ผู้ใช้ PWA ไม่มีปลั๊กอิน
//    และตอนนี้ผู้ใช้ iOS **ทุกคน** อยู่บน PWA เพราะแอปยังไม่ขึ้น App Store
//    ⇒ ช่องทางเดียวที่ถึงพวกเขาตอนแอปปิดคือ Web Push จากเซิร์ฟเวอร์
//
// ⚠️ ข้อสมมติเรื่องเขตเวลา: ตัดสิน "วันนี้" ด้วย Asia/Vientiane (UTC+7) ให้ทุกคนเหมือนกัน
//    ฐานผู้ใช้อยู่ลาว/ไทยซึ่ง UTC+7 ทั้งคู่ ยังไม่เก็บเขตเวลารายคน — ถ้าวันหลังมีผู้ใช้นอกโซนนี้ต้องแก้ตรงนี้
//
// Secrets ที่ต้องมี (ชุดเดียวกับ send-pos-push ตั้งไว้แล้ว):
//   VAPID_PUBLIC · VAPID_PRIVATE · VAPID_SUBJECT
//   SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY ถูกฉีดให้อัตโนมัติ

import webpush from 'npm:web-push@3.6.7'
import { createClient } from 'jsr:@supabase/supabase-js@2'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SERVICE_ROLE = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
const VAPID_PUBLIC = Deno.env.get('VAPID_PUBLIC')!
const VAPID_PRIVATE = Deno.env.get('VAPID_PRIVATE')!
const VAPID_SUBJECT = Deno.env.get('VAPID_SUBJECT') || 'mailto:mhdgroup01@gmail.com'

webpush.setVapidDetails(VAPID_SUBJECT, VAPID_PUBLIC, VAPID_PRIVATE)
const admin = createClient(SUPABASE_URL, SERVICE_ROLE)

// ข้อความ 4 ภาษา — ต้องตรงกับคีย์ due_reminder_* ใน index.html ไม่งั้นผู้ใช้เห็นคนละสำนวนสองที่
const T: Record<string, { title: string; one: string; many: string }> = {
  lo: { title: '🔔 ຮອດກຳນົດຊຳລະແລ້ວ', one: '{name} ຮອດກຳນົດຄືນມື້ນີ້', many: '{name} ແລະອີກ {n} ລາຍການ ຮອດກຳນົດມື້ນີ້' },
  th: { title: '🔔 ถึงกำหนดชำระแล้ว', one: '{name} ครบกำหนดคืนวันนี้', many: '{name} และอีก {n} รายการ ครบกำหนดวันนี้' },
  en: { title: '🔔 Loan due', one: '{name} is due today', many: '{name} and {n} more are due today' },
  zh: { title: '🔔 借款到期', one: '{name} 今天到期', many: '{name} 等 {n} 笔今天到期' },
}

const vientianeToday = () => {
  // en-CA ให้รูปแบบ YYYY-MM-DD ตรงกับชนิด date ของ Postgres พอดี
  return new Intl.DateTimeFormat('en-CA', { timeZone: 'Asia/Vientiane' }).format(new Date())
}

Deno.serve(async (req) => {
  // กันคนนอกยิง: ต้องมาพร้อม service-role key (pg_cron ส่งให้ผ่าน header)
  const auth = req.headers.get('authorization') || ''
  if (!auth.includes(SERVICE_ROLE)) {
    return new Response(JSON.stringify({ error: 'forbidden' }), { status: 403, headers: { 'content-type': 'application/json' } })
  }

  const today = vientianeToday()
  const { data: due, error } = await admin
    .from('loans')
    .select('user_id, friend_name, due_date')
    .eq('status', 'active')
    .eq('due_date', today)

  if (error) {
    return new Response(JSON.stringify({ error: error.message }), { status: 500, headers: { 'content-type': 'application/json' } })
  }
  if (!due || !due.length) {
    return new Response(JSON.stringify({ today, due: 0, sent: 0 }), { headers: { 'content-type': 'application/json' } })
  }

  // รวมเป็นรายผู้ใช้ — คนหนึ่งอาจมีหลายใบครบกำหนดวันเดียวกัน ต้องส่งครั้งเดียว ไม่ใช่ยิงรัว
  const byUser = new Map<string, string[]>()
  for (const r of due) {
    if (!r.user_id) continue
    const arr = byUser.get(r.user_id) || []
    arr.push(r.friend_name || '')
    byUser.set(r.user_id, arr)
  }

  const userIds = [...byUser.keys()]
  const { data: subs } = await admin.from('push_subscriptions').select('user_id, endpoint, p256dh, auth').in('user_id', userIds)
  const { data: langs } = await admin.from('user_settings').select('user_id, lang').in('user_id', userIds)
  const langOf = new Map((langs || []).map((r: any) => [r.user_id, r.lang || 'lo']))

  let sent = 0, gone = 0, failed = 0
  const dead: string[] = []

  for (const s of subs || []) {
    const names = byUser.get(s.user_id) || []
    if (!names.length) continue
    const t = T[langOf.get(s.user_id) || 'lo'] || T.lo
    const body = names.length > 1
      ? t.many.replace('{name}', names[0]).replace('{n}', String(names.length - 1))
      : t.one.replace('{name}', names[0])
    try {
      await webpush.sendNotification(
        { endpoint: s.endpoint, keys: { p256dh: s.p256dh, auth: s.auth } },
        // tag คงที่ต่อวัน ⇒ ถ้าเผลอยิงซ้ำ ระบบจะทับอันเดิมแทนที่จะกองซ้อนกันบนแถบ
        JSON.stringify({ title: t.title, body, tag: 'loan-due-' + today, url: '.' }),
      )
      sent++
    } catch (e: any) {
      const code = e && (e.statusCode || e.status)
      // 404/410 = subscription ตายแล้ว (ผู้ใช้ถอนแอป/ล้างข้อมูล) — เก็บกวาดทิ้ง ไม่งั้นสะสมไปเรื่อยๆ
      if (code === 404 || code === 410) { dead.push(s.endpoint); gone++ } else { failed++ }
    }
  }

  if (dead.length) { try { await admin.from('push_subscriptions').delete().in('endpoint', dead) } catch (_) {} }

  return new Response(JSON.stringify({ today, due: due.length, users: userIds.length, subs: (subs || []).length, sent, gone, failed }), {
    headers: { 'content-type': 'application/json' },
  })
})

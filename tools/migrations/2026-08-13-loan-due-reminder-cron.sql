-- v3.7.434 — งานเตือนกำหนดคืนเงินกู้รายวัน (Web Push สำหรับผู้ใช้ PWA)
-- 🔴 รันบน DB โปรดักชันแล้วเมื่อ 2026-08-13 — เก็บไว้เพื่อสร้างใหม่ได้ถ้าต้องย้ายเครื่อง
--
-- ทำไมต้องมี: LocalNotifications ตั้งปลุกได้เฉพาะแอปเนทีฟ ผู้ใช้ PWA (รวม iOS ทุกคนตอนนี้)
-- ไม่มีปลั๊กอิน ⇒ ช่องทางเดียวที่ถึงตอนแอปปิดคือ Web Push จากเซิร์ฟเวอร์
--
-- ข้อสังเกตที่วัดมาแล้ว:
--   * pg_cron อยู่ใน shared_preload_libraries อยู่แล้ว ⇒ create extension ได้โดยไม่ต้องรีสตาร์ต Postgres
--   * pg_net ติดตั้งไว้แล้ว (schema net)
--   * timezone ของเซิร์ฟเวอร์เป็น UTC ⇒ 09:00 Asia/Vientiane = 02:00 UTC
--   * ทดสอบ cron ด้วยงานทุกนาทีแล้วเห็น status=succeeded จริงก่อนตั้งงานจริง

create extension if not exists pg_cron;

-- แทนที่ <SERVICE_ROLE_KEY> ด้วยค่าจาก /docker/supabase/docker/.env (SERVICE_ROLE_KEY)
-- เก็บอยู่ในตาราง cron.job ซึ่งอ่านได้เฉพาะ superuser
select cron.schedule(
  'loan-due-daily',
  '0 2 * * *',                       -- 02:00 UTC = 09:00 เวียงจันทน์
  $$select net.http_post(
      url := 'http://kong:8000/functions/v1/send-loan-due',
      headers := jsonb_build_object('content-type','application/json','Authorization','Bearer <SERVICE_ROLE_KEY>'),
      body := '{}'::jsonb
  )$$
);

-- ตรวจว่าตั้งแล้ว:        select jobid, schedule, jobname, active from cron.job;
-- ดูผลการรันย้อนหลัง:     select jobid, status, return_message, start_time from cron.job_run_details order by start_time desc limit 10;
-- ดูผลตอบกลับ HTTP:       select id, status_code, content from net._http_response order by id desc limit 5;
-- ยกเลิกงาน:              select cron.unschedule('loan-due-daily');

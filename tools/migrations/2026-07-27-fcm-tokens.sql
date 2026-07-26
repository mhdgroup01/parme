-- 2026-07-27 — FCM device tokens (v3.7.420)
-- เจ้าของสั่ง: ให้แจ้งเตือนได้แม้ปิดแอป ⇒ ต้องใช้ push จริง (FCM) เพราะ
-- LocalNotifications (v3.7.419) เด้งได้เฉพาะตอนโปรเซสแอปยังมีชีวิต
--
-- ทำไมตารางใหม่ ไม่ใช้ push_subscriptions เดิม: ตารางนั้นเป็นรูปของ Web Push
-- (endpoint UNIQUE + p256dh/auth NOT NULL) ซึ่ง FCM token ไม่มีสองคอลัมน์หลัง
-- ยัดลงไปต้องใส่ค่าปลอม = ทำ schema เดิมเสียความหมาย
--
-- RLS: ลอกแบบเดียวกับ push_subscriptions เป๊ะ (เจ้าของแถวจัดการแถวตัวเองได้เท่านั้น)
-- edge function อ่านด้วย service role จึงข้าม RLS ได้ตามปกติ
--
-- apply: docker exec -i supabase-db psql -U postgres -d postgres < ไฟล์นี้ ; แล้ว NOTIFY pgrst

BEGIN;

CREATE TABLE IF NOT EXISTS public.fcm_tokens (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  shop_id    text NOT NULL DEFAULT ''::text,
  token      text NOT NULL UNIQUE,
  platform   text NOT NULL DEFAULT 'android',
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS fcm_tokens_shop_idx ON public.fcm_tokens (shop_id);

ALTER TABLE public.fcm_tokens ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "fcm own select" ON public.fcm_tokens;
CREATE POLICY "fcm own select" ON public.fcm_tokens FOR SELECT USING (auth.uid() = user_id);
DROP POLICY IF EXISTS "fcm own insert" ON public.fcm_tokens;
CREATE POLICY "fcm own insert" ON public.fcm_tokens FOR INSERT WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS "fcm own update" ON public.fcm_tokens;
CREATE POLICY "fcm own update" ON public.fcm_tokens FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS "fcm own delete" ON public.fcm_tokens;
CREATE POLICY "fcm own delete" ON public.fcm_tokens FOR DELETE USING (auth.uid() = user_id);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.fcm_tokens TO authenticated;

COMMIT;

NOTIFY pgrst, 'reload schema';

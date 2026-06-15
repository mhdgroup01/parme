-- ============================================================
-- Paruay v3.7.42 — Cursor polling: เพิ่ม updated_at + trigger + index
-- 2026-06-16
--
-- ปัญหา: pollForUpdates ดึง transactions + ious **ทั้งหมดของ user** ทุก 9 วินาที
--   - ผู้ใช้ใช้แอปนานๆ ข้อมูลโต → poll หนักขึ้นเรื่อยๆ
--   - bandwidth + DB load สูงขึ้น linearly กับอายุ user
--
-- แก้: cursor polling — first poll = full (เหมือนเดิม), subsequent = delta
--   .gt('updated_at', lastCursor).limit(500)
-- ลด volume ของ poll หลัง first poll แรกเหลือเกือบ 0 KB (ยกเว้นมี update จริง)
-- ============================================================

-- ── transactions ────────────────────────────────────────────
ALTER TABLE public.transactions
  ADD COLUMN IF NOT EXISTS updated_at timestamptz;

UPDATE public.transactions
SET updated_at = COALESCE(created_at, now())
WHERE updated_at IS NULL;

ALTER TABLE public.transactions
  ALTER COLUMN updated_at SET DEFAULT now(),
  ALTER COLUMN updated_at SET NOT NULL;


-- ── ious ────────────────────────────────────────────────────
ALTER TABLE public.ious
  ADD COLUMN IF NOT EXISTS updated_at timestamptz;

UPDATE public.ious
SET updated_at = COALESCE(created_at, now())
WHERE updated_at IS NULL;

ALTER TABLE public.ious
  ALTER COLUMN updated_at SET DEFAULT now(),
  ALTER COLUMN updated_at SET NOT NULL;


-- ── Trigger function (ทั้ง 2 ตารางใช้ร่วมกัน) ───────────────
CREATE OR REPLACE FUNCTION public.tg_set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END
$$;


-- ── Apply trigger ───────────────────────────────────────────
DROP TRIGGER IF EXISTS transactions_set_updated_at ON public.transactions;
CREATE TRIGGER transactions_set_updated_at
  BEFORE UPDATE ON public.transactions
  FOR EACH ROW EXECUTE FUNCTION public.tg_set_updated_at();

DROP TRIGGER IF EXISTS ious_set_updated_at ON public.ious;
CREATE TRIGGER ious_set_updated_at
  BEFORE UPDATE ON public.ious
  FOR EACH ROW EXECUTE FUNCTION public.tg_set_updated_at();


-- ── Cursor indexes (composite สำหรับ poll: WHERE user_id=? AND updated_at>?) ───
CREATE INDEX IF NOT EXISTS transactions_user_updated_idx
  ON public.transactions (user_id, updated_at DESC);

CREATE INDEX IF NOT EXISTS ious_user_updated_idx
  ON public.ious (user_id, updated_at DESC);


-- ============================================================
-- ตรวจสอบ
-- ============================================================
-- 1) ดูว่า column updated_at อยู่ใน transactions/ious
SELECT table_name, column_name, data_type, column_default, is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name IN ('transactions', 'ious')
  AND column_name = 'updated_at';

-- 2) ดูว่า trigger ติดแล้ว
SELECT event_object_table, trigger_name, action_timing, event_manipulation
FROM information_schema.triggers
WHERE event_object_schema = 'public'
  AND event_object_table IN ('transactions', 'ious');

-- 3) ดูว่า index ใหม่ใช้งานได้ (EXPLAIN ANALYZE — เลือก user_id จริง)
-- EXPLAIN ANALYZE
-- SELECT id FROM transactions
-- WHERE user_id = '<your-user-uuid>'::uuid AND updated_at > now() - interval '1 hour';
-- ควรเห็น Index Scan using transactions_user_updated_idx

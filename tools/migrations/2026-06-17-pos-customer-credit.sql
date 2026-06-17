-- ============================================================
-- Paruay — POS customer credit (ลูกค้าเชื่อ / ค้างจ่าย)
-- 2026-06-17
--
-- เพิ่มความสามารถ "ลงเชื่อ" — ลูกค้าซื้อก่อน จ่ายทีหลัง (วัฒนธรรมร้านลาว/ไทย)
--
-- ดีไซน์ (มินิมอล — ไม่สร้างตารางใหม่, reuse pos_sales):
--   • paid       = true ปกติ (จ่ายแล้ว) / false = บิลเชื่อ (ค้างจ่าย)
--   • customer   = ชื่อลูกค้า (เฉพาะบิลเชื่อ)
--   • settled_at = เวลาที่ลูกค้ามารับเงิน/เคลียร์ยอด
--
-- ยอดขาย/กำไรในรายงานไม่เปลี่ยน (บิลเชื่อนับเป็นยอดขายตั้งแต่วันขาย).
-- "ยังเก็บไม่ได้" = SUM(total) WHERE paid = false
-- แถวเก่าทั้งหมด → paid = true (default) = ถือว่าเก็บเงินแล้ว ✓ (ถูกต้อง)
-- ============================================================

ALTER TABLE public.pos_sales
  ADD COLUMN IF NOT EXISTS paid       boolean NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS customer   text,
  ADD COLUMN IF NOT EXISTS settled_at timestamptz;

-- index สำหรับ query "ใครค้างเท่าไหร่" (เฉพาะบิลที่ยังไม่จ่าย — partial index เล็ก)
CREATE INDEX IF NOT EXISTS idx_pos_sales_unpaid
  ON public.pos_sales (shop, customer)
  WHERE paid = false;

-- ============================================================
-- ทดสอบหลังรัน:
--   SELECT customer, SUM(total) AS owes
--   FROM pos_sales WHERE paid = false GROUP BY customer ORDER BY owes DESC;
-- (ควรว่างเปล่าตอนนี้ เพราะยังไม่มีบิลเชื่อ — แถวเก่า paid = true หมด)
-- ============================================================

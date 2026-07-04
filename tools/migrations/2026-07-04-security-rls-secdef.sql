-- ============================================================================
-- Security fixes 2026-07-04 (applied to VPS self-host Supabase; rollback below)
-- พบจาก adversarial security audit (workflow 5-มิติ + skeptic verify) แล้ว
-- reproduce/verify exploit บน prod จริงก่อน+หลังแก้ (test harness ใน scratchpad)
-- ============================================================================

-- 🔴 CRITICAL: family_members fm_ins policy เช็คแค่ user_id=auth.uid() ไม่เช็ค family_id
--    → ใครล็อกอินก็ INSERT ตัวเองเข้าครอบครัวไหนก็ได้ (ไม่ต้องมี invite code)
--    → อ่าน/แก้/ลบเงินทั้งครอบครัวคนอื่น (ft/fi/ff/fam_msg/family_pos_* ทั้งหมด gate ด้วย is_family_full/is_family_member)
--    client เข้าครอบครัวผ่าน create_family/join_family RPC (SECURITY DEFINER = insert ข้าม RLS) เท่านั้น → drop policy ปลอดภัย
--    VERIFY: หลัง drop, direct insert = 403 RLS ทั้ง 3 รูปแบบ; create_family/join_family ยัง 200; tx insert (own) ยัง 201
DROP POLICY fm_ins ON public.family_members;
-- rollback: CREATE POLICY fm_ins ON public.family_members FOR INSERT TO public WITH CHECK (user_id = auth.uid());

-- 🟠 HIGH: family_transactions ft_upd ไม่มี WITH CHECK → Postgres reuse USING (มี user_id=auth.uid())
--    → ย้าย tx ตัวเองเข้า family_id ครอบครัวคนอื่น = ทำยอดครอบครัวเหยื่อเพี้ยน (ไม่ต้องเป็นสมาชิก)
ALTER POLICY ft_upd ON public.family_transactions WITH CHECK (is_family_full(family_id, auth.uid()));
-- rollback: ALTER POLICY ... ต้องลบ with_check (recreate policy จาก def เดิม)

-- 🟡 MEDIUM: set_family_currency / set_family_goals(4-arg,5-arg) ใช้ is_family_member (หรือ inline owner-OR-member)
--    → POS-only seller (is_family_full=false) เปลี่ยนสกุลเงิน/เป้าการเงินครอบครัวได้ → เปลี่ยนเป็น is_family_full
--    (ดู body ใหม่ที่ apply แล้วใน /docker/sec-func-fixes.sql บน VPS; 3-arg set_family_goals ถูกต้องอยู่แล้ว)

-- 🟡 MEDIUM: pos_sales_totals today_rev ใช้ (created_at)::date = current_date (UTC)
--    → today revenue เพี้ยนสำหรับร้านเปิดหลังเที่ยงคืน (client ใช้ local UTC+7) → เปลี่ยนเป็น AT TIME ZONE 'Asia/Bangkok'
--    (bucket อื่นในฟังก์ชันเดียวกันใช้ Asia/Bangkok อยู่แล้ว — ตัวนี้ตกหล่น)

-- NOTE: หลัง CREATE OR REPLACE function ต้อง NOTIFY pgrst, 'reload schema';

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

-- ============================================================================
-- v3.7.254 — pos_products/pos_categories anon cost/recipe leak (medium)
-- qr_anon_read_* policy USING(true) roles {anon,authenticated} → ใครก็อ่าน cost/cost_layers/recipe ทุกร้าน
-- fix: ทำ RPC qr_menu (คืนเฉพาะคอลัมน์ปลอดภัย) + client QR menu ใช้ RPC + DROP broad policy
-- เจ้าของอ่านร้านตัวเองผ่าน pos_products_all/pos_categories_all (authenticated, shop-scoped) — ไม่กระทบ
-- VERIFY: anon อ่าน cost ตรง=[]; qr_menu RPC ได้เมนูไม่มี cost; owner read own shop ปกติ
-- ============================================================================
CREATE OR REPLACE FUNCTION public.qr_menu(p_shop uuid)
RETURNS json LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public'
AS $function$
  SELECT json_build_object(
    'products', COALESCE((SELECT json_agg(p) FROM (
        SELECT id, shop, name, price, stock, emoji, photo, category_id, station, sort, unit, stock_type
        FROM pos_products WHERE shop = p_shop) p), '[]'::json),
    'categories', COALESCE((SELECT json_agg(c) FROM (
        SELECT id, shop, name, emoji, station, default_unit
        FROM pos_categories WHERE shop = p_shop) c), '[]'::json)
  );
$function$;
GRANT EXECUTE ON FUNCTION public.qr_menu(uuid) TO anon, authenticated;
DROP POLICY qr_anon_read_products ON public.pos_products;
DROP POLICY qr_anon_read_categories ON public.pos_categories;
-- rollback: ดู /docker/backups/rollback-security-20260704.sql

-- ============================================================================
-- v3.7.256 — ปิด get_email_by_username PII leak สมบูรณ์ (phase 2)
-- Edge Function login-username (service role) เป็น path เดียว → REVOKE จาก anon/authenticated
-- VERIFY: anon เรียก = 403 permission denied; edge fn ยัง resolve (service_role) = login ทำงาน
-- ============================================================================
REVOKE EXECUTE ON FUNCTION public.get_email_by_username(text) FROM anon, authenticated, public;
GRANT EXECUTE ON FUNCTION public.get_email_by_username(text) TO service_role;
-- rollback: GRANT EXECUTE ON FUNCTION public.get_email_by_username(text) TO anon, authenticated;

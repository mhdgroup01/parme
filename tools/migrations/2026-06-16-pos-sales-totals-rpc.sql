-- ============================================================
-- Paruay v3.7.40 — POS sales totals RPC (correctness fix)
-- 2026-06-16
--
-- ปัญหา: client โหลด pos_sales ด้วย .limit(500) แล้ว reduce เอง
-- → ร้านที่ขายเกิน 500 บิล จะเห็นยอดรวม/ต้นทุนรวมผิด *เงียบๆ*
--
-- แก้: คำนวณ server-side ครอบทุกบิล (พร้อม membership check)
-- ============================================================

CREATE OR REPLACE FUNCTION public.pos_sales_totals(p_shop uuid)
RETURNS TABLE(
  total_rev numeric,
  total_cost numeric,
  today_rev numeric,
  sale_count int
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    COALESCE(SUM(total), 0)::numeric,
    COALESCE(SUM(cost_total), 0)::numeric,
    COALESCE(
      SUM(total) FILTER (
        WHERE (created_at AT TIME ZONE 'Asia/Bangkok')::date = (now() AT TIME ZONE 'Asia/Bangkok')::date
      ), 0
    )::numeric,
    COUNT(*)::int
  FROM pos_sales
  WHERE shop = p_shop
    AND (
      -- เจ้าของร้าน
      EXISTS (SELECT 1 FROM pos_shops WHERE id = p_shop AND owner = auth.uid())
      OR
      -- สมาชิกร้าน
      EXISTS (SELECT 1 FROM pos_members WHERE shop = p_shop AND member = auth.uid())
    );
$$;

-- Permissions
REVOKE ALL ON FUNCTION public.pos_sales_totals(uuid) FROM public;
GRANT EXECUTE ON FUNCTION public.pos_sales_totals(uuid) TO authenticated;

-- ============================================================
-- ทดสอบ (ใช้ shop id จริงของคุณ)
-- ============================================================
-- SELECT * FROM pos_sales_totals('<shop-uuid-here>'::uuid);
--
-- ต้องคืนค่า:
--   total_rev | total_cost | today_rev | sale_count
--   ----------+------------+-----------+------------
--    12345    |   6789     |   500     |    742

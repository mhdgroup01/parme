-- ============================================================
-- Paruay — POS sales totals RPC: timezone fix (UTC)
-- 2026-06-16
--
-- ปัญหา (bug LOW จาก bug-hunter 2026-06-16-0205):
-- RPC คำนวณ today_rev ด้วย Asia/Bangkok แต่ client (mapSale.date + todayStr)
-- ใช้ UTC → ช่วงเที่ยงคืน-เช้า ยอด today_rev ฝั่ง server กับ client ไม่ตรงกัน
--
-- แก้: today_rev ใช้ (created_at)::date = current_date (UTC)
-- ให้ตรงกับ client. interface เดิมไม่เปลี่ยน → ไม่ต้องแก้ index.html
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
        WHERE (created_at)::date = current_date
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

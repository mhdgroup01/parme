-- v3.7.457 — ประวัติฝั่งลูกค้าต้องตัดจาก "การขายล่าสุดของโต๊ะ" ไม่ใช่รอให้แอปแจ้ง
-- (เจ้าของ: "ยังไม่หาย ธุรกรรมสำเร็จแล้ว แต่ประวัติการสั่งรอบก่อนยังอยู่")
--
-- ── ทำไม v3.7.456 ไม่พอ ────────────────────────────────────────────────────
-- v3.7.456 ให้ "แอป POS เรียก set_table_cleared() ตอนเช็คบิล" ซึ่งพึ่งเงื่อนไขเปราะหลายชั้น:
--   1. เครื่องนั้นต้องโหลดโค้ดใหม่แล้ว — แต่ sw.js เป็น **cache-first** ⇒ เครื่องที่เปิดแอปค้างไว้
--      ยังรันของเก่าอีกนาน (ตรวจ log จริง: set_table_cleared ถูกเรียก **0 ครั้ง** ทั้งที่มีการขายจริง)
--   2. ต้องออนไลน์ตอนกด · 3. ทุกเส้นทางปิดบิลต้องเรียกครบ · 4. ร้านหลายเครื่องต้องอัปเดตครบทุกเครื่อง
--
-- 🔴 บทเรียน: ข้อมูลที่ "จริงอยู่แล้วในฐานข้อมูล" ไม่ควรรอให้ไคลเอนต์มาบอก
--    `pos_sales` บันทึกอยู่แล้วว่าโต๊ะไหนเช็คบิลเมื่อไหร่ ⇒ อ่านตรงจากตรงนั้น
--    ⇒ ทำงานย้อนหลังทันที ไม่ต้องรอเครื่องอัปเดต ไม่ต้องแก้แอปเลย
--
-- คงการอ่าน table_cleared ไว้ด้วย แล้วเอา "อันที่ใหม่กว่า" — เผื่อกรณีที่ปิดบิลโดยไม่เกิดการขาย
-- (ยกเลิกบิล / ย้ายโต๊ะ / รวมโต๊ะ) ซึ่งไม่มีแถวใน pos_sales ให้อ้างอิง
CREATE OR REPLACE FUNCTION public.qr_get_orders(p_shop text, p_table text, p_token text)
RETURNS SETOF pos_qr_orders
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  WITH cut AS (
    SELECT GREATEST(
      -- เวลาเช็คบิลล่าสุดของโต๊ะนี้ (แหล่งความจริงหลัก — ไม่ต้องพึ่งแอป)
      (SELECT max(sa.created_at) FROM pos_sales sa
        WHERE sa.shop = p_shop::uuid AND sa.table_no::text = p_table),
      -- เวลาที่แอปแจ้งว่าเคลียร์โต๊ะ (เสริม: ยกเลิกบิล/ย้ายโต๊ะ/รวมโต๊ะ ซึ่งไม่มีการขาย)
      (SELECT (s.table_cleared ->> p_table)::timestamptz FROM pos_shops s WHERE s.id = p_shop::uuid)
    ) AS at
  )
  SELECT o.*
  FROM public.pos_qr_orders o, cut
  WHERE o.shop = p_shop
    AND o.table_no::text = p_table
    AND p_token <> '' AND o.token = p_token
    AND (cut.at IS NULL OR o.created_at > cut.at)
  ORDER BY o.created_at DESC
  LIMIT 50
$$;

NOTIFY pgrst, 'reload schema';

-- ── ตรวจย้อนหลัง ───────────────────────────────────────────────────────────
--  จุดตัดของแต่ละโต๊ะ:
--    select table_no, max(created_at) from pos_sales where shop='<uuid>' group by 1;
--  ลูกค้าโต๊ะ 1 เห็นอะไรตอนนี้:
--    select id, created_at from qr_get_orders('<shop>', '1', '<token>');

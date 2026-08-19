-- v3.7.460 — คำอธิบายสินค้า + ให้ลูกค้ากดดูได้
-- (เจ้าของ: "ในการกรอกข้อมูลสินค้าทุกครั้ง ให้มีระบบอธิบายสินค้าของเราด้วย
--  แล้วสามารถกดดูที่ปุ่มเล็ก ๆ ได้อยู่หน้าซื้อของลูกค้า")
--
-- ⚠️ ตั้งชื่อคอลัมน์ `descr` ไม่ใช่ `desc` — `desc` เป็นคำสงวนของ SQL (ORDER BY ... DESC)
--    ใช้เป็นชื่อคอลัมน์ได้ก็ต่อเมื่อใส่ double quote ทุกครั้ง ซึ่งพลาดง่ายมาก
ALTER TABLE public.pos_products
  ADD COLUMN IF NOT EXISTS descr text NOT NULL DEFAULT '' CHECK (length(descr) <= 500);

-- หน้าลูกค้าอ่านเมนูผ่าน qr_menu (คืนเฉพาะคอลัมน์ปลอดภัย ไม่รั่ว cost/recipe)
-- ⇒ ต้องเติม descr เข้าไปด้วย ไม่งั้นลูกค้าไม่มีทางเห็นคำอธิบาย
CREATE OR REPLACE FUNCTION public.qr_menu(p_shop uuid)
RETURNS json
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $function$
  SELECT json_build_object(
    'products', COALESCE((SELECT json_agg(p) FROM (
        SELECT id, shop, name, price, stock, emoji, photo, category_id, station, sort, unit, stock_type, var_group, var_word, descr
        FROM pos_products WHERE shop = p_shop) p), '[]'::json),
    'categories', COALESCE((SELECT json_agg(c) FROM (
        SELECT id, shop, name, emoji, station, default_unit
        FROM pos_categories WHERE shop = p_shop) c), '[]'::json)
  );
$function$;

NOTIFY pgrst, 'reload schema';

-- ── ตรวจย้อนหลัง ───────────────────────────────────────────────────────────
--  สินค้าที่มีคำอธิบายแล้ว:
--    select name, left(descr,40) from pos_products where descr <> '';
--  ลูกค้าได้ descr ไหม:
--    select (qr_menu('<shop>'::uuid)->'products'->0) ? 'descr';

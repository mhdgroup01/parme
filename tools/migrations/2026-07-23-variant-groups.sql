-- v3.7.392 — variant groups (ตั้งชื่อแบบเองได้): 2 คอลัมน์ + qr_menu คืนค่าเพิ่ม
-- additive ล้วน (nullable) — สินค้าเดิมไม่กระทบ
ALTER TABLE public.pos_products ADD COLUMN IF NOT EXISTS var_group text;
ALTER TABLE public.pos_products ADD COLUMN IF NOT EXISTS var_word  text;

-- qr_menu: เพิ่ม var_group, var_word ในชุดคอลัมน์สินค้า (ไม่ sensitive — แค่ id จับกลุ่ม)
CREATE OR REPLACE FUNCTION public.qr_menu(p_shop uuid)
 RETURNS json
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT json_build_object(
    'products', COALESCE((SELECT json_agg(p) FROM (
        SELECT id, shop, name, price, stock, emoji, photo, category_id, station, sort, unit, stock_type, var_group, var_word
        FROM pos_products WHERE shop = p_shop) p), '[]'::json),
    'categories', COALESCE((SELECT json_agg(c) FROM (
        SELECT id, shop, name, emoji, station, default_unit
        FROM pos_categories WHERE shop = p_shop) c), '[]'::json)
  );
$function$;

NOTIFY pgrst, 'reload schema';

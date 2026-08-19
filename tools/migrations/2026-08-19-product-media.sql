-- v3.7.461 — คำอธิบายสินค้าใส่ "รูปหลายใบ + ลิงก์วิดีโอ" ได้ (เจ้าของ: "ให้ทำให้ใส่รูปภาพได้ด้วย
-- และใส่ลิงก์วิดีโอได้ด้วย ลูกค้า กดวิดีโอเปิดดูอยู่ในแอปได้เลย")
--
-- ── ทำไมรูปต้องขึ้น Storage ไม่ใช่ base64 ในคอลัมน์ (วัดจริงก่อนตัดสิน) ──────────────
-- รูปสินค้าเดิม (`photo`) เก็บเป็น data URL ⇒ payload ของ qr_menu ที่ลูกค้าโหลดตอนสแกน QR
-- วัดจริงบน prod: ร้าน 8 สินค้า = **238,528 ไบต์** และเซิร์ฟเวอร์ **ไม่ได้บีบอัด** response นี้เลย
-- (ส่ง Accept-Encoding: gzip แล้ว content-length เท่าเดิม ไม่มี content-encoding)
-- ถ้าคำอธิบายใส่รูปได้อีก 6 ใบแบบ base64 (ใบละได้ถึง ~180KB ตาม CAP ใน compressImage)
-- เมนูร้านเดียวจะแตะหลักเมกะไบต์ ⇒ ลูกค้าบนเน็ต 4G ลาวเปิดเมนูไม่ขึ้น
-- ⇒ เก็บ **path** (≈50 ไบต์/ใบ) แล้วให้เบราว์เซอร์โหลดรูปแยกเป็นไฟล์ (แคชได้ + โหลดขนานได้)

-- ══════════════════════════════════════════════════════════════════════════
-- 1. คอลัมน์
-- ══════════════════════════════════════════════════════════════════════════
-- ⚠️ ตั้งชื่อขึ้นต้น descr_ ให้รู้ว่าเป็นของ "คำอธิบาย" ไม่ใช่รูปหลักของสินค้า (`photo` คนละอัน)
ALTER TABLE public.pos_products
  ADD COLUMN IF NOT EXISTS descr_imgs  text[] NOT NULL DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS descr_video text   NOT NULL DEFAULT '';

-- path ต้องเป็น '<shop uuid>/<ชื่อสุ่ม>.<นามสกุลรูป>' เท่านั้น — กันคนยัด URL เต็มหรือ ../
-- (แบบเดียวกับ svc_images_ok ที่ใช้กับกระดาน ຮັບເຮັດ อยู่แล้ว)
CREATE OR REPLACE FUNCTION public.pos_media_ok(p text[])
RETURNS boolean LANGUAGE sql IMMUTABLE AS $$
  SELECT p IS NULL
      OR (coalesce(array_length(p, 1), 0) <= 6
          AND coalesce(array_length(p, 1), 0) = (
            SELECT count(*) FROM unnest(p) u
            WHERE u ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/[A-Za-z0-9_-]{1,60}\.(webp|jpg|png)$'
          ));
$$;

ALTER TABLE public.pos_products DROP CONSTRAINT IF EXISTS pos_products_descr_imgs_check;
ALTER TABLE public.pos_products ADD CONSTRAINT pos_products_descr_imgs_check
  CHECK (public.pos_media_ok(descr_imgs));

-- ลิงก์วิดีโอเก็บ "ตามที่ร้านวาง" แล้วไปแกะ/ประกอบ embed URL ใหม่ที่ฝั่งแอป
-- (แกะที่ฝั่งแอปเพราะรูปแบบลิงก์ของ YouTube/TikTok/Facebook เปลี่ยนบ่อยกว่าที่ DB จะตามทัน)
-- 🔴 DB จำกัดแค่ความยาว — **ตัวกันช่องโหว่จริงคือ parseVideo() ฝั่งแอป** ที่รับเฉพาะโดเมนใน allowlist
--    ดึงเฉพาะ id ออกมา แล้วประกอบ URL ขึ้นใหม่ (ไม่เคยส่ง URL ดิบเข้า iframe.src)
ALTER TABLE public.pos_products DROP CONSTRAINT IF EXISTS pos_products_descr_video_check;
ALTER TABLE public.pos_products ADD CONSTRAINT pos_products_descr_video_check
  CHECK (length(descr_video) <= 300);

-- ══════════════════════════════════════════════════════════════════════════
-- 2. bucket `pos` — รูปคำอธิบายสินค้า
-- ══════════════════════════════════════════════════════════════════════════
-- ทำไมไม่ใช้ bucket เดิม:
--   • `svc` ผูกโฟลเดอร์กับ **uid ของผู้ใช้** ⇒ ลูกจ้างที่ช่วยลงสินค้า อัปรูปแล้วเจ้าของร้านลบไม่ได้
--   • `vmoto` สโคปต่อร้านถูกแล้ว แต่เป็นบักเก็ตของหน้าขาย VMOTO คนละงานกัน
-- ที่นี่โฟลเดอร์ = **id ร้าน** ⇒ ใครก็ตามที่เป็น owner/สมาชิกของร้านนั้นจัดการรูปของร้านได้ ตรงกับความเป็นจริง
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('pos', 'pos', true, 2097152, '{image/jpeg,image/png,image/webp}')
ON CONFLICT (id) DO UPDATE
  SET public = true, file_size_limit = 2097152,
      allowed_mime_types = '{image/jpeg,image/png,image/webp}';

DROP POLICY IF EXISTS pos_obj_read   ON storage.objects;
DROP POLICY IF EXISTS pos_obj_write  ON storage.objects;
DROP POLICY IF EXISTS pos_obj_update ON storage.objects;
DROP POLICY IF EXISTS pos_obj_del    ON storage.objects;

-- 🔴 **ไม่มี policy SELECT ให้ anon โดยตั้งใจ** — bucket public อ่านผ่าน /object/public/... ได้อยู่แล้ว
--    โดยไม่ผ่าน RLS ⇒ ลูกค้าเห็นรูปได้ตามปกติ แต่ **ไล่ลิสต์ไฟล์ทั้งบักเก็ตไม่ได้**
--    (ต่างจาก `vmoto` ที่ anon ยิง /object/list/vmoto แล้วได้รายชื่อโฟลเดอร์ = id ทุกร้าน)
--    ให้เฉพาะคนของร้านอ่านผ่าน API ได้ เพื่อให้หน้าจัดการสินค้าลิสต์รูปตัวเองได้ถ้าต้องใช้
CREATE POLICY pos_obj_read ON storage.objects FOR SELECT TO authenticated
  USING (bucket_id = 'pos' AND (storage.foldername(name))[1] IN (
           SELECT id::text FROM public.pos_shops   WHERE owner  = auth.uid()
           UNION
           SELECT shop::text FROM public.pos_members WHERE member = auth.uid()));

-- เทียบเป็น text กับ subquery (ไม่ cast โฟลเดอร์เป็น uuid) — โฟลเดอร์ที่ไม่ใช่ uuid จะได้ false
-- ไม่ใช่ error ระหว่างประเมิน policy · เป็นสำนวนเดียวกับ vmoto_obj_write ที่ใช้งานจริงอยู่แล้ว
CREATE POLICY pos_obj_write ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'pos' AND (storage.foldername(name))[1] IN (
                SELECT id::text FROM public.pos_shops   WHERE owner  = auth.uid()
                UNION
                SELECT shop::text FROM public.pos_members WHERE member = auth.uid()));

CREATE POLICY pos_obj_update ON storage.objects FOR UPDATE TO authenticated
  USING      (bucket_id = 'pos' AND (storage.foldername(name))[1] IN (
                SELECT id::text FROM public.pos_shops   WHERE owner  = auth.uid()
                UNION
                SELECT shop::text FROM public.pos_members WHERE member = auth.uid()))
  WITH CHECK (bucket_id = 'pos' AND (storage.foldername(name))[1] IN (
                SELECT id::text FROM public.pos_shops   WHERE owner  = auth.uid()
                UNION
                SELECT shop::text FROM public.pos_members WHERE member = auth.uid()));

CREATE POLICY pos_obj_del ON storage.objects FOR DELETE TO authenticated
  USING (bucket_id = 'pos' AND (storage.foldername(name))[1] IN (
           SELECT id::text FROM public.pos_shops   WHERE owner  = auth.uid()
           UNION
           SELECT shop::text FROM public.pos_members WHERE member = auth.uid()));

-- ══════════════════════════════════════════════════════════════════════════
-- 3. qr_menu — ลูกค้า anon อ่าน pos_products ตรงไม่ได้ (RLS ให้เฉพาะ owner/member)
--    ⇒ **เพิ่มคอลัมน์เฉยๆ ลูกค้าไม่เห็น** ต้องเติมในลิสต์ของ RPC ทุกครั้ง
-- ══════════════════════════════════════════════════════════════════════════
-- RETURNS json ⇒ CREATE OR REPLACE เปลี่ยนคอลัมน์ข้างในได้ ไม่ชน 42P13
-- (ต่างจาก qr_shop_public ที่เป็น RETURNS TABLE — อันนั้นต้อง DROP ก่อน)
CREATE OR REPLACE FUNCTION public.qr_menu(p_shop uuid)
RETURNS json LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $function$
  SELECT json_build_object(
    'products', COALESCE((SELECT json_agg(p) FROM (
        SELECT id, shop, name, price, stock, emoji, photo, category_id, station, sort,
               unit, stock_type, var_group, var_word, descr, descr_imgs, descr_video
        FROM pos_products WHERE shop = p_shop) p), '[]'::json),
    'categories', COALESCE((SELECT json_agg(c) FROM (
        SELECT id, shop, name, emoji, station, default_unit
        FROM pos_categories WHERE shop = p_shop) c), '[]'::json)
  );
$function$;

NOTIFY pgrst, 'reload schema';

-- ── ตรวจย้อนหลัง ───────────────────────────────────────────────────────────
--  ต้อง false ทั้งหมด:
--    select pos_media_ok(array['https://evil.example/x.png']),
--           pos_media_ok(array['../secret.png']),
--           pos_media_ok(array['00000000-0000-0000-0000-000000000000/a.svg']),
--           pos_media_ok(array['00000000-0000-0000-0000-000000000000/a.webp','00000000-0000-0000-0000-000000000000/b.webp','00000000-0000-0000-0000-000000000000/c.webp','00000000-0000-0000-0000-000000000000/d.webp','00000000-0000-0000-0000-000000000000/e.webp','00000000-0000-0000-0000-000000000000/f.webp','00000000-0000-0000-0000-000000000000/g.webp']);
--  ต้อง true:
--    select pos_media_ok('{}'), pos_media_ok(array['00000000-0000-0000-0000-000000000000/a.webp']);
--  ลูกค้าได้ฟิลด์ใหม่จริง:
--    select (qr_menu('<shop>'::uuid)::jsonb->'products'->0) ?& array['descr_imgs','descr_video'];
--  anon ไล่ลิสต์บักเก็ต pos ไม่ได้ (ต้องได้ [] หรือ error) แต่โหลดรูปผ่าน /object/public/pos/... ได้ 200

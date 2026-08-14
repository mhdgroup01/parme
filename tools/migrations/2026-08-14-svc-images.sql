-- v3.7.441 — ຮັບເຮັດ: แนบรูปในประกาศได้ (เจ้าของ: "ทำให้ใส่รูปภาพได้ด้วย")
--
-- ── ทำไมไม่เก็บ base64 ใน DB (แบบสลิป/รูปสินค้าในแอปนี้) ──────────────────
-- กระดานนี้เป็น feed สาธารณะ: `select * ... limit 200` ⇒ ถ้ารูปฝังในแถว
-- ทุกคนที่เปิดบอร์ดจะดาวน์โหลดรูปของทุกประกาศพร้อมกัน (200 × ~130KB ≈ 26MB)
-- ⇒ ใช้ Storage แล้วให้เบราว์เซอร์โหลดรูปทีละใบตามที่เห็นจริง (แพทเทิร์นเดียวกับ bucket `vmoto`)
--
-- ── ทำไมเก็บ "path" ไม่ใช่ URL เต็ม (ต่างจาก vmoto) ───────────────────────
-- คอลัมน์นี้ผู้ใช้เขียนเองผ่าน REST ได้ ⇒ ถ้ารับ URL เต็ม ใครก็ยัด URL ภายนอกได้
-- แล้วเบราว์เซอร์ของ "ทุกคนที่เปิดบอร์ด" จะยิงไปเว็บนั้น (เนื้อหาที่ควบคุมไม่ได้ + เก็บ IP คนดูได้)
-- เก็บเป็น path แล้วประกอบ URL ฝั่งแอป ⇒ ปิดสนิทด้วย CHECK และย้ายโดเมนได้ในอนาคต

-- ── 1. คอลัมน์ ────────────────────────────────────────────────────────────
ALTER TABLE public.svc_posts
  ADD COLUMN IF NOT EXISTS images text[] NOT NULL DEFAULT '{}';

-- path ต้องเป็น '<uuid ของเจ้าของ>/<ชื่อไฟล์>' เท่านั้น — ห้าม '..' ห้าม scheme ห้ามช่องว่าง
-- (ใช้ฟังก์ชัน IMMUTABLE เพราะ CHECK เขียน subquery ตรงๆ ไม่ได้)
CREATE OR REPLACE FUNCTION public.svc_images_ok(p text[])
RETURNS boolean LANGUAGE sql IMMUTABLE AS $$
  SELECT p IS NULL
      OR (coalesce(array_length(p, 1), 0) <= 4
          AND coalesce(array_length(p, 1), 0) = (
            SELECT count(*) FROM unnest(p) u
            WHERE u ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/[A-Za-z0-9_-]{1,60}\.(webp|jpg|png)$'
          ));
$$;

ALTER TABLE public.svc_posts DROP CONSTRAINT IF EXISTS svc_posts_images_check;
ALTER TABLE public.svc_posts ADD CONSTRAINT svc_posts_images_check CHECK (public.svc_images_ok(images));

-- ── 2. bucket ─────────────────────────────────────────────────────────────
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('svc', 'svc', true, 2097152, '{image/jpeg,image/png,image/webp}')
ON CONFLICT (id) DO UPDATE
  SET public = true, file_size_limit = 2097152,
      allowed_mime_types = '{image/jpeg,image/png,image/webp}';

-- ── 3. สิทธิ์ไฟล์ ──────────────────────────────────────────────────────────
-- 🔴 รัดกุมกว่า policy ของ bucket `vmoto` โดยตั้งใจ: ที่นั่น authenticated เขียน/ลบไฟล์ไหนก็ได้
--    ในบักเก็ต ⇒ ผู้ใช้คนหนึ่งลบรูปของอีกคนได้ ที่นี่ผูกกับโฟลเดอร์ = uid ของตัวเองเท่านั้น
DROP POLICY IF EXISTS svc_obj_read   ON storage.objects;
DROP POLICY IF EXISTS svc_obj_write  ON storage.objects;
DROP POLICY IF EXISTS svc_obj_update ON storage.objects;
DROP POLICY IF EXISTS svc_obj_del    ON storage.objects;

CREATE POLICY svc_obj_read ON storage.objects FOR SELECT TO public
  USING (bucket_id = 'svc');
CREATE POLICY svc_obj_write ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'svc' AND (storage.foldername(name))[1] = auth.uid()::text);
CREATE POLICY svc_obj_update ON storage.objects FOR UPDATE TO authenticated
  USING (bucket_id = 'svc' AND (storage.foldername(name))[1] = auth.uid()::text)
  WITH CHECK (bucket_id = 'svc' AND (storage.foldername(name))[1] = auth.uid()::text);
CREATE POLICY svc_obj_del ON storage.objects FOR DELETE TO authenticated
  USING (bucket_id = 'svc' AND (storage.foldername(name))[1] = auth.uid()::text);

NOTIFY pgrst, 'reload schema';

-- ── ตรวจย้อนหลัง ───────────────────────────────────────────────────────────
--  ต้อง false ทั้งหมด (path นอกรูปแบบต้องถูกปฏิเสธ):
--    select svc_images_ok(array['https://evil.example/x.png']),
--           svc_images_ok(array['../secret.png']),
--           svc_images_ok(array['00000000-0000-0000-0000-000000000000/a.svg']);
--  ต้อง true:
--    select svc_images_ok('{}'), svc_images_ok(array['00000000-0000-0000-0000-000000000000/a.webp']);

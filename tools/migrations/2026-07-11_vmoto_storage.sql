-- Storage สำหรับรูปสี vmoto: bucket public, อัปโหลดได้เฉพาะโฟลเดอร์ร้านตัวเอง (<shopId>/...)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('vmoto', 'vmoto', true, 3145728, ARRAY['image/jpeg','image/png','image/webp'])
ON CONFLICT (id) DO UPDATE SET public = true, file_size_limit = 3145728,
  allowed_mime_types = ARRAY['image/jpeg','image/png','image/webp'];

-- อ่าน public (หน้า vmoto โหลดรูปได้โดยไม่ต้อง auth)
DROP POLICY IF EXISTS vmoto_obj_read ON storage.objects;
CREATE POLICY vmoto_obj_read ON storage.objects FOR SELECT TO public
  USING (bucket_id = 'vmoto');

-- อัป/ลบ เฉพาะสมาชิกร้านของตัวเอง ที่ path ขึ้นต้นด้วย <shopId ของตัวเอง>
DROP POLICY IF EXISTS vmoto_obj_write ON storage.objects;
CREATE POLICY vmoto_obj_write ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'vmoto' AND (storage.foldername(name))[1] IN (
    SELECT id::text FROM public.pos_shops WHERE owner = auth.uid()
    UNION SELECT shop::text FROM public.pos_members WHERE member = auth.uid()
  ));
DROP POLICY IF EXISTS vmoto_obj_update ON storage.objects;
CREATE POLICY vmoto_obj_update ON storage.objects FOR UPDATE TO authenticated
  USING (bucket_id = 'vmoto' AND (storage.foldername(name))[1] IN (
    SELECT id::text FROM public.pos_shops WHERE owner = auth.uid()
    UNION SELECT shop::text FROM public.pos_members WHERE member = auth.uid()
  ));
DROP POLICY IF EXISTS vmoto_obj_del ON storage.objects;
CREATE POLICY vmoto_obj_del ON storage.objects FOR DELETE TO authenticated
  USING (bucket_id = 'vmoto' AND (storage.foldername(name))[1] IN (
    SELECT id::text FROM public.pos_shops WHERE owner = auth.uid()
    UNION SELECT shop::text FROM public.pos_members WHERE member = auth.uid()
  ));

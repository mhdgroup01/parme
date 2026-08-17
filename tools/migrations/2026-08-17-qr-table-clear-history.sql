-- v3.7.456 — ประวัติการสั่งฝั่งลูกค้าต้องล้างเมื่อเช็คบิล (เจ้าของ: "ลูกค้าเช็คบิลเสร็จแล้ว
-- รายการในโต๊ะนั้นทำไมยังค้างอยู่?")
--
-- ── ต้นเหตุ ────────────────────────────────────────────────────────────────
-- `qr_get_orders` เดิมกรองด้วย `o.token = p_token` เท่านั้น ไม่มีเงื่อนไขเรื่องบิลเลย
-- ที่ผ่านมา "ประวัติล้างเอง" ได้เพราะ **token โต๊ะหมุนตอนเช็คบิล** ⇒ ออเดอร์เก่าที่ถือ token เดิม
-- หลุดจากเงื่อนไขไปเอง ⇒ มันไม่เคยเป็นกลไกล้างประวัติจริง เป็นแค่ "ผลข้างเคียงของการหมุน token"
--
-- 🔴 พอ v3.7.454 เพิ่มโหมด QR โต๊ะถาวร (ไม่หมุน token) ผลข้างเคียงนั้นหายไป ⇒ ประวัติค้าง
--    และร้ายกว่าความรำคาญ: **ลูกค้าคนใหม่ที่นั่งโต๊ะเดิมเห็นว่าคนก่อนสั่งอะไรไปบ้าง**
--
-- ── วิธีแก้ ────────────────────────────────────────────────────────────────
-- ผูกประวัติกับ "รอบบิลปัจจุบัน" แทนที่จะพึ่ง token: เก็บเวลาที่โต๊ะถูกเคลียร์ล่าสุดไว้ใน
-- `pos_shops.table_cleared` (jsonb คู่กับ table_tokens) แล้วให้ qr_get_orders คืนเฉพาะ
-- ออเดอร์ที่เกิด "หลัง" เวลานั้น
--   • ไม่แตะแถวออเดอร์เลย ⇒ ประวัติฝั่งร้าน/รายงานยังครบเหมือนเดิม
--   • ทำงานทั้งสองโหมด (ถาวร/หมุน) ⇒ เป็นการแก้ที่ถูกต้องกว่าการพึ่งผลข้างเคียงตั้งแต่แรก

ALTER TABLE public.pos_shops
  ADD COLUMN IF NOT EXISTS table_cleared jsonb NOT NULL DEFAULT '{}'::jsonb;

-- เขียนเวลาเคลียร์ของโต๊ะหนึ่ง — เฉพาะเจ้าของ/สมาชิกร้านเท่านั้น
-- อิงสิทธิ์แบบเดียวกับ set_table_token ที่มีอยู่แล้ว (เขียนทีละคีย์ ไม่เขียนทั้งก้อน
-- ⇒ หลายเครื่องเขียนพร้อมกันไม่ทับกัน — บทเรียนเดิมของ table_tokens)
-- ⚠️ ใช้ `is_pos_staff()` และ signature (text, integer) ให้เหมือน `set_table_token` ที่มีอยู่แล้ว
--    (ตรวจก่อนเขียน: คอลัมน์เจ้าของชื่อ `owner` ไม่ใช่ `owner_id` และ pos_members ใช้ `shop`/`member`
--     ⇒ ถ้าเขียนเงื่อนไขสิทธิ์เองจะผิดชื่อคอลัมน์ทั้งหมด)
CREATE OR REPLACE FUNCTION public.set_table_cleared(p_shop text, p_table integer)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF public.is_pos_staff(p_shop::uuid, auth.uid()) THEN
    UPDATE public.pos_shops
       SET table_cleared = COALESCE(table_cleared, '{}'::jsonb)
           || jsonb_build_object(p_table::text, to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'))
     WHERE id = p_shop::uuid;
  END IF;
END $$;

-- คืนเฉพาะออเดอร์ของ "รอบบิลปัจจุบัน"
CREATE OR REPLACE FUNCTION public.qr_get_orders(p_shop text, p_table text, p_token text)
RETURNS SETOF pos_qr_orders
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT o.*
  FROM public.pos_qr_orders o
  JOIN public.pos_shops s ON s.id = p_shop::uuid
  WHERE o.shop = p_shop
    AND o.table_no::text = p_table
    AND p_token <> '' AND o.token = p_token
    -- ไม่มีเวลาเคลียร์ = ยังไม่เคยเช็คบิลตั้งแต่มีฟีเจอร์นี้ ⇒ แสดงเหมือนเดิม (ไม่ทำของเก่าหาย)
    AND (
      (s.table_cleared -> p_table) IS NULL
      OR o.created_at > (s.table_cleared ->> p_table)::timestamptz
    )
  ORDER BY o.created_at DESC
  LIMIT 50
$$;

REVOKE ALL ON FUNCTION public.set_table_cleared(text, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.set_table_cleared(text, integer) TO authenticated;

NOTIFY pgrst, 'reload schema';

-- ── ตรวจย้อนหลัง ───────────────────────────────────────────────────────────
--  เวลาเคลียร์ของแต่ละโต๊ะ:
--    select id, table_cleared from pos_shops where table_cleared <> '{}'::jsonb;
--  ออเดอร์ที่ลูกค้าโต๊ะ 1 จะเห็นตอนนี้:
--    select * from qr_get_orders('<shop>', '1', '<token>');

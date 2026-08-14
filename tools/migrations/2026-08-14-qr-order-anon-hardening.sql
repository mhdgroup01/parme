-- v3.7.435 — ปิดช่องที่ anon ยิงออเดอร์ปลอมเข้ากล่องออเดอร์ของร้าน
--
-- 🔴 ช่องโหว่ที่พบ (อ่านจากฟังก์ชันบน DB โปรดักชันเอง 2026-08-14):
--    สาขา pickup/delivery ของ qr_order_allowed เช็กแค่ remote_cfg.enabled = true
--    ไม่ได้เช็ก token เลย ในขณะที่สาขา dinein บังคับ token ต่อโต๊ะ
--    ⇒ ใครรู้ UUID ของร้านก็ insert ออเดอร์ได้ในฐานะ anon
--    และ UUID ร้านไม่ใช่ความลับ — มันอยู่ใน URL สั่งซื้อที่ร้านแจกลูกค้าเอง
--    ขอบเขต: 5 ร้านจาก 49 ที่เปิด remote_cfg.enabled
--
-- ⚠️ ทำไมไม่บังคับ token ทันที — วัดข้อมูลจริงก่อนแล้วพบว่า:
--    ออเดอร์ pickup จริง 21 รายการ **20 รายการไม่มี token** (ล่าสุด 2026-07-27)
--    เพราะลิงก์รุ่นเก่าเป็น ?shop=<uuid> เฉยๆ (token เพิ่มมาตอน v3.7.237 เป็น ?shop=<uuid>.<token>)
--    บังคับทันที = ลิงก์ที่ร้านแจกลูกค้าไปแล้วใช้ไม่ได้ทันที = ธุรกิจจริง 5 ร้านสั่งไม่ได้โดยไม่รู้ตัว
--
--    และต้องพูดตรงๆ ว่า: ลิงก์เก่า "มีแค่ UUID" ⇒ ตราบใดที่ยังรับลิงก์เก่า ก็คือยังรับ "รู้ UUID ก็สั่งได้"
--    ⇒ ปิดสนิทกับไม่ทำลิงก์เก่าพัง เป็นสิ่งเดียวกัน เลือกได้อย่างเดียว
--
-- วิธีแก้จึงแยกเป็น 2 ชั้น:
--   ชั้น A (มีผลทันที ไม่ทำอะไรพัง) — เพดานอัตราการยิง ปิด "ความเสียหายจริง" คือการถล่มกล่องออเดอร์
--   ชั้น B (เปิดทีละร้านเมื่อพร้อม) — remote_cfg.strict = true แล้วร้านนั้นบังคับ token เต็มรูปแบบ
--
-- เพดานเลือกจากข้อมูลจริง: พีคสูงสุดในประวัติทั้งหมดคือ 5 ออเดอร์/5 นาที/ร้าน ⇒ ตั้ง 20 = เผื่อ 4 เท่า

CREATE OR REPLACE FUNCTION public.qr_order_allowed(p_shop text, p_type text, p_table integer, p_token text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT EXISTS (
    SELECT 1 FROM public.pos_shops s
    WHERE s.id = p_shop::uuid AND (
        -- นั่งในร้าน: บังคับ token ต่อโต๊ะเหมือนเดิมทุกประการ (ไม่แตะ)
        (p_type = 'dinein' AND p_table >= 1 AND p_table <= 9999
           AND p_token <> '' AND (s.table_tokens ->> p_table::text) = p_token)
        -- สั่งระยะไกล
     OR (((s.remote_cfg ->> 'enabled')::boolean IS TRUE)
         AND p_type = ANY (ARRAY['pickup','delivery'])
         AND (
              CASE
                -- ร้านที่เปิด strict แล้ว: ต้องมี token และต้องตรง
                WHEN (s.remote_cfg ->> 'strict')::boolean IS TRUE
                  THEN p_token IS NOT NULL AND p_token <> '' AND p_token = (s.remote_cfg ->> 'token')
                -- ร้านที่ยังไม่เปิด strict: ลิงก์เก่า (ไม่มี token) ยังใช้ได้
                -- แต่ถ้าลิงก์พา token มา ต้องตรง — กันคนเดาสุ่มยัด token มั่ว
                ELSE p_token IS NULL OR p_token = '' OR p_token = (s.remote_cfg ->> 'token')
              END
         ))
    )
  )
  -- ชั้น A: เพดานกันยิงรัวต่อร้าน (ใช้ index pos_qr_orders_shop_created_idx ที่มีอยู่แล้ว)
  -- ปิดความเสียหายจริงคือ "ถล่มกล่องออเดอร์" โดยไม่ต้องทำลิงก์เก่าพัง
  AND (
    SELECT count(*) FROM public.pos_qr_orders o
    WHERE o.shop = p_shop AND o.created_at > now() - interval '5 minutes'
  ) < 20;
$function$;

-- ฟังก์ชันรุ่น 3 อาร์กิวเมนต์เป็นของเก่าที่หลวมกว่ามาก (dinein ไม่เช็ก token เลย)
-- ไม่มี policy ไหนใช้แล้ว — ถอนสิทธิ์ anon ไม่ให้เรียกได้ กันไว้ก่อน
REVOKE ALL ON FUNCTION public.qr_order_allowed(text, text, integer) FROM anon, authenticated;

NOTIFY pgrst, 'reload schema';

-- ── วิธีเปิด strict ให้ร้านหนึ่งร้าน (ทำหลังจากร้านแชร์ลิงก์ใหม่ที่มี token แล้วเท่านั้น) ──
--   update pos_shops set remote_cfg = remote_cfg || '{"strict":true}'::jsonb where id = '<shop-uuid>';
-- ── ตรวจว่าร้านไหนยังรับลิงก์เก่าอยู่ ──
--   select left(id::text,8), (remote_cfg->>'strict') from pos_shops where (remote_cfg->>'enabled')::boolean is true;
-- ── ดูว่ามีใครโดนเพดานสกัดไหม (ควรเป็น 0 ในการใช้งานปกติ) ──
--   select shop, count(*) from pos_qr_orders where created_at > now() - interval '1 day' group by 1 order by 2 desc;

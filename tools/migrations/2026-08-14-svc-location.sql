-- v3.7.445 — ຮັບເຮັດ: ปักจุดที่ตั้งในประกาศได้ (เจ้าของ: "สามารถใส่จุด Location Google Map ได้")
--
-- ── เก็บ lat/lng ไม่ใช่ลิงก์ Google Maps ──────────────────────────────────
-- เหตุผลเดียวกับคอลัมน์ images: ผู้ใช้เขียนคอลัมน์นี้เองผ่าน REST ได้
-- ถ้ารับลิงก์ ใครก็ยัด URL ภายนอกให้คนกดจากกระดานสาธารณะได้ (พาไปเว็บอะไรก็ได้)
-- เก็บเป็นตัวเลขแล้วประกอบลิงก์ฝั่งแอป ⇒ ลิงก์ปลายทางเป็น google.com/maps เสมอ
-- และยังวาดหมุดบนแผนที่ในแอปได้โดยไม่ต้องเรียก API ของ Google
--
-- ⚠️ พิกัดนี้ "สาธารณะ" — ทุกคนที่เห็นประกาศเห็นจุดนี้ ⇒ ฝั่งแอปต้องเตือนก่อนปัก
--    (ข้อความ svc_loc_warn) และต้องลบออกได้ตลอดเวลา

ALTER TABLE public.svc_posts
  ADD COLUMN IF NOT EXISTS lat double precision,
  ADD COLUMN IF NOT EXISTS lng double precision;

-- ต้องมาคู่กันเสมอ (มีแต่ lat = จุดที่วาดไม่ได้) และต้องอยู่ในพิสัยจริงของโลก
--
-- 🔴 เขียนแบบ `(lat IS NULL AND lng IS NULL) OR (lat BETWEEN ... AND lng BETWEEN ...)` ไม่ได้ —
--    ทดสอบแล้วมันปล่อยให้ lat=17.9, lng=NULL ผ่าน! เพราะตรรกะสามค่าของ SQL:
--    ฝั่งซ้าย = false, ฝั่งขวามี NULL อยู่ในนิพจน์ ⇒ ทั้งก้อนได้ NULL
--    และ CHECK จะปฏิเสธเฉพาะเมื่อผลเป็น false "ชัดเจน" — NULL ถือว่าผ่าน
--    ⇒ ต้องเทียบ `(lat IS NULL) = (lng IS NULL)` ซึ่ง IS NULL คืน boolean เสมอ ไม่มีทางเป็น NULL
ALTER TABLE public.svc_posts DROP CONSTRAINT IF EXISTS svc_posts_latlng_check;
ALTER TABLE public.svc_posts ADD CONSTRAINT svc_posts_latlng_check CHECK (
  (lat IS NULL) = (lng IS NULL)
  AND (lat IS NULL OR (lat >= -90 AND lat <= 90 AND lng >= -180 AND lng <= 180))
);

NOTIFY pgrst, 'reload schema';

-- ── ตรวจย้อนหลัง ───────────────────────────────────────────────────────────
--  ต้องผ่าน:  update svc_posts set lat=17.9757, lng=102.6331 where id='...';
--  ต้องล้ม:   update svc_posts set lat=91, lng=0 where id='...';
--             update svc_posts set lat=17.9, lng=null where id='...';
--  ดูประกาศที่ปักจุดแล้ว:
--    select left(id::text,8), title, lat, lng from svc_posts where lat is not null;

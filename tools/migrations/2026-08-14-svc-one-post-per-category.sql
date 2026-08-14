-- v3.7.439 — กฎ: ผู้ใช้หนึ่งคนเปิดประกาศค้างไว้ได้ "หมวดละ 1 อัน" (เจ้าของสั่ง)
--
-- 🔴 บังคับที่ฐานข้อมูล ไม่ใช่แค่ซ่อนปุ่มฝั่งไคลเอนต์:
--    แอปนี้เป็น client-only ⇒ ใครก็ยิง REST ตรงได้ ⇒ constraint คือขอบเขตจริงอันเดียว
--    และ unique index กัน race ได้ด้วย (กดสองครั้งเร็วๆ / สองเครื่องพร้อมกัน) ซึ่งเช็คในโค้ดกันไม่ได้
--
-- ขอบเขตของกฎ: (user_id, category) เฉพาะที่ status='open'
--   • ไม่รวม side ⇒ หมวดหนึ่งเปิดได้อันเดียว ไม่ว่าจะเป็น "รับเฮ็ด" หรือ "หาคนเฮ็ด"
--     (ตีความตามคำสั่งตรงตัวว่า "ครั้งเดียวต่อหมวด" — ถ้าอยากให้แยกฝั่ง เพิ่ม side เข้า index ได้ทันที)
--   • นับเฉพาะที่ยังเปิด ⇒ ปิดประกาศเก่าแล้วลงหมวดเดิมใหม่ได้ ไม่ต้องลบทิ้ง
--
-- ⚠️ ก่อนสร้าง index ต้องไม่มีข้อมูลที่ขัดกฎอยู่ก่อน ไม่งั้น CREATE ล้มทั้งคำสั่ง
--    ตรวจแล้วพบผู้ใช้ 1 คนมี 2 ประกาศเปิดในหมวด aircon (เป็นการทดสอบของเจ้าของเอง)
--    ⇒ ปิดอันที่ใหม่กว่า (ไม่ลบ) เก็บอันที่ข้อมูลครบกว่าไว้ · เจ้าของเปิดคืนได้เองจากแท็บ "ຂອງຂ້ອຍ"

-- ปิดตัวซ้ำ: เก็บอันที่เก่าที่สุดของแต่ละ (user, category) ที่เปิดอยู่ ปิดที่เหลือ
UPDATE public.svc_posts p
SET status = 'closed', updated_at = now()
WHERE p.status = 'open'
  AND EXISTS (
    SELECT 1 FROM public.svc_posts q
    WHERE q.user_id = p.user_id AND q.category = p.category
      AND q.status = 'open' AND q.created_at < p.created_at
  );

-- กฎจริง
CREATE UNIQUE INDEX IF NOT EXISTS svc_posts_one_open_per_cat_idx
  ON public.svc_posts (user_id, category)
  WHERE status = 'open';

NOTIFY pgrst, 'reload schema';

-- ── ตรวจย้อนหลัง ───────────────────────────────────────────────────────────
--  ต้องได้ 0 แถวเสมอ:
--    select user_id, category, count(*) from svc_posts where status='open' group by 1,2 having count(*)>1;
--  ดูว่าใครมีอะไรเปิดอยู่บ้าง:
--    select user_id, category, title from svc_posts where status='open' order by user_id, category;
--  ถ้าวันหลังอยากให้แยกตามฝั่ง (รับเฮ็ด/หาคนเฮ็ด ลงหมวดเดียวกันได้ทั้งคู่):
--    drop index svc_posts_one_open_per_cat_idx;
--    create unique index svc_posts_one_open_per_cat_idx on svc_posts (user_id, category, side) where status='open';

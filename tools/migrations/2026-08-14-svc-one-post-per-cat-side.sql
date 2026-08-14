-- v3.7.440 — แก้ขอบเขตกฎ: หมวดละ 1 อัน "แยกตามฝั่ง" (เจ้าของ: "ให้แยกฝั่ง รับเฮ็ดกับหาคนเฮ็ดลงหมวดเดียวกันได้")
--
-- แทนที่ svc_posts_one_open_per_cat_idx (2026-08-14-svc-one-post-per-category.sql)
--   เดิม: (user_id, category)        ⇒ หมวดแอร์เปิดได้อันเดียว ไม่ว่าฝั่งไหน
--   ใหม่: (user_id, category, side)  ⇒ ฝั่ง "รับเฮ็ด" กับ "หาคนเฮ็ด" ลงหมวดแอร์ได้ทั้งคู่
--
-- กฎใหม่ "หลวมกว่า" เดิมทุกกรณี ⇒ ข้อมูลที่ผ่านกฎเดิมอยู่แล้วผ่านกฎใหม่แน่นอน
-- ไม่ต้องล้างอะไรก่อน (ต่างจากรอบที่แล้วที่ต้องปิดตัวซ้ำก่อนสร้าง index)

BEGIN;

DROP INDEX IF EXISTS public.svc_posts_one_open_per_cat_idx;

CREATE UNIQUE INDEX svc_posts_one_open_per_cat_side_idx
  ON public.svc_posts (user_id, category, side)
  WHERE status = 'open';

COMMIT;

NOTIFY pgrst, 'reload schema';

-- ── ตรวจย้อนหลัง ───────────────────────────────────────────────────────────
--  ต้องได้ 0 แถวเสมอ:
--    select user_id, category, side, count(*) from svc_posts where status='open' group by 1,2,3 having count(*)>1;
--  ต้องเหลือ index เดียว (ตัวเก่าต้องหายไป):
--    select indexname from pg_indexes where tablename='svc_posts' and indexname like '%one_open%';

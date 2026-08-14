-- v3.7.450 (ต่อจาก 2026-08-14-svc-jobs-reviews.sql) — RPC สำหรับ "อ่าน"
--
-- ทำไมต้องมี: RLS ของ profiles ไม่เปิดให้อ่านโปรไฟล์คนแปลกหน้า ⇒ ถ้าไคลเอนต์ query svc_jobs ตรง
-- จะได้แต่ uuid ของคู่กรณี แล้วต้องยิงถามชื่อทีละคน (N+1 request บนเน็ตลาว)
-- ⇒ รวบมาให้ครบในคำขอเดียว และคืนเฉพาะฟิลด์ที่หน้าจอใช้จริง ไม่มี email/เบอร์

-- ใบงานของฉันทั้งหมด + ชื่อ/ดาวของคู่กรณี + สถานะรีวิวของทั้งสองฝ่าย
CREATE OR REPLACE FUNCTION public.svc_my_jobs()
RETURNS TABLE (
  id uuid, post_id uuid, title text, category text, price bigint, price_unit text,
  status text, created_at timestamptz, done_at timestamptz,
  i_am text, i_started boolean, other_id uuid, other_name text, other_rating numeric, other_rating_count integer,
  my_stars smallint, my_comment text, their_stars smallint, their_comment text, reviews_open boolean
)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT
    j.id, j.post_id, j.title, j.category, j.price, j.price_unit,
    j.status, j.created_at, j.done_at,
    CASE WHEN j.employer_id = auth.uid() THEN 'employer' ELSE 'worker' END,
    -- ต้องรู้ว่าเราเป็นคนเปิดใบงานเองไหม ⇒ ซ่อนปุ่ม "รับงาน" จากคนเปิด (RPC ปฏิเสธอยู่แล้ว
    -- แต่ปุ่มที่กดแล้ว error คือ UI ที่โกหกผู้ใช้)
    (j.starter_id = auth.uid()),
    o.id, coalesce(o.display_name, o.username, ''), o.svc_rating, o.svc_rating_count,
    mine.stars, mine.comment,
    -- รีวิวของอีกฝ่ายโผล่เฉพาะตอนหน้าต่างปิดตาเปิดแล้ว — ตรรกะเดียวกับ RLS ของ svc_reviews
    CASE WHEN svc_review_open(j.id) THEN theirs.stars END,
    CASE WHEN svc_review_open(j.id) THEN theirs.comment END,
    svc_review_open(j.id)
  FROM svc_jobs j
  JOIN profiles o ON o.id = CASE WHEN j.employer_id = auth.uid() THEN j.worker_id ELSE j.employer_id END
  LEFT JOIN svc_reviews mine   ON mine.job_id = j.id AND mine.reviewer_id = auth.uid()
  LEFT JOIN svc_reviews theirs ON theirs.job_id = j.id AND theirs.reviewer_id <> auth.uid()
  WHERE auth.uid() IN (j.employer_id, j.worker_id)
  ORDER BY
    -- เรียงตามสิ่งที่ต้องลงมือก่อน: รอตอบรับ → กำลังทำ → จบแล้ว → ยกเลิก
    CASE j.status WHEN 'proposed' THEN 0 WHEN 'active' THEN 1 WHEN 'done' THEN 2 ELSE 3 END,
    j.created_at DESC
  LIMIT 200;
$$;

-- รีวิวสาธารณะของผู้ใช้คนหนึ่ง — ใช้ตอนดูประกาศเพื่อตัดสินใจก่อนจ้าง
-- คืนเฉพาะรีวิวที่พ้นหน้าต่างปิดตาแล้ว และไม่บอกว่าใครเขียน (กันตามไปกดดันคนรีวิว)
CREATE OR REPLACE FUNCTION public.svc_user_reviews(p_user uuid, p_limit integer DEFAULT 10)
RETURNS TABLE (stars smallint, comment text, created_at timestamptz, job_title text)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT r.stars, r.comment, r.created_at, j.title
  FROM svc_reviews r JOIN svc_jobs j ON j.id = r.job_id
  WHERE r.reviewee_id = p_user AND svc_review_open(r.job_id)
  ORDER BY r.created_at DESC
  LIMIT greatest(1, least(coalesce(p_limit, 10), 50));
$$;

REVOKE ALL ON FUNCTION public.svc_my_jobs()                    FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.svc_user_reviews(uuid, integer)  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.svc_my_jobs()                 TO authenticated;
GRANT EXECUTE ON FUNCTION public.svc_user_reviews(uuid, integer) TO authenticated;

NOTIFY pgrst, 'reload schema';

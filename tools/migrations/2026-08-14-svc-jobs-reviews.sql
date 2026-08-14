-- v3.7.450 — ຮັບເຮັດ: ประวัติการจ้างงาน + รีวิว + ดาว (เจ้าของ: "เก็บประวัติการจ้างงาน มีการคอมเมนต์
-- ให้ดาว เพื่อมาเป็นคะแนนและดาว")
--
-- ── หลักคิดที่ทั้งไฟล์นี้ยืนอยู่บนมัน ────────────────────────────────────────
-- ดาวจะมีค่าก็ต่อเมื่อ "ปั่นไม่ได้" ⇒ ห้ามให้ใครรีวิวใครก็ได้
-- ต้องผูกกับ "ใบงาน" ที่ทั้งสองฝ่ายกดยืนยันว่าจ้างกันจริง แล้วรีวิวได้ฝ่ายละครั้งเดียวต่อใบงาน
-- (แนวเดียวกับ Airbnb/Fastwork) · เจ้าของเลือก: รีวิวสองทาง + ต้องมีใบงานยืนยัน
--
-- ⚠️ Parme ไม่ได้ถือเงินและไม่ใช่คนกลาง ⇒ ระบบนี้ไม่ใช่หลักฐานการชำระเงิน
--    มันบันทึกแค่ว่า "สองคนนี้ตกลงจ้างกันและกดจบงานร่วมกัน"

-- ══════════════════════════════════════════════════════════════════════════
-- 1. ใบงาน
-- ══════════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS public.svc_jobs (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  -- ON DELETE SET NULL ไม่ใช่ CASCADE — ลบประกาศทิ้งแล้วประวัติการจ้างต้องยังอยู่
  post_id     uuid REFERENCES public.svc_posts(id) ON DELETE SET NULL,
  employer_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,  -- ฝ่ายจ้าง
  worker_id   uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,  -- ฝ่ายรับงาน
  starter_id  uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,  -- ใครกดเปิดใบงาน
  -- คัดลอกไว้ ณ เวลาเปิดใบงาน: ประกาศถูกแก้/ลบทีหลังแล้วประวัติต้องยังอ่านรู้เรื่อง
  title       text NOT NULL CHECK (length(btrim(title)) BETWEEN 1 AND 80),
  category    text NOT NULL,
  price       bigint CHECK (price IS NULL OR (price >= 0 AND price <= 9000000000)),
  price_unit  text NOT NULL DEFAULT 'job',
  status      text NOT NULL DEFAULT 'proposed'
              CHECK (status IN ('proposed', 'active', 'done', 'cancelled')),
  created_at   timestamptz NOT NULL DEFAULT now(),
  accepted_at  timestamptz,
  done_at      timestamptz,
  cancelled_at timestamptz,
  cancelled_by uuid,
  CHECK (employer_id <> worker_id),
  CHECK (starter_id IN (employer_id, worker_id))
);

CREATE INDEX IF NOT EXISTS svc_jobs_employer_idx ON public.svc_jobs (employer_id, created_at DESC);
CREATE INDEX IF NOT EXISTS svc_jobs_worker_idx   ON public.svc_jobs (worker_id, created_at DESC);
-- กันเปิดใบงานซ้ำกับคู่เดิมบนประกาศเดิมขณะที่ใบเก่ายังไม่จบ
CREATE UNIQUE INDEX IF NOT EXISTS svc_jobs_open_pair_idx
  ON public.svc_jobs (post_id, employer_id, worker_id)
  WHERE status IN ('proposed', 'active');

ALTER TABLE public.svc_jobs ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON public.svc_jobs TO authenticated;
-- ไม่ให้ INSERT/UPDATE ตรง — ทุกการเปลี่ยนสถานะผ่าน RPC ที่ตรวจกฎว่าใครกดได้ตอนไหน

DROP POLICY IF EXISTS svc_jobs_read ON public.svc_jobs;
-- ใบงานเป็นเรื่องของคู่กรณีเท่านั้น (คนนอกเห็นแค่ยอดรวมในโปรไฟล์)
CREATE POLICY svc_jobs_read ON public.svc_jobs FOR SELECT TO authenticated
  USING (employer_id = auth.uid() OR worker_id = auth.uid());

-- ══════════════════════════════════════════════════════════════════════════
-- 2. รีวิว
-- ══════════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS public.svc_reviews (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  job_id      uuid NOT NULL REFERENCES public.svc_jobs(id) ON DELETE CASCADE,
  reviewer_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  reviewee_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  stars       smallint NOT NULL CHECK (stars BETWEEN 1 AND 5),
  comment     text NOT NULL DEFAULT '' CHECK (length(comment) <= 300),
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE (job_id, reviewer_id),          -- รีวิวได้ครั้งเดียวต่อใบงาน
  CHECK (reviewer_id <> reviewee_id)
);

CREATE INDEX IF NOT EXISTS svc_reviews_reviewee_idx ON public.svc_reviews (reviewee_id, created_at DESC);

ALTER TABLE public.svc_reviews ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON public.svc_reviews TO authenticated;
-- เขียนผ่าน RPC เท่านั้น · ไม่มี DELETE ให้ใครเลย รวมเจ้าของรีวิว (ลบได้ = ลบรีวิวแย่ทิ้ง)

-- ── หน้าต่างปิดตา (blind window) ───────────────────────────────────────────
-- ถ้าเห็นรีวิวของอีกฝ่ายก่อน จะเกิดการรีวิวแก้แค้น (โดน 2 ดาว ก็ให้ 1 ดาวคืน)
-- ⇒ ซ่อนจนกว่า "ทั้งคู่รีวิวแล้ว" หรือ "ผ่าน 14 วันนับจากจบงาน" อย่างใดอย่างหนึ่ง
CREATE OR REPLACE FUNCTION public.svc_review_open(p_job uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT (SELECT count(*) FROM svc_reviews WHERE job_id = p_job) >= 2
      OR (SELECT done_at < now() - interval '14 days' FROM svc_jobs WHERE id = p_job);
$$;

DROP POLICY IF EXISTS svc_reviews_read ON public.svc_reviews;
CREATE POLICY svc_reviews_read ON public.svc_reviews FOR SELECT TO authenticated
  USING (reviewer_id = auth.uid() OR public.svc_review_open(job_id));

-- ══════════════════════════════════════════════════════════════════════════
-- 3. คะแนนสะสมในโปรไฟล์ (อ่านเร็ว ไม่ต้อง join ทุกครั้งที่โหลดกระดาน)
-- ══════════════════════════════════════════════════════════════════════════
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS svc_rating       numeric(3,2),
  ADD COLUMN IF NOT EXISTS svc_rating_count integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS svc_jobs_done    integer NOT NULL DEFAULT 0;

CREATE OR REPLACE FUNCTION public.svc_recalc_rating(p_user uuid)
RETURNS void LANGUAGE sql SECURITY DEFINER SET search_path = public, pg_temp AS $$
  UPDATE profiles p SET
    svc_rating = r.avg_stars,
    svc_rating_count = coalesce(r.n, 0)
  FROM (
    SELECT round(avg(stars)::numeric, 2) AS avg_stars, count(*) AS n
    FROM svc_reviews WHERE reviewee_id = p_user
  ) r
  WHERE p.id = p_user;
$$;

CREATE OR REPLACE FUNCTION public.svc_reviews_touch()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  PERFORM svc_recalc_rating(COALESCE(NEW.reviewee_id, OLD.reviewee_id));
  RETURN NULL;
END $$;

DROP TRIGGER IF EXISTS svc_reviews_after ON public.svc_reviews;
CREATE TRIGGER svc_reviews_after AFTER INSERT OR UPDATE OR DELETE ON public.svc_reviews
  FOR EACH ROW EXECUTE FUNCTION public.svc_reviews_touch();

CREATE OR REPLACE FUNCTION public.svc_jobs_touch()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NEW.status = 'done' AND (OLD.status IS DISTINCT FROM 'done') THEN
    UPDATE profiles SET svc_jobs_done = svc_jobs_done + 1 WHERE id IN (NEW.employer_id, NEW.worker_id);
  END IF;
  RETURN NULL;
END $$;

DROP TRIGGER IF EXISTS svc_jobs_after ON public.svc_jobs;
CREATE TRIGGER svc_jobs_after AFTER UPDATE ON public.svc_jobs
  FOR EACH ROW EXECUTE FUNCTION public.svc_jobs_touch();

-- ══════════════════════════════════════════════════════════════════════════
-- 4. ชนิดการแจ้งเตือนใหม่
-- ══════════════════════════════════════════════════════════════════════════
ALTER TABLE public.friend_notifications DROP CONSTRAINT IF EXISTS friend_notifications_type_check;
ALTER TABLE public.friend_notifications ADD CONSTRAINT friend_notifications_type_check
  CHECK (type IN ('reminder','paid_notify','paid_confirmed','message','svc_interest',
                  'svc_job_offer','svc_job_accepted','svc_job_done','svc_review'));

-- ══════════════════════════════════════════════════════════════════════════
-- 5. RPC — ทุกการเปลี่ยนสถานะอยู่ที่นี่ที่เดียว
--    (ไคลเอนต์ update ตรงไม่ได้ ⇒ กฎ "ใครกดได้ตอนไหน" บังคับฝั่งเซิร์ฟเวอร์)
-- ══════════════════════════════════════════════════════════════════════════

-- เปิดใบงานจากประกาศ · ฝ่ายไหนเป็นนายจ้างขึ้นกับว่าประกาศเป็น offer หรือ want
CREATE OR REPLACE FUNCTION public.svc_job_start(p_post uuid)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_me uuid := auth.uid(); v_post svc_posts%ROWTYPE; v_emp uuid; v_wrk uuid; v_id uuid;
BEGIN
  IF v_me IS NULL THEN RAISE EXCEPTION 'unauthenticated'; END IF;
  IF svc_user_banned(v_me) THEN RAISE EXCEPTION 'banned'; END IF;

  SELECT * INTO v_post FROM svc_posts WHERE id = p_post AND status = 'open';
  IF NOT FOUND THEN RAISE EXCEPTION 'post_not_found'; END IF;
  IF v_post.user_id = v_me THEN RAISE EXCEPTION 'cannot_hire_self'; END IF;

  -- ประกาศ 'offer' = เจ้าของรับทำงาน ⇒ คนกดคือผู้จ้าง · 'want' = เจ้าของหาคนทำ ⇒ คนกดคือผู้รับงาน
  IF v_post.side = 'offer' THEN v_emp := v_me;          v_wrk := v_post.user_id;
  ELSE                         v_emp := v_post.user_id; v_wrk := v_me;
  END IF;

  -- เพดานรายวัน กันไล่เปิดใบงานรัวๆ (เหตุผลเดียวกับ svc_interest)
  IF (SELECT count(*) FROM svc_jobs WHERE starter_id = v_me AND created_at > now() - interval '1 day') >= 15 THEN
    RAISE EXCEPTION 'rate_limited';
  END IF;

  INSERT INTO svc_jobs (post_id, employer_id, worker_id, starter_id, title, category, price, price_unit)
  VALUES (p_post, v_emp, v_wrk, v_me, v_post.title, v_post.category, v_post.price, v_post.price_unit)
  RETURNING id INTO v_id;

  INSERT INTO friend_notifications (sender_id, recipient_id, type, body, metadata)
  VALUES (v_me, v_post.user_id, 'svc_job_offer', left(v_post.title, 200),
          jsonb_build_object('job_id', v_id, 'post_id', p_post, 'title', v_post.title));
  RETURN v_id;
END $$;

-- อีกฝ่าย (คนที่ไม่ได้เปิด) กดรับ
CREATE OR REPLACE FUNCTION public.svc_job_accept(p_job uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_me uuid := auth.uid(); v_j svc_jobs%ROWTYPE;
BEGIN
  IF v_me IS NULL THEN RAISE EXCEPTION 'unauthenticated'; END IF;
  SELECT * INTO v_j FROM svc_jobs WHERE id = p_job FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'job_not_found'; END IF;
  IF v_j.status <> 'proposed' THEN RAISE EXCEPTION 'bad_status'; END IF;
  IF v_me NOT IN (v_j.employer_id, v_j.worker_id) THEN RAISE EXCEPTION 'not_party'; END IF;
  -- คนเปิดใบงานกดรับเองไม่ได้ ไม่งั้น "ยืนยันสองฝ่าย" ก็ไม่มีความหมาย
  IF v_me = v_j.starter_id THEN RAISE EXCEPTION 'starter_cannot_accept'; END IF;

  UPDATE svc_jobs SET status = 'active', accepted_at = now() WHERE id = p_job;
  INSERT INTO friend_notifications (sender_id, recipient_id, type, body, metadata)
  VALUES (v_me, v_j.starter_id, 'svc_job_accepted', left(v_j.title, 200),
          jsonb_build_object('job_id', p_job, 'title', v_j.title));
END $$;

-- ฝ่ายใดก็ได้กดจบงาน (ไม่ต้องรออีกฝ่าย — ยืนยันสองชั้นตอนเปิดพอแล้ว
-- ถ้าต้องยืนยันจบสองฝ่ายอีก งานจะค้างเป็นจำนวนมากเพราะคนไม่กลับมากด)
CREATE OR REPLACE FUNCTION public.svc_job_done(p_job uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_me uuid := auth.uid(); v_j svc_jobs%ROWTYPE; v_other uuid;
BEGIN
  IF v_me IS NULL THEN RAISE EXCEPTION 'unauthenticated'; END IF;
  SELECT * INTO v_j FROM svc_jobs WHERE id = p_job FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'job_not_found'; END IF;
  IF v_j.status <> 'active' THEN RAISE EXCEPTION 'bad_status'; END IF;
  IF v_me NOT IN (v_j.employer_id, v_j.worker_id) THEN RAISE EXCEPTION 'not_party'; END IF;

  UPDATE svc_jobs SET status = 'done', done_at = now() WHERE id = p_job;
  v_other := CASE WHEN v_me = v_j.employer_id THEN v_j.worker_id ELSE v_j.employer_id END;
  INSERT INTO friend_notifications (sender_id, recipient_id, type, body, metadata)
  VALUES (v_me, v_other, 'svc_job_done', left(v_j.title, 200),
          jsonb_build_object('job_id', p_job, 'title', v_j.title));
END $$;

-- ยกเลิกได้ก่อนจบงาน · งานที่ยกเลิกรีวิวไม่ได้ (ไม่งั้นเปิดใบงานปลอมแล้วยกเลิกเพื่อรีวิว)
CREATE OR REPLACE FUNCTION public.svc_job_cancel(p_job uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_me uuid := auth.uid(); v_j svc_jobs%ROWTYPE;
BEGIN
  IF v_me IS NULL THEN RAISE EXCEPTION 'unauthenticated'; END IF;
  SELECT * INTO v_j FROM svc_jobs WHERE id = p_job FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'job_not_found'; END IF;
  IF v_j.status NOT IN ('proposed', 'active') THEN RAISE EXCEPTION 'bad_status'; END IF;
  IF v_me NOT IN (v_j.employer_id, v_j.worker_id) THEN RAISE EXCEPTION 'not_party'; END IF;
  UPDATE svc_jobs SET status = 'cancelled', cancelled_at = now(), cancelled_by = v_me WHERE id = p_job;
END $$;

-- รีวิว: เฉพาะคู่กรณีของใบงานที่ 'done' · ฝ่ายละครั้ง · แก้ได้ 24 ชม.แรกแล้วล็อกถาวร
CREATE OR REPLACE FUNCTION public.svc_review(p_job uuid, p_stars int, p_comment text DEFAULT '')
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_me uuid := auth.uid(); v_j svc_jobs%ROWTYPE; v_target uuid; v_old svc_reviews%ROWTYPE; v_id uuid;
BEGIN
  IF v_me IS NULL THEN RAISE EXCEPTION 'unauthenticated'; END IF;
  IF svc_user_banned(v_me) THEN RAISE EXCEPTION 'banned'; END IF;
  IF p_stars IS NULL OR p_stars < 1 OR p_stars > 5 THEN RAISE EXCEPTION 'bad_stars'; END IF;

  SELECT * INTO v_j FROM svc_jobs WHERE id = p_job;
  IF NOT FOUND THEN RAISE EXCEPTION 'job_not_found'; END IF;
  IF v_j.status <> 'done' THEN RAISE EXCEPTION 'job_not_done'; END IF;
  IF v_me NOT IN (v_j.employer_id, v_j.worker_id) THEN RAISE EXCEPTION 'not_party'; END IF;

  v_target := CASE WHEN v_me = v_j.employer_id THEN v_j.worker_id ELSE v_j.employer_id END;

  SELECT * INTO v_old FROM svc_reviews WHERE job_id = p_job AND reviewer_id = v_me;
  IF FOUND THEN
    IF v_old.created_at < now() - interval '24 hours' THEN RAISE EXCEPTION 'edit_window_closed'; END IF;
    UPDATE svc_reviews SET stars = p_stars, comment = left(coalesce(btrim(p_comment), ''), 300), updated_at = now()
    WHERE id = v_old.id RETURNING id INTO v_id;
    RETURN v_id;
  END IF;

  INSERT INTO svc_reviews (job_id, reviewer_id, reviewee_id, stars, comment)
  VALUES (p_job, v_me, v_target, p_stars, left(coalesce(btrim(p_comment), ''), 300))
  RETURNING id INTO v_id;

  INSERT INTO friend_notifications (sender_id, recipient_id, type, body, metadata)
  VALUES (v_me, v_target, 'svc_review', left(v_j.title, 200),
          jsonb_build_object('job_id', p_job, 'title', v_j.title));
  RETURN v_id;
END $$;

-- โปรไฟล์สาธารณะย่อของผู้ลงประกาศ — ต้องดูดาวได้ "ก่อน" ตัดสินใจจ้าง
-- SECURITY DEFINER เพราะ RLS ของ profiles ไม่ได้เปิดให้อ่านโปรไฟล์คนแปลกหน้า
-- คืนเฉพาะ 4 ค่าที่จำเป็น ไม่คืน email/เบอร์/วันเกิด
CREATE OR REPLACE FUNCTION public.svc_public_profile(p_user uuid)
RETURNS TABLE (display_name text, svc_rating numeric, svc_rating_count integer, svc_jobs_done integer)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT coalesce(p.display_name, p.username, ''), p.svc_rating, p.svc_rating_count, p.svc_jobs_done
  FROM profiles p WHERE p.id = p_user AND p.is_banned IS NOT TRUE;
$$;

REVOKE ALL ON FUNCTION public.svc_job_start(uuid)               FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.svc_job_accept(uuid)              FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.svc_job_done(uuid)                FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.svc_job_cancel(uuid)              FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.svc_review(uuid, int, text)       FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.svc_job_start(uuid)            TO authenticated;
GRANT EXECUTE ON FUNCTION public.svc_job_accept(uuid)           TO authenticated;
GRANT EXECUTE ON FUNCTION public.svc_job_done(uuid)             TO authenticated;
GRANT EXECUTE ON FUNCTION public.svc_job_cancel(uuid)           TO authenticated;
GRANT EXECUTE ON FUNCTION public.svc_review(uuid, int, text)    TO authenticated;
GRANT EXECUTE ON FUNCTION public.svc_public_profile(uuid)       TO authenticated;
GRANT EXECUTE ON FUNCTION public.svc_review_open(uuid)          TO authenticated;

NOTIFY pgrst, 'reload schema';

-- ── ตรวจย้อนหลัง ───────────────────────────────────────────────────────────
--  งานที่ค้างรอยืนยันเกิน 7 วัน:
--    select id, title, created_at from svc_jobs where status='proposed' and created_at < now()-interval '7 days';
--  คนที่ได้ดาวสูงสุด (นับเฉพาะที่มี 3 รีวิวขึ้นไป ตามที่แอปแสดง):
--    select id, svc_rating, svc_rating_count from profiles where svc_rating_count >= 3 order by svc_rating desc;
--  รีวิวที่ยังปิดตาอยู่:
--    select r.id, r.job_id from svc_reviews r where not svc_review_open(r.job_id);

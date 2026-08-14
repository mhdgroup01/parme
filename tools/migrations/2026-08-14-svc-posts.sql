-- v3.7.435 — ຮັບເຮັດ: กระดานสองฝ่าย (รับทำงาน / หาคนทำงาน) เปิดให้ผู้ใช้ Parme ทุกคน
--
-- ออกแบบตามที่เจ้าของสั่ง: ผู้ใช้ทุกคนโพสต์ได้เอง 2 ฝั่ง
--   side='offer' = ຂ້ອຍຮັບເຮັດ (ฉันรับทำงานนี้)
--   side='want'  = ຂ້ອຍຫາຄົນເຮັດ (ฉันหาคนมาทำงานนี้)
--
-- 🔴 ทำไมเป็นตารางใหม่ ไม่ยัดใน pos_products ตามที่งานวิจัยเสนอ:
--    pos_shops มี unique index ต่อเจ้าของ 1 ร้าน ⇒ ผูกโพสต์กับ "ร้าน" จะบังคับให้ทุกคนต้องมีร้าน
--    ซึ่งผิดความหมาย (คนรับซ่อมรถไม่ใช่ร้าน) และคนที่มีร้านอยู่แล้วจะปนกับสินค้า POS
--    ⇒ ตารางแยกตรงไปตรงมากว่า แลกกับ RLS ใหม่ที่ต้องทดสอบให้ครบ (ทำแล้วท้ายไฟล์)
--
-- 🔴 ทำไมไม่ใช้ send_friend_notification ที่มีอยู่เป็นช่องทาง "สนใจ":
--    RPC นั้นบังคับว่า sender กับ recipient ต้องเป็นเพื่อนกันแล้ว (status='accepted')
--    ทั้งแอปมีเพื่อนกัน 5 คู่ ⇒ ใช้กับคนแปลกหน้าไม่ได้เลย จึงต้องมี RPC ของตัวเอง
--    และตาราง friend_notifications มี CHECK จำกัด type ไว้ 4 ค่า ⇒ ต้องขยายก่อน

-- ── 1) ตารางโพสต์ ──────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.svc_posts (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  side        text NOT NULL CHECK (side IN ('offer','want')),
  category    text NOT NULL,
  title       text NOT NULL CHECK (length(btrim(title)) BETWEEN 3 AND 80),
  detail      text NOT NULL DEFAULT '' CHECK (length(detail) <= 600),
  -- ราคา: offer = ราคาที่คิด · want = งบที่ตั้งไว้ · NULL = ตกลงกันเอง
  price       bigint CHECK (price IS NULL OR (price >= 0 AND price <= 9000000000)),
  price_unit  text NOT NULL DEFAULT 'job' CHECK (price_unit IN ('job','hour','day','piece','month')),
  area        text NOT NULL DEFAULT '' CHECK (length(area) <= 60),
  -- ผู้โพสต์เลือกเองว่าจะเปิดเบอร์/ลิงก์ติดต่อไหม (ว่างได้ — ให้คนสนใจกดปุ่มแทน)
  contact     text NOT NULL DEFAULT '' CHECK (length(contact) <= 120),
  status      text NOT NULL DEFAULT 'open' CHECK (status IN ('open','closed')),
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS svc_posts_feed_idx  ON public.svc_posts (side, status, created_at DESC);
CREATE INDEX IF NOT EXISTS svc_posts_owner_idx ON public.svc_posts (user_id, created_at DESC);

ALTER TABLE public.svc_posts ENABLE ROW LEVEL SECURITY;

-- อ่าน: ผู้ใช้ที่ล็อกอินแล้วเห็นโพสต์ที่ยังเปิดอยู่ของทุกคน (นี่คือกระดาน)
--       + เจ้าของเห็นของตัวเองทุกสถานะ
--       🔴 ซ่อนโพสต์ของคนที่ถูกแบน — ทำที่ชั้น RLS ไม่ใช่ที่ไคลเอนต์
DROP POLICY IF EXISTS svc_posts_read ON public.svc_posts;
CREATE POLICY svc_posts_read ON public.svc_posts FOR SELECT TO authenticated
USING (
  user_id = auth.uid()
  OR (
    status = 'open'
    AND NOT EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = svc_posts.user_id AND p.is_banned IS TRUE)
  )
);

-- เขียน: ของตัวเองเท่านั้น และคนที่ถูกแบนโพสต์ไม่ได้
DROP POLICY IF EXISTS svc_posts_insert ON public.svc_posts;
CREATE POLICY svc_posts_insert ON public.svc_posts FOR INSERT TO authenticated
WITH CHECK (
  user_id = auth.uid()
  AND NOT EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.is_banned IS TRUE)
  -- เพดานกันสแปม: คนหนึ่งโพสต์ได้ไม่เกิน 20 โพสต์ที่ยังเปิดอยู่
  AND (SELECT count(*) FROM public.svc_posts s WHERE s.user_id = auth.uid() AND s.status = 'open') < 20
);

DROP POLICY IF EXISTS svc_posts_update ON public.svc_posts;
CREATE POLICY svc_posts_update ON public.svc_posts FOR UPDATE TO authenticated
USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS svc_posts_delete ON public.svc_posts;
CREATE POLICY svc_posts_delete ON public.svc_posts FOR DELETE TO authenticated
USING (user_id = auth.uid());

-- ── 2) ขยาย type ของกล่องแจ้งเตือนเดิม ให้รับ 'svc_interest' ──────────────
ALTER TABLE public.friend_notifications DROP CONSTRAINT IF EXISTS friend_notifications_type_check;
ALTER TABLE public.friend_notifications ADD CONSTRAINT friend_notifications_type_check
  CHECK (type IN ('reminder','paid_notify','paid_confirmed','message','svc_interest'));

-- ── 3) RPC "สนใจโพสต์นี้" — ไม่ต้องเป็นเพื่อนกัน แต่คุมสแปมแน่น ────────────
CREATE OR REPLACE FUNCTION public.svc_interest(p_post uuid, p_note text DEFAULT NULL)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_me    uuid := auth.uid();
  v_post  public.svc_posts%ROWTYPE;
  v_id    uuid;
BEGIN
  IF v_me IS NULL THEN RAISE EXCEPTION 'unauthenticated'; END IF;
  IF EXISTS (SELECT 1 FROM profiles WHERE id = v_me AND is_banned IS TRUE) THEN
    RAISE EXCEPTION 'banned';
  END IF;

  SELECT * INTO v_post FROM svc_posts WHERE id = p_post AND status = 'open';
  IF NOT FOUND THEN RAISE EXCEPTION 'post_not_found'; END IF;
  IF v_post.user_id = v_me THEN RAISE EXCEPTION 'cannot_send_to_self'; END IF;

  -- กันกดซ้ำโพสต์เดิม
  IF EXISTS (
    SELECT 1 FROM friend_notifications
    WHERE sender_id = v_me AND type = 'svc_interest' AND (metadata->>'post_id') = p_post::text
  ) THEN RAISE EXCEPTION 'already_sent'; END IF;

  -- เพดานรายวัน กันไล่กดทุกโพสต์
  IF (SELECT count(*) FROM friend_notifications
      WHERE sender_id = v_me AND type = 'svc_interest'
        AND created_at > now() - interval '1 day') >= 15 THEN
    RAISE EXCEPTION 'rate_limited';
  END IF;

  INSERT INTO friend_notifications (sender_id, recipient_id, type, body, metadata)
  VALUES (v_me, v_post.user_id, 'svc_interest',
          left(coalesce(btrim(p_note), ''), 200),
          jsonb_build_object('post_id', p_post, 'title', v_post.title, 'side', v_post.side))
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

REVOKE ALL ON FUNCTION public.svc_interest(uuid, text) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.svc_interest(uuid, text) TO authenticated;

NOTIFY pgrst, 'reload schema';

-- ── ตรวจย้อนหลัง ───────────────────────────────────────────────────────────
--  โพสต์ทั้งหมด:      select side, status, count(*) from svc_posts group by 1,2;
--  คนโพสต์เยอะสุด:    select user_id, count(*) from svc_posts group by 1 order by 2 desc limit 5;
--  การกดสนใจ:         select count(*) from friend_notifications where type='svc_interest';
-- v3.7.435 fix — แก้บั๊ก 2 ตัวที่ตัวทดสอบ RLS จับได้ (ทั้งคู่ทำให้ฟีเจอร์พังสนิท)
--
-- บั๊ก 1: ลืม GRANT ⇒ "permission denied for table svc_posts"
--   สร้างตารางด้วย SQL ดิบ สิทธิ์ default ของ Supabase ไม่ครอบให้ ⇒ RLS ไม่ทันได้ทำงานเลย
--   ผู้ใช้ทุกคนจะอ่าน/เขียนไม่ได้แม้แต่ของตัวเอง
--
-- บั๊ก 2: "infinite recursion detected in policy"
--   policy INSERT มี subquery นับโพสต์จาก svc_posts เอง ⇒ ไปกระตุ้น policy SELECT ของ svc_posts ⇒ วนไม่จบ
--   ⇒ ย้ายการนับไปไว้ในฟังก์ชัน SECURITY DEFINER ซึ่งรันในสิทธิ์เจ้าของตาราง จึงข้าม RLS และไม่วน
--   ใช้วิธีเดียวกันกับการเช็ก is_banned ด้วย เพราะ policy ของ profiles อาจไม่ให้อ่านแถวคนอื่น
--   ซึ่งจะทำให้ NOT EXISTS คืน true เงียบๆ = โพสต์ของคนโดนแบนโผล่ต่อ

GRANT SELECT, INSERT, UPDATE, DELETE ON public.svc_posts TO authenticated;

CREATE OR REPLACE FUNCTION public.svc_user_banned(p_uid uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public'
AS $$ SELECT EXISTS (SELECT 1 FROM public.profiles WHERE id = p_uid AND is_banned IS TRUE) $$;

CREATE OR REPLACE FUNCTION public.svc_open_posts(p_uid uuid)
RETURNS integer LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public'
AS $$ SELECT count(*)::int FROM public.svc_posts WHERE user_id = p_uid AND status = 'open' $$;

REVOKE ALL ON FUNCTION public.svc_user_banned(uuid) FROM public, anon;
REVOKE ALL ON FUNCTION public.svc_open_posts(uuid) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.svc_user_banned(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.svc_open_posts(uuid) TO authenticated;

DROP POLICY IF EXISTS svc_posts_read ON public.svc_posts;
CREATE POLICY svc_posts_read ON public.svc_posts FOR SELECT TO authenticated
USING (user_id = auth.uid() OR (status = 'open' AND NOT public.svc_user_banned(user_id)));

DROP POLICY IF EXISTS svc_posts_insert ON public.svc_posts;
CREATE POLICY svc_posts_insert ON public.svc_posts FOR INSERT TO authenticated
WITH CHECK (
  user_id = auth.uid()
  AND NOT public.svc_user_banned(auth.uid())
  AND public.svc_open_posts(auth.uid()) < 20
);

NOTIFY pgrst, 'reload schema';

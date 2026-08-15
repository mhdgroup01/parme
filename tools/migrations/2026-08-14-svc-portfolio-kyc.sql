-- v3.7.452 — ຮັບເຮັດ: ผลงาน (portfolio) + ยืนยันตัวตน (KYC)
-- (เจ้าของ: "ทำระบบกรอกข้อมูลผลงาน และระบบ KYC ... KYC ผ่านจะมีสัญลักษณ์พิเศษ ยืนยันจากเรา
--  ว่าคนนี้มีตัวตนจริง เพื่อความเชื่อถือไปอีกขั้น")
--
-- 🔴🔴 ไฟล์นี้แตะข้อมูลอ่อนไหวที่สุดในระบบ: รูปบัตรประชาชน/พาสปอร์ต
--     รั่วเมื่อไหร่ = ถูกสวมรอยตัวตนได้จริง กู้คืนไม่ได้ ⇒ ออกแบบด้วยหลัก "เก็บให้น้อยที่สุด สั้นที่สุด"
--     1. bucket 'kyc' เป็น **private** (ต่างจาก 'svc'/'vmoto' ที่ public) — ไม่มี URL สาธารณะเลย
--        ดูได้ผ่าน signed URL อายุสั้นเท่านั้น และเฉพาะเจ้าของกับแอดมิน
--     2. **ลบไฟล์ทิ้งทันทีที่ตรวจเสร็จ** ไม่ว่าผ่านหรือไม่ผ่าน — เก็บไว้แค่ "ผล" ไม่เก็บหลักฐาน
--     3. **ไม่เก็บเลขบัตรเต็ม** เก็บแค่ 4 ตัวท้ายไว้อ้างอิงเวลามีข้อพิพาท
--     4. คนนอกเห็นได้อย่างเดียวคือ badge ✓ — ไม่เห็นชื่อจริง เลขเอกสาร หรือรูป

-- ══════════════════════════════════════════════════════════════════════════
-- 1. ผลงาน — สาธารณะโดยตั้งใจ (มีไว้ให้คนดูก่อนจ้าง)
-- ══════════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS public.svc_portfolio (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title      text NOT NULL CHECK (length(btrim(title)) BETWEEN 2 AND 80),
  detail     text NOT NULL DEFAULT '' CHECK (length(detail) <= 500),
  category   text,
  year       smallint CHECK (year IS NULL OR (year BETWEEN 1990 AND 2100)),
  -- ใช้ bucket 'svc' ตัวเดียวกับรูปประกาศ ⇒ กติกา path เดิม และ CHECK ตัวเดิม (svc_images_ok)
  images     text[] NOT NULL DEFAULT '{}' CHECK (public.svc_images_ok(images)),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS svc_portfolio_user_idx ON public.svc_portfolio (user_id, created_at DESC);

ALTER TABLE public.svc_portfolio ENABLE ROW LEVEL SECURITY;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.svc_portfolio TO authenticated;

-- เพดาน 12 ชิ้นต่อคน — กันคนถล่มกระดานด้วยผลงานปลอมเป็นร้อยชิ้น
CREATE OR REPLACE FUNCTION public.svc_portfolio_count(p_user uuid)
RETURNS integer LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT count(*)::int FROM svc_portfolio WHERE user_id = p_user;
$$;

DROP POLICY IF EXISTS svc_portfolio_read   ON public.svc_portfolio;
DROP POLICY IF EXISTS svc_portfolio_insert ON public.svc_portfolio;
DROP POLICY IF EXISTS svc_portfolio_update ON public.svc_portfolio;
DROP POLICY IF EXISTS svc_portfolio_delete ON public.svc_portfolio;
-- อ่านได้ทุกคนที่ล็อกอิน (ยกเว้นของคนถูกแบน) — ผลงานมีไว้ให้ดูก่อนจ้าง
CREATE POLICY svc_portfolio_read ON public.svc_portfolio FOR SELECT TO authenticated
  USING (user_id = auth.uid() OR NOT public.svc_user_banned(user_id));
CREATE POLICY svc_portfolio_insert ON public.svc_portfolio FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid() AND NOT public.svc_user_banned(auth.uid())
              AND public.svc_portfolio_count(auth.uid()) < 12);
CREATE POLICY svc_portfolio_update ON public.svc_portfolio FOR UPDATE TO authenticated
  USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
CREATE POLICY svc_portfolio_delete ON public.svc_portfolio FOR DELETE TO authenticated
  USING (user_id = auth.uid());

-- ══════════════════════════════════════════════════════════════════════════
-- 2. KYC — ปิดที่สุดเท่าที่ทำได้
-- ══════════════════════════════════════════════════════════════════════════
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS kyc_status text NOT NULL DEFAULT 'none'
    CHECK (kyc_status IN ('none','pending','verified','rejected')),
  ADD COLUMN IF NOT EXISTS kyc_verified_at timestamptz;

CREATE TABLE IF NOT EXISTS public.kyc_requests (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name     text NOT NULL CHECK (length(btrim(full_name)) BETWEEN 2 AND 120),
  doc_type      text NOT NULL CHECK (doc_type IN ('id_card','passport','driver','family_book')),
  -- 🔴 4 ตัวท้ายเท่านั้น — เลขเต็มไม่มีเหตุผลต้องเก็บ และเป็นสิ่งที่ทำให้ข้อมูลรั่วมีค่าสำหรับคนขโมย
  doc_last4     text NOT NULL DEFAULT '' CHECK (doc_last4 ~ '^[0-9]{0,4}$'),
  -- path ใน bucket 'kyc' (private) · ว่างหลังตรวจเสร็จเพราะไฟล์ถูกลบทิ้ง
  files         text[] NOT NULL DEFAULT '{}' CHECK (coalesce(array_length(files,1),0) <= 3),
  status        text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','approved','rejected')),
  note          text NOT NULL DEFAULT '' CHECK (length(note) <= 300),
  reject_reason text NOT NULL DEFAULT '' CHECK (length(reject_reason) <= 300),
  reviewed_by   uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  reviewed_at   timestamptz,
  created_at    timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS kyc_requests_status_idx ON public.kyc_requests (status, created_at);
-- ส่งค้างได้ทีละใบเท่านั้น
CREATE UNIQUE INDEX IF NOT EXISTS kyc_requests_one_pending_idx
  ON public.kyc_requests (user_id) WHERE status = 'pending';

ALTER TABLE public.kyc_requests ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON public.kyc_requests TO authenticated;
-- ไม่ให้ INSERT/UPDATE ตรง — ผ่าน RPC เท่านั้น (สถานะกับการลบไฟล์ต้องเดินคู่กันเสมอ)

-- ⚠️ ใช้ `public.is_admin_user(uuid)` ที่ **มีอยู่แล้วในระบบ** ไม่สร้างใหม่และไม่เขียนทับ
--    ของเดิมคืน profiles.is_admin เหมือนกันทุกอย่าง และมี 5 policy (profiles/user_activity/
--    admin_messages) กับฟังก์ชัน protect_profile_privileges ใช้อยู่ ⇒ แตะแล้วพังเป็นวงกว้าง
--    (พารามิเตอร์ของเดิมชื่อ `uid` — CREATE OR REPLACE ที่เปลี่ยนชื่อพารามิเตอร์จะ error ทันที
--     ซึ่งเป็นสิ่งที่ช่วยจับได้ว่ากำลังจะทับของเดิม)

DROP POLICY IF EXISTS kyc_requests_read ON public.kyc_requests;
-- เจ้าของเห็นของตัวเอง · แอดมินเห็นทุกใบ · คนอื่นไม่เห็นอะไรเลย
CREATE POLICY kyc_requests_read ON public.kyc_requests FOR SELECT TO authenticated
  USING (user_id = auth.uid() OR public.is_admin_user(auth.uid()));

-- ── bucket 'kyc' : private ────────────────────────────────────────────────
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('kyc', 'kyc', false, 4194304, '{image/jpeg,image/png,image/webp}')
ON CONFLICT (id) DO UPDATE
  SET public = false, file_size_limit = 4194304,
      allowed_mime_types = '{image/jpeg,image/png,image/webp}';

DROP POLICY IF EXISTS kyc_obj_read   ON storage.objects;
DROP POLICY IF EXISTS kyc_obj_write  ON storage.objects;
DROP POLICY IF EXISTS kyc_obj_del    ON storage.objects;
-- อ่าน: เจ้าของไฟล์ หรือ แอดมิน — ไม่มี public เด็ดขาด (ต่างจาก svc_obj_read ที่เปิด public)
CREATE POLICY kyc_obj_read ON storage.objects FOR SELECT TO authenticated
  USING (bucket_id = 'kyc'
         AND ((storage.foldername(name))[1] = auth.uid()::text OR public.is_admin_user(auth.uid())));
CREATE POLICY kyc_obj_write ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'kyc' AND (storage.foldername(name))[1] = auth.uid()::text);
CREATE POLICY kyc_obj_del ON storage.objects FOR DELETE TO authenticated
  USING (bucket_id = 'kyc'
         AND ((storage.foldername(name))[1] = auth.uid()::text OR public.is_admin_user(auth.uid())));

-- ── RPC ───────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.kyc_submit(
  p_full_name text, p_doc_type text, p_last4 text, p_files text[], p_note text DEFAULT ''
)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_me uuid := auth.uid(); v_id uuid; v_f text;
BEGIN
  IF v_me IS NULL THEN RAISE EXCEPTION 'unauthenticated'; END IF;
  IF svc_user_banned(v_me) THEN RAISE EXCEPTION 'banned'; END IF;
  IF coalesce(array_length(p_files,1),0) < 1 THEN RAISE EXCEPTION 'need_file'; END IF;
  IF (SELECT kyc_status FROM profiles WHERE id = v_me) = 'verified' THEN RAISE EXCEPTION 'already_verified'; END IF;
  -- ทุกไฟล์ต้องอยู่ในโฟลเดอร์ของผู้ส่งเอง — กันแนบ path ของคนอื่นมาให้แอดมินเปิดดู
  FOREACH v_f IN ARRAY p_files LOOP
    IF position(v_me::text || '/' in v_f) <> 1 THEN RAISE EXCEPTION 'bad_path'; END IF;
  END LOOP;

  INSERT INTO kyc_requests (user_id, full_name, doc_type, doc_last4, files, note)
  VALUES (v_me, btrim(p_full_name), p_doc_type,
          coalesce(regexp_replace(coalesce(p_last4,''), '[^0-9]', '', 'g'), ''),
          p_files, left(coalesce(btrim(p_note),''), 300))
  RETURNING id INTO v_id;

  UPDATE profiles SET kyc_status = 'pending' WHERE id = v_me;
  RETURN v_id;
END $$;

-- แอดมินตัดสิน — สถานะกับการลบไฟล์ต้องเกิดพร้อมกันเสมอ จึงรวมไว้ในฟังก์ชันเดียว
-- คืน list ของ path ที่ต้องลบ ให้ฝั่งแอปเรียก storage API ลบต่อ (ลบ storage.objects ตรงๆ ถูกบล็อกโดย
-- storage.protect_delete ซึ่งเป็นการป้องกันที่ถูกต้อง — ไม่ควรหาทางข้าม)
CREATE OR REPLACE FUNCTION public.kyc_review(p_req uuid, p_approve boolean, p_reason text DEFAULT '')
RETURNS text[] LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_me uuid := auth.uid(); v_r kyc_requests%ROWTYPE;
BEGIN
  IF v_me IS NULL THEN RAISE EXCEPTION 'unauthenticated'; END IF;
  IF NOT is_admin_user(v_me) THEN RAISE EXCEPTION 'not_admin'; END IF;
  SELECT * INTO v_r FROM kyc_requests WHERE id = p_req FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'not_found'; END IF;
  IF v_r.status <> 'pending' THEN RAISE EXCEPTION 'already_reviewed'; END IF;

  UPDATE kyc_requests SET
    status = CASE WHEN p_approve THEN 'approved' ELSE 'rejected' END,
    reject_reason = CASE WHEN p_approve THEN '' ELSE left(coalesce(btrim(p_reason),''), 300) END,
    reviewed_by = v_me, reviewed_at = now(),
    files = '{}'                      -- 🔴 ล้าง path ทิ้งพร้อมกัน ไฟล์จริงถูกลบโดยผู้เรียก
  WHERE id = p_req;

  UPDATE profiles SET
    kyc_status = CASE WHEN p_approve THEN 'verified' ELSE 'rejected' END,
    kyc_verified_at = CASE WHEN p_approve THEN now() ELSE NULL END
  WHERE id = v_r.user_id;

  INSERT INTO friend_notifications (sender_id, recipient_id, type, body, metadata)
  VALUES (v_me, v_r.user_id, CASE WHEN p_approve THEN 'svc_kyc_ok' ELSE 'svc_kyc_no' END,
          left(coalesce(p_reason,''), 200), jsonb_build_object('kyc', true));

  RETURN v_r.files;
END $$;

-- รายการรอตรวจสำหรับแอดมิน (คืนข้อมูลเท่าที่ต้องใช้ตัดสิน)
CREATE OR REPLACE FUNCTION public.kyc_pending()
RETURNS TABLE (id uuid, user_id uuid, display_name text, full_name text, doc_type text,
               doc_last4 text, files text[], note text, created_at timestamptz)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT r.id, r.user_id, coalesce(p.display_name, p.username, ''), r.full_name, r.doc_type,
         r.doc_last4, r.files, r.note, r.created_at
  FROM kyc_requests r JOIN profiles p ON p.id = r.user_id
  WHERE r.status = 'pending' AND is_admin_user(auth.uid())
  ORDER BY r.created_at
  LIMIT 100;
$$;

ALTER TABLE public.friend_notifications DROP CONSTRAINT IF EXISTS friend_notifications_type_check;
ALTER TABLE public.friend_notifications ADD CONSTRAINT friend_notifications_type_check
  CHECK (type IN ('reminder','paid_notify','paid_confirmed','message','svc_interest',
                  'svc_job_offer','svc_job_accepted','svc_job_done','svc_review',
                  'svc_kyc_ok','svc_kyc_no'));

-- ══════════════════════════════════════════════════════════════════════════
-- 3. เครื่องหมายยืนยันตัวตนไปโผล่ในที่ที่คนตัดสินใจจ้าง
-- ══════════════════════════════════════════════════════════════════════════
DROP FUNCTION IF EXISTS public.svc_feed(text, text, numeric, integer);
CREATE FUNCTION public.svc_feed(
  p_side text, p_cat text DEFAULT NULL, p_min_rating numeric DEFAULT NULL, p_limit integer DEFAULT 200
)
RETURNS TABLE (
  id uuid, user_id uuid, side text, category text, title text, detail text,
  price bigint, price_unit text, area text, contact text, status text,
  images text[], lat double precision, lng double precision, created_at timestamptz,
  owner_name text, owner_rating numeric, owner_rating_count integer, owner_jobs_done integer,
  owner_verified boolean
)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT p.id, p.user_id, p.side, p.category, p.title, p.detail,
         p.price, p.price_unit, p.area, p.contact, p.status,
         p.images, p.lat, p.lng, p.created_at,
         coalesce(o.display_name, o.username, ''), o.svc_rating, o.svc_rating_count, o.svc_jobs_done,
         (o.kyc_status = 'verified')
  FROM svc_posts p
  JOIN profiles o ON o.id = p.user_id
  WHERE p.status = 'open' AND o.is_banned IS NOT TRUE AND p.side = p_side
    AND (p_cat IS NULL OR p_cat = '' OR p.category = p_cat)
    AND (p_min_rating IS NULL OR (o.svc_rating_count >= 3 AND o.svc_rating >= p_min_rating))
  ORDER BY p.created_at DESC
  LIMIT greatest(1, least(coalesce(p_limit, 200), 200));
$$;

DROP FUNCTION IF EXISTS public.svc_public_profile(uuid);
CREATE FUNCTION public.svc_public_profile(p_user uuid)
RETURNS TABLE (display_name text, svc_rating numeric, svc_rating_count integer,
               svc_jobs_done integer, verified boolean)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT coalesce(p.display_name, p.username, ''), p.svc_rating, p.svc_rating_count,
         p.svc_jobs_done, (p.kyc_status = 'verified')
  FROM profiles p WHERE p.id = p_user AND p.is_banned IS NOT TRUE;
$$;

-- ผลงานสาธารณะของผู้ใช้คนหนึ่ง — ใช้ตอนดูประกาศก่อนตัดสินใจจ้าง
CREATE OR REPLACE FUNCTION public.svc_user_portfolio(p_user uuid, p_limit integer DEFAULT 12)
RETURNS TABLE (id uuid, title text, detail text, category text, year smallint,
               images text[], created_at timestamptz)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT w.id, w.title, w.detail, w.category, w.year, w.images, w.created_at
  FROM svc_portfolio w JOIN profiles p ON p.id = w.user_id
  WHERE w.user_id = p_user AND p.is_banned IS NOT TRUE
  ORDER BY coalesce(w.year, 0) DESC, w.created_at DESC
  LIMIT greatest(1, least(coalesce(p_limit, 12), 12));
$$;

REVOKE ALL ON FUNCTION public.kyc_submit(text, text, text, text[], text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.kyc_review(uuid, boolean, text)            FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.kyc_pending()                              FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.kyc_submit(text, text, text, text[], text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.kyc_review(uuid, boolean, text)            TO authenticated;
GRANT EXECUTE ON FUNCTION public.kyc_pending()                              TO authenticated;
GRANT EXECUTE ON FUNCTION public.svc_feed(text, text, numeric, integer)     TO authenticated;
GRANT EXECUTE ON FUNCTION public.svc_public_profile(uuid)                   TO authenticated;
GRANT EXECUTE ON FUNCTION public.svc_user_portfolio(uuid, integer)          TO authenticated;
GRANT EXECUTE ON FUNCTION public.svc_portfolio_count(uuid)                  TO authenticated;

NOTIFY pgrst, 'reload schema';

-- ── ตรวจย้อนหลัง ───────────────────────────────────────────────────────────
--  ต้องได้ 0 เสมอ — ไม่มีไฟล์ KYC ค้างจากใบที่ตรวจแล้ว:
--    select count(*) from storage.objects o where o.bucket_id='kyc'
--      and not exists (select 1 from kyc_requests r where r.status='pending' and o.name = any(r.files));
--  ใครยืนยันตัวตนแล้วบ้าง:
--    select left(id::text,8), display_name, kyc_status, kyc_verified_at from profiles where kyc_status <> 'none';

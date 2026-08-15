-- v3.7.451 — ຮັບເຮັດ: 3 อย่างที่ค้างไว้จาก v3.7.450 (เจ้าของ: "ทำต่อเลย ทั้ง 3 อย่างที่เสนอ")
--   1. แจ้งเตือนเด้งมือถือเมื่อมีใบงาน/ถูกรีวิว
--   2. ปิดใบงานที่ค้างรอตอบรับเกิน 7 วันอัตโนมัติ
--   3. กรองประกาศตามดาวขั้นต่ำ (+ แสดงดาวในการ์ดลิสต์)

-- ══════════════════════════════════════════════════════════════════════════
-- 1. push — trigger บน friend_notifications → edge function send-svc-push
-- ══════════════════════════════════════════════════════════════════════════
-- แนวเดียวกับ trg_notify_new_pos_order แต่ **ยิงตรงเข้า container ของ edge functions
-- ไม่ผ่าน kong** เพราะ kong ต้องมี apikey ⇒ trigger เดิมจึงต้องฝัง anon key ไว้ในตัวฟังก์ชัน
-- ยิงตรงแล้วไม่ต้องมีคีย์ที่ไหนเลย (ทดสอบแล้วได้ HTTP 200 จาก db container)
-- แลกกับการผูกชื่อ container 'supabase-edge-functions' — เปลี่ยนชื่อคอนเทนเนอร์เมื่อไหร่ต้องแก้ที่นี่
-- (ของเดิมก็ผูกกับชื่อ 'kong' เหมือนกัน)
--
-- ⚠️ WHEN กรองที่ตัว trigger ไม่ใช่ในฟังก์ชัน ⇒ notification ประเภทอื่น (message/reminder/iou)
--    ไม่ถูกยิงเลยแม้แต่ครั้งเดียว ไม่เปลืองและไม่เปลี่ยนพฤติกรรมของเดิม
CREATE OR REPLACE FUNCTION public.notify_svc_push()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  PERFORM net.http_post(
    url := 'http://supabase-edge-functions:9000/send-svc-push',
    headers := jsonb_build_object('Content-Type', 'application/json'),
    body := jsonb_build_object('record', to_jsonb(NEW))
  );
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_notify_svc ON public.friend_notifications;
CREATE TRIGGER trg_notify_svc AFTER INSERT ON public.friend_notifications
  FOR EACH ROW WHEN (NEW.type LIKE 'svc\_%')
  EXECUTE FUNCTION public.notify_svc_push();

-- ══════════════════════════════════════════════════════════════════════════
-- 2. ปิดใบงานที่ค้าง 'proposed' เกิน 7 วัน
-- ══════════════════════════════════════════════════════════════════════════
-- ทำไมต้องมี: ใบงานที่ไม่มีใครตอบจะค้างเป็น 'proposed' ตลอดกาล และ unique index
-- svc_jobs_open_pair_idx จะบล็อกไม่ให้เปิดใบใหม่กับคนเดิมบนประกาศเดิมไปด้วย
-- ⇒ กลายเป็น "ล็อกถาวรจากงานที่ไม่เคยเกิด"
-- ใช้ cancelled_by = NULL เป็นเครื่องหมายว่า "ระบบปิดให้" ไม่ใช่คนกด
CREATE OR REPLACE FUNCTION public.svc_expire_stale_jobs()
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE n integer;
BEGIN
  UPDATE svc_jobs SET status = 'cancelled', cancelled_at = now(), cancelled_by = NULL
  WHERE status = 'proposed' AND created_at < now() - interval '7 days';
  GET DIAGNOSTICS n = ROW_COUNT;
  RETURN n;
END $$;

SELECT cron.schedule('svc-expire-jobs', '30 2 * * *', $$SELECT public.svc_expire_stale_jobs();$$)
WHERE NOT EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'svc-expire-jobs');

-- ══════════════════════════════════════════════════════════════════════════
-- 3. ฟีดที่มีดาวของผู้ลงประกาศ + กรองตามดาวขั้นต่ำ
-- ══════════════════════════════════════════════════════════════════════════
-- ทำไมต้องเป็น RPC: RLS ของ profiles ไม่เปิดให้อ่านโปรไฟล์คนแปลกหน้า ⇒ ไคลเอนต์ join เองไม่ได้
-- และการยิงถามดาวทีละใบ (200 ใบ) บนเน็ตลาวคือฆ่าตัวตาย
--
-- 🔴 p_min_rating กรอง "เฉพาะคนที่มีดาวจริง" — คนที่ยังไม่ถึง 3 รีวิว (แอปแสดงป้าย "ໃໝ່")
--    ต้องถูกกรองออกด้วยเมื่อผู้ใช้เลือกกรองดาว ไม่งั้นคนใหม่จะปนมาในผลลัพธ์ "4 ดาวขึ้นไป"
--    ซึ่งหลอกคนกรอง · เกณฑ์ 3 รีวิวต้องตรงกับ SVC_RATING_MIN ในแอป
CREATE OR REPLACE FUNCTION public.svc_feed(
  p_side text, p_cat text DEFAULT NULL, p_min_rating numeric DEFAULT NULL, p_limit integer DEFAULT 200
)
RETURNS TABLE (
  id uuid, user_id uuid, side text, category text, title text, detail text,
  price bigint, price_unit text, area text, contact text, status text,
  images text[], lat double precision, lng double precision, created_at timestamptz,
  owner_name text, owner_rating numeric, owner_rating_count integer, owner_jobs_done integer
)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT p.id, p.user_id, p.side, p.category, p.title, p.detail,
         p.price, p.price_unit, p.area, p.contact, p.status,
         p.images, p.lat, p.lng, p.created_at,
         coalesce(o.display_name, o.username, ''), o.svc_rating, o.svc_rating_count, o.svc_jobs_done
  FROM svc_posts p
  JOIN profiles o ON o.id = p.user_id
  WHERE p.status = 'open'
    AND o.is_banned IS NOT TRUE
    AND p.side = p_side
    AND (p_cat IS NULL OR p_cat = '' OR p.category = p_cat)
    AND (p_min_rating IS NULL
         OR (o.svc_rating_count >= 3 AND o.svc_rating >= p_min_rating))
  ORDER BY p.created_at DESC
  LIMIT greatest(1, least(coalesce(p_limit, 200), 200));
$$;

REVOKE ALL ON FUNCTION public.svc_feed(text, text, numeric, integer) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.svc_expire_stale_jobs()                FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.svc_feed(text, text, numeric, integer) TO authenticated;

NOTIFY pgrst, 'reload schema';

-- ── ตรวจย้อนหลัง ───────────────────────────────────────────────────────────
--  cron ทำงานไหม:  select * from cron.job_run_details where jobid=(select jobid from cron.job where jobname='svc-expire-jobs') order by start_time desc limit 5;
--  ใบงานที่ระบบปิดให้ (ไม่ใช่คนกด):  select id, title from svc_jobs where status='cancelled' and cancelled_by is null;
--  push ยิงออกไหม:  select * from net._http_response order by id desc limit 5;

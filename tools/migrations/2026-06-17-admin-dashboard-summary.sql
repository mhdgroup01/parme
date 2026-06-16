-- ============================================================
-- Paruay — admin_dashboard_summary RPC (FINAL, ready to run)
-- 2026-06-17
--
-- รวม + แก้บั๊กจาก draft ใน pending/:
--   pending/2026-06-16-admin-dashboard-summary.sql      (Phase A — aggregates)
--   pending/2026-06-16-admin-dashboard-summary-v2.sql   (Phase B — +charts)
--
-- บั๊กที่แก้ในไฟล์นี้ (เทียบ v2):
--   • hourly / weekday เดิมใช้ GROUP BY ตรง ๆ → ได้ array ความยาวไม่คงที่
--     (ชั่วโมง/วันที่ไม่มี event จะหายไป). client ต้องการ length === 24 / === 7
--     เป๊ะ ไม่งั้น fallback ไป client-compute เสมอ.
--     → แก้ด้วย generate_series(0,23)/(0,6) + LEFT JOIN เติม 0 ให้ครบทุก bucket.
--   • เพิ่ม STABLE (function อ่านอย่างเดียว → optimizer hint)
--   • เพิ่ม composite index ช่วย DISTINCT ON (user_id) … ORDER BY created_at DESC
--
-- หมายเหตุ: client (index.html) wire ไว้แล้วตั้งแต่ v3.7.50:
--   supabase.rpc('admin_dashboard_summary', { p_since }) + graceful fallback
--   → รัน SQL นี้เสร็จ admin dashboard จะ aggregate ฝั่ง server ครอบทุก row ทันที
--   (ไม่ต้องแก้/deploy client เพิ่ม)
--
-- ความปลอดภัย: SECURITY DEFINER (bypass RLS) → มี admin-gate ในตัว
--   (เช็ค profiles.is_admin ของ auth.uid() ก่อน ไม่งั้น RAISE 'not_admin')
--   GRANT EXECUTE เฉพาะ authenticated; REVOKE จาก public/anon
--
-- TZ: Asia/Bangkok (= Vientiane +7) ให้ peak hour / daily bucket ตรงเวลา local
--   และตรงกับ client (ที่ bucket ด้วย local date)
-- ============================================================

CREATE OR REPLACE FUNCTION public.admin_dashboard_summary(p_since timestamptz)
RETURNS json
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_is_admin boolean;
  result json;
BEGIN
  -- ── admin gate (สำคัญ: function นี้ bypass RLS) ──
  SELECT COALESCE(is_admin, false) INTO v_is_admin
    FROM public.profiles WHERE id = auth.uid();
  IF NOT COALESCE(v_is_admin, false) THEN
    RAISE EXCEPTION 'not_admin';
  END IF;

  SELECT json_build_object(
    -- ── KPI (rolling windows — ตรงกับ client fallback: now - ts < DAY/7d/30d) ──
    'dau', (SELECT COUNT(DISTINCT user_id) FROM public.user_activity
              WHERE created_at >= now() - interval '1 day'),
    'wau', (SELECT COUNT(DISTINCT user_id) FROM public.user_activity
              WHERE created_at >= now() - interval '7 days'),
    'mau', (SELECT COUNT(DISTINCT user_id) FROM public.user_activity
              WHERE created_at >= now() - interval '30 days'),
    'total_events', (SELECT COUNT(*) FROM public.user_activity
              WHERE created_at >= p_since),
    'total_users', (SELECT COUNT(*) FROM public.profiles),
    'new_users_today', (SELECT COUNT(*) FROM public.profiles
              WHERE created_at >= now() - interval '1 day'),
    'new_users_week', (SELECT COUNT(*) FROM public.profiles
              WHERE created_at >= now() - interval '7 days'),

    'top_actions', (SELECT COALESCE(json_agg(row_to_json(t)), '[]'::json) FROM (
        SELECT event_type, COUNT(*) AS n FROM public.user_activity
          WHERE created_at >= p_since
          GROUP BY event_type ORDER BY n DESC LIMIT 10
      ) t),
    'top_countries', (SELECT COALESCE(json_agg(row_to_json(c)), '[]'::json) FROM (
        SELECT COALESCE(country,'—') AS country, COUNT(*) AS n
          FROM public.user_activity
          WHERE created_at >= p_since
          GROUP BY COALESCE(country,'—') ORDER BY n DESC LIMIT 8
      ) c),

    -- ── chart data (dense: เติม 0 ให้ครบทุก bucket) ──
    'hourly', (SELECT COALESCE(json_agg(n ORDER BY h), '[]'::json) FROM (
        SELECT g.h AS h, COALESCE(c.n, 0)::int AS n
          FROM generate_series(0, 23) AS g(h)
          LEFT JOIN (
            SELECT EXTRACT(HOUR FROM (created_at AT TIME ZONE 'Asia/Bangkok'))::int AS h,
                   COUNT(*)::int AS n
              FROM public.user_activity
              WHERE created_at >= p_since
              GROUP BY 1
          ) c ON c.h = g.h
      ) hr),
    'weekday', (SELECT COALESCE(json_agg(n ORDER BY d), '[]'::json) FROM (
        SELECT g.d AS d, COALESCE(c.n, 0)::int AS n
          FROM generate_series(0, 6) AS g(d)
          LEFT JOIN (
            SELECT EXTRACT(DOW FROM (created_at AT TIME ZONE 'Asia/Bangkok'))::int AS d,
                   COUNT(*)::int AS n
              FROM public.user_activity
              WHERE created_at >= p_since
              GROUP BY 1
          ) c ON c.d = g.d
      ) wk),
    'daily', (SELECT COALESCE(json_agg(row_to_json(d) ORDER BY day), '[]'::json) FROM (
        SELECT (created_at AT TIME ZONE 'Asia/Bangkok')::date AS day, COUNT(*)::int AS events
          FROM public.user_activity
          WHERE created_at >= p_since
          GROUP BY 1
      ) d),
    'new_users_daily', (SELECT COALESCE(json_agg(row_to_json(d) ORDER BY day), '[]'::json) FROM (
        SELECT (created_at AT TIME ZONE 'Asia/Bangkok')::date AS day, COUNT(*)::int AS n
          FROM public.profiles
          WHERE created_at >= p_since
          GROUP BY 1
      ) d),

    -- ── per-user maps (ครอบทุก row ใน window) ──
    'user_geo', (SELECT COALESCE(json_agg(row_to_json(g)), '[]'::json) FROM (
        SELECT DISTINCT ON (user_id)
            user_id,
            latitude AS lat,
            longitude AS lng,
            COALESCE(country,'—') AS country,
            city
          FROM public.user_activity
          WHERE created_at >= p_since
            AND latitude IS NOT NULL AND longitude IS NOT NULL
          ORDER BY user_id, created_at DESC
      ) g),
    'events_by_user', (SELECT COALESCE(json_object_agg(user_id::text, n), '{}'::json) FROM (
        SELECT user_id, COUNT(*)::int AS n FROM public.user_activity
          WHERE created_at >= p_since AND user_id IS NOT NULL
          GROUP BY user_id
      ) e),
    'user_last_seen', (SELECT COALESCE(json_object_agg(user_id::text, last_ts), '{}'::json) FROM (
        SELECT user_id, MAX(created_at) AS last_ts FROM public.user_activity
          WHERE created_at >= p_since AND user_id IS NOT NULL
          GROUP BY user_id
      ) l),
    'user_country', (SELECT COALESCE(json_object_agg(user_id::text, country), '{}'::json) FROM (
        SELECT DISTINCT ON (user_id) user_id, COALESCE(country,'—') AS country
          FROM public.user_activity
          WHERE created_at >= p_since AND user_id IS NOT NULL AND country IS NOT NULL
          ORDER BY user_id, created_at DESC
      ) c)
  ) INTO result;

  RETURN result;
END;
$$;

-- ── permissions ──
REVOKE ALL ON FUNCTION public.admin_dashboard_summary(timestamptz) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.admin_dashboard_summary(timestamptz) TO authenticated;

-- ── index ช่วยความเร็ว (DISTINCT ON user_id + GROUP BY user_id + ORDER created_at DESC) ──
-- (มี BRIN index บน created_at อยู่แล้วจาก 2026-06-15-research-indexes.sql)
CREATE INDEX IF NOT EXISTS idx_user_activity_user_created
  ON public.user_activity (user_id, created_at DESC);

-- ============================================================
-- ทดสอบ (รันในฐานะ admin user — ต้อง login JWT ของ admin)
-- ============================================================
-- SELECT admin_dashboard_summary((now() - interval '365 days')::timestamptz);
--
-- ตรวจว่า:
--   • hourly เป็น array ยาว 24 (เช่น [0,0,3,12,...])  ← ถ้ายาวไม่ครบ 24 = บั๊กยังอยู่
--   • weekday เป็น array ยาว 7
--   • daily / new_users_daily เป็น [{day, events|n}, ...]
--   • top_countries เป็น [{country, n}, ...]
--   • user_geo เป็น [{user_id, lat, lng, country, city}, ...]
--   • events_by_user / user_last_seen / user_country เป็น object { "<uuid>": ... }
--
-- ทดสอบ admin-gate (รันในฐานะ non-admin) ต้องได้ error 'not_admin':
-- SELECT admin_dashboard_summary(now());
-- ============================================================

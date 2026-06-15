-- ============================================================
-- Paruay v3.7.53 — admin_dashboard_summary RPC v2 (Phase B)
-- 2026-06-16
--
-- ขยายจาก v3.7.50 (Phase A) — เพิ่ม fields สำหรับ chart ทั้งหมด:
--   hourly[24], weekday[7], daily[365], user_geo[], events_by_user{}, recent[]
-- ทำให้ทุก stat ใน AdminDashboard ครอบทุก row ใน DB (ไม่จำกัด 10k)
-- ============================================================

CREATE OR REPLACE FUNCTION public.admin_dashboard_summary(p_since timestamptz)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_is_admin boolean;
  result json;
BEGIN
  SELECT COALESCE(is_admin, false) INTO v_is_admin
    FROM public.profiles WHERE id = auth.uid();
  IF NOT COALESCE(v_is_admin, false) THEN
    RAISE EXCEPTION 'not_admin';
  END IF;

  SELECT json_build_object(
    -- aggregates (Phase A)
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
          GROUP BY country ORDER BY n DESC LIMIT 8
      ) c),

    -- Phase B: chart data (server-side, ครอบทุก row)
    'hourly', (SELECT COALESCE(json_agg(n ORDER BY h), '[]'::json) FROM (
        SELECT EXTRACT(HOUR FROM created_at)::int AS h, COUNT(*)::int AS n
          FROM public.user_activity
          WHERE created_at >= p_since
          GROUP BY 1
      ) hr),
    'weekday', (SELECT COALESCE(json_agg(n ORDER BY d), '[]'::json) FROM (
        SELECT EXTRACT(DOW FROM created_at)::int AS d, COUNT(*)::int AS n
          FROM public.user_activity
          WHERE created_at >= p_since
          GROUP BY 1
      ) wk),
    'daily', (SELECT COALESCE(json_agg(row_to_json(d) ORDER BY day), '[]'::json) FROM (
        SELECT date_trunc('day', created_at)::date AS day, COUNT(*)::int AS events
          FROM public.user_activity
          WHERE created_at >= p_since
          GROUP BY 1
      ) d),
    'new_users_daily', (SELECT COALESCE(json_agg(row_to_json(d) ORDER BY day), '[]'::json) FROM (
        SELECT date_trunc('day', created_at)::date AS day, COUNT(*)::int AS n
          FROM public.profiles
          WHERE created_at >= p_since
          GROUP BY 1
      ) d),
    'user_geo', (SELECT COALESCE(json_agg(row_to_json(g)), '[]'::json) FROM (
        SELECT DISTINCT ON (user_id)
            user_id,
            latitude AS lat,
            longitude AS lng,
            COALESCE(country,'—') AS country,
            city
          FROM public.user_activity
          WHERE created_at >= p_since AND latitude IS NOT NULL AND longitude IS NOT NULL
          ORDER BY user_id, created_at DESC
      ) g),
    'events_by_user', (SELECT COALESCE(json_object_agg(user_id::text, n), '{}'::json) FROM (
        SELECT user_id, COUNT(*)::int AS n FROM public.user_activity
          WHERE created_at >= p_since
          GROUP BY user_id
      ) e),
    'user_last_seen', (SELECT COALESCE(json_object_agg(user_id::text, last_ts), '{}'::json) FROM (
        SELECT user_id, MAX(created_at) AS last_ts FROM public.user_activity
          WHERE created_at >= p_since
          GROUP BY user_id
      ) l),
    'user_country', (SELECT COALESCE(json_object_agg(user_id::text, country), '{}'::json) FROM (
        SELECT DISTINCT ON (user_id) user_id, COALESCE(country,'—') AS country
          FROM public.user_activity
          WHERE created_at >= p_since AND country IS NOT NULL
          ORDER BY user_id, created_at DESC
      ) c),
    'recent', (SELECT COALESCE(json_agg(row_to_json(r)), '[]'::json) FROM (
        SELECT * FROM public.user_activity
          WHERE created_at >= p_since
          ORDER BY created_at DESC
          LIMIT 5000
      ) r)
  ) INTO result;

  RETURN result;
END;
$$;

REVOKE ALL ON FUNCTION public.admin_dashboard_summary(timestamptz) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.admin_dashboard_summary(timestamptz) TO authenticated;

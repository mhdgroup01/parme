-- ============================================================
-- Paruay v3.7.50 — admin_dashboard_summary RPC (Phase A: additive)
-- 2026-06-16
--
-- ปัญหา: AdminDashboard derive DAU/MAU/total events จาก raw user_activity ที่ดึงด้วย .limit(10000)
-- → ระบบที่มี > 10k events เห็นยอด DAU/MAU **ผิดเงียบๆ** (correctness bug แบบเดียวกับ v3.7.40)
--
-- แก้ Phase A: server-side aggregate (ครอบทุก row ใน DB ไม่จำกัด)
-- - ไม่กระทบ download/map/CSV/chart เดิม (Phase B ทำทีหลังเมื่อ M ตัดสินใจ design)
-- - SECURITY DEFINER + is_admin gate (ป้องกัน user ทั่วไป)
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
        SELECT event_type, COUNT(*) AS n
          FROM public.user_activity
          WHERE created_at >= p_since
          GROUP BY event_type ORDER BY n DESC LIMIT 10
      ) t),
    'top_countries', (SELECT COALESCE(json_agg(row_to_json(c)), '[]'::json) FROM (
        SELECT COALESCE(country,'—') AS country, COUNT(*) AS n
          FROM public.user_activity
          WHERE created_at >= p_since
          GROUP BY country ORDER BY n DESC LIMIT 8
      ) c)
  ) INTO result;

  RETURN result;
END;
$$;

REVOKE ALL ON FUNCTION public.admin_dashboard_summary(timestamptz) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.admin_dashboard_summary(timestamptz) TO authenticated;

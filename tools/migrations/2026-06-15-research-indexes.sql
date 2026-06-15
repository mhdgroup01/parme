-- ============================================================
-- Paruay — Research-backed index audit (2026-06-15)
-- Source: workflow "paruay-research-application" (52 agents, adversarial-verified)
-- Backed by: ~/Desktop/DemoVault/wiki/concepts/database-cost-optimization.md
--
-- หมายเหตุ: Supabase SQL editor ห่อ query เป็น transaction → CONCURRENTLY ใช้ไม่ได้
-- ใช้ CREATE INDEX ธรรมดา (lock table เขียนชั่วครู่ขณะ build — Paruay table เล็กพอ ไม่กระทบ)
-- paste ทั้งไฟล์ใน SQL editor → Run ครั้งเดียวได้เลย
-- ============================================================


-- ============================================================
-- ส่วนที่ 1 — Family hot path (RLS predicates)
-- ============================================================

CREATE INDEX IF NOT EXISTS family_transactions_family_created_idx
  ON public.family_transactions (family_id, created_at DESC);

CREATE INDEX IF NOT EXISTS family_messages_family_created_desc_idx
  ON public.family_messages (family_id, created_at DESC) INCLUDE (user_id);

CREATE INDEX IF NOT EXISTS family_ious_family_created_idx
  ON public.family_ious (family_id, created_at DESC);

CREATE INDEX IF NOT EXISTS family_members_user_idx
  ON public.family_members (user_id) INCLUDE (family_id, role);

CREATE INDEX IF NOT EXISTS family_members_family_idx
  ON public.family_members (family_id);


-- ============================================================
-- ส่วนที่ 2 — Friendships + Trips (.or() patterns)
-- ============================================================

CREATE INDEX IF NOT EXISTS friendships_user_a_idx
  ON public.friendships (user_a);

CREATE INDEX IF NOT EXISTS friendships_user_b_idx
  ON public.friendships (user_b);

CREATE INDEX IF NOT EXISTS friendships_accepted_a_idx
  ON public.friendships (user_a) WHERE status = 'accepted';

CREATE INDEX IF NOT EXISTS friendships_accepted_b_idx
  ON public.friendships (user_b) WHERE status = 'accepted';

CREATE INDEX IF NOT EXISTS trip_settlements_from_idx
  ON public.trip_settlements (from_user);

CREATE INDEX IF NOT EXISTS trip_settlements_to_idx
  ON public.trip_settlements (to_user);

CREATE INDEX IF NOT EXISTS trip_expenses_paid_by_idx
  ON public.trip_expenses (paid_by);

CREATE INDEX IF NOT EXISTS trip_expenses_created_by_idx
  ON public.trip_expenses (created_by);

CREATE INDEX IF NOT EXISTS trip_expenses_trip_date_idx
  ON public.trip_expenses (trip_id, date DESC);

CREATE INDEX IF NOT EXISTS trip_settlements_trip_created_idx
  ON public.trip_settlements (trip_id, created_at DESC);

CREATE INDEX IF NOT EXISTS trip_members_user_idx
  ON public.trip_members (user_id);

CREATE INDEX IF NOT EXISTS trip_members_trip_idx
  ON public.trip_members (trip_id);

CREATE INDEX IF NOT EXISTS ious_counterparty_pending_idx
  ON public.ious (counterparty_user_id) WHERE shared_status = 'pending';

CREATE INDEX IF NOT EXISTS trip_settlements_to_pending_idx
  ON public.trip_settlements (to_user) WHERE status = 'pending';


-- ============================================================
-- ส่วนที่ 3 — POS + Transactions + Admin
-- ============================================================

CREATE INDEX IF NOT EXISTS pos_sales_shop_recent_idx
  ON public.pos_sales (shop, created_at DESC) INCLUDE (total, cost_total);

CREATE INDEX IF NOT EXISTS pos_products_shop_idx
  ON public.pos_products (shop);

CREATE INDEX IF NOT EXISTS pos_categories_shop_idx
  ON public.pos_categories (shop);

CREATE INDEX IF NOT EXISTS pos_open_bills_shop_idx
  ON public.pos_open_bills (shop);

CREATE INDEX IF NOT EXISTS transactions_user_date_idx
  ON public.transactions (user_id, date DESC, created_at DESC);

CREATE INDEX IF NOT EXISTS ious_user_created_desc_idx
  ON public.ious (user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS loans_user_created_desc_idx
  ON public.loans (user_id, created_at DESC);

-- ถ้า table game_sessions ไม่มี → ลบ statement นี้ออก
CREATE INDEX IF NOT EXISTS game_sessions_player_ids_gin
  ON public.game_sessions USING GIN (player_ids);

-- BRIN เล็กกว่า B-tree หลายเท่า เหมาะกับ timeseries
CREATE INDEX IF NOT EXISTS user_activity_created_brin
  ON public.user_activity USING BRIN (created_at);


-- ============================================================
-- ตรวจสอบเมื่อรันครบ — ควรเห็น index ใหม่ ~25 row
-- ============================================================

SELECT tablename, indexname
FROM pg_indexes
WHERE schemaname = 'public'
  AND (indexname LIKE '%_idx' OR indexname LIKE '%_gin' OR indexname LIKE '%_brin')
ORDER BY tablename, indexname;

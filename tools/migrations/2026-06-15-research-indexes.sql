-- ============================================================
-- Paruay — Research-backed index audit (2026-06-15)
-- Source: workflow "paruay-research-application" (52 agents, adversarial-verified)
-- Backed by: ~/Desktop/DemoVault/wiki/concepts/database-cost-optimization.md
--
-- IMPORTANT: รัน CONCURRENTLY ทีละ statement (ห้ามอยู่ใน transaction block)
-- Supabase SQL editor: เลือก statement ทีละบล็อก แล้วกด Run
--
-- ผลที่คาดหวัง:
--   - RLS predicates ใช้ index → overhead เกือบเป็นศูนย์
--   - Polling queries (transactions/ious) เร็วขึ้น 3-5x
--   - Friendships/Trips .or() patterns ไม่ scan ทั้งตาราง
--   - POS realtime + admin dashboard queries เร็วขึ้น
-- ============================================================

-- ============================================================
-- 4.1 RLS predicate indexes (รากของ perf ทั้งหมด)
-- ============================================================

-- Family hot path (composite + covering)
CREATE INDEX CONCURRENTLY IF NOT EXISTS family_transactions_family_created_idx
  ON public.family_transactions (family_id, created_at DESC);

CREATE INDEX CONCURRENTLY IF NOT EXISTS family_messages_family_created_desc_idx
  ON public.family_messages (family_id, created_at DESC) INCLUDE (user_id);

CREATE INDEX CONCURRENTLY IF NOT EXISTS family_ious_family_created_idx
  ON public.family_ious (family_id, created_at DESC);

CREATE INDEX CONCURRENTLY IF NOT EXISTS family_members_user_idx
  ON public.family_members (user_id) INCLUDE (family_id, role);

CREATE INDEX CONCURRENTLY IF NOT EXISTS family_members_family_idx
  ON public.family_members (family_id);


-- ============================================================
-- 4.4 Friendships + Trips bi-directional indexes (.or() patterns)
-- ============================================================

-- friendships
CREATE INDEX CONCURRENTLY IF NOT EXISTS friendships_user_a_idx
  ON public.friendships (user_a);

CREATE INDEX CONCURRENTLY IF NOT EXISTS friendships_user_b_idx
  ON public.friendships (user_b);

CREATE INDEX CONCURRENTLY IF NOT EXISTS friendships_accepted_a_idx
  ON public.friendships (user_a) WHERE status = 'accepted';

CREATE INDEX CONCURRENTLY IF NOT EXISTS friendships_accepted_b_idx
  ON public.friendships (user_b) WHERE status = 'accepted';

-- trip_settlements .or() patterns
CREATE INDEX CONCURRENTLY IF NOT EXISTS trip_settlements_from_idx
  ON public.trip_settlements (from_user);

CREATE INDEX CONCURRENTLY IF NOT EXISTS trip_settlements_to_idx
  ON public.trip_settlements (to_user);

-- trip_expenses .or() patterns
CREATE INDEX CONCURRENTLY IF NOT EXISTS trip_expenses_paid_by_idx
  ON public.trip_expenses (paid_by);

CREATE INDEX CONCURRENTLY IF NOT EXISTS trip_expenses_created_by_idx
  ON public.trip_expenses (created_by);

-- trip detail composites
CREATE INDEX CONCURRENTLY IF NOT EXISTS trip_expenses_trip_date_idx
  ON public.trip_expenses (trip_id, date DESC);

CREATE INDEX CONCURRENTLY IF NOT EXISTS trip_settlements_trip_created_idx
  ON public.trip_settlements (trip_id, created_at DESC);

CREATE INDEX CONCURRENTLY IF NOT EXISTS trip_members_user_idx
  ON public.trip_members (user_id);

CREATE INDEX CONCURRENTLY IF NOT EXISTS trip_members_trip_idx
  ON public.trip_members (trip_id);

-- Partial สำหรับ pending badges
CREATE INDEX CONCURRENTLY IF NOT EXISTS ious_counterparty_pending_idx
  ON public.ious (counterparty_user_id) WHERE shared_status = 'pending';

CREATE INDEX CONCURRENTLY IF NOT EXISTS trip_settlements_to_pending_idx
  ON public.trip_settlements (to_user) WHERE status = 'pending';


-- ============================================================
-- 4.5 POS + game + admin indexes
-- ============================================================

CREATE INDEX CONCURRENTLY IF NOT EXISTS pos_sales_shop_recent_idx
  ON public.pos_sales (shop, created_at DESC) INCLUDE (total, cost_total);

CREATE INDEX CONCURRENTLY IF NOT EXISTS pos_products_shop_idx
  ON public.pos_products (shop);

CREATE INDEX CONCURRENTLY IF NOT EXISTS pos_categories_shop_idx
  ON public.pos_categories (shop);

CREATE INDEX CONCURRENTLY IF NOT EXISTS pos_open_bills_shop_idx
  ON public.pos_open_bills (shop);

-- Transactions (loans hot path)
CREATE INDEX CONCURRENTLY IF NOT EXISTS transactions_user_date_idx
  ON public.transactions (user_id, date DESC, created_at DESC);

CREATE INDEX CONCURRENTLY IF NOT EXISTS ious_user_created_desc_idx
  ON public.ious (user_id, created_at DESC);

CREATE INDEX CONCURRENTLY IF NOT EXISTS loans_user_created_desc_idx
  ON public.loans (user_id, created_at DESC);

-- game_sessions array contains (GIN เพราะ player_ids เป็น array)
-- ⚠️ ถ้าตาราง game_sessions ไม่มี → ข้าม block นี้ได้
CREATE INDEX CONCURRENTLY IF NOT EXISTS game_sessions_player_ids_gin
  ON public.game_sessions USING GIN (player_ids);

-- admin user_activity (BRIN เหมาะกับ append-only timeseries — เล็กกว่า B-tree หลายเท่า)
CREATE INDEX CONCURRENTLY IF NOT EXISTS user_activity_created_brin
  ON public.user_activity USING BRIN (created_at);


-- ============================================================
-- เสร็จแล้ว — ทดสอบ
-- ============================================================
-- หลังรันครบ ลองรัน:
--   SELECT schemaname, indexname, tablename FROM pg_indexes
--   WHERE indexname LIKE '%_idx' OR indexname LIKE '%_gin' OR indexname LIKE '%_brin'
--   ORDER BY tablename;
-- เพื่อยืนยันว่า indexes ขึ้นครบ

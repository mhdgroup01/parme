-- 2026-07-09 — POS QR session-token (v3.7.263)
-- เจ้าของสั่ง: เช็คบิลสำเร็จ → QR โต๊ะนั้นตายทันที; เปิดโต๊ะใหม่/กดสร้าง QR ใหม่ = token ใหม่ กันลูกค้าเก่าสั่งปนลูกค้าใหม่.
-- เดิม: dine-in order ผ่าน RLS แค่ "ร้านมีจริง + โต๊ะ 1-9999" (qr_order_allowed 3-arg) ไม่เช็ค token เลย.
--
-- P0 (verified ก่อน apply): anon อ่าน pos_shops.table_tokens ไม่ได้ (policy pos_shops_sel = owner OR member;
--   SET ROLE anon; SELECT table_tokens → 0 rows) → token เป็นความลับจริง → โมเดลนี้มีความหมาย.
-- adversarial review (3-lens) ก่อนเขียน: ใช้ ALTER POLICY (atomic, ไม่มี deny-all window),
--   RPC set_table_token เขียนราย key ด้วย jsonb || (กันหลายเครื่องเขียนทับกันทั้งก้อน = บั๊กเดิมกลับมา),
--   ไม่สร้าง qr_table_valid (เป็น oracle เดา token ไม่มี throttle — ใช้ insert-error → จอ expired ฝั่ง client แทน).
-- apply: docker exec -i supabase-db psql -U postgres -d postgres < ไฟล์นี้ ; แล้ว NOTIFY pgrst.

BEGIN;

-- 1) qr_order_allowed 4-arg: dine-in ต้องมี token ตรงกับ table_tokens ปัจจุบัน (เก็บ 3-arg orphan ไว้ — มีแค่ qr_insert_orders อ้าง, จะ repoint ในข้อ 2)
CREATE OR REPLACE FUNCTION public.qr_order_allowed(p_shop text, p_type text, p_table integer, p_token text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public'
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.pos_shops s
    WHERE s.id = p_shop::uuid AND (
        (p_type = 'dinein' AND p_table >= 1 AND p_table <= 9999
           AND p_token <> '' AND (s.table_tokens ->> p_table::text) = p_token)
     OR (((s.remote_cfg ->> 'enabled')::boolean IS TRUE) AND p_type = ANY (ARRAY['pickup','delivery']))
    )
  );
$$;

-- 2) repoint RLS แบบ atomic (ALTER POLICY ไม่มีช่วง default-deny เหมือน DROP+CREATE)
ALTER POLICY qr_insert_orders ON public.pos_qr_orders
  WITH CHECK (public.qr_order_allowed(shop, order_type, table_no, token));

-- 3) เขียน token ราย key (staff เท่านั้น) — jsonb || เป็น atomic ภายใต้ READ COMMITTED → คนละ key เขียนพร้อมกันไม่ทับกัน
CREATE OR REPLACE FUNCTION public.set_table_token(p_shop text, p_table integer, p_token text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $$
BEGIN
  IF public.is_pos_staff(p_shop::uuid, auth.uid()) THEN
    UPDATE public.pos_shops
       SET table_tokens = COALESCE(table_tokens, '{}'::jsonb) || jsonb_build_object(p_table::text, p_token)
     WHERE id = p_shop::uuid;
  END IF;
END;
$$;
GRANT EXECUTE ON FUNCTION public.set_table_token(text, integer, text) TO authenticated;

COMMIT;

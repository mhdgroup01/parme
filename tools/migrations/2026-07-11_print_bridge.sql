-- Print bridge: คิวพิมพ์บิล → โปรแกรมบน PC ดึงไปพิมพ์ (Xprinter)
-- app (authenticated สมาชิกร้าน) insert งานพิมพ์; bridge บน PC ใช้ anon + secret ผ่าน RPC เท่านั้น

CREATE TABLE IF NOT EXISTS public.pos_print_jobs (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  shop       uuid NOT NULL REFERENCES public.pos_shops(id) ON DELETE CASCADE,
  img        text NOT NULL,                -- PNG data URL ของบิล (วาดจากแอป)
  status     text NOT NULL DEFAULT 'new',  -- new | printing | done | error
  created_at timestamptz NOT NULL DEFAULT now(),
  claimed_at timestamptz,
  printed_at timestamptz
);
CREATE INDEX IF NOT EXISTS pos_print_jobs_shop_status ON public.pos_print_jobs (shop, status, created_at);

ALTER TABLE public.pos_print_jobs ENABLE ROW LEVEL SECURITY;

-- เจ้าของ/สมาชิกร้าน จัดการงานพิมพ์ของร้านตัวเอง (mirror นโยบาย pos_sales_all)
DROP POLICY IF EXISTS pos_print_jobs_all ON public.pos_print_jobs;
CREATE POLICY pos_print_jobs_all ON public.pos_print_jobs
  FOR ALL TO authenticated
  USING (
    shop IN (SELECT id FROM public.pos_shops WHERE owner = auth.uid())
    OR shop IN (SELECT shop FROM public.pos_members WHERE member = auth.uid())
  )
  WITH CHECK (
    shop IN (SELECT id FROM public.pos_shops WHERE owner = auth.uid())
    OR shop IN (SELECT shop FROM public.pos_members WHERE member = auth.uid())
  );

-- bridge (PC) ดึงงานใหม่: ตรวจ secret จาก pos_shops.remote_cfg->>'printSecret'
-- คว้าได้ทั้ง 'new' และ 'printing' ที่ค้างเกิน 2 นาที (bridge เดิมตายกลางคัน)
CREATE OR REPLACE FUNCTION public.bridge_pop_print_jobs(p_shop uuid, p_secret text)
RETURNS SETOF public.pos_print_jobs
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF p_secret IS NULL OR length(p_secret) < 6 OR NOT EXISTS (
    SELECT 1 FROM pos_shops s WHERE s.id = p_shop AND s.remote_cfg->>'printSecret' = p_secret
  ) THEN
    RAISE EXCEPTION 'bad secret' USING ERRCODE = '28000';
  END IF;
  -- เก็บกวาดงานเก่าเกิน 1 วัน กันตารางบวม
  DELETE FROM pos_print_jobs WHERE shop = p_shop AND created_at < now() - interval '1 day';
  RETURN QUERY
  UPDATE pos_print_jobs j SET status = 'printing', claimed_at = now()
  WHERE j.id IN (
    SELECT id FROM pos_print_jobs
    WHERE shop = p_shop
      AND (status = 'new' OR (status = 'printing' AND claimed_at < now() - interval '2 minutes'))
    ORDER BY created_at
    LIMIT 5
    FOR UPDATE SKIP LOCKED
  )
  RETURNING j.*;
END $$;

-- bridge รายงานผลพิมพ์
CREATE OR REPLACE FUNCTION public.bridge_mark_print_job(p_id uuid, p_secret text, p_ok boolean)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  UPDATE pos_print_jobs j
     SET status = CASE WHEN p_ok THEN 'done' ELSE 'error' END,
         printed_at = now()
   WHERE j.id = p_id
     AND EXISTS (SELECT 1 FROM pos_shops s WHERE s.id = j.shop AND s.remote_cfg->>'printSecret' = p_secret AND length(p_secret) >= 6);
END $$;

REVOKE ALL ON FUNCTION public.bridge_pop_print_jobs(uuid, text) FROM public;
REVOKE ALL ON FUNCTION public.bridge_mark_print_job(uuid, text, boolean) FROM public;
GRANT EXECUTE ON FUNCTION public.bridge_pop_print_jobs(uuid, text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.bridge_mark_print_job(uuid, text, boolean) TO anon, authenticated;

NOTIFY pgrst, 'reload schema';

-- (แก้ตาม verify จริง) ตารางใหม่ไม่ได้ default grant ให้ role ของ PostgREST — app insert ต้องมีสิทธิ์
GRANT SELECT, INSERT ON public.pos_print_jobs TO authenticated;

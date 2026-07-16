-- VMOTO sales page CMS: ร้านแก้ content หน้าขาย (parme.me/vmoto/) เองผ่านแอป
-- เก็บใน pos_shops.sales_cfg (jsonb) — แก้จากแอป (authenticated, RLS owner) / หน้าเว็บอ่าน public ผ่าน RPC (anon)
-- schema: { variants:[{id,name{lo,th,en,zh},desc{..},range,top,accel,charge,price}],
--           deposit:number, bank:{name,number,note}, phone:string,
--           promo:{eyebrow{..},tagline{..}} }  -- field ไหนไม่มี → หน้าเว็บใช้ค่า hardcode เดิม

ALTER TABLE public.pos_shops ADD COLUMN IF NOT EXISTS sales_cfg jsonb;

-- หน้าเว็บ (anon) อ่านได้เฉพาะ sales_cfg ของร้านที่ระบุ — ไม่หลุดคอลัมน์อื่น
CREATE OR REPLACE FUNCTION public.vmoto_public_cfg(p_shop uuid)
RETURNS jsonb
LANGUAGE sql SECURITY DEFINER SET search_path = public STABLE AS $$
  SELECT sales_cfg FROM pos_shops WHERE id = p_shop;
$$;

REVOKE ALL ON FUNCTION public.vmoto_public_cfg(uuid) FROM public;
GRANT EXECUTE ON FUNCTION public.vmoto_public_cfg(uuid) TO anon, authenticated;

-- การเขียน: แอปใช้ pos_shops UPDATE ที่มี RLS pos_shops_upd (owner) อยู่แล้ว — ไม่ต้อง grant เพิ่ม

NOTIFY pgrst, 'reload schema';

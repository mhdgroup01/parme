-- v3.7.249 — POS ↔ รายรับส่วนตัว: เก็บ linked_tx_id บน cloud
-- เดิม linkedTxId อยู่แค่ใน memory/localStorage → โดน loadShopData/mapSale ทับหายภายในไม่กี่นาที
-- → ลบ/แก้บิลที่ผูกรายรับไว้ ไม่ตามไปลบ/แก้ tx ให้ = ยอดเงินส่วนตัวค้างเกินจริง
-- (รันบน VPS แล้ว 2026-07-04 — ไฟล์นี้เก็บเป็น record + เผื่อ restore)
ALTER TABLE public.pos_sales ADD COLUMN IF NOT EXISTS linked_tx_id uuid;

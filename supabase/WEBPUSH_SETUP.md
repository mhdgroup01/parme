# Web Push — ตั้งค่าฝั่ง Supabase (ทำครั้งเดียว)

แจ้งเตือนออเดอร์เข้ามือถือ **แม้แอปปิด/พับไว้** (iOS 16.4+ ต้องติดตั้งแอปลงโฮมสกรีนก่อน)

ฝั่งแอป (PWA + service worker `sw.js` + ปุ่มเปิดใน Settings) ผมทำให้แล้ว เหลือ 4 ขั้นตอนนี้ที่ M ต้องทำใน Supabase:

## VAPID keys (สร้างไว้แล้ว — ใช้คู่นี้)

```
PUBLIC : BKcKU-zbMvDXyUQ5IaGuMHYzBTuVBaCdwXhx_nYiQ9u6zZXuPO-fiU-P5QM7Gk77h6s8ejye-914rQzIrULKmGI
PRIVATE: 2If89FjZpZkZG9krNwas19crEYVqpb6hiRWFSrlaxqE
```
- **PUBLIC** ฝังในแอปแล้ว (ค่า `VAPID_PUBLIC` ใน index.html)
- **PRIVATE** = ความลับ ห้ามใส่ในโค้ดฝั่ง client — ใส่เป็น secret ของ Edge Function เท่านั้น (ขั้นตอนที่ 3)

---

## 1) สร้างตารางเก็บ subscription
Supabase Dashboard → **SQL Editor** → วางทั้งไฟล์ `push_subscriptions.sql` แล้วกด Run

## 2) deploy Edge Function
ต้องมี Supabase CLI (`npm i -g supabase`) แล้ว login + link โปรเจกต์
```bash
cd ~/paruay
supabase functions deploy send-pos-push --no-verify-jwt
```
(`--no-verify-jwt` เพราะ webhook เรียกด้วย service key ไม่ใช่ JWT ผู้ใช้)

## 3) ตั้ง secrets ให้ฟังก์ชัน
```bash
supabase secrets set \
  VAPID_PUBLIC=BKcKU-zbMvDXyUQ5IaGuMHYzBTuVBaCdwXhx_nYiQ9u6zZXuPO-fiU-P5QM7Gk77h6s8ejye-914rQzIrULKmGI \
  VAPID_PRIVATE=2If89FjZpZkZG9krNwas19crEYVqpb6hiRWFSrlaxqE \
  VAPID_SUBJECT=mailto:mhdgroup01@gmail.com
```
(`SUPABASE_URL` กับ `SUPABASE_SERVICE_ROLE_KEY` Supabase ใส่ให้อัตโนมัติ)

## 4) สร้าง Database Webhook ยิงตอนมีออเดอร์ใหม่
Dashboard → **Database → Webhooks → Create a new hook**
- Name: `pos-order-push`
- Table: `pos_qr_orders`
- Events: **Insert** เท่านั้น
- Type: **Supabase Edge Functions** → เลือก `send-pos-push`
- (Method POST, Timeout ค่า default ได้)
- Save

---

## ทดสอบ
1. เปิดแอปบนมือถือ (iOS: ติดตั้งลงโฮมสกรีนก่อน) → **Settings → 🔔 แจ้งเตือนออเดอร์เข้ามือถือ → เปิด** → กดอนุญาต
2. ปิดแอป/พับไว้ แล้วให้ลูกค้าสแกน QR สั่งของ (หรือ insert แถวใน `pos_qr_orders` เอง)
3. ควรเด้ง notification + เสียงของระบบ

## ค่าใช้จ่าย
ฟรีในโควต้า Supabase free tier (Edge Function 500k/เดือน) + Apple/Google ไม่คิดค่าส่ง push

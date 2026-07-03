# CLAUDE.md — Paruay (ພາລວຍ)

> ไฟล์นี้ Claude Code อ่านทุกครั้งที่เริ่ม session ทำหน้าที่เป็น "ความจำถาวร" ของโปรเจกต์

## ภาษา
คุยกับเจ้าของโปรเจกต์ (M) เป็น **ภาษาไทย** เสมอ ใช้ศัพท์เทคนิคภาษาอังกฤษได้ตามปกติ

## ภาพรวมโปรเจกต์
Paruay เป็น **single-file React PWA** ไฟล์เดียวคือ `index.html` (~3.9MB)
รวม 3 ระบบในแอปเดียว:
- การเงินส่วนตัว/ครอบครัว (เน้นเงินกีบลาว + รองรับสกุลเงินต่างประเทศ)
- POS ร้านอาหาร/ร้านค้า (โต๊ะ, QR order, ครัว, ส่วนลด/service charge)
- เกมไพ่/ลูกเต๋า

รองรับ 4 ภาษา: ลาว (lo), ไทย (th), อังกฤษ (en), จีน (zh) — ภาษาหลักคือลาว
กลุ่มเป้าหมาย: ร้านค้าเล็กที่พูดภาษาลาว

## สถาปัตยกรรม (ข้อจำกัดที่ต้องยึดเสมอ)
- **ไฟล์เดียว** — ทุกอย่างอยู่ใน `index.html` ห้ามแตกไฟล์ JS/CSS ออก
- **ไม่มี build step** — โค้ดเขียน `React.createElement` ตรงๆ (มี `h` เป็น alias) ไม่มี Babel runtime ในเบราว์เซอร์
- **Deploy: self-host บน Hostinger VPS** — https://parme.me + www (nginx container `parme-prod`, DNS ผ่าน Cloudflare → 187.127.122.252). repo `mhdgroup01/paruay` branch `main` ยัง sync อยู่แต่ **GitHub Pages ไม่ใช่ตัวเสิร์ฟ prod แล้ว** (เหลือเป็น fallback: revert DNS กลับ 185.199.108-111.153) — ย้ายมา VPS ตั้งแต่ 2026-07-02
- **Backend: self-host Supabase บน VPS** (`https://api.parme.me`, project ref เดิม `rilrbflteuwhomrwfcsa` ยังใช้เป็นชื่อ display) — auth (GoTrue)/realtime/postgres/edge functions รันบน VPS. **Supabase Cloud เก็บไว้เป็น fallback** (snapshot วัน cutover ไม่ใช่ backup ปัจจุบัน). รายละเอียดโครงสร้าง VPS ดู second-brain memory `[[hostinger-vps]]`

## เวอร์ชันปัจจุบัน
v3.7.250 (2026-07-04 — เก็บ follow-up จาก audit: POS offline boot, self-heal resurrect, bill-edit reprice, QR retry, quota fallback, stale guards)

## Workflow การแก้โค้ด (สำคัญมาก)

> 🛠️ **มี helper scripts ใน `tools/` แล้ว** (ใช้แทนขั้นตอนมือด้านล่าง — ปลอดภัยกว่า):
> - `python3 tools/bump.py 3.7.xx` — bump ครบ 4 จุด อัตโนมัติ (assert จุดละ 1 ครั้งก่อนเขียน, ไม่แตะ comment ประวัติ; มี `--dry` ดูก่อนได้)
> - `python3 tools/check.py` — แยก block หลัก (ที่มี `APP_VERSION`) แล้วรัน `node --check` ให้เลย
> - `bash tools/release.sh 3.7.xx "สรุปสั้น"` — bump → check → โชว์คำสั่ง commit/push (ไม่ push ให้เอง)
> ขั้นตอนมือด้านล่างเก็บไว้เป็นเอกสารอ้างอิง/fallback ถ้า script มีปัญหา

### 1. Version bump — แก้ครบ **4 จุด** ทุกครั้งที่ release
แนะนำ: `python3 tools/bump.py 3.7.xx` (จัดการให้ครบ + ปลอดภัย). ถ้าทำมือ:
ก่อนแก้ให้ `grep -n` หาเลขบรรทัดสดเสมอ (เลขบรรทัดขยับได้):
```
grep -n "v3\.7\.35" index.html
```
จุดที่ต้องแก้ (ตำแหน่งโดยประมาณ):
1. `<title>ພາລວຍ · Paruay v3.7.xx</title>` (~บรรทัด 6)
2. `<meta name="app-version" content="v3.7.xx" />` (~บรรทัด 8)
3. `<div class="version-tag">v3.7.xx</div>` (~บรรทัด 872)
4. `const APP_VERSION = 'v3.7.xx';` (~บรรทัด 3753)

⚠️ ระวัง comment ประวัติ เช่น `// v3.7.34 — ...` กระจายอยู่ในโค้ด — **ห้ามนับรวม** ตอน bump ให้แก้เฉพาะ 4 จุด canonical ข้างบน

### 2. ตรวจ syntax หลังแก้ทุกครั้ง
แนะนำ: `python3 tools/check.py`. (กลไกข้างใต้: `index.html` มี `<script>` ~8 blocks; block หลักของแอป
ที่มี logic ทั้งหมดคือ block ที่มี `APP_VERSION` ขนาด ~1.6MB — script แยก block นั้นออกมารัน `node --check` ให้)
หลังแก้โค้ดต้องผ่าน `node --check` ก่อน commit เสมอ

ตัวอย่างสคริปต์แยก + เช็ก (Python):
```python
import io
src = io.open('index.html', encoding='utf-8').read()
idx = 0
while True:
    s = src.find('<script', idx)
    if s == -1: break
    gt = src.find('>', s); e = src.find('</script>', gt)
    c = src[gt+1:e]
    if 'APP_VERSION' in c:   # block หลักของแอป
        io.open('/tmp/app.js', 'w', encoding='utf-8').write(c)
    idx = e + 9
```
แล้ว `node --check /tmp/app.js`

### 3. การแก้ string — assert ก่อนเขียนเสมอ
ก่อน replace ให้นับจำนวน occurrence ให้ตรงตามคาด ป้องกันแก้ผิดจุด (ไฟล์ใหญ่ string ซ้ำได้ง่าย) ใช้ Edit tool ของ Claude Code โดยใส่ context รอบ ๆ ให้ unique หรือถ้าแก้หลายจุดพร้อมกันใช้ Python heredoc ที่ assert count ก่อน

### 4. Deploy (v3.7.249+ — prod อยู่บน VPS แล้ว)
prod ตัวจริงคือ nginx บน VPS — **push GitHub อย่างเดียวไม่ deploy แล้ว** ต้อง rsync ด้วย:
```
# 1) deploy จริง (VPS)
rsync -e "ssh -i ~/.ssh/hostinger_vps_ed25519" -av ~/paruay/index.html root@187.127.122.252:/docker/parme-prod/html/index.html
# 2) verify
curl -s https://parme.me/ | grep -o 'app-version" content="[^"]*'
# 3) เก็บ repo ให้ตรง prod (+GitHub Pages fallback)
git add -A && git commit -m "v3.7.xx — <สรุปสั้น>" && git push
```
nginx ส่ง `Cache-Control: no-cache` ให้ HTML/sw.js แล้ว (ตั้งใน `/docker/parme-prod/default.conf` 2026-07-04) → ผู้ใช้ได้เวอร์ชันใหม่ตอนเปิดแอปรอบถัดไป. ถ้าแก้ schema DB → รัน SQL บน VPS (`docker exec supabase-db psql -U postgres`) + เก็บไฟล์ใน `tools/migrations/` + **อย่าลืม `NOTIFY pgrst, 'reload schema';`** ไม่งั้น PostgREST ไม่รู้จักคอลัมน์ใหม่

## โครงสร้าง Supabase (ตารางหลัก)
ฝั่งการเงิน: `user_settings` (มี `fx_manual` jsonb สำหรับ FX override sync), `families`, `family_transactions`, `family_members`, `family_messages`, `family_ious`
ฝั่ง POS: `pos_products` (มี `sort`, `station`), `pos_categories` (มี `station`), `pos_sales` (มี `table_no`, `sub_total`, `discount`, `svc`, `svc_pct`), `pos_shops` (มี `table_tokens`, `seeded`), `pos_qr_orders`, `pos_open_bills`

⚠️ การเพิ่ม column ต้องรัน SQL ใน Supabase เอง (M รันเอง) ใช้ `ADD COLUMN IF NOT EXISTS` เสมอเพื่อความปลอดภัย

## ระบบ FX (สรุปจากงานล่าสุด v3.7.35)
- auto-rate เป็น **kip-based** (กีบต่อ 1 หน่วย) ดึงจาก jsDelivr/er-api
- `fxKipPerUnit(st, sym, codeHint)` → กีบต่อหน่วย
- `fxToPrimary(st, sym, codeHint, primarySym, primaryCodeHint)` → **สกุลหลักต่อหน่วย** (ใช้กีบเป็นสะพาน) ถ้าสกุลหลัก = กีบ จะได้ผลเท่า fxKipPerUnit เป๊ะ
- กราฟใช้คอลัมน์ `fxk_<sym>` = ค่าที่แปลงเป็นสกุลหลักแล้ว, tooltip แสดง `≈ CUR fmt(...)`

## Demo mode (v3.7.88+) — เปิด UI หลัง login ได้โดยไม่ต้องล็อกอินจริง
เพิ่ม `?demo=1` ใน URL → bypass Supabase auth + seed localStorage (7 transactions + 2 IOUs) → เปิดหน้าหลัก/รายงาน/Family/POS ในพรีวิวได้เลย ไม่กระทบ Supabase production. กลไก: `__fakeSupabase` stub (chainable .from() คืน empty array) + `__DEMO__` ตรวจ URL + early-return ใน auth useEffect + loadCloudData. ใช้สำหรับ Claude ตรวจ UI/UX bug ในพรีวิวก่อน deploy.

## ⚠️ ต้องรัน SQL (v3.7.98–99) — POS ลูกค้าเชื่อ + วิธีจ่าย
1. `tools/migrations/2026-06-17-pos-customer-credit.sql` — เพิ่มคอลัมน์ `paid`/`customer`/`settled_at` ใน `pos_sales`. **สำคัญ:** client v3.7.98+ ส่ง 3 คอลัมน์นี้ในทุก upsert ของการขาย → ถ้ายังไม่รัน SQL การ sync ขายขึ้น cloud จะ fail เงียบ ๆ (try/catch — ข้อมูลไม่หาย เซฟ local ปกติ แต่ไม่ขึ้นเครื่องอื่นจนกว่าจะรัน SQL). ฟีเจอร์ "ลงเชื่อ" verified ใน demo แล้ว (create→panel→settle ครบ).
2. `tools/migrations/2026-06-17-pos-payment-method.sql` — เพิ่มคอลัมน์ `payment` (text = cash/transfer/null) ใน `pos_sales`. client v3.7.99+ ส่ง `payment` ทุก upsert → เหตุผลเดียวกับข้อ 1 (ต้องรันคู่กัน). ฟีเจอร์ "ระบุวิธีจ่าย" เปิด/ปิดได้ในตั้งค่า POS (toggle เก็บ localStorage `paruay_pos_pay_mode`); ปิดอยู่ → `payment` = null. verified ใน demo (เปิด toggle → ขาย→chooser→cash/transfer → report แยกชิป 💵 เງິນສົດ / 📱 ໂอน).

## POS Tier 1 (เสริมร้าน POS — จาก audit)
- ✅ **#1 ลูกค้าเชื่อ** (v3.7.98) — ดู section "ต้องรัน SQL" ด้านบน
- ✅ **#2 ระบุวิธีจ่าย เงินสด/โอน + toggle** (v3.7.99) — ดู section "ต้องรัน SQL" ด้านบน
- ✅ **#3 Export CSV** (v3.7.100) — **client ล้วน ไม่แตะ DB ไม่ต้องรัน SQL**. ปุ่ม 📤 ในแถบ range ของ PosReport → ดึงบิลตามช่วงที่เลือก (วัน/เดือน/ปี/ทั้งหมด) เป็น CSV. 1 แถว/บิล, 15 คอลัมน์ (วันที่/เวลา/รหัสบิล/โต๊ะ/รายการ/ยอดย่อย/ส่วนลด/ค่าบริการ/รวม/ต้นทุน/กำไร/การจ่าย/สถานะ/ลูกค้า/ผู้ขาย). มี BOM (Excel อ่าน Lao/Thai ได้), CSV-injection guard (=+-@ → prefix '), RFC-4180 escaping, CRLF, ตัวเลขดิบ (ไม่ใช้ fmt). iOS: ลอง `navigator.share({files})` ก่อน → fallback `<a download>`. ใช้ inline `T()` ล้วน (PosReport ไม่มี `t` ใน scope). helper `exportCsv`/`filtRows`/`csvCols` อยู่ใน PosReport (~L30075). verified ใน demo (จับ blob จริง: header ลาวถูกครบ + escaping ผ่าน adversarial name `=Boon, "VIP"`).
- ✅ **#1b ลูกค้าเชื่อ — กดดูรายบิล + แก้ไข** (v3.7.101) — **client ล้วน ไม่ต้องรัน SQL** (reuse คอลัมน์ paid/settled_at เดิม). แตะแถวลูกค้าในการ์ด `ລູກຄ້າເຊື່ອ` (มี chevron ›) → bottom-sheet (zIndex 500) โชว์บิลค้างรายใบ (วันเวลา + รายการ + ยอด). ต่อบิล: **✓ ຮັບເງິນ** = settle เฉพาะบิลนั้น (จ่ายบางส่วน — fn ใหม่ `posSettleCreditBill(saleId)` mirror `posSettleCredit` **ไม่เรียก applyTotalsDelta** เพราะ rev นับ unpaid อยู่แล้ว → settle ไม่ขยับรายได้ แค่ Owed ลด), **✏️ ແກ້ໄຂ** = ดูข้อ #1c, **🗑️ ລຶບ** = two-tap confirm (ไม่มี askConfirm/showToast ใน PosReport) → `posDeleteSale` (ลบคืน stock + reverse totals → รายได้ลด). settle/delete บิลสุดท้าย → useEffect auto-close sheet. edit/delete gate ด้วย `amOwner`; settle ไม่ gate. verified ใน demo ครบ.
- ✅ **#1c แก้บิลเชื่อในหน้าขาย** (v3.7.102) — **client ล้วน ไม่ต้องรัน SQL**. กด ✏️ ในแผ่นรายละเอียด → ปิดแผ่น แล้ว `onEditBill(saleId)` (ใน POSModal) สร้าง **บิลชั่วคราว** `{name:'__edit__', table:null}` โหลด items→cart map (กรอง productId ที่มีจริง, นับ `editDropped` ที่หาย=สินค้าถูกลบ) → `setActiveBillId` + `setTab('sell')`. หน้าขายโหมดแก้: bill-chips strip ถูกแทนด้วย **banner "ກຳລັງແກ້ໄຂບິນ"** (+ ⚠️ ถ้า editDropped>0) + ปุ่มยกเลิก; แถว checkout เปลี่ยนเป็นปุ่มเดียว **💾 ບັນທຶກການແກ້ໄຂ** (ซ่อนปุ่ม credit + complete → ไม่มีทางสร้างบิลใหม่). `saveEdit` → `onEditSale(saleId,{items, seller:null})` (posEditSale spread `...old` → paid:false/customer/payment/table/createdAt/id คงไว้; seller:null → คง old.seller; ถ้า editDropped>0 askConfirm ก่อน). `exitEdit` ลบบิล `__edit__` + คืน `prevActiveBillId` + `setTab('report')`. bills loader กรอง `__edit__` ออกกัน remount ค้าง. **ข้อจำกัด:** posEditSale คิด total = Σ price×qty (ไม่ re-apply discount/svc เดิม — quirk เดียวกับ modal เก่า) จึงไม่เปิดให้แก้ส่วนลด/โต๊ะในโหมดนี้. verified ใน demo: load→cart, เพิ่มสินค้า→save = 1 บิล 2 รายการ ยังเชื่อ rev ถูก · cancel ไม่กระทบบิล.
- ✅ **#1d รวม edit เป็น `startBillEdit` เดียว** (v3.7.106) — extract logic โหลด-เข้า-ตะกร้าเป็น `startBillEdit(saleId)` ใน POSModal. ทั้ง **ปุ่ม ✏️ ในรายการประวัติบิล** (เดิมเปิด edit modal เล็ก qty-only ที่ `setEditSale`, ~L33086) **และ** onEditBill ของแผ่นลูกค้าเชื่อ เรียก `startBillEdit` ร่วมกัน → แก้บิลไหนก็เด้งหน้าขาย เพิ่ม/แก้สินค้าได้เหมือนกันหมด. edit modal เก่า (editSale ~L33270) กลายเป็น dead code (ไม่มี opener แล้ว — ปล่อยไว้ ไม่ลบ กันเสี่ยง). verified ใน demo: ปุ่มประวัติบิล→หน้าขาย, เพิ่ม Pepsi→save = บิลเดิมอัปเดต Beerlao×2+Pepsi ₭24,000 paid คงไว้ 1 บิล.

## perf — CLS 0.48→0.001 (v3.7.105)
loading screens (`authState==='loading'` ~L17664 + `cloudLoading` ~L18239) เคยใช้ `minHeight:100vh`+`justify-content:center` (โลโก้กลางจอ, อยู่ใน flow). พอ render เปลี่ยนเป็น dashboard React **reuse DOM node** ย้ายโลโก้กลางจอ→บนสุด = เนื้อหากระโดด ~259px = **CLS 0.48 (แดง)**. แก้: ทำ splash เป็น `position:fixed; inset:0` (ออกจาก flow) + `key:'authloading'` (บังคับ unmount สะอาด ไม่ reuse node → dashboard = เนื้อหาใหม่ ไม่ใช่ "ย้าย"). วัดด้วย buffered `layout-shift` PerformanceObserver: 0.4804→0.0013. **LCP ~2.7s บนเครื่องจริงเป็นข้อจำกัดของ single-file 4.2MB (parse+mount) — ไม่แก้ตอนนี้.**

## bugfix สำคัญ — realtime mapSale ตัด paid/customer (v3.7.104)
`mapSale` (~L17166) = mapper สำหรับ **realtime delta-merge** (`mergeRow`) ของ `pos_sales`. เขียนไว้ก่อนมีฟีเจอร์ลูกค้าเชื่อ/วิธีจ่าย → **ไม่มี paid/customer/payment/settled_at**. อาการ: แก้/settle/สร้างบิลเชื่อ → Supabase realtime echo กลับ → `mergeRow`→`mapSale` ตัด paid/customer ทิ้ง → in-memory บิลกลายเป็น paid:undefined → `creditBy` (เช็ก `paid===false`) ไม่นับ → **บิลเชื่อหายจากการ์ดทันทีหลังแก้** จนกว่าจะ refresh (loadShopData mapping เต็ม อ่าน cloud กลับมา). **ไม่เกิดใน demo** เพราะ fake supabase channel เป็น no-op (mergeRow ไม่ทำงาน) — เป็นเหตุผลที่เทสต์ demo ผ่านตลอด. แก้: เติม `paid/customer/payment/settledAt` ใน mapSale ให้ตรงกับ loadShopData (16901). **บทเรียน: เพิ่ม column sale ใหม่ ต้องอัปเดต 3 ที่ — upsert mapping (16846), loadShopData mapping (16901), mapSale realtime mapper (17166).**

## bugfix สำคัญ — empty-cloud overwrite (v3.7.103)
`loadShopData` (~L16877) เคยใช้ `if (prods) setPosProducts(...)` — แต่ `[]` เป็น **truthy** → ถ้า cloud คืน array ว่าง (sync ยังไม่เสร็จ/ล้มเหลว/seed ตอน posShopId ยัง null) จะ**เขียนทับสินค้า local เป็นว่าง** = สินค้า/บิลหายหลัง refresh (เฉพาะตอนล็อกอิน+มีร้าน; เส้นทางไม่มีร้านปลอดภัยเพราะ loadShopData ไม่รัน). แก้: `if (prods && prods.length)` กับ **products + categories + sales** (cloud ว่าง = ไม่ลบ local). ⚠️ ทดสอบ demo ไม่ได้ (ไม่มีร้าน) — verify เครื่องจริง. **เหลือ:** ถ้า cloud ไม่ว่างแต่ขาดบิลที่ sync ไม่ขึ้น (เช่นยังไม่รัน SQL credit/payment → upsert fail) ก็ยังโดนทับได้ → ทางแก้คือรัน SQL ให้ครบ.

## v3.7.249 (2026-07-04) — audit ใหญ่ 4 agents + ซ่อมยกชุด
**ซ่อมแล้ว (deploy บน VPS แล้ว):**
- **dead writes 14 จุด** — supabase-js builder ไม่ถูก `await`/`.then` = ไม่ยิง HTTP เลย: sync `pos_ingredients` (ตายสนิททั้ง feature), reset POS wipe cloud, ตั้งค่าร้าน 7 จุด (fifo/stock/table_count/units), ลบ ghost bill `__edit__`. แก้: `.then(r=>{if(r&&r.error)...})` + enqueue สำหรับ ingredients. **บทเรียน: `supabase.from(...)` ต้องมี await/.then เสมอ**
- **offline tx queue** — (a) แก้ไขรายการเก่าตอน offline โดนทับหาย: เพิ่ม pending-edit protection (local ชนะ cloud) ใน poll merge 3 path + loadCloudData, (b) เลิก `txPendingClear()` เหมา, (c) จำกัด re-push local-only เฉพาะ pending∪สร้างใหม่<72ชม. (กัน tx ที่ลบจากเครื่องอื่นคืนชีพ), (d) 'online' event flush คิว POS ด้วย + timer 30s (`window.__paruayFlushTimer` + event `paruay-auto-flush`)
- **timezone** — `todayStr()` เดิม UTC → ก่อน 7 โมงเช้า รายการ/ยอดขายลงวันเมื่อวาน. แก้เป็น local (+รับ Date param) + จุด inline อีก 6 (famDate/dk/ds/todayS/dob max). RPC ฝั่ง DB ใช้ Asia/Bangkok อยู่แล้ว
- **auth watchdog** — session มาช้ากว่า 6s watchdog → token ถูกทิ้ง → realtime ค้าง anon (SUBSCRIBED แต่เงียบ). แก้: early-return branch ยัง setAuth ให้ realtime
- **stale-response guards** — `posShopIdRef` + guard ใน loadShopData/loadPosTotals (สลับร้านเร็ว = ข้อมูลข้ามร้าน), double-tap guard `completeRemoteSale`, recipe-type ไม่คืน product stock ตอน void/edit, `computeShares` โยนเศษปัดให้แชร์ใหญ่สุด (Σ = ยอดจริง)
- **linkedTxId round-trip** — คอลัมน์ใหม่ `pos_sales.linked_tx_id` (SQL: `tools/migrations/2026-07-04-pos-sales-linked-tx.sql`, รันบน VPS แล้ว + NOTIFY pgrst) + ใส่ครบ 4 mappers → ลบ/แก้บิลที่ผูกรายรับ ตามไปจัดการ tx ถูกแล้ว (เดิมค่าอยู่แค่ local โดน sync ทับหาย = ยอดค้างเกิน)
- **dead code ~293 บรรทัด** — modal แก้บิลเก่า (editSale), goal UI เก่า (bar/goalCard/short/ring/goalRing), orphan states 12 ตัว. `CATALOG_BASE` → `./catalog/` (เดิมชี้ github.io). เหลือ `rotateToken` (อาจเป็นฟีเจอร์อนาคต — ถาม M ก่อนลบ)
- **nginx VPS** — เพิ่ม `Cache-Control: no-cache` ให้ HTML/sw.js (เดิมไม่มี header → heuristic cache → ติดเวอร์ชันเก่า), catalog 7 วัน

## v3.7.250 (2026-07-04) — เก็บ follow-up รอบสอง
- **POS เปิดตอน offline ได้แล้ว** — resolve ร้านล้ม (เน็ตล่ม) → กู้จาก `paruay_pos_shops_cache` (เก็บ list+myId+user ทุกครั้งที่ resolve สำเร็จ ได้สิทธิ์ owner ถูกต้อง) + state `posShopDegraded` + auto-retry ตอน 'online' event
- **self-heal สินค้า/หมวด** — push คืน cloud เฉพาะ id ที่ค้างคิว `pendingUpsertIds()` (เดิม push ทุกตัวที่ cloud ไม่มี = ของที่ลบจากเครื่องอื่นคืนชีพ) — local merge ยังคงเดิม
- **แก้บิลเก่าไม่ reprice แล้ว** — `editPriceOv` ใน cartItems: สินค้าที่อยู่ในบิลเดิมใช้ราคา/ต้นทุน "ตามบิล" (จอ+ยอด+เซฟตรงกันหมด) ของเพิ่มใหม่ใช้ราคาปัจจุบัน
- **QR order status** — helper `qrOrderUpdate(id, patch)` retry×3 backoff แทน `.then(()=>{})` ทั้ง 8 จุด (accepted/rejected/done/paid/expired/patch)
- **localStorage เต็ม** — `saveTxStore` fallback เซฟแบบตัดรูปแนบ (รูปอยู่บน cloud row แล้ว) แทนเงียบทั้งก้อน
- **stale guards** — `loadReqRef` (loadDetail: เปิดครอบครัวซ้อน/ปิดแล้วไม่เด้งคืน), `openRef` guard ใน loadPOS, `currentUserIdRef` guard ใน loadCloudData (สลับบัญชีเร็ว)

**follow-up ที่เหลือ (design change — ต้องเทสต์ร้านจริง/ตัดสินใจก่อนทำ):**
1. **soft-delete tombstones** (`deleted_at` ทุกตาราง sync) — ลบข้ามเครื่องยัง propagate ผ่าน realtime เท่านั้น (cursor poll มองไม่เห็น delete; local-only ghost ค้างบนเครื่อง stale จนกว่า realtime จะจับ). ต้องแก้ DB schema + ทุก delete path + filter ทุก query
2. **atomic stock decrement RPC** — สองเครื่องขายพร้อมกันยัง lose update (upsert absolute). ควรมี `decrement_stock(product_id, qty)` + เปลี่ยน checkout path; กระทบคิว offline (เก็บ delta แทน absolute)
3. **`game_sessions` realtime ไม่มี filter** — fan-out ทุก event × ทุก client (filter ด้วย array ไม่ได้ — ต้องเปลี่ยน schema เป็น notify-row ต่อ user หรือยอมรับจนกว่าผู้ใช้เกมจะเยอะ)
4. duplicate report block ×2 (~130 บรรทัด family vs personal) — refactor เมื่อสะดวก
5. `rotateToken` (QR token rotation) เขียนไว้ไม่มี UI เรียก — ถาม M: ฟีเจอร์อนาคตหรือลบ

## งานค้าง (ณ v3.7.103)
- Tier 1 #4+ (ถ้าจะทำต่อ): ดูจาก POS audit — เช่น พิมพ์ใบเสร็จ/แชร์, สต็อกสินค้า, กะ/รอบขาย ฯลฯ
- ขยาย product catalog (รับรูป → ลบพื้นหลังดำ → webp 256px q80 → อัปเดต `catalog/catalog.json` + zip ไม่ต้อง bump แอป) — *ต้องมีรูปจริงจาก M*
- ✅ **2.3 cursor polling** (transactions/ious) — **เสร็จแล้ว**: client ใช้ `.gt('updated_at', txCursorRef)` (full/delta/first mode + `cursorDisabledRef` fallback, pollForUpdates ~L12848) + SQL `tools/migrations/2026-06-16-cursor-polling-updated-at.sql` (top-level = run แล้ว)
- ✅ **2.4 admin dashboard RPC** — **เสร็จแล้ว** (2026-06-17): client wire ไว้ตั้งแต่ v3.7.50 + SQL `tools/migrations/2026-06-17-admin-dashboard-summary.sql` รันที่ Supabase แล้ว (verified: hourly=24/weekday=7, dau/mau คืนค่าถูก). แก้บั๊ก sparse hourly/weekday จาก draft v2.
- **Phase 2.1b / 2.2b** ตัด `loadDetail()/loadShopData()` ออกจาก local writes (ต้องการ optimistic update เต็ม) — ⚠️ เสี่ยง: แตะ core money-sync, ทำเมื่อมั่นใจ delta-merge เสถียร + ต้องเทสต์ multi-device จริง (เทสต์ใน demo mode ไม่ได้ เพราะ supabase stub)

## sprint ที่ทำแล้ว (2026-06-15/16)
ดู `docs/2026-06-15-research-action-plan.md` สำหรับรายละเอียดงานวิจัย (52-agent workflow + adversarial verify)
- v3.7.37 — security probe fix + preconnect + decision records
- v3.7.37 — SQL: 25 indexes (RLS, .or() patterns, POS, admin) — `tools/migrations/2026-06-15-research-indexes.sql`
- v3.7.38 — family realtime delta-merge (7 RTT/event → 0)
- v3.7.39 — POS realtime delta-merge (4-query refetch → 0)
- v3.7.40 — POS sales totals RPC (correctness fix: ยอด > 500 บิลผิดเงียบๆ) — `tools/migrations/2026-06-16-pos-sales-totals-rpc.sql`

## สิ่งที่ไม่ควรทำ
- ห้ามแตก index.html เป็นหลายไฟล์
- ห้าม `cat`/อ่านทั้งไฟล์ 3.9MB โดยไม่จำเป็น — ใช้ `grep -n` + `sed -n` ช่วงแคบ ๆ (ระวังบรรทัด I18N dictionary ที่ยาวเป็นหมื่นตัวอักษร — grep แบบจำกัด width)
- ห้าม bump version ไม่ครบ 4 จุด
- ห้าม commit โดยยังไม่ผ่าน `node --check`

## ตัดสินใจแล้ว — ไม่ทำ (ป้องกัน session ถัดไปเสนอซ้ำ)

ผ่าน research workflow 2026-06-15 (52 agents, audit + adversarial review):

**ไม่ migrate PowerSync / cr-sqlite (local-first)** — ขัด iron rule "single file"; anon QR ไม่มี JWT (sync layer ไม่รองรับ); ผู้ใช้ส่วนใหญ่ single-writer ไม่ต้อง CRDT; delta-merge ใน-memory ทำเองได้ ~90% ของ benefit (ดู v3.7.37+ realtime delta-merge work).

**ไม่ migrate Vite / SvelteKit** — claim "ลด bundle 60%" ลอย เพราะ Paruay ไม่มี Babel runtime อยู่แล้ว (React.createElement ตรงๆ); ขัด no-build rule.

**ไม่ย้าย GitHub Pages → Cloudflare Pages** — origin change → PWA ที่ install ไว้แล้ว orphan; GitHub Pages มี Fastly Bangkok PoP อยู่แล้ว.

**ไม่เพิ่ม Service Worker shell cache** — ขัด iron rule "ห้ามแตกไฟล์"; SW จาก Blob URL ไม่มี scope; version skew กับ Supabase schema = correctness risk.

**Trigger reconsider:** ถ้ามี shop จริง > 10 + multi-cashier conflict report จริง + ยอมแตก single-file constraint → คุยเรื่อง local-first ใหม่.

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
- Deploy ผ่าน **GitHub Pages**: https://mhdgroup01.github.io/paruay/ (repo: `mhdgroup01/paruay`, branch `main`)
- **Backend: Supabase** (region Singapore) — auth, realtime, postgres

## เวอร์ชันปัจจุบัน
v3.7.40 (sprint 2026-06-15/16 — research-backed optimization)

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

### 4. Deploy (เปลี่ยนจากเดิม)
ใน Claude Code ไม่ต้อง `cp` ไป outputs หรือ present_files แล้ว — แก้ไฟล์ในเครื่องตรง ๆ แล้ว:
```
git add index.html
git commit -m "v3.7.xx — <สรุปสั้น>"
git push
```
GitHub Pages จะ deploy อัตโนมัติ (รอ ~1 นาที) M เทสต์บนมือถือจริง (iOS) แล้วส่ง screenshot กลับมา

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

## งานค้าง (ณ v3.7.100)
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

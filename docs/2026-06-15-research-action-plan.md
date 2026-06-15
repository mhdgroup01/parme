# Paruay Action Plan — จากงานวิจัย 2025

> Generated 2026-06-15 จาก research workflow (52 agents, audit + adversarial review).
> Source research ใน second brain: `~/Desktop/DemoVault/wiki/concepts/` (framework-performance-landscape, database-cost-optimization).

## สรุป

- ทำ audit + adversarial review ของ 39 recommendations → ผ่าน 23 ข้อ
- **Root cause ที่ใหญ่ที่สุด:** realtime write-amplification (chat message → 7 round-trips ต่อ client)
- **Quick win ที่คุ้มที่สุด:** rebuild indexes (M รัน SQL ครั้งเดียว)
- **Long-term ปฏิเสธแล้ว:** PowerSync / Vite / Cloudflare Pages — เหตุผลใน CLAUDE.md

---

## v3.7.37 — เสร็จแล้วใน commit นี้

1. **1.1 ลบ shop-enumeration probe** — `index.html:28852-28862` (info leak fix)
2. **1.2 Preconnect Supabase + jsDelivr** — `index.html:8-12` (ลด TLS handshake 150-200ms)
3. **1.4 แก้ CLAUDE.md ลบ "Babel" claim** — Paruay ใช้ React.createElement ตรงๆ ไม่มี Babel runtime
4. **1.5 เพิ่ม Decision Record ใน CLAUDE.md** — กันเสนอ migration ซ้ำใน session ถัดไป

---

## รออยู่ — M ต้องทำ

### A. รัน SQL indexes (10 นาทีใน Supabase SQL editor)

ไฟล์: [`tools/migrations/2026-06-15-research-indexes.sql`](../tools/migrations/2026-06-15-research-indexes.sql)

- Index ใหม่ครอบคลุม: family hot path, friendships/trips .or() patterns, POS, admin
- `CONCURRENTLY` — ไม่ block table
- รันทีละ statement (Supabase SQL editor จะแยกให้)

### B. ทดสอบ POS sync 2 เครื่อง (งานค้างเดิม)

ก่อนทำ delta-merge (2.1, 2.2) ต้องยืนยันก่อนว่า v3.7.36 QR fix ทำงานถูกต้อง

---

## Sprint ถัดไป — Claude ทำ (รอ M รัน SQL ก่อน)

### 2.1 Delta-merge แทน loadDetail reload (family realtime) — `index.html:10059-10102`

- Channel handlers ปัจจุบันยิง `loadDetail(fam)` ทุกครั้ง → 7 RTT ต่อ chat message
- แก้: merge `payload.new/old` เข้า state ในหน่วยความจำตรงๆ
- ต้องทำเพิ่ม:
  - คง broadcast typing handler
  - families channel: merge เฉพาะ column ของ families, อย่า overwrite income_goal/expense_goal/categories (มาจาก family_finance)
  - profile fallback: fetch 1 profile (coalesce 250ms) ถ้า user_id ใหม่
  - ลบ loadDetail() ซ้ำหลัง local writes (8 จุด)
  - Reconnect resync: เรียก loadDetail() เต็มเมื่อ SUBSCRIBED, visibilitychange, online

**Impact:** สูง · **Effort:** M-L · **Risk:** medium (regression risk ถ้าทำไม่ครบ)

### 2.2 POS realtime delta-merge — `index.html:16252-16263`

- คล้าย 2.1 แต่สำหรับ POS (pos_sales, pos_products, pos_categories, pos_open_bills)
- prereq: M ทดสอบ QR fix ก่อน

### 2.3 Cursor-based polling (transactions/ious) — `index.html:12324-12348`

- แทน fetch ทั้งหมด → `.gt('updated_at', lastPoll).limit(500)`
- ต้องการ `updated_at` column ใน DB (SQL ใน sprint ถัดไป)
- เก็บ poll loop ไว้ (เป็น iOS WebSocket fallback)

### 2.4 Admin dashboard summary RPC — `index.html:7771-7773, 7795-7829`

- ปัจจุบัน admin ดาวน์โหลด 10k+ rows + profiles ทั้งหมดต่อ page open
- แก้: สร้าง RPC `admin_dashboard_summary(p_since)` server-side aggregate

### 2.5 POS sales totals RPC (correctness fix) — `index.html:31683-31686`

- **Correctness bug จริง:** `sales.reduce(...)` บน `.limit(500)` → ร้านขาย > 500 บิลเห็นยอดตลอดชีพผิดเงียบๆ
- แก้: RPC `pos_sales_totals(p_shop)` คำนวณ server-side

---

## พิจารณาแล้ว — ไม่ทำ

ดู `CLAUDE.md` section "ตัดสินใจแล้ว — ไม่ทำ" สำหรับสรุปสั้น. รายการเต็มในเอกสาร research workflow:

- PowerSync / cr-sqlite migration (ขัด iron rules)
- Vite / SvelteKit migration (Babel claim ผิด — ลด bundle ปลอม)
- Cloudflare Pages migration (PWA origin break)
- Service Worker (ขัด single-file)
- Materialized view + pg_cron สำหรับ pos_sales_daily (over-engineered → ใช้ on-demand RPC แทน)
- IndexedDB แทน localStorage (cache ขนาด KB เท่านั้น — ไม่คุ้ม)
- Externalise Recharts CDN (savings จริง 130KB ไม่ใช่ 499KB)
- 11-DELETE → 1-RPC cascade (SQL ที่เสนอลบผิด table → data loss risk)

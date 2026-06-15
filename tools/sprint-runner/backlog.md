# Sprint Backlog

> เขียน task ตรงนี้ในรูป `- [ ] {task description}` 
> sprint-runner จะรันทีละ task — done = AI commit + bug-hunt ผ่าน
> mark `- [x]` หลัง PR merge

## Tasks

- [x] แก้ timezone mismatch ใน pos_sales_totals — DONE in c0e5c42 (v3.7.44, sprint-2026-06-16-0326)

- [x] แก้ POS sales realtime UPDATE prepend ผิดตำแหน่ง — DONE in a427310 (v3.7.45)

- [x] เพิ่ม load-more pagination สำหรับ POS sales history > 500 บิล — DONE in b5806a1 (v3.7.49)

- [x] 2.4 admin dashboard summary RPC — Phase A DONE in c8c6f78 (v3.7.50, additive). Phase B รอ M ตัดสินใจ 4 คำถามใน docs/sprint-stopped/

## Phase B (รอ design decisions จาก M)

- [ ] 2.4 Phase B — ตัด download user_activity 10k → ใช้ RPC ครอบทุก stat. ต้องตอบ 4 คำถามใน docs/sprint-stopped/2-4-admin-dashboard-summary-rpc-rpc-admin-dashboar.md ก่อน:
  - (1) RPC return อะไรบ้าง? (aggregates / + geo / + recent / + daily series)
  - (2) ยอม re-source growth chart, country/hour/weekday จาก RPC ไหม?
  - (3) CSV export: recent N / server-export?
  - (4) `activities` state ยังต้อง raw array (เพื่อ map + filteredActs) → ตัด download ไม่ได้จริงไหม?

## เสร็จแล้ว (history)

<!-- sprint-runner จะ append ที่นี่อัตโนมัติ -->

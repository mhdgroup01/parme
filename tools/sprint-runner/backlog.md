# Sprint Backlog

> เขียน task ตรงนี้ในรูป `- [ ] {task description}` 
> sprint-runner จะรันทีละ task — done = AI commit + bug-hunt ผ่าน
> mark `- [x]` หลัง PR merge

## Tasks

- [ ] 2.4 admin dashboard summary RPC — สร้าง RPC `admin_dashboard_summary(p_since)` server-side aggregation (DAU/MAU/top-actions, check is_admin SECURITY DEFINER) ใน tools/migrations/pending/. Client: แทนการดาวน์โหลด user_activity + profiles ทั้งหมดด้วย RPC call. ดู docs/2026-06-15-research-action-plan.md task 2.4. **สำคัญ:** ห้ามตัด Leaflet map (ใช้ lat/lng + ชื่อ), เก็บ profiles query แต่ paginate. ห้ามลบ/แก้ filteredActs / activity state ที่ใช้ทั่ว AdminDashboard — ถ้าเปลี่ยน source ของ activity ต้องเก็บ shape เดิม

- [ ] แก้ timezone mismatch ใน pos_sales_totals — bug LOW จาก bug-hunter report 2026-06-16-0205: RPC ใช้ Asia/Bangkok แต่ client mapSale.date + todayStr ใช้ UTC → ยอด today_rev ไม่ตรงในช่วงเที่ยงคืน-เช้า. แก้: เปลี่ยน RPC ให้ใช้ UTC ให้ตรงกับ client (สร้าง migration ใหม่ใน pending/ — ALTER OR REPLACE FUNCTION). อย่าเปลี่ยน client timezone เพราะกระทบทุกที่

- [ ] แก้ POS sales realtime UPDATE prepend ผิดตำแหน่ง — bug LOW จาก bug-hunter report 2026-06-16-0205: ใน mergeRow สาขา UPDATE เมื่อ idx<0 (บิลอยู่นอก 500 ที่โหลด) ปัจจุบัน prepend ทื่อๆ ทำให้บิลเก่าเด้งขึ้นหัวลิสต์ผิด. แก้: ใน mergeRow สาขา UPDATE ถ้า idx<0 ให้ ignore (ไม่ insert — บิลอยู่นอก window) แทนการ prepend. เฉพาะตาราง pos_sales (products/categories ไม่กระทบ)

- [ ] เพิ่ม load-more pagination สำหรับ POS sales history > 500 บิล — ปัจจุบัน loadShopData ใช้ .limit(500) แต่ UI ไม่มีปุ่ม "ดูบิลเก่ากว่านี้". แก้: เพิ่มปุ่ม "โหลดเพิ่ม" ใน POS history view ที่ดึง pos_sales เก่ากว่า bill ล่างสุดที่มี (.lt('created_at', oldestCreatedAt).limit(100)). ไม่ใช้ infinite scroll (single-file PWA, simple). UI: ปุ่มท้ายลิสต์ + count "แสดง N จาก ?"

## เสร็จแล้ว (history)

<!-- sprint-runner จะ append ที่นี่อัตโนมัติ -->

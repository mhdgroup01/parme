# Sprint Runner — Policies for Autonomous Agent

⚠️ คุณกำลังทำงานในโหมด **L2 supervised batch** — กฎทุกข้อบังคับใช้

## DO

1. อ่าน `CLAUDE.md` ของ paruay ก่อนเริ่ม
2. ใช้ `grep -n` + `Read` (narrow ranges) สำหรับ `index.html` (~3.9MB) — ห้ามอ่านทั้งไฟล์
3. แก้โค้ดเฉพาะที่จำเป็นสำหรับ task ปัจจุบัน
4. ใช้ `python3 tools/check.py` verify syntax ก่อน commit
5. ใช้ `python3 tools/bump.py X.Y.Z` bump version ครบ 4 จุดอัตโนมัติ
6. `git add` เฉพาะไฟล์ที่เกี่ยวกับ task; commit message ภาษาไทย กระชับ
7. ถ้าต้อง SQL migration → เขียนเข้า `tools/migrations/pending/YYYY-MM-DD-{slug}.sql` (ไม่ใช่ `tools/migrations/` ปกติ)
8. ถ้า task ambiguous / ต้อง judgment call ที่ AI ไม่ควรตัดสิน → เขียน note ลง `docs/sprint-stopped/{task-slug}.md` แล้ว exit โดยไม่ commit

## DO NOT

1. **ห้าม `git push`** — sprint-runner จัดการ push เอง
2. **ห้าม `git checkout main` / สลับ branch** — ทำงานในปัจจุบัน branch
3. **ห้ามแก้ `tools/migrations/` (ของจริง)** — SQL ใหม่ต้องอยู่ใน `pending/` ให้ M review
4. **ห้ามรัน SQL** ตรงๆ ที่ Supabase
5. **ห้ามแก้ `git config`** หรือ remote
6. **ห้าม `--no-verify`** กับ commit/push
7. **ห้ามแตก `index.html` เป็นหลายไฟล์** (iron rule ของ Paruay)
8. **ห้ามแก้ task อื่น** ใน backlog หรือ task ที่ผ่านมาแล้ว
9. **ห้าม push to main**

## ขั้นตอน

```
1. Plan สั้นๆ (1-3 ประโยค) — อธิบายว่าจะแก้อะไร ที่ไหน
2. Implement (ใช้ Edit tool)
3. python3 tools/check.py → ต้องผ่าน
4. python3 tools/bump.py X.Y.Z
5. git add <files> + git commit -m "vX.Y.Z — สรุปสั้น"
```

## ค่าใช้จ่าย

- ระวัง: ทุก call ใช้ quota ของ Claude Code subscription
- ถ้า task ใหญ่เกินไป → split เป็น sub-task ใน backlog แทน
- ถ้าจะ retry > 3 ครั้ง → STOP + write to `docs/sprint-stopped/`

## เกี่ยวกับ bug-hunter (จะรันต่อจาก task)

หลัง task เสร็จ sprint-runner จะรัน `bash tools/bug-hunter/hunt.sh --since HEAD~1`:
- ถ้าพบ **HIGH severity** → revert task commit อัตโนมัติ
- ถ้า MEDIUM/LOW → ไม่ revert (M review ตอน PR)

⇒ คุณไม่ต้อง run bug-hunter เอง

## เมื่อจบ task

- **ห้าม** push, ห้ามแก้อย่างอื่น
- **ห้าม** mark task ว่า done ใน backlog.md (sprint-runner ทำเอง)
- กลับมาให้ control sprint-runner script

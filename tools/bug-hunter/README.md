# bug-hunter — AI bug audit สำหรับ Paruay

Tool ง่ายๆ ใช้ `claude -p` (subscription quota — ไม่ต้องตั้ง API key แยก) หา bug ในโค้ดให้เอง

## ใช้ยังไง

```bash
# ตรวจ diff 3 commit ล่าสุด (default — ใช้บ่อยสุด หลัง commit แล้วอยากเช็คก่อน push)
bash tools/bug-hunter/hunt.sh

# ตรวจทั้งไฟล์ (deep audit — ทำเดือนละครั้ง)
bash tools/bug-hunter/hunt.sh --full

# ตรวจตั้งแต่ tag/commit ใด commit หนึ่ง
bash tools/bug-hunter/hunt.sh --since v3.7.37
```

ผลลัพธ์เขียนลง `docs/bug-reports/YYYY-MM-DD-HHMM.md` (gitignore แล้ว — ไม่ commit เข้า repo)

## ใช้ token เท่าไหร่

~1 ครั้ง `claude -p` ต่อ run (~30-60 วินาที)
- diff mode: น้อย เพราะ scope แคบ
- --full: เยอะกว่าหน่อย (แต่ agent ใช้ grep เป็นหลัก ไม่อ่านทั้งไฟล์)

ใช้ quota ของ Claude Code Pro/Max — ถ้าใช้แผน paid อยู่แล้ว = ไม่มี cost เพิ่ม

## ทำไม "1 prompt + self-verify"

Workflow ใหญ่ (50+ agent + adversarial verify หลายชั้น) ได้ผลแม่น แต่:
- ใช้ token เยอะ (workflow research วันก่อนใช้ 2.2M tokens)
- ใช้เวลานาน (~30 นาที)
- ต้อง orchestration framework

Self-verify รอบเดียวประหยัดกว่า แลกกับ false positive ~30% — ยอมรับได้สำหรับ daily/post-commit ใช้

ถ้าวันไหนอยากตรวจลึกแบบ workflow เต็ม → บอกใน Claude Code session ปกติได้

## ดูประวัติ report

```bash
ls -lt docs/bug-reports/ | head -10
```

## ปัญหาที่อาจเจอ

**`claude: command not found`** → install Claude Code: https://claude.com/code

**Report ว่าง / agent ไม่เขียน** → อาจถูก rate-limit (รอสักครู่) หรือ prompt ยาวเกิน (ลอง `--full` แบ่งหลายรอบ)

**ผิดมาก / false positive เยอะ** → ดู `## พิจารณาแล้วไม่ใช่ bug` ใน report (transparency section) ถ้า refuted น้อย แสดงว่า self-verify อ่อน — บอกผม จะปรับ prompt

# sprint-runner — L2 supervised batch automation

AI ทำงาน sprint แทน — รัน tasks autonomous, bug-hunt ทุก commit, push branch (ไม่ใช่ main)

ดู [[ai-augmented-dev-loop]] ใน second brain สำหรับ pattern เต็ม

## ใช้ยังไง

### 1. เขียน task ลง backlog

แก้ `tools/sprint-runner/backlog.md`:

```markdown
## Tasks
- [ ] 2.4 admin dashboard summary RPC
- [ ] เพิ่ม dark mode toggle ใน settings
- [ ] แก้ค่ารวมต่อเดือนหน้า report ไม่ตรงกับ home
```

### 2. รัน

```bash
bash tools/sprint-runner/run.sh           # ทุก task
bash tools/sprint-runner/run.sh --dry     # plan only (ดูว่าจะทำอะไร)
bash tools/sprint-runner/run.sh --one     # ทำแค่ task แรก แล้วหยุด
```

### 3. หลังรัน sprint

Sprint-runner จะ:
- สร้าง branch `sprint-YYYY-MM-DD-HHMM` (ถ้าอยู่ main)
- รัน task ทีละอันใน loop
- หลังทุก task: `node --check` + `bug-hunter` → ถ้า HIGH bug → revert อัตโนมัติ
- Push branch (NOT main)
- พิมพ์คำสั่ง PR

แล้วคุณ:
1. `git diff main...sprint-...` ดู PR diff
2. รัน SQL ใน `tools/migrations/pending/` (ถ้ามี)
3. `gh pr create` หรือเปิดผ่าน web
4. Review → merge

## Safety

- ✅ Branch-only push (ห้าม push main)
- ✅ SQL ใหม่ → `tools/migrations/pending/` ให้คุณ review ก่อนรัน
- ✅ Auto-revert ถ้า bug-hunter เจอ HIGH
- ✅ Auto-revert ถ้า syntax check fail
- ✅ Ambiguous task → AI เขียน note ลง `docs/sprint-stopped/` ไม่ commit
- ✅ Iron rules ของ Paruay บังคับใน policies (no build, single file ฯลฯ)

## ต้นทุน

- 1 task ≈ 5-20 claude calls (plan + read + edit + check + retry + bug-hunt)
- 1 sprint (3-5 tasks) ≈ 30-100 calls
- ใช้ quota Claude Code subscription (ไม่ต้อง API key)

## ปัญหาที่อาจเจอ

**Task เลื่อน (ไม่ commit, ไม่ revert)** → AI ตัดสินว่า ambiguous, ดู `docs/sprint-stopped/{slug}.md`

**บั๊กที่ bug-hunter จับไม่ได้ผ่านมาได้** → คุณ review ตอน PR (เคยเจอ false-negative rate ~25% ของ self-verify)

**SQL migration ผิด** → คุณ review ก่อนรันใน `tools/migrations/pending/` — เป็นเหตุผลที่บังคับใส่ pending/

**Push fail** → script แค่ print คำสั่งให้รันเอง (ไม่บังคับ)

## Files

- `run.sh` — entry point (bash)
- `policies.md` — กฎที่ AI ต้องทำตาม (ส่งเป็น prompt prefix)
- `backlog.md` — task list (คุณแก้)
- `README.md` — เอกสารนี้

ขั้นถัดไป (sprint จริงๆ ครั้งแรก) → รัน `bash tools/sprint-runner/run.sh --dry` ดูว่าจะทำอะไรก่อน

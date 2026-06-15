#!/usr/bin/env bash
# bug-hunter — AI bug audit for Paruay (single-file React PWA)
# Uses `claude -p` (subscription quota — no extra API key needed)
# Usage:
#   bash tools/bug-hunter/hunt.sh              # diff since HEAD~3
#   bash tools/bug-hunter/hunt.sh --full       # full index.html
#   bash tools/bug-hunter/hunt.sh --since v3.7.37   # since git tag/commit
set -euo pipefail

# ── locate paruay root (script is at tools/bug-hunter/) ──
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$ROOT"

# ── locate claude CLI (Claude Code installer ปกติติดที่ ~/.local/bin) ──
CLAUDE_BIN=""
for cand in \
  "$HOME/.local/bin/claude" \
  "$HOME/.claude/bin/claude" \
  "/opt/homebrew/bin/claude" \
  "/usr/local/bin/claude"; do
  [ -x "$cand" ] && CLAUDE_BIN="$cand" && break
done
if [ -z "$CLAUDE_BIN" ]; then
  CLAUDE_BIN="$(command -v claude 2>/dev/null || true)"
fi
if [ -z "$CLAUDE_BIN" ]; then
  echo "❌ ไม่เจอ claude CLI — install Claude Code: https://claude.com/code" >&2
  exit 1
fi

# ── parse args ──
MODE="diff"
SINCE_REF=""
if [ "${1:-}" = "--full" ]; then
  MODE="full"
elif [ "${1:-}" = "--since" ] && [ -n "${2:-}" ]; then
  MODE="since"
  SINCE_REF="$2"
fi

# ── setup output ──
TS="$(date +%Y-%m-%d-%H%M)"
REPORT_DIR="docs/bug-reports"
REPORT="$REPORT_DIR/$TS.md"
mkdir -p "$REPORT_DIR"

# ── compute scope description for the agent ──
case "$MODE" in
  diff)
    CHANGED="$(git diff HEAD~3 --name-only 2>/dev/null | grep -v '^docs/' | grep -v '^tools/bug-hunter/' | tr '\n' ' ' | sed 's/ $//')"
    [ -z "$CHANGED" ] && CHANGED="index.html"
    SCOPE_DESC="ไฟล์ที่เปลี่ยนใน 3 commit ล่าสุด: $CHANGED + จุดที่ interaction ใกล้เคียง"
    ;;
  since)
    CHANGED="$(git diff "$SINCE_REF" --name-only 2>/dev/null | grep -v '^docs/' | grep -v '^tools/bug-hunter/' | tr '\n' ' ' | sed 's/ $//')"
    [ -z "$CHANGED" ] && CHANGED="index.html"
    SCOPE_DESC="ไฟล์ที่เปลี่ยนตั้งแต่ $SINCE_REF: $CHANGED"
    ;;
  full)
    SCOPE_DESC="ทั้ง index.html (ใช้ grep -n ช่วย ไม่อ่านทั้งไฟล์)"
    ;;
esac

# ── build prompt ──
PROMPT="คุณคือ bug hunter สำหรับ Paruay (single-file React PWA, ~3.9MB, ~150k บรรทัด)

สภาพแวดล้อม:
- Working directory: $ROOT
- โค้ดอยู่ใน index.html ทั้งหมด — **อย่าอ่านทั้งไฟล์** ใช้ \`grep -n\` หา pattern แล้ว Read เฉพาะช่วงแคบๆ
- ใช้ React.createElement (ไม่ใช้ Babel runtime), Supabase backend (Singapore region)
- Iron rules: single file, no build step, GitHub Pages deploy

📍 SCOPE: $SCOPE_DESC

🔎 มองหาอะไร (เน้น bug จริง ไม่ใช่ optimization):
1. **Async/race**: stale closure ใน useEffect, missing cleanup, double-firing handler, useEffect deps ที่หาย/เกิน
2. **State**: direct mutation แทน immutable update, setState ใน async ที่ component อาจ unmount แล้ว
3. **Supabase**: N+1 query, .or() ที่ไม่มี index, missing .eq tenant column, query inside loop, ใช้ \`select('*')\` ใน hot path ใหญ่
4. **Security/privacy**: anon role enumerate ได้, error message รั่วข้อมูลผู้ใช้, ใช้ console.log แสดงข้อมูล sensitive
5. **Memory leak**: addEventListener ไม่ removeEventListener, supabase.channel ไม่ removeChannel
6. **Correctness**: off-by-one, reduce บน array ที่ paginate (เห็นผลผิดเมื่อข้อมูลโต), date/timezone bug, parseInt ไม่ใส่ radix

🧪 METHODOLOGY (สำคัญ — ลด false positive):
1. **FIND**: หา pattern ที่น่าสงสัย
2. **SELF-VERIFY** แต่ละจุด ถามตัวเอง 3 ข้อ:
   - มันเป็น bug ของจริงในการใช้งานจริง หรือ theoretical?
   - มี code อื่น handle เคสนี้อยู่แล้วไหม (cleanup, dedupe, retry)?
   - reproduce ได้จริงไหม? บรรยายขั้นตอน
3. **เก็บเฉพาะที่ผ่าน self-verify ทั้ง 3 ข้อ** — refuted ให้แยกใส่ section ท้าย

📄 OUTPUT: เขียน markdown ลง \`$REPORT\` ด้วยโครงนี้:

\`\`\`
# Bug Report — $TS
**Scope:** $SCOPE_DESC

## สรุป
- พบ N findings (X high, Y medium, Z low) หลัง self-verify
- พิจารณาแล้วไม่ใช่ bug: M ข้อ (อยู่ section ล่าง)

## Findings

### [HIGH] หัวเรื่องสั้น
- **ที่ไหน:** index.html:LINE
- **อาการ:** อะไรจะเกิด + ทำไมเป็น bug
- **Reproduce:** ขั้นตอนทดลอง
- **เสนอแก้:** สั้นๆ

### [MEDIUM] ...
### [LOW] ...

## พิจารณาแล้วไม่ใช่ bug (transparency)
- [refuted] ชื่อ — ทำไมตัดออก
\`\`\`

ภาษา: เขียนเป็น **ภาษาไทย**

❌ ห้าม:
- ห้ามแต่ง finding ลอย ๆ — ทุก finding ต้องอ้าง file:line จริง
- ห้ามรายงาน optimization / style / refactor — เน้น **bug จริง** เท่านั้น
- ถ้าไม่เจออะไรเลย → เขียน 'ไม่พบ bug ใน scope นี้' ก็พอ"

# ── run ──
echo "🔍 Bug hunt: $MODE ($SCOPE_DESC)"
echo "📝 Report → $REPORT"
echo

"$CLAUDE_BIN" -p "$PROMPT"

echo
echo "✓ เสร็จแล้ว — เปิดดู:"
echo "   open $REPORT"

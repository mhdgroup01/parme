#!/usr/bin/env bash
# sprint-runner — L2 supervised batch automation
# Runs tasks from backlog.md autonomously, bug-hunts each, pushes BRANCH (not main)
#
# Usage:
#   bash tools/sprint-runner/run.sh            # run all unchecked tasks
#   bash tools/sprint-runner/run.sh --dry      # plan only (no execution)
#   bash tools/sprint-runner/run.sh --one      # run only the first task
set -euo pipefail

# ── locate paruay root ──
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$ROOT"

# ── locate claude CLI ──
CLAUDE_BIN=""
for cand in \
  "$HOME/.local/bin/claude" \
  "$HOME/.claude/bin/claude" \
  "/opt/homebrew/bin/claude" \
  "/usr/local/bin/claude"; do
  [ -x "$cand" ] && CLAUDE_BIN="$cand" && break
done
[ -z "$CLAUDE_BIN" ] && CLAUDE_BIN="$(command -v claude 2>/dev/null || true)"
if [ -z "$CLAUDE_BIN" ]; then
  echo "❌ claude CLI not found" >&2
  exit 1
fi

# ── parse args ──
MODE="all"
case "${1:-}" in
  --dry) MODE="dry" ;;
  --one) MODE="one" ;;
  "") MODE="all" ;;
  *) echo "Unknown arg: $1" >&2; exit 1 ;;
esac

BACKLOG="tools/sprint-runner/backlog.md"
POLICIES="tools/sprint-runner/policies.md"
STOPPED_DIR="docs/sprint-stopped"
PENDING_SQL="tools/migrations/pending"
mkdir -p "$STOPPED_DIR" "$PENDING_SQL"

# ── safety: must NOT be on main ──
CUR_BRANCH="$(git branch --show-current)"
if [ "$CUR_BRANCH" = "main" ] || [ "$CUR_BRANCH" = "master" ]; then
  NEW_BRANCH="sprint-$(date +%Y-%m-%d-%H%M)"
  echo "→ on $CUR_BRANCH — creating sprint branch: $NEW_BRANCH"
  if [ "$MODE" != "dry" ]; then
    git checkout -b "$NEW_BRANCH"
    CUR_BRANCH="$NEW_BRANCH"
  fi
fi

# ── commit pending backlog edits ก่อนเริ่ม (กัน revert ลบ user edits) ──
if [ "$MODE" != "dry" ] && ! git diff --quiet "$BACKLOG"; then
  echo "→ committing pending backlog edits"
  git add "$BACKLOG"
  git commit -m "backlog: queue tasks for sprint $(date +%Y-%m-%d)" --quiet
fi

# ── parse unchecked tasks from backlog (compat with bash 3.x on macOS) ──
TASKS=()
while IFS= read -r line; do
  [ -n "$line" ] && TASKS+=("$line")
done < <(grep -E '^- \[ \] ' "$BACKLOG" | sed -E 's/^- \[ \] //')

if [ "${#TASKS[@]}" -eq 0 ]; then
  echo "No unchecked tasks in $BACKLOG"
  exit 0
fi

echo
echo "═══════════════════════════════════════════════════"
echo "  Sprint Runner — found ${#TASKS[@]} task(s)"
echo "  Branch: $CUR_BRANCH"
echo "  Mode: $MODE"
echo "═══════════════════════════════════════════════════"

# ── loop ──
DONE_COUNT=0
SKIP_COUNT=0
REVERT_COUNT=0
SUMMARY=""

for TASK in "${TASKS[@]}"; do
  echo
  echo "▶ Task: $TASK"
  echo "─────────────────────────────────────────────"

  if [ "$MODE" = "dry" ]; then
    echo "[dry-run] would invoke claude with task"
    SUMMARY="${SUMMARY}\n• [dry] $TASK"
    continue
  fi

  BEFORE_HEAD="$(git rev-parse HEAD)"
  TASK_SLUG="$(echo "$TASK" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed -E 's/^-+|-+$//g' | cut -c1-50)"
  # v2 — เก็บ backlog ตัวจริง (uncommitted edits ของ user) ไว้แยก ป้องกัน revert ลบทิ้ง
  cp "$BACKLOG" /tmp/sprint-backlog-snapshot.md

  # ── build prompt ──
  PROMPT="$(cat "$POLICIES")

═══════════════════════════════════════════════════
CURRENT TASK: $TASK
TASK SLUG (for stopped/migration files): $TASK_SLUG
WORKING DIRECTORY: $ROOT
CURRENT BRANCH: $CUR_BRANCH (เก็บไว้ใน branch นี้ — ห้าม checkout)
═══════════════════════════════════════════════════

อ่าน CLAUDE.md ก่อน → plan สั้นๆ → implement → check.py → bump → commit
ตามขั้นตอนใน policies. ตอบกลับสั้นที่สุด — เน้นการ commit ที่ดี ไม่ใช่ explain"

  # ── run claude ──
  set +e
  "$CLAUDE_BIN" -p "$PROMPT" 2>&1 | tee /tmp/sprint-task.log | tail -20
  CLAUDE_EXIT=$?
  set -e

  AFTER_HEAD="$(git rev-parse HEAD)"

  if [ "$BEFORE_HEAD" = "$AFTER_HEAD" ]; then
    echo "⚠ no commit made — task skipped"
    SKIP_COUNT=$((SKIP_COUNT + 1))
    SUMMARY="${SUMMARY}\n• ⊘ skipped: $TASK"
    if [ "$MODE" = "one" ]; then break; fi
    continue
  fi

  # ── post-checks: syntax ──
  if ! python3 tools/check.py > /tmp/sprint-check.log 2>&1; then
    echo "✗ syntax check failed → revert"
    cat /tmp/sprint-check.log | tail -10
    git reset --hard "$BEFORE_HEAD"
    cp /tmp/sprint-backlog-snapshot.md "$BACKLOG"  # restore user backlog edits
    REVERT_COUNT=$((REVERT_COUNT + 1))
    SUMMARY="${SUMMARY}\n• ✗ reverted (syntax): $TASK"
    if [ "$MODE" = "one" ]; then break; fi
    continue
  fi

  # ── post-checks: bug-hunter ──
  echo "→ running bug-hunter on new commit..."
  set +e
  bash tools/bug-hunter/hunt.sh --since "$BEFORE_HEAD" > /tmp/sprint-hunt.log 2>&1
  HUNT_EXIT=$?
  set -e

  if grep -q '\[HIGH\]' /tmp/sprint-hunt.log; then
    echo "✗ bug-hunter found HIGH → revert"
    grep '\[HIGH\]' /tmp/sprint-hunt.log | head -3
    git reset --hard "$BEFORE_HEAD"
    cp /tmp/sprint-backlog-snapshot.md "$BACKLOG"  # restore user backlog edits
    REVERT_COUNT=$((REVERT_COUNT + 1))
    SUMMARY="${SUMMARY}\n• ✗ reverted (HIGH bug): $TASK"
    if [ "$MODE" = "one" ]; then break; fi
    continue
  fi

  # ── done ──
  echo "✓ task complete"
  DONE_COUNT=$((DONE_COUNT + 1))
  COMMIT_MSG="$(git log -1 --format=%s)"
  SUMMARY="${SUMMARY}\n• ✓ $TASK\n   commit: $COMMIT_MSG"

  if [ "$MODE" = "one" ]; then break; fi
done

# ── push (if any commits made) ──
echo
echo "═══════════════════════════════════════════════════"
echo "  Summary"
echo "═══════════════════════════════════════════════════"
echo -e "Done:     $DONE_COUNT"
echo -e "Skipped:  $SKIP_COUNT"
echo -e "Reverted: $REVERT_COUNT"
echo -e "$SUMMARY"

if [ "$MODE" = "dry" ]; then
  echo
  echo "(dry-run — no commits made)"
  exit 0
fi

if [ "$DONE_COUNT" -eq 0 ]; then
  echo
  echo "No commits to push."
  exit 0
fi

echo
echo "→ pushing branch $CUR_BRANCH..."
set +e
git push -u origin "$CUR_BRANCH" 2>&1 | tail -3
PUSH_EXIT=$?
set -e

if [ "$PUSH_EXIT" -ne 0 ]; then
  echo
  echo "⚠ push failed — try manually:  git push -u origin $CUR_BRANCH"
  exit 1
fi

echo
echo "═══════════════════════════════════════════════════"
echo "✓ Branch pushed. Next steps:"
echo "═══════════════════════════════════════════════════"
echo "1. Review diff on GitHub or via:"
echo "     git diff main...$CUR_BRANCH"
echo "2. รัน SQL ใน tools/migrations/pending/ (ถ้ามี) ผ่าน Supabase SQL editor"
echo "3. Create PR:"
echo "     gh pr create --title 'Sprint $CUR_BRANCH' --body \"\$(cat tools/sprint-runner/backlog.md)\""
echo "   หรือผ่าน GitHub web"
echo "4. Merge → GitHub Pages auto-deploy"

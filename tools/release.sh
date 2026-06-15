#!/usr/bin/env bash
# Paruay release helper — bump 4 จุด -> node --check -> โชว์ diff + คำสั่ง commit/push
# ไม่ push ให้อัตโนมัติ (ให้ M รีวิวก่อน)
#
# ใช้:  bash tools/release.sh 3.7.36 "สรุปสั้นของรุ่นนี้"
set -euo pipefail
cd "$(dirname "$0")/.."

VER="${1:?ใส่เวอร์ชัน เช่น 3.7.36}"
MSG="${2:-}"
[[ "$VER" == v* ]] || VER="v$VER"

echo "==> bump เป็น $VER"
python3 tools/bump.py "$VER"

echo "==> node --check"
python3 tools/check.py

echo "==> git diff (เฉพาะ index.html)"
git diff --stat index.html || true

echo ""
echo "ผ่านหมดแล้ว ✓  ขั้นต่อไป (รันเองเมื่อพร้อม deploy):"
if [[ -n "$MSG" ]]; then
  echo "  git add index.html && git commit -m \"$VER — $MSG\" && git push"
else
  echo "  git add index.html && git commit -m \"$VER — <สรุปสั้น>\" && git push"
fi
echo "  (GitHub Pages deploy อัตโนมัติ ~1 นาที: https://mhdgroup01.github.io/paruay/)"

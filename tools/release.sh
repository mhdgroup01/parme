#!/usr/bin/env bash
# Parme release helper — bump 4 จุด -> node --check -> พิมพ์ขั้นตอน deploy จริงพร้อมค่าที่กรอกไว้ให้แล้ว
# ไม่ deploy / ไม่ push ให้อัตโนมัติ (ให้เจ้าของรีวิวก่อน)
#
# ใช้:  bash tools/release.sh 3.7.412 "สรุปสั้นของรุ่นนี้"
#
# v3.7.412 — เขียนใหม่: ของเดิมบอกให้ push แล้วรอ GitHub Pages ซึ่ง **ไม่ใช่ prod ตั้งแต่ v3.7.249**
# (prod = nginx บน VPS) และไม่รู้จัก parme.apk / app-version.json ที่แอปเนทีฟต้องใช้ตั้งแต่ v3.7.411
set -euo pipefail
cd "$(dirname "$0")/.."

VER="${1:?ใส่เวอร์ชัน เช่น 3.7.412}"
MSG="${2:-}"
[[ "$VER" == v* ]] || VER="v$VER"
NUM="${VER#v}"

VPS="root@187.127.209.83"
KEY="$HOME/.ssh/hostinger_vps_ed25519"
HTMLDIR="/docker/parme-prod/html"
APPDIR="$HOME/parme-app"
GRADLE="$APPDIR/android/app/build.gradle"

echo "==> bump เป็น $VER"
python3 tools/bump.py "$VER"

echo "==> node --check"
python3 tools/check.py

echo "==> git diff (เฉพาะ index.html)"
git diff --stat index.html || true

# sw.js เปลี่ยนด้วยไหม — ถ้าเปลี่ยนต้อง rsync ตามไป ไม่งั้น shell ออฟไลน์ค้างเวอร์ชันเก่า
# ใช้ git status ไม่ใช่ git diff: ถ้าเจ้าของ git add ไปแล้ว git diff จะมองไม่เห็น (ตาบอดเงียบๆ)
SW_CHANGED=""
git status --porcelain -- sw.js | grep -q . && SW_CHANGED=1 || true

# เวอร์ชันของแอปเนทีฟ — แบนเนอร์ในแอปเทียบ versionCode ของตัวเองกับ app-version.json บนเว็บ
VC=""; VN=""
if [[ -f "$GRADLE" ]]; then
  VC=$(grep -Eo 'versionCode[[:space:]]+[0-9]+' "$GRADLE" | grep -Eo '[0-9]+' | head -1 || true)
  VN=$(grep -Eo 'versionName[[:space:]]+"[^"]+"' "$GRADLE" | sed 's/.*"\(.*\)"/\1/' | head -1 || true)
fi
NEWVC="${VC:-?}"
[[ -n "$VC" && "$VN" != "$NUM" ]] && NEWVC=$((VC + 1))

echo ""
echo "ผ่านหมดแล้ว ✓  ขั้นต่อไป (รันเองเมื่อพร้อม deploy)"
echo "prod ตัวจริง = nginx บน VPS — push GitHub อย่างเดียว 'ไม่' deploy"
echo ""
echo "  # 1) เว็บ + PWA"
echo "  rsync -e \"ssh -i $KEY\" -av index.html $VPS:$HTMLDIR/index.html"
if [[ -n "$SW_CHANGED" ]]; then
echo "  rsync -e \"ssh -i $KEY\" -av sw.js $VPS:$HTMLDIR/sw.js      # sw.js เปลี่ยนรอบนี้"
fi
echo "  curl -s https://parme.me/ | grep -o 'app-version\" content=\"[^\"]*'"
echo ""
echo "  # 2) เก็บ repo ให้ตรง prod"
if [[ -n "$MSG" ]]; then
echo "  git add -A && git commit -m \"$VER — $MSG\" && git push"
else
echo "  git add -A && git commit -m \"$VER — <สรุปสั้น>\" && git push"
fi
echo ""
echo "  # 3) แอปเนทีฟ (ข้ามได้ถ้ารุ่นนี้ไม่ปล่อย APK ใหม่)"
if [[ -z "$VC" ]]; then
echo "  ⚠️  อ่าน versionCode จาก $GRADLE ไม่ได้ — เช็กเองก่อน build"
elif [[ "$VN" != "$NUM" ]]; then
echo "  ⚠️  ตอนนี้ $GRADLE เป็น versionName \"$VN\" / versionCode $VC"
echo "      → แก้เป็น versionName \"$NUM\" และ versionCode $NEWVC ก่อน build"
echo "      → iOS: MARKETING_VERSION = $NUM, CURRENT_PROJECT_VERSION = $NEWVC ใน ios/App/App.xcodeproj/project.pbxproj"
else
echo "  • $GRADLE ตรงกับ $NUM แล้ว (versionCode $VC)"
fi
APKOUT="$APPDIR/android/app/build/outputs/apk/release"
echo "  # ร้อยด้วย && ทั้งเส้น: ถ้าขั้นใดล้ม ต้องไม่ไปประกาศเวอร์ชันที่ยังไม่ได้อัป"
echo "  cp index.html sw.js $APPDIR/www/ \\"
echo "    && (cd $APPDIR && npx cap sync android && npx cap sync ios) \\"
echo "    && (cd $APPDIR/android && ./gradlew assembleRelease) \\"
echo "    && scp -i $KEY $APKOUT/app-release.apk $VPS:$HTMLDIR/parme.apk"
echo ""
echo "  # ประกาศเวอร์ชัน — อ่าน versionCode จาก APK ที่ build ออกมาจริง ไม่ใช่พิมพ์มือ"
echo "  # (ถ้าลืม bump build.gradle เลขที่ประกาศจะเท่าเดิม แบนเนอร์เงียบ = เห็นปัญหาทันที ดีกว่าประกาศเลขที่ไม่มีอยู่)"
echo "  VC=\$(python3 -c \"import json;print(json.load(open('$APKOUT/output-metadata.json'))['elements'][0]['versionCode'])\") \\"
echo "    && VN=\$(python3 -c \"import json;print(json.load(open('$APKOUT/output-metadata.json'))['elements'][0]['versionName'])\") \\"
echo "    && printf '{\"versionCode\":%s,\"versionName\":\"%s\",\"url\":\"https://parme.me/parme.apk\"}' \"\$VC\" \"\$VN\" \\"
echo "       | ssh -i $KEY $VPS 'cat > $HTMLDIR/app-version.json'"
echo ""
echo "  # ตรวจว่าที่ประกาศตรงกับไฟล์ที่เสิร์ฟจริง (สอง hash ต้องเท่ากัน)"
echo "  curl -sS -H 'Origin: https://localhost' https://parme.me/app-version.json; echo"
echo "  shasum -a 256 $APKOUT/app-release.apk | cut -d' ' -f1"
echo "  ssh -i $KEY $VPS 'sha256sum $HTMLDIR/parme.apk | cut -d\" \" -f1'"
echo ""
echo "  หมายเหตุ: app-version.json ต้องมี CORS — origin ของแอปคือ https://localhost (Android) / capacitor://localhost (iOS)"
echo "            กฎอยู่ใน /docker/parme-prod/default.conf — ถ้าหาย แบนเนอร์แจ้งเตือนอัปเดตจะเงียบสนิท"

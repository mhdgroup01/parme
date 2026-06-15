#!/usr/bin/env python3
"""Paruay syntax check — แยก script block หลักของแอป (block ที่มี APP_VERSION)
ออกมาแล้วรัน `node --check` ยืนยันว่าไม่มี syntax error ก่อน commit.

ใช้:  python3 tools/check.py        (จาก root ของ repo)
exit 0 = ผ่าน, exit 1 = มี syntax error / หา block ไม่เจอ
"""
import io, os, sys, subprocess, tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
HTML = os.path.join(ROOT, "index.html")

def main():
    src = io.open(HTML, encoding="utf-8").read()
    idx, app_code, blocks = 0, None, 0
    while True:
        s = src.find("<script", idx)
        if s == -1:
            break
        gt = src.find(">", s)
        e = src.find("</script>", gt)
        if e == -1:
            break
        code = src[gt + 1:e]
        blocks += 1
        if "APP_VERSION" in code:          # block หลักของแอป
            app_code = code
        idx = e + len("</script>")

    if app_code is None:
        print("✗ หา script block หลัก (ที่มี APP_VERSION) ไม่เจอ", file=sys.stderr)
        return 1

    tmp = os.path.join(tempfile.gettempdir(), "paruay_app.js")
    io.open(tmp, "w", encoding="utf-8").write(app_code)
    kb = len(app_code) // 1024
    print(f"• script blocks: {blocks} | main block: {kb}KB -> {tmp}")

    r = subprocess.run(["node", "--check", tmp])
    if r.returncode == 0:
        print("✓ node --check ผ่าน — ไม่มี syntax error")
    else:
        print("✗ node --check ล้มเหลว — แก้ก่อน commit", file=sys.stderr)
    return r.returncode

if __name__ == "__main__":
    sys.exit(main())

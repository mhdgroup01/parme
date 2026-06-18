#!/usr/bin/env python3
"""Paruay version bump — แก้เวอร์ชันครบ 4 จุด canonical พร้อมกัน อย่างปลอดภัย.

แก้เฉพาะ 4 จุดนี้ (ไม่แตะ comment ประวัติ // v3.7.xx):
  1) <title>ພາລວຍ · Paruay vX</title>
  2) <meta name="app-version" content="vX" />
  3) <div class="version-tag">vX</div>
  4) const APP_VERSION = 'vX';

ใช้:
  python3 tools/bump.py 3.7.36          # bump เป็น v3.7.36
  python3 tools/bump.py v3.7.36 --dry   # แสดงว่าจะแก้อะไร ไม่เขียนจริง

ความปลอดภัย: ยืนยันว่าทั้ง 4 pattern ของเวอร์ชันเดิมเจอ "จุดละ 1 ครั้งพอดี" ก่อน
ถ้าจุดใดไม่ใช่ 1 จะ abort โดยไม่เขียนไฟล์เลย (กันแก้ผิด/แก้ไม่ครบ).
"""
import io, os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
HTML = os.path.join(ROOT, "index.html")

def norm(v):
    v = v.strip()
    return v if v.startswith("v") else "v" + v

def patterns(ver):
    return [
        ("title",       f"<title>ພາme · Parme {ver}</title>"),
        ("meta",        f'name="app-version" content="{ver}"'),
        ("version-tag", f'class="version-tag">{ver}<'),
        ("APP_VERSION", f"APP_VERSION = '{ver}'"),
    ]

def main(argv):
    args = [a for a in argv if not a.startswith("--")]
    dry = "--dry" in argv
    if len(args) != 1:
        print(__doc__); return 2
    new = norm(args[0])

    src = io.open(HTML, encoding="utf-8").read()
    m = re.search(r"APP_VERSION = '(v[0-9.]+)'", src)
    if not m:
        print("✗ หา APP_VERSION ปัจจุบันไม่เจอ", file=sys.stderr); return 1
    old = m.group(1)
    if old == new:
        print(f"• เวอร์ชันปัจจุบันเป็น {old} อยู่แล้ว — ไม่มีอะไรต้องแก้"); return 0

    # ตรวจครบ 4 จุดก่อน (ทุกจุดต้องเจอ 1 ครั้งพอดี) — atomic
    errs = []
    for name, pat in patterns(old):
        c = src.count(pat)
        if c != 1:
            errs.append(f"  ✗ {name}: เจอ {c} ครั้ง (ต้องเป็น 1) — pattern: {pat!r}")
    if errs:
        print(f"ABORT: ตรวจจุด canonical ของ {old} ไม่ผ่าน:", *errs, sep="\n", file=sys.stderr)
        return 1

    print(f"• bump {old} -> {new}" + ("  [DRY RUN]" if dry else ""))
    out = src
    for name, pat in patterns(old):
        out = out.replace(pat, pat.replace(old, new))
        print(f"  ✓ {name}")

    # ยืนยันผลลัพธ์: ใหม่เจอ 4, เก่าใน canonical เหลือ 0
    for name, pat in patterns(new):
        assert out.count(pat) == 1, f"post-check fail: {name}"

    if dry:
        print("  (DRY RUN — ไม่ได้เขียนไฟล์) เอา --dry ออกเพื่อเขียนจริง")
        return 0
    io.open(HTML, "w", encoding="utf-8").write(out)
    print(f"✓ เขียนแล้ว — ต่อไป: python3 tools/check.py  แล้วค่อย git commit")
    return 0

if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

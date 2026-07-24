# -*- coding: utf-8 -*-
"""Render the guide content as a plain prose article (markdown), per language."""
import json, sys, io
DATA = '/tmp/paruay_guide_i18n.json'
lang = sys.argv[1] if len(sys.argv) > 1 else 'th'
OUT = sys.argv[2] if len(sys.argv) > 2 else '/Users/mickysili/parme/docs/paruay-guide.md'
data = json.load(open(DATA, encoding='utf-8'))

HEAD = {
 'th': {'title':'คู่มือการใช้งานพารวย (Paruay)',
   'intro':'พารวยเป็นแอปจัดการเงินที่รวมหลายระบบไว้ในแอปเดียว ตั้งแต่บันทึกรายรับ-รายจ่ายส่วนตัว หารบิลและให้ยืมกับเพื่อน จัดการเงินครอบครัวหรือกลุ่ม เปิดร้านขายของแบบ POS ออกทริปกับเพื่อน ไปจนถึงเล่นเกม บทความนี้อธิบายทุกฟังก์ชันแบบเรียงหัวข้อ เพื่อให้ผู้ใช้มือใหม่เริ่มต้นได้ทันที',
   'how':'วิธีใช้:','tip':'เคล็ดลับ:'},
 'lo': {'title':'ຄູ່ມືການນຳໃຊ້ ພາລວຍ (Paruay)',
   'intro':'ພາລວຍແມ່ນແອັບຈັດການເງິນທີ່ລວມຫຼາຍລະບົບໄວ້ໃນແອັບດຽວ ຕັ້ງແຕ່ບັນທຶກລາຍຮັບ-ລາຍຈ່າຍສ່ວນຕົວ, ຫານບິນ ແລະ ໃຫ້ຢືມກັບໝູ່, ຈັດການເງິນຄອບຄົວ ຫຼື ກຸ່ມ, ເປີດຮ້ານຂາຍເຄື່ອງແບບ POS, ອອກທິບກັບໝູ່ ໄປຈົນເຖິງຫຼິ້ນເກມ. ບົດຄວາມນີ້ອະທິບາຍທຸກຟັງຊັນແບບຮຽງຫົວຂໍ້ ເພື່ອໃຫ້ຜູ້ໃຊ້ມືໃໝ່ເລີ່ມຕົ້ນໄດ້ທັນທີ',
   'how':'ວິທີໃຊ້:','tip':'ເຄັດລັບ:'},
 'en': {'title':'Paruay User Guide',
   'intro':'Paruay is an all-in-one money app — personal income/expense tracking, splitting bills and lending with friends, family/group finances, a point-of-sale (POS) shop system, group trips, and even games. This article walks through every feature, topic by topic, so new users can get started right away.',
   'how':'How to:','tip':'Tip:'},
}[lang]

def strip_end(s): return s.rstrip(' .。·')

lines = ['# %s' % HEAD['title'], '', HEAD['intro'], '']
for di, dom_all in enumerate(data):
    dom = dom_all[lang]
    lines.append('## %d. %s' % (di + 1, dom['domain']))
    lines.append('')
    for sec in dom['sections']:
        lines.append('### %s %s' % (sec['emoji'], sec['title']))
        lines.append('')
        if sec.get('intro'):
            lines.append(sec['intro'])
            lines.append('')
        for f in sec['features']:
            para = '**%s** — %s' % (f['name'], strip_end(f['what']) + '.')
            if f.get('steps'):
                para += ' %s %s.' % (HEAD['how'], ' → '.join(strip_end(s) for s in f['steps']))
            if f.get('tip') and f['tip'].strip():
                para += ' *(%s %s)*' % (HEAD['tip'], strip_end(f['tip']))
            lines.append(para)
            lines.append('')
lines.append('---')
lines.append('เปิดแอป: **mhdgroup01.github.io/paruay** · คู่มือเว็บแอป: **mhdgroup01.github.io/paruay/guide.html**' if lang=='th'
             else ('ເປີດແອັບ: **mhdgroup01.github.io/paruay** · ຄູ່ມືເວັບແອັບ: **mhdgroup01.github.io/paruay/guide.html**' if lang=='lo'
                   else 'Open the app: **mhdgroup01.github.io/paruay** · Web guide: **mhdgroup01.github.io/paruay/guide.html**'))
md = '\n'.join(lines) + '\n'
io.open(OUT, 'w', encoding='utf-8').write(md)
print('wrote', OUT, '·', len(md), 'chars ·', md.count('**')//2, 'features')

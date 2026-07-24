# -*- coding: utf-8 -*-
"""Build the Paruay user-guide web app (guide.html), trilingual (th/lo/en) + illustrations."""
import json, html, io, sys
DATA = sys.argv[1] if len(sys.argv) > 1 else '/tmp/paruay_guide_i18n.json'
OUT = sys.argv[2] if len(sys.argv) > 2 else '/Users/mickysili/parme/guide.html'
data = json.load(open(DATA, encoding='utf-8'))   # list of {th,lo,en} domains

LANGS = ['th', 'lo', 'en']
def esc(s): return html.escape(s or '', quote=True)
def tint(hx, a):
    hx = hx.lstrip('#'); r,g,b = int(hx[0:2],16),int(hx[2:4],16),int(hx[4:6],16)
    return 'rgba(%d,%d,%d,%s)' % (r,g,b,a)

ACC = ['#1B7A43', '#C8902E', '#7C3AED', '#0E7C66', '#BE123C']
NAVL = {
 'th': ['การเงินส่วนตัว','เพื่อน · หารบิล · ให้ยืม','ครอบครัว · ทริป','ร้านค้า POS','เกม · ตั้งค่า · ระบบ'],
 'lo': ['ການເງິນສ່ວນຕົວ','ໝູ່ · ຫານບິນ · ໃຫ້ຢືມ','ຄອບຄົວ · ທິບ','ຮ້ານຄ້າ POS','ເກມ · ຕັ້ງຄ່າ · ລະບົບ'],
 'en': ['Personal finance','Friends · Split · Lend','Family · Trips','Shop (POS)','Games · Settings · System'],
}
UI = {
 'th': {'title':'คู่มือการใช้งาน พารวย','brandSub':'Paruay · คู่มือ','start':'เริ่มต้น / ภาพรวม',
   'sub':'แอปจัดการเงินครบในแอปเดียว — บันทึกรายรับรายจ่าย หารบิลกับเพื่อน ให้ยืม จัดการเงินครอบครัว เปิดร้านขายของ (POS) ออกทริป และเล่นเกม คู่มือนี้รวมทุกฟังก์ชันให้ผู้ใช้มือใหม่เริ่มได้ทันที',
   'ph':'ค้นหาฟังก์ชัน เช่น หารบิล, งบประมาณ, QR, ดอกเบี้ย ...','introTag':'หน้าจอหลัก',
   'introText':'เมื่อเปิดแอป คุณจะเห็น <b>การ์ดยอดเงิน</b> สีเขียวอยู่บนสุด ใต้ลงมาคือปุ่ม <b>รายรับ/รายจ่าย</b> สำหรับบันทึกเร็ว และแถว <b>ปุ่มเมนู 5 ปุ่ม</b> สำหรับฟีเจอร์หลัก — แตะหัวข้อทางซ้าย (หรือเมนู ☰ บนมือถือ) เพื่อข้ามไปยังส่วนที่สนใจได้เลย',
   'footer':'พารวย (Paruay) · คู่มือการใช้งาน · อัปเดต 16 มิ.ย. 2026','openApp':'เปิดแอป:',
   'mTotal':'ยอดเงินทั้งหมด','mIn':'+ รายรับ','mOut':'▽ รายจ่าย','back':'หน้าแรก'},
 'lo': {'title':'ຄູ່ມືການນຳໃຊ້ ພາລວຍ','brandSub':'Paruay · ຄູ່ມື','start':'ເລີ່ມຕົ້ນ / ພາບລວມ',
   'sub':'ແອັບຈັດການເງິນຄົບໃນແອັບດຽວ — ບັນທຶກລາຍຮັບລາຍຈ່າຍ, ຫານບິນກັບໝູ່, ໃຫ້ຢືມ, ຈັດການເງິນຄອບຄົວ, ເປີດຮ້ານຂາຍເຄື່ອງ (POS), ອອກທິບ ແລະ ຫຼິ້ນເກມ. ຄູ່ມືນີ້ລວມທຸກຟັງຊັນໃຫ້ຜູ້ໃຊ້ມືໃໝ່ເລີ່ມໄດ້ທັນທີ',
   'ph':'ຄົ້ນຫາຟັງຊັນ ເຊັ່ນ ຫານບິນ, ງົບປະມານ, QR, ດອກເບ້ຍ ...','introTag':'ໜ້າຈໍຫຼັກ',
   'introText':'ເມື່ອເປີດແອັບ ທ່ານຈະເຫັນ <b>ກາດຍອດເງິນ</b> ສີຂຽວຢູ່ເທິງສຸດ ໃຕ້ລົງມາຄືປຸ່ມ <b>ລາຍຮັບ/ລາຍຈ່າຍ</b> ສຳລັບບັນທຶກໄວ ແລະ ແຖວ <b>ປຸ່ມເມນູ 5 ປຸ່ມ</b> ສຳລັບຟີເຈີຫຼັກ — ແຕະຫົວຂໍ້ທາງຊ້າຍ (ຫຼື ເມນູ ☰ ເທິງມືຖື) ເພື່ອຂ້າມໄປຫາສ່ວນທີ່ສົນໃຈໄດ້ເລີຍ',
   'footer':'ພາລວຍ (Paruay) · ຄູ່ມືການນຳໃຊ້ · ອັບເດດ 16 ມິ.ຖ. 2026','openApp':'ເປີດແອັບ:',
   'mTotal':'ຍອດເງິນທັງໝົດ','mIn':'+ ລາຍຮັບ','mOut':'▽ ລາຍຈ່າຍ','back':'ໜ້າຫຼັກ'},
 'en': {'title':'Paruay User Guide','brandSub':'Paruay · Guide','start':'Getting started / Overview',
   'sub':'An all-in-one money app — log income & expenses, split bills with friends, lend money, manage family finances, run a shop (POS), take trips, and play games. This guide covers every feature so new users can start right away.',
   'ph':'Search features e.g. split bill, budget, QR, interest ...','introTag':'Home screen',
   'introText':"When you open the app you'll see the green <b>Balance card</b> on top, then the <b>Income / Expense</b> quick buttons, and a row of <b>5 menu buttons</b> for the main features — tap a topic on the left (or the ☰ menu on mobile) to jump to any section.",
   'footer':'Paruay · User Guide · Updated 16 Jun 2026','openApp':'Open the app:',
   'mTotal':'Total balance','mIn':'+ Income','mOut':'▽ Expense','back':'Home'},
}
TIPLBL = {'th':'💡 เคล็ดลับ:','lo':'💡 ເຄັດລັບ:','en':'💡 Tip:'}
LANGNAME = {'th':'ไทย','lo':'ລາວ','en':'EN'}

CAP = {
 'ok':{'th':'ปกติ','lo':'ປົກກະຕິ','en':'On track'},'near':{'th':'ใกล้หมดงบ','lo':'ໃກ້ໝົດງົບ','en':'Near limit'},'over':{'th':'ใช้เกินงบ!','lo':'ໃຊ້ເກີນງົບ!','en':'Over budget!'},
 'day':{'th':'วัน','lo':'ວັນ','en':'Day'},'week':{'th':'สัปดาห์','lo':'ອາທິດ','en':'Week'},'month':{'th':'เดือน','lo':'ເດືອນ','en':'Month'},'year':{'th':'ปี','lo':'ປີ','en':'Year'},'all':{'th':'ทั้งหมด','lo':'ທັງໝົດ','en':'All'},
 'income':{'th':'รายรับ','lo':'ລາຍຮັບ','en':'Income'},'expense':{'th':'รายจ่าย','lo':'ລາຍຈ່າຍ','en':'Expense'},
 'invcode':{'th':'รหัสเชิญกลุ่ม','lo':'ລະຫັດເຊີນກຸ່ມ','en':'Group invite code'},'copy':{'th':'คัดลอก','lo':'ສຳເນົາ','en':'Copy'},
 'scan':{'th':'ลูกค้าสแกน','lo':'ລູກຄ້າສະແກນ','en':'Scan'},'order':{'th':'สั่งอาหาร','lo':'ສັ່ງອາຫານ','en':'Order'},'alerted':{'th':'ร้านเด้งเตือน','lo':'ຮ້ານເດັ້ງເຕືອນ','en':'Shop alerted'},'ordertag':{'th':'🔔 ออเดอร์','lo':'🔔 ອໍເດີ','en':'🔔 Order'},
 'balance':{'th':'ยอดเงิน','lo':'ຍອດເງິນ','en':'Balance'},'yant':{'th':'ลายยันต์การ์ดเงิน','lo':'ລາຍຍັນບັດເງິນ','en':'Card yantra'},'neworder':{'th':'ออเดอร์ใหม่ · โต๊ะ 5','lo':'ອໍເດີໃໝ່ · ໂຕະ 5','en':'New order · Table 5'},'appclosed':{'th':'เด้งเข้ามือถือแม้แอปปิด','lo':'ເດັ້ງເຂົ້າມືຖືເຖິງແອັບປິດ','en':'Even when the app is closed'},'pushcap':{'th':'แจ้งเตือนเข้ามือถือ (Web Push)','lo':'ແຈ້ງເຕືອນເຂົ້າມືຖື (Web Push)','en':'Phone push alerts (Web Push)'},
}
def C(k, lang): return CAP[k][lang]

ICONS = {
 'people': '<svg viewBox="0 0 24 24" fill="#fff"><circle cx="9" cy="7.5" r="3"/><circle cx="16" cy="9" r="2"/><path d="M2.5 18.5c0-2.8 2.8-4.8 6.5-4.8s6.5 2 6.5 4.8V20h-13v-1.5z"/><path d="M16 14.5c2 0 4.2 1 4.2 3V18H17" opacity="0.7"/></svg>',
 'dollar': '<svg viewBox="0 0 24 24" fill="#fff"><rect x="1" y="4" width="22" height="16" rx="2"/><circle cx="12" cy="12" r="4.5" fill="#3B82F6"/><circle cx="12" cy="12" r="3.5" fill="#fff"/><text x="12" y="15.5" text-anchor="middle" fill="#3B82F6" font-size="9" font-weight="800">$</text></svg>',
 'shop': '<svg viewBox="0 0 24 24" fill="none"><path d="M3 9l1.5-5h15L21 9" stroke="#fff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/><path d="M3 9c0 1.1.9 2 2 2s2-.9 2-2c0 1.1.9 2 2 2s2-.9 2-2c0 1.1.9 2 2 2s2-.9 2-2c0 1.1.9 2 2 2s2-.9 2-2" stroke="#fff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/><rect x="4" y="11" width="16" height="10" stroke="#fff" stroke-width="2" rx="1"/><rect x="9" y="15" width="6" height="6" stroke="#fff" stroke-width="2" rx="0.5"/></svg>',
 'game': '<svg viewBox="0 0 24 24" fill="none"><path d="M6 11h4M8 9v4" stroke="#fff" stroke-width="2" stroke-linecap="round"/><circle cx="15" cy="10" r="1" fill="#fff"/><circle cx="18" cy="13" r="1" fill="#fff"/><path d="M17.32 5H6.68a4 4 0 00-3.978 3.59L2 14a3 3 0 005.12 2.13L8.24 15h7.52l1.12 1.13A3 3 0 0022 14l-.7-5.41A4 4 0 0017.32 5z" stroke="#fff" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/></svg>',
 'plane': '<svg viewBox="0 0 24 24" fill="#fff"><g transform="translate(12,12) rotate(-35) translate(-12,-12)"><path d="M21 12c1.1 0 2 .6 2 1.5S22.1 15 21 15H15l-3.5 5.5h-2l1.5-5.5H7l-1.5 2H4l1-3.5L4 10h1.5L7 12h4L9.5 6.5h2L15 12h6z"/></g></svg>',
}
MENU = [('people','#F59E0B','split'),('dollar','#3B82F6','lend'),('shop','#10B981','pos'),('game','#F43F5E','game'),('plane','#8B5CF6','trip')]
MENUL = {'th':['หารบิล','ให้ยืม','ร้าน (POS)','เกม','ออกทริป'],'lo':['ຫານບິນ','ໃຫ້ຢືມ','ຮ້ານ (POS)','ເກມ','ອອກທິບ'],'en':['Split','Lend','Shop','Game','Trip']}

def svgw(vb, body, A):
    return ('<svg viewBox="%s" fill="none" stroke="%s" stroke-width="2.3" stroke-linecap="round" stroke-linejoin="round" font-family="\'Noto Sans Thai\',\'Noto Sans Lao\',sans-serif">%s</svg>' % (vb, A, body))
def coin(cx, cy, r, sym, A):
    return ('<circle cx="%d" cy="%d" r="%d"/><text x="%d" y="%d" text-anchor="middle" fill="%s" stroke="none" font-size="%d" font-weight="700" font-family="serif">%s</text>' % (cx,cy,r,cx,cy+r//3+1,A,int(r*0.95),sym))

def CHAP_ART(di):
    A = ACC[di]; L = tint(A,'0.13')
    if di == 0:
        b=('<rect x="26" y="48" width="118" height="70" rx="13"/><path d="M26 70h118"/><rect x="104" y="80" width="46" height="20" rx="6" fill="%s"/><circle cx="127" cy="90" r="3.5" fill="%s" stroke="none"/>'%(L,A)+coin(214,92,25,'₭',A)+coin(262,72,18,'$',A)+'<path d="M356 120h180"/><rect x="368" y="92" width="24" height="28" rx="3" fill="%s"/><rect x="404" y="74" width="24" height="46" rx="3"/><rect x="440" y="56" width="24" height="64" rx="3" fill="%s"/><rect x="476" y="40" width="24" height="80" rx="3"/><path d="M380 96l36-18 36-18 42-22"/><path d="M482 36l16 2-2 16"/>'%(L,L))
        return svgw('0 0 560 150', b, A)
    if di == 1:
        b=('<circle cx="70" cy="58" r="22"/><path d="M40 116c0-22 13-34 30-34s30 12 30 34"/><circle cx="490" cy="58" r="22"/><path d="M460 116c0-22 13-34 30-34s30 12 30 34"/><rect x="232" y="40" width="96" height="92" rx="8" fill="%s"/><path d="M252 60h56M252 78h56M252 96h36"/><text x="280" y="124" text-anchor="middle" fill="%s" stroke="none" font-size="15" font-weight="700">฿900</text><path d="M150 86h70M340 86h70" stroke-dasharray="2 7"/><path d="M214 80l8 6-8 6M346 80l-8 6 8 6"/>'%(L,A))
        return svgw('0 0 560 150', b, A)
    if di == 2:
        b=('<path d="M40 80l60-44 60 44"/><rect x="58" y="78" width="84" height="56" rx="6" fill="%s"/><rect x="86" y="100" width="28" height="34" rx="3"/><path d="M100 58c-6-8-18-4-14 6 2 6 14 12 14 12s12-6 14-12c4-10-8-14-14-6z" fill="%s" stroke="none"/><rect x="250" y="70" width="70" height="64" rx="9" fill="%s"/><path d="M268 70v-12a6 6 0 016-6h22a6 6 0 016 6v12M250 96h70"/><g transform="translate(430,86) rotate(-20)"><path d="M70 0c4 0 7 2 7 5s-3 5-7 5H48l-12 18h-7l5-18H18l-5 7h-5l3-12-3-12h5l5 7h16l-5-18h7l12 18h22z" fill="%s" stroke="none"/></g>'%(L,A,L,A))
        return svgw('0 0 560 150', b, A)
    if di == 3:
        b=('<path d="M40 64l12-26h96l12 26"/><path d="M40 64c0 9 7 14 14 14s14-5 14-14c0 9 7 14 14 14s14-5 14-14c0 9 7 14 14 14s14-5 14-14c0 9 7 14 14 14s14-5 14-14"/><rect x="50" y="78" width="116" height="56" rx="5" fill="%s"/><rect x="92" y="104" width="32" height="30" rx="3"/><rect x="250" y="42" width="78" height="96" rx="11" fill="%s"/><rect x="266" y="60" width="46" height="46" rx="4"/><path d="M274 68h12v12h-12zM296 68h6v6h-6zM274 90h6v6h-6zM292 92h10v10h-10z" fill="%s" stroke="none"/><path d="M278 120h22"/><path d="M470 56c-16 0-24 12-24 28 0 14-6 18-6 18h60s-6-4-6-18c0-16-8-28-24-28z"/><path d="M462 110a8 8 0 0016 0"/><path d="M470 44v8"/><circle cx="496" cy="56" r="13" fill="%s" stroke="none"/><text x="496" y="61" text-anchor="middle" fill="#fff" stroke="none" font-size="14" font-weight="800">1</text>'%(L,L,A,A))
        return svgw('0 0 560 150', b, A)
    teeth=''.join('<rect x="88" y="50" width="8" height="14" rx="2" transform="rotate(%d 92 86)" fill="%s" stroke="none"/>'%(a,A) for a in range(0,360,45))
    b=('<circle cx="92" cy="86" r="30"/><circle cx="92" cy="86" r="12" fill="%s"/>%s<rect x="210" y="64" width="150" height="56" rx="28" fill="%s"/><path d="M246 84v18M237 93h18"/><circle cx="330" cy="86" r="5" fill="%s" stroke="none"/><circle cx="346" cy="98" r="5" fill="%s" stroke="none"/><path d="M430 60h90M430 90h90M430 120h90"/><circle cx="470" cy="60" r="8" fill="#fff"/><circle cx="500" cy="90" r="8" fill="#fff"/><circle cx="452" cy="120" r="8" fill="#fff"/>'%(L,teeth,tint(A,'0.12'),A,A))
    return svgw('0 0 560 150', b, A)

def SEC_ART(di, si, lang):
    key=(di,si); A=ACC[di]; cl=lambda k:esc(C(k,lang))
    if key==(0,2):
        rows=[('ok',45,'#1B7A43'),('near',82,'#C8902E'),('over',100,'#AA3C28')]; body=''
        for i,(k,pct,c) in enumerate(rows):
            y=18+i*44
            body+=('<text x="0" y="%d" fill="#5C4632" stroke="none" font-size="13" font-weight="600">%s</text><rect x="0" y="%d" width="520" height="16" rx="8" fill="#EDE4CF" stroke="none"/><rect x="0" y="%d" width="%d" height="16" rx="8" fill="%s" stroke="none"/><text x="525" y="%d" fill="%s" stroke="none" font-size="12" font-weight="700">%d%%</text>'%(y,cl(k),y+8,y+8,int(520*pct/100),c,y+20,c,pct))
        return '<svg viewBox="0 0 580 150" font-family="\'Noto Sans Thai\',\'Noto Sans Lao\',sans-serif">%s</svg>'%body
    if key==(0,3):
        keys=['day','week','month','year','all']
        pills=''.join('<rect x="%d" y="0" width="64" height="26" rx="9" fill="%s" stroke="none"/><text x="%d" y="17" text-anchor="middle" fill="%s" stroke="none" font-size="12" font-weight="700">%s</text>'%(i*70,('#1B4332' if i==0 else '#EDE4CF'),i*70+32,('#fff' if i==0 else '#7F5539'),cl(keys[i])) for i in range(5))
        inc='40,150 110,96 180,120 250,70 320,104 390,58 460,86'; exp='40,164 110,150 180,160 250,128 320,150 390,134 460,120'
        dots=''.join('<circle cx="%s" cy="%s" r="3.4"/>'%(p.split(',')[0],p.split(',')[1]) for p in inc.split())
        return ('<svg viewBox="0 0 500 210" font-family="\'Noto Sans Thai\',\'Noto Sans Lao\',sans-serif">%s<line x1="36" y1="46" x2="36" y2="180" stroke="rgba(127,85,57,.2)"/><line x1="36" y1="180" x2="478" y2="180" stroke="rgba(127,85,57,.2)"/><polyline points="%s" fill="none" stroke="#1B7A43" stroke-width="2.6"/><polyline points="%s" fill="none" stroke="#D4A574" stroke-width="2.6"/><g fill="#1B7A43">%s</g><text x="40" y="202" fill="#1B7A43" stroke="none" font-size="11" font-weight="700">● %s</text><text x="120" y="202" fill="#C8902E" stroke="none" font-size="11" font-weight="700">● %s</text></svg>'%(pills,inc,exp,dots,cl('income'),cl('expense')))
    if key==(1,1):
        ppl=''.join('<circle cx="%d" cy="58" r="20" fill="@A" stroke="none"/><text x="%d" y="65" text-anchor="middle" stroke="none" font-size="17">😀</text><text x="%d" y="108" text-anchor="middle" fill="#5C4632" stroke="none" font-size="13" font-weight="700">฿300</text>'%(x,x,x) for x in (360,440,520))
        s=('<svg viewBox="0 0 580 130" fill="none" font-family="\'Noto Sans Thai\',\'Noto Sans Lao\',sans-serif"><rect x="20" y="22" width="92" height="92" rx="8" fill="@T" stroke="@A" stroke-width="2.2"/><path d="M40 44h52M40 62h52M40 80h34" stroke="@A" stroke-width="2.2"/><text x="66" y="106" text-anchor="middle" fill="@A" stroke="none" font-size="14" font-weight="800">฿900</text><path d="M130 68h200" stroke="@A" stroke-width="2.2" stroke-dasharray="2 7"/><path d="M326 62l8 6-8 6" stroke="@A" stroke-width="2.2" fill="none"/>'+ppl+'</svg>')
        return s.replace('@T',tint(A,'0.10')).replace('@A',A)
    if key==(2,0):
        s=('<svg viewBox="0 0 560 130" fill="none" font-family="\'Noto Sans Thai\',\'Noto Sans Lao\',sans-serif"><rect x="20" y="16" width="320" height="98" rx="14" fill="@T" stroke="@A" stroke-width="2.2"/><text x="40" y="48" fill="@A" stroke="none" font-size="13" font-weight="700">%s</text><text x="40" y="88" fill="#2A1F1A" stroke="none" font-size="30" font-weight="800" font-family="monospace" letter-spacing="6">A1B2C3</text><rect x="250" y="62" width="74" height="34" rx="9" fill="@A" stroke="none"/><text x="287" y="84" text-anchor="middle" fill="#fff" stroke="none" font-size="13" font-weight="700">%s</text><path d="M380 65h110" stroke="@A" stroke-width="2.2" stroke-dasharray="2 7"/><path d="M486 59l8 6-8 6" stroke="@A" stroke-width="2.2"/><circle cx="524" cy="40" r="17" fill="@A" stroke="none"/><circle cx="524" cy="92" r="17" fill="@A" stroke="none"/><text x="524" y="46" text-anchor="middle" stroke="none" font-size="15">🧑</text><text x="524" y="98" text-anchor="middle" stroke="none" font-size="15">🧑</text></svg>'%(cl('invcode'),cl('copy')))
        return s.replace('@T',tint(A,'0.08')).replace('@A',A)
    if key==(3,3):
        s=('<svg viewBox="0 0 560 150" fill="none" font-family="\'Noto Sans Thai\',\'Noto Sans Lao\',sans-serif"><rect x="20" y="20" width="86" height="110" rx="12" fill="@T" stroke="@A" stroke-width="2.2"/><rect x="38" y="40" width="50" height="50" rx="4" stroke="@A" stroke-width="2"/><path d="M46 48h12v12H46zM70 48h8v8h-8zM46 72h8v8h-8zM66 70h14v14H66z" fill="@A" stroke="none"/><text x="63" y="116" text-anchor="middle" fill="@A" stroke="none" font-size="12" font-weight="700">%s</text><path d="M120 75h150" stroke="@A" stroke-width="2.4"/><path d="M264 68l10 7-10 7" stroke="@A" stroke-width="2.4"/><text x="195" y="64" text-anchor="middle" fill="@A" stroke="none" font-size="12" font-weight="700">%s</text><path d="M360 48c-18 0-26 14-26 32 0 16-7 20-7 20h66s-7-4-7-20c0-18-8-32-26-32z" stroke="@A" stroke-width="2.4"/><path d="M351 104a9 9 0 0018 0" stroke="@A" stroke-width="2.4"/><path d="M360 36v8" stroke="@A" stroke-width="2.4"/><circle cx="392" cy="46" r="15" fill="#AA3C28" stroke="none"/><text x="392" y="51" text-anchor="middle" fill="#fff" stroke="none" font-size="15" font-weight="800">1</text><text x="358" y="132" text-anchor="middle" fill="@A" stroke="none" font-size="12" font-weight="700">%s</text><path d="M430 75h44" stroke="@A" stroke-width="2.4" stroke-dasharray="1 7"/><path d="M468 68l10 7-10 7" stroke="@A" stroke-width="2.4"/><rect x="486" y="34" width="64" height="82" rx="10" fill="@TT" stroke="@A" stroke-width="2.2"/><rect x="496" y="48" width="44" height="14" rx="4" fill="@A" stroke="none"/><text x="518" y="58" text-anchor="middle" fill="#fff" stroke="none" font-size="8">%s</text></svg>'%(cl('scan'),cl('order'),cl('alerted'),cl('ordertag')))
        return s.replace('@TT',tint(A,'0.06')).replace('@T',tint(A,'0.08')).replace('@A',A)
    if key==(4,1):
        return ('<svg viewBox="0 0 560 150" fill="none" font-family="\'Noto Sans Thai\',\'Noto Sans Lao\',sans-serif"><rect x="20" y="16" width="200" height="118" rx="14" fill="#1B4332" stroke="none"/><text x="38" y="48" fill="rgba(245,239,224,.8)" stroke="none" font-size="11">%s</text><text x="38" y="80" fill="#F5EFE0" stroke="none" font-size="22" font-weight="800" font-family="serif">₭ 1,250,000</text><g stroke="#F5EFE0" stroke-width="1" opacity="0.5"><circle cx="200" cy="40" r="14"/><circle cx="200" cy="40" r="22"/><circle cx="200" cy="40" r="30"/></g><text x="120" y="126" text-anchor="middle" fill="rgba(245,239,224,.6)" stroke="none" font-size="10">%s</text><rect x="270" y="34" width="270" height="58" rx="14" fill="#fff" stroke="rgba(127,85,57,.2)" stroke-width="1.5"/><circle cx="300" cy="63" r="16" fill="#10B981" stroke="none"/><text x="300" y="69" text-anchor="middle" fill="#fff" stroke="none" font-size="15">🔔</text><text x="328" y="58" fill="#2A1F1A" stroke="none" font-size="13" font-weight="800">%s</text><text x="328" y="78" fill="#7F5539" stroke="none" font-size="11">%s</text><text x="405" y="118" text-anchor="middle" fill="#7F5539" stroke="none" font-size="11" font-weight="600">%s</text></svg>'%(cl('balance'),cl('yant'),cl('neworder'),cl('appclosed'),cl('pushcap')))
    return None

def feature_html(f, acc, lang):
    p=['<div class="feature" data-sf="%s">'%esc((f['name']+' '+f['what']).lower())]
    p.append('<h4><span class="k" style="background:%s"></span>%s</h4>'%(acc,esc(f['name'])))
    p.append('<p class="what">%s</p>'%esc(f['what']))
    if f.get('steps'): p.append('<ol class="steps">'+''.join('<li>%s</li>'%esc(s) for s in f['steps'])+'</ol>')
    if f.get('tip') and f['tip'].strip(): p.append('<div class="tip"><b>%s</b> %s</div>'%(TIPLBL[lang],esc(f['tip'])))
    p.append('</div>'); return ''.join(p)

def block_html(sec, acc, sid, di, si, lang):
    h=['<div class="block" id="%s">'%sid]
    h.append('<h3 class="block-title"><span class="em">%s</span>%s</h3>'%(esc(sec['emoji']),esc(sec['title'])))
    if sec.get('intro'): h.append('<p class="block-intro">%s</p>'%esc(sec['intro']))
    art=SEC_ART(di,si,lang)
    if art: h.append('<div class="sec-art" style="background:%s">%s</div>'%(tint(acc,'0.05'),art))
    for f in sec['features']: h.append(feature_html(f,acc,lang))
    h.append('</div>'); return ''.join(h)

def build_lang(lang):
    chapters=[]; navgroups=[]
    for di,dom_all in enumerate(data):
        dom=dom_all[lang]; acc=ACC[di%len(ACC)]; cid='dom%d_%s'%(di,lang)
        secs=[]; links=[]
        for si,sec in enumerate(dom['sections']):
            sid='sec%d_%d_%s'%(di,si,lang)
            secs.append(block_html(sec,acc,sid,di,si,lang))
            links.append('<a href="#%s">%s %s</a>'%(sid,esc(sec['emoji']),esc(sec['title'])))
        chapters.append('<section class="chapter" id="%s"><div class="chapter-head"><div class="no" style="background:%s">%d</div><h2>%s</h2></div><div class="chapter-rule" style="background:%s"></div><div class="chap-art" style="background:%s">%s</div>%s</section>'%(cid,acc,di+1,esc(dom['domain']),acc,tint(acc,'0.07'),CHAP_ART(di),''.join(secs)))
        navgroups.append('<div class="nav-group"><div class="gh"><span class="dot" style="background:%s"></span><a href="#%s" style="padding:0">%s</a></div>%s</div>'%(acc,cid,esc(NAVL[lang][di]),''.join(links)))
    return ''.join(chapters), ''.join(navgroups)

nav_by, chap_by = {}, {}
for L in LANGS:
    chap_by[L], nav_by[L] = build_lang(L)

def Lspan(key, tag='span'):  # inline/block per-lang text from UI
    return ''.join('<%s class="L%s %s">%s</%s>'%(tag,'b' if tag!='span' else 'x',L,UI[L][key],('span' if tag=='span' else tag)) for L in LANGS) if False else ''.join(
        ('<span class="Lx %s">%s</span>'%(L,UI[L][key])) if tag=='span' else ('<%s class="Lb %s">%s</%s>'%(tag,L,UI[L][key],tag)) for L in LANGS)

langbtns=''.join('<button class="langbtn" data-l="%s">%s</button>'%(L,LANGNAME[L]) for L in ['lo','th','en'])
navwraps=''.join('<div class="LB %s">%s</div>'%(L,nav_by[L]) for L in LANGS)
chapwraps=''.join('<div class="LB %s">%s</div>'%(L,chap_by[L]) for L in LANGS)
hero_pills=''.join('<span class="pill"><i style="background:%s"></i>%s</span>'%(c,''.join('<span class="Lx %s">%s</span>'%(L,esc(MENUL[L][i])) for L in LANGS)) for i,(k,c,lbl) in enumerate(MENU))
mock_menu=''.join('<div class="b"><div class="ic" style="background:%s">%s</div><small>%s</small></div>'%(c,ICONS[k],''.join('<span class="Lx %s">%s</span>'%(L,esc(MENUL[L][i])) for L in LANGS)) for i,(k,c,lbl) in enumerate(MENU))
def uispan(key): return ''.join('<span class="Lx %s">%s</span>'%(L,esc(UI[L][key])) for L in LANGS)
def uib(key): return ''.join('<div class="Lb %s">%s</div>'%(L,UI[L][key]) for L in LANGS)  # raw (may contain <b>)

CSS = open('/dev/stdin').read() if False else ''
PYEOF_CSS = r"""
:root{--cream:#F5EFE0;--cream2:#FBF6E9;--paper:#fff;--forest:#1B4332;--brown:#7F5539;--brown2:#5C4632;--sand:#A89580;--gold:#D4A574;--gold2:#C8902E;--danger:#AA3C28;--line:rgba(127,85,57,.14);--line2:rgba(127,85,57,.22);--shadow:0 10px 30px -16px rgba(27,67,50,.35);}
*{box-sizing:border-box}html{scroll-behavior:smooth;scroll-padding-top:74px}
body{margin:0;background:var(--cream);color:var(--brown2);font-family:'Noto Sans Thai','Noto Sans Lao',system-ui,sans-serif;line-height:1.65;font-size:16px;-webkit-font-smoothing:antialiased}
.display{font-family:'Fraunces','Noto Serif Lao','Noto Serif Thai',serif}
a{color:inherit;text-decoration:none}svg{max-width:100%}
.Lx,.Lb,.LB{display:none}
body.lang-th .Lx.th,body.lang-lo .Lx.lo,body.lang-en .Lx.en{display:inline}
body.lang-th .Lb.th,body.lang-lo .Lb.lo,body.lang-en .Lb.en{display:block}
body.lang-th .LB.th,body.lang-lo .LB.lo,body.lang-en .LB.en{display:block}
.wrap{display:grid;grid-template-columns:268px 1fr;max-width:1280px;margin:0 auto}
.sidebar{position:sticky;top:0;align-self:start;height:100vh;overflow-y:auto;padding:24px 14px 40px;border-right:1px solid var(--line);background:var(--cream2)}
.brand{display:flex;align-items:center;gap:10px;padding:6px 8px 12px}
.brand .logo{width:40px;height:40px;border-radius:12px;background:linear-gradient(135deg,#1B4332,#3D6B53);display:flex;align-items:center;justify-content:center;color:#F5EFE0;font-weight:800;font-size:20px;flex:0 0 auto;font-family:'Noto Sans Lao','Noto Sans Thai',sans-serif}
.brand b{font-size:20px;color:var(--forest);font-family:'Noto Sans Lao','Noto Sans Thai',sans-serif;font-weight:800}.brand small{display:block;font-size:11px;color:var(--sand);letter-spacing:.12em}
.langbar{display:flex;gap:6px;padding:0 8px 14px;border-bottom:1px solid var(--line);margin-bottom:8px}
.langbtn{flex:1;border:1px solid var(--line2);background:#fff;color:var(--brown);border-radius:10px;padding:7px 4px;font-size:13px;font-weight:700;cursor:pointer;font-family:inherit}
.langbtn.on{background:var(--forest);color:#F5EFE0;border-color:var(--forest)}
.nav-group{margin-top:12px}
.nav-group>.gh{display:flex;align-items:center;gap:8px;font-weight:700;font-size:13px;color:var(--forest);padding:8px 10px}
.nav-group>.gh .dot{width:9px;height:9px;border-radius:3px;flex:0 0 auto}
.nav-group a{display:block;font-size:13.5px;color:var(--brown);padding:6px 10px 6px 28px;border-radius:9px;border-left:2px solid transparent;line-height:1.4}
.nav-group a:hover{background:#fff}.nav-group a.active{background:#fff;color:var(--forest);font-weight:600;border-left-color:var(--gold2)}
.topbar{display:none;position:sticky;top:0;z-index:40;background:rgba(245,239,224,.92);backdrop-filter:blur(8px);border-bottom:1px solid var(--line);padding:10px 14px;align-items:center;justify-content:space-between;gap:8px}
.topbar b{color:var(--forest);font-size:16px;font-family:'Noto Sans Lao','Noto Sans Thai',sans-serif;font-weight:800}.topbar .right{display:flex;gap:6px;align-items:center}
.tlang{border:1px solid var(--line2);background:#fff;color:var(--brown);border-radius:8px;padding:5px 9px;font-size:12px;font-weight:700;cursor:pointer;font-family:inherit}
.tlang.on{background:var(--forest);color:#F5EFE0}
.burger{width:42px;height:42px;border:1px solid var(--line2);background:#fff;border-radius:12px;display:flex;align-items:center;justify-content:center;cursor:pointer;font-size:18px;color:var(--forest)}
.tleft{display:flex;align-items:center;gap:8px;min-width:0}
.backbtn{width:40px;height:40px;border:1px solid var(--line2);background:#fff;border-radius:11px;display:flex;align-items:center;justify-content:center;cursor:pointer;font-size:20px;color:var(--forest);font-weight:800;flex:0 0 auto;font-family:inherit;line-height:1}
.backbtn:active{background:var(--cream2)}
.backlink{display:flex;align-items:center;gap:9px;margin:0 6px 14px;padding:11px 13px;border:1px solid var(--line2);background:#fff;border-radius:13px;color:var(--forest);font-weight:700;font-size:14.5px;cursor:pointer;font-family:inherit;width:auto}
.backlink:hover{background:var(--cream2)}
.backlink .ar{font-size:18px;font-weight:800}
main{min-width:0;padding:0 clamp(16px,3vw,40px) 80px}
.search{position:relative;margin:18px 0 8px}
.search input{width:100%;padding:13px 14px 13px 42px;border:1px solid var(--line2);border-radius:14px;background:#fff;font-size:15px;font-family:inherit;color:var(--brown2);outline:none}
.search input:focus{border-color:var(--gold2)}.search>svg{position:absolute;left:14px;top:50%;transform:translateY(-50%);width:18px;height:18px;opacity:.5}
.hero{position:relative;overflow:hidden;border-radius:26px;margin:18px 0 8px;padding:36px 30px;color:#F5EFE0;background:linear-gradient(135deg,#1B4332 0%,#2D5A47 55%,#3D6B53 100%);box-shadow:var(--shadow)}
.hero .glow{position:absolute;top:-60px;right:-50px;width:240px;height:240px;border-radius:50%;background:radial-gradient(circle,rgba(212,165,116,.3),transparent 70%)}
.hero h1{margin:0 0 6px;font-size:clamp(28px,5vw,42px);font-weight:800}
.hero .sub{font-size:15px;opacity:.86;max-width:640px;min-height:2px}
.hero .pills{display:flex;flex-wrap:wrap;gap:8px;margin-top:18px}
.hero .pill{display:inline-flex;align-items:center;gap:7px;background:rgba(245,239,224,.14);border:1px solid rgba(245,239,224,.2);padding:7px 13px;border-radius:999px;font-size:13px}
.hero .pill i{width:18px;height:18px;border-radius:5px;display:inline-block}
.intro{display:grid;grid-template-columns:1fr 300px;gap:22px;align-items:center;margin:26px 0 8px}
.intro .lead{font-size:16px;color:var(--brown2)}
.intro .lead .tag{display:inline-block;background:#E7F0E9;color:#1B7A43;font-weight:700;font-size:12px;padding:3px 10px;border-radius:999px;margin-bottom:10px}
.phone{justify-self:center;width:280px;border-radius:34px;background:#1d2a22;padding:12px;box-shadow:var(--shadow)}
.phone .scr{border-radius:24px;background:var(--cream);overflow:hidden;padding:14px}
.mock-card{position:relative;overflow:hidden;border-radius:18px;padding:18px;color:#F5EFE0;background:linear-gradient(135deg,#1B4332,#2D5A47 60%,#3D6B53)}
.mock-card .ylab{font-size:10px;opacity:.75;letter-spacing:.08em}.mock-card .num{font-family:'Fraunces',serif;font-size:30px;font-weight:700;line-height:1.1;margin-top:2px}.mock-card .sub{font-size:11px;opacity:.8;margin-top:8px}
.mock-ie{display:flex;gap:8px;margin-top:12px}.mock-ie div{flex:1;text-align:center;border-radius:12px;padding:11px;font-size:13px;font-weight:700;color:#fff}
.mock-menu{display:flex;gap:6px;margin-top:12px}.mock-menu .b{flex:1;display:flex;flex-direction:column;align-items:center;gap:4px}
.mock-menu .ic{width:100%;padding:11px 0;border-radius:11px;display:flex;align-items:center;justify-content:center}.mock-menu .ic svg{width:21px;height:21px}.mock-menu small{font-size:8.5px;color:#7F5539;font-weight:600}
.chapter{margin-top:46px;scroll-margin-top:74px}
.chapter-head{display:flex;align-items:center;gap:14px;margin-bottom:6px}
.chapter-head .no{width:46px;height:46px;border-radius:14px;display:flex;align-items:center;justify-content:center;color:#fff;font-family:'Fraunces',serif;font-weight:700;font-size:22px;flex:0 0 auto}
.chapter-head h2{margin:0;font-size:clamp(21px,3.4vw,28px);color:var(--forest);font-weight:800}
.chapter-rule{height:3px;border-radius:3px;margin:10px 0 16px;opacity:.5}
.chap-art{border-radius:20px;padding:14px 22px;margin-bottom:22px}.chap-art svg{display:block;width:100%;height:auto;max-height:150px}
.block{background:var(--paper);border:1px solid var(--line);border-radius:20px;padding:20px 20px 8px;margin-bottom:18px;box-shadow:0 6px 18px -14px rgba(27,67,50,.3);scroll-margin-top:74px}
.block-title{display:flex;align-items:center;gap:10px;margin:0 0 4px;font-size:18px;font-weight:800;color:var(--forest)}.block-title .em{font-size:22px;line-height:1}
.block-intro{margin:0 0 14px;color:var(--brown);font-size:14.5px}
.sec-art{border-radius:14px;padding:14px 16px;margin:0 0 16px;border:1px solid var(--line)}.sec-art svg{display:block;width:100%;height:auto;max-height:200px}
.feature{border-top:1px dashed var(--line2);padding:16px 0}.feature:first-of-type{border-top:0;padding-top:2px}
.feature h4{margin:0 0 5px;font-size:16px;color:var(--brown2);font-weight:800;display:flex;gap:8px;align-items:baseline}.feature h4 .k{flex:0 0 auto;width:7px;height:7px;border-radius:2px;margin-top:7px}
.feature .what{margin:0 0 12px;font-size:14.5px;color:#6b5947}
.steps{margin:0;padding:0;list-style:none;counter-reset:s;display:flex;flex-direction:column;gap:8px}
.steps li{counter-increment:s;position:relative;padding-left:34px;font-size:14px;color:var(--brown2)}
.steps li::before{content:counter(s);position:absolute;left:0;top:-1px;width:23px;height:23px;border-radius:8px;background:#E7F0E9;color:#1B7A43;font-weight:800;font-size:12px;display:flex;align-items:center;justify-content:center;font-family:'Fraunces',serif}
.tip{margin:13px 0 2px;background:linear-gradient(#FDF7EA,#FBF1DD);border:1px solid rgba(200,144,46,.25);border-left:4px solid var(--gold2);border-radius:12px;padding:11px 14px;font-size:13.5px;color:#7a5b27}.tip b{color:var(--gold2)}
footer{margin-top:60px;padding:28px 0 10px;border-top:1px solid var(--line);color:var(--sand);font-size:13px;text-align:center}
.totop{position:fixed;right:18px;bottom:18px;width:46px;height:46px;border-radius:50%;border:none;background:var(--forest);color:#F5EFE0;font-size:20px;cursor:pointer;box-shadow:var(--shadow);opacity:0;pointer-events:none;transition:.25s;z-index:50}.totop.show{opacity:1;pointer-events:auto}
.scrim{display:none}
@media(max-width:880px){.wrap{grid-template-columns:1fr}.topbar{display:flex}
 .sidebar{position:fixed;top:0;left:0;height:100vh;width:280px;z-index:60;transform:translateX(-105%);transition:transform .28s ease;box-shadow:0 0 40px rgba(0,0,0,.25)}
 body.nav-open .sidebar{transform:none}body.nav-open .scrim{display:block;position:fixed;inset:0;background:rgba(20,12,8,.4);z-index:55}
 .intro{grid-template-columns:1fr}.phone{width:262px}}
"""
CSS = PYEOF_CSS

HTML = """<!doctype html><html lang="lo"><head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>ຄູ່ມື · ພາລວຍ (Paruay) Guide</title>
<link rel="preconnect" href="https://fonts.googleapis.com"><link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Fraunces:opsz,wght@9..144,500;9..144,700;9..144,900&family=Noto+Serif+Lao:wght@600;700&family=Noto+Sans+Lao:wght@400;500;600;700;800&family=Noto+Sans+Thai:wght@400;500;600;700;800&family=Noto+Serif+Thai:wght@600;700&display=swap" rel="stylesheet">
<style>__CSS__</style></head><body class="lang-lo">
<div class="topbar"><div class="tleft"><button class="backbtn" onclick="goBackApp()" aria-label="back">←</button><b class="display">ພາລວຍ</b></div><div class="right"><button class="tlang" data-l="lo">ລາວ</button><button class="tlang" data-l="th">ไทย</button><button class="tlang" data-l="en">EN</button><button class="burger" id="burger" aria-label="menu">☰</button></div></div>
<div class="scrim" id="scrim"></div>
<div class="wrap">
<aside class="sidebar" id="sidebar">
 <button class="backlink" onclick="goBackApp()"><span class="ar">←</span><span>__BACK__</span></button>
 <div class="brand"><div class="logo display">ພ</div><div><b class="display">ພາລວຍ</b><small>Paruay · Guide</small></div></div>
 <div class="langbar">__LANGBTNS__</div>
 <div class="nav-group"><div class="gh"><span class="dot" style="background:#1B4332"></span><a href="#top" style="padding:0">__START__</a></div></div>
 __NAVWRAPS__
</aside>
<main>
 <span id="top"></span>
 <section class="hero"><div class="glow"></div>
   <h1 class="display">__TITLE__</h1>
   <p class="sub">__SUB__</p>
   <div class="pills">__PILLS__</div>
 </section>
 <div class="search"><svg viewBox="0 0 24 24" fill="none"><circle cx="11" cy="11" r="7" stroke="#7F5539" stroke-width="2"/><path d="M21 21l-4-4" stroke="#7F5539" stroke-width="2" stroke-linecap="round"/></svg>
   <input id="q" type="search" data-ph-th="__PHTH__" data-ph-lo="__PHLO__" data-ph-en="__PHEN__"></div>
 <div class="intro">
  <div class="lead"><span class="tag">__INTROTAG__</span><br>__INTROTEXT__</div>
  <div class="phone"><div class="scr">
    <div class="mock-card"><div class="ylab">__MTOTAL__</div><div class="num">₭ 1,250,000</div><div class="sub">฿ 3,000 &nbsp; $ 50</div></div>
    <div class="mock-ie"><div style="background:#1B7A43">__MIN__</div><div style="background:#AA3C28">__MOUT__</div></div>
    <div class="mock-menu">__MOCKMENU__</div>
  </div></div>
 </div>
 __CHAPWRAPS__
 <footer>__FOOTER__<br>__OPENAPP__ <b>mhdgroup01.github.io/paruay</b></footer>
</main></div>
<button class="totop" id="totop" aria-label="top">↑</button>
<script>
var LS=['th','lo','en'];
function setLang(l){if(LS.indexOf(l)<0)l='th';document.body.className=document.body.className.replace(/lang-\\w+/,'').trim()+' lang-'+l;
 try{localStorage.setItem('paruay_guide_lang',l)}catch(e){}
 document.querySelectorAll('.langbtn,.tlang').forEach(function(b){b.classList.toggle('on',b.getAttribute('data-l')===l)});
 var q=document.getElementById('q');if(q)q.placeholder=q.getAttribute('data-ph-'+l)||'';
 document.documentElement.lang=l;}
document.querySelectorAll('.langbtn,.tlang').forEach(function(b){b.addEventListener('click',function(){setLang(b.getAttribute('data-l'))})});
var burger=document.getElementById('burger'),scrim=document.getElementById('scrim');
function closeNav(){document.body.classList.remove('nav-open')}
burger.onclick=function(){document.body.classList.toggle('nav-open')};scrim.onclick=closeNav;
document.querySelectorAll('.sidebar a').forEach(function(a){a.addEventListener('click',closeNav)});
function goBackApp(){try{if(history.length>1&&(document.referrer||'').indexOf(location.host)>-1){history.back();return;}}catch(e){}location.href='index.html';}
var links=[].slice.call(document.querySelectorAll('.nav-group a[href^="#sec"]'));
var map={};links.forEach(function(a){map[a.getAttribute('href').slice(1)]=a});
var io=new IntersectionObserver(function(es){es.forEach(function(e){var a=map[e.target.id];if(!a)return;if(e.isIntersecting){links.forEach(function(x){x.classList.remove('active')});a.classList.add('active');}});},{rootMargin:'-72px 0px -70% 0px'});
document.querySelectorAll('.block').forEach(function(b){io.observe(b)});
var tt=document.getElementById('totop');addEventListener('scroll',function(){tt.classList.toggle('show',scrollY>500)});tt.onclick=function(){scrollTo({top:0,behavior:'smooth'})};
var q=document.getElementById('q');
q.addEventListener('input',function(){var v=q.value.trim().toLowerCase();
 document.querySelectorAll('.LB').forEach(function(W){W.querySelectorAll('.block').forEach(function(bl){var any=false;
  bl.querySelectorAll('.feature').forEach(function(f){var hit=!v||f.getAttribute('data-sf').indexOf(v)>=0;f.style.display=hit?'':'none';if(hit)any=true;});
  var t=bl.querySelector('.block-title').textContent.toLowerCase();bl.style.display=(!v||any||t.indexOf(v)>=0)?'':'none';});
  W.querySelectorAll('.chapter').forEach(function(ch){var vis=[].slice.call(ch.querySelectorAll('.block')).some(function(b){return b.style.display!=='none'});ch.style.display=vis?'':'none';});});});
var saved='lo';try{saved=localStorage.getItem('paruay_guide_lang')||'lo'}catch(e){}
setLang(saved);
</script></body></html>"""

repl = {
 '__CSS__':CSS,'__LANGBTNS__':langbtns,'__START__':uispan('start'),'__NAVWRAPS__':navwraps,
 '__TITLE__':uispan('title'),'__SUB__':uispan('sub'),'__PILLS__':hero_pills,
 '__PHTH__':esc(UI['th']['ph']),'__PHLO__':esc(UI['lo']['ph']),'__PHEN__':esc(UI['en']['ph']),
 '__INTROTAG__':uispan('introTag'),'__INTROTEXT__':''.join('<span class="Lx %s">%s</span>'%(L,UI[L]['introText']) for L in LANGS),
 '__MTOTAL__':uispan('mTotal'),'__MIN__':uispan('mIn'),'__MOUT__':uispan('mOut'),'__MOCKMENU__':mock_menu,
 '__CHAPWRAPS__':chapwraps,'__FOOTER__':uispan('footer'),'__OPENAPP__':uispan('openApp'),'__BACK__':uispan('back'),
}
for k,v in repl.items(): HTML=HTML.replace(k,v)
io.open(OUT,'w',encoding='utf-8').write(HTML)
print('wrote',OUT,'·',round(len(HTML)/1024),'KB · 3 languages · illustrations 5+6')

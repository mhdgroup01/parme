# -*- coding: utf-8 -*-
"""Build the Paruay user-guide web app (guide.html) from the feature-map JSON."""
import json, html, io, sys

DATA = sys.argv[1] if len(sys.argv) > 1 else '/tmp/paruay_guide_data.json'
OUT = sys.argv[2] if len(sys.argv) > 2 else '/Users/mickysili/paruay/guide.html'
data = json.load(open(DATA, encoding='utf-8'))

def esc(s): return html.escape(s or '', quote=True)

# accent color per domain
ACC = ['#1B7A43', '#C8902E', '#7C3AED', '#0E7C66', '#BE123C']
# short nav label per domain
NAV = ['การเงินส่วนตัว', 'เพื่อน · หารบิล · ให้ยืม', 'ครอบครัว · ทริป', 'ร้านค้า POS', 'เกม · ตั้งค่า · ระบบ']

ICONS = {
 'people': '<svg viewBox="0 0 24 24" fill="#fff"><circle cx="9" cy="7.5" r="3"/><circle cx="16" cy="9" r="2"/><path d="M2.5 18.5c0-2.8 2.8-4.8 6.5-4.8s6.5 2 6.5 4.8V20h-13v-1.5z"/><path d="M16 14.5c2 0 4.2 1 4.2 3V18H17" opacity="0.7"/></svg>',
 'dollar': '<svg viewBox="0 0 24 24" fill="#fff"><rect x="1" y="4" width="22" height="16" rx="2"/><circle cx="12" cy="12" r="4.5" fill="#3B82F6"/><circle cx="12" cy="12" r="3.5" fill="#fff"/><text x="12" y="15.5" text-anchor="middle" fill="#3B82F6" font-size="9" font-weight="800">$</text></svg>',
 'shop': '<svg viewBox="0 0 24 24" fill="none"><path d="M3 9l1.5-5h15L21 9" stroke="#fff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/><path d="M3 9c0 1.1.9 2 2 2s2-.9 2-2c0 1.1.9 2 2 2s2-.9 2-2c0 1.1.9 2 2 2s2-.9 2-2c0 1.1.9 2 2 2s2-.9 2-2" stroke="#fff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/><rect x="4" y="11" width="16" height="10" stroke="#fff" stroke-width="2" rx="1"/><rect x="9" y="15" width="6" height="6" stroke="#fff" stroke-width="2" rx="0.5"/></svg>',
 'game': '<svg viewBox="0 0 24 24" fill="none"><path d="M6 11h4M8 9v4" stroke="#fff" stroke-width="2" stroke-linecap="round"/><circle cx="15" cy="10" r="1" fill="#fff"/><circle cx="18" cy="13" r="1" fill="#fff"/><path d="M17.32 5H6.68a4 4 0 00-3.978 3.59L2 14a3 3 0 005.12 2.13L8.24 15h7.52l1.12 1.13A3 3 0 0022 14l-.7-5.41A4 4 0 0017.32 5z" stroke="#fff" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/></svg>',
 'plane': '<svg viewBox="0 0 24 24" fill="#fff"><g transform="translate(12,12) rotate(-35) translate(-12,-12)"><path d="M21 12c1.1 0 2 .6 2 1.5S22.1 15 21 15H15l-3.5 5.5h-2l1.5-5.5H7l-1.5 2H4l1-3.5L4 10h1.5L7 12h4L9.5 6.5h2L15 12h6z"/></g></svg>',
}
MENU = [('people','#F59E0B','หารบิล'),('dollar','#3B82F6','ให้ยืม'),('shop','#10B981','ร้าน (POS)'),('game','#F43F5E','เกม'),('plane','#8B5CF6','ออกทริป')]

# ---------- CSS ----------
CSS = """
:root{
 --cream:#F5EFE0;--cream2:#FBF6E9;--paper:#fff;
 --forest:#1B4332;--forest2:#2D5A47;--forest3:#3D6B53;
 --brown:#7F5539;--brown2:#5C4632;--sand:#A89580;
 --gold:#D4A574;--gold2:#C8902E;--danger:#AA3C28;
 --line:rgba(127,85,57,.14);--line2:rgba(127,85,57,.22);
 --shadow:0 10px 30px -16px rgba(27,67,50,.35);
}
*{box-sizing:border-box}
html{scroll-behavior:smooth;scroll-padding-top:74px}
body{margin:0;background:var(--cream);color:var(--brown2);
 font-family:'Noto Sans Thai',system-ui,sans-serif;line-height:1.65;font-size:16px;
 -webkit-font-smoothing:antialiased}
.display{font-family:'Fraunces','Noto Serif Thai',serif}
a{color:inherit;text-decoration:none}
img,svg{max-width:100%}
.wrap{display:grid;grid-template-columns:268px 1fr;max-width:1280px;margin:0 auto}

/* sidebar */
.sidebar{position:sticky;top:0;align-self:start;height:100vh;overflow-y:auto;
 padding:24px 14px 40px;border-right:1px solid var(--line);background:var(--cream2)}
.brand{display:flex;align-items:center;gap:10px;padding:6px 8px 16px}
.brand .logo{width:40px;height:40px;border-radius:12px;background:linear-gradient(135deg,#1B4332,#3D6B53);
 display:flex;align-items:center;justify-content:center;color:#F5EFE0;font-weight:800;font-size:20px;flex:0 0 auto}
.brand b{font-size:20px;color:var(--forest)}
.brand small{display:block;font-size:11px;color:var(--sand);letter-spacing:.12em;text-transform:uppercase}
.nav-group{margin-top:14px}
.nav-group>.gh{display:flex;align-items:center;gap:8px;font-weight:700;font-size:13px;color:var(--forest);
 padding:8px 10px;letter-spacing:.01em}
.nav-group>.gh .dot{width:9px;height:9px;border-radius:3px;flex:0 0 auto}
.nav-group a{display:block;font-size:13.5px;color:var(--brown);padding:6px 10px 6px 28px;border-radius:9px;
 border-left:2px solid transparent;line-height:1.4}
.nav-group a:hover{background:#fff}
.nav-group a.active{background:#fff;color:var(--forest);font-weight:600;border-left-color:var(--gold2)}

/* topbar (mobile) */
.topbar{display:none;position:sticky;top:0;z-index:40;background:rgba(245,239,224,.92);
 backdrop-filter:blur(8px);border-bottom:1px solid var(--line);padding:10px 14px;
 align-items:center;justify-content:space-between}
.topbar b{color:var(--forest);font-size:17px}
.burger{width:42px;height:42px;border:1px solid var(--line2);background:#fff;border-radius:12px;
 display:flex;align-items:center;justify-content:center;cursor:pointer;font-size:18px;color:var(--forest)}

/* main */
main{min-width:0;padding:0 clamp(16px,3vw,40px) 80px}
.search{position:relative;margin:18px 0 8px}
.search input{width:100%;padding:13px 14px 13px 42px;border:1px solid var(--line2);border-radius:14px;
 background:#fff;font-size:15px;font-family:inherit;color:var(--brown2);outline:none}
.search input:focus{border-color:var(--gold2)}
.search svg{position:absolute;left:14px;top:50%;transform:translateY(-50%);width:18px;height:18px;opacity:.5}

/* hero */
.hero{position:relative;overflow:hidden;border-radius:26px;margin:18px 0 8px;padding:36px 30px;
 color:#F5EFE0;background:linear-gradient(135deg,#1B4332 0%,#2D5A47 55%,#3D6B53 100%);box-shadow:var(--shadow)}
.hero .glow{position:absolute;top:-60px;right:-50px;width:240px;height:240px;border-radius:50%;
 background:radial-gradient(circle,rgba(212,165,116,.3),transparent 70%)}
.hero h1{margin:0 0 6px;font-size:clamp(28px,5vw,42px);font-weight:800;letter-spacing:-.01em}
.hero .sub{font-size:15px;opacity:.86;max-width:640px}
.hero .pills{display:flex;flex-wrap:wrap;gap:8px;margin-top:18px}
.hero .pill{display:inline-flex;align-items:center;gap:7px;background:rgba(245,239,224,.14);
 border:1px solid rgba(245,239,224,.2);padding:7px 13px;border-radius:999px;font-size:13px}
.hero .pill i{width:18px;height:18px;border-radius:5px;display:inline-block}

/* intro grid: text + mockup */
.intro{display:grid;grid-template-columns:1fr 300px;gap:22px;align-items:center;margin:26px 0 8px}
.intro .lead{font-size:16px;color:var(--brown2)}
.intro .lead .tag{display:inline-block;background:#E7F0E9;color:#1B7A43;font-weight:700;font-size:12px;
 padding:3px 10px;border-radius:999px;margin-bottom:10px}
.phone{justify-self:center;width:280px;border-radius:34px;background:#1d2a22;padding:12px;box-shadow:var(--shadow)}
.phone .scr{border-radius:24px;background:var(--cream);overflow:hidden;padding:14px}
.mock-card{position:relative;overflow:hidden;border-radius:18px;padding:18px;color:#F5EFE0;
 background:linear-gradient(135deg,#1B4332,#2D5A47 60%,#3D6B53)}
.mock-card .ylab{font-size:10px;opacity:.75;letter-spacing:.08em;text-transform:uppercase}
.mock-card .num{font-family:'Fraunces',serif;font-size:30px;font-weight:700;line-height:1.1;margin-top:2px}
.mock-card .sub{font-size:11px;opacity:.8;margin-top:8px}
.mock-ie{display:flex;gap:8px;margin-top:12px}
.mock-ie div{flex:1;text-align:center;border-radius:12px;padding:11px;font-size:13px;font-weight:700;color:#fff}
.mock-menu{display:flex;gap:6px;margin-top:12px}
.mock-menu .b{flex:1;display:flex;flex-direction:column;align-items:center;gap:4px}
.mock-menu .ic{width:100%;padding:11px 0;border-radius:11px;display:flex;align-items:center;justify-content:center}
.mock-menu .ic svg{width:21px;height:21px}
.mock-menu small{font-size:8.5px;color:#7F5539;font-weight:600}

/* chapters */
.chapter{margin-top:46px;scroll-margin-top:74px}
.chapter-head{display:flex;align-items:center;gap:14px;margin-bottom:6px}
.chapter-head .no{width:46px;height:46px;border-radius:14px;display:flex;align-items:center;justify-content:center;
 color:#fff;font-family:'Fraunces',serif;font-weight:700;font-size:22px;flex:0 0 auto}
.chapter-head h2{margin:0;font-size:clamp(21px,3.4vw,28px);color:var(--forest);font-weight:800}
.chapter-rule{height:3px;border-radius:3px;margin:10px 0 22px;opacity:.5}

.block{background:var(--paper);border:1px solid var(--line);border-radius:20px;
 padding:20px 20px 8px;margin-bottom:18px;box-shadow:0 6px 18px -14px rgba(27,67,50,.3);scroll-margin-top:74px}
.block-title{display:flex;align-items:center;gap:10px;margin:0 0 4px;font-size:18px;font-weight:800;color:var(--forest)}
.block-title .em{font-size:22px;line-height:1}
.block-intro{margin:0 0 16px;color:var(--brown);font-size:14.5px}

.feature{border-top:1px dashed var(--line2);padding:16px 0}
.feature:first-of-type{border-top:0;padding-top:2px}
.feature h4{margin:0 0 5px;font-size:16px;color:var(--brown2);font-weight:800;display:flex;gap:8px;align-items:baseline}
.feature h4 .k{flex:0 0 auto;width:7px;height:7px;border-radius:2px;margin-top:7px}
.feature .what{margin:0 0 12px;font-size:14.5px;color:#6b5947}
.steps{margin:0;padding:0;list-style:none;counter-reset:s;display:flex;flex-direction:column;gap:8px}
.steps li{counter-increment:s;position:relative;padding-left:34px;font-size:14px;color:var(--brown2)}
.steps li::before{content:counter(s);position:absolute;left:0;top:-1px;width:23px;height:23px;border-radius:8px;
 background:#E7F0E9;color:#1B7A43;font-weight:800;font-size:12px;display:flex;align-items:center;justify-content:center;
 font-family:'Fraunces',serif}
.tip{margin:13px 0 2px;background:linear-gradient(#FDF7EA,#FBF1DD);border:1px solid rgba(200,144,46,.25);
 border-left:4px solid var(--gold2);border-radius:12px;padding:11px 14px;font-size:13.5px;color:#7a5b27}
.tip b{color:var(--gold2)}

footer{margin-top:60px;padding:28px 0 10px;border-top:1px solid var(--line);color:var(--sand);font-size:13px;text-align:center}
.totop{position:fixed;right:18px;bottom:18px;width:46px;height:46px;border-radius:50%;border:none;
 background:var(--forest);color:#F5EFE0;font-size:20px;cursor:pointer;box-shadow:var(--shadow);
 opacity:0;pointer-events:none;transition:.25s;z-index:50}
.totop.show{opacity:1;pointer-events:auto}
.scrim{display:none}

@media(max-width:880px){
 .wrap{grid-template-columns:1fr}
 .topbar{display:flex}
 .sidebar{position:fixed;top:0;left:0;height:100vh;width:280px;z-index:60;transform:translateX(-105%);
  transition:transform .28s ease;box-shadow:0 0 40px rgba(0,0,0,.25)}
 body.nav-open .sidebar{transform:none}
 body.nav-open .scrim{display:block;position:fixed;inset:0;background:rgba(20,12,8,.4);z-index:55}
 .intro{grid-template-columns:1fr}
 .phone{width:262px}
}
.hl{background:#fde9a8;border-radius:4px}
"""

# ---------- build HTML ----------
def feature_html(f, acc):
    parts = ['<div class="feature" data-sf="%s">' % esc((f['name']+' '+f['what']).lower())]
    parts.append('<h4><span class="k" style="background:%s"></span>%s</h4>' % (acc, esc(f['name'])))
    parts.append('<p class="what">%s</p>' % esc(f['what']))
    if f.get('steps'):
        parts.append('<ol class="steps">' + ''.join('<li>%s</li>' % esc(s) for s in f['steps']) + '</ol>')
    if f.get('tip') and f['tip'].strip():
        parts.append('<div class="tip"><b>💡 เคล็ดลับ:</b> %s</div>' % esc(f['tip']))
    parts.append('</div>')
    return ''.join(parts)

def block_html(sec, acc, sid):
    h = ['<div class="block" id="%s">' % sid]
    h.append('<h3 class="block-title"><span class="em">%s</span>%s</h3>' % (esc(sec['emoji']), esc(sec['title'])))
    if sec.get('intro'): h.append('<p class="block-intro">%s</p>' % esc(sec['intro']))
    for f in sec['features']:
        h.append(feature_html(f, acc))
    h.append('</div>')
    return ''.join(h)

chapters = []
navgroups = []
for di, dom in enumerate(data):
    acc = ACC[di % len(ACC)]
    cid = 'dom%d' % di
    secs_html = []
    navlinks = []
    for si, sec in enumerate(dom['sections']):
        sid = 'sec%d_%d' % (di, si)
        secs_html.append(block_html(sec, acc, sid))
        navlinks.append('<a href="#%s">%s %s</a>' % (sid, esc(sec['emoji']), esc(sec['title'])))
    chapters.append(
        '<section class="chapter" id="%s">'
        '<div class="chapter-head"><div class="no" style="background:%s">%d</div>'
        '<h2>%s</h2></div>'
        '<div class="chapter-rule" style="background:%s"></div>%s</section>'
        % (cid, acc, di+1, esc(dom['domain']), acc, ''.join(secs_html)))
    navgroups.append(
        '<div class="nav-group"><div class="gh"><span class="dot" style="background:%s"></span>'
        '<a href="#%s" style="padding:0">%s</a></div>%s</div>'
        % (acc, cid, esc(NAV[di]), ''.join(navlinks)))

# hero pills + menu mockup
hero_pills = ''.join('<span class="pill"><i style="background:%s"></i>%s</span>' % (c, esc(lbl)) for _,c,lbl in MENU)
mock_menu = ''.join(
    '<div class="b"><div class="ic" style="background:%s">%s</div><small>%s</small></div>' % (c, ICONS[k], esc(lbl))
    for k,c,lbl in MENU)

HTML = """<!doctype html><html lang="th"><head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>คู่มือการใช้งาน · พารวย (Paruay)</title>
<meta name="description" content="คู่มือการใช้งานแอปพารวย — บันทึกรายรับรายจ่าย หารบิล ให้ยืม ครอบครัว ร้านค้า POS และอื่นๆ">
<link rel="preconnect" href="https://fonts.googleapis.com"><link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Fraunces:opsz,wght@9..144,500;9..144,700;9..144,900&family=Noto+Sans+Thai:wght@400;500;600;700;800&family=Noto+Serif+Thai:wght@600;700&display=swap" rel="stylesheet">
<style>__CSS__</style></head><body>
<div class="topbar"><b class="display">พารวย · คู่มือ</b><button class="burger" id="burger" aria-label="เมนู">☰</button></div>
<div class="scrim" id="scrim"></div>
<div class="wrap">
<aside class="sidebar" id="sidebar">
 <div class="brand"><div class="logo display">พ</div><div><b class="display">พารวย</b><small>Paruay · คู่มือ</small></div></div>
 <div class="nav-group"><div class="gh"><span class="dot" style="background:#1B4332"></span><a href="#top" style="padding:0">เริ่มต้น / ภาพรวม</a></div></div>
 __NAV__
</aside>
<main>
 <span id="top"></span>
 <section class="hero"><div class="glow"></div>
   <h1 class="display">คู่มือการใช้งาน พารวย</h1>
   <p class="sub">แอปจัดการเงินครบในแอปเดียว — บันทึกรายรับรายจ่าย หารบิลกับเพื่อน ให้ยืม จัดการเงินครอบครัว เปิดร้านขายของ (POS) ออกทริป และเล่นเกม คู่มือนี้รวมทุกฟังก์ชันให้ผู้ใช้มือใหม่เริ่มได้ทันที</p>
   <div class="pills">__PILLS__</div>
 </section>

 <div class="search"><svg viewBox="0 0 24 24" fill="none"><circle cx="11" cy="11" r="7" stroke="#7F5539" stroke-width="2"/><path d="M21 21l-4-4" stroke="#7F5539" stroke-width="2" stroke-linecap="round"/></svg>
   <input id="q" type="search" placeholder="ค้นหาฟังก์ชัน เช่น หารบิล, งบประมาณ, QR, ดอกเบี้ย ..."></div>

 <div class="intro">
  <div class="lead"><span class="tag">หน้าจอหลัก</span><br>
   เมื่อเปิดแอป คุณจะเห็น <b>การ์ดยอดเงิน</b> สีเขียวอยู่บนสุด ใต้ลงมาคือปุ่ม <b>รายรับ/รายจ่าย</b> สำหรับบันทึกเร็ว และแถว <b>ปุ่มเมนู 5 ปุ่ม</b> สำหรับฟีเจอร์หลัก — แตะหัวข้อทางซ้าย (หรือเมนู ☰ บนมือถือ) เพื่อข้ามไปยังส่วนที่สนใจได้เลย</div>
  <div class="phone"><div class="scr">
    <div class="mock-card">
      <div class="ylab">ยอดเงินทั้งหมด</div>
      <div class="num">₭ 1,250,000</div>
      <div class="sub">฿ 3,000 &nbsp; $ 50</div>
    </div>
    <div class="mock-ie"><div style="background:#1B7A43">+ รายรับ</div><div style="background:#AA3C28">▽ รายจ่าย</div></div>
    <div class="mock-menu">__MOCKMENU__</div>
  </div></div>
 </div>

 __CHAPTERS__

 <footer>พารวย (Paruay) · คู่มือการใช้งาน · อัปเดต 16 มิ.ย. 2026<br>เปิดแอป: <b>mhdgroup01.github.io/paruay</b></footer>
</main></div>
<button class="totop" id="totop" aria-label="ขึ้นบน">↑</button>
<script>
var burger=document.getElementById('burger'),scrim=document.getElementById('scrim');
function closeNav(){document.body.classList.remove('nav-open')}
burger.onclick=function(){document.body.classList.toggle('nav-open')};
scrim.onclick=closeNav;
document.querySelectorAll('.sidebar a').forEach(function(a){a.addEventListener('click',closeNav)});
// scroll spy
var links=[].slice.call(document.querySelectorAll('.nav-group a[href^="#sec"]'));
var map={};links.forEach(function(a){map[a.getAttribute('href').slice(1)]=a});
var io=new IntersectionObserver(function(es){es.forEach(function(e){var a=map[e.target.id];if(!a)return;
 if(e.isIntersecting){links.forEach(function(x){x.classList.remove('active')});a.classList.add('active');}});},
 {rootMargin:'-72px 0px -70% 0px'});
document.querySelectorAll('.block').forEach(function(b){io.observe(b)});
// back to top
var tt=document.getElementById('totop');
addEventListener('scroll',function(){tt.classList.toggle('show',scrollY>500)});
tt.onclick=function(){scrollTo({top:0,behavior:'smooth'})};
// search filter
var q=document.getElementById('q');
q.addEventListener('input',function(){
 var v=q.value.trim().toLowerCase();
 document.querySelectorAll('.block').forEach(function(bl){
  var any=false;
  bl.querySelectorAll('.feature').forEach(function(f){
   var hit=!v||f.getAttribute('data-sf').indexOf(v)>=0;
   f.style.display=hit?'':'none';if(hit)any=true;});
  var t=bl.querySelector('.block-title').textContent.toLowerCase();
  if(!v){bl.style.display='';}else{bl.style.display=(any||t.indexOf(v)>=0)?'':'none';}
 });
 document.querySelectorAll('.chapter').forEach(function(ch){
  var vis=[].slice.call(ch.querySelectorAll('.block')).some(function(b){return b.style.display!=='none'});
  ch.style.display=vis?'':'none';});
});
</script></body></html>"""

HTML = (HTML.replace('__CSS__', CSS).replace('__NAV__', ''.join(navgroups))
        .replace('__PILLS__', hero_pills).replace('__MOCKMENU__', mock_menu)
        .replace('__CHAPTERS__', ''.join(chapters)))

io.open(OUT, 'w', encoding='utf-8').write(HTML)
print('wrote', OUT, '·', round(len(HTML)/1024), 'KB ·', sum(len(d['sections']) for d in data), 'sections')

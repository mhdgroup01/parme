# สเปกออกแบบ: Parme Poker 3D (Texas Hold'em) — v1
ออกแบบโดย Fable 5 · 2026-07-17 · สำหรับ AI implementer ลงมือสร้างใน `~/paruay/index.html`

## 0. เป้าหมาย
เกมโป๊กเกอร์ Texas Hold'em หน้าตา "3D สวย" เล่นกับบอท 1–5 ตัวจบในเครื่อง (v1)
เสียบเข้าโหมดเกมเดิมของ GameModal เป็นเกมที่ 5 — **ห้ามแตะพฤติกรรมเกมเดิมทั้ง 4 เกม**
โครง state ออกแบบให้ multiplayer ผ่าน game_sessions ทำได้ในเฟส 2 โดยไม่ต้องรื้อ (แต่ v1 ไม่ทำ)

## 1. จุดเสียบใน GameModal (อ่านโค้ดจริงก่อนแก้ — เลขบรรทัด ณ v3.7.336 อาจขยับ)
- `GameModal` เริ่ม ~L31402. เกมเดิม: draw52 / liarsdice / koy / memory
- **picker**: state `gt` — เพิ่มตัวเลือก `'poker'` ในเมนูเลือกเกม (หา UI ที่ set `setGt`)
- **สร้าง state เริ่มเกม**: ternary ที่ ~L31493 (`gt === 'draw52' ? {...} : ...`) — เพิ่ม branch poker
- **normalizer** (รับ state จาก session): ternary ~L31498 — เพิ่ม branch poker (ทุก field มี default)
- **เริ่มรอบใหม่**: ternary ใน handler ~L31569 — poker = เริ่มมือใหม่ (ดู §4 ข้อ H)
- **จอเกม**: switch ตาม `g.game` — เพิ่ม renderer ของ poker
- **ไพ่**: ใช้ `deckCard(c, key)` (~L31756) — svg `<use xlinkHref='#vpc_'+PCSUIT[c.s]+'_'+PCRANK[c.r]>` viewBox `0 0 222.24 310.82`; สำรับจาก `make52()`; ห้าม embed ภาพไพ่ใหม่
- **หลังไพ่**: ไม่มี asset — วาดด้วย div: พื้น `var(--pv-primary)` ไล่เฉด + ขอบขาว 6% + ลายตาราง CSS (repeating-linear-gradient ขาว 6%) + ตัว "P" กลาง (font display, ขาว 25%)
- **i18n**: ทุกข้อความผ่าน `t.xxx || 'fallback อังกฤษ'` แบบเกมเดิม + เพิ่มคีย์ใน I18N ครบ 4 ภาษา (lo/th/en/zh) — คำลาวให้ประกอบจากคำที่มีอยู่แล้วในไฟล์เท่านั้น (grep ก่อนใช้ทุกคำ) ถ้าไม่มีให้ใช้อังกฤษแทน ห้ามแต่งคำลาวใหม่จากความจำ
- **ธีม**: สีทุกค่าผ่าน `var(--pv-*)`; ค่าที่ต่างตามธีมใช้ `window.__pvFb ? ... : ...` (ดู idiom ใน PIE_COLORS ~L11605); **ห้าม hex ธีมเขียวตรงๆ**; ห้าม emoji ใหม่ทุกที่ (ใช้ไอคอน lucide ที่มี: Plus, Check, X, RefreshIc, CrownIc, Settings, StarIc ฯลฯ)
- **ฟอนต์/ขนาด**: ตัวเลข/หัวข้อใช้ `className: 'display'`; ข้อความใช้ `className: langClass`; fontSize เป็น "ตัวเลข" ใน style เสมอ (interceptor ธีม fb สเกล +15% ให้เอง)

## 2. กติกา (No-Limit Texas Hold'em — ครบ ไม่ตัดทอน)
- ที่นั่ง 2–6 (ผู้เล่นจริง seat 0 + บอท) · ชิปเริ่มเท่ากันทุกคน
- Dealer button หมุนตามเข็ม; SB = BB/2 (ปัดขึ้นเป็นจำนวนเต็ม), heads-up: dealer = SB
- Street: preflop → flop(3) → turn(1) → river(1); เผา 1 ใบก่อนแจกกองกลางทุกครั้ง
- Action: fold / check / call / bet / raise / all-in
  - min-bet = BB; min-raise = ขนาด raise ล่าสุด (ถ้าไม่มี = BB); all-in ต่ำกว่า min-raise ไม่ re-open การ raise ให้คนที่ action ครบแล้ว
- **Side pots**: ต้องถูกต้องเต็มรูปแบบ — ผู้เล่น all-in หลายคนหลาย stack แยก pot เป็นชั้น แต่ละ pot มีผู้มีสิทธิ์ของตัวเอง
- Showdown: best 5 จาก 7; เทียบ rank → kicker; เสมอแบ่ง pot เท่ากัน (เศษชิปให้ที่นั่งซ้ายสุดจาก dealer)
- ทุกคน fold เหลือคนเดียว = จบมือทันที ไม่เปิดไพ่
- ผู้เล่นชิปหมด = นั่งดู (out); เหลือคนมีชิปคนเดียว = จบเกม แสดงแชมป์
- ตัวเลือก blind เพิ่ม: ทุก N มือ SB/BB ×2 (ดู options)

## 3. Hand evaluator (หัวใจ — จะถูกทดสอบแยกก่อนรับงาน)
ฟังก์ชัน pure: `pkEval(cards7)` → `{ cat, tiebreak }` — cat 8=straight flush … 0=high card,
tiebreak = อาร์เรย์เลขเทียบตามลำดับ; เปรียบเทียบมือด้วย `pkCmp(a, b)`
- รองรับ: wheel (A-2-3-4-5 ต่ำสุดของ straight), flush เทียบ 5 ใบ, full house เทียบ trips→pair,
  two pair เทียบ คู่สูง→คู่รอง→kicker, quads+kicker
- **ต้องผ่าน test vectors ท้ายสเปกทุกข้อ** — เขียนเป็นฟังก์ชัน pure ที่ extract ไป node ได้
  (ห้ามอ้าง state/DOM ข้างใน)

## 4. State shape (ตาม convention เกมเดิม — field สั้น, serializable)
```js
{ game: 'poker',
  deck: [...],           // ที่เหลือหลังแจล (จาก make52() สับแล้ว)
  hole: [[c,c], ...],    // ต่อที่นั่ง
  board: [c, ...],       // 0/3/4/5 ใบ
  stacks: [n, ...], bets: [n, ...],   // bets = เงินบน street ปัจจุบัน
  pot: n,                // ที่เก็บแล้วจาก street ก่อนหน้า
  folded: [bool], allin: [bool], out: [bool],
  dealer: i, turn: i, street: 'pre'|'flop'|'turn'|'river'|'showdown'|'handover',
  lastRaise: n, toCall: n,
  sb: n, bb: n, handNo: n, blindUp: 0|N,   // 0 = ไม่เพิ่ม
  reveal: null | { winners:[i], pots:[{amt, eligible:[i], winners:[i]}], best:{i:[c5]}, name:{i:catName} },
  msg: null | 'สตริงเหตุการณ์ล่าสุด', round: 1 }
```
- A) แจกมือ: สับ deck (Fisher-Yates), แจก hole ทีละใบวนตามเข็มจาก SB, ตั้ง blinds เข้า bets
- B) turn เดินเฉพาะคนที่ !folded && !allin && !out
- C) จบ street: ทุกคน action ครบและ bets เท่ากัน (หรือ all-in) → เก็บ bets เข้า pot, เปิดกองกลาง, turn = คนแรกซ้าย dealer ที่ยังเล่น
- D) บอทตัดสินใจใน `setTimeout` ตาม speed option (คิวทีละตัว ห้ามซ้อน — ใช้ ref กัน re-entry;
  cleanup timer ตอน unmount)
- E) showdown: สร้าง side pots จาก contribution ทั้งมือ (รวม street ก่อนหน้า — เก็บ
  contribution สะสมต่อคนใน field `paid: [n,...]`), ประเมิน pkEval, กรอก reveal
- F) จอ reveal ค้างไว้จนกด "มือต่อไป" (หรือ auto ตาม speed หลัง 6 วิ — มี option)
- G) เงินเข้า stacks ตอน reveal commit เท่านั้น
- H) เริ่มมือใหม่: dealer+1 (ข้ามคน out), handNo+1, blind ×2 ถ้าถึงรอบ blindUp
- ห้ามใช้ `Math.random` นอกการสับไพ่/บอท (ไม่มีข้อจำกัด Date — นี่แอปปกติ)

## 5. Bot AI (3 ระดับ — option)
- ใช้คะแนนมือ: preflop = Chen formula (คิดจาก hole 2 ใบ); postflop = `pkEval(hole+board)` + จำนวน out คร่าว
- ง่าย: เดิมพันสุ่มถ่วงน้ำหนักตามคะแนน, ไม่ bluff, call เก่ง
- กลาง: pot odds จริง (call เมื่อ equity คร่าว ≥ ราคา), bet ตามความแรงมือ, bluff 8%
- โหด: เพิ่ม positional awareness (ตำแหน่งท้าย bet บ่อยขึ้น), semi-bluff เมื่อมี draw, บีบคนใกล้หมดชิป, bluff 15%
- ทุกระดับ: ไม่โกง — **ห้ามอ่าน hole ของคนอื่น** (รับเฉพาาะ hole ตัวเอง + board + ข้อมูลสาธารณะ)

## 6. UI/3D (หัวใจ "สวย")
**เลย์เอาต์โต๊ะ (จอเกม):** เต็มพื้นที่ GameModal แนวตั้งมือถือเป็นหลัก (~390×700)
- ฉาก: `perspective: 1100px` ที่ container; โต๊ะเป็น ellipse `rotateX(38deg)` — ผ้าสักหลาด
  ไล่เฉด radial (ธีมเขียว: เขียวเข้ม→ดำ #royal, ธีม fb: น้ำเงิน --pv-primary-deep→เกือบดำ)
  + ขอบราง (rail) หนาไล่เฉดเข้ม + เงา drop-shadow ใต้โต๊ะ (ลอยจากพื้น)
- ที่นั่ง 2–6 จัดรอบวงรี (ผู้เล่นจริงล่างกลางเสมอ) — แผ่นชื่อ: avatar อักษรแรก, ชื่อ, stack,
  แถบสถานะ (fold = จาง 45%, all-in = ป้าย, ถึงตา = ขอบเรือง `box-shadow` สีธีม + วงแหวน
  countdown เดินรอบ (conic-gradient, เฉพาะตาผู้เล่นจริง — ไม่มี time limit จริง แค่ pulse))
- **ไพ่ 3D**: การ์ดทุกใบเป็น `transform-style: preserve-3d` สองหน้า (front = deckCard,
  back = ลาย Parme §1) พลิกด้วย `rotateY(180deg)` transition 0.5s; แจกไพ่ = อนิเมชันลอยจาก
  ตำแหน่ง deck กลางโต๊ะไปที่นั่ง (keyframe translate+rotate, delay ไล่ทีละใบ 90ms);
  เปิดกองกลาง = พลิกทีละใบ delay 140ms; hole ของผู้เล่นจริงใหญ่ ยกขึ้นเมื่อแตะ (hover/press
  translateY(-10px) rotateX เล็กน้อย)
- **ชิป**: กองชิปวาดด้วย div ซ้อน (isometric: วงรี + ขอบหนา + notch ขาว 4 จุด) มูลค่าสี
  มาตรฐาน (1k แดง / 5k น้ำเงิน / 10k ดำ / 25k เขียว / 100k ม่วง — ปรับ hue ตามธีมได้);
  เดิมพัน = ชิปบินจากที่นั่งไปหน้า seat (transition transform), เก็บ pot = บินเข้ากลาง,
  ชนะ = pot บินไปผู้ชนะ + ตัวเลขเด้ง
- **แถบ action ผู้เล่นจริง** (ล่างสุด, ติดนิ้วโป้ง): ปุ่ม Fold / Check-Call (รวมปุ่มเดียว
  เปลี่ยน label+จำนวน) / Raise — กด Raise เปิดสไลเดอร์ + ปุ่มลัด (Min / ½ pot / Pot / All-in)
  ตัวเลขพรีวิวใหญ่ font display; ปุ่มใหญ่ ≥48px สูง เว้นช่องกันกดพลาด
- **showdown**: ไพ่ผู้ชนะเรืองแสง (box-shadow ทอง `--pv-gold`), ใบที่เป็น best-5 ยกขึ้น,
  ป้ายชื่อมือ (เช่น "Full House") + จำนวนชนะ; แพ้ = จางลง
- **จอ setup (ก่อนเริ่ม):** การ์ดตั้งค่า option ทั้งหมด (§7) สไตล์เดียวกับจอ setup เกมเดิม
  (ดู liarsdice ~L31649, bonusRanks ~L31750 เป็น idiom)
- ธีม fb: พื้นหลัง/การ์ดต้องดูเข้ากับ FB ขาวน้ำเงิน (โต๊ะน้ำเงินเข้ม); เขียว: โต๊ะเขียวคาสิโน
- ประสิทธิภาพ: อนิเมชันใช้ transform/opacity เท่านั้น (ห้าม animate layout); จำนวน DOM
  ต่อจอ < 400 node; ไม่มี setInterval ยิงตลอด (ใช้ transition/animation CSS + timeout บอท)

## 6.5 Art Direction ระดับโลก (ยกระดับจาก §6 — บังคับทุกข้อ, CSS ล้วน transform/opacity เท่านั้น)
เทียบชั้น PokerStars/WSOP (โต๊ะโปร) + Zynga (feedback ฉ่ำ) + Balatro (แสง+สปริง):

**A. แสงและบรรยากาศ (สำคัญสุด — ตัวแยก "เกมจริง" กับ "เดโม"):**
- ฉากหลังเป็นห้องมืด: gradient แนวตั้งเข้ม + **vignette** radial ดำจางรอบขอบจอ (สปอตไลต์กลางโต๊ะ)
  + ambient glow สีตามธีมจางๆ หลังโต๊ะ (เขียว→amber อุ่น, fb→น้ำเงินเย็น)
- ผ้าสักหลาด: radial หลาย stop (กลางสว่าง→ขอบดำลึก) + **แสง sheen เคลื่อนช้าๆ** (::after
  linear-gradient เอียง opacity ~0.05 เลื่อนด้วย keyframes 14s วนไป-กลับ — โต๊ะ "มีชีวิต")
  + เส้นขอบสนาม (betting line) วงรีเส้นบาง opacity 0.15
- ราง (rail): หนังเข้ม = inner shadow บน + highlight เส้นบนสุด + **เส้นทริมทอง 1.5px**
  (--pv-gold) ระหว่างรางกับผ้า; เงาโต๊ะตกพื้น 2 ชั้น (ใกล้เข้ม/ไกลฟุ้ง) แหล่งแสงบน-กลางเสมอ
- ทุกเงาในฉากทิศเดียวกัน (ลงล่างเยื้องหน้า) — การ์ด/ชิป/ปุ่ม ใช้ drop-shadow สอดคล้องกัน

**B. Typography & HUD:**
- ตัวเลขใหญ่ทั้งหมด (pot, stack, ราคา call): font `display` + **count-up** (เปลี่ยนค่าแล้ว
  วิ่งเลขถึงค่าใหม่ ~350ms ผ่าน rAF helper ตัวเดียว ใช้ร่วมกันทุกจุด)
- Pot กลางโต๊ะ: เม็ดยา (pill) พื้นดำโปร่ง + ขอบทอง + เรืองทองจางๆ; ตัวเลขทอง
- แผ่นชื่อผู้เล่น: **glass** (พื้นดำโปร่ง ~0.55 + backdrop-blur 8px + ขอบขาว 8%) avatar วงแหวน
  สีสถานะ; ปุ่ม dealer = เหรียญ "D" ทองนูน (gradient + inner highlight + เงา) เลื่อนตามตำแหน่งจริง
- ปุ่ม action: นูนกดได้จริง — พัก: gradient + inner-highlight บน + เงาล่าง 3px; :active:
  translateY(2px) + เงาหด (physical press); Fold โทนแดงเข้ม, Check/Call เทากลาง, Raise สีธีมเด่นสุด

**C. Motion language (สปริงทั้งเกม — easing กลาง `cubic-bezier(0.34,1.56,0.64,1)` มี overshoot):**
- แจกไพ่: วิ่ง**โค้ง**จากสำรับ (2 จังหวะ: ยกขึ้นเฉียง→ตกลงที่นั่ง) + หมุนเล็กน้อย, stagger 90ms,
  จบด้วย overshoot สั้น; เปิดกองกลาง: พลิก + **scale 1.08 กลางพลิก** ทีละใบ
- ชิปเดิมพัน: ลอยโค้งไปหน้า seat แบบ stagger; เก็บเข้า pot ตอนจบ street = ทั้งหมดวิ่งเข้า
  กลางไล่กัน; **ชนะ = ชิประเบิดจาก pot วิ่งไปผู้ชนะ + ประกายทอง 12 เม็ด** (div เล็ก
  keyframe กระจาย+จาง transform-only) + เลข stack วิ่งขึ้น
- ถึงตา: วงแหวนหายใจ (scale+opacity pulse 1.6s) + แผ่นชื่อยกขึ้น 4px; หมดตา วางลง
- Fold: ไพ่บินเข้ากอง muck กลางโต๊ะ หมุน+จาง; All-in: แผ่นชื่อขอบเรืองแรง + ป้าย ALL-IN
  กระแทกเข้า (scale overshoot)
- **ฉลองผู้ชนะ**: ป้ายชื่อมือ (เช่น FULL HOUSE) สไลด์เข้ากลางจอ + **shine sweep** วิ่งผ่าน
  ตัวอักษรหนึ่งครั้ง; pot ใหญ่ (> 20×BB) เพิ่ม**คอนเฟตตีทอง ~16 ชิ้น**ร่วงจากบน (CSS ล้วน);
  แผ่นผู้ชนะ scale 1.06 + รัศมี conic หมุนช้าด้านหลัง 2.5s แล้วจางออก
- ทั้งหมด scale ตาม option ความเร็ว (คูณ duration กลางที่ตัวแปรเดียว)

**D. Micro-interactions ระดับโลก:**
- **Peek ไพ่ตัวเอง**: ไพ่ hole คว่ำอยู่ กดค้าง = "บี้ไพ่" — มุมไพ่ค่อยๆ งอเปิด (rotateX จากขอบล่าง
  ~35° + เงาเลื่อน) เห็นแต้มมุม, ปล่อย = ปิดกลับ; ดับเบิลแตะ = หงายถาวรทั้งสองใบ
  (จำสถานะต่อมือ) — นี่คือ signature ของโป๊กเกอร์มือถือชั้นนำ
- Raise slider: ราง gradient จาง→เข้มตามจำนวน, thumb ใหญ่ 28px นูน, **snap** เข้าปุ่มลัด
  (Min/⅓/½/Pot/All-in) เมื่อเข้าใกล้, ตัวเลขพรีวิวลอยเหนือ thumb ขยับตาม
- Check = เคาะโต๊ะ: ripple วงกลมจางกลางโต๊ะ 1 ครั้ง
- แตะ board card = ซูมดูใหญ่ชั่วคราว (scale 1.6 กลางจอ พื้นหลังมืดลง แตะปิด)

**E. HUD บน:** แถวบางบนสุด — มือที่ #N · blind ปัจจุบัน (SB/BB) · ไอคอน Settings เปิดชีต
ตั้งค่ากลางเกม (เปลี่ยนได้: ความเร็ว/ความยาก/auto-next/peek) · ปุ่มออก (ยืนยันก่อนถ้ามือค้าง)

**F. เส้นสายตา:** ทุกจังหวะสำคัญมีลำดับโฟกัสเดียว — แจก→ตาใคร→board→pot→ผู้ชนะ; ห้ามมี
อนิเมชันสองจุดแย่งสายตาพร้อมกัน (คิวอนิเมชันต่อเนื่อง ไม่ยิงขนาน)

## 7. Options (จอ setup — เก็บ `localStorage 'paruay_poker_opts'` JSON เดียว)
| ตัวเลือก | ค่า | default |
|---|---|---|
| จำนวนบอท | 1–5 | 2 |
| ชิปเริ่ม | 20k / 50k / 100k / 200k | 100k |
| Big blind | 500 / 1k / 2k / 5k | 1k |
| Blind เพิ่ม ×2 ทุก N มือ | ปิด / 5 / 10 | ปิด |
| ความยากบอท | ง่าย / กลาง / โหด | กลาง |
| ความเร็ว (บอท+อนิเมชัน) | ช้า / ปกติ / เร็ว | ปกติ |
| เปิดมือต่อไปอัตโนมัติ | เปิด / ปิด | เปิด |
| โชว์ชื่อมือของเรา realtime | เปิด / ปิด | เปิด |
(ทุก option ต้อง "มีผลจริง" — flip แล้วพฤติกรรมเปลี่ยน จะถูกทดสอบ)

## 8. Definition of Done (ผู้ออกแบบจะตรวจเองทุกข้อ)
1. `python3 tools/check.py` ผ่าน
2. pkEval ผ่าน test vectors ครบ (extract ไป node ได้)
3. เล่นจบมือได้จริงใน browser (?demo=1): แจก→เดิมพัน→showdown→มือต่อไป; ทั้ง fold-จบเร็ว
   และ showdown หลาย pot
4. เกมเดิม 4 เกมเปิดเล่นได้เหมือนเดิม (regression)
5. ธีมเขียว/fb สวยทั้งคู่ ไม่มีสี hardcode ธีมเขียวหลุดใน fb
6. มือถือ 390px ไม่มีอะไรล้น/ทับ; ปุ่ม action กดได้จริงด้วยการคลิก
7. ไม่มี console error
- วิธีทำงาน: `cp index.html index.html.bak-poker` ก่อน, แก้ผ่านสคริปต์ python นับ occurrence
  ตาม convention repo, **ห้าม bump เวอร์ชัน/deploy/commit** — ผู้ออกแบบเป็นคนตรวจและปล่อยเอง

## 9. Test vectors — pkEval (`cards = {r: 2..14, s: 0..3}`; 14=A)
| มือ 7 ใบ (r/s) | คาด cat | หมายเหตุ |
|---|---|---|
| 10♠J♠Q♠K♠A♠ 2♥3♦ | 8 | royal (straight flush สูงสุด tiebreak [14]) |
| A♠2♠3♠4♠5♠ K♥Q♦ | 8, tb [5] | wheel straight flush |
| 9♣9♦9♥9♠ K♠ 2♥3♦ | 7, tb [9,13] | quads + kicker K |
| 8♣8♦8♥ 5♠5♦ A♠K♥ | 6, tb [8,5] | full house (A ไม่เกี่ยว) |
| 2♠5♠9♠J♠K♠ A♥A♦ | 5 | flush ชนะ pair A |
| A♥2♦3♣4♠5♥ 9♦9♣ | 4, tb [5] | wheel ชนะ pair 9 |
| 6♥7♦8♣9♠10♥ 10♦10♣ | 4, tb [10] | straight ชนะ trips |
| Q♥Q♦Q♣ 7♠2♥3♦9♣ | 3, tb [12,9,7] | trips + kickers |
| K♥K♦ 9♠9♥ A♣ 2♦3♣ | 2, tb [13,9,14] | two pair |
| J♥J♦ A♠K♥9♣ 2♦3♣ | 1, tb [11,14,13,9] | pair |
| A♦K♥9♣7♠5♥3♦2♣ | 0, tb [14,13,9,7,5] | high card |
| เทียบ: A♠A♥KQJx vs A♦A♣KQ10x | pkCmp > 0 | kicker ตัดสิน |
| side pot: A all-in 1k, B all-in 5k, C 10k → pot หลัก 3k (ABC), side1 8k (BC), side2 5k คืน C | — | ทดสอบใน logic แยก pot |

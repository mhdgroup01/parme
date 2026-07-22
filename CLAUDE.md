# CLAUDE.md — Paruay (ພາລວຍ)

> ไฟล์นี้ Claude Code อ่านทุกครั้งที่เริ่ม session ทำหน้าที่เป็น "ความจำถาวร" ของโปรเจกต์

## ภาษา
คุยกับเจ้าของโปรเจกต์ (M) เป็น **ภาษาไทย** เสมอ ใช้ศัพท์เทคนิคภาษาอังกฤษได้ตามปกติ

## ภาพรวมโปรเจกต์
Paruay เป็น **single-file React PWA** ไฟล์เดียวคือ `index.html` (~3.9MB)
รวม 3 ระบบในแอปเดียว:
- การเงินส่วนตัว/ครอบครัว (เน้นเงินกีบลาว + รองรับสกุลเงินต่างประเทศ)
- POS ร้านอาหาร/ร้านค้า (โต๊ะ, QR order, ครัว, ส่วนลด/service charge)
- เกมไพ่/ลูกเต๋า

รองรับ 4 ภาษา: ลาว (lo), ไทย (th), อังกฤษ (en), จีน (zh) — ภาษาหลักคือลาว
กลุ่มเป้าหมาย: ร้านค้าเล็กที่พูดภาษาลาว

## สถาปัตยกรรม (ข้อจำกัดที่ต้องยึดเสมอ)
- **ไฟล์เดียว** — ทุกอย่างอยู่ใน `index.html` ห้ามแตกไฟล์ JS/CSS ออก
- **ไม่มี build step** — โค้ดเขียน `React.createElement` ตรงๆ (มี `h` เป็น alias) ไม่มี Babel runtime ในเบราว์เซอร์
- **Deploy: self-host บน Hostinger VPS** — https://parme.me + www (nginx container `parme-prod`, DNS ผ่าน Cloudflare → 187.127.209.83). repo `mhdgroup01/paruay` branch `main` ยัง sync อยู่แต่ **GitHub Pages ไม่ใช่ตัวเสิร์ฟ prod แล้ว** (เหลือเป็น fallback: revert DNS กลับ 185.199.108-111.153) — ย้ายมา VPS ตั้งแต่ 2026-07-02
- **Backend: self-host Supabase บน VPS** (`https://api.parme.me`, project ref เดิม `rilrbflteuwhomrwfcsa` ยังใช้เป็นชื่อ display) — auth (GoTrue)/realtime/postgres/edge functions รันบน VPS. **Supabase Cloud เก็บไว้เป็น fallback** (snapshot วัน cutover ไม่ใช่ backup ปัจจุบัน). รายละเอียดโครงสร้าง VPS ดู second-brain memory `[[hostinger-vps]]`

## เวอร์ชันปัจจุบัน
v3.7.370 (2026-07-22 — **แผงบิลโหมดสองคอลัมน์ (≥1100): ยอด+ปุ่มบันทึกตรึงล่างสุด รายการบิลยืดเต็มกลาง** — เจ้าของขอจากภาพ iPad จริง. CSS ล้วนในบล็อก ≥1100 เดิม: `.pv-pos-cart` เป็น flex column, กล่องห่อรายการ+ยอด (ลูกตัวสุดท้ายเสมอ ทั้งกรณีว่าง/มีของ) flex:1, ตัวรายการ (`[style*="max-height: 108px"]` — แคปที่จำเป็นบนมือถือ) → `max-height:none + flex:1 + min-height:96px` เลื่อนในตัวเอง. verified วัด DOM ที่ 1280×800: itemsH 108→477px, ปุ่มบันทึกห่างขอบล่างแผง 14px; มือถือ 390 ยัง 108px + shell กลับ flex; ภาพหน้าจอยืนยัน. หมายเหตุ: iPad แนวตั้ง (<1100 ไม่มีแผงข้าง) คงเดิมโดยตั้งใจ; บทเรียน tooling — แผงพรีวิวย่อหลัง PostToolUse hook เปิดไฟล์ → ภาพหน้าจอเพี้ยน/พิกัดคลิกเพี้ยนทั้งที่ DOM ถูก ให้เชื่อ getComputedStyle+getBoundingClientRect แล้วเก็บภาพทีหลัง)
v3.7.369 (2026-07-22 — **ชั้น UI จอใหญ่ (iPad/คอมพิวเตอร์) ทั้งแอป** — CSS overlay ล้วนตามไอดิออมธีม fb + className โครงสร้าง POS 5 จุด (`pv-pos-shell/head/tabs/body/cart`), **มือถือไม่โดนแตะ** (ทุกกฎใต้ `min-width:700 + min-height:520` หรือ `hover+pointer:fine`; ยืนยันจาก DOM: กริดขายมือถือยัง 3 คอลัมน์): เวที backdrop ไล่สีจาก `--pv-primary` ผ่าน `color-mix` (ตามธีมอัตโนมัติ ทั้งเขียว+fb), ชีต/โมดัล 600→720 + ชีตแปะขอบล่าง→กล่องกลางจอมุมโค้ง 22 + เงา, POS เป็นหน้าต่างลอย (≥900: กว้าง 920 + กริดสินค้า/โต๊ะ 3→4 คอลัมน์ — เฉพาะ `repeat(3,1fr)+gap:10px` ใน shell, กริดเลข vmoto gap:6 กับแถวสถิติ `'1fr 1fr 1fr'` ไม่โดน), **≥1100: หน้าขายสองคอลัมน์ สินค้าซ้าย-ตะกร้าขวา 400px ด้วย `:has(>.pv-pos-cart)`** (เบราว์เซอร์ไม่มี :has → คอลัมน์เดียวกว้าง งามเหมือนกัน; แท็บอื่น shell กลับคอลัมน์เดียวอัตโนมัติ), hover ปุ่ม/การ์ดเฉพาะเมาส์. verified ในพรีวิว ?demo=1: 1280/768×1024/390×844 + ธีม fb + เทียบ prod 368 ที่ 390px. หมายเหตุ: จอแชต AI เต็มจอกว้างบนเดสก์ท็อป — ใช้ได้แต่ยังไม่ได้จัดเป็นคอลัมน์ ไว้ค่อยเก็บ)
v3.7.306 (2026-07-17 — **เมนูลูกค้า QR รวม ร้อน/เย็น/ปั่น เป็น tile เดียว + แผงเลือก** เหมือนหน้าขาย; ย้าย varBase/groupShown ขึ้น module scope แชร์ 2 คอมโพเนนต์. verified e2e กับข้อมูลจริงร้าน vmotolaos)
v3.7.305 (2026-07-17 — **หน้าขาย POS รวมสินค้า ร้อน/เย็น/ปั่น (ชื่อฐานเดียวกัน) เป็น tile เดียว** → แตะแล้ว bottom sheet เลือกแบบ (คำแบบดึงจาก I18N runtime ไม่ hardcode); การแสดงผลล้วน เส้นทางเงินไม่แตะ)
v3.7.304 (2026-07-17 — ช่องต้นทุนต่อแบบ ร้อน/เย็น/ปั่น ในฟอร์มเพิ่มสินค้า (ว่าง=ใช้ต้นทุนหลัก))
v3.7.303 (2026-07-17 — **ฟอร์มเพิ่มสินค้า: ติ๊ก ร้อน/เย็น/ปั่น + ราคาต่อแบบ → บันทึกครั้งเดียวสร้างสินค้าแยกต่อแบบ** (จงใจเป็นสินค้าปกติหลายตัว ไม่ทำกลไก variant — cart/สต็อก/ใบเสร็จ/QR ผูก productId เดี่ยวทั้งระบบ); i18n pos_var_* ×4; **บั๊กที่เจอ: เกต canSaveProduct บังคับราคาหลัก → แก้กติกาเดียวกับ submitProduct**)
v3.7.302 (2026-07-16 — พิลล์ยี่ห้อใน vmoto editor: กดสลับต้องยืนยัน "แน่ใจหรือยัง..." (askConfirm); กดพิลล์เดิมไม่ถาม)
v3.7.301 (2026-07-16 — **รูป 360° vmoto อัปเป็น WebP** (โปร่งใสรอด + เล็กกว่า JPEG); เบราว์เซอร์ทำ webp ไม่ได้ → เติมพื้นขาว+JPEG. root cause พื้นดำ: JPEG ไม่มี alpha. รูปเก่าต้องอัปใหม่)
v3.7.300 (2026-07-16 — ปุ่มลบทั้ง 5 ใน vmoto editor (ยี่ห้อ/รุ่น/สี/รูป/โลโก้) ต้อง askConfirm ก่อน danger:true)
v3.7.299 (2026-07-16 — **ปิด silent fallback ใน vmLoad หลัง incident sales_cfg โดนทับ** (กู้จาก backup แล้ว): โหลด error → โชว์ error+ลองใหม่ ไม่ render ปุ่มบันทึก)
v3.7.298 (2026-07-16 — ช่องชื่อสีใน vmoto editor แปลอัตโนมัติ 4 ภาษา (dictionary 13 สี ในตัว; คำลาว verified 3 ทาง); คำนอกลิสต์ copy เหมือนกันทุกภาษา)
v3.7.297 (2026-07-16 — ช่องชื่อ (ยี่ห้อ/รุ่น/สี) ใน vmoto editor พิมพ์แล้วทับทุกภาษา (proper noun); desc ยังแยกภาษา)
v3.7.296 (2026-07-16 — **vmoto sales page หลายยี่ห้อ**: editor มีแถบเลือกยี่ห้อ+เพิ่ม/ลบ, sales_cfg → {brands:[...]} (backward-compat flat เดิม); ฝั่งหน้าเว็บ vmoto-citi แถบสลับยี่ห้อบนสุด)
v3.7.289-295 (2026-07-14/15 — vmoto sales-page CMS ครบชุดใน POS settings ร้าน vmoto: รุ่น/สเปก/ราคา (เพิ่ม-ลบ-ซ่อนรุ่น-ซ่อนสเปกรายช่อง) + มัดจำ/บัญชี + โปรโม + สี/รูป 360° อัป Supabase Storage (bucket vmoto, RLS ต่อร้าน) + โลโก้ hero (PNG); ตาราง sales_cfg + RPC vmoto_public_cfg + storage migration ใน tools/migrations/)
v3.7.288 (2026-07-13 — **แก้ sw.js activate ลบ cache ของแอปอื่นทั้ง origin**: เดิม `k !== CACHE ? caches.delete(k)` กวาดทุก cache key บน origin — CacheStorage เป็นของทั้ง origin (parme.me) ไม่ใช่ของ SW scope → ถ้ามี PWA อื่น deploy ใต้ parme.me (เช่น borisat/vmoto) จะโดนลบ offline shell ทุกครั้งที่ paruay activate. แก้: เพิ่ม `CACHE_PREFIX='paruay-shell-'` + ลบเฉพาะ key ที่ขึ้นต้น prefix (sw.js header v2→v3). **verified fail→pass ในพรีวิว**: ก่อนแก้ activate ลบ `borisat-shell-1` จริง; หลังแก้ `borisat-shell-1` รอด + `paruay-shell-vOLD`/เวอร์ชันเก่าถูกลบถูกต้อง + ทดสอบ offline จริง (หยุด server แล้ว reload — แอปเปิดจาก cache ได้เต็มหน้า). **ยังไม่ deploy** — รอเจ้าของยืนยัน; ⚠️ deploy ครั้งนี้ต้อง rsync **sw.js ด้วย** ไม่ใช่แค่ index.html. หมายเหตุ: ไฟล์งานตอนเริ่มอยู่ที่ v3.7.287 แล้ว (287 และก่อนหน้าเป็นงานค้าง session อื่น ยังไม่ถูกจด))
v3.7.285 (2026-07-11 — **ปุ่มดาวน์โหลดคีย์บอร์ดลาว (APK) ใน AdminDashboard**: ปุ่ม `<a href='/laokeyboard.apk' download>` ใน toolbar ข้างปุ่ม Export CSV (แสดงทุก tab, สไตล์เดียวกันแต่พื้นเขียว #1B4332) + i18n key ใหม่ `admin_download_laokb` ครบ 4 ภาษา. ไฟล์ APK อัปโหลดที่ VPS `/docker/parme-prod/html/laokeyboard.apk` (861KB, debug-signed จากโปรเจกต์ `~/laokeyboard` — คีย์บอร์ดลาว IME + voice typing แยกต่างหาก). **ปุ่มเห็นเฉพาะ admin แต่ตัวไฟล์เป็น static URL สาธารณะ** (ใครมีลิงก์โหลดได้ — ไม่ sensitive). nginx เสิร์ฟเป็น application/octet-stream (ไม่มี apk ใน mime.types — Android ติดตั้งได้ปกติ ไม่ได้แก้ nginx). verified หลัง deploy: live = v3.7.285, APK 200/861564 bytes, key อยู่ใน HTML live ครบ 5 จุด. **หมายเหตุ: บันทึก v3.7.271-284 ยังไม่ถูกจดโดย session ที่ทำ (ไม่ใช่งานรอบนี้) + repo ยังไม่ commit ตั้งแต่ v3.7.267 — รอบนี้จงใจไม่ commit เพื่อไม่พัดงานค้างของ session อื่นเข้า commit**)
v3.7.270 (2026-07-09 — เจ้าของเลือก routing เสียง: **ลาว→Gemini, ไทย/อังกฤษ/จีน→เอนจินในเครื่องฟรีเท่านั้น (ไม่วิ่ง Gemini)**. verified ทดสอบจริงบน VPS: Whisper self-host ลาวแย่ (ออกอักษรไทย/เวียดนาม คำเพี้ยน ช้า 8-15s) ส่วน Gemini ลาวออกอักษรลาวถูก → ลาวคง Gemini. แก้ startAiVoice: (1) ลาว + (iOS หรือไม่มี SR) → Gemini เลย (Apple ไม่มีลาว); ลาว + Android/desktop-Chrome → ลอง Web Speech ก่อน (Google ทำลาวได้ฟรี) แล้ว onerror→Gemini. (2) ไทย/en/zh: Web Speech ฟรี; ที่เครื่องทำไม่ได้ (iOS เพิ่มหน้าโฮม บล็อก / no SR) → toast บอกใช้ **ไมค์บนคีย์บอร์ด** (ฟรี) ไม่ fallback Gemini. **ผลข้างเคียงที่ต้องรู้: ไทยบน iPhone-เพิ่มหน้าโฮม ปุ่ม 🎤 ในแอปกดแล้วขึ้นฮินต์ให้ใช้ไมค์คีย์บอร์ดแทน (กดตรงๆไม่ถอดให้)** — ถ้าอยากให้กดแล้วทำงานเลยต้องยอมให้ fallback Gemini (~เศษสตางค์). ยังไม่ verify บน iOS/Android จริง (ไม่มีเครื่อง))
v3.7.269 (2026-07-09 — เจ้าของถาม "ทำ iPhone ให้ฟรีเหมือน Android (in-browser) ได้ไหม". **verified via websearch: iOS บล็อก webkitSpeechRecognition ใน standalone PWA (เพิ่มหน้าโฮม) — WebKit โยน error ทันทีไม่ขอไมค์; ทำงานได้เฉพาะเปิดใน Safari แท็บปกติ** (Apple limit แก้ด้วยโค้ดไม่ได้). แก้ startAiVoice: routing ใหม่ = ใช้ Web Speech (ฟรี) บน Android/desktop/**iOS-Safari-แท็บ**; เฉพาะ **iOS standalone PWA → server (Gemini)**. detect ด้วย navigator.standalone \|\| matchMedia('(display-mode:standalone)'). + onerror('language-not-supported'/'service-not-allowed'/'network')→ตกไป server (เช่นลาวบน iOS ที่เครื่องถอดไม่ได้). **ยังไม่ verify บน iOS จริง (ไม่มีเครื่อง)**. หมายเหตุกรอบใหญ่: Gemini เป็น free tier อยู่แล้ว (ไม่เสียเงิน) — โควตาหมดเมื่อวานเพราะผมเทสต์เอง ไม่ใช่ค่าใช้จ่ายปกติ)
v3.7.268 (2026-07-09 — เจ้าของรายงาน "ถอดเสียงมั่ว" หลังสลับหลักเป็น 3-flash-preview: ตรวจแล้วพบ **โควตา free tier ของวันหมด** (429 ทั้งสองโมเดล — จากการทดสอบ perf หลายสิบ call วันเดียว) ซ้อนกับ preview ที่ยังไม่พิสูจน์กับเสียงจริง. แก้: (1) **สลับหลักกลับ `gemini-2.5-flash`** (ตัวที่เจ้าของยืนยันกับเสียงจริงแล้ว) 3-flash เหลือเป็น fallback, (2) client: 429/all_models_failed → toast "โควตาเสียง AI วันนี้เต็ม" แทน "ฟังไม่ชัด" (เดิมหลอกให้ลองซ้ำ). **โควตารีเซ็ต ~14:00 ICT (เที่ยงคืน Pacific)**; ใช้จริงจัง scale ต้องเปิด billing GCP. ยังไม่ verify: คุณภาพ 3-flash กับเสียงจริง (เทียบไม่ได้จนโควตากลับ))
v3.7.267 (2026-07-09 — **ผู้ช่วย AI: iPhone ใช้เอนจิน Google ถอดเสียง**. iPhone เลือกเอนจิน Web Speech ไม่ได้ (WebKit บังคับ Apple/Siri — พังใน PWA + ไม่มีภาษาลาว) → เพิ่มเส้นทางอัดเสียง: iOS (หรือเครื่องไม่มี SR) กด 🎤 = MediaRecorder อัด (กดซ้ำ ⏹ หยุด, auto-stop 30s) → base64 → **edge fn ใหม่ `transcribe`** (`supabase/functions/transcribe/`) → Gemini `gemini-2.5-flash` (env GEMINI_MODEL override ได้) ถอดตรงตัว → เติมช่องพิมพ์. Android/desktop ใช้ Web Speech เดิม (Google engine ฟรีอยู่แล้ว). state aiVoice: false|'listen'|'rec'|'stt'. mime normalize mp4→aac ฝั่ง fn. **GEMINI_API_KEY ใส่แล้ว LIVE (2026-07-09)** — key จาก AI Studio บัญชี mahudone (Free tier, project gen-lang-client-0998319342; หมายเหตุ: key format ใหม่ของ Google ขึ้นต้น `AQ.` ไม่ใช่ `AIza`; key โผล่ในแชตแล้ว rotate ได้ที่ aistudio → ใส่ .env → restart functions). **e2e verified:** เสียงพูดไทยจริง (AAC/m4a แบบ iPhone) → `{ok:true,text:"บันทึกค่ากาแฟ 25,000"}` ถูกเป๊ะ; anon → 401. **perf fix (เจ้าของทักช้ามาก):** Gemini 2.5 เปิด thinking เป็น default → วัดจริง ~48s/ครั้ง; เพิ่ม `thinkingConfig:{thinkingBudget:0}` → ~2.5-3.5s. **รอบสอง (เจ้าของถามเร็วกว่านี้ได้ไหม):** สลับหลักเป็น `gemini-3-flash-preview` (วัด ~2-2.5s + ถอดครบกว่า — ได้คำ "กีบ" ที่ 2.5 ตัด) + **per-model timeout [12s,25s] + auto-fallback → 2.5-flash** (เจอจริง: preview ค้าง 58s → Kong ตัดเป็น 500 1/3 รอบ; หลังแก้ = แย่สุด ~15s ไม่มี 500; พิสูจน์ fallback ด้วย bogus model แล้ว). อย่าใช้ flash-lite (ตัดคำหาย); 2.0-flash โดน 429 บน free tier (ไม่มีโควตา). **ข้อจำกัดที่เหลือ = free tier rate limit**: ยิงถี่ (ทดสอบ 8 รอบติด) ชน 429 ทั้งสอง model → client เห็น "ฟังไม่ชัด"; ใช้จริงเว้นช่วงปกติไม่ชน แต่ถ้าผู้ใช้เยอะ/บ่อยต้องเปิด billing GCP (ถูกมาก ~$0.001/ครั้ง). เหลือทดสอบ iPhone จริงโดยเจ้าของ)
v3.7.266 (2026-07-09 — แก้ settings footer โชว์ "vv3.7.265": L24576 ต่อสตริง `"… · v", APP_VERSION` แต่ APP_VERSION มี 'v' อยู่แล้ว → ลบ 'v' ในสตริง. ตรวจ class ทั้งไฟล์: จุดต่อ APP_VERSION อื่น (8888/20024/22267) ถูกอยู่แล้ว; `sw.js?v=`+APP_VERSION (36706) เป็น cache-bust query param ไม่ใช่จอแสดงผล — ไม่แตะ. verified ใน demo: เปิด settings modal → footer = "Parme · ພາme · v3.7.266")
v3.7.265 (2026-07-09 — **window.confirm() → styled ConfirmDialog ครบ 12 จุด** (ปิดงานค้างจาก v3.7.264): component กลางใหม่ `ConfirmDialog` (~L8260, ก่อน AdminDashboard) หน้าตา/พฤติกรรมเดียวกับ askConfirm modal ของ POS (ครีม #FBF6E9, ปุ่ม danger #AA3C28 / ปกติ #1B4332, modalFade, zIndex 10080 เหนือ settings modal 9999) + รองรับ `\n` ใน message (pre-line, ใช้กับ admin ban โชว์ email). caller ถือ state เอง 3 component: **Paruay** ×9 (เพื่อนลบ/ทริปปิด-ออก-settle×2-ยกเลิกคำขอ/reset settings/ลบทั้งหมด/ปิดบัญชีเงินกู้, mount ท้าย main return, lang ใน scope นี้คือ `settings.lang` ไม่ใช่ `lang`!), **FamilyScreen** ×2 (ออกกลุ่ม/ลบ tx, mount เฉพาะ detail return @~12234 — list return @~11458 ไม่มีจุดเรียก), **AdminDashboard** ×1 (ban/unban, confirmLabel=t.admin_ban/unban). ทุกจุด refactor sync→callback ทีละจุด (caller ทั้งหมดเป็น onClick ไม่มีใคร await). ปุ่มยืนยันใช้ i18n key เดิมทั้งหมด (pos_leave/pos_remove/reset_defaults_cta/delete_all_cta) ไม่เพิ่ม key ใหม่. **verified ใน demo:** reset settings (cancel+confirm→toast), delete-all (dialog+cancel), loan ปิดบัญชี (confirm→status paid). **ยังไม่ verified บนเครื่องจริง:** admin ban, family ออก/ลบ tx, ลบเพื่อน, ทริป 5 จุด (demo ไม่มีข้อมูล cloud — transform เหมือนกันทุกจุด + ตรวจ depth ของ mount ด้วย paren-counter แล้ว). พบ bug เดิมนอกขอบเขต: settings footer โชว์ "vv3.7.265" (L24576 ต่อ 'v'+APP_VERSION ซ้อน) — ยังไม่แก้)
v3.7.264 (2026-07-09 — **UI/pop-up sweep**: หน้าลูกค้า QR เลิกใช้ native alert() ทั้ง 3 จุด (สลิปใหญ่เกิน / ส่งออเดอร์ไม่สำเร็จ / เรียกพนักงานไม่สำเร็จ) → toast pill เข้าธีม (state qMsg+qToast, style เดียวกับ pill หลักแอป v3.7.259). ตรวจ pop-up in-app แล้ว (modal รายรับ-จ่าย/POS/QR modal/toast) สวยเข้าธีมอยู่แล้ว. **ค้าง: window.confirm() 12 จุด** (destructive actions ทั้งหมด — ลบบัญชี/ลบทั้งหมด/ออกกลุ่ม/ปิดทริป/ลบ tx/mark loan) ยังเป็นกล่องระบบดิบ → งานแยก: refactor sync→async ทีละจุด + verify ต่อ flow ก่อน deploy (ห้าม bulk))
v3.7.263 (2026-07-09 — **POS QR session-token**: เช็คบิลสำเร็จ → หมุน token โต๊ะนั้นทันที (QR เก่าตาย กันลูกค้าเก่าสั่งปนใหม่); staff โชว์ QR ใหม่จากในแอป (ไม่ใช้สติกเกอร์). server: `qr_order_allowed` +arg token (RLS เช็ค dinein token=table_tokens[โต๊ะ] ปัจจุบัน; ALTER POLICY atomic), RPC `set_table_token` (per-key jsonb merge, staff-only via is_pos_staff — กัน 2 เครื่องเขียนทับกันทั้งก้อน). client: rotate ตอน completeSale + move/merge(src) + ปุ่ม "สร้าง QR ใหม่" + mount-sync per-key union + genTok crypto8 + จอ "QR หมดอายุ" ตอน insert โดน RLS reject. SQL: tools/migrations/2026-07-09-qr-session-token.sql. **P0 verified:** anon อ่าน table_tokens ไม่ได้ (pos_shops_sel=owner/member). ผ่าน adversarial review 3-lens ก่อนลง + e2e (token เก่า→block, ใหม่→ผ่าน, merge ไม่ทับ, remote ไม่กระทบ). **client interactive UI (modal/rotate/expired) ยังต้อง test บนเครื่อง login จริง**)
v3.7.262 (2026-07-09 — เปลี่ยนป้ายปุ่ม AI จาก "ถามผู้ช่วย AI" → "ผู้ช่วย AI" (เอา verb ออกทั้ง 4 ภาษา: ຜູ້ຊ່ວຍ AI / ผู้ช่วย AI / AI assistant / AI助手))
v3.7.261 (2026-07-09 — เอาปุ่ม "🎤 เว้าบันทึก" (voice-add) ออกจากหน้าหลัก เพราะปุ่ม 🤖 AI ครอบหน้าที่นี้แล้ว (มีไมค์+สั่งเพิ่มด้วยภาษาธรรมชาติ). ลบเฉพาะ element ปุ่ม; โค้ด voice ที่เหลือ (startVoiceAdd/parseVoice/overlay/undo/state) กลายเป็น dead code ยังไม่ลบ (`voiceLangCode` ยังใช้อยู่โดย AI mic — อย่าลบ). ถ้าจะ purge dead voice code ค่อยทำแยก)
v3.7.260 (2026-07-08 — **AI CHAT AGENT**: ห้องแชท "🤖 ถามผู้ช่วย AI" หน้าหลัก ต่อยอดจาก voice. edge fn ใหม่ `assistant` (`supabase/functions/assistant/`, sonnet-5, **tool-use loop รันฝั่ง server**) — ตอบเรื่องเงิน (get_balance/summarize/search คำนวณจาก snapshot ที่ client ส่ง, edge fn ไม่แตะ DB) + เพิ่มรายรับ-รายจ่าย (add_transaction คืน adds[], **client persist เองใต้ RLS** + undo). auth gate role==='authenticated'. deploy: scp → `/docker/supabase/docker/volumes/functions/assistant/` + `docker compose up -d --wait functions`. เลข AI ตรงกับแอป (get_balance ใช้ stats.bal). cost สูงกว่า parse-expense (หลาย call/คำถาม))
v3.7.258 (2026-07-04 — แก้ login error message: อ่าน error จาก fErr.context (supabase-js invoke โยนเมื่อ non-2xx) — เดิม branch เป็น dead code โชว์ generic)

## Workflow การแก้โค้ด (สำคัญมาก)

> 🛠️ **มี helper scripts ใน `tools/` แล้ว** (ใช้แทนขั้นตอนมือด้านล่าง — ปลอดภัยกว่า):
> - `python3 tools/bump.py 3.7.xx` — bump ครบ 4 จุด อัตโนมัติ (assert จุดละ 1 ครั้งก่อนเขียน, ไม่แตะ comment ประวัติ; มี `--dry` ดูก่อนได้)
> - `python3 tools/check.py` — แยก block หลัก (ที่มี `APP_VERSION`) แล้วรัน `node --check` ให้เลย
> - `bash tools/release.sh 3.7.xx "สรุปสั้น"` — bump → check → โชว์คำสั่ง commit/push (ไม่ push ให้เอง)
> ขั้นตอนมือด้านล่างเก็บไว้เป็นเอกสารอ้างอิง/fallback ถ้า script มีปัญหา

### 1. Version bump — แก้ครบ **4 จุด** ทุกครั้งที่ release
แนะนำ: `python3 tools/bump.py 3.7.xx` (จัดการให้ครบ + ปลอดภัย). ถ้าทำมือ:
ก่อนแก้ให้ `grep -n` หาเลขบรรทัดสดเสมอ (เลขบรรทัดขยับได้):
```
grep -n "v3\.7\.35" index.html
```
จุดที่ต้องแก้ (ตำแหน่งโดยประมาณ):
1. `<title>ພາລວຍ · Paruay v3.7.xx</title>` (~บรรทัด 6)
2. `<meta name="app-version" content="v3.7.xx" />` (~บรรทัด 8)
3. `<div class="version-tag">v3.7.xx</div>` (~บรรทัด 872)
4. `const APP_VERSION = 'v3.7.xx';` (~บรรทัด 3753)

⚠️ ระวัง comment ประวัติ เช่น `// v3.7.34 — ...` กระจายอยู่ในโค้ด — **ห้ามนับรวม** ตอน bump ให้แก้เฉพาะ 4 จุด canonical ข้างบน

### 2. ตรวจ syntax หลังแก้ทุกครั้ง
แนะนำ: `python3 tools/check.py`. (กลไกข้างใต้: `index.html` มี `<script>` ~8 blocks; block หลักของแอป
ที่มี logic ทั้งหมดคือ block ที่มี `APP_VERSION` ขนาด ~1.6MB — script แยก block นั้นออกมารัน `node --check` ให้)
หลังแก้โค้ดต้องผ่าน `node --check` ก่อน commit เสมอ

ตัวอย่างสคริปต์แยก + เช็ก (Python):
```python
import io
src = io.open('index.html', encoding='utf-8').read()
idx = 0
while True:
    s = src.find('<script', idx)
    if s == -1: break
    gt = src.find('>', s); e = src.find('</script>', gt)
    c = src[gt+1:e]
    if 'APP_VERSION' in c:   # block หลักของแอป
        io.open('/tmp/app.js', 'w', encoding='utf-8').write(c)
    idx = e + 9
```
แล้ว `node --check /tmp/app.js`

### 3. การแก้ string — assert ก่อนเขียนเสมอ
ก่อน replace ให้นับจำนวน occurrence ให้ตรงตามคาด ป้องกันแก้ผิดจุด (ไฟล์ใหญ่ string ซ้ำได้ง่าย) ใช้ Edit tool ของ Claude Code โดยใส่ context รอบ ๆ ให้ unique หรือถ้าแก้หลายจุดพร้อมกันใช้ Python heredoc ที่ assert count ก่อน

### 4. Deploy (v3.7.249+ — prod อยู่บน VPS แล้ว)
prod ตัวจริงคือ nginx บน VPS — **push GitHub อย่างเดียวไม่ deploy แล้ว** ต้อง rsync ด้วย:
```
# 1) deploy จริง (VPS)
rsync -e "ssh -i ~/.ssh/hostinger_vps_ed25519" -av ~/paruay/index.html root@187.127.209.83:/docker/parme-prod/html/index.html
# 2) verify
curl -s https://parme.me/ | grep -o 'app-version" content="[^"]*'
# 3) เก็บ repo ให้ตรง prod (+GitHub Pages fallback)
git add -A && git commit -m "v3.7.xx — <สรุปสั้น>" && git push
```
nginx ส่ง `Cache-Control: no-cache` ให้ HTML/sw.js แล้ว (ตั้งใน `/docker/parme-prod/default.conf` 2026-07-04) → ผู้ใช้ได้เวอร์ชันใหม่ตอนเปิดแอปรอบถัดไป. ถ้าแก้ schema DB → รัน SQL บน VPS (`docker exec supabase-db psql -U postgres`) + เก็บไฟล์ใน `tools/migrations/` + **อย่าลืม `NOTIFY pgrst, 'reload schema';`** ไม่งั้น PostgREST ไม่รู้จักคอลัมน์ใหม่

## โครงสร้าง Supabase (ตารางหลัก)
ฝั่งการเงิน: `user_settings` (มี `fx_manual` jsonb สำหรับ FX override sync), `families`, `family_transactions`, `family_members`, `family_messages`, `family_ious`
ฝั่ง POS: `pos_products` (มี `sort`, `station`), `pos_categories` (มี `station`), `pos_sales` (มี `table_no`, `sub_total`, `discount`, `svc`, `svc_pct`), `pos_shops` (มี `table_tokens`, `seeded`), `pos_qr_orders`, `pos_open_bills`

⚠️ การเพิ่ม column ต้องรัน SQL ใน Supabase เอง (M รันเอง) ใช้ `ADD COLUMN IF NOT EXISTS` เสมอเพื่อความปลอดภัย

## ระบบ FX (สรุปจากงานล่าสุด v3.7.35)
- auto-rate เป็น **kip-based** (กีบต่อ 1 หน่วย) ดึงจาก jsDelivr/er-api
- `fxKipPerUnit(st, sym, codeHint)` → กีบต่อหน่วย
- `fxToPrimary(st, sym, codeHint, primarySym, primaryCodeHint)` → **สกุลหลักต่อหน่วย** (ใช้กีบเป็นสะพาน) ถ้าสกุลหลัก = กีบ จะได้ผลเท่า fxKipPerUnit เป๊ะ
- กราฟใช้คอลัมน์ `fxk_<sym>` = ค่าที่แปลงเป็นสกุลหลักแล้ว, tooltip แสดง `≈ CUR fmt(...)`

## Demo mode (v3.7.88+) — เปิด UI หลัง login ได้โดยไม่ต้องล็อกอินจริง
เพิ่ม `?demo=1` ใน URL → bypass Supabase auth + seed localStorage (7 transactions + 2 IOUs) → เปิดหน้าหลัก/รายงาน/Family/POS ในพรีวิวได้เลย ไม่กระทบ Supabase production. กลไก: `__fakeSupabase` stub (chainable .from() คืน empty array) + `__DEMO__` ตรวจ URL + early-return ใน auth useEffect + loadCloudData. ใช้สำหรับ Claude ตรวจ UI/UX bug ในพรีวิวก่อน deploy.

## ⚠️ ต้องรัน SQL (v3.7.98–99) — POS ลูกค้าเชื่อ + วิธีจ่าย
1. `tools/migrations/2026-06-17-pos-customer-credit.sql` — เพิ่มคอลัมน์ `paid`/`customer`/`settled_at` ใน `pos_sales`. **สำคัญ:** client v3.7.98+ ส่ง 3 คอลัมน์นี้ในทุก upsert ของการขาย → ถ้ายังไม่รัน SQL การ sync ขายขึ้น cloud จะ fail เงียบ ๆ (try/catch — ข้อมูลไม่หาย เซฟ local ปกติ แต่ไม่ขึ้นเครื่องอื่นจนกว่าจะรัน SQL). ฟีเจอร์ "ลงเชื่อ" verified ใน demo แล้ว (create→panel→settle ครบ).
2. `tools/migrations/2026-06-17-pos-payment-method.sql` — เพิ่มคอลัมน์ `payment` (text = cash/transfer/null) ใน `pos_sales`. client v3.7.99+ ส่ง `payment` ทุก upsert → เหตุผลเดียวกับข้อ 1 (ต้องรันคู่กัน). ฟีเจอร์ "ระบุวิธีจ่าย" เปิด/ปิดได้ในตั้งค่า POS (toggle เก็บ localStorage `paruay_pos_pay_mode`); ปิดอยู่ → `payment` = null. verified ใน demo (เปิด toggle → ขาย→chooser→cash/transfer → report แยกชิป 💵 เງິນສົດ / 📱 ໂอน).

## POS Tier 1 (เสริมร้าน POS — จาก audit)
- ✅ **#1 ลูกค้าเชื่อ** (v3.7.98) — ดู section "ต้องรัน SQL" ด้านบน
- ✅ **#2 ระบุวิธีจ่าย เงินสด/โอน + toggle** (v3.7.99) — ดู section "ต้องรัน SQL" ด้านบน
- ✅ **#3 Export CSV** (v3.7.100) — **client ล้วน ไม่แตะ DB ไม่ต้องรัน SQL**. ปุ่ม 📤 ในแถบ range ของ PosReport → ดึงบิลตามช่วงที่เลือก (วัน/เดือน/ปี/ทั้งหมด) เป็น CSV. 1 แถว/บิล, 15 คอลัมน์ (วันที่/เวลา/รหัสบิล/โต๊ะ/รายการ/ยอดย่อย/ส่วนลด/ค่าบริการ/รวม/ต้นทุน/กำไร/การจ่าย/สถานะ/ลูกค้า/ผู้ขาย). มี BOM (Excel อ่าน Lao/Thai ได้), CSV-injection guard (=+-@ → prefix '), RFC-4180 escaping, CRLF, ตัวเลขดิบ (ไม่ใช้ fmt). iOS: ลอง `navigator.share({files})` ก่อน → fallback `<a download>`. ใช้ inline `T()` ล้วน (PosReport ไม่มี `t` ใน scope). helper `exportCsv`/`filtRows`/`csvCols` อยู่ใน PosReport (~L30075). verified ใน demo (จับ blob จริง: header ลาวถูกครบ + escaping ผ่าน adversarial name `=Boon, "VIP"`).
- ✅ **#1b ลูกค้าเชื่อ — กดดูรายบิล + แก้ไข** (v3.7.101) — **client ล้วน ไม่ต้องรัน SQL** (reuse คอลัมน์ paid/settled_at เดิม). แตะแถวลูกค้าในการ์ด `ລູກຄ້າເຊື່ອ` (มี chevron ›) → bottom-sheet (zIndex 500) โชว์บิลค้างรายใบ (วันเวลา + รายการ + ยอด). ต่อบิล: **✓ ຮັບເງິນ** = settle เฉพาะบิลนั้น (จ่ายบางส่วน — fn ใหม่ `posSettleCreditBill(saleId)` mirror `posSettleCredit` **ไม่เรียก applyTotalsDelta** เพราะ rev นับ unpaid อยู่แล้ว → settle ไม่ขยับรายได้ แค่ Owed ลด), **✏️ ແກ້ໄຂ** = ดูข้อ #1c, **🗑️ ລຶບ** = two-tap confirm (ไม่มี askConfirm/showToast ใน PosReport) → `posDeleteSale` (ลบคืน stock + reverse totals → รายได้ลด). settle/delete บิลสุดท้าย → useEffect auto-close sheet. edit/delete gate ด้วย `amOwner`; settle ไม่ gate. verified ใน demo ครบ.
- ✅ **#1c แก้บิลเชื่อในหน้าขาย** (v3.7.102) — **client ล้วน ไม่ต้องรัน SQL**. กด ✏️ ในแผ่นรายละเอียด → ปิดแผ่น แล้ว `onEditBill(saleId)` (ใน POSModal) สร้าง **บิลชั่วคราว** `{name:'__edit__', table:null}` โหลด items→cart map (กรอง productId ที่มีจริง, นับ `editDropped` ที่หาย=สินค้าถูกลบ) → `setActiveBillId` + `setTab('sell')`. หน้าขายโหมดแก้: bill-chips strip ถูกแทนด้วย **banner "ກຳລັງແກ້ໄຂບິນ"** (+ ⚠️ ถ้า editDropped>0) + ปุ่มยกเลิก; แถว checkout เปลี่ยนเป็นปุ่มเดียว **💾 ບັນທຶກການແກ້ໄຂ** (ซ่อนปุ่ม credit + complete → ไม่มีทางสร้างบิลใหม่). `saveEdit` → `onEditSale(saleId,{items, seller:null})` (posEditSale spread `...old` → paid:false/customer/payment/table/createdAt/id คงไว้; seller:null → คง old.seller; ถ้า editDropped>0 askConfirm ก่อน). `exitEdit` ลบบิล `__edit__` + คืน `prevActiveBillId` + `setTab('report')`. bills loader กรอง `__edit__` ออกกัน remount ค้าง. **ข้อจำกัด:** posEditSale คิด total = Σ price×qty (ไม่ re-apply discount/svc เดิม — quirk เดียวกับ modal เก่า) จึงไม่เปิดให้แก้ส่วนลด/โต๊ะในโหมดนี้. verified ใน demo: load→cart, เพิ่มสินค้า→save = 1 บิล 2 รายการ ยังเชื่อ rev ถูก · cancel ไม่กระทบบิล.
- ✅ **#1d รวม edit เป็น `startBillEdit` เดียว** (v3.7.106) — extract logic โหลด-เข้า-ตะกร้าเป็น `startBillEdit(saleId)` ใน POSModal. ทั้ง **ปุ่ม ✏️ ในรายการประวัติบิล** (เดิมเปิด edit modal เล็ก qty-only ที่ `setEditSale`, ~L33086) **และ** onEditBill ของแผ่นลูกค้าเชื่อ เรียก `startBillEdit` ร่วมกัน → แก้บิลไหนก็เด้งหน้าขาย เพิ่ม/แก้สินค้าได้เหมือนกันหมด. edit modal เก่า (editSale ~L33270) กลายเป็น dead code (ไม่มี opener แล้ว — ปล่อยไว้ ไม่ลบ กันเสี่ยง). verified ใน demo: ปุ่มประวัติบิล→หน้าขาย, เพิ่ม Pepsi→save = บิลเดิมอัปเดต Beerlao×2+Pepsi ₭24,000 paid คงไว้ 1 บิล.

## perf — CLS 0.48→0.001 (v3.7.105)
loading screens (`authState==='loading'` ~L17664 + `cloudLoading` ~L18239) เคยใช้ `minHeight:100vh`+`justify-content:center` (โลโก้กลางจอ, อยู่ใน flow). พอ render เปลี่ยนเป็น dashboard React **reuse DOM node** ย้ายโลโก้กลางจอ→บนสุด = เนื้อหากระโดด ~259px = **CLS 0.48 (แดง)**. แก้: ทำ splash เป็น `position:fixed; inset:0` (ออกจาก flow) + `key:'authloading'` (บังคับ unmount สะอาด ไม่ reuse node → dashboard = เนื้อหาใหม่ ไม่ใช่ "ย้าย"). วัดด้วย buffered `layout-shift` PerformanceObserver: 0.4804→0.0013. **LCP ~2.7s บนเครื่องจริงเป็นข้อจำกัดของ single-file 4.2MB (parse+mount) — ไม่แก้ตอนนี้.**

## bugfix สำคัญ — realtime mapSale ตัด paid/customer (v3.7.104)
`mapSale` (~L17166) = mapper สำหรับ **realtime delta-merge** (`mergeRow`) ของ `pos_sales`. เขียนไว้ก่อนมีฟีเจอร์ลูกค้าเชื่อ/วิธีจ่าย → **ไม่มี paid/customer/payment/settled_at**. อาการ: แก้/settle/สร้างบิลเชื่อ → Supabase realtime echo กลับ → `mergeRow`→`mapSale` ตัด paid/customer ทิ้ง → in-memory บิลกลายเป็น paid:undefined → `creditBy` (เช็ก `paid===false`) ไม่นับ → **บิลเชื่อหายจากการ์ดทันทีหลังแก้** จนกว่าจะ refresh (loadShopData mapping เต็ม อ่าน cloud กลับมา). **ไม่เกิดใน demo** เพราะ fake supabase channel เป็น no-op (mergeRow ไม่ทำงาน) — เป็นเหตุผลที่เทสต์ demo ผ่านตลอด. แก้: เติม `paid/customer/payment/settledAt` ใน mapSale ให้ตรงกับ loadShopData (16901). **บทเรียน: เพิ่ม column sale ใหม่ ต้องอัปเดต 3 ที่ — upsert mapping (16846), loadShopData mapping (16901), mapSale realtime mapper (17166).**

## bugfix สำคัญ — empty-cloud overwrite (v3.7.103)
`loadShopData` (~L16877) เคยใช้ `if (prods) setPosProducts(...)` — แต่ `[]` เป็น **truthy** → ถ้า cloud คืน array ว่าง (sync ยังไม่เสร็จ/ล้มเหลว/seed ตอน posShopId ยัง null) จะ**เขียนทับสินค้า local เป็นว่าง** = สินค้า/บิลหายหลัง refresh (เฉพาะตอนล็อกอิน+มีร้าน; เส้นทางไม่มีร้านปลอดภัยเพราะ loadShopData ไม่รัน). แก้: `if (prods && prods.length)` กับ **products + categories + sales** (cloud ว่าง = ไม่ลบ local). ⚠️ ทดสอบ demo ไม่ได้ (ไม่มีร้าน) — verify เครื่องจริง. **เหลือ:** ถ้า cloud ไม่ว่างแต่ขาดบิลที่ sync ไม่ขึ้น (เช่นยังไม่รัน SQL credit/payment → upsert fail) ก็ยังโดนทับได้ → ทางแก้คือรัน SQL ให้ครบ.

## v3.7.249 (2026-07-04) — audit ใหญ่ 4 agents + ซ่อมยกชุด
**ซ่อมแล้ว (deploy บน VPS แล้ว):**
- **dead writes 14 จุด** — supabase-js builder ไม่ถูก `await`/`.then` = ไม่ยิง HTTP เลย: sync `pos_ingredients` (ตายสนิททั้ง feature), reset POS wipe cloud, ตั้งค่าร้าน 7 จุด (fifo/stock/table_count/units), ลบ ghost bill `__edit__`. แก้: `.then(r=>{if(r&&r.error)...})` + enqueue สำหรับ ingredients. **บทเรียน: `supabase.from(...)` ต้องมี await/.then เสมอ**
- **offline tx queue** — (a) แก้ไขรายการเก่าตอน offline โดนทับหาย: เพิ่ม pending-edit protection (local ชนะ cloud) ใน poll merge 3 path + loadCloudData, (b) เลิก `txPendingClear()` เหมา, (c) จำกัด re-push local-only เฉพาะ pending∪สร้างใหม่<72ชม. (กัน tx ที่ลบจากเครื่องอื่นคืนชีพ), (d) 'online' event flush คิว POS ด้วย + timer 30s (`window.__paruayFlushTimer` + event `paruay-auto-flush`)
- **timezone** — `todayStr()` เดิม UTC → ก่อน 7 โมงเช้า รายการ/ยอดขายลงวันเมื่อวาน. แก้เป็น local (+รับ Date param) + จุด inline อีก 6 (famDate/dk/ds/todayS/dob max). RPC ฝั่ง DB ใช้ Asia/Bangkok อยู่แล้ว
- **auth watchdog** — session มาช้ากว่า 6s watchdog → token ถูกทิ้ง → realtime ค้าง anon (SUBSCRIBED แต่เงียบ). แก้: early-return branch ยัง setAuth ให้ realtime
- **stale-response guards** — `posShopIdRef` + guard ใน loadShopData/loadPosTotals (สลับร้านเร็ว = ข้อมูลข้ามร้าน), double-tap guard `completeRemoteSale`, recipe-type ไม่คืน product stock ตอน void/edit, `computeShares` โยนเศษปัดให้แชร์ใหญ่สุด (Σ = ยอดจริง)
- **linkedTxId round-trip** — คอลัมน์ใหม่ `pos_sales.linked_tx_id` (SQL: `tools/migrations/2026-07-04-pos-sales-linked-tx.sql`, รันบน VPS แล้ว + NOTIFY pgrst) + ใส่ครบ 4 mappers → ลบ/แก้บิลที่ผูกรายรับ ตามไปจัดการ tx ถูกแล้ว (เดิมค่าอยู่แค่ local โดน sync ทับหาย = ยอดค้างเกิน)
- **dead code ~293 บรรทัด** — modal แก้บิลเก่า (editSale), goal UI เก่า (bar/goalCard/short/ring/goalRing), orphan states 12 ตัว. `CATALOG_BASE` → `./catalog/` (เดิมชี้ github.io). เหลือ `rotateToken` (อาจเป็นฟีเจอร์อนาคต — ถาม M ก่อนลบ)
- **nginx VPS** — เพิ่ม `Cache-Control: no-cache` ให้ HTML/sw.js (เดิมไม่มี header → heuristic cache → ติดเวอร์ชันเก่า), catalog 7 วัน

## v3.7.250 (2026-07-04) — เก็บ follow-up รอบสอง
- **POS เปิดตอน offline ได้แล้ว** — resolve ร้านล้ม (เน็ตล่ม) → กู้จาก `paruay_pos_shops_cache` (เก็บ list+myId+user ทุกครั้งที่ resolve สำเร็จ ได้สิทธิ์ owner ถูกต้อง) + state `posShopDegraded` + auto-retry ตอน 'online' event
- **self-heal สินค้า/หมวด** — push คืน cloud เฉพาะ id ที่ค้างคิว `pendingUpsertIds()` (เดิม push ทุกตัวที่ cloud ไม่มี = ของที่ลบจากเครื่องอื่นคืนชีพ) — local merge ยังคงเดิม
- **แก้บิลเก่าไม่ reprice แล้ว** — `editPriceOv` ใน cartItems: สินค้าที่อยู่ในบิลเดิมใช้ราคา/ต้นทุน "ตามบิล" (จอ+ยอด+เซฟตรงกันหมด) ของเพิ่มใหม่ใช้ราคาปัจจุบัน
- **QR order status** — helper `qrOrderUpdate(id, patch)` retry×3 backoff แทน `.then(()=>{})` ทั้ง 8 จุด (accepted/rejected/done/paid/expired/patch)
- **localStorage เต็ม** — `saveTxStore` fallback เซฟแบบตัดรูปแนบ (รูปอยู่บน cloud row แล้ว) แทนเงียบทั้งก้อน
- **stale guards** — `loadReqRef` (loadDetail: เปิดครอบครัวซ้อน/ปิดแล้วไม่เด้งคืน), `openRef` guard ใน loadPOS, `currentUserIdRef` guard ใน loadCloudData (สลับบัญชีเร็ว)

## v3.7.251 (2026-07-04) — ซ่อม regression จาก self-review (workflow 6-มิติ + adversarial verify)
adversarial self-review ของ diff v3.7.248→250 (demo smoke ไม่ครอบ sync/offline เพราะ fake supabase) เจอ 6 regression **ทั้งหมด medium/low** (qrOrderUpdate scope + dead-code deletion ผ่านสะอาด; editPriceOv โดน refute = ถูกอยู่แล้ว). ซ่อมที่ราก:
- **todayStr แปลง local ไม่ครบ (4 จุด):** v3.7.249 แปลง write-side เป็น local แต่ read-side ยัง UTC → ปนกัน. แก้: POS `date` mappers 3 จุด (17969/18049/18279) → `todayStr(new Date(r.created_at))`; family month-key `mk` (11420) → `todayStr().slice(0,7)`. **บทเรียน: แปลง timezone ต้องแก้ทั้ง write + read + ทุก bucket key พร้อมกัน** (sale.date ของ pos_sales ไม่ persist — derive จาก created_at ทุกครั้งที่โหลด)
- **tx queue race (ราก):** `pushPendingTx` เดิม `txPendingWrite([])` ล้างทั้งก้อนหลัง await → id ที่ persist() append ระหว่าง upsert หลุด = tx ค้างถาวร. แก้: re-read คิวแล้วลบเฉพาะ id ที่ส่งเสร็จ (done=dead∪success) → ปิด race ที่ทำให้ 72h gate ทำ row หาย
- **computeShares orphan:** residual (v3.7.249) โยนเศษให้คนใหญ่สุด แต่ถ้ามี member ถูกถอด (id ยังค้างใน item.memberIds จาก addIouItem ที่ seed allMemIds) จะโยนทั้งก้อน = overcharge debtor. แก้: filter id นอกวงก่อนหาร → per ถูก residual เป็นเศษจริง. **พิสูจน์เชิงตัวเลข node แล้ว 5 เคส** (orphan 90k/2 = 45k/45k ไม่ใช่ 60k)
- **POS degraded iOS:** เพิ่ม visibilitychange fallback (iOS มักไม่ยิง 'online' → กลับมา foreground ก็ re-resolve ร้าน)

## v3.7.252 (2026-07-04) — completeness sweep (critic catch)
หลังซ่อม v3.7.251 ทำ completeness sweep timezone (grep ทุก `slice(0,10)`/`slice(0,7)`/`created_at` ที่เป็น date bucket) → เจอ straggler ที่ review 6-มิติ**พลาด**: **day-chart bucket key** (report กราฟ "มื้/วัน", FamilyScreen ~11651 + Paruay ~21551) ยังสร้าง key ด้วย `d.toISOString().slice(0,10)` = UTC ขณะที่ tx match ด้วย `t2.date` (local หลัง v3.7.249) → tx วันนี้หายจากกราฟช่วง 00:00–07:00 (UTC+7). แก้: `ensure(todayStr(d), ...)`. **week/month/year ปลอดภัยอยู่แล้ว** (key กับ matcher ใช้ transform เดียวกัน — week: `mon().toISOString()` ทั้งคู่; month/year: getFullYear/getMonth local ทั้งคู่). **บทเรียนย้ำ: หลังแปลง timezone ต้อง grep completeness ทุก bucket-key builder เทียบ basis กับตัวที่มัน match — dimension review อาจโฟกัสจุดใหญ่แล้วพลาด bucket ย่อย**

## v3.7.253 (2026-07-04) — Security + money-math audit (workflow 5-มิติ + skeptic verify + live-DB exploit test)
audit มิติที่ยังไม่เคยตรวจ: RLS / SECURITY DEFINER / XSS / family+FX+loan math / POS money. **RLS เปิดครบทุกตาราง, mapper-drift + XSS สะอาด.** เจอ 15 issue (2 critical, 6 high) — **reproduce exploit บน prod จริงก่อนแก้** (test harness node+supabase-js mint JWT):

**✅ อุดแล้ว (DB — apply บน VPS, verify exploit blocked + legit flow works):**
- 🔴 **CRITICAL family_members self-join** — fm_ins policy เช็คแค่ user_id ไม่เช็ค family_id → ใครก็ INSERT เข้าครอบครัวไหนก็ได้ (ไม่ต้องมี code) → เห็น/แก้เงินครอบครัวคนอื่นทั้งหมด. แก้: DROP fm_ins (join ผ่าน create_family/join_family RPC SECURITY DEFINER เท่านั้น). **บทเรียน: exploit ตัวแรก 403 เพราะ `return=representation` (red herring) — insert ปกติ 201 = จริง! ต้องเทสต์หลายรูปแบบ**
- 🟠 **ft_upd** ไม่มี WITH_CHECK → ย้าย tx เข้าครอบครัวคนอื่น. แก้: + WITH CHECK is_family_full
- 🟡 set_family_currency/goals(4,5-arg) is_family_member→is_family_full (POS-only seller เปลี่ยนสกุล/เป้าไม่ได้แล้ว)
- 🟡 pos_sales_totals today_rev UTC→Asia/Bangkok (ตรง client local)
- SQL record: `tools/migrations/2026-07-04-security-rls-secdef.sql`; body ใหม่บน VPS `/docker/sec-func-fixes.sql`; rollback `/docker/backups/rollback-security-20260704.sql`

**✅ อุดแล้ว (client v3.7.253):**
- 🟠 family `inToday` (daily goal) ไม่ filter สกุลเงิน → +isPrimaryTx
- 🟠 posEditSale ลบส่วนลด/svc ตอนแก้บิล → ยอด+รายได้พองเท่าส่วนลด. แก้: คง old.discount/svc/svcPct, total = subTotal−disc+svc (verify: บิล 100k ลด 20k แก้ไม่เปลี่ยน = คง 80k)
- loan-IOU header (low) สรุปยอดไม่รวมดอก ต่างจากแถว → iouOwed() interest-aware

**⚠️ ยังไม่แก้ — ต้องเจ้าของตัดสินใจ/งานใหญ่ (เรียงตามคุ้ม):**
1. ✅ **~~get_email_by_username (high, PII)~~ ปิดสมบูรณ์ 2 phase (v3.7.255→256):**
   - Edge Function `login-username` (`supabase/functions/login-username/`, deploy บน VPS): resolve อีเมลฝั่ง server (service role) → GoTrue `/token` ส่ง captcha ต่อ → คืน session ไม่คืนอีเมล
   - client username login ใช้ edge fn (setSession), ไม่เรียก get_email แล้ว (v3.7.256 ถอด fallback)
   - **REVOKE EXECUTE get_email_by_username FROM anon,authenticated,public** (เหลือ postgres+service_role). **verify prod: anon เรียก = 403 permission denied; edge fn (service role) ยัง resolve+ถึง GoTrue = username login ทำงาน.** เจ้าของยืนยัน browser login ผ่าน
   - **หมายเหตุ:** captcha ทำให้ Claude เทสต์ full login เองไม่ได้ (mint JWT bypass ได้แค่ RLS ไม่ใช่ signin) → ใช้ 2-phase + fallback ปลอดภัย. **เหลือ:** username_taken/search_user_by_username ยัง leak การมีตัวตน (username → มี/ไม่มี) — พิจารณาแยก (severity ต่ำกว่า ไม่ leak อีเมลแล้ว)
2. ✅ **~~sync_loan_payment (high)~~ แก้แล้ว v3.7.257:** overload 5-arg รับ `p_paid` (client ส่ง `computeLoanState.remaining<=0` = นับดอก) แทนเทียบเงินต้นเปล่า; เก็บ 4-arg เดิม (client เก่าไม่พัง). client 2 call sites ส่ง p_paid. **e2e-test live DB ผ่าน** (p_paid=false+total=principal→mirror ไม่ flip; p_paid=true→flip)
3. ✅ **~~pos_products anon cost/recipe leak~~ แก้แล้ว v3.7.254** — RPC `qr_menu(p_shop)` คืนเฉพาะคอลัมน์ปลอดภัย + client QR menu (L31682) ใช้ RPC + DROP qr_anon_read_products/categories. เจ้าของอ่านร้านตัวเองผ่าน pos_products_all/pos_categories_all (scoped) ไม่กระทบ. verify: anon อ่าน cost ตรง=[], RPC ได้เมนูไม่มี cost, ปิด authenticated cross-shop ด้วย. **⚠️ QR customer menu ควรให้เจ้าของสแกนเทสต์จริง 1 ครั้ง** (demo ไม่ครอบ path ลูกค้า)
4. ✅ **~~FIFO COGS (medium)~~ แก้แล้ว v3.7.257:** costTotal fifo mode = `fifoConsume().cogs` (unit-test node ผ่าน). average mode ไม่แตะ. 0 ร้าน fifo = latent
5. ✅ **~~FIFO void-restore~~ แก้แล้ว v3.7.257:** เก็บ used layers/item → posDeleteSale prepend คืน. **⚠️ posEditSale ยังไม่คืน layer** (edit qty fifo = residual แคบ)
6. 🟢 **credit payment split (low):** settle บิลเชื่อไม่บันทึกวิธีจ่าย → chip เงินสด+โอน ไม่ตรง revenue (CSV ยัง reconcile)

**follow-up ที่เหลือ (design change — ต้องเทสต์ร้านจริง/ตัดสินใจก่อนทำ):**
1. **soft-delete tombstones** (`deleted_at` ทุกตาราง sync) — ลบข้ามเครื่องยัง propagate ผ่าน realtime เท่านั้น (cursor poll มองไม่เห็น delete; local-only ghost ค้างบนเครื่อง stale จนกว่า realtime จะจับ). ต้องแก้ DB schema + ทุก delete path + filter ทุก query
2. **atomic stock decrement RPC** — สองเครื่องขายพร้อมกันยัง lose update (upsert absolute). ควรมี `decrement_stock(product_id, qty)` + เปลี่ยน checkout path; กระทบคิว offline (เก็บ delta แทน absolute)
3. **`game_sessions` realtime ไม่มี filter** — fan-out ทุก event × ทุก client (filter ด้วย array ไม่ได้ — ต้องเปลี่ยน schema เป็น notify-row ต่อ user หรือยอมรับจนกว่าผู้ใช้เกมจะเยอะ)
4. duplicate report block ×2 (~130 บรรทัด family vs personal) — refactor เมื่อสะดวก
5. `rotateToken` (QR token rotation) เขียนไว้ไม่มี UI เรียก — ถาม M: ฟีเจอร์อนาคตหรือลบ

## งานค้าง (ณ v3.7.103)
- Tier 1 #4+ (ถ้าจะทำต่อ): ดูจาก POS audit — เช่น พิมพ์ใบเสร็จ/แชร์, สต็อกสินค้า, กะ/รอบขาย ฯลฯ
- ขยาย product catalog (รับรูป → ลบพื้นหลังดำ → webp 256px q80 → อัปเดต `catalog/catalog.json` + zip ไม่ต้อง bump แอป) — *ต้องมีรูปจริงจาก M*
- ✅ **2.3 cursor polling** (transactions/ious) — **เสร็จแล้ว**: client ใช้ `.gt('updated_at', txCursorRef)` (full/delta/first mode + `cursorDisabledRef` fallback, pollForUpdates ~L12848) + SQL `tools/migrations/2026-06-16-cursor-polling-updated-at.sql` (top-level = run แล้ว)
- ✅ **2.4 admin dashboard RPC** — **เสร็จแล้ว** (2026-06-17): client wire ไว้ตั้งแต่ v3.7.50 + SQL `tools/migrations/2026-06-17-admin-dashboard-summary.sql` รันที่ Supabase แล้ว (verified: hourly=24/weekday=7, dau/mau คืนค่าถูก). แก้บั๊ก sparse hourly/weekday จาก draft v2.
- **Phase 2.1b / 2.2b** ตัด `loadDetail()/loadShopData()` ออกจาก local writes (ต้องการ optimistic update เต็ม) — ⚠️ เสี่ยง: แตะ core money-sync, ทำเมื่อมั่นใจ delta-merge เสถียร + ต้องเทสต์ multi-device จริง (เทสต์ใน demo mode ไม่ได้ เพราะ supabase stub)

## sprint ที่ทำแล้ว (2026-06-15/16)
ดู `docs/2026-06-15-research-action-plan.md` สำหรับรายละเอียดงานวิจัย (52-agent workflow + adversarial verify)
- v3.7.37 — security probe fix + preconnect + decision records
- v3.7.37 — SQL: 25 indexes (RLS, .or() patterns, POS, admin) — `tools/migrations/2026-06-15-research-indexes.sql`
- v3.7.38 — family realtime delta-merge (7 RTT/event → 0)
- v3.7.39 — POS realtime delta-merge (4-query refetch → 0)
- v3.7.40 — POS sales totals RPC (correctness fix: ยอด > 500 บิลผิดเงียบๆ) — `tools/migrations/2026-06-16-pos-sales-totals-rpc.sql`

## สิ่งที่ไม่ควรทำ
- ห้ามแตก index.html เป็นหลายไฟล์
- ห้าม `cat`/อ่านทั้งไฟล์ 3.9MB โดยไม่จำเป็น — ใช้ `grep -n` + `sed -n` ช่วงแคบ ๆ (ระวังบรรทัด I18N dictionary ที่ยาวเป็นหมื่นตัวอักษร — grep แบบจำกัด width)
- ห้าม bump version ไม่ครบ 4 จุด
- ห้าม commit โดยยังไม่ผ่าน `node --check`

## ตัดสินใจแล้ว — ไม่ทำ (ป้องกัน session ถัดไปเสนอซ้ำ)

ผ่าน research workflow 2026-06-15 (52 agents, audit + adversarial review):

**ไม่ migrate PowerSync / cr-sqlite (local-first)** — ขัด iron rule "single file"; anon QR ไม่มี JWT (sync layer ไม่รองรับ); ผู้ใช้ส่วนใหญ่ single-writer ไม่ต้อง CRDT; delta-merge ใน-memory ทำเองได้ ~90% ของ benefit (ดู v3.7.37+ realtime delta-merge work).

**ไม่ migrate Vite / SvelteKit** — claim "ลด bundle 60%" ลอย เพราะ Paruay ไม่มี Babel runtime อยู่แล้ว (React.createElement ตรงๆ); ขัด no-build rule.

**ไม่ย้าย GitHub Pages → Cloudflare Pages** — origin change → PWA ที่ install ไว้แล้ว orphan; GitHub Pages มี Fastly Bangkok PoP อยู่แล้ว.

**ไม่เพิ่ม Service Worker shell cache** — ขัด iron rule "ห้ามแตกไฟล์"; SW จาก Blob URL ไม่มี scope; version skew กับ Supabase schema = correctness risk.

**Trigger reconsider:** ถ้ามี shop จริง > 10 + multi-cashier conflict report จริง + ยอมแตก single-file constraint → คุยเรื่อง local-first ใหม่.

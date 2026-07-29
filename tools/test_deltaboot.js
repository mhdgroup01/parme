// ชุดทดสอบ deltaBootFetch — ดึง "โค้ดตัวจริง" ออกจาก index.html มารัน ไม่ได้เขียนเลียนแบบ
// (กับดักที่โปรแกรมหวยเคยเจอ: เทสต์เขียน handler เลียนแบบไว้เอง แล้วโค้ดจริงกลายพันธุ์ก็ยังเขียว)
const fs = require('fs');
const SRC = process.argv[2] || '/Users/mickysili/parme/index.html';
const src = fs.readFileSync(SRC, 'utf8');

// ตัดโค้ด "ทั้งบล็อกติดกัน" ตั้งแต่ const SYNC_CUR_KEY จนจบ deltaBootFetch
// (เคยพลาด: ตัดเฉพาะฟังก์ชันแล้วลืมค่าคงที่ SYNC_CUR_KEY / DELTA_BOOT_CAP ⇒ ทุกเคสคืน null
//  เพราะ ReferenceError ถูกกลืนใน catch ⇒ เคสด้านลบ "ผ่าน" ทั้งที่ไม่ได้ทดสอบอะไรเลย)
const A = src.indexOf("  const localSurvivors = (localArr, serverIds) => {");
if (A < 0) throw new Error('ไม่พบจุดเริ่ม');
const B = src.indexOf('  // ── LOAD ALL DATA FROM CLOUD AFTER LOGIN ──', A);
if (B < 0) throw new Error('ไม่พบจุดจบ');
const CODE = src.slice(A, B);
['SYNC_CUR_KEY', 'DELTA_BOOT_CAP', 'syncCurRead', 'syncCurWrite', 'deltaBootFetch', 'localSurvivors'].forEach(n => {
  if (CODE.indexOf(n) < 0) throw new Error('ดึงโค้ดมาไม่ครบ: ' + n);
});
// ใช้ txFromRow/iouFromRow "ตัวจริง" ด้วย ไม่งั้นธง srv ที่มันติดให้จะไม่ถูกทดสอบเลย
function grabTop(name) {
  const i = src.indexOf('const ' + name + ' = r => ({');
  if (i < 0) throw new Error('ไม่พบ ' + name);
  const j = src.indexOf('});', i);
  return src.slice(i, j + 3);
}
const ROWFNS = grabTop('txFromRow') + '\n' + grabTop('iouFromRow') + '\n';
if (!/srv: 1/.test(ROWFNS)) console.log('⚠ txFromRow ไม่ติดธง srv');
if (!/\.gte\(/.test(CODE)) throw new Error('ดึงโค้ดมาไม่ครบ: ไม่มี .gte');

// ---- สภาพแวดล้อมจำลอง (เฉพาะสิ่งที่ deltaBootFetch พึ่งพา) ----
function makeEnv(o) {
  const store = Object.assign({}, o.ls);
  const localStorage = {
    getItem: k => (k in store ? store[k] : null),
    setItem: (k, v) => { store[k] = String(v); },
    removeItem: k => { delete store[k]; }
  };
  const calls = [];
  const q = (table) => {
    const st = { table, count: null, head: false };
    const api = {};
    ['select', 'eq', 'gte', 'gt', 'order', 'limit'].forEach(m => api[m] = (...a) => {
      if (m === 'select' && a[1] && a[1].head) { st.head = true; st.countMode = a[1].count; }
      if (m === 'gte') st.gte = a[1];
      if (m === 'limit') st.limit = a[1];
      return api;
    });
    api.then = (res, rej) => {
      calls.push(st);
      let out;
      if (st.head) out = { data: null, error: o.countError || null, count: o.serverCount };
      else if (table === 'transactions') out = { data: o.txDelta, error: o.txError || null };
      else out = { data: o.iouDelta, error: o.iouError || null };
      return Promise.resolve(out).then(res, rej);
    };
    return api;
  };
  return {
    localStorage,
    calls,
    supabase: { from: q },
    cursorDisabledRef: { current: !!o.cursorDisabled },
    transactionsRef: { current: o.localTx || [] },
    iousRef: { current: o.localIous || [] },
    txPendingRead: () => o.pending || [],
    txDelPendingRead: () => o.pendingDel || [],
    // ตัวจริงจากไฟล์ (ไม่ใช่ของปลอม) — ทดสอบธง srv ที่มันติดให้ด้วย
    rowFns: new Function(ROWFNS + 'return { txFromRow: txFromRow, iouFromRow: iouFromRow };')()
  };
}

function getLocalSurvivors(o) {
  const env = makeEnv(o);
  return new Function(
    'localStorage', 'supabase', 'cursorDisabledRef', 'transactionsRef', 'iousRef',
    'txPendingRead', 'txDelPendingRead', 'txFromRow', 'iouFromRow',
    CODE + '\nreturn localSurvivors;'
  )(env.localStorage, env.supabase, env.cursorDisabledRef, env.transactionsRef, env.iousRef,
    env.txPendingRead, env.txDelPendingRead, env.rowFns.txFromRow, env.rowFns.iouFromRow);
}

async function run(o) {
  const env = makeEnv(o);
  const fn = new Function(
    'localStorage', 'supabase', 'cursorDisabledRef', 'transactionsRef', 'iousRef',
    'txPendingRead', 'txDelPendingRead', 'txFromRow', 'iouFromRow',
    CODE + '\nreturn deltaBootFetch;'
  )(env.localStorage, env.supabase, env.cursorDisabledRef, env.transactionsRef, env.iousRef,
    env.txPendingRead, env.txDelPendingRead, env.rowFns.txFromRow, env.rowFns.iouFromRow);
  const r = await fn(o.userId || 'u1');
  return { r, calls: env.calls };
}

const U = 'u1';
const cur = (tx, iou) => JSON.stringify({ u: U, tx: tx, iou: iou || '' });
const row = (id, u, amt) => ({ id, updated_at: u, amount: amt, note: 'n' + id });
let pass = 0, fail = 0;
const check = (name, cond, extra) => { if (cond) { pass++; console.log('  ✓', name); } else { fail++; console.log('  ✗', name, extra === undefined ? '' : JSON.stringify(extra)); } };

(async () => {
  console.log('=== deltaBootFetch: เงื่อนไขที่ต้องคืน null (= ไปดึงเต็มแบบเดิม) ===');
  let o = { ls: {}, localTx: [row('a', '1')], serverCount: 1 };
  check('ไม่มีเคอร์เซอร์', (await run(o)).r === null);

  o = { ls: { paruay_sync_cursor: cur('2026-01-01'), paruay_tx_user: 'คนอื่น' }, localTx: [row('a','1')], serverCount: 1 };
  check('แท็กในเครื่องเป็นของ user อื่น', (await run(o)).r === null);

  o = { ls: { paruay_sync_cursor: JSON.stringify({ u: 'u2', tx: '2026-01-01' }), paruay_tx_user: U }, localTx: [row('a','1')], serverCount: 1 };
  check('เคอร์เซอร์เป็นของ user อื่น', (await run(o)).r === null);

  o = { ls: { paruay_sync_cursor: cur('2026-01-01'), paruay_tx_user: U }, localTx: [], serverCount: 0 };
  check('ไม่มีรายการในเครื่อง', (await run(o)).r === null);

  o = { ls: { paruay_sync_cursor: cur('2026-01-01'), paruay_tx_user: U }, localTx: [row('a','1')], pending: ['x'], serverCount: 1 };
  check('มีของค้างคิวส่ง', (await run(o)).r === null);

  o = { ls: { paruay_sync_cursor: cur('2026-01-01'), paruay_tx_user: U }, localTx: [row('a','1')], pendingDel: ['x'], serverCount: 1 };
  check('มีของค้างคิวลบ', (await run(o)).r === null);

  o = { ls: { paruay_sync_cursor: cur('2026-01-01'), paruay_tx_user: U }, localTx: [row('a','1')], cursorDisabled: true, serverCount: 1 };
  check('เซิร์ฟเวอร์ไม่รองรับ updated_at', (await run(o)).r === null);

  o = { ls: { paruay_sync_cursor: cur('2026-01-01'), paruay_tx_user: U }, localTx: [row('a','1')], txDelta: [], serverCount: 1, txError: { message: 'boom' } };
  check('คำขอ delta ล้มเหลว', (await run(o)).r === null);

  o = { ls: { paruay_sync_cursor: cur('2026-01-01'), paruay_tx_user: U }, localTx: [row('a','1')], txDelta: [], serverCount: undefined };
  check('นับจำนวนแถวไม่ได้', (await run(o)).r === null);

  const big = Array.from({ length: 1001 }, (_, i) => row('b' + i, '2026-02-01'));
  o = { ls: { paruay_sync_cursor: cur('2026-01-01'), paruay_tx_user: U }, localTx: [row('a','1')], txDelta: big, serverCount: 1002 };
  check('ส่วนเพิ่มใหญ่เกินเพดาน', (await run(o)).r === null);

  console.log('=== ด่านสำคัญ: จับการลบจากเครื่องอื่น ===');
  o = { ls: { paruay_sync_cursor: cur('2026-01-01'), paruay_tx_user: U }, localTx: [row('a','1'), row('b','1')], txDelta: [], serverCount: 1 };
  check('เซิร์ฟเวอร์มี 1 แต่ในเครื่องมี 2 (ถูกลบ) → null', (await run(o)).r === null);

  console.log('=== เส้นทางที่ต้องทำงาน ===');
  o = { ls: { paruay_sync_cursor: cur('2026-01-01'), paruay_tx_user: U }, localTx: [row('a','1',10), row('b','1',20)],
        txDelta: [row('b', '2026-03-01', 99), row('c', '2026-03-02', 30)], serverCount: 3 };
  let out = await run(o);
  check('ผสมแล้วได้ 3 แถว', out.r && out.r.txs.length === 3, out.r && out.r.txs);
  check('แถวที่แก้ถูกทับด้วยค่าใหม่', out.r && out.r.txs.find(x => x.id === 'b').amount === 99);
  check('แถวใหม่ถูกเพิ่ม', !!(out.r && out.r.txs.find(x => x.id === 'c')));
  check('แถวที่ไม่เปลี่ยนยังอยู่', out.r && out.r.txs.find(x => x.id === 'a').amount === 10);
  check('เคอร์เซอร์ใหม่ = updated_at มากสุด', out.r && out.r.txMaxU === '2026-03-02', out.r && out.r.txMaxU);
  check('ใช้ .gte ไม่ใช่ .gt (กันแถวที่เวลาเท่ากันถูกข้าม)', out.calls.some(c => c.gte === '2026-01-01'), out.calls);
  check('ขอ count แบบ head (ไม่ดึง body)', out.calls.some(c => c.head === true && c.countMode === 'exact'));

  console.log('=== IOU ===');
  o = { ls: { paruay_sync_cursor: cur('2026-01-01', '2026-01-01'), paruay_tx_user: U },
        localTx: [row('a','1')], localIous: [{ id: 'i1', amount: 5 }],
        txDelta: [], iouDelta: [{ id: 'i1', updated_at: '2026-04-01', amount: 77 }], serverCount: 1 };
  out = await run(o);
  check('IOU ที่เปลี่ยนถูกผสมเข้า', out.r && out.r.ious.find(x => x.id === 'i1').amount === 77, out.r && out.r.ious);
  check('เคอร์เซอร์ IOU เดินตาม', out.r && out.r.iouMaxU === '2026-04-01');

  console.log('=== ธง srv ต้องถูกติดให้แถวที่มาจากเซิร์ฟเวอร์ ===');
  o = { ls: { paruay_sync_cursor: cur('2026-01-01'), paruay_tx_user: U }, localTx: [row('a','1',10)],
        txDelta: [row('c', '2026-03-02', 30)], serverCount: 2 };
  out = await run(o);
  check('แถวที่เพิ่งมาจากเซิร์ฟเวอร์มีธง srv', out.r && out.r.txs.find(x => x.id === 'c') && out.r.txs.find(x => x.id === 'c').srv === 1, out.r && out.r.txs);

  o = { ls: { paruay_sync_cursor: cur('2026-01-01'), paruay_tx_user: U }, localTx: [row('a','1')], txDelta: [], serverCount: 1 };
  out = await run(o);
  check('ไม่มีเคอร์เซอร์ IOU → ไม่ยิงคำขอ IOU และคืน ious=null (ผู้เรียกดึงเต็ม)', out.r && out.r.ious === null && !out.calls.some(c => c.table === 'ious'));

  console.log('=== localSurvivors: แถวในเครื่องที่เซิร์ฟเวอร์ไม่มี อยู่ต่อหรือถูกทิ้ง ===');
  const srvIds = new Set(['keep-on-server']);
  const L = [
    { id: 'keep-on-server', srv: 1 },   // เซิร์ฟเวอร์มี → ไม่นับเป็น local-only
    { id: 'offline-new' },              // สร้างในเครื่อง ยังไม่เคยขึ้น → ต้องเก็บ
    { id: 'deleted-elsewhere', srv: 1 },// เคยอยู่บนเซิร์ฟเวอร์ แต่ตอนนี้ไม่มี → ต้องทิ้ง
    { id: 'pending-edit', srv: 1 },     // เคยอยู่ แต่ยังค้างคิวส่ง → ต้องเก็บ
    null, { }                           // ขยะ → ต้องไม่หลุดออกมา
  ];
  let surv = getLocalSurvivors({ pending: ['pending-edit'] })(L, srvIds).map(x => x.id);
  check('ทิ้งเฉพาะแถวที่เคยอยู่บนเซิร์ฟเวอร์แล้วหายไป', JSON.stringify(surv) === JSON.stringify(['offline-new', 'pending-edit']), surv);
  surv = getLocalSurvivors({ pending: [] })(L, srvIds).map(x => x.id);
  check('ไม่มีของค้างคิว → แถวที่มีธง srv ถูกทิ้งทั้งหมด', JSON.stringify(surv) === JSON.stringify(['offline-new']), surv);
  surv = getLocalSurvivors({ pending: [] })([{ id: 'old-no-flag' }], new Set()).map(x => x.id);
  check('แถวเก่าที่ไม่มีธง (ก่อนอัปเวอร์ชัน) ยังถูกเก็บไว้', JSON.stringify(surv) === JSON.stringify(['old-no-flag']), surv);

  console.log('\n' + (fail ? '❌ ตก ' + fail + ' ข้อ' : '✅ ผ่านทั้งหมด') + ' (' + pass + '/' + (pass + fail) + ')');
  process.exit(fail ? 1 : 0);
})();

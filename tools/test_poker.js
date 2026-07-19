#!/usr/bin/env node
/* test_poker.js — สกัดฟังก์ชัน pure ของ Parme Poker จาก index.html จริง (marker-extract)
   แล้วรัน test vectors §9 ของสเปก + side-pot cases. รัน: node tools/test_poker.js */
'use strict';
const fs = require('fs');
const path = require('path');

const HTML = path.join(__dirname, '..', 'index.html');
const src = fs.readFileSync(HTML, 'utf8');

const START = '/* ==POKER_PURE_START==';
const END = '/* ==POKER_PURE_END== */';
const si = src.indexOf(START);
const ei = src.indexOf(END);
if (si < 0 || ei < 0) { console.error('FATAL: ไม่พบ marker POKER_PURE ใน index.html'); process.exit(2); }
const pureCode = src.slice(si, ei + END.length);

// eval ในแซนด์บ็อกซ์ function scope แล้วดึงฟังก์ชันออกมา
const mod = new Function(pureCode + '\nreturn { pkEval, pkCmp, pkBest5, pkSidePots, pkChen, pkStraightHigh };')();
const { pkEval, pkCmp, pkBest5, pkSidePots, pkChen } = mod;

// helper: parse "10s Jh Qd" -> {r,s}; suits s=0..3 (♠♥♦♣)
const SU = { s: 0, h: 1, d: 2, c: 3 };
const RA = { A: 14, K: 13, Q: 12, J: 11, T: 10, '10': 10, '9': 9, '8': 8, '7': 7, '6': 6, '5': 5, '4': 4, '3': 3, '2': 2 };
function C(str) {
  return str.trim().split(/\s+/).map(tok => {
    const su = tok.slice(-1);
    const rk = tok.slice(0, -1);
    return { r: RA[rk], s: SU[su] };
  });
}
function eqArr(a, b) { if (a.length !== b.length) return false; for (let i = 0; i < a.length; i++) if (a[i] !== b[i]) return false; return true; }

let pass = 0, fail = 0;
function check(name, cond, extra) {
  if (cond) { pass++; console.log('  PASS  ' + name); }
  else { fail++; console.log('  FAIL  ' + name + (extra ? '  -> ' + extra : '')); }
}

console.log('== pkEval — test vectors §9 ==');
const V = [
  ['royal SF',            '10s Js Qs Ks As 2h 3d', 8, [14]],
  ['wheel SF',            'As 2s 3s 4s 5s Kh Qd',  8, [5]],
  ['quads+K',             '9c 9d 9h 9s Ks 2h 3d',  7, [9, 13]],
  ['full house',          '8c 8d 8h 5s 5d As Kh',  6, [8, 5]],
  ['flush > pairA',       '2s 5s 9s Js Ks Ah Ad',  5, null],
  ['wheel straight',      'Ah 2d 3c 4s 5h 9d 9c',  4, [5]],
  ['straight > trips',    '6h 7d 8c 9s 10h 10d 10c',4, [10]],
  ['trips+kick',          'Qh Qd Qc 7s 2h 3d 9c',  3, [12, 9, 7]],
  ['two pair',            'Kh Kd 9s 9h Ac 2d 3c',  2, [13, 9, 14]],
  ['one pair',            'Jh Jd As Kh 9c 2d 3c',  1, [11, 14, 13, 9]],
  ['high card',           'Ad Kh 9c 7s 5h 3d 2c',  0, [14, 13, 9, 7, 5]],
];
for (const [name, hand, cat, tb] of V) {
  const ev = pkEval(C(hand));
  const okCat = ev.cat === cat;
  const okTb = tb === null ? true : eqArr(ev.tiebreak, tb);
  check(name + ' (cat=' + cat + (tb ? ' tb=' + JSON.stringify(tb) : '') + ')', okCat && okTb,
    'got cat=' + ev.cat + ' tb=' + JSON.stringify(ev.tiebreak));
}

console.log('== pkBest5 ต้องสอดคล้อง pkEval บน 7 ใบ (independent cross-check) ==');
for (const [name, hand, cat] of V) {
  const cards = C(hand);
  const direct = pkEval(cards);
  const b5 = pkBest5(cards);
  check('best5==eval: ' + name, pkCmp(direct, b5.ev) === 0 && b5.cards.length === 5,
    'direct=' + JSON.stringify(direct) + ' best5=' + JSON.stringify(b5.ev));
}

console.log('== pkCmp — kicker ==');
const A1 = pkEval(C('As Ah Kd Qc Js 4h 3c')); // pair A, kick K Q J
const A2 = pkEval(C('Ad Ac Kh Qs 10d 4s 2h')); // pair A, kick K Q 10
check('AAKQJ > AAKQ10 (kicker)', pkCmp(A1, A2) > 0, 'cmp=' + pkCmp(A1, A2));
check('cmp reflexive == 0', pkCmp(A1, A1) === 0);
check('cmp anti-symmetric', pkCmp(A2, A1) < 0);

console.log('== pkSidePots — A allin 1k, B allin 5k, C 10k ==');
{
  const pots = pkSidePots([1000, 5000, 10000], [false, false, false]);
  // คาด: main 3000 [0,1,2], side1 8000 [1,2], side2 5000 [2]
  check('3 layers', pots.length === 3, JSON.stringify(pots));
  check('main 3000 ABC', pots[0] && pots[0].amt === 3000 && eqArr(pots[0].eligible, [0, 1, 2]), JSON.stringify(pots[0]));
  check('side1 8000 BC', pots[1] && pots[1].amt === 8000 && eqArr(pots[1].eligible, [1, 2]), JSON.stringify(pots[1]));
  check('side2 5000 C', pots[2] && pots[2].amt === 5000 && eqArr(pots[2].eligible, [2]), JSON.stringify(pots[2]));
  const total = pots.reduce((s, p) => s + p.amt, 0);
  check('รวม = 16000 (เงินไม่หาย)', total === 16000, 'total=' + total);
}

console.log('== pkSidePots — folded ไม่ eligible แต่เงินยังอยู่ในกอง ==');
{
  // A(fold) จ่าย 1k, B 5k, C 5k → main 3k eligible [B,C] (A folded), เงินรวม 11k
  const pots = pkSidePots([1000, 5000, 5000], [true, false, false]);
  const total = pots.reduce((s, p) => s + p.amt, 0);
  check('เงินรวม = 11000', total === 11000, 'total=' + total);
  check('layer แรกไม่มี A (folded)', pots[0] && pots[0].eligible.indexOf(0) < 0, JSON.stringify(pots));
}

console.log('== pkSidePots — เท่ากันหมด = 1 กอง ==');
{
  const pots = pkSidePots([2000, 2000, 2000], [false, false, false]);
  check('1 กอง 6000 ABC', pots.length === 1 && pots[0].amt === 6000 && eqArr(pots[0].eligible, [0, 1, 2]), JSON.stringify(pots));
}

console.log('== pkChen — sanity (ไม่ใช่ vector บังคับ แต่กันค่าเพี้ยน) ==');
check('AA = 20', pkChen({ r: 14, s: 0 }, { r: 14, s: 1 }) === 20, 'got ' + pkChen({ r: 14, s: 0 }, { r: 14, s: 1 }));
check('KK = 16', pkChen({ r: 13, s: 0 }, { r: 13, s: 1 }) === 16, 'got ' + pkChen({ r: 13, s: 0 }, { r: 13, s: 1 }));
check('72o ต่ำสุดๆ (<=1)', pkChen({ r: 7, s: 0 }, { r: 2, s: 1 }) <= 1, 'got ' + pkChen({ r: 7, s: 0 }, { r: 2, s: 1 }));
check('AKs > AKo', pkChen({ r: 14, s: 0 }, { r: 13, s: 0 }) > pkChen({ r: 14, s: 0 }, { r: 13, s: 1 }));

console.log('\n==================  ' + pass + ' PASS / ' + fail + ' FAIL  ==================');
process.exit(fail === 0 ? 0 : 1);

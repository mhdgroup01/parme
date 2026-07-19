# CragonGame table — faithful reproduction spec (v3.7.341)

Both reference images confirm the subsystem specs (teal stadium felt, warm-leather rail, blue arena + gray chairs, pink chips, gold winning-card frame, red/green/orange action buttons, lavender pot-fraction buttons). Here is the merged authoritative spec.

---

# CRAGON SKIN — Authoritative CSS Implementation Spec

Single source of truth for the `cragon` visual skin. Target: React (`React.createElement`), single-file app, landscape 16:9 stage. This specifies the **skin only** — the engine and rotated stage already exist. All coordinates are **% of the 16:9 stage** (0–100 x, 0–100 y). All hex are final; raw sample ranges are noted only where useful. Where this repo uses Phi 2-layer tokens, register these as `--cragon-*` aliases and reference the alias in components — never hard-code hex in a component.

The whole skin is **theme-fixed dark** — it must NOT follow `prefers-color-scheme`. Pin it dark regardless.

---

## 0. Token layer (define once, reference everywhere)

```css
:root .skin-cragon{
  /* felt */
  --felt-hotspot:#4fb0b8; --felt-lit:#2a95a0; --felt-mid:#1d7078;
  --felt-edge:#185f66; --felt-deep:#145159; --felt-rim:#2c9aa2;
  /* rail */
  --rail-gloss:#6c625f; --rail-body:#3a3d41; --rail-brown:#4a3d33;
  --rail-spec:#9c968a; --rail-dark:#221b1c;
  /* arena */
  --bg-ceiling:#050310; --bg-wall:#131a33; --stands:#1a315d; --stands-dk:#0c184e;
  --seat-spec:#c6c8d0; --truss:#303d70; --truss-dk:#130a3f;
  --chair-mid:#4c4c4c; --chair-lit:#5d5d5d; --chair-dk:#2b2b2b;
  --floor:#232c52; --floor-lo:#1f2647; --floor-grid:#2d3663; --back-glow:#47274c;
  /* seats/hud */
  --active:#6fd30a; --active-text:#7bf501; --name:#fbfdfd; --chip-gold:#c1aa72;
  --strip:rgba(20,26,42,0.60); --fold-txt:#7a8093; --call-txt:#57c81e; --raise-txt:#ffb52c;
  --vip:#f9c102; --vip-dk:#e8890f; --disc-face:#ffffff;
  --logo-chev-a:#c4d2f2; --logo-chev-b:#6d84c8; --red-dot:#e8195f;
  --hud-time:#dfe6f2; --hud-stat:#ffffff; --icon:#9ab3f0;
  --btn-fill:rgba(41,49,90,0.38); --btn-ring:rgba(74,86,136,0.6);
  /* center */
  --card-face:#fbfaf6; --suit-red:#e01a17; --suit-black:#171717;
  --win-gold:#f4c20d; --win-glow:#ffd94a; --pot-txt:#ffffff; --potamt:#fdf6d9;
  --bet-txt:#f7efc9; --blinds:#c2c2c2;
  --chip:#d61b78; --chip-hi:#e8579e; --chip-lo:#a9145e; --card-back:#1b6ec6;
  /* action bar */
  --bar:rgba(20,27,60,0.82); --pot-btn-a:#7c5f99; --pot-btn-b:#62478c;
}
```

Layer order back→front for the whole scene:
`arena-bg → floor → chairs → trusses → vignette → table shadow → rail oval → felt oval → felt rim-ring → center cluster (pot/board/bets) → seat cards → dealer button → HUD → corner discs → action bar`

---

## 1. Arena background (always-dark, `aria-hidden`, `pointer-events:none`)

Full-screen stack of absolutely-positioned divs behind the table.

**1a. Base gradient div** (0,0,100,100):
```css
background:linear-gradient(180deg,#050310 0%,#0d1330 8%,#16224a 20%,#1c2a52 55%,#202749 78%,#1a2140 100%);
```

**1b. Central back-glow** (soft purple stage glow, generic — NO logo):
```css
background:radial-gradient(ellipse 60% 40% at 50% 20%,rgba(90,70,120,.35) 0%,rgba(40,50,95,.15) 40%,transparent 70%);
```

**1c. Spectator stands** — div `top:3% left:0 w:100% h:21%`:
```css
background:#1a315d;
/* tier rows */
background-image:
  repeating-linear-gradient(180deg,rgba(255,255,255,.06) 0 2px,transparent 2px 9px);
```
Add a low-opacity speckle of 1–2px `#c6c8d0` dots at ~8% opacity (a data-URI dot pattern or tiny inline SVG noise) = distant empty seats. This speckle is the single strongest "stadium" cue — invest here. Fade the bottom edge to transparent so stands sink behind the table.

**1d. Trusses** — two thin vertical divs, `left:0` and `right:0`, `y 8%–32%`, `w ~5%`:
```css
background:linear-gradient(90deg,#141a3a,#303d70,#141a3a);
```
Add 2–3 horizontal cross-brace lines `rgba(120,140,190,.4)` and a couple of small white radial glow dots near the top (lamp fixtures).

**1e. Empty gaming chairs** — gray rounded-back divs positioned around the TOP arc of the oval (both screenshots show 4–6). Positions (center x, center y, w×h):
- top-left of dealer: `33%, 18%, 12×18%`
- top-right of dealer: `67%, 18%, 12×18%`
- far-left: `14%, 27%, 11×15%`
- upper-right side (a.png): `~76%, 20%, 11×16%`
- (fill remaining arc evenly if seat model needs more)

Each chair:
```css
background:linear-gradient(160deg,#6a6a6a 0%,#4c4c4c 45%,#2b2b2b 100%);
border-radius:45% 45% 18% 18%;
box-shadow:inset 0 6px 12px rgba(0,0,0,.5), 0 8px 14px rgba(0,0,0,.45);
```

**1f. Glossy tiled floor** — div `bottom:0 left:0 w:100% h:36%`, real perspective:
```css
transform:perspective(600px) rotateX(60deg); transform-origin:bottom;
background:linear-gradient(180deg,#232c52,#1f2647);
background-image:
  repeating-linear-gradient(90deg,transparent 0 78px,rgba(45,54,99,.6) 78px 80px),
  repeating-linear-gradient(0deg,transparent 0 78px,rgba(45,54,99,.5) 78px 80px);
```
Grid lines `rgba(70,90,150,.3)`, low opacity. Add a faint horizon sheen `linear-gradient(180deg,rgba(255,255,255,.05) 0%,transparent 25%)` and a faint vertical mirror streak under the table.

**1g. Vignette overlay** (topmost of the bg group):
```css
background:radial-gradient(ellipse 120% 100% at 50% 45%,transparent 55%,rgba(8,10,24,.55) 100%);
```

Keep ALL seat highlights + grid lines at 5–25% opacity so the arena recedes and the felt pops.

---

## 2. Oval table — felt + leather rail + drop shadow

Horizontal **stadium oval** (rounded-rect), aspect ~1.8:1, flat long sides + semicircular ends. Viewed slightly from above-front: **front (bottom) rail is visibly thicker with the strongest gloss; top rail is thin.** This asymmetry sells the angle — do not skip it.

**2a. Rail oval (outer div)** — `x 13%→87% (w 74%)`, `y 26%→72% (h 46%)`, center `50%,49%`:
```css
border-radius:50%/38%;              /* stadium; tune to w:h */
background:
  radial-gradient(ellipse at 50% 30%,rgba(90,70,55,.35),transparent 60%),
  linear-gradient(to bottom,#6c625f 0%,#47413f 14%,#3a3d41 38%,#322c2f 62%,#241d1e 100%);
box-shadow:
  inset 0 5px 10px rgba(210,205,195,.22),   /* top-crown gloss */
  inset 0 -10px 16px rgba(0,0,0,.65),        /* underside roll (front lip) */
  inset 0 0 0 1px rgba(0,0,0,.5),            /* felt-side crease */
  0 20px 44px rgba(0,0,0,.55),               /* soft floor shadow */
  0 6px 10px rgba(0,0,0,.45);                /* contact shadow */
```
The warm-brown radial patch is mandatory — without it the rail reads as plastic, not leather. Optionally add 2–3 thin elongated soft-white specular glints (`rgba(200,192,175,.5)`, blurred) following the curvature on the top-center crown and the front roll (brightest tan `#9c968a`), thin arcs not full rings.

**2b. Felt oval (inner div)** — inset from rail: `~4.5%` L/R, `~2.5%` top, `~7%` bottom (bottom inset larger = perspective). Net felt box `x 18%→82% (w 64%)`, `y 29%→64% (h 35%)`, center `50%,46.5%`:
```css
border-radius:50%/40%;
background:radial-gradient(ellipse 58% 52% at 50% 42%,
  #4fb0b8 0%,#2a95a0 18%,#1e7a82 45%,#1d7078 68%,#185f66 88%,#145159 100%);
box-shadow:
  inset 0 0 0 5px rgba(60,175,185,.35),      /* bright teal rim-ring */
  inset 0 0 14px 4px rgba(70,190,200,.18),   /* rim glow */
  inset 0 0 60px rgba(0,0,0,.35);            /* center-lit vignette */
```
Notes: felt is **desaturated dark cyan `#1d7078`, not pure teal** — keep saturation moderate. Sheen hotspot sits **above** geometric center (`42% y`) because light is overhead-front; far top edge darkens most. The bright teal rim-ring `#2c9aa2` at the felt/rail seam is the second most important realism detail — do not omit. Optionally overlay a 2–4% black speckle felt-weave.

No logo or watermark is printed on the felt or rail — reproduce both faithfully (generic casino furniture).

---

## 3. Player seat cards + dealer button

6 seats around the oval. Card = **vertical flex column**: name/action strip → avatar → chip strip. Card `w≈9%`, total `h≈27%`. Corner radius ~6px.

**Structure**
```
.seat (column, radius 6px)
 ├ .strip.name   (h≈3%, --strip fill)   → nickname white OR action tag
 ├ .avatar       (near-square, aspect 1/1, radius 4px)
 │   └ .vip      (abs bottom-left)
 └ .strip.chip   (h≈4%, --strip fill)    → amount, gold or green
```

**Strips**: `background:rgba(20,26,42,.60)` (reads teal over felt via transparency). `text-shadow:0 1px 1px rgba(0,0,0,.7)`.

**Avatar (GENERIC — substitute)**: instead of the source photo/sticker, render an **initials circle**:
```css
.avatar{aspect-ratio:1/1;border-radius:4px;display:flex;align-items:center;justify-content:center;
  background:hsl(var(--hue),45%,45%);   /* --hue = hash(name)%360 deterministic */
  color:#fff;font-weight:700;font-size:40%;}  /* 2 uppercase initials, ~40% of avatar height */
```

**Name text**: `#fbfdfd`, centered, bold, ~24–28px.

**Chip text**: normal/folded seats muted gold `#c1aa72`; ACTIVE seat neon green `#7bf501`. Uses 千/万 myriad units (keep numeric format from engine).

**Active-to-act state** (`.to-act`) — two coupled changes:
```css
border:3px solid #6fd30a;border-radius:6px;
box-shadow:0 0 10px 2px rgba(111,211,10,.75),0 0 22px 6px rgba(111,211,10,.35);
/* AND recolor chip text to #7bf501 */
```

**Folded state** (`.folded`):
```css
.folded .avatar{filter:grayscale(.30) brightness(.62);}
.folded .avatar::after{content:'';position:absolute;inset:0;background:rgba(0,0,0,.4);}
/* name strip shows grey '弃牌' tag instead of nickname */
```
Optional idle/away seats: a grey translucent martini glyph (~2.2% disc) over the dimmed avatar.

**Action tags** (in the name strip, TEXT-COLOR ONLY — no colored pill):
- fold `弃牌` → `#7a8093` (grey)
- call `跟注` → `#57c81e` (green)
- raise `加注` → `#ffb52c` (orange)

Implement as a single `.tag` node where only `color` changes.

**VIP badge** (`.vip`, abs `bottom:0;left:0`, w≈3.5% h≈2.2%) — redraw crown from scratch:
```css
background:linear-gradient(180deg,#ffdf5a 0%,#f9c102 45%,#e8890f 100%);
/* 'VIP'+level white, 1px #7a4a00 outline; small white sparkle star */
```

**Dealer 'D' button** — `position:absolute` white disc, w≈2.1%, moved beside the on-button seat (h.png example `x≈17.3% y≈68.5%`):
```css
background:radial-gradient(circle,#ffffff,#dfe1e5);
box-shadow:0 2px 3px rgba(0,0,0,.5);   /* black bold 'D', near-#111 */
```

---

## 4. Top HUD bar — Parme mark (NO Cragon/CPT logo)

Fixed row across the top. Two groups.

**Left group:**
- **Logo disc** — `x≈0.7% y≈1.5%`, dia ≈5.5% (`~105px`). Glassy circle:
```css
background:radial-gradient(circle at 30% 25%,rgba(255,255,255,.15),rgba(15,20,45,.55));
```
Inside: **Parme's own mark** — a periwinkle **"P"** glyph (gradient `#c4d2f2 → #6d84c8`), replacing the source "V" chevron. Do NOT reproduce the Cragon "V". Keep it a plain letterform.
- **Red notification dot** `#e8195f` at top-right of disc (`~x5% y2.5%`, dia ~1.3%), `box-shadow:0 0 4px` bloom.
- **Clock** `20:43` at `x≈9% y≈3.2%`, `#dfe6f2`, ~28px, `text-shadow:0 1px 2px rgba(0,0,0,.6)`.
- Small signal-bars icon at `x≈14.5%`.

**Right group** (right-aligned, ends `x≈96%`, two stacked white lines, ~44px, `text-shadow:0 1px 2px rgba(0,0,0,.6)`):
- line 1 `y≈2.3%`: `8/14  均筹:13214` (players/max + average stack)
- line 2 `y≈7.4%`: `涨盲时间:01:39` (blind-increase countdown; a.png variant `下一局将升盲`)

**Corner utility discs** — 4 translucent glass discs, dia ≈5.5%, icon `#9ab3f0`:
- friends (two-people) — `x≈4.3% y≈84%`
- chat (bubble) — `x≈11.8% y≈84%`
- lock (padlock) — `x≈88% y≈84%`
- chat2/emote — `x≈94.5% y≈84%`
```css
background:rgba(41,49,90,.38);
box-shadow:inset 0 1px 0 rgba(255,255,255,.06);
border:1px solid rgba(74,86,136,.6);
backdrop-filter:blur(4px);
```

---

## 5. Community cards + pot + main-pot chip + per-player bets + pink CHIP recipe + blinds

**Community board** — 5-card row, bounding box `x 31% y 38.5% w 36% h 18%`, centered on `~49% x`. Each card `w 6.3% h 18%`, aspect **1 : 1.5**, radius ~6% of card width.

Card X positions (h.png): C1 `31.5%`, C2 `38.4%`, C3 `45.3%`, C4 `52.2%`, C5 `61%` (slightly larger gap before 5th).

**Card face:**
```css
background:linear-gradient(180deg,#ffffff 0%,#f4f2ea 100%);  /* warm white #fbfaf6, NOT pure */
border-radius:8px;box-shadow:0 4px 8px rgba(0,0,0,.35);
```
**Index:** SINGLE top-left rank + suit pip (inset ~8%). NO mirrored bottom-right index. Number cards show ONE large centered suit pip (~45% card width). Court cards (K/J/Q) show a figure.
- red suits ♥♦ → `#e01a17`
- black suits ♠♣ → `#171717`

**Winning card** (`.win` — gold frame + glow, e.g. K♥ J♥ K♠):
```css
border:3px solid #f4c20d;
box-shadow:0 0 10px 2px rgba(255,217,74,.85),0 0 3px #f4c20d,0 4px 8px rgba(0,0,0,.35);
```

**Court-card art** — use a **public-domain / open-licensed** French-suited court design (or a simple crown+robe silhouette). Do NOT copy the source deck's exact art. Rank+suit index layout itself is functional/free.

**Card backs** (opponent/mucked) — generic royal blue `#1b6ec6` with a plain repeating diamond/crosshatch, no brand mark.

**Pink CHIP recipe** (one div, used for main pot AND every bet — single chip, not a stack; drawn top-down as a squashed ellipse):
```css
.chip{width:2.2%;height:4%;border-radius:50%;transform:scaleY(.9);position:relative;
  background:radial-gradient(circle at 42% 35%,#e8579e 0%,#d61b78 55%,#a9145e 100%);
  box-shadow:0 2px 3px rgba(0,0,0,.4);}
.chip::before{content:'';position:absolute;inset:18%;border-radius:50%;
  border:2px dashed #fff;opacity:.95;}          /* white edge spots, ~6-8 dashes */
.chip::after{content:'';position:absolute;inset:0;border-radius:50%;
  background:radial-gradient(circle at 35% 28%,rgba(255,255,255,.55),transparent 42%);} /* gloss */
```

**Pot label** `底池: 4.9千` — `x 44% y 29%`, white `#ffffff`, ~2.6% cap-height, `text-shadow:0 1px 2px rgba(0,0,0,.6)`. (Sits under the center-top rebuy button region.)

**Main-pot chip + amount** — chip `x 44.8% y 34.5%`, amount `2.1千` at `x 48%`, color pale cream `#fdf6d9`.

**Per-player bets** (pale gold-cream `#f7efc9`, distinct from white pot label):
- `400` bottom-left: chip `x 25.5% y 56%`, text `x 29%` — **left side ⇒ chip then number**
- `800` upper-right: text `x 73% y 44.5%`, chip `x 78% y 45%` — **right side ⇒ number then chip**
- `800` lower-right: text `x 73% y 54%`, chip `x 70.5% y 54.5%`
Rule: chip always sits **toward** the player's pod.

**Blinds/ante** `盲注:200/400 前注:75` — `x 42% y 56.5%`, muted grey `#c2c2c2`, small (~2% cap-height), directly under the board. (a.png: `盲注:300/600 前注:100`.)

---

## 6. Action buttons + pot-fraction shortcuts + bottom bar

**Bottom bar** — `x 0% y 89% w 100% h 11%`:
```css
position:absolute;left:0;bottom:0;width:100%;height:11%;
display:flex;align-items:center;justify-content:space-between;padding:0 1%;
background:rgba(20,27,60,.82);box-sizing:border-box;
```
Two clusters with a large empty gap between: pot-fraction cluster far-left (ends ~38%), color trio right (~42%→98.7%). Corner social/lock discs float just ABOVE the bar, not inside it.

**Shared button base:**
```css
.btn{border:none;border-radius:8px;color:#fff;font-weight:700;
  text-shadow:0 1px 1px rgba(0,0,0,.35);
  box-shadow:0 2px 4px rgba(0,0,0,.35),inset 0 1px 0 rgba(255,255,255,.45);
  display:flex;align-items:center;justify-content:center;}
```
Corner radius small (~8px), NOT pills. The lightest gradient stop IS the top gloss — don't wash it out with an extra white overlay.

**Pot-fraction buttons** (`1/2 x 底池`, `2/3 x 底池`, `1 x 底池`) — `w 11.5% h 7%`, x at `~0.8%`, `~13.75%`, `~26.2%`, `y 90.5%`, ~1.5% gaps:
```css
background:linear-gradient(180deg,#7c5f99 0%,#62478c 100%);
box-shadow:inset 0 1px 0 rgba(255,255,255,.18);
font-size:clamp(11px,1.4vw,16px);
```

**Color trio** — `h 8%` (visibly a touch taller than pot buttons), `font-size:clamp(16px,2.4vw,26px)`:
- **FOLD** `弃牌` — `x 41.7% w 18.3%`:
```css
background:linear-gradient(180deg,#dd6b60 0%,#c72c28 20%,#a80d09 58%,#b81b0b 86%,#cf3a11 100%);
```
- **CALL** `跟900` — `x 61.3% w 17.9%` (auto-fit variable amount, allow font shrink):
```css
background:linear-gradient(180deg,#8ed665 0%,#55a532 28%,#2e8027 68%,#108230 100%);
```
- **RAISE** `加注` — `x 80.8% w 17.9%`, ends ~98.7%:
```css
background:linear-gradient(180deg,#f0cf6e 0%,#e6b23f 24%,#d18f2b 55%,#bb6208 90%,#c47009 100%);
```
The brighter/warmer FINAL stop on each color button reads as a lit lower bevel — keep it even though it looks "wrong" next to the darker mid-body. Optional bottom bevel `inset 0 -1px 0 rgba(0,0,0,.25)`. All labels pure white `#ffffff`.

Labels are generic game terms — swap Chinese for any locale via the engine's i18n.

---

## 7. COPYRIGHT-SAFE MANIFEST

**Reproduce faithfully (functional/generic casino UI — no protected expression):**
- Teal felt + warm-leather rail materials, all gradients/shadows.
- Blue e-sports arena gradient, tiered stands + speckle, trusses, perspective tiled floor, empty gray gaming chairs.
- Oval geometry, perspective asymmetry, rim-ring.
- Community cards: warm-white face, red/black rank+suit index layout, gold winning-highlight.
- Pink chip graphic (radial gradient + dashed ring + gloss), pot label, per-player bets, blinds/ante text.
- Fold/Call/Raise gradient buttons, pot-fraction shortcut math, bottom bar.
- VIP crown badge — the concept is generic; **redraw the crown+star from scratch**, don't copy the source artwork.
- Dealer "D" disc, corner utility glyphs (friends/chat/lock).

**Substitute (do NOT copy the source's protected/personal assets):**
| Source asset | Replace with |
|---|---|
| Center hostess/dealer painted character art | **None** — omit; keep only a plain rebuy button / neutral dealer-position marker; background gradient continues behind it |
| `Cragon Poker` wordmark + `2018 CPT` chip logos (back wall) | **Omit** — plain blue wall gradient + soft glow only; NO text, no branded chip emblems |
| Top-left "V" chevron brand mark | **Parme "P"** letterform (periwinkle gradient) in the glass disc |
| God-of-Wealth (财神) sticker avatar | Initials-on-colored-circle avatar |
| Panda "惹不起" meme sticker avatar | Initials-on-colored-circle avatar |
| Real user photographs (beach, cowgirl, sleeping man, VIP portraits) | Initials-on-colored-circle avatars (deterministic hue = hash(name)%360) |
| Source deck's exact court-card painting | Public-domain / open-licensed French court design or generic crown+robe silhouette |
| Card-back diamond-lattice art | Generic blue `#1b6ec6` diamond/crosshatch, no mark |
| Any sponsor wordmarks / stylized app-icon glow on wall | Neutral radial light only |

**Net rule:** materials, geometry, colors, and functional controls are reproduced 1:1; every branded logo, painted character, meme/photo avatar, and the specific court-deck art is replaced with a generic or Parme-owned equivalent.

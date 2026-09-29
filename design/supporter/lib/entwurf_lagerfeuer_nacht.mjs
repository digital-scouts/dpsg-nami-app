// Entwuerfe: Lagerfeuer bei Nacht mit sichtbarem Feuer (Feedback-Runde).
// Gleiche Farben und Szene wie backgrounds.mjs, dazu ein animiertes Feuer.
import { rng, r1, ridge, pineRow, kohte } from './util.mjs';

const W = 1200;
const H = 400;

export const NIGHT_FIRE = {
  top: '#1d1512',
  bottom: '#3a241b',
  hill: '#2c1c16',
  trees: '#24170f',
  glow: '#e07a3c',
  spark: '#ffb56b',
  log: '#3a2418',
  logLit: '#6b4128',
  stone: '#3b2a22',
  stoneLit: '#7a4a30',
  cloth: '#0c0806',
  flameOuter: '#d9542a',
  flameMid: '#f5a03d',
  flameInner: '#ffd98a',
};

export const ENTWUERFE = [
  {
    id: 'a',
    label: 'A: Kleines Feuer, unten',
    hint: 'Wie tagsüber: Feuer unten in der Mitte, Funken steigen daraus auf.',
  },
  {
    id: 'b',
    label: 'B: Feuerstelle mit Sitzkreis',
    hint: 'Größeres Feuer mit Steinring und zwei Sitzbalken, etwas höher gesetzt.',
  },
  {
    id: 'c',
    label: 'C: Feuer an der Kohte, auf der Anhöhe',
    hint: 'Feuer auf dem Hügel neben einer Kohte, etwas höher als A und B.',
  },
  {
    id: 'd',
    label: 'D: Feuer in der Ferne, weit oben',
    hint: 'Kleines Feuer auf einer fernen Anhöhe in der oberen Bildhälfte, dazu Glut am Waldrand. Sitzt über der Suchleiste.',
  },
];

export const FIRE_CSS = `
.glow { animation: flicker 5.3s ease-in-out infinite alternate; transform-box: fill-box; transform-origin: 50% 70%; }
.glow2 { animation: flicker 3.7s ease-in-out infinite alternate-reverse; transform-box: fill-box; transform-origin: 50% 70%; }
@keyframes flicker { from { opacity: .55; transform: scale(1); } to { opacity: .85; transform: scale(1.06); } }
.flame { transform-box: fill-box; transform-origin: 50% 100%; animation-name: flame; animation-timing-function: ease-in-out; animation-iteration-count: infinite; animation-direction: alternate; }
@keyframes flame {
  0% { transform: scale(1, 1) skewX(0deg); }
  35% { transform: scale(.94, 1.08) skewX(-4deg); }
  70% { transform: scale(1.04, .94) skewX(3deg); }
  100% { transform: scale(.98, 1.04) skewX(-1deg); }
}
.spark { animation-name: rise; animation-timing-function: linear; animation-iteration-count: infinite; opacity: 0; }
@keyframes rise { 0% { transform: translate(0,0); opacity: 0; } 10% { opacity: .85; } 100% { transform: translate(var(--dx), var(--dy)); opacity: 0; } }
@media (prefers-reduced-motion: reduce) { * { animation: none !important; } }`;

const flamePath = (x, y, w, h) =>
  `M${r1(x - w)} ${r1(y)} C${r1(x - w)} ${r1(y - h * 0.45)} ${r1(x - w * 0.15)} ${r1(y - h * 0.6)} ${r1(x + w * 0.1)} ${r1(y - h)} C${r1(x + w * 0.25)} ${r1(y - h * 0.62)} ${r1(x + w)} ${r1(y - h * 0.5)} ${r1(x + w)} ${r1(y)} Z`;

// Animiertes Feuer: drei Flammenschichten, Scheite, Glut. s = Groesse.
export function animatedFire(x, y, s, p = NIGHT_FIRE) {
  const layer = (dx, w, h, fill, dur, delay) =>
    `<path class="flame" d="${flamePath(x + dx * s, y, w * s, h * s)}" fill="${fill}" style="animation-duration:${dur}s;animation-delay:${delay}s"/>`;
  const logs = [-14, 14]
    .map(
      (deg) =>
        `<g transform="rotate(${deg} ${x} ${r1(y + 4 * s)})"><rect x="${r1(x - 46 * s)}" y="${r1(y - 2 * s)}" width="${r1(92 * s)}" height="${r1(12 * s)}" rx="${r1(6 * s)}" fill="${p.log}"/><rect x="${r1(x - 46 * s)}" y="${r1(y - 2 * s)}" width="${r1(92 * s)}" height="${r1(4 * s)}" rx="${r1(2 * s)}" fill="${p.logLit}"/></g>`,
    )
    .join('');
  return (
    `<ellipse cx="${x}" cy="${r1(y + 6 * s)}" rx="${r1(40 * s)}" ry="${r1(7 * s)}" fill="${p.glow}" opacity="0.55"/>` +
    layer(-16, 16, 44, p.flameOuter, 1.7, -0.4) +
    layer(15, 15, 50, p.flameOuter, 1.9, -1.1) +
    layer(0, 26, 74, p.flameOuter, 2.1, 0) +
    layer(1, 18, 54, p.flameMid, 1.5, -0.7) +
    layer(0, 9, 32, p.flameInner, 1.2, -0.3) +
    logs
  );
}

function glowAt(x, y, rx, ry) {
  return (
    `<defs><radialGradient id="fireGlow"><stop offset="0" stop-color="${NIGHT_FIRE.glow}" stop-opacity="0.55"/><stop offset="1" stop-color="${NIGHT_FIRE.glow}" stop-opacity="0"/></radialGradient></defs>` +
    `<ellipse class="glow" cx="${x}" cy="${y}" rx="${rx}" ry="${ry}" fill="url(#fireGlow)"/>` +
    `<ellipse class="glow2" cx="${x}" cy="${y + 10}" rx="${r1(rx * 0.6)}" ry="${r1(ry * 0.6)}" fill="url(#fireGlow)"/>`
  );
}

function sparks(x, y, count, spread, rise) {
  const rand = rng(7);
  let out = '';
  for (let i = 0; i < count; i++) {
    const dur = 7 + rand() * 7;
    out += `<circle class="spark" cx="${r1(x + (rand() - 0.5) * spread)}" cy="${r1(y)}" r="${r1(1.4 + rand() * 1.8)}" fill="${NIGHT_FIRE.spark}" style="--dx:${r1((rand() - 0.5) * 120)}px;--dy:${-rise}px;animation-duration:${r1(dur)}s;animation-delay:${r1(-rand() * dur)}s"/>`;
  }
  return out;
}

const sky = `<defs><linearGradient id="bgSky" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="${NIGHT_FIRE.top}"/><stop offset="1" stop-color="${NIGHT_FIRE.bottom}"/></linearGradient></defs><rect width="${W}" height="${H}" fill="url(#bgSky)"/>`;

const campTrees =
  ridge({ y: 300, amp: 22, seed: 3, width: W, bottom: H, fill: NIGHT_FIRE.hill }) +
  pineRow({ from: -20, to: 360, y: 350, hMin: 90, hMax: 160, seed: 4, fill: NIGHT_FIRE.trees }) +
  pineRow({ from: 840, to: 1220, y: 350, hMin: 90, hMax: 160, seed: 5, fill: NIGHT_FIRE.trees });

function variantA() {
  return sky + campTrees + glowAt(600, 380, 380, 230) + sparks(600, 370, 16, 60, 360) + animatedFire(600, 388, 1);
}

function variantB() {
  const rand = rng(12);
  let stones = '';
  for (let i = 0; i < 11; i++) {
    const a = (i / 11) * Math.PI * 2;
    const x = 600 + Math.cos(a) * 92;
    const y = 368 + Math.sin(a) * 18;
    const lit = Math.sin(a) > 0 ? NIGHT_FIRE.stoneLit : NIGHT_FIRE.stone;
    stones += `<ellipse cx="${r1(x)}" cy="${r1(y)}" rx="${r1(15 + rand() * 5)}" ry="${r1(8 + rand() * 3)}" fill="${lit}"/>`;
  }
  const bench = (x, y, w) =>
    `<rect x="${x}" y="${y}" width="${w}" height="16" rx="8" fill="${NIGHT_FIRE.log}"/><rect x="${x}" y="${y}" width="${w}" height="5" rx="2.5" fill="${NIGHT_FIRE.logLit}" opacity="0.8"/>`;
  return (
    sky +
    campTrees +
    `<ellipse cx="600" cy="372" rx="260" ry="38" fill="${NIGHT_FIRE.glow}" opacity="0.12"/>` +
    glowAt(600, 350, 420, 250) +
    bench(360, 376, 150) +
    bench(700, 380, 160) +
    stones +
    sparks(600, 330, 20, 70, 340) +
    animatedFire(600, 366, 1.35)
  );
}

function variantC() {
  const hill = `<path d="M-40 400 L-40 360 Q300 330 560 318 Q720 310 900 330 Q1080 348 1240 340 L1240 400 Z" fill="${NIGHT_FIRE.trees}"/>`;
  return (
    sky +
    ridge({ y: 290, amp: 20, seed: 3, width: W, bottom: H, fill: NIGHT_FIRE.hill }) +
    pineRow({ from: -20, to: 300, y: 350, hMin: 90, hMax: 160, seed: 4, fill: NIGHT_FIRE.trees }) +
    pineRow({ from: 960, to: 1220, y: 350, hMin: 90, hMax: 160, seed: 5, fill: NIGHT_FIRE.trees }) +
    hill +
    glowAt(680, 300, 360, 220) +
    kohte(540, 322, 120, { cloth: NIGHT_FIRE.cloth, light: '#ffb45c', lit: true, seams: true }) +
    sparks(680, 280, 16, 50, 300) +
    animatedFire(680, 318, 0.9)
  );
}

function variantD() {
  const farHill = `<path d="M-40 400 L-40 250 Q260 236 470 214 Q600 200 730 214 Q940 236 1240 250 L1240 400 Z" fill="${NIGHT_FIRE.hill}"/>`;
  return (
    sky +
    farHill +
    glowAt(600, 205, 300, 160) +
    `<ellipse cx="600" cy="214" rx="130" ry="9" fill="#5a2e1a" opacity="0.7"/>` +
    `<ellipse cx="600" cy="213" rx="60" ry="5" fill="#8a4a26" opacity="0.6"/>` +
    sparks(600, 195, 14, 30, 200) +
    animatedFire(600, 208, 0.6) +
    pineRow({ from: -20, to: 1220, y: 360, hMin: 70, hMax: 140, seed: 6, fill: NIGHT_FIRE.trees, gap: 0.8 })
  );
}

const BUILDERS = { a: variantA, b: variantB, c: variantC, d: variantD };

export function buildLagerfeuerNachtEntwurf(id) {
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${W} ${H}" preserveAspectRatio="xMidYMax slice"><title>lagerfeuer nacht entwurf ${id}</title><style>${FIRE_CSS}</style>${BUILDERS[id]()}</svg>\n`;
}

// Vorschauseite: ganze Szene, Handy-Kopf ohne UI und mit Suchleiste.
export function buildLagerfeuerNachtPage() {
  const phone = (src, withUi, lifted = false) => `<figure class="phone${lifted ? ' lifted' : ''}">
<div class="screen">
<img src="${src}" alt="">
<span class="island"></span>
${withUi ? '<span class="load">Mitglieder laden</span><span class="search">Suche nach Name, Mail oder ID</span><span class="chips"><i>Wölflinge</i><i>Jufis</i><i>Pfadis</i><i>Rover</i></span>' : ''}
</div>
<figcaption>${lifted ? 'Andere Verankerung: Szene endet über der Suche' : withUi ? 'Im Header mit Lade-Info, Suche und Gruppenfilter' : 'Nur die Animation'}</figcaption>
</figure>`;
  const rows = [
    { id: 'aktuell', label: 'Aktuell: nur Glut und Funken', hint: 'Zum Vergleich der freigegebene Stand.', src: 'backgrounds/lagerfeuer-dark.svg' },
    ...ENTWUERFE.map((e) => ({ ...e, src: `backgrounds/entwurf-lagerfeuer-nacht-${e.id}.svg` })),
  ]
    .map(
      (r) => `<section>
<h2>${r.label}</h2>
<p>${r.hint}</p>
<img class="wide" src="${r.src}" alt="${r.label}">
<div class="phones">${phone(r.src, false)}${phone(r.src, true)}${phone(r.src, true, true)}</div>
</section>`,
    )
    .join('');
  return `<!doctype html>
<html lang="de">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Entwurf: Lagerfeuer bei Nacht</title>
<style>
body { margin:0; background:#121814; color:#e4eae3; font:17px/1.5 system-ui, sans-serif; }
main { max-width:1260px; margin:0 auto; padding:32px 24px 64px; }
h1 { font-size:2.2rem; margin:0 0 .4rem; }
h2 { font-size:1.3rem; margin:0 0 .2rem; }
p { color:#9aa69e; margin:0 0 1rem; max-width:65ch; }
section { border-top:1px solid #2b352f; padding:28px 0; }
.wide { width:100%; aspect-ratio:3/1; display:block; border-radius:16px; object-fit:cover; }
.phones { display:flex; gap:20px; margin-top:16px; flex-wrap:wrap; }
.phone { margin:0; width:390px; }
.screen { position:relative; height:230px; overflow:hidden; border-radius:28px 28px 0 0; }
.phone img { width:390px; height:230px; object-fit:cover; object-position:bottom; display:block; }
.phone .island { position:absolute; top:12px; left:50%; transform:translateX(-50%); width:120px; height:34px; border-radius:17px; background:#000; }
.phone .load { position:absolute; top:59px; left:0; right:0; padding:8px 16px; background:rgba(26,26,34,.6); font-size:14px; }
.phone .chips { position:absolute; top:186px; left:16px; right:16px; display:flex; gap:8px; }
.phone .chips i { font-style:normal; font-size:13px; padding:6px 12px; border-radius:10px; background:#1a1a22; border:1px solid #2e2e3a; color:#c9c9d4; }
.phone .search { position:absolute; top:128px; left:16px; right:16px; height:44px; border-radius:22px; background:#2e2e3a; color:#8a8a9a; padding:11px 16px; box-sizing:border-box; font-size:15px; }
.phone.lifted .screen { background:#24170f; }
.phone.lifted img { height:128px; }
figcaption { font-size:14px; color:#9aa69e; margin-top:6px; }
</style>
</head>
<body>
<main>
<h1>Lagerfeuer bei Nacht</h1>
<p>Vier Entwürfe mit sichtbarem Feuer. Jeweils die ganze Szene, der Kopf der Mitgliederliste ohne Oberfläche, mit Lade-Info, Suche und Gruppenfilter, und rechts eine alternative Verankerung, bei der die Szene über der Suchleiste endet.</p>
${rows}
</main>
</body>
</html>
`;
}

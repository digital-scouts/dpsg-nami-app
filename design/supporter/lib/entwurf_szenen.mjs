// Entwuerfe: Varianten fuer die uebrigen Hintergrund-Szenen (Feedback-Runde).
// Je Szene der aktuelle Stand plus zwei Varianten, gleiche Verankerung wie in
// der App (Szene unten buendig, unterer Teil liegt hinter Suche und Filter).
import { rng, r1, mix, ridge, pineRow, kohte } from './util.mjs';
import { P, W, H, style, sky, BIRD_CSS, birds, DRAGONFLY_CSS, dragonfly, FOREST_CSS, forest, SHOOTING } from './backgrounds.mjs';
import { FIRE_CSS, NIGHT_FIRE, animatedFire } from './entwurf_lagerfeuer_nacht.mjs';

const svg = (title, body) =>
  `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${W} ${H}" preserveAspectRatio="xMidYMax slice"><title>${title}</title>${body}</svg>\n`;

const blurDefs = `<defs><filter id="soft" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="8"/></filter><filter id="softer" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="22"/></filter></defs>`;

// ------------------------------------------------------------- Bausteine

const SMOKE_CSS = `
.smoke { animation-name: smoke; animation-timing-function: ease-out; animation-iteration-count: infinite; opacity: 0; transform-box: fill-box; transform-origin: center; }
@keyframes smoke { 0% { transform: translate(0,0) scale(.6); opacity: 0; } 15% { opacity: .3; } 100% { transform: translate(var(--dx), var(--dy)) scale(3); opacity: 0; } }`;

function smoke(x, y, count, rise, color, seed = 17, size = 1) {
  const rand = rng(seed);
  let out = '';
  for (let i = 0; i < count; i++) {
    const dur = 13 + rand() * 5;
    out += `<ellipse class="smoke" cx="${x}" cy="${y}" rx="${r1(22 * size)}" ry="${r1(17 * size)}" fill="${color}" filter="url(#soft)" style="--dx:${r1(50 + rand() * 80)}px;--dy:${-rise}px;animation-duration:${r1(dur)}s;animation-delay:${r1(-(i / count) * dur)}s"/>`;
  }
  return out;
}

function stoneRing(x, y, rx, ry, dark, lit, seed = 12) {
  const rand = rng(seed);
  let out = '';
  for (let i = 0; i < 11; i++) {
    const a = (i / 11) * Math.PI * 2;
    out += `<ellipse cx="${r1(x + Math.cos(a) * rx)}" cy="${r1(y + Math.sin(a) * ry)}" rx="${r1(15 + rand() * 5)}" ry="${r1(8 + rand() * 3)}" fill="${Math.sin(a) > 0 ? lit : dark}"/>`;
  }
  return out;
}

const bench = (x, y, w, log, top) =>
  `<rect x="${x}" y="${y}" width="${w}" height="16" rx="8" fill="${log}"/><rect x="${x}" y="${y}" width="${w}" height="5" rx="2.5" fill="${top}" opacity="0.8"/>`;

const DAY_FIRE = {
  ...NIGHT_FIRE,
  glow: '#f2a063',
  log: '#7a5a44',
  logLit: '#a07a5c',
  flameOuter: '#e8703a',
  flameMid: '#f5ab58',
  flameInner: '#ffe0a0',
};

function cloud(x, y, s, o, color, cls) {
  return `<g class="${cls}"><g transform="translate(${x} ${y}) scale(${s})" opacity="${o}"><ellipse cx="0" cy="0" rx="70" ry="22" fill="${color}"/><ellipse cx="-28" cy="-14" rx="34" ry="24" fill="${color}"/><ellipse cx="20" cy="-20" rx="40" ry="28" fill="${color}"/></g></g>`;
}

const CLOUD_CSS = `
.cl1 { animation: cloud 110s linear infinite; }
.cl2 { animation: cloud 80s linear infinite; animation-delay: -40s; }
.cl3 { animation: cloud 140s linear infinite; animation-delay: -90s; }
@keyframes cloud { from { transform: translateX(-300px); } to { transform: translateX(${W + 300}px); } }`;

const TWINKLE_CSS = `
.tw { animation-name: twinkle; animation-timing-function: ease-in-out; animation-iteration-count: infinite; animation-direction: alternate; opacity: var(--o); }
@keyframes twinkle { from { opacity: var(--o); } to { opacity: calc(var(--o) * .15); } }
.shoot { animation-name: shoot; animation-timing-function: cubic-bezier(.3,.1,.6,1); animation-iteration-count: infinite; opacity: 0; }
@keyframes shoot { 0%, 80% { opacity: 0; transform: translate(0,0); } 82% { opacity: .9; } 92% { opacity: 0; transform: translate(var(--tx), var(--ty)); } 100% { opacity: 0; transform: translate(var(--tx), var(--ty)); } }`;

function twinkleStars(count, seed, color, { yMax = 300, band = null } = {}) {
  const rand = rng(seed);
  let out = '';
  for (let i = 0; i < count; i++) {
    let x = rand() * W;
    let y = rand() * yMax;
    if (band) {
      // Sterne entlang einer Diagonale verdichten (Milchstrasse).
      const t = rand();
      const spread = (rand() + rand() + rand() - 1.5) * band.width;
      x = band.x0 + (band.x1 - band.x0) * t - spread * band.ny;
      y = band.y0 + (band.y1 - band.y0) * t + spread * band.nx;
    }
    const r = 0.7 + rand() ** 3 * 2.2;
    const dur = 3 + rand() * 4;
    out += `<circle class="tw" cx="${r1(x)}" cy="${r1(y)}" r="${r1(r)}" fill="${color}" style="animation-duration:${r1(dur)}s;animation-delay:${r1(-rand() * dur)}s;--o:${r1(0.45 + rand() * 0.45)}"/>`;
  }
  return out;
}

function shootingStars(color) {
  return SHOOTING.map((sh, i) => {
    const len = Math.hypot(sh.tx, sh.ty);
    const ex = r1(sh.x - (sh.tx / len) * 110);
    const ey = r1(sh.y - (sh.ty / len) * 110);
    return `<g class="shoot" style="--tx:${sh.tx}px;--ty:${sh.ty}px;animation-duration:${sh.dur}s;animation-delay:${sh.delay}s"><defs><linearGradient id="tail${i}" gradientUnits="userSpaceOnUse" x1="${sh.x}" y1="${sh.y}" x2="${ex}" y2="${ey}"><stop offset="0" stop-color="${color}"/><stop offset="1" stop-color="${color}" stop-opacity="0"/></linearGradient></defs><line x1="${sh.x}" y1="${sh.y}" x2="${ex}" y2="${ey}" stroke="url(#tail${i})" stroke-width="2.4" stroke-linecap="round"/><circle cx="${sh.x}" cy="${sh.y}" r="2.2" fill="${color}"/></g>`;
  }).join('');
}

// Weicher Lichthof mit Verlauf statt flacher Scheibe.
function halo(id, cx, cy, r, color, strength) {
  return `<defs><radialGradient id="${id}"><stop offset="0" stop-color="${color}" stop-opacity="${strength}"/><stop offset="0.4" stop-color="${color}" stop-opacity="${r1(strength * 0.4)}"/><stop offset="1" stop-color="${color}" stop-opacity="0"/></radialGradient></defs><circle class="breathe" cx="${cx}" cy="${cy}" r="${r}" fill="url(#${id})"/>`;
}

const BREATHE_CSS = `
.breathe { animation: breathe 9s ease-in-out infinite alternate; transform-box: fill-box; transform-origin: center; }
@keyframes breathe { from { opacity: .7; transform: scale(1); } to { opacity: 1; transform: scale(1.06); } }`;

// ------------------------------------------------------------ Lagerfeuer Tag

function lagerfeuerTagSitzkreis() {
  const c = P.lagerfeuer.light;
  return (
    style(`${FIRE_CSS}${SMOKE_CSS}${BIRD_CSS}`) +
    sky(c) +
    blurDefs +
    birds([{ y: 90, dir: 1, dur: 46, delay: -8, count: 3 }], c.bird) +
    ridge({ y: 300, amp: 22, seed: 3, width: W, bottom: H, fill: c.hill }) +
    pineRow({ from: -20, to: 360, y: 350, hMin: 90, hMax: 160, seed: 4, fill: c.trees }) +
    pineRow({ from: 840, to: 1220, y: 350, hMin: 90, hMax: 160, seed: 5, fill: c.trees }) +
    `<ellipse cx="600" cy="372" rx="260" ry="36" fill="${mix(c.hill, '#ffffff', 0.25)}"/>` +
    bench(360, 376, 150, DAY_FIRE.log, DAY_FIRE.logLit) +
    bench(700, 380, 160, DAY_FIRE.log, DAY_FIRE.logLit) +
    stoneRing(600, 368, 92, 18, '#a8977f', '#c7b69c') +
    smoke(600, 300, 7, 300, c.smoke) +
    animatedFire(600, 366, 1.1, DAY_FIRE)
  );
}

function lagerfeuerTagZeltlager() {
  const c = P.lagerfeuer.light;
  const mist = `<rect class="mist" x="-200" y="250" width="1600" height="60" rx="30" fill="#ffffff" opacity="0.45" filter="url(#softer)"/>`;
  return (
    style(`${FIRE_CSS}${SMOKE_CSS}${BIRD_CSS}
.mist { animation: drift 40s ease-in-out infinite alternate; }
@keyframes drift { from { transform: translateX(-160px); } to { transform: translateX(160px); } }`) +
    sky(c) +
    blurDefs +
    birds(
      [
        { y: 80, dir: 1, dur: 46, delay: -8, count: 3 },
        { y: 130, dir: -1, dur: 58, delay: -30, count: 2, size: 0.8 },
      ],
      c.bird,
    ) +
    ridge({ y: 290, amp: 24, seed: 3, width: W, bottom: H, fill: c.hill }) +
    mist +
    pineRow({ from: -20, to: 300, y: 350, hMin: 90, hMax: 160, seed: 4, fill: c.trees }) +
    pineRow({ from: 960, to: 1220, y: 350, hMin: 90, hMax: 160, seed: 5, fill: c.trees }) +
    kohte(470, 330, 120, { cloth: '#3d3530', light: '#e8c9a0', lit: false }) +
    kohte(760, 322, 95, { cloth: '#453c36', light: '#e8c9a0', lit: false }) +
    smoke(615, 290, 6, 280, c.smoke, 23, 0.8) +
    animatedFire(615, 336, 0.7, DAY_FIRE)
  );
}

// Ausgebranntes Feuer: verkohlte Scheite, schwache Glut, kraeftiger Rauch.
function lagerfeuerTagAusgebrannt() {
  const c = P.lagerfeuer.light;
  const charred = [-12, 14, 0]
    .map(
      (deg, i) =>
        `<g transform="rotate(${deg} 600 ${366 + i})"><rect x="548" y="${360 + i * 2}" width="104" height="13" rx="6.5" fill="#4a3a30"/><rect x="560" y="${360 + i * 2}" width="30" height="4" rx="2" fill="#8c8278" opacity="0.8"/></g>`,
    )
    .join('');
  return (
    style(`${SMOKE_CSS}${BIRD_CSS}
.ember { animation: ember 6s ease-in-out infinite alternate; transform-box: fill-box; transform-origin: center; }
@keyframes ember { from { opacity: .25; } to { opacity: .6; } }`) +
    sky(c) +
    blurDefs +
    birds([{ y: 90, dir: 1, dur: 46, delay: -8, count: 3 }], c.bird) +
    ridge({ y: 300, amp: 22, seed: 3, width: W, bottom: H, fill: c.hill }) +
    pineRow({ from: -20, to: 360, y: 350, hMin: 90, hMax: 160, seed: 4, fill: c.trees }) +
    pineRow({ from: 840, to: 1220, y: 350, hMin: 90, hMax: 160, seed: 5, fill: c.trees }) +
    `<ellipse cx="600" cy="372" rx="260" ry="36" fill="${mix(c.hill, '#ffffff', 0.25)}"/>` +
    bench(360, 376, 150, DAY_FIRE.log, DAY_FIRE.logLit) +
    bench(700, 380, 160, DAY_FIRE.log, DAY_FIRE.logLit) +
    stoneRing(600, 368, 92, 18, '#a8977f', '#c7b69c') +
    `<ellipse cx="600" cy="370" rx="46" ry="9" fill="#5a4a40"/>` +
    charred +
    `<ellipse class="ember" cx="596" cy="366" rx="18" ry="4" fill="#e9713a"/>` +
    `<ellipse class="ember" cx="614" cy="369" rx="9" ry="2.5" fill="#f08a45" style="animation-delay:-2.5s"/>` +
    smoke(600, 352, 10, 320, c.smoke, 19, 0.9)
  );
}

// ---------------------------------------------------------------- Himmel Tag

function himmelTagSonne() {
  const c = { ...P.sternenhimmel.light, top: '#b3cde6', bottom: '#f7e6cf' };
  const rays = Array.from({ length: 8 }, (_, i) => {
    const a = (i / 8) * 360;
    return `<path d="M-6 -70 L6 -70 L40 -260 L-40 -260 Z" fill="#fff4dc" opacity="0.14" transform="rotate(${a})"/>`;
  }).join('');
  return (
    style(`${CLOUD_CSS}${BIRD_CSS}${BREATHE_CSS}
.sunrays { animation: spin 120s linear infinite; transform-box: view-box; transform-origin: 900px 210px; }
@keyframes spin { to { transform: rotate(360deg); } }`) +
    sky(c) +
    `<g class="sunrays"><g transform="translate(900 210)">${rays}</g></g>` +
    halo('sunHalo', 900, 210, 150, '#fff4dc', 0.7) +
    `<circle cx="900" cy="210" r="42" fill="#fff1d0"/>` +
    cloud(0, 100, 1.1, 0.85, c.cloud, 'cl1') +
    cloud(0, 170, 0.8, 0.7, c.cloud, 'cl2') +
    birds([{ y: 120, dir: -1, dur: 40, delay: -12, count: 5 }], c.bird) +
    ridge({ y: 330, amp: 26, seed: 8, width: W, bottom: H, fill: c.hill }) +
    pineRow({ from: -20, to: 1220, y: 380, hMin: 50, hMax: 90, seed: 9, fill: c.trees, gap: 0.9 })
  );
}

function himmelTagWeite() {
  const c = P.sternenhimmel.light;
  const camp = [420, 520, 640]
    .map((x, i) => kohte(x, 262 + (i % 2) * 4, 38 - i * 4, { cloth: '#6f7c84', light: '#e8c9a0', lit: false, seams: false }))
    .join('');
  return (
    style(`${CLOUD_CSS}${BIRD_CSS}${SMOKE_CSS}`) +
    sky(c) +
    blurDefs +
    cloud(0, 80, 1.2, 0.85, c.cloud, 'cl1') +
    cloud(0, 150, 0.8, 0.7, c.cloud, 'cl2') +
    cloud(0, 50, 0.6, 0.6, c.cloud, 'cl3') +
    birds(
      [
        { y: 100, dir: 1, dur: 38, delay: -5, count: 5 },
        { y: 60, dir: -1, dur: 52, delay: -26, count: 3, size: 0.8 },
      ],
      c.bird,
    ) +
    ridge({ y: 262, amp: 14, seed: 30, width: W, bottom: H, fill: mix(c.hill, '#ffffff', 0.35) }) +
    camp +
    smoke(580, 250, 5, 160, '#9aa6ad', 31, 0.45) +
    ridge({ y: 330, amp: 26, seed: 8, width: W, bottom: H, fill: c.hill }) +
    pineRow({ from: -20, to: 1220, y: 380, hMin: 50, hMax: 90, seed: 9, fill: c.trees, gap: 0.9 })
  );
}

// -------------------------------------------------------------- Himmel Nacht

function himmelNachtMond() {
  const c = P.sternenhimmel.dark;
  return (
    style(`${TWINKLE_CSS}${BREATHE_CSS}`) +
    sky(c) +
    twinkleStars(110, 41, c.star) +
    halo('moonHalo', 880, 120, 120, '#dfe8f5', 0.28) +
    `<circle cx="880" cy="120" r="32" fill="#eef1f4"/><circle cx="870" cy="112" r="6" fill="#000" opacity="0.06"/><circle cx="892" cy="128" r="8" fill="#000" opacity="0.05"/>` +
    shootingStars(c.star) +
    ridge({ y: 330, amp: 26, seed: 8, width: W, bottom: H, fill: c.hill }) +
    pineRow({ from: -20, to: 1220, y: 380, hMin: 50, hMax: 90, seed: 9, fill: c.trees, gap: 0.9 })
  );
}

function himmelNachtMilchstrasse() {
  const c = P.sternenhimmel.dark;
  const band = { x0: 60, y0: 20, x1: 1140, y1: 260, width: 70 };
  const len = Math.hypot(band.x1 - band.x0, band.y1 - band.y0);
  band.nx = (band.x1 - band.x0) / len;
  band.ny = (band.y1 - band.y0) / len;
  const angle = (Math.atan2(band.y1 - band.y0, band.x1 - band.x0) * 180) / Math.PI;
  return (
    style(`${TWINKLE_CSS}
.haze { animation: haze 14s ease-in-out infinite alternate; }
@keyframes haze { from { opacity: .10; } to { opacity: .2; } }`) +
    sky(c) +
    blurDefs +
    `<ellipse class="haze" cx="600" cy="140" rx="620" ry="60" fill="#b9c3ef" filter="url(#softer)" transform="rotate(${r1(angle)} 600 140)"/>` +
    twinkleStars(80, 21, c.star) +
    twinkleStars(220, 51, c.star, { band }) +
    shootingStars(c.star) +
    ridge({ y: 330, amp: 26, seed: 8, width: W, bottom: H, fill: c.hill }) +
    pineRow({ from: -20, to: 1220, y: 380, hMin: 50, hMax: 90, seed: 9, fill: c.trees, gap: 0.9 })
  );
}

// ------------------------------------------------------------------ Wald Tag

function waldTagSee() {
  const c = P.wald.light;
  const rand = rng(5);
  let shine = '';
  for (let i = 0; i < 10; i++) {
    const dur = 5 + rand() * 4;
    shine += `<rect class="sh" x="${r1(200 + rand() * 800)}" y="${r1(338 + i * 5)}" width="${r1(40 + rand() * 60)}" height="2.5" rx="1.2" fill="#ffffff" style="animation-duration:${r1(dur)}s;animation-delay:${r1(-rand() * dur)}s"/>`;
  }
  let reeds = '';
  for (let i = 0; i < 14; i++) {
    const x = i < 7 ? 190 + i * 12 : 900 + (i - 7) * 12;
    const h = 40 + rand() * 40;
    reeds += `<path d="M${r1(x)} 350 Q${r1(x + 4)} ${r1(350 - h * 0.6)} ${r1(x + 10)} ${r1(350 - h)}" stroke="${c.near}" stroke-width="3" fill="none" stroke-linecap="round"/>`;
  }
  const flies = [
    dragonfly({ y: 300, dir: 1, dur: 30, delay: -4, color: c.fly }),
    dragonfly({ y: 270, dir: -1, dur: 38, delay: -20, color: c.fly }),
  ].join('');
  return (
    style(`${FOREST_CSS}${DRAGONFLY_CSS}
.sh { animation-name: shimmer; animation-timing-function: ease-in-out; animation-iteration-count: infinite; animation-direction: alternate; opacity: .5; transform-box: fill-box; transform-origin: center; }
@keyframes shimmer { from { opacity: .55; transform: scaleX(1); } to { opacity: .15; transform: scaleX(.6); } }`) +
    sky(c) +
    `<defs><filter id="fogBlur" x="-20%" y="-100%" width="140%" height="300%"><feGaussianBlur stdDeviation="14"/></filter></defs>` +
    `<g class="l1">${pineRow({ from: -60, to: 1260, y: 330, hMin: 120, hMax: 200, seed: 1, fill: c.far, gap: 0.42 })}</g>` +
    `<rect x="0" y="330" width="${W}" height="70" fill="#c9dcd6"/>` +
    shine +
    reeds +
    flies +
    `<g class="l3">${pineRow({ from: -80, to: 180, y: 420, hMin: 300, hMax: 380, seed: 3, fill: c.near })}${pineRow({ from: 1030, to: 1290, y: 420, hMin: 300, hMax: 380, seed: 4, fill: c.near })}</g>`
  );
}

function waldTagBlaetter() {
  const c = P.wald.light;
  const rand = rng(9);
  let leaves = '';
  const colors = ['#c9a14a', '#b9793a', '#9fb66a'];
  for (let i = 0; i < 16; i++) {
    const dur = 14 + rand() * 10;
    leaves += `<g class="leaf" style="--x0:${r1(rand() * W)}px;--dx:${r1(-80 - rand() * 160)}px;animation-duration:${r1(dur)}s;animation-delay:${r1(-rand() * dur)}s"><ellipse class="spin" cx="0" cy="0" rx="6" ry="3" fill="${colors[i % 3]}" style="animation-duration:${r1(3 + rand() * 3)}s"/></g>`;
  }
  return (
    style(`${FOREST_CSS}${BIRD_CSS}
.leaf { animation-name: fall; animation-timing-function: linear; animation-iteration-count: infinite; }
@keyframes fall { 0% { transform: translate(var(--x0), -20px); opacity: 0; } 10% { opacity: .9; } 50% { transform: translate(calc(var(--x0) + var(--dx) * .5 + 30px), 200px); } 90% { opacity: .8; } 100% { transform: translate(calc(var(--x0) + var(--dx)), 400px); opacity: 0; } }
.spin { animation-name: spin; animation-timing-function: ease-in-out; animation-iteration-count: infinite; animation-direction: alternate; transform-box: fill-box; transform-origin: center; }
@keyframes spin { from { transform: rotate(-40deg) scaleY(1); } to { transform: rotate(50deg) scaleY(.4); } }`) +
    sky(c) +
    birds([{ y: 70, dir: 1, dur: 44, delay: -10, count: 3, size: 0.8 }], '#5d6b5f') +
    forest(c, 0.5, '') +
    leaves
  );
}

// ---------------------------------------------------------------- Wald Nacht

function fireflies(count, seed, color, peak = 0.7) {
  const rand = rng(seed);
  let out = '';
  for (let i = 0; i < count; i++) {
    const x = rand() * W;
    const y = 160 + rand() * 220;
    const dur = 9 + rand() * 6;
    const r = 1.6 + rand() * 1.4;
    out += `<g class="bug" style="--dx:${r1((rand() - 0.5) * 80)}px;--dy:${r1(-15 - rand() * 40)}px;animation-duration:${r1(dur)}s;animation-delay:${r1(-rand() * dur)}s"><circle cx="${r1(x)}" cy="${r1(y)}" r="${r1(r * 3)}" fill="${color}" opacity="0.14"/><circle cx="${r1(x)}" cy="${r1(y)}" r="${r1(r)}" fill="${color}"/></g>`;
  }
  return (
    out +
    `<style>.bug { animation-name: float; animation-timing-function: ease-in-out; animation-iteration-count: infinite; opacity: 0; }
@keyframes float { 0% { transform: translate(0,0); opacity: 0; } 30% { opacity: ${peak}; } 55% { transform: translate(calc(var(--dx) * .6), calc(var(--dy) * .5)); opacity: ${peak / 2}; } 75% { opacity: ${peak}; } 100% { transform: translate(var(--dx), var(--dy)); opacity: 0; } }</style>`
  );
}

function waldNachtMond() {
  const c = P.wald.dark;
  const beams = [
    [760, 200],
    [880, 150],
  ]
    .map(([x, w], i) => `<path class="beam" style="animation-delay:${-i * 4}s" d="M${x + 180} 60 L${x + 220} 60 L${x + 40} ${H} L${x - w + 40} ${H} Z" fill="#b9cfee"/>`)
    .join('');
  return (
    style(`${FOREST_CSS}${BREATHE_CSS}
.beam { animation: beam 12s ease-in-out infinite alternate; opacity: .05; }
@keyframes beam { from { opacity: .03; } to { opacity: .12; } }`) +
    sky(c) +
    halo('moonHaloWald', 960, 80, 110, '#dfe8f2', 0.25) +
    `<circle cx="960" cy="80" r="26" fill="#e9eef5"/>` +
    beams +
    forest(c, 0.4, '') +
    fireflies(10, 71, c.bug, 0.6)
  );
}

function waldNachtKohte() {
  const c = P.wald.dark;
  return (
    style(FOREST_CSS) +
    sky(c) +
    `<defs><filter id="fogBlur" x="-20%" y="-100%" width="140%" height="300%"><feGaussianBlur stdDeviation="14"/></filter><radialGradient id="kg"><stop offset="0" stop-color="#ffb45c" stop-opacity="0.35"/><stop offset="1" stop-color="#ffb45c" stop-opacity="0"/></radialGradient></defs>` +
    `<g class="l1">${pineRow({ from: -60, to: 1260, y: 330, hMin: 120, hMax: 200, seed: 1, fill: c.far, gap: 0.42 })}</g>` +
    `<rect class="fog" x="-250" y="250" width="1700" height="70" rx="35" fill="${c.fog}" opacity="0.25" filter="url(#fogBlur)"/>` +
    `<ellipse cx="600" cy="300" rx="200" ry="70" fill="url(#kg)"/>` +
    kohte(600, 312, 130, { cloth: '#070a08', light: '#ffb45c', lit: true }) +
    `<g class="l2">${pineRow({ from: -60, to: 430, y: 380, hMin: 160, hMax: 260, seed: 2, fill: c.mid, gap: 0.5 })}${pineRow({ from: 780, to: 1260, y: 380, hMin: 160, hMax: 260, seed: 12, fill: c.mid, gap: 0.5 })}</g>` +
    `<g class="l3">${pineRow({ from: -80, to: 180, y: 420, hMin: 300, hMax: 380, seed: 3, fill: c.near })}${pineRow({ from: 1030, to: 1290, y: 420, hMin: 300, hMax: 380, seed: 4, fill: c.near })}</g>` +
    `<rect y="390" width="${W}" height="10" fill="${c.near}"/>` +
    fireflies(16, 33, c.bug, 0.6)
  );
}

// ------------------------------------------------------------------ Katalog

export const SZENEN = [
  {
    id: 'lagerfeuer-tag',
    label: 'Lagerfeuer, Tag',
    dark: false,
    current: 'backgrounds/lagerfeuer-light.svg',
    variants: [
      { id: 'b', label: 'B: Feuerstelle mit Sitzkreis', hint: 'Passend zur Nacht-Variante B: Steinring, Sitzbalken, kleines Feuer und Rauch.', build: lagerfeuerTagSitzkreis },
      { id: 'c', label: 'C: Zeltlager am Morgen', hint: 'Zwei Kohten, Feuer dazwischen, ziehender Morgendunst und Vögel.', build: lagerfeuerTagZeltlager },
    ],
  },
  {
    id: 'himmel-tag',
    label: 'Himmel, Tag',
    dark: false,
    current: 'backgrounds/sternenhimmel-light.svg',
    variants: [
      { id: 'b', label: 'B: Tiefe Sonne', hint: 'Warme Sonne mit langsam drehenden Strahlen, Wolken und Vogelschwarm.', build: himmelTagSonne },
      { id: 'c', label: 'C: Lager in der Weite', hint: 'Kleine Kohten auf einem fernen Hügel mit dünnem Rauch, Wolken und Vögel.', build: himmelTagWeite },
    ],
  },
  {
    id: 'himmel-nacht',
    label: 'Himmel, Nacht',
    dark: true,
    current: 'backgrounds/sternenhimmel-dark.svg',
    variants: [
      { id: 'b', label: 'B: Mondnacht', hint: 'Mond mit atmendem Lichthof, Sterne und Sternschnuppen.', build: himmelNachtMond },
      { id: 'c', label: 'C: Milchstraße', hint: 'Dichtes Sternenband mit sanftem Schimmer quer über den Himmel, dazu Sternschnuppen.', build: himmelNachtMilchstrasse },
    ],
  },
  {
    id: 'wald-tag',
    label: 'Wald, Tag',
    dark: false,
    current: 'backgrounds/wald-light.svg',
    variants: [
      { id: 'b', label: 'B: Waldsee', hint: 'Libellen über einem See mit Schilf und glitzernder Oberfläche.', build: waldTagSee },
      { id: 'c', label: 'C: Blätter im Wind', hint: 'Einzelne Blätter segeln herab, dazu ein paar Vögel über den Wipfeln.', build: waldTagBlaetter },
    ],
  },
  {
    id: 'wald-nacht',
    label: 'Wald, Nacht',
    dark: true,
    current: 'backgrounds/wald-dark.svg',
    variants: [
      { id: 'b', label: 'B: Mondlicht', hint: 'Mond über den Wipfeln, schwache Lichtbahnen, Nebel und nur wenige Glühwürmchen.', build: waldNachtMond },
      { id: 'c', label: 'C: Kohte im Wald', hint: 'Eine leuchtende Kohte auf einer Lichtung, Nebel und Glühwürmchen.', build: waldNachtKohte },
    ],
  },
];

export function buildSzenenEntwurf(szene, variant) {
  return svg(`${szene.id} ${variant.id}`, variant.build());
}

// Vorschauseite: ganze Szene, Handy-Kopf ohne UI und mit Suche und Filter.
const PAGE_CSS = `body { margin:0; background:#121814; color:#e4eae3; font:17px/1.5 system-ui, sans-serif; }
main { max-width:1100px; margin:0 auto; padding:32px 24px 64px; }
h1 { font-size:2.2rem; margin:0 0 .4rem; }
h2 { font-size:1.6rem; margin:0 0 .6rem; }
h3 { font-size:1.15rem; margin:0 0 .2rem; }
p { color:#9aa69e; margin:0 0 1rem; max-width:65ch; }
nav { display:flex; gap:12px; flex-wrap:wrap; margin:1rem 0 0; }
nav a { color:#e0b155; }
section { border-top:1px solid #2b352f; padding:28px 0 8px; }
.row { margin-bottom:36px; }
.tag { font-size:.8rem; font-weight:600; background:#3a2f18; color:#e0b155; border-radius:999px; padding:2px 10px; vertical-align:middle; }
.wide { width:100%; aspect-ratio:3/1; display:block; border-radius:16px; object-fit:cover; }
.phones { display:flex; gap:20px; margin-top:16px; flex-wrap:wrap; }
.phone { margin:0; width:390px; }
.screen { position:relative; height:230px; overflow:hidden; border-radius:28px 28px 0 0; }
.phone img { width:390px; height:230px; object-fit:cover; object-position:bottom; display:block; }
.island { position:absolute; top:12px; left:50%; transform:translateX(-50%); width:120px; height:34px; border-radius:17px; background:#000; }
.load { position:absolute; top:59px; left:0; right:0; padding:8px 16px; font-size:14px; }
.search { position:absolute; top:128px; left:16px; right:16px; height:44px; border-radius:22px; padding:11px 16px; box-sizing:border-box; font-size:15px; }
.chips { position:absolute; top:186px; left:16px; right:16px; display:flex; gap:8px; }
.chips i { font-style:normal; font-size:13px; padding:6px 12px; border-radius:10px; }
.dark .load { background:rgba(26,26,34,.6); color:#f0f0f5; }
.dark .search { background:#2e2e3a; color:#8a8a9a; }
.dark .chips i { background:#1a1a22; border:1px solid #2e2e3a; color:#c9c9d4; }
.light .load { background:rgba(255,255,255,.6); color:#1c1c1e; }
.light .search { background:#f5f5f7; color:#8e8e93; }
.light .chips i { background:#ffffff; border:1px solid #e5e5ea; color:#1c1c1e; }
figcaption { font-size:14px; color:#9aa69e; margin-top:6px; }
`;

// Handy-Vorschau und Zeile fuer die Entwurfsseiten.
const phone = (src, withUi, dark) => `<figure class="phone ${dark ? 'dark' : 'light'}">
<div class="screen">
<img src="${src}" alt="">
<span class="island"></span>
${withUi ? '<span class="load">Mitglieder laden</span><span class="search">Suche nach Name, Mail oder ID</span><span class="chips"><i>Wölflinge</i><i>Jufis</i><i>Pfadis</i><i>Rover</i></span>' : ''}
</div>
<figcaption>${withUi ? 'Im Header mit Lade-Info, Suche und Gruppenfilter' : 'Nur die Animation'}</figcaption>
</figure>`;
const row = (label, hint, src, dark, tag) => `<div class="row">
<h3>${label}${tag ? ` <span class="tag">${tag}</span>` : ''}</h3>
<p>${hint}</p>
<img class="wide" src="${src}" alt="${label}">
<div class="phones">${phone(src, false, dark)}${phone(src, true, dark)}</div>
</div>`;

export function buildSzenenPage() {
  const fixed = `<section>
<h2>Lagerfeuer, Nacht</h2>
${row('B: Feuerstelle mit Sitzkreis', 'Aus der letzten Runde, bisherige Verankerung.', 'backgrounds/entwurf-lagerfeuer-nacht-b.svg', true, 'festgelegt')}
</section>`;
  const sections = SZENEN.map(
    (s) => `<section>
<h2>${s.label}</h2>
${row('A: Aktuell', 'Der bisherige Stand zum Vergleich.', s.current, s.dark)}
${s.variants.map((v) => row(v.label, v.hint, `backgrounds/entwurf-${s.id}-${v.id}.svg`, s.dark)).join('')}
</section>`,
  ).join('');
  return `<!doctype html>
<html lang="de">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Entwürfe: Hintergrund-Szenen</title>
<style>
${PAGE_CSS}</style>
</head>
<body>
<main>
<h1>Hintergrund-Szenen</h1>
<p>Je Szene der aktuelle Stand (A) und zwei neue Varianten (B, C). Gleiche Verankerung wie in der App: Die Szene ist unten bündig, ihr unterer Teil liegt hinter Suche und Gruppenfilter.</p>
<nav>${[['lagerfeuer-nacht', 'Lagerfeuer, Nacht'], ...SZENEN.map((s) => [s.id, s.label])].map(([id, label]) => `<a href="#${id}">${label}</a>`).join('')}</nav>
${fixed.replace('<section>', '<section id="lagerfeuer-nacht">')}
${sections.replace(/<section>\n<h2>([^<]+)<\/h2>/g, (m, label) => {
    const s = SZENEN.find((x) => x.label === label);
    return `<section id="${s.id}">\n<h2>${label}</h2>`;
  })}
</main>
</body>
</html>
`;
}

// ------------------------------------------------------------- Runde 3

// Kleines Lager auf fernem Huegel, Kohten dicht beisammen.
function farCamp(cx, y, { cloth, lit = false, light = '#ffb45c' }) {
  const tents = [
    [-34, 0, 40],
    [0, -3, 46],
    [32, 1, 36],
  ];
  return tents
    .map(([dx, dy, h], i) => kohte(cx + dx, y + dy, h, { cloth, light, lit: lit && i === 1, seams: false }))
    .join('');
}

function himmelTagSonneLager() {
  const c = { ...P.sternenhimmel.light, top: '#b3cde6', bottom: '#f7e6cf' };
  const rays = Array.from({ length: 8 }, (_, i) => {
    const a = (i / 8) * 360;
    return `<path d="M-6 -70 L6 -70 L40 -260 L-40 -260 Z" fill="#fff4dc" opacity="0.14" transform="rotate(${a})"/>`;
  }).join('');
  return (
    style(`${CLOUD_CSS}${BIRD_CSS}${BREATHE_CSS}${SMOKE_CSS}
.sunrays { animation: spin 120s linear infinite; transform-box: view-box; transform-origin: 900px 200px; }
@keyframes spin { to { transform: rotate(360deg); } }`) +
    sky(c) +
    blurDefs +
    `<g class="sunrays"><g transform="translate(900 200)">${rays}</g></g>` +
    halo('sunHalo', 900, 200, 150, '#fff4dc', 0.7) +
    `<circle cx="900" cy="200" r="42" fill="#fff1d0"/>` +
    cloud(0, 90, 1.1, 0.85, c.cloud, 'cl1') +
    cloud(0, 150, 0.8, 0.7, c.cloud, 'cl2') +
    birds([{ y: 110, dir: -1, dur: 40, delay: -12, count: 5 }], c.bird) +
    ridge({ y: 262, amp: 14, seed: 30, width: W, bottom: H, fill: mix(c.hill, '#ffffff', 0.35) }) +
    farCamp(520, 262, { cloth: '#6f7c84' }) +
    smoke(540, 244, 5, 150, '#9aa6ad', 31, 0.45) +
    ridge({ y: 330, amp: 26, seed: 8, width: W, bottom: H, fill: c.hill }) +
    pineRow({ from: -20, to: 1220, y: 380, hMin: 50, hMax: 90, seed: 9, fill: c.trees, gap: 0.9 })
  );
}

function himmelNachtMilchstrasseLager() {
  const c = P.sternenhimmel.dark;
  const band = { x0: 60, y0: 20, x1: 1140, y1: 260, width: 70 };
  const len = Math.hypot(band.x1 - band.x0, band.y1 - band.y0);
  band.nx = (band.x1 - band.x0) / len;
  band.ny = (band.y1 - band.y0) / len;
  const angle = (Math.atan2(band.y1 - band.y0, band.x1 - band.x0) * 180) / Math.PI;
  return (
    style(`${TWINKLE_CSS}${BREATHE_CSS}
.haze { animation: haze 14s ease-in-out infinite alternate; }
@keyframes haze { from { opacity: .10; } to { opacity: .2; } }`) +
    sky(c) +
    blurDefs +
    `<ellipse class="haze" cx="600" cy="140" rx="620" ry="60" fill="#b9c3ef" filter="url(#softer)" transform="rotate(${r1(angle)} 600 140)"/>` +
    twinkleStars(80, 21, c.star) +
    twinkleStars(220, 51, c.star, { band }) +
    shootingStars(c.star) +
    ridge({ y: 262, amp: 14, seed: 30, width: W, bottom: H, fill: mix(c.hill, '#ffffff', 0.06) }) +
    halo('campGlow', 520, 256, 60, '#ffb45c', 0.35) +
    farCamp(520, 262, { cloth: '#070b16', lit: true }) +
    ridge({ y: 330, amp: 26, seed: 8, width: W, bottom: H, fill: c.hill }) +
    pineRow({ from: -20, to: 1220, y: 380, hMin: 50, hMax: 90, seed: 9, fill: c.trees, gap: 0.9 })
  );
}

// Wasserkreise: tauchen einzeln auf und laufen langsam aus.
const RIPPLE_CSS = `
.ripple { transform-box: fill-box; transform-origin: center; animation-name: ripple; animation-timing-function: ease-out; animation-iteration-count: infinite; opacity: 0; }
@keyframes ripple { 0% { transform: scale(.1); opacity: 0; } 3% { opacity: .65; } 22% { transform: scale(1); opacity: 0; } 100% { transform: scale(1); opacity: 0; } }`;

// Gleichmaessig verteilt: alle `period / count` Sekunden ein Kreis an einer
// anderen Stelle, nie mehrere gleichzeitig (kein Regen-Eindruck).
function ripples(count, seed, yMin, yMax, color, period = 18) {
  const rand = rng(seed);
  let out = '';
  for (let i = 0; i < count; i++) {
    const x = 240 + rand() * 720;
    const y = yMin + rand() * (yMax - yMin);
    const delay = -(i / count) * period;
    for (const [k, extra] of [
      [1, 0],
      [0.6, 0.5],
    ]) {
      out += `<ellipse class="ripple" cx="${r1(x)}" cy="${r1(y)}" rx="${r1(30 * k)}" ry="${r1(7 * k)}" fill="none" stroke="${color}" stroke-width="1.6" style="animation-duration:${period}s;animation-delay:${r1(delay + extra)}s"/>`;
    }
  }
  return out;
}

function lake({ top, color, shineColor, reedColor, seed = 5, shineX = null }) {
  const rand = rng(seed);
  let shine = '';
  for (let i = 0; i < 10; i++) {
    const dur = 5 + rand() * 4;
    const x = shineX == null ? 200 + rand() * 800 : shineX - 40 + (rand() - 0.5) * 60;
    shine += `<rect class="sh" x="${r1(x)}" y="${r1(top + 8 + i * 5)}" width="${r1(shineX == null ? 40 + rand() * 60 : 50 + rand() * 40)}" height="2.5" rx="1.2" fill="${shineColor}" style="animation-duration:${r1(dur)}s;animation-delay:${r1(-rand() * dur)}s"/>`;
  }
  let reeds = '';
  for (let i = 0; i < 14; i++) {
    const x = i < 7 ? 190 + i * 12 : 900 + (i - 7) * 12;
    const h = 40 + rand() * 40;
    reeds += `<path d="M${r1(x)} ${top + 20} Q${r1(x + 4)} ${r1(top + 20 - h * 0.6)} ${r1(x + 10)} ${r1(top + 20 - h)}" stroke="${reedColor}" stroke-width="3" fill="none" stroke-linecap="round"/>`;
  }
  return { water: `<rect x="0" y="${top}" width="${W}" height="${H - top}" fill="${color}"/>`, shine, reeds };
}

const SHIMMER_CSS = `
.sh { animation-name: shimmer; animation-timing-function: ease-in-out; animation-iteration-count: infinite; animation-direction: alternate; opacity: .5; transform-box: fill-box; transform-origin: center; }
@keyframes shimmer { from { opacity: .55; transform: scaleX(1); } to { opacity: .15; transform: scaleX(.6); } }`;

function waldTagSeePlaetschern() {
  const c = P.wald.light;
  const l = lake({ top: 330, color: '#c9dcd6', shineColor: '#ffffff', reedColor: c.near });
  const flies = [
    dragonfly({ y: 300, dir: 1, dur: 30, delay: -4, color: c.fly }),
    dragonfly({ y: 270, dir: -1, dur: 38, delay: -20, color: c.fly }),
  ].join('');
  return (
    style(`${FOREST_CSS}${DRAGONFLY_CSS}${SHIMMER_CSS}${RIPPLE_CSS}`) +
    sky(c) +
    `<g class="l1">${pineRow({ from: -60, to: 1260, y: 330, hMin: 120, hMax: 200, seed: 1, fill: c.far, gap: 0.42 })}</g>` +
    l.water +
    l.shine +
    ripples(5, 61, 338, 380, '#ffffff', 20) +
    l.reeds +
    flies +
    `<g class="l3">${pineRow({ from: -80, to: 180, y: 420, hMin: 300, hMax: 380, seed: 3, fill: c.near })}${pineRow({ from: 1030, to: 1290, y: 420, hMin: 300, hMax: 380, seed: 4, fill: c.near })}</g>`
  );
}

function moonReflection(x, top, color) {
  const rand = rng(44);
  let out = `<ellipse class="breathe" cx="${x}" cy="${top + 22}" rx="90" ry="16" fill="${color}" opacity="0.18" filter="url(#soft)"/>`;
  for (let i = 0; i < 16; i++) {
    const dur = 4 + rand() * 4;
    const w = 70 - i * 3 + rand() * 30;
    out += `<rect class="sh" x="${r1(x - w / 2 + (rand() - 0.5) * 24)}" y="${r1(top + 4 + i * 4)}" width="${r1(w)}" height="2.4" rx="1.2" fill="${color}" style="animation-duration:${r1(dur)}s;animation-delay:${r1(-rand() * dur)}s"/>`;
  }
  // Schwache Spiegelung der Sterne und Wipfel ueber die ganze Breite.
  for (let i = 0; i < 14; i++) {
    const dur = 6 + rand() * 5;
    out += `<rect class="sh" x="${r1(rand() * W)}" y="${r1(top + 6 + rand() * 50)}" width="${r1(16 + rand() * 30)}" height="1.6" rx="0.8" fill="${color}" opacity="0.35" style="animation-duration:${r1(dur)}s;animation-delay:${r1(-rand() * dur)}s"/>`;
  }
  return out;
}

function waldNachtMondSee() {
  const c = P.wald.dark;
  const l = lake({ top: 330, color: '#0e1a1f', shineColor: '#c9d6ea', reedColor: '#0a120e', shineX: 820 });
  // Mondlicht: zwei weiche Keile, die am Mond beginnen und nach unten
  // auslaufen (Verlauf plus Unschaerfe, kein harter Rand).
  const moon = [820, 80];
  const beams =
    `<defs><linearGradient id="beamFade" gradientUnits="userSpaceOnUse" x1="${moon[0]}" y1="${moon[1]}" x2="${moon[0] - 120}" y2="330"><stop offset="0" stop-color="#c9d9f0" stop-opacity="0.5"/><stop offset="0.5" stop-color="#c9d9f0" stop-opacity="0.18"/><stop offset="1" stop-color="#c9d9f0" stop-opacity="0"/></linearGradient><filter id="beamBlur" x="-30%" y="-10%" width="160%" height="120%"><feGaussianBlur stdDeviation="10"/></filter></defs>` +
    [
      [-200, 90, 0],
      [10, 120, -5],
    ]
      .map(
        ([dx, width, delay]) =>
          `<path class="beam" style="animation-delay:${delay}s" d="M${moon[0] - 6} ${moon[1]} L${moon[0] + 6} ${moon[1]} L${moon[0] + dx + width / 2} 330 L${moon[0] + dx - width / 2} 330 Z" fill="url(#beamFade)" filter="url(#beamBlur)"/>`,
      )
      .join('');
  return (
    style(`${FOREST_CSS}${BREATHE_CSS}${SHIMMER_CSS}${RIPPLE_CSS}${TWINKLE_CSS}
.beam { animation: beam 12s ease-in-out infinite alternate; opacity: .5; }
@keyframes beam { from { opacity: .35; } to { opacity: .7; } }`) +
    sky(c) +
    `<defs><filter id="fogBlur" x="-20%" y="-100%" width="140%" height="300%"><feGaussianBlur stdDeviation="14"/></filter></defs>` +
    blurDefs +
    twinkleStars(28, 91, '#dfe8f2', { yMax: 170 }) +
    halo('moonHaloWald', 820, 80, 110, '#dfe8f2', 0.25) +
    `<circle cx="820" cy="80" r="26" fill="#e9eef5"/>` +
    beams +
    `<g class="l1">${pineRow({ from: -60, to: 1260, y: 330, hMin: 120, hMax: 200, seed: 1, fill: c.far, gap: 0.42 })}</g>` +
    `<rect class="fog" x="-250" y="280" width="1700" height="60" rx="30" fill="${c.fog}" opacity="0.3" filter="url(#fogBlur)"/>` +
    l.water +
    moonReflection(820, 330, '#c9d6ea') +
    ripples(3, 81, 340, 380, '#9fb3cf', 21) +
    l.reeds +
    `<g class="l3">${pineRow({ from: -80, to: 180, y: 420, hMin: 300, hMax: 380, seed: 3, fill: c.near })}${pineRow({ from: 1030, to: 1290, y: 420, hMin: 300, hMax: 380, seed: 4, fill: c.near })}</g>` +
    fireflies(10, 71, c.bug, 0.6)
  );
}

export const RUNDE3 = [
  { id: 'lagerfeuer-nacht', label: 'Lagerfeuer, Nacht', dark: true, tag: 'festgelegt', title: 'B: Feuerstelle mit Sitzkreis', hint: 'Festgelegt.', src: 'backgrounds/entwurf-lagerfeuer-nacht-b.svg' },
  { id: 'lagerfeuer-tag', label: 'Lagerfeuer, Tag', dark: false, tag: 'neu', title: 'Sitzkreis, Feuer ausgebrannt', hint: 'Wie B, aber das Feuer ist heruntergebrannt: verkohlte Scheite, schwach glimmende Glut und kräftiger, ruhig aufsteigender Rauch.', build: lagerfeuerTagAusgebrannt },
  { id: 'himmel-tag', label: 'Himmel, Tag', dark: false, tag: 'unverändert', title: 'Sonne und Lager', hint: 'B und C kombiniert: tiefe Sonne mit Strahlen, Wolken und Vögel, dazu das Lager auf dem fernen Hügel mit dicht beieinander stehenden Kohten.', build: himmelTagSonneLager },
  { id: 'himmel-nacht', label: 'Himmel, Nacht', dark: true, tag: 'unverändert', title: 'Milchstraße mit Lager', hint: 'Milchstraße und Sternschnuppen, dazu dasselbe Lager wie am Tag, nachts mit einer leuchtenden Kohte.', build: himmelNachtMilchstrasseLager },
  { id: 'wald-tag', label: 'Wald, Tag', dark: false, tag: 'neu', title: 'Waldsee mit Plätschern', hint: 'Waldsee mit Libellen. Wasserkreise kommen jetzt einzeln und gleichmäßig verteilt, etwa alle vier Sekunden an einer anderen Stelle.', build: waldTagSeePlaetschern },
  { id: 'wald-nacht', label: 'Wald, Nacht', dark: true, tag: 'neu', title: 'Mondlicht am See', hint: 'Weiches Mondlicht, das direkt am Mond beginnt und nach unten ausläuft, einige Sterne über den Wipfeln, dazu ein See mit kräftigerer Mondspiegelung, schwachen Lichtreflexen über die ganze Breite, seltenen Wasserkreisen und wenigen Glühwürmchen.', build: waldNachtMondSee },
];

export function buildRunde3Entwurf(entry) {
  return svg(`${entry.id} runde3`, entry.build());
}

export function buildRunde3Page() {
  const src = (e) => e.src ?? `backgrounds/entwurf3-${e.id}.svg`;
  const sections = RUNDE3.map(
    (e) => `<section id="${e.id}">
<h2>${e.label}</h2>
${row(e.title, e.hint, src(e), e.dark, e.tag)}
</section>`,
  ).join('');
  return `<!doctype html>
<html lang="de">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Entwürfe: Hintergrund-Szenen, Runde 3</title>
<style>
${PAGE_CSS}
</style>
</head>
<body>
<main>
<h1>Hintergrund-Szenen</h1>
<p>Stand nach deiner letzten Rückmeldung: überarbeitet sind Lagerfeuer am Tag, Wald am Tag und Wald in der Nacht. Gleiche Verankerung wie in der App.</p>
<nav>${RUNDE3.map((e) => `<a href="#${e.id}">${e.label}</a>`).join('')}</nav>
${sections}
</main>
</body>
</html>
`;
}

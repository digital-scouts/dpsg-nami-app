// Lagerfeuer bei Nacht: Feuerstelle mit Sitzkreis und animiertem Feuer.
// Gleiche Farben wie backgrounds.mjs; das Feuer nutzt auch die Tagesszene.
import { rng, r1, ridge, pineRow } from './util.mjs';

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

function feuerstelle() {
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

export function lagerfeuerNacht() {
  return `<style>${FIRE_CSS}</style>` + feuerstelle();
}

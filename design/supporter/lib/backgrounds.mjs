// Animierte Header-Hintergruende (Foerderer). Dezent, langsam, gedeckt.
// Jeder Hintergrund hat eine Tag- (hell) und eine Nachtszene (dunkel).
import { rng, r1, ridge, pineRow } from './util.mjs';

export const BACKGROUNDS = [
  { id: 'lagerfeuer', label: 'Lagerfeuer', day: 'Rauch und Vögel', night: 'Glut und Funken' },
  { id: 'sternenhimmel', label: 'Himmel', day: 'Wolken und Vogelschwarm', night: 'Sterne und Sternschnuppen' },
  { id: 'wald', label: 'Wald', day: 'Libellen und Sonnenstrahlen', night: 'Glühwürmchen und Nebel' },
];

const W = 1200;
const H = 400;

const P = {
  lagerfeuer: {
    light: { top: '#e6edf0', bottom: '#f3e6d6', hill: '#d8c7ae', trees: '#b9b08f', smoke: '#8f877f', log: '#8a6a52', ember: '#e98a4a', bird: '#56606a' },
    dark: { top: '#1d1512', bottom: '#3a241b', hill: '#2c1c16', trees: '#24170f', glow: '#e07a3c', spark: '#ffb56b' },
  },
  sternenhimmel: {
    light: { top: '#b7d0e6', bottom: '#eef2ee', hill: '#bccbc2', trees: '#9fb3a6', cloud: '#ffffff', bird: '#4d5a66' },
    dark: { top: '#0b1428', bottom: '#1d2f50', hill: '#15223b', trees: '#0f1a2e', star: '#e6ecf7' },
  },
  wald: {
    light: { top: '#e3ebe2', bottom: '#cfdccd', far: '#b9cbb8', mid: '#9fb69f', near: '#85a086', fog: '#f4f7f2', ray: '#fff6d6', fly: '#4e6660' },
    dark: { top: '#0d1612', bottom: '#16241d', far: '#1b2c23', mid: '#16251d', near: '#101c16', fog: '#6d8a7a', bug: '#f4e79a' },
  },
};

const style = (css) => `<style>
${css}
@media (prefers-reduced-motion: reduce) { * { animation: none !important; } }
</style>`;

const sky = (c) =>
  `<defs><linearGradient id="bgSky" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="${c.top}"/><stop offset="1" stop-color="${c.bottom}"/></linearGradient></defs><rect width="${W}" height="${H}" fill="url(#bgSky)"/>`;

// ------------------------------------------------------------- Tagesfiguren

// Vogel als zwei Fluegelboegen; Flug ueber die volle Breite, Fluegelschlag per scaleY.
const BIRD_CSS = `
.bird { animation-name: fly; animation-timing-function: linear; animation-iteration-count: infinite; }
@keyframes fly { from { transform: translate(var(--x0), var(--y0)); } 50% { transform: translate(calc((var(--x0) + var(--x1)) / 2), calc(var(--y0) - 14px)); } to { transform: translate(var(--x1), var(--y1)); } }
.flap { animation: flap 1.1s ease-in-out infinite alternate; transform-box: fill-box; transform-origin: center; }
@keyframes flap { from { transform: scaleY(1); } to { transform: scaleY(-0.35); } }`;

function birds(flocks, color) {
  return flocks
    .map(({ y, dir, dur, delay, count, size = 1 }) => {
      const x0 = dir > 0 ? -80 : W + 80;
      const x1 = dir > 0 ? W + 80 : -80;
      let g = '';
      for (let i = 0; i < count; i++) {
        const ox = -dir * i * 26 * size;
        const oy = (i % 2 === 0 ? 1 : -1) * Math.ceil(i / 2) * 12 * size;
        const s = 7 * size;
        g += `<g transform="translate(${r1(ox)} ${r1(oy)})"><path class="flap" style="animation-delay:${r1(-i * 0.27)}s" d="M${-s} 0 Q${r1(-s / 2)} ${r1(-s * 0.8)} 0 0 Q${r1(s / 2)} ${r1(-s * 0.8)} ${s} 0" fill="none" stroke="${color}" stroke-width="${r1(1.8 * size)}" stroke-linecap="round"/></g>`;
      }
      return `<g class="bird" style="--x0:${x0}px;--x1:${x1}px;--y0:${y}px;--y1:${y + 20}px;animation-duration:${dur}s;animation-delay:${delay}s">${g}</g>`;
    })
    .join('');
}

// Libelle: feine Silhouette wie die Voegel. Fliegt immer kopfvoran quer durchs
// Bild und haelt zwischendurch kurz in der Luft an.
const DRAGONFLY_CSS = `
.df { animation-name: dfly; animation-timing-function: ease-in-out; animation-iteration-count: infinite; }
@keyframes dfly {
  0% { transform: translate(var(--x0), var(--y)); }
  24%, 34% { transform: translate(calc(var(--x0) + (var(--x1) - var(--x0)) * .32), calc(var(--y) - 12px)); }
  60%, 70% { transform: translate(calc(var(--x0) + (var(--x1) - var(--x0)) * .64), calc(var(--y) + 8px)); }
  100% { transform: translate(var(--x1), calc(var(--y) - 4px)); }
}
.wing { animation: wing 1.4s ease-in-out infinite alternate; transform-box: fill-box; transform-origin: center; }
@keyframes wing { from { transform: scaleY(1); } to { transform: scaleY(.7); } }`;

function dragonfly({ y, dir, dur, delay, color }) {
  const x0 = dir > 0 ? -60 : W + 60;
  const x1 = dir > 0 ? W + 60 : -60;
  // Kopf zeigt nach rechts (+x); fuer Fluege nach links gespiegelt.
  const body =
    `<line x1="-20" y1="0" x2="2" y2="0" stroke="${color}" stroke-width="1.5" stroke-linecap="round"/>` +
    `<circle cx="3.5" cy="0" r="1.8" fill="${color}"/>` +
    `<g class="wing"><ellipse cx="-1" cy="-7" rx="1.8" ry="7" fill="${color}" opacity="0.4" transform="rotate(-8 -1 -7)"/><ellipse cx="-1" cy="7" rx="1.8" ry="7" fill="${color}" opacity="0.4" transform="rotate(8 -1 7)"/><ellipse cx="-4.5" cy="-6" rx="1.6" ry="6" fill="${color}" opacity="0.32" transform="rotate(-18 -4.5 -6)"/><ellipse cx="-4.5" cy="6" rx="1.6" ry="6" fill="${color}" opacity="0.32" transform="rotate(18 -4.5 6)"/></g>`;
  return `<g class="df" style="--x0:${x0}px;--x1:${x1}px;--y:${y}px;animation-duration:${dur}s;animation-delay:${delay}s"><g transform="scale(${dir > 0 ? 1 : -1} 1)">${body}</g></g>`;
}

// ------------------------------------------------------------------ Szenen

function lagerfeuerTag(c) {
  const rand = rng(17);
  let smoke = '';
  for (let i = 0; i < 7; i++) {
    const dur = 13 + rand() * 5;
    smoke += `<ellipse class="smoke" cx="600" cy="380" rx="26" ry="20" fill="${c.smoke}" style="--dx:${r1(60 + rand() * 90)}px;animation-duration:${r1(dur)}s;animation-delay:${r1(-(i / 7) * dur)}s"/>`;
  }
  return (
    style(`
.smoke { animation-name: smoke; animation-timing-function: ease-out; animation-iteration-count: infinite; opacity: 0; transform-box: fill-box; transform-origin: center; filter: url(#smokeBlur); }
@keyframes smoke { 0% { transform: translate(0,0) scale(.6); opacity: 0; } 15% { opacity: .32; } 100% { transform: translate(var(--dx), -330px) scale(3.2); opacity: 0; } }
.ember { animation: ember 4.5s ease-in-out infinite alternate; }
@keyframes ember { from { opacity: .45; } to { opacity: .8; } }
${BIRD_CSS}`) +
    sky(c) +
    `<defs><filter id="smokeBlur" x="-100%" y="-100%" width="300%" height="300%"><feGaussianBlur stdDeviation="8"/></filter></defs>` +
    birds(
      [
        { y: 90, dir: 1, dur: 46, delay: -8, count: 3 },
        { y: 150, dir: -1, dur: 58, delay: -30, count: 2, size: 0.8 },
      ],
      c.bird,
    ) +
    ridge({ y: 300, amp: 22, seed: 3, width: W, bottom: H, fill: c.hill }) +
    pineRow({ from: -20, to: 360, y: 350, hMin: 90, hMax: 160, seed: 4, fill: c.trees }) +
    pineRow({ from: 840, to: 1220, y: 350, hMin: 90, hMax: 160, seed: 5, fill: c.trees }) +
    smoke +
    `<ellipse class="ember" cx="600" cy="392" rx="46" ry="10" fill="${c.ember}"/>` +
    `<rect x="552" y="382" width="96" height="12" rx="6" fill="${c.log}" transform="rotate(-10 600 388)"/><rect x="552" y="382" width="96" height="12" rx="6" fill="${c.log}" transform="rotate(10 600 388)"/>`
  );
}

function lagerfeuerNacht(c) {
  const rand = rng(7);
  let sparks = '';
  for (let i = 0; i < 16; i++) {
    const x = 600 + (rand() - 0.5) * 260;
    const dur = 9 + rand() * 8;
    sparks += `<circle class="spark" cx="${r1(x)}" cy="400" r="${r1(1.6 + rand() * 2.2)}" fill="${c.spark}" style="--dx:${r1((rand() - 0.5) * 120)}px;animation-duration:${r1(dur)}s;animation-delay:${r1(-rand() * dur)}s"/>`;
  }
  return (
    style(`
.glow { animation: flicker 5.3s ease-in-out infinite alternate; transform-origin: 600px 420px; }
.glow2 { animation: flicker 3.7s ease-in-out infinite alternate-reverse; transform-origin: 600px 420px; }
@keyframes flicker { from { opacity: .55; transform: scale(1); } to { opacity: .8; transform: scale(1.05); } }
.spark { animation-name: rise; animation-timing-function: linear; animation-iteration-count: infinite; opacity: 0; }
@keyframes rise { 0% { transform: translate(0,0); opacity: 0; } 12% { opacity: .8; } 100% { transform: translate(var(--dx), -380px); opacity: 0; } }`) +
    sky(c) +
    `<defs><radialGradient id="fg"><stop offset="0" stop-color="${c.glow}" stop-opacity="0.55"/><stop offset="1" stop-color="${c.glow}" stop-opacity="0"/></radialGradient></defs>` +
    ridge({ y: 300, amp: 22, seed: 3, width: W, bottom: H, fill: c.hill }) +
    pineRow({ from: -20, to: 360, y: 350, hMin: 90, hMax: 160, seed: 4, fill: c.trees }) +
    pineRow({ from: 840, to: 1220, y: 350, hMin: 90, hMax: 160, seed: 5, fill: c.trees }) +
    `<ellipse class="glow" cx="600" cy="420" rx="420" ry="260" fill="url(#fg)"/>` +
    `<ellipse class="glow2" cx="600" cy="430" rx="260" ry="160" fill="url(#fg)"/>` +
    sparks
  );
}

function himmelTag(c) {
  const cloud = (x, y, s, o) =>
    `<g transform="translate(${x} ${y}) scale(${s})" opacity="${o}"><ellipse cx="0" cy="0" rx="70" ry="22" fill="${c.cloud}"/><ellipse cx="-28" cy="-14" rx="34" ry="24" fill="${c.cloud}"/><ellipse cx="20" cy="-20" rx="40" ry="28" fill="${c.cloud}"/></g>`;
  return (
    style(`
.cl1 { animation: cloud 110s linear infinite; }
.cl2 { animation: cloud 80s linear infinite; animation-delay: -40s; }
.cl3 { animation: cloud 140s linear infinite; animation-delay: -90s; }
@keyframes cloud { from { transform: translateX(-300px); } to { transform: translateX(${W + 300}px); } }
${BIRD_CSS}`) +
    sky(c) +
    `<g class="cl1">${cloud(0, 90, 1.2, 0.85)}</g><g class="cl2">${cloud(0, 170, 0.8, 0.7)}</g><g class="cl3">${cloud(0, 60, 0.6, 0.6)}</g>` +
    birds(
      [
        { y: 110, dir: 1, dur: 38, delay: -5, count: 5 },
        { y: 70, dir: -1, dur: 52, delay: -26, count: 3, size: 0.8 },
        { y: 190, dir: 1, dur: 64, delay: -44, count: 2, size: 0.7 },
      ],
      c.bird,
    ) +
    ridge({ y: 330, amp: 26, seed: 8, width: W, bottom: H, fill: c.hill }) +
    pineRow({ from: -20, to: 1220, y: 380, hMin: 50, hMax: 90, seed: 9, fill: c.trees, gap: 0.9 })
  );
}

// Sternschnuppen aus drei Richtungen, jede etwa alle 7 bis 13 Sekunden.
const SHOOTING = [
  { x: 1000, y: 40, tx: -320, ty: 130, dur: 7.5, delay: -1 },
  { x: 180, y: 30, tx: 300, ty: 120, dur: 9.5, delay: -5 },
  { x: 660, y: 10, tx: -110, ty: 190, dur: 11, delay: -8.5 },
  { x: 880, y: 120, tx: -260, ty: 70, dur: 13, delay: -3 },
];

function himmelNacht(c) {
  const rand = rng(21);
  let starEls = '';
  for (let i = 0; i < 140; i++) {
    const dur = 3 + rand() * 4;
    starEls += `<circle class="tw" cx="${r1(rand() * W)}" cy="${r1(rand() * 300)}" r="${r1(0.8 + rand() ** 3 * 2.4)}" fill="${c.star}" style="animation-duration:${r1(dur)}s;animation-delay:${r1(-rand() * dur)}s;--o:${r1(0.55 + rand() * 0.4)}"/>`;
  }
  const shooting = SHOOTING.map((sh, i) => {
    const len = Math.hypot(sh.tx, sh.ty);
    const ex = r1(sh.x - (sh.tx / len) * 110);
    const ey = r1(sh.y - (sh.ty / len) * 110);
    // Schweif zeigt entgegen der Flugrichtung.
    return `<g class="shoot" style="--tx:${sh.tx}px;--ty:${sh.ty}px;animation-duration:${sh.dur}s;animation-delay:${sh.delay}s">
<defs><linearGradient id="tail${i}" gradientUnits="userSpaceOnUse" x1="${sh.x}" y1="${sh.y}" x2="${ex}" y2="${ey}"><stop offset="0" stop-color="${c.star}" stop-opacity="1"/><stop offset="1" stop-color="${c.star}" stop-opacity="0"/></linearGradient></defs>
<line x1="${sh.x}" y1="${sh.y}" x2="${ex}" y2="${ey}" stroke="url(#tail${i})" stroke-width="2.4" stroke-linecap="round"/>
<circle cx="${sh.x}" cy="${sh.y}" r="2.2" fill="${c.star}"/>
</g>`;
  }).join('');
  return (
    style(`
.tw { animation-name: twinkle; animation-timing-function: ease-in-out; animation-iteration-count: infinite; animation-direction: alternate; opacity: var(--o); }
@keyframes twinkle { from { opacity: var(--o); } to { opacity: calc(var(--o) * .15); } }
.shoot { animation-name: shoot; animation-timing-function: cubic-bezier(.3,.1,.6,1); animation-iteration-count: infinite; opacity: 0; }
@keyframes shoot { 0%, 80% { opacity: 0; transform: translate(0,0); } 82% { opacity: .9; } 92% { opacity: 0; transform: translate(var(--tx), var(--ty)); } 100% { opacity: 0; transform: translate(var(--tx), var(--ty)); } }`) +
    sky(c) +
    starEls +
    shooting +
    ridge({ y: 330, amp: 26, seed: 8, width: W, bottom: H, fill: c.hill }) +
    pineRow({ from: -20, to: 1220, y: 380, hMin: 50, hMax: 90, seed: 9, fill: c.trees, gap: 0.9 })
  );
}

const FOREST_CSS = `
.l1 { animation: sway 26s ease-in-out infinite alternate; }
.l2 { animation: sway 19s ease-in-out infinite alternate-reverse; }
.l3 { animation: sway 14s ease-in-out infinite alternate; }
@keyframes sway { from { transform: translateX(-18px); } to { transform: translateX(18px); } }
.fog { animation: drift 34s ease-in-out infinite alternate; }
@keyframes drift { from { transform: translateX(-220px); } to { transform: translateX(220px); } }`;

function forest(c, fogOpacity, between) {
  return (
    `<defs><filter id="fogBlur" x="-20%" y="-100%" width="140%" height="300%"><feGaussianBlur stdDeviation="14"/></filter></defs>` +
    `<g class="l1">${pineRow({ from: -60, to: 1260, y: 330, hMin: 120, hMax: 200, seed: 1, fill: c.far, gap: 0.42 })}</g>` +
    `<rect class="fog" x="-250" y="250" width="1700" height="70" rx="35" fill="${c.fog}" opacity="${fogOpacity}" filter="url(#fogBlur)"/>` +
    `<g class="l2">${pineRow({ from: -60, to: 1260, y: 380, hMin: 160, hMax: 260, seed: 2, fill: c.mid, gap: 0.5 })}</g>` +
    between +
    `<g class="l3">${pineRow({ from: -80, to: 180, y: 420, hMin: 300, hMax: 380, seed: 3, fill: c.near })}${pineRow({ from: 1030, to: 1290, y: 420, hMin: 300, hMax: 380, seed: 4, fill: c.near })}</g>` +
    `<rect y="390" width="${W}" height="10" fill="${c.near}"/>`
  );
}

function waldTag(c) {
  const rays = [
    [380, 160],
    [560, 220],
    [760, 150],
  ]
    .map(([x, w], i) => `<path class="ray" style="animation-delay:${-i * 3.3}s" d="M${x} -10 L${x + 40} -10 L${x + w} ${H} L${x + w - 160} ${H} Z" fill="${c.ray}"/>`)
    .join('');
  const flies = [
    dragonfly({ y: 250, dir: 1, dur: 34, delay: -6, color: c.fly }),
    dragonfly({ y: 210, dir: -1, dur: 42, delay: -22, color: c.fly }),
    dragonfly({ y: 290, dir: 1, dur: 50, delay: -38, color: c.fly }),
  ].join('');
  return (
    style(`${FOREST_CSS}
.ray { animation: rays 10s ease-in-out infinite alternate; opacity: .1; }
@keyframes rays { from { opacity: .06; } to { opacity: .24; } }
${DRAGONFLY_CSS}`) +
    sky(c) +
    rays +
    forest(c, 0.6, flies)
  );
}

function waldNacht(c) {
  const rand = rng(33);
  let bugs = '';
  for (let i = 0; i < 24; i++) {
    const x = rand() * W;
    const y = 140 + rand() * 240;
    const dur = 9 + rand() * 6;
    const r = 1.6 + rand() * 1.4;
    bugs += `<g class="bug" style="--dx:${r1((rand() - 0.5) * 80)}px;--dy:${r1(-15 - rand() * 40)}px;animation-duration:${r1(dur)}s;animation-delay:${r1(-rand() * dur)}s"><circle cx="${r1(x)}" cy="${r1(y)}" r="${r1(r * 3)}" fill="${c.bug}" opacity="0.14"/><circle cx="${r1(x)}" cy="${r1(y)}" r="${r1(r)}" fill="${c.bug}"/></g>`;
  }
  return (
    style(`${FOREST_CSS}
.bug { animation-name: float; animation-timing-function: ease-in-out; animation-iteration-count: infinite; opacity: 0; }
@keyframes float { 0% { transform: translate(0,0); opacity: 0; } 30% { opacity: .7; } 55% { transform: translate(calc(var(--dx) * .6), calc(var(--dy) * .5)); opacity: .35; } 75% { opacity: .7; } 100% { transform: translate(var(--dx), var(--dy)); opacity: 0; } }`) +
    sky(c) +
    forest(c, 0.28, '') +
    bugs
  );
}

const SCENES = {
  lagerfeuer: { light: lagerfeuerTag, dark: lagerfeuerNacht },
  sternenhimmel: { light: himmelTag, dark: himmelNacht },
  wald: { light: waldTag, dark: waldNacht },
};

export function buildBackground(id, mode) {
  const body = SCENES[id][mode](P[id][mode]);
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${W} ${H}" preserveAspectRatio="xMidYMax slice"><title>${id} ${mode}</title>${body}</svg>\n`;
}

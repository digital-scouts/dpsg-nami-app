// Gemeinsame Bausteine der Header-Hintergruende (Foerderer): Farben, Himmel,
// Voegel, Libellen, Wald und Sternschnuppen. Die freigegebenen Szenen stehen
// in entwurf_lagerfeuer_nacht.mjs und entwurf_szenen.mjs (siehe generate.mjs).
import { r1, pineRow } from './util.mjs';

export const BACKGROUNDS = [
  { id: 'lagerfeuer', label: 'Lagerfeuer', day: 'Ausgebranntes Feuer im Sitzkreis, Rauch', night: 'Feuerstelle mit Sitzkreis, Funken' },
  { id: 'sternenhimmel', label: 'Himmel', day: 'Tiefe Sonne, Wolken und Lager in der Weite', night: 'Milchstraße mit Lager' },
  { id: 'wald', label: 'Wald', day: 'Waldsee mit Libellen', night: 'Mondlicht am See' },
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

// Sternschnuppen aus drei Richtungen, jede etwa alle 7 bis 13 Sekunden.
const SHOOTING = [
  { x: 1000, y: 40, tx: -320, ty: 130, dur: 7.5, delay: -1 },
  { x: 180, y: 30, tx: 300, ty: 120, dur: 9.5, delay: -5 },
  { x: 660, y: 10, tx: -110, ty: 190, dur: 11, delay: -8.5 },
  { x: 880, y: 120, tx: -260, ty: 70, dur: 13, delay: -3 },
];

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

// Bausteine fuer die Entwuerfe (entwurf_szenen.mjs).
export { P, W, H, style, sky, BIRD_CSS, birds, DRAGONFLY_CSS, dragonfly, FOREST_CSS, forest, SHOOTING };

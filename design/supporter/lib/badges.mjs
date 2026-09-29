// Supporter-Badges im Aufnaeher-Stil. Stufenfarben nur als Farbwerte.
import { mix, r1 } from './util.mjs';

export const BADGE_COLORS = [
  { id: 'biber', label: 'Biber', fill: '#ffffff', glyph: '#2b3138', stitch: '#a3aab3', edge: '#cfd4da' },
  { id: 'woe', label: 'Wölflinge', fill: '#ff6400', glyph: '#fff6ea', stitch: '#ffd2ad', edge: '#d65200' },
  { id: 'jufi', label: 'Jungpfadfinder', fill: '#2f53a7', glyph: '#f3f6ff', stitch: '#a9bbe6', edge: '#233f82' },
  { id: 'pfadi', label: 'Pfadfinder', fill: '#00823c', glyph: '#effaf2', stitch: '#9fd8b5', edge: '#00632d' },
  { id: 'rover', label: 'Rover', fill: '#cc1f2f', glyph: '#fff1f1', stitch: '#f0a7ad', edge: '#a01624' },
  { id: 'neutral', label: 'Neutral', fill: '#3b4750', glyph: '#f1efe8', stitch: '#8f9ba3', edge: '#2a343b' },
];

export const BADGE_MOTIFS = [
  { id: 'kompass', label: 'Kompass', claim: 'Du hältst uns auf Kurs', foerderer: 'foerderer-polarstern' },
];

// Glyphen im 256er-Raster, Mittelpunkt 128/128.
const GLYPHS = {
  kompass: (g, bg) =>
    `<circle cx="128" cy="128" r="66" fill="none" stroke="${g}" stroke-width="12"/>` +
    [0, 90, 180, 270].map((a) => `<rect x="124" y="50" width="8" height="16" rx="3" fill="${g}" transform="rotate(${a} 128 128)"/>`).join('') +
    `<g transform="rotate(35 128 128)"><path d="M128 76 L146 128 L110 128 Z" fill="${g}"/><path d="M128 180 L146 128 L110 128 Z" fill="${g}" opacity="0.45"/></g>` +
    `<circle cx="128" cy="128" r="8" fill="${bg}"/>`,
};

function stitchRing(color, r, count, width = 5) {
  const circ = 2 * Math.PI * r;
  const dash = circ / count;
  return `<circle cx="128" cy="128" r="${r}" fill="none" stroke="${color}" stroke-width="${width}" stroke-dasharray="${r1(dash * 0.55)} ${r1(dash * 0.45)}" stroke-linecap="round"/>`;
}

export function buildBadge(motifId, colorId) {
  const c = BADGE_COLORS.find((x) => x.id === colorId);
  const body =
    `<circle cx="128" cy="128" r="120" fill="${c.edge}"/>` +
    `<circle cx="128" cy="128" r="112" fill="${c.fill}"/>` +
    stitchRing(c.stitch, 100, 44) +
    `<g transform="translate(128 128) scale(0.82) translate(-128 -128)">${GLYPHS[motifId](c.glyph, c.fill)}</g>`;
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 256 256" width="256" height="256"><title>${motifId} ${colorId}</title>${body}</svg>\n`;
}

// ------------------------------------------------------- Foerderer-Badges

function rosette(r, points, depth) {
  let d = '';
  for (let i = 0; i <= points * 2; i++) {
    const a = (i / (points * 2)) * Math.PI * 2 - Math.PI / 2;
    const rr = i % 2 === 0 ? r : r - depth;
    d += `${i === 0 ? 'M' : 'L'}${r1(128 + Math.cos(a) * rr)} ${r1(128 + Math.sin(a) * rr)} `;
  }
  return d + 'Z';
}

function star(cx, cy, R, rIn, n = 8) {
  let d = '';
  for (let i = 0; i < n * 2; i++) {
    const a = (i / (n * 2)) * Math.PI * 2 - Math.PI / 2;
    const rr = i % 2 === 0 ? R : rIn;
    d += `${i === 0 ? 'M' : 'L'}${r1(cx + Math.cos(a) * rr)} ${r1(cy + Math.sin(a) * rr)} `;
  }
  return d + 'Z';
}

// Schimmer: ein langsam wandernder Lichtstreifen (nur in der Vorschau animiert).
const shimmer = (id) => `
<linearGradient id="${id}" x1="0" y1="0" x2="1" y2="1">
  <stop offset="0" stop-color="#fff" stop-opacity="0"/>
  <stop offset="0.45" stop-color="#fff" stop-opacity="0"/>
  <stop offset="0.5" stop-color="#fff" stop-opacity="0.55"/>
  <stop offset="0.55" stop-color="#fff" stop-opacity="0"/>
  <stop offset="1" stop-color="#fff" stop-opacity="0"/>
  <animate attributeName="x1" values="-1.2;1.2" dur="6s" repeatCount="indefinite"/>
  <animate attributeName="x2" values="-0.2;2.2" dur="6s" repeatCount="indefinite"/>
</linearGradient>`;

export const FOERDERER_BADGES = [
  {
    id: 'foerderer-polarstern',
    label: 'Polarstern',
    svg: () => `<defs>
<linearGradient id="gold" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#f6dc8e"/><stop offset="0.5" stop-color="#c9973b"/><stop offset="1" stop-color="#f1d17a"/></linearGradient>
<radialGradient id="night" cx="0.5" cy="0.35" r="0.7"><stop offset="0" stop-color="#2c4a80"/><stop offset="1" stop-color="#0d1a33"/></radialGradient>
${shimmer('shine')}
</defs>
<path d="${rosette(124, 24, 9)}" fill="url(#gold)"/>
<circle cx="128" cy="128" r="100" fill="url(#night)"/>
${stitchRing('#e3c16e', 90, 40, 4)}
<circle cx="84" cy="90" r="3" fill="#fff" opacity="0.7"/><circle cx="176" cy="96" r="2.5" fill="#fff" opacity="0.6"/><circle cx="160" cy="176" r="2" fill="#fff" opacity="0.5"/><circle cx="92" cy="170" r="2.5" fill="#fff" opacity="0.6"/>
<path d="${star(128, 124, 56, 16, 4)}" fill="url(#gold)"/>
<path d="${star(128, 124, 30, 12, 4)}" fill="#fff6d8" transform="rotate(45 128 124)" opacity="0.9"/>
<path d="${rosette(124, 24, 9)}" fill="url(#shine)"/>`,
  },
];

export function buildFoerdererBadge(badge) {
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 256 256" width="256" height="256"><title>${badge.id}</title>${badge.svg()}</svg>\n`;
}

export { mix };

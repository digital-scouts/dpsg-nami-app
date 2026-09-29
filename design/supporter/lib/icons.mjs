// App-Icon-Dioramen: 8 Motive x 3 Tageszeiten.
import {
  rng,
  r1,
  mix,
  ridge,
  pine,
  pineRow,
  kohte,
  fire,
  fireGlowDef,
  stars,
  celestial,
  mistBand,
} from './util.mjs';

export const TIMES = {
  morgen: {
    label: 'Morgen',
    skyTop: '#9db8c6',
    skyBottom: '#f3d8bf',
    far: '#a9b9b4',
    mid: '#7c938b',
    near: '#4a625a',
    ground: '#2e4239',
    cloth: '#20262a',
    light: '#ffe0b3',
    celestial: 'sun',
    celestialColor: '#fff1d6',
    starCount: 0,
    mist: '#f7eee6',
    mistOpacity: 0.55,
    water: ['#c9d6d4', '#8fa9ab'],
    wood: '#b58a5a',
    pack: '#9a4f33',
    paper: '#efe5cf',
  },
  abend: {
    label: 'Abend',
    skyTop: '#2f3a5e',
    skyBottom: '#e38c5d',
    far: '#8d6376',
    mid: '#5d4661',
    near: '#372d46',
    ground: '#211c2d',
    cloth: '#15121b',
    light: '#ffb45c',
    celestial: 'sun',
    celestialColor: '#ffd38f',
    starCount: 22,
    mist: '#e9a386',
    mistOpacity: 0.22,
    water: ['#b77463', '#3e3452'],
    wood: '#8a5d3f',
    pack: '#7c3a2a',
    paper: '#eed1a6',
  },
  nacht: {
    label: 'Nacht',
    skyTop: '#0a1527',
    skyBottom: '#28436b',
    far: '#2c4363',
    mid: '#1c2e48',
    near: '#112034',
    ground: '#0a1422',
    cloth: '#06080c',
    light: '#ffbd5a',
    celestial: 'moon',
    celestialColor: '#eef1f4',
    starCount: 95,
    mist: '#a3b9d8',
    mistOpacity: 0.12,
    water: ['#223a5c', '#0c1829'],
    wood: '#4b3d38',
    pack: '#4a2a26',
    paper: '#c9d0d8',
  },
};

export const MOTIFS = [
  { id: 'nachtlager', label: 'Nachtlager' },
  { id: 'lagerfeuer', label: 'Lagerfeuer' },
  { id: 'kohte-see', label: 'Kohte am See' },
  { id: 'hajk', label: 'Hajk am Wegweiser' },
];

function defs(T, extra = '') {
  return `<defs>
<linearGradient id="sky" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="${T.skyTop}"/><stop offset="1" stop-color="${T.skyBottom}"/></linearGradient>
<linearGradient id="water" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="${T.water[0]}"/><stop offset="1" stop-color="${T.water[1]}"/></linearGradient>
${fireGlowDef(T.light)}
<radialGradient id="doorGlow"><stop offset="0" stop-color="${T.light}" stop-opacity="0.5"/><stop offset="1" stop-color="${T.light}" stop-opacity="0"/></radialGradient>
<filter id="blur" x="-20%" y="-50%" width="140%" height="200%"><feGaussianBlur stdDeviation="18"/></filter>
<filter id="blurS" x="-20%" y="-50%" width="140%" height="200%"><feGaussianBlur stdDeviation="6"/></filter>
${extra}
</defs>`;
}

const sky = () => `<rect width="1024" height="1024" fill="url(#sky)"/>`;

function skyObjects(T, cx, cy, r = 62, seed = 3) {
  const st = T.starCount ? stars({ count: T.starCount, seed, yMax: 620, opacity: T.starCount > 50 ? 1 : 0.6 }) : '';
  return st + celestial(T.celestial, cx, cy, r, T.celestialColor);
}

// Trennmarke zwischen Hintergrund, Mittelgrund und Vordergrund (fuer Liquid-Glass-Ebenen).
const LAYER = '<!--layer-->';

// ---------------------------------------------------------------- Motive

function nachtlager(T, key) {
  const lit = key !== 'morgen';
  return (
    sky() +
    skyObjects(T, 740, 250, 58, 11) +
    ridge({ y: 560, amp: 40, seed: 2, fill: T.far }) +
    LAYER +
    pineRow({ from: -20, to: 1060, y: 640, hMin: 70, hMax: 130, seed: 5, fill: T.mid }) +
    ridge({ y: 640, amp: 18, seed: 9, fill: T.mid }) +
    (key === 'morgen' ? mistBand(610, 70, T.mist, T.mistOpacity, 'blur') : '') +
    ridge({ y: 800, amp: 14, seed: 4, fill: T.near }) +
    LAYER +
    (lit ? `<ellipse cx="512" cy="815" rx="260" ry="46" fill="url(#doorGlow)"/>` : '') +
    kohte(500, 812, 350, { cloth: T.cloth, light: T.light, lit }) +
    (lit ? fire(735, 820, 0.22, { glow: true }) : '') +
    ridge({ y: 880, amp: 16, seed: 21, fill: T.ground }) +
    pine(70, 900, 420, T.ground) +
    pine(960, 910, 480, T.ground) +
    pine(1040, 930, 360, T.ground)
  );
}

function lagerfeuer(T, key) {
  const rand = rng(44);
  let sparks = '';
  for (let i = 0; i < 26; i++) {
    const x = 512 + (rand() - 0.5) * 360;
    const y = 520 - rand() * 330;
    sparks += `<circle cx="${r1(x)}" cy="${r1(y)}" r="${r1(2 + rand() * 4)}" fill="#ffd28a" opacity="${r1(0.35 + rand() * 0.6)}"/>`;
  }
  let stones = '';
  for (let i = 0; i < 13; i++) {
    const a = (i / 13) * Math.PI * 2;
    const x = 512 + Math.cos(a) * 200;
    const y = 815 + Math.sin(a) * 52;
    const front = Math.sin(a) > 0;
    stones += `<ellipse cx="${r1(x)}" cy="${r1(y)}" rx="${r1(34 + rand() * 12)}" ry="${r1(20 + rand() * 6)}" fill="${front ? mix(T.near, T.light, 0.35) : mix(T.near, T.light, 0.18)}"/>`;
  }
  const backStones = stones; // Reihenfolge reicht fuer die Tiefe
  return (
    sky() +
    skyObjects(T, 230, 220, 44, 7) +
    ridge({ y: 560, amp: 30, seed: 12, fill: T.far }) +
    LAYER +
    pineRow({ from: -30, to: 1060, y: 680, hMin: 140, hMax: 240, seed: 8, fill: T.mid, gap: 0.45 }) +
    `<rect y="680" width="1024" height="344" fill="${T.near}"/>` +
    `<ellipse cx="512" cy="800" rx="420" ry="120" fill="${T.light}" opacity="${key === 'morgen' ? 0.12 : 0.22}"/>` +
    LAYER +
    backStones +
    fire(512, 810, 1.05) +
    sparks +
    `<rect x="60" y="860" width="250" height="44" rx="22" fill="${T.ground}"/><rect x="720" y="870" width="260" height="44" rx="22" fill="${T.ground}"/>` +
    `<rect y="930" width="1024" height="94" fill="${T.ground}"/>`
  );
}

function kohteSee(T, key) {
  const sun = key === 'nacht' ? [700, 300] : key === 'abend' ? [640, 590] : [660, 420];
  const mountains = ridge({ y: 470, amp: 90, seed: 31, steps: 9, fill: T.far, jag: true, bottom: 640 });
  const rand = rng(8);
  let glints = '';
  for (let i = 0; i < 12; i++) {
    const y = 660 + i * 26;
    const w = 90 - i * 4 + rand() * 30;
    glints += `<rect x="${r1(sun[0] - w / 2 + (rand() - 0.5) * 30)}" y="${y}" width="${r1(w)}" height="6" rx="3" fill="${T.celestialColor}" opacity="${r1(0.5 - i * 0.03)}"/>`;
  }
  return (
    sky() +
    skyObjects(T, sun[0], sun[1], 58, 13) +
    mountains +
    ridge({ y: 610, amp: 20, seed: 32, fill: T.mid, bottom: 640 }) +
    pineRow({ from: 560, to: 1060, y: 640, hMin: 60, hMax: 110, seed: 3, fill: T.near }) +
    LAYER +
    `<rect y="640" width="1024" height="384" fill="url(#water)"/>` +
    `<g transform="translate(0 1280) scale(1 -1)" opacity="0.28">${mountains}</g>` +
    glints +
    (key === 'morgen' ? mistBand(630, 60, T.mist, T.mistOpacity, 'blur') : '') +
    LAYER +
    `<path d="M-40 700 Q180 640 460 690 L460 720 Q200 700 -40 760 Z" fill="${T.near}"/>` +
    `<g transform="translate(0 1418) scale(1 -1)" opacity="0.3">${kohte(260, 709, 250, { cloth: T.cloth, light: T.light, lit: key !== 'morgen', seams: false })}</g>` +
    kohte(260, 709, 250, { cloth: T.cloth, light: T.light, lit: key !== 'morgen' }) +
    pine(80, 720, 300, T.ground) +
    `<path d="M-40 1024 L-40 930 Q300 890 560 960 Q800 1010 1064 950 L1064 1024 Z" fill="${T.ground}"/>`
  );
}

function hajk(T, key) {
  const pathColor = mix(T.near, T.light, key === 'nacht' ? 0.12 : 0.4);
  const board = (y, dir, w) => {
    const x0 = 640;
    const tip = dir > 0 ? x0 + w + 30 : x0 - w - 30;
    const back = dir > 0 ? x0 - 30 : x0 + 30;
    const body = dir > 0 ? x0 + w : x0 - w;
    return (
      `<path d="M${back} ${y} L${body} ${y} L${tip} ${y + 26} L${body} ${y + 52} L${back} ${y + 52} Z" fill="${T.wood}"/>` +
      `<rect x="${Math.min(back, body) + 18}" y="${y + 18}" width="${Math.abs(body - back) - 40}" height="6" rx="3" fill="${T.cloth}" opacity="0.35"/>` +
      `<rect x="${Math.min(back, body) + 18}" y="${y + 30}" width="${(Math.abs(body - back) - 40) * 0.6}" height="5" rx="2.5" fill="${T.cloth}" opacity="0.25"/>`
    );
  };
  const pack = `
<g transform="translate(-20 80) rotate(-7 560 820)">
<rect x="470" y="600" width="170" height="225" rx="38" fill="${T.pack}"/>
<rect x="490" y="700" width="130" height="90" rx="20" fill="${mix(T.pack, '#000000', 0.2)}"/>
<path d="M470 640 Q555 590 640 640 L640 680 Q555 650 470 680 Z" fill="${mix(T.pack, '#ffffff', 0.12)}"/>
<rect x="455" y="560" width="200" height="56" rx="28" fill="${key === 'nacht' ? '#394234' : '#6f7f58'}"/>
<ellipse cx="655" cy="588" rx="14" ry="28" fill="${key === 'nacht' ? '#2c3328' : '#586646'}"/>
<rect x="520" y="560" width="10" height="120" fill="${mix(T.pack, '#000000', 0.35)}"/>
<rect x="580" y="560" width="10" height="120" fill="${mix(T.pack, '#000000', 0.35)}"/>
<rect x="470" y="780" width="170" height="10" fill="${mix(T.pack, '#000000', 0.3)}"/>
</g>`;
  return (
    sky() +
    skyObjects(T, 300, 260, 54, 29) +
    ridge({ y: 520, amp: 45, seed: 61, fill: T.far }) +
    ridge({ y: 610, amp: 30, seed: 62, fill: T.mid }) +
    LAYER +
    pineRow({ from: -20, to: 1060, y: 640, hMin: 50, hMax: 100, seed: 63, fill: T.mid }) +
    ridge({ y: 700, amp: 20, seed: 64, fill: T.near }) +
    `<path d="M300 1024 Q420 860 470 780 Q520 700 470 660 Q440 640 500 626 L516 626 Q490 650 530 690 Q600 780 760 1024 Z" fill="${pathColor}"/>` +
    LAYER +
    `<rect x="628" y="440" width="24" height="480" rx="6" fill="${mix(T.wood, '#000000', 0.25)}"/>` +
    `<path d="M624 440 L640 418 L656 440 Z" fill="${mix(T.wood, '#000000', 0.25)}"/>` +
    board(470, 1, 190) +
    board(540, -1, 170) +
    board(610, 1, 140) +
    pack +
    `<path d="M-40 1024 L-40 900 Q180 880 320 1024 Z" fill="${T.ground}"/><path d="M1064 1024 L1064 880 Q860 900 780 1024 Z" fill="${T.ground}"/>` +
    pine(60, 1000, 460, T.ground) +
    pine(990, 1010, 420, T.ground)
  );
}

const SCENES = {
  nachtlager,
  lagerfeuer,
  'kohte-see': kohteSee,
  hajk,
};

const svg = (title, body) =>
  `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" width="1024" height="1024"><title>${title}</title>${body}</svg>\n`;

export function buildIcon(motifId, timeKey) {
  const T = TIMES[timeKey];
  return svg(`${motifId} ${timeKey}`, defs(T) + SCENES[motifId](T, timeKey).replaceAll(LAYER, ''));
}

// Drei Ebenen (hinten, mitte, vorne) mit transparentem Rest, fuer Icon Composer.
export const LAYER_NAMES = ['hinten', 'mitte', 'vorne'];

export function buildIconLayers(motifId, timeKey) {
  const T = TIMES[timeKey];
  const parts = SCENES[motifId](T, timeKey).split(LAYER);
  if (parts.length !== 3) throw new Error(`${motifId}: erwartet 3 Ebenen, gefunden ${parts.length}`);
  return parts.map((part, i) => svg(`${motifId} ${timeKey} ${LAYER_NAMES[i]}`, defs(T) + part));
}

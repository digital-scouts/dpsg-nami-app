// Gemeinsame Helfer fuer die Supporter-Entwuerfe.

export function rng(seed) {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

export const r1 = (n) => Math.round(n * 10) / 10;

function hexToRgb(hex) {
  const h = hex.replace('#', '');
  return [0, 2, 4].map((i) => parseInt(h.slice(i, i + 2), 16));
}

export function mix(a, b, t) {
  const ca = hexToRgb(a);
  const cb = hexToRgb(b);
  const c = ca.map((v, i) => Math.round(v + (cb[i] - v) * t));
  return '#' + c.map((v) => v.toString(16).padStart(2, '0')).join('');
}

function luminance(hex) {
  const [r, g, b] = hexToRgb(hex).map((v) => {
    const s = v / 255;
    return s <= 0.03928 ? s / 12.92 : ((s + 0.055) / 1.055) ** 2.4;
  });
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

export function contrast(a, b) {
  const la = luminance(a);
  const lb = luminance(b);
  return (Math.max(la, lb) + 0.05) / (Math.min(la, lb) + 0.05);
}

// Glatte Linie durch Punkte (Catmull-Rom als kubische Bezier).
export function smoothPath(points) {
  let d = `M${r1(points[0][0])} ${r1(points[0][1])}`;
  for (let i = 0; i < points.length - 1; i++) {
    const p0 = points[i - 1] ?? points[i];
    const p1 = points[i];
    const p2 = points[i + 1];
    const p3 = points[i + 2] ?? p2;
    const c1 = [p1[0] + (p2[0] - p0[0]) / 6, p1[1] + (p2[1] - p0[1]) / 6];
    const c2 = [p2[0] - (p3[0] - p1[0]) / 6, p2[1] - (p3[1] - p1[1]) / 6];
    d += ` C${r1(c1[0])} ${r1(c1[1])} ${r1(c2[0])} ${r1(c2[1])} ${r1(p2[0])} ${r1(p2[1])}`;
  }
  return d;
}

// Huegelkamm ueber die volle Breite, nach unten geschlossen.
export function ridge({ y, amp, seed, steps = 7, width = 1024, bottom = 1024, fill, jag = false }) {
  const rand = rng(seed);
  const pts = [];
  for (let i = 0; i <= steps; i++) {
    const x = (i / steps) * width;
    pts.push([x, y + (rand() - 0.5) * 2 * amp]);
  }
  let d;
  if (jag) {
    d = `M${pts.map((p) => `${r1(p[0])} ${r1(p[1])}`).join(' L')}`;
  } else {
    d = smoothPath([[-40, pts[0][1]], ...pts, [width + 40, pts[pts.length - 1][1]]]);
  }
  return `<path d="${d} L${width + 40} ${bottom} L-40 ${bottom} Z" fill="${fill}"/>`;
}

// Einzelne Tanne als ein Pfad.
export function pine(x, by, h, fill) {
  const tiers = 4;
  let d = `M${r1(x - h * 0.025)} ${r1(by)} L${r1(x - h * 0.025)} ${r1(by - h * 0.12)} L${r1(x + h * 0.025)} ${r1(by - h * 0.12)} L${r1(x + h * 0.025)} ${r1(by)} Z`;
  for (let i = 0; i < tiers; i++) {
    const top = by - h + i * h * 0.2;
    const bot = top + h * 0.34;
    const hw = h * (0.1 + i * 0.065);
    d += ` M${r1(x)} ${r1(top)} L${r1(x + hw)} ${r1(bot)} Q${r1(x)} ${r1(bot - h * 0.05)} ${r1(x - hw)} ${r1(bot)} Z`;
  }
  return `<path d="${d}" fill="${fill}"/>`;
}

export function pineRow({ from, to, y, hMin, hMax, seed, fill, gap = 0.55 }) {
  const rand = rng(seed);
  let out = '';
  let x = from;
  while (x < to) {
    const h = hMin + rand() * (hMax - hMin);
    out += pine(x, y + rand() * 14, h, fill);
    x += h * (gap * 0.6 + rand() * gap * 0.5);
  }
  return out;
}

// Kohte (Schwarzzelt) mit Kohtenkreuz. cx/by = Mitte unten, h = Hoehe.
export function kohte(cx, by, h, { cloth, light, lit = true, seams = true }) {
  const w = h * 0.98;
  const ax = cx;
  const ay = by - h;
  const left = cx - w / 2;
  const right = cx + w / 2;
  const body = `M${r1(left)} ${r1(by)} Q${r1(cx - w * 0.2)} ${r1(by - h * 0.52)} ${r1(ax)} ${r1(ay)} Q${r1(cx + w * 0.2)} ${r1(by - h * 0.52)} ${r1(right)} ${r1(by)} Z`;
  const pole = h * 0.024;
  const poles = [
    [cx - h * 0.1, ay - h * 0.17, cx + h * 0.05, ay + h * 0.09],
    [cx + h * 0.1, ay - h * 0.17, cx - h * 0.05, ay + h * 0.09],
  ]
    .map(
      ([x1, y1, x2, y2]) =>
        `<line x1="${r1(x1)}" y1="${r1(y1)}" x2="${r1(x2)}" y2="${r1(y2)}" stroke="${cloth}" stroke-width="${r1(pole)}" stroke-linecap="round"/>`,
    )
    .join('');
  const seamLines = seams
    ? [0.26, 0.74]
        .map((t) => {
          const bx = left + w * t;
          return `<path d="M${r1(ax)} ${r1(ay + h * 0.06)} Q${r1((ax + bx) / 2)} ${r1(by - h * 0.45)} ${r1(bx)} ${r1(by)}" stroke="${mix(cloth, '#ffffff', 0.14)}" stroke-width="${r1(h * 0.008)}" fill="none" opacity="0.8"/>`;
        })
        .join('')
    : '';
  const dw = h * 0.15;
  const dh = h * 0.44;
  const door = lit
    ? `<path d="M${r1(cx - dw)} ${r1(by)} Q${r1(cx - dw * 0.35)} ${r1(by - dh * 0.55)} ${r1(cx)} ${r1(by - dh)} Q${r1(cx + dw * 0.35)} ${r1(by - dh * 0.55)} ${r1(cx + dw)} ${r1(by)} Z" fill="${light}"/>` +
      `<path d="M${r1(cx - dw * 0.45)} ${r1(by)} Q${r1(cx - dw * 0.1)} ${r1(by - dh * 0.4)} ${r1(cx)} ${r1(by - dh * 0.62)} Q${r1(cx + dw * 0.1)} ${r1(by - dh * 0.4)} ${r1(cx + dw * 0.45)} ${r1(by)} Z" fill="${mix(light, '#ffffff', 0.45)}" opacity="0.75"/>`
    : `<path d="M${r1(cx - dw)} ${r1(by)} L${r1(cx)} ${r1(by - dh)} L${r1(cx + dw)} ${r1(by)} Z" fill="${mix(cloth, '#ffffff', 0.1)}"/>`;
  return `<g>${poles}<path d="${body}" fill="${cloth}"/>${seamLines}${door}</g>`;
}

// Lagerfeuer mit Holzscheiten. s = Skalierung.
export function fire(cx, by, s, { glow = true, logColor = '#4a2f22' } = {}) {
  const logs = [-17, 17]
    .map(
      (deg) =>
        `<rect x="${r1(cx - 150 * s)}" y="${r1(by - 18 * s)}" width="${r1(300 * s)}" height="${r1(36 * s)}" rx="${r1(18 * s)}" fill="${logColor}" transform="rotate(${deg} ${r1(cx)} ${r1(by)})"/>`,
    )
    .join('');
  const flame = (w, h, dx, fill) =>
    `<path d="M${r1(cx + dx - w)} ${r1(by)} C${r1(cx + dx - w)} ${r1(by - h * 0.45)} ${r1(cx + dx - w * 0.15)} ${r1(by - h * 0.6)} ${r1(cx + dx + w * 0.1)} ${r1(by - h)} C${r1(cx + dx + w * 0.25)} ${r1(by - h * 0.62)} ${r1(cx + dx + w)} ${r1(by - h * 0.5)} ${r1(cx + dx + w)} ${r1(by)} Z" fill="${fill}"/>`;
  const glowEl = glow
    ? `<circle cx="${r1(cx)}" cy="${r1(by - 90 * s)}" r="${r1(380 * s)}" fill="url(#fireGlow)"/>`
    : '';
  return (
    glowEl +
    flame(70 * s, 200 * s, -70 * s, '#d9542a') +
    flame(66 * s, 230 * s, 72 * s, '#d9542a') +
    flame(112 * s, 320 * s, 0, '#e8702f') +
    flame(78 * s, 240 * s, 4 * s, '#f5a03d') +
    flame(42 * s, 150 * s, 2 * s, '#ffd98a') +
    logs
  );
}

export const fireGlowDef = (light) =>
  `<radialGradient id="fireGlow"><stop offset="0" stop-color="${light}" stop-opacity="0.55"/><stop offset="0.45" stop-color="${light}" stop-opacity="0.18"/><stop offset="1" stop-color="${light}" stop-opacity="0"/></radialGradient>`;

export function stars({ count, seed, yMax, width = 1024, color = '#ffffff', minR = 1.6, maxR = 4.2, opacity = 1 }) {
  const rand = rng(seed);
  let out = '';
  for (let i = 0; i < count; i++) {
    const x = rand() * width;
    const y = rand() * yMax * (0.35 + 0.65 * rand());
    const r = minR + rand() ** 3 * (maxR - minR);
    const o = (0.35 + rand() * 0.65) * opacity;
    if (r > maxR * 0.78) {
      const k = r * 3.2;
      out += `<path d="M${r1(x)} ${r1(y - k)} Q${r1(x)} ${r1(y)} ${r1(x + k)} ${r1(y)} Q${r1(x)} ${r1(y)} ${r1(x)} ${r1(y + k)} Q${r1(x)} ${r1(y)} ${r1(x - k)} ${r1(y)} Q${r1(x)} ${r1(y)} ${r1(x)} ${r1(y - k)} Z" fill="${color}" opacity="${r1(o)}"/>`;
    } else {
      out += `<circle cx="${r1(x)}" cy="${r1(y)}" r="${r1(r)}" fill="${color}" opacity="${r1(o)}"/>`;
    }
  }
  return out;
}

export function celestial(kind, cx, cy, r, color) {
  const halo = `<circle cx="${cx}" cy="${cy}" r="${r * 3.4}" fill="${color}" opacity="0.12"/><circle cx="${cx}" cy="${cy}" r="${r * 1.9}" fill="${color}" opacity="0.18"/>`;
  if (kind === 'moon') {
    return (
      halo +
      `<circle cx="${cx}" cy="${cy}" r="${r}" fill="${color}"/>` +
      `<circle cx="${cx - r * 0.3}" cy="${cy - r * 0.2}" r="${r * 0.16}" fill="#000" opacity="0.06"/><circle cx="${cx + r * 0.25}" cy="${cy + r * 0.3}" r="${r * 0.22}" fill="#000" opacity="0.05"/>`
    );
  }
  return halo + `<circle cx="${cx}" cy="${cy}" r="${r}" fill="${color}"/>`;
}

export function mistBand(y, h, color, opacity, id) {
  return `<rect x="-60" y="${y}" width="1144" height="${h}" fill="${color}" opacity="${opacity}" filter="url(#${id})" rx="${h / 2}"/>`;
}

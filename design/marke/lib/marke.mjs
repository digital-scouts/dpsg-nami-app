// Logo und App-Icon der Marke (#285), Entscheidung
// design/entscheidung/2026-10-30-marke-logo-app-icon.md.
//
// Logo: drei Personen als Linie (K1), die vordere verdeckt die hinteren.
// App-Icon: Liste mit drei gefüllten Personen im farbigen Kreis (I1).
// Halstuch: breit und flach über beide Schultern (T2), die Bänder laufen oben
// in einen Lederring (D3), unten kommen zwei spitze Zipfel heraus; im Logo
// deckt das Tuch die Schulterlinie bündig ab (S2).

export const FARBEN = {
  hell: {
    figur: ['#8e0f1b', '#114a84', '#bd6508'],
    tuch: '#9c9c9c',
    tuchIcon: '#8a8a8a',
    leder: '#7a5230',
    zeile: '#9aa6b4',
    grund: ['#f3f7fc', '#d6e3f1'],
  },
  dunkel: {
    figur: ['#c9404b', '#4f8bd0', '#e0902f'],
    tuch: '#c4c4c4',
    tuchIcon: '#8a8a8a',
    leder: '#c08a5a',
    zeile: '#6d7787',
    grund: ['#1d2a40', '#0d121c'],
  },
};

const n = (v) => +v.toFixed(2);
let zaehler = 0;
const uid = (p) => `${p}${zaehler++}`;

/**
 * Halstuch um den Hals; (cx, y) ist die Halsmitte auf Schulterhöhe, s der
 * Maßstab. Die Bänder liegen bündig auf der Schulterkurve
 * x = -b(1-t²), y = h(1-t)² + dy. `auf` hebt die Oberkante an, damit das Tuch
 * eine Umrisslinie bis zu ihrer Außenkante abdeckt.
 * Liefert die Ebenen getrennt, damit Tuch und Knoten animiert werden können.
 */
export function halstuch(cx, y, s, { schulter, auf = 0, tuch, leder }) {
  const { b, h, dy } = schulter;
  const P = (x, yy) => `${n(cx + x * s)},${n(y + yy * s)}`;
  const kurve = (x) => {
    const t = Math.sqrt(1 - x / b);
    return h * (1 - t) ** 2 + dy;
  };
  const aussen = 10.6;
  const innen = 4.4;
  const oben = 5.6;
  const band = (sx) => {
    const pts = [];
    for (let i = 0; i <= 6; i++) {
      const x = aussen - ((aussen - innen) * i) / 6;
      pts.push(P(-x * sx, kurve(x) - auf));
    }
    return `M${pts.join(' L')} Q${P(-2.4 * sx, 2.6)} ${P(-0.15 * sx, oben)} L${P(-1.9 * sx, oben + 0.4)} Q${P(-8.6 * sx, 4.6)} ${P(-aussen * sx, kurve(aussen) - auf)} Z`;
  };
  const zipfel = (sx) => `M${P(-1.9 * sx, 9.6)} L${P(-0.1 * sx, 9.6)} L${P(-4 * sx, 17.2)} Z`;
  const flaeche = (d) => `<path d="${d}" fill="${tuch}" stroke="${tuch}" stroke-width="${n(0.5 * s)}" stroke-linejoin="round"/>`;
  return {
    zipfel: flaeche(`${zipfel(1)} ${zipfel(-1)}`),
    tuch: flaeche(`${band(1)} ${band(-1)}`),
    knoten: `<rect x="${n(cx - 2.4 * s)}" y="${n(y + 5 * s)}" width="${n(4.8 * s)}" height="${n(5.2 * s)}" rx="${n(2 * s)}" fill="${leder}"/><path d="M${P(-1.7, 6.7)} H${n(cx + 1.7 * s)} M${P(-1.7, 8.4)} H${n(cx + 1.7 * s)}" stroke="#fff" stroke-opacity=".35" stroke-width="${n(0.45 * s)}"/>`,
  };
}

// Person als Linie mit Halstuch über der Schulterlinie.
function linienPerson(cx, cy, s, farbe, f) {
  const r = 7.5 * s;
  const w = 3.8 * s;
  const unten = cy + 37 * s;
  const schulter = `M${n(cx - 16 * s)},${n(unten)} L${n(cx - 16 * s)},${n(cy + 27 * s)} Q${n(cx - 16 * s)},${n(cy + 14 * s)} ${cx},${n(cy + 14 * s)} Q${n(cx + 16 * s)},${n(cy + 14 * s)} ${n(cx + 16 * s)},${n(cy + 27 * s)} L${n(cx + 16 * s)},${n(unten)}`;
  const umriss = `<g fill="none" stroke="${farbe}" stroke-width="${n(w)}" stroke-linecap="round"><circle cx="${cx}" cy="${cy}" r="${n(r)}"/><path d="${schulter}"/></g>`;
  // Fläche, mit der eine vordere Person die hinteren ausspart, samt Lücke.
  const silhouette = `<g fill="#000" stroke="#000" stroke-width="${n(w + 5)}" stroke-linejoin="round"><circle cx="${cx}" cy="${cy}" r="${n(r)}"/><rect x="${n(cx - 6 * s)}" y="${n(cy)}" width="${n(12 * s)}" height="${n(16 * s)}"/><path d="${schulter} Z"/></g>`;
  const tuch = halstuch(cx, cy + 14.6 * s, s, { schulter: { b: 16, h: 13, dy: -0.6 }, auf: 1.9, tuch: f.tuch, leder: f.leder });
  return { umriss, silhouette, tuch };
}

/** Logo K1 auf transparentem Grund, viewBox 0 0 100 100. */
export function logo(modus, { ebenen = ['umriss', 'zipfel', 'tuch', 'knoten'] } = {}) {
  const f = FARBEN[modus];
  const hinten = [linienPerson(27, 22, 1, f.figur[0], f), linienPerson(73, 22, 1, f.figur[2], f)];
  const vorn = linienPerson(50, 34, 1.2, f.figur[1], f);
  const id = uid('logo');
  const teile = (p) => ebenen.map((e) => (e === 'umriss' ? p.umriss : p.tuch[e])).join('');
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100"><defs><mask id="${id}" maskUnits="userSpaceOnUse" x="-10" y="-10" width="120" height="120"><rect x="-10" y="-10" width="120" height="120" fill="#fff"/>${vorn.silhouette}</mask></defs><g mask="url(#${id})">${hinten.map(teile).join('')}</g>${teile(vorn)}</svg>`;
}

// Gefüllte Person im farbigen Kreis. Einfarbig (mono) ist die Person aus
// dem Kreis ausgespart, etwa für das monochrome Android-Icon.
function avatar(x, y, r, farbe, f, ebenen, mono) {
  const s = r / 9.5;
  const id = uid('kreis');
  const tuch = halstuch(x, y + 2.6 * s, 0.5 * s, { schulter: { b: 15.2, h: 20.8, dy: 0 }, tuch: f.tuchIcon, leder: f.leder });
  const form = (fill) => `<circle cx="${x}" cy="${n(y - 2.8 * s)}" r="${n(3.6 * s)}" fill="${fill}"/><path d="M${n(x - 7.6 * s)},${n(y + 13 * s)} Q${n(x - 7.6 * s)},${n(y + 2.6 * s)} ${x},${n(y + 2.6 * s)} Q${n(x + 7.6 * s)},${n(y + 2.6 * s)} ${n(x + 7.6 * s)},${n(y + 13 * s)} Z" fill="${fill}"/>`;
  if (mono) {
    if (!ebenen.includes('person')) return '';
    return `<mask id="${id}" maskUnits="userSpaceOnUse" x="${x - r}" y="${y - r}" width="${2 * r}" height="${2 * r}"><circle cx="${x}" cy="${y}" r="${r}" fill="#fff"/>${form('#000')}</mask><circle cx="${x}" cy="${y}" r="${r}" fill="#000" mask="url(#${id})"/>`;
  }
  const person = form('#fff');
  const inhalt = ebenen.map((e) => (e === 'person' ? person : tuch[e] ?? '')).join('');
  return `<clipPath id="${id}"><circle cx="${x}" cy="${y}" r="${r}"/></clipPath>${ebenen.includes('person') ? `<circle cx="${x}" cy="${y}" r="${r}" fill="${farbe}"/>` : ''}<g clip-path="url(#${id})">${inhalt}</g>`;
}

const ZEILEN = [
  [20, 26, 0, 44],
  [28, 50, 1, 46],
  [20, 74, 2, 40],
];

/**
 * App-Icon I1 als Quadrat ohne Rundung (die Plattform maskiert), Grund H3.
 * `ebenen` wählt Teile aus: grund, person, zeilen, zipfel, tuch, knoten.
 * `rand` erweitert die Fläche um Einheiten je Seite (adaptives Android-Icon),
 * `mono` zeichnet alles einfarbig schwarz.
 */
export function icon(modus, { ebenen = ['grund', 'person', 'zeilen', 'zipfel', 'tuch', 'knoten'], rand = 0, mono = false } = {}) {
  const f = mono ? { ...FARBEN[modus], zeile: '#000' } : FARBEN[modus];
  const id = uid('grund');
  const grund = ebenen.includes('grund')
    ? `<defs><linearGradient id="${id}" x1="0" y1="0" x2="0.3" y2="1"><stop offset="0" stop-color="${f.grund[0]}"/><stop offset="1" stop-color="${f.grund[1]}"/></linearGradient></defs><rect x="-8" y="-8" width="116" height="116" fill="url(#${id})"/>`
    : '';
  const r = 9.5;
  const zeilen = ZEILEN.map(([x, y, k, lang]) => {
    const balken = ebenen.includes('zeilen')
      ? `<rect x="${x + r + 4.5}" y="${y - 5}" width="${lang}" height="5.5" rx="2.75" fill="${f.zeile}"/><rect x="${x + r + 4.5}" y="${y + 3}" width="${n(lang * 0.6)}" height="3.8" rx="1.9" fill="${f.zeile}" opacity=".55"/>`
      : '';
    return avatar(x, y, r, f.figur[k], f, ebenen, mono) + balken;
  }).join('');
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="${-8 - rand} ${-8 - rand} ${116 + 2 * rand} ${116 + 2 * rand}">${grund}${zeilen}</svg>`;
}

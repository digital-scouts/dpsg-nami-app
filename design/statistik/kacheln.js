// Kachel-Katalog mit festen Größen (1×1, 2×1, 2×2), Kopf nach PR #162
// (zwei einzeilige Zeilen, 48 + 34 pt) und Themen-Tabs aus Kacheln.
// window.RUNDE steuert, welcher Entwurfsstand gerendert wird (Standard 2),
// damit ältere Entwurfsseiten unverändert bleiben.
(function () {
  const D = window.STATISTIK;
  const B = window.BAUSTEINE;
  const { esc, zahl, datum, farbe, kontur, svg, schluessel } = B;

  const SPALTE = 173; // (358 − 12) / 2
  const LUECKE = 12;
  const INNEN = { '1x1': SPALTE - 24, '2x1': 358 - 24, '2x2': 358 - 24 };
  // Rasterhöhe wächst mit der Textskalierung (wie der Header aus PR #162,
  // gedeckelt bei 1,4); die Breite bleibt durch das Gerät vorgegeben.
  let SKALA = 1;
  let ZEILE = 150;
  const HOEHE = {};
  function setzeSkala(f) {
    SKALA = Math.min(1.4, Math.max(1, f));
    ZEILE = Math.round(150 * SKALA);
    const kopf = Math.round(18 * SKALA) + 6;
    HOEHE['1x1'] = ZEILE - 24 - kopf;
    HOEHE['2x1'] = ZEILE - 24 - kopf;
    HOEHE['2x2'] = 2 * ZEILE + LUECKE - 24 - kopf;
  }
  setzeSkala(1);
  function mitSkala(f, fn) {
    const alt = SKALA;
    setzeSkala(f);
    try {
      return fn();
    } finally {
      setzeSkala(alt);
    }
  }

  const R3 = (window.RUNDE || 2) >= 3;
  const R4 = (window.RUNDE || 2) >= 4;
  const R5 = (window.RUNDE || 2) >= 5;

  const zielFuerStufe = (k, id) =>
    (k.ziele.gruppeMax[id] || 0) * Math.max(1, k.proStufe.find((ps) => ps.stufe.id === id).gruppen.length);

  // Minibalken mit dezenter Zielmarke (Haarlinie).
  function miniBalken(id, wert, ziel, skala, breite, dicke = 3) {
    const w = (breite * wert) / skala;
    const zx = ziel ? (breite * ziel) / skala : null;
    const h = dicke + 5;
    const r = dicke / 2;
    return svg(breite, h,
      `<rect x="0" y="2.5" width="${breite}" height="${dicke}" rx="${r}" fill="var(--grid)"/>` +
      `<rect x="0" y="2.5" width="${w.toFixed(1)}" height="${dicke}" rx="${r}" fill="${farbe(id)}"${kontur(id)}/>` +
      (zx !== null ? `<rect x="${(zx - 0.5).toFixed(1)}" y="0" width="1" height="${h}" fill="var(--muted)"><title>Ziel: höchstens ${ziel}</title></rect>` : ''));
  }

  // ------------------------------------------------------------ Kacheln
  function personen(ctx, g) {
    const { k } = ctx;
    if (g === '1x1') {
      return `<div class="zk-val">${k.personen}</div><div class="stat-sub">${k.kinder.length} Kinder & Jugendliche<br>${k.leitende.length} Leitende${k.sonstige ? ` · ${k.sonstige} Sonstige` : ''}</div>`;
    }
    const zeile = (wert, text) => `<div class="pz"><b>${wert}</b><span>${text}</span></div>`;
    return `<div class="split"><div class="zk-val">${k.personen}</div><div class="pz-list">
      ${zeile(k.kinder.length, 'Kinder & Jugendliche')}${zeile(k.leitende.length, 'Leitende')}${k.sonstige ? zeile(k.sonstige, 'Sonstige') : ''}</div></div>`;
  }

  function stufen(ctx) {
    return B.stufenband(ctx, { breite: INNEN['2x1'], hoehe: 14 });
  }

  function gruppen(ctx, g, { zielStil = R3 ? 'lang' : 'strich' } = {}) {
    const { k } = ctx;
    if (g === '2x1') {
      const spalten = k.proStufe.filter((ps) => ps.kinder.length).map((ps) => {
        const ziel = zielFuerStufe(k, ps.stufe.id);
        const skala = Math.max(1, ziel, ps.kinder.length);
        return `<div class="scol"><div class="scol-val">${ps.kinder.length}<small>+${ps.leitende.length}</small></div>
          <div class="scol-lab">${esc(ps.stufe.kurz)}</div>${miniBalken(ps.stufe.id, ps.kinder.length, ziel, skala, 56)}</div>`;
      });
      return `<div class="scols">${spalten.join('')}</div><div class="foot muted">Kinder & Jugendliche +Leitende · | Zielwert</div>`;
    }
    const skala = Math.max(1, k.gruppenMax, ...Object.values(k.ziele.gruppeMax));
    const alle = k.proStufe.flatMap((ps) => ps.gruppen.map((gr) => ({ ps, gr })));
    if (zielStil === 'lang') return gruppenLang(k, alle, skala);
    // Feste Kachelhöhe: passen nicht alle Gruppen, zeigt die letzte Zeile "+n weitere".
    const kapazitaet = Math.floor(HOEHE['2x2'] / 43);
    const sichtbar = alle.length > kapazitaet ? alle.slice(0, kapazitaet - 1) : alle;
    const zeilen = sichtbar.map(({ ps, gr }) => {
      const ziel = k.ziele.gruppeMax[ps.stufe.id];
      const wert = zielStil === 'bruch'
        ? `<div class="g2-val">${gr.kinder.length}<small class="bruch">/${ziel}</small></div>`
        : `<div class="g2-val">${gr.kinder.length}<small>+${gr.leitende.length}</small></div>`;
      const mitte = zielStil === 'strich' ? miniBalken(ps.stufe.id, gr.kinder.length, ziel, skala, 60) : '';
      const sub = zielStil === 'text' ? `${esc(ps.stufe.name)} · Ziel höchstens ${ziel}` : `${esc(ps.stufe.name)} · ${gr.leitende.length} Leitende`;
      return `<div class="g2-row"><i class="dot${ps.stufe.id === 'biber' ? ' biber' : ''}" style="background:${farbe(ps.stufe.id)}"></i>
        <div class="g2-main"><div class="g2-name">${esc(gr.name)}</div><div class="g2-sub">${sub}</div></div>
        <div class="g2-mid">${mitte}</div>${wert}</div>`;
    });
    if (sichtbar.length < alle.length) zeilen.push(`<div class="g2-more">+${alle.length - sichtbar.length} weitere Gruppen ›</div>`);
    return `<div class="g2-list">${zeilen.join('')}</div>`;
  }

  // Runde 3: Gruppen wie "Zahlen" aus Runde 1 – langer Balken unter dem
  // Namen, große Zahl rechts, Zielwert als Strich am Balken.
  function gruppenLang(k, alle, skala) {
    const kapazitaet = Math.floor(HOEHE['2x2'] / 44);
    const sichtbar = alle.length > kapazitaet ? alle.slice(0, kapazitaet - 1) : alle;
    const zeilen = sichtbar.map(({ ps, gr }) => {
      const ziel = k.ziele.gruppeMax[ps.stufe.id];
      return `<div class="g3-row"><i class="dot${ps.stufe.id === 'biber' ? ' biber' : ''}" style="background:${farbe(ps.stufe.id)}"></i>
        <div class="g3-main"><div class="g3-line"><span class="g2-name">${esc(gr.name)}</span><span class="g2-sub">${esc(ps.stufe.name)} · ${gr.leitende.length} Leitende</span></div>
          ${miniBalken(ps.stufe.id, gr.kinder.length, ziel, skala, 226, 5)}</div>
        <div class="g2-val">${gr.kinder.length}<small>+${gr.leitende.length}</small></div></div>`;
    });
    if (sichtbar.length < alle.length) zeilen.push(`<div class="g2-more">+${alle.length - sichtbar.length} weitere Gruppen</div>`);
    return `<div class="g2-list">${zeilen.join('')}</div>`;
  }

  // Stufenwechsel: jetzt dezent (neutrales Grau), danach kräftig (Stufenfarbe).
  function wechsel(ctx, g, { variante = R3 ? 'balken' : 'tabelle' } = {}) {
    if (R4) return wechsel4(ctx, g);
    const { k } = ctx;
    const lead = R3
      ? `<div class="lead"><b>${k.wechselAnzahl}</b> können zum ${datum(D.stichtag)} wechseln</div>`
      : `<div class="lead"><b>${k.wechselAnzahl}</b> wechseln zum ${datum(D.stichtag)}${k.ueberfaellig ? ` · <b>${k.ueberfaellig}</b> überfällig` : ''}</div>`;
    const reihen = k.prognose.filter((r) => r.jetzt || r.danach);
    if (g === '1x1') {
      if (R3) return `<div class="zk-val">${k.wechselAnzahl}</div><div class="stat-sub">können zum ${B.datumKurz(D.stichtag)} wechseln</div>`;
      return `<div class="zk-val">${k.wechselAnzahl}</div><div class="stat-sub">wechseln zum ${B.datumKurz(D.stichtag)}</div>${k.ueberfaellig ? `<div class="flag">↑ ${k.ueberfaellig} überfällig</div>` : ''}`;
    }
    if (g === '2x1') {
      const spalten = reihen.map((r) => `<div class="scol"><div class="scol-lab">${esc(r.stufe.kurz)}</div>
        <div class="scol-flow"><span>${r.jetzt}</span>→<b>${r.danach}</b></div></div>`);
      return `${lead}<div class="scols">${spalten.join('')}</div>`;
    }
    const max = Math.max(...reihen.map((r) => Math.max(r.jetzt, r.danach, zielFuerStufe(k, r.stufe.id))));
    const legende = `<div class="foot">${svg(14, 8, '<rect width="14" height="8" rx="2" fill="var(--ghost)"/>')} heute ${svg(14, 8, '<rect width="14" height="8" rx="2" fill="var(--fg2)"/>')} nach dem Stichtag ${svg(4, 12, '<rect x="1.5" width="1" height="12" fill="var(--muted)"/>')} Zielwert</div>`;
    if (variante === 'tabelle') {
      const bw = 104;
      const zeilen = reihen.map((r) => {
        const id = r.stufe.id;
        const ziel = zielFuerStufe(k, id);
        const x = (v) => (v / max) * bw;
        const bar = svg(bw, 10,
          `<rect x="0" y="0" width="${x(r.jetzt).toFixed(1)}" height="10" rx="2" fill="var(--ghost)"/>` +
          `<rect x="0" y="2" width="${x(r.danach).toFixed(1)}" height="6" rx="2" fill="${farbe(id)}"${kontur(id)}/>` +
          `<rect x="${(x(ziel) - 0.5).toFixed(1)}" y="-2" width="1" height="14" fill="var(--muted)"/>`);
        return `<tr><td>${esc(r.stufe.kurz)}</td><td class="m">${r.jetzt}</td><td class="m">${r.ab ? `−${r.ab}` : '–'}</td><td class="m">${r.zu ? `+${r.zu}` : '–'}</td><td><b>${r.danach}</b>${r.danach > ziel ? '<span class="over">▲</span>' : ''}</td><td class="wbar">${bar}</td></tr>`;
      });
      return `${lead}<table class="tbl wt"><thead><tr><th></th><th>heute</th><th>ab</th><th>zu</th><th>danach</th><th></th></tr></thead><tbody>${zeilen.join('')}</tbody></table>${legende}`;
    }
    if (variante === 'balken') {
      const labelB = 46;
      const rechts = 62;
      const breite = INNEN['2x2'];
      const pw = breite - labelB - rechts;
      const x = (v) => (v / max) * pw;
      let inhalt = '';
      reihen.forEach((r, i) => {
        const y = i * 30 + 4;
        const id = r.stufe.id;
        const ziel = zielFuerStufe(k, id);
        inhalt += `<text x="0" y="${y + 12}" class="t-lab">${esc(r.stufe.kurz)}</text>`;
        inhalt += `<rect x="${labelB}" y="${y}" width="${x(r.jetzt).toFixed(1)}" height="16" rx="3" fill="var(--ghost)"><title>heute ${r.jetzt}</title></rect>`;
        inhalt += `<rect x="${labelB}" y="${y + 4}" width="${x(r.danach).toFixed(1)}" height="8" rx="2" fill="${farbe(id)}"${kontur(id)}><title>danach ${r.danach}</title></rect>`;
        inhalt += `<rect x="${(labelB + x(ziel) - 0.5).toFixed(1)}" y="${y - 2}" width="1" height="20" fill="var(--muted)"/>`;
        inhalt += `<text x="${breite}" y="${y + 12}" class="t-val" text-anchor="end"><tspan fill="var(--muted)">${r.jetzt} →</tspan> <tspan font-weight="700" font-size="13">${r.danach}</tspan>${r.danach > ziel && !R3 ? ' ▲' : ''}</text>`;
      });
      return `${lead}${svg(breite, reihen.length * 30, inhalt)}${legende}`;
    }
    // Säulenpaare
    const breite = INNEN['2x2'];
    const ph = 118;
    const slot = breite / reihen.length;
    const w = 20;
    let inhalt = '';
    reihen.forEach((r, i) => {
      const id = r.stufe.id;
      const cx = i * slot + slot / 2;
      const hJ = (r.jetzt / max) * ph;
      const hD = (r.danach / max) * ph;
      const basis = ph + 18;
      inhalt += B.saeule(cx - w - 1, basis, w, hJ, 'var(--ghost)', '', `heute ${r.jetzt}`);
      inhalt += B.saeule(cx + 1, basis, w, hD, farbe(id), kontur(id), `danach ${r.danach}`);
      inhalt += `<text x="${cx - w / 2 - 1}" y="${basis - hJ - 4}" class="t-axis" text-anchor="middle">${r.jetzt}</text>`;
      inhalt += `<text x="${cx + w / 2 + 1}" y="${basis - hD - 4}" class="t-val" text-anchor="middle" font-size="13">${r.danach}</text>`;
      inhalt += `<text x="${cx}" y="${basis + 14}" class="t-lab" text-anchor="middle">${esc(r.stufe.kurz)}</text>`;
      const netto = r.danach - r.jetzt;
      inhalt += `<text x="${cx}" y="${basis + 27}" class="t-axis" text-anchor="middle">${netto > 0 ? '+' : ''}${netto || '±0'}</text>`;
    });
    inhalt += `<line x1="0" x2="${breite}" y1="${ph + 18.5}" y2="${ph + 18.5}" stroke="var(--grid)"/>`;
    return `${lead}${svg(breite, ph + 50, inhalt)}<div class="foot">${svg(14, 8, '<rect width="14" height="8" rx="2" fill="var(--ghost)"/>')} heute ${svg(14, 8, '<rect width="14" height="8" rx="2" fill="var(--fg2)"/>')} nach dem Stichtag</div>`;
  }

  function alter(ctx) {
    if (R4) return alter4(ctx);
    let einheit = 5;
    if (R3) {
      // Säulenhöhe so wählen, dass Diagramm, Achse und Fußzeile in 2×2 passen.
      const reihen = ctx.k.proStufe.filter((ps) => ps.kinder.length);
      const maxProJahr = Math.max(1, ...reihen.flatMap((ps) => {
        const z = {};
        ps.kinder.forEach((p) => { const a = Math.floor(B.alter(p)); z[a] = (z[a] || 0) + 1; });
        return Object.values(z);
      }));
      const frei = HOEHE['2x2'] - 22 - 14 - reihen.length * 14;
      einheit = Math.max(2, Math.min(6, Math.floor(frei / (reihen.length * maxProJahr))));
    }
    return B.altersstruktur({ ...ctx, stil: 'balken' }, { breite: INNEN['2x2'], einheit, legende: false }) +
      '<div class="foot muted">Fläche = Altersgrenze · ↑ über der Grenze · Jahre</div>';
  }

  // Runde 3: Alter in Zahlen ohne Überschreitungs-Kennzeichen; die Spanne
  // läuft auf einer gemeinsamen Achse frei über die Altersgrenze hinaus.
  function alterZahlen3(ctx, g) {
    const { k } = ctx;
    const reihen = k.proStufe.filter((ps) => ps.kinder.length);
    if (g === '2x1') {
      return `<div class="scols">${reihen.map((ps) => {
        const alters = ps.kinder.map((p) => B.alter(p));
        return `<div class="scol"><div class="scol-lab">${esc(ps.stufe.kurz)}</div><div class="scol-val">${zahl(B.median(alters), 1)}</div>
          <div class="scol-sub">${Math.floor(Math.min(...alters))}–${Math.floor(Math.max(...alters))} J.</div></div>`;
      }).join('')}</div><div class="foot muted">Median in Jahren · jüngste bis älteste</div>`;
    }
    const sb = 150;
    const zeilen = reihen.map((ps) => {
      const s = ps.stufe;
      const alters = ps.kinder.map((p) => B.alter(p));
      const lo = Math.min(...alters);
      const hi = Math.max(...alters);
      const med = B.median(alters);
      // Eigene Skala je Stufe, weit genug, dass die Spanne sichtbar über die Grenze läuft.
      const von = Math.min(s.min, lo) - 1.5;
      const bis = Math.max(s.max + 1, hi) + 1.5;
      const x = (a) => ((a - von) / (bis - von)) * sb;
      const bandFill = s.id === 'biber' ? 'var(--biber-band)' : farbe(s.id);
      const strip = svg(sb, 12,
        `<rect x="${x(s.min).toFixed(1)}" y="1" width="${(x(s.max + 1) - x(s.min)).toFixed(1)}" height="10" rx="3" fill="${bandFill}" opacity="${s.id === 'biber' ? 1 : 0.14}"/>` +
        `<rect x="${x(lo).toFixed(1)}" y="5" width="${Math.max(2, x(hi) - x(lo)).toFixed(1)}" height="2" rx="1" fill="${s.id === 'biber' ? 'var(--fg2)' : farbe(s.id)}"/>` +
        `<circle cx="${x(med).toFixed(1)}" cy="6" r="4" fill="${farbe(s.id)}" stroke="var(--surface)" stroke-width="2"/>` +
        (s.id === 'biber' ? `<circle cx="${x(med).toFixed(1)}" cy="6" r="3.5" fill="none" stroke="var(--biber-ring)" stroke-width="1"/>` : ''));
      return `<div class="az-row"><span class="num-lab">${schluessel(s.id, s.kurz)}</span><span class="num-big">${zahl(med, 1)}<small> J.</small></span>${strip}<small class="az-span">${Math.floor(lo)}–${Math.floor(hi)}</small></div>`;
    });
    return `<div class="num-list">${zeilen.join('')}</div><div class="foot muted">Median · Linie von jüngster bis ältester Person · Fläche = Altersgrenze</div>`;
  }

  function alterZahlen(ctx, g) {
    if (R4) return alterZahlen4(ctx, g);
    if (R3) return alterZahlen3(ctx, g);
    const { k } = ctx;
    if (g === '2x2') return B.altersstruktur({ ...ctx, stil: 'zahlen' }, { breite: INNEN['2x2'] });
    const spalten = k.proStufe.filter((ps) => ps.kinder.length).map((ps) => {
      const alters = ps.kinder.map((p) => B.alter(p));
      const ueber = alters.filter((a) => a >= ps.stufe.max + 1).length;
      return `<div class="scol"><div class="scol-lab">${esc(ps.stufe.kurz)}</div><div class="scol-val">${zahl(B.median(alters), 1)}</div>
        <div class="scol-sub">${Math.floor(Math.min(...alters))}–${Math.floor(Math.max(...alters))}${ueber ? ` <b>↑${ueber}</b>` : ''}</div></div>`;
    });
    return `<div class="scols">${spalten.join('')}</div><div class="foot muted">Median in Jahren · jüngste bis älteste · ↑ über der Grenze</div>`;
  }

  function bindung(ctx, g) {
    if (R4) return bindung4(ctx, g);
    const { k } = ctx;
    const meter = `<div class="meter"><i style="width:${Math.min(100, (k.neu.length / k.ziele.neuProJahr) * 100)}%"></i></div>`;
    if (g === '1x1') {
      return `<div class="zk-val">${k.neu.length}</div>${meter}<div class="stat-sub">Ziel ${k.ziele.neuProJahr} pro Jahr</div>`;
    }
    return `<div class="trio">
      <div><div class="stat-lab">Neu in 12 Mon.</div><div class="stat-val">${k.neu.length}</div>${meter}<div class="stat-sub">Ziel ${k.ziele.neuProJahr}</div></div>
      <div><div class="stat-lab">Dabei (Median)</div><div class="stat-val">${zahl(k.dauerKinder, 1)}<small> J.</small></div><div class="stat-sub">Kinder & Jugendl.</div></div>
      <div><div class="stat-lab">Leitende</div><div class="stat-val">${zahl(k.dauerLeitende, 1)}<small> J.</small></div><div class="stat-sub">seit Eintritt</div></div>
    </div><div class="foot muted">Nur heutige Mitglieder</div>`;
  }

  function verlauf(ctx, g) {
    if (R4) return verlauf4(ctx, g);
    if (g === '1x1') {
      return `<div class="vk-chart">${svg(INNEN['1x1'], 44, `<line x1="0" x2="${INNEN['1x1']}" y1="40.5" y2="40.5" stroke="var(--grid)"/><circle cx="${INNEN['1x1'] - 8}" cy="18" r="4" fill="var(--primary)"/>`)}</div>
        <div class="stat-sub"><b class="fg">Aufzeichnung läuft</b><br>Erste Kurve ab November</div>`;
    }
    return `<div class="verlauf-kachel"><div class="vk-chart">${svg(120, 44, '<line x1="0" x2="120" y1="40.5" y2="40.5" stroke="var(--grid)"/><circle cx="112" cy="18" r="4" fill="var(--primary)"/>')}</div>
      <div><b>Aufzeichnung läuft</b><br><span class="stat-sub">Monatliche Summen auf diesem Gerät. Erste Kurve ab November 2026.</span></div></div>`;
  }

  function merkmal(ctx, items, g, einheit) {
    const farben = D.merkmal[ctx.modus];
    if (R4 && g === '1x1') return merkmal4(ctx, items, einheit);
    const summe = items.reduce((a, x) => a + x.wert, 0) || 1;
    if (g === '1x1') {
      const klein = items.filter((x) => x.wert && x.wert / summe < 0.12);
      return `<div class="donut-1x1">${B.donut(ctx, items, { groesse: 88, ring: 22, zentrum: [summe, einheit], unter: 'inlay' })}</div>` +
        `<div class="donut-rest">${klein.length ? klein.map((x) => `${esc(x.kurz)} ${zahl((x.wert / summe) * 100)} %`).join(' · ') : '&nbsp;'}</div>`;
    }
    const legende = items.filter((x) => x.wert).map((x) => {
      const i = items.indexOf(x);
      return `<div class="leg-row"><i class="sw" style="background:${farben[i]}"></i><span>${esc(x.label)}</span><b>${x.wert}</b><small>${zahl((x.wert / summe) * 100)} %</small></div>`;
    }).join('');
    const groesse = R5 ? Math.min(100, HOEHE['2x1']) : 108;
    return `<div class="donut-2x1">${B.donut(ctx, items, { groesse, ring: 22, zentrum: [summe, einheit] })}<div class="leg">${legende}</div></div>`;
  }

  function standorte(ctx, g) {
    const n = ctx.k.kinder.length + ctx.k.leitende.length;
    const legende = `<div class="leg-row"><i class="sw round" style="background:var(--primary)"></i><span>Wohnorte</span><b>${n}</b></div>
      <div class="leg-row"><i class="sw house"></i><span>Stammesheim</span></div>`;
    if (R5) {
      // Kartengröße aus der freien Fläche: Legende rechts (2×1) bzw. unten (2×2)
      // bekommt so viel Platz, wie die Schrift braucht.
      if (g === '2x1') {
        const legB = Math.ceil(128 * SKALA);
        return `<div class="map-2x1">${B.karte(ctx, INNEN['2x1'] - legB - 12, HOEHE['2x1'], 7)}<div class="leg">${legende}</div></div>`;
      }
      const legH = Math.ceil(18 * SKALA) + 12;
      return `<div>${B.karte(ctx, INNEN['2x2'], HOEHE['2x2'] - legH, 7)}<div class="leg row">${legende}</div></div>`;
    }
    if (g === '2x1') {
      return `<div class="map-2x1">${B.karte(ctx, 200, HOEHE['2x1'], 7)}<div class="leg">${legende}</div></div>`;
    }
    return `<div>${B.karte(ctx, INNEN['2x2'], 238, 7)}<div class="leg row">${legende}</div></div>`;
  }

  function eigen(ctx, g, kachel) {
    if (R4) return eigen4(ctx, g, kachel);
    const meter = kachel.ziel
      ? `<div class="meter"><i style="width:${Math.min(100, (kachel.wert / kachel.ziel) * 100)}%"></i></div><div class="stat-sub">${kachel.wert} von ${kachel.ziel} ${esc(kachel.zielText || '')}</div>`
      : '';
    if (g === '1x1' && kachel.aufteilung && R3) {
      // Runde 3: Aufteilung nach Stufe als Kreis, Wert in der Mitte.
      const items = Object.entries(kachel.aufteilung).map(([id, v]) => ({
        label: B.stufeById[id].name, kurz: B.stufeById[id].kurz, wert: v, inlay: String(v),
        farbe: farbe(id), hex: D.stufenfarben[ctx.modus][id],
      }));
      const kreis = B.donut(ctx, items.map((it) => ({ ...it, kurz: it.inlay, inlay: '' })), { groesse: 68, ring: 18, zentrum: [kachel.wert, ''], unter: 'inlay' });
      return `<div class="donut-1x1">${kreis}</div><div class="keys mini">${items.map((it) => `<span class="key"><i class="sw" style="background:${it.farbe}"></i>${esc(it.kurz)}</span>`).join('')}</div>`;
    }
    if (g === '1x1' || !kachel.aufteilung) {
      return `<div class="zk-val">${kachel.wert}</div>${meter}`;
    }
    const teile = Object.entries(kachel.aufteilung);
    const summe = teile.reduce((a, [, v]) => a + v, 0);
    const bw = 180;
    const nutz = bw - 2 * (teile.length - 1);
    let x = 0;
    let inhalt = '';
    teile.forEach(([id, v]) => {
      const w = (nutz * v) / summe;
      inhalt += `<rect x="${x.toFixed(1)}" y="0" width="${w.toFixed(1)}" height="10" rx="3" fill="${farbe(id)}"${kontur(id)}/>`;
      x += w + 2;
    });
    return `<div class="zk-2x1"><div class="zk-val">${kachel.wert}</div><div class="zk-right">${svg(bw, 10, inhalt)}<div class="keys">${teile.map(([id, v]) => schluessel(id, B.stufeById[id].kurz, v)).join('')}</div></div></div>`;
  }


  // ------------------------------------------------------------ Runde 4
  // Mehr Inhalt statt Leerraum, Stufenfarben in den 2×1-Kacheln, robust
  // gegenüber krummen Daten (leere Mengen, fehlende Ziele, Ausreißer).
  const mindestens1 = (v) => (Number.isFinite(v) && v > 0 ? v : 1);
  const MONATE = ['Jan', 'Feb', 'Mär', 'Apr', 'Mai', 'Jun', 'Jul', 'Aug', 'Sep', 'Okt', 'Nov', 'Dez'];
  const fuellen = (oben, unten) => `<div class="fill"><div>${oben}</div><div>${unten}</div></div>`;

  // Band aus Teilen in Stufenfarben mit 2 pt Lücken.
  function stufenTeile(teile, breite, hoehe, { zahlen = false, modus = 'hell' } = {}) {
    const sichtbar = teile.filter(([, v]) => v > 0);
    const summe = sichtbar.reduce((a, [, v]) => a + v, 0);
    if (!summe) return svg(breite, hoehe, `<rect width="${breite}" height="${hoehe}" rx="3" fill="var(--grid)"/>`);
    const nutz = breite - 2 * (sichtbar.length - 1);
    let x = 0;
    let inhalt = '';
    sichtbar.forEach(([id, v]) => {
      const w = (nutz * v) / summe;
      inhalt += `<rect x="${x.toFixed(1)}" y="0" width="${w.toFixed(1)}" height="${hoehe}" rx="3" fill="${farbe(id)}"${kontur(id)}><title>${esc(B.stufeById[id].name)}: ${v}</title></rect>`;
      if (zahlen && w > 18) inhalt += `<text x="${(x + w / 2).toFixed(1)}" y="${hoehe / 2 + 4}" text-anchor="middle" class="t-in1" fill="${B.tinteAuf(D.stufenfarben[modus][id])}">${v}</text>`;
      x += w + 2;
    });
    return svg(breite, hoehe, inhalt);
  }
  const miniKeys = (teile, mitWert = true) =>
    `<div class="keys mini links">${teile.filter(([, v]) => v > 0).map(([id, v]) => `<span class="key"><i class="sw${id === 'biber' ? ' biber' : ''}" style="background:${farbe(id)}"></i>${esc(B.stufeById[id].kurz)}${mitWert ? ` <b>${v}</b>` : ''}</span>`).join('')}</div>`;

  function wechsel4(ctx, g) {
    const { k } = ctx;
    const reihen = k.prognose.filter((r) => r.jetzt || r.danach);
    const lead = `<div class="lead"><b>${k.wechselAnzahl}</b> können zum ${datum(D.stichtag)} wechseln</div>`;
    const max = mindestens1(Math.max(0, ...reihen.map((r) => Math.max(r.jetzt, r.danach, zielFuerStufe(k, r.stufe.id)))));
    if (g === '1x1') {
      const teile = reihen.filter((r) => r.ab).map((r) => [r.stufe.id, r.ab]);
      return fuellen(`<div class="zk-val">${k.wechselAnzahl}</div><div class="stat-sub">können zum ${B.datumKurz(D.stichtag)} wechseln</div>`,
        `${stufenTeile(teile, INNEN['1x1'], 8)}${miniKeys(teile)}`);
    }
    if (g === '2x1') {
      const bw = 56;
      const spalten = reihen.map((r) => {
        const id = r.stufe.id;
        const bar = svg(bw, 8,
          `<rect x="0" y="0" width="${((bw * r.jetzt) / max).toFixed(1)}" height="8" rx="2" fill="var(--ghost)"/>` +
          `<rect x="0" y="2" width="${((bw * r.danach) / max).toFixed(1)}" height="4" rx="1.5" fill="${farbe(id)}"${kontur(id)}/>`);
        return `<div class="scol"><div class="scol-lab">${esc(r.stufe.kurz)}</div><div class="scol-flow"><span>${r.jetzt}</span>→<b>${r.danach}</b></div>${bar}</div>`;
      });
      return `${lead}<div class="scols">${spalten.join('')}</div>`;
    }
    // 2×2: Zeilenhöhe aus der verfügbaren Höhe, damit unten kein Leerraum bleibt.
    const labelB = 52;
    const rechts = 66;
    const breite = INNEN['2x2'];
    const pw = breite - labelB - rechts;
    const leadH = Math.ceil(19 * SKALA) + 14;
    const legH = Math.ceil(16 * SKALA) + 12;
    const rowH = Math.max(22, Math.min(46 * SKALA, (HOEHE['2x2'] - leadH - legH) / Math.max(1, reihen.length)));
    const gh = Math.round(rowH * 0.5);
    const dh = Math.max(4, Math.round(gh * 0.5));
    const x = (v) => (v / max) * pw;
    let inhalt = '';
    reihen.forEach((r, i) => {
      const y = i * rowH + (rowH - gh) / 2;
      const mitte = y + gh / 2;
      const id = r.stufe.id;
      const ziel = zielFuerStufe(k, id);
      inhalt += `<text x="0" y="${mitte}" dominant-baseline="central" class="t-lab gross">${esc(r.stufe.kurz)}</text>`;
      inhalt += `<rect x="${labelB}" y="${y}" width="${x(r.jetzt).toFixed(1)}" height="${gh}" rx="3" fill="var(--ghost)"><title>heute ${r.jetzt}</title></rect>`;
      inhalt += `<rect x="${labelB}" y="${mitte - dh / 2}" width="${x(r.danach).toFixed(1)}" height="${dh}" rx="2" fill="${farbe(id)}"${kontur(id)}><title>danach ${r.danach}</title></rect>`;
      if (ziel) inhalt += `<rect x="${(labelB + x(ziel) - 0.5).toFixed(1)}" y="${y - 3}" width="1" height="${gh + 6}" fill="var(--muted)"/>`;
      inhalt += `<text x="${breite}" y="${mitte}" dominant-baseline="central" class="t-val" text-anchor="end"><tspan class="t-v12" fill="var(--muted)">${r.jetzt} →</tspan> <tspan class="t-v15">${r.danach}</tspan></text>`;
    });
    const legende = `<div class="foot">${svg(14, 8, '<rect width="14" height="8" rx="2" fill="var(--ghost)"/>')} heute ${svg(14, 8, '<rect width="14" height="8" rx="2" fill="var(--fg2)"/>')} nach dem Stichtag ${svg(4, 12, '<rect x="1.5" width="1" height="12" fill="var(--muted)"/>')} Zielwert</div>`;
    if (R5) return `<div class="fill-col"><div>${lead}${svg(breite, Math.max(1, reihen.length) * rowH, inhalt)}</div>${legende}</div>`;
    return `${lead}${svg(breite, Math.max(1, reihen.length) * rowH, inhalt)}${legende}`;
  }

  function alter4(ctx) {
    const reihen = ctx.k.proStufe.filter((ps) => (ps.kinderAlter || ps.kinder).length);
    const maxProJahr = Math.max(1, ...reihen.flatMap((ps) => {
      const z = {};
      (ps.kinderAlter || ps.kinder).forEach((p) => { const a = Math.max(3, Math.min(22, Math.floor(B.alter(p)))); z[a] = (z[a] || 0) + 1; });
      return Object.values(z);
    }));
    const ohne = ctx.k.ohneGeburt ? ` · ${ctx.k.ohneGeburt} ohne Geburtsdatum` : '';
    if (!reihen.length) return `<div class="leer">Keine Geburtsdaten vorhanden${ohne}</div>`;
    const fuss = `<div class="foot muted">Fläche = Altersgrenze · Jahre${ohne}</div>`;
    if (R5) {
      // Runde 5: Säulen strecken sich über die ganze freie Höhe; die Fußzeile
      // sitzt unten, unabhängig davon, wie die Daten verteilt sind.
      const achse = Math.round(14 * SKALA);
      const fussText = `Fläche = Altersgrenze · Jahre${ohne}`;
      const fussZeilen = Math.max(1, Math.ceil((fussText.length * 6 * SKALA) / INNEN['2x2']));
      const fussH = Math.ceil(fussZeilen * 15 * SKALA) + 12;
      const frei = HOEHE['2x2'] - fussH - achse - reihen.length * 14;
      const einheit = Math.max(1, frei / (reihen.length * maxProJahr));
      return `<div class="fill-col"><div>${B.altersstruktur({ ...ctx, stil: 'balken' }, { breite: INNEN['2x2'], einheit, legende: false, ueberLabel: false, achsHoehe: achse })}</div>${fuss}</div>`;
    }
    const frei = HOEHE['2x2'] - 22 - 14 - Math.max(1, reihen.length) * 14;
    const einheit = Math.max(1, Math.min(7, Math.floor(frei / (Math.max(1, reihen.length) * maxProJahr))));
    return B.altersstruktur({ ...ctx, stil: 'balken' }, { breite: INNEN['2x2'], einheit, legende: false, ueberLabel: false }) + fuss;
  }

  // Alterspanne als Streifen: Fläche = Altersgrenze, Linie = jüngste bis
  // älteste Person, Punkt = Median. Eigene Skala je Stufe.
  function streifen(s, alters, breite, hoehe) {
    const lo = Math.min(...alters);
    const hi = Math.max(...alters);
    const med = B.median(alters);
    const von = Math.min(s.min, lo) - 1.5;
    const bis = Math.max(s.max + 1, hi) + 1.5;
    const x = (a) => ((a - von) / (bis - von)) * breite;
    const m = hoehe / 2;
    const r = Math.max(3, Math.min(5, hoehe / 3));
    const bandFill = s.id === 'biber' ? 'var(--biber-band)' : farbe(s.id);
    return svg(breite, hoehe,
      `<rect x="${x(s.min).toFixed(1)}" y="0" width="${(x(s.max + 1) - x(s.min)).toFixed(1)}" height="${hoehe}" rx="3" fill="${bandFill}" opacity="${s.id === 'biber' ? 1 : 0.16}"/>` +
      `<rect x="${x(lo).toFixed(1)}" y="${m - 1}" width="${Math.max(2, x(hi) - x(lo)).toFixed(1)}" height="2" rx="1" fill="${s.id === 'biber' ? 'var(--fg2)' : farbe(s.id)}"/>` +
      `<circle cx="${x(med).toFixed(1)}" cy="${m}" r="${r}" fill="${farbe(s.id)}" stroke="var(--surface)" stroke-width="2"/>` +
      (s.id === 'biber' ? `<circle cx="${x(med).toFixed(1)}" cy="${m}" r="${r - 0.5}" fill="none" stroke="var(--biber-ring)" stroke-width="1"/>` : ''));
  }

  function alterZahlen4(ctx, g) {
    const reihen = ctx.k.proStufe.filter((ps) => (ps.kinderAlter || ps.kinder).length);
    if (!reihen.length) return '<div class="leer">Keine Geburtsdaten vorhanden</div>';
    if (g === '2x1') {
      return `<div class="scols">${reihen.map((ps) => {
        const alters = (ps.kinderAlter || ps.kinder).map((p) => B.alter(p));
        return `<div class="scol"><div class="scol-lab">${esc(ps.stufe.kurz)}</div><div class="scol-val">${zahl(B.median(alters), 1)}</div>
          ${streifen(ps.stufe, alters, 56, 10)}<div class="scol-sub">${Math.floor(Math.min(...alters))}–${Math.floor(Math.max(...alters))} J.</div></div>`;
      }).join('')}</div><div class="foot muted">Median in Jahren · Linie = jüngste bis älteste</div>`;
    }
    if (R5) {
      // Runde 5: Zeilen verteilen sich über die freie Höhe, die Legende sitzt unten.
      const zeilen5 = reihen.map((ps) => {
        const alters = (ps.kinderAlter || ps.kinder).map((p) => B.alter(p));
        return `<div class="az4"><span class="num-lab gross">${schluessel(ps.stufe.id, ps.stufe.kurz)}</span><span class="az4-val">${zahl(B.median(alters), 1)}<small> J.</small></span>${streifen(ps.stufe, alters, 140, 16)}<small class="az-span">${Math.floor(Math.min(...alters))}–${Math.floor(Math.max(...alters))}</small></div>`;
      });
      return `<div class="fill-col"><div class="az4-list">${zeilen5.join('')}</div><div class="foot muted">Median · Linie: jüngste bis älteste · Fläche: Grenze</div></div>`;
    }
    const rowH = Math.max(28, Math.min(52, (HOEHE['2x2'] - 30) / reihen.length));
    const zeilen = reihen.map((ps) => {
      const alters = (ps.kinderAlter || ps.kinder).map((p) => B.alter(p));
      return `<div class="az4" style="height:${rowH}px"><span class="num-lab gross">${schluessel(ps.stufe.id, ps.stufe.kurz)}</span><span class="az4-val">${zahl(B.median(alters), 1)}<small> J.</small></span>${streifen(ps.stufe, alters, 140, Math.min(18, rowH - 14))}<small class="az-span">${Math.floor(Math.min(...alters))}–${Math.floor(Math.max(...alters))}</small></div>`;
    });
    return `<div>${zeilen.join('')}</div><div class="foot muted">Median · Linie von jüngster bis ältester Person · Fläche = Altersgrenze</div>`;
  }

  function bindung4(ctx, g) {
    const { k } = ctx;
    const ziel = k.ziele.neuProJahr;
    const meter = ziel > 0 ? `<div class="meter"><i style="width:${Math.min(100, (k.neu.length / ziel) * 100)}%"></i></div>` : '';
    const zielText = ziel > 0 ? `Ziel ${ziel} pro Jahr` : 'kein Ziel gesetzt';
    if (g === '1x1') {
      // Eintritte je Monat der letzten zwölf Monate.
      const monate = [];
      for (let i = 11; i >= 0; i--) {
        const d = new Date(D.heute.getFullYear(), D.heute.getMonth() - i, 1);
        monate.push({ j: d.getFullYear(), m: d.getMonth(), n: 0 });
      }
      for (const p of k.neu) {
        const t = monate.find((x) => x.j === p.eintritt.getFullYear() && x.m === p.eintritt.getMonth());
        if (t) t.n++;
      }
      const maxN = mindestens1(Math.max(0, ...monate.map((x) => x.n)));
      const bw = INNEN['1x1'];
      const slot = bw / 12;
      const w = Math.min(8, slot - 3);
      let inhalt = '';
      monate.forEach((x, i) => {
        const h = x.n ? Math.max(3, (x.n / maxN) * 20) : 0;
        inhalt += `<rect x="${(i * slot + (slot - w) / 2).toFixed(1)}" y="${22 - h}" width="${w}" height="${h}" rx="1.5" fill="var(--primary)"><title>${MONATE[x.m]} ${x.j}: ${x.n}</title></rect>`;
      });
      inhalt += `<line x1="0" x2="${bw}" y1="22.5" y2="22.5" stroke="var(--grid)"/>`;
      inhalt += `<text x="0" y="34" dominant-baseline="text-after-edge" class="t-axis">${MONATE[monate[0].m]}</text><text x="${bw}" y="34" dominant-baseline="text-after-edge" class="t-axis" text-anchor="end">${MONATE[monate[11].m]}</text>`;
      return fuellen(`<div class="zk-val">${k.neu.length}</div>${meter}<div class="stat-sub">${zielText}</div>`, svg(bw, 34, inhalt));
    }
    return `<div class="trio mitte">
      <div><div class="stat-lab">Neu in 12 Mon.</div><div class="stat-val">${k.neu.length}</div>${meter}<div class="stat-sub">${ziel > 0 ? `Ziel ${ziel}` : 'kein Ziel'}</div></div>
      <div><div class="stat-lab">Kinder dabei</div><div class="stat-val">${zahl(k.dauerKinder, 1)}<small> J.</small></div><div class="stat-sub">Median</div></div>
      <div><div class="stat-lab">Leitende dabei</div><div class="stat-val">${zahl(k.dauerLeitende, 1)}<small> J.</small></div><div class="stat-sub">Median</div></div>
    </div><div class="foot muted">Nur heutige Mitglieder</div>`;
  }

  function verlauf4(ctx, g) {
    const breite = g === '1x1' ? INNEN['1x1'] : 236;
    const n = g === '1x1' ? 6 : 12;
    const start = new Date(D.heute.getFullYear(), D.heute.getMonth() + 1, 1);
    const slot = breite / n;
    let inhalt = `<line x1="0" x2="${breite}" y1="40.5" y2="40.5" stroke="var(--grid)"/>`;
    for (let i = 0; i < n; i++) {
      const d = new Date(start.getFullYear(), start.getMonth() + i, 1);
      inhalt += `<line x1="${(i * slot + slot / 2).toFixed(1)}" x2="${(i * slot + slot / 2).toFixed(1)}" y1="38" y2="43" stroke="var(--grid)"/>`;
      if (g !== '1x1' || i % 2 === 0) inhalt += `<text x="${(i * slot + slot / 2).toFixed(1)}" y="55" class="t-axis" text-anchor="middle">${MONATE[d.getMonth()].slice(0, g === '1x1' ? 3 : 1)}</text>`;
    }
    inhalt += `<circle cx="${(slot / 2).toFixed(1)}" cy="18" r="4" fill="var(--primary)"><title>Erster Wert ${MONATE[start.getMonth()]} ${start.getFullYear()}</title></circle>`;
    const kurve = svg(breite, 58, inhalt);
    if (g === '1x1') return fuellen(kurve, `<div class="stat-sub"><b class="fg">Ab ${MONATE[start.getMonth()]} ${start.getFullYear()}</b><br>monatliche Summen</div>`);
    if (R5) return `<div class="verlauf4">${kurve}<div class="stat-sub"><b class="fg">Ab ${MONATE[start.getMonth()]}.</b><br>monatlich</div></div>`;
    return `<div class="verlauf4">${kurve}<div class="stat-sub"><b class="fg">Aufzeichnung läuft</b><br>nur Summen, nur auf diesem Gerät</div></div>`;
  }

  function merkmal4(ctx, items, einheit) {
    const farben = D.merkmal[ctx.modus];
    const summe = items.reduce((a, x) => a + x.wert, 0);
    // Nur kurze Kürzel im Ring (w, m, ev.), keine Prozente: in 1×1 sonst nicht
    // lesbar. Längere Kürzel und kleine Anteile stehen in der Mini-Legende.
    const imRing = (x) => x.wert / (summe || 1) >= 0.12 && x.kurz.length <= 3;
    const klein = items.filter((x) => x.wert && !imRing(x));
    // In der Mitte nur die Zahl; ein zweites Wort kollidiert mit den Kürzeln im Ring.
    const groesse = R5 ? Math.max(60, Math.min(96, HOEHE['1x1'] - Math.ceil(13 * SKALA) - 8)) : 88;
    const ring = R5 ? Math.round(groesse * 0.27) : 25;
    const kreis = B.donut(ctx, items.map((x) => ({ ...x, kurz: imRing(x) ? x.kurz : '', inlay: '' })), { groesse, ring, zentrum: [summe, ''], unter: 'inlay' });
    const rest = klein.map((x) => `<span class="key"><i class="sw" style="background:${farben[items.indexOf(x)]}"></i>${esc(x.kurz)}</span>`).join('');
    return `<div class="donut-1x1">${kreis}</div><div class="keys mini">${rest || '&nbsp;'}</div>`;
  }

  // Tortendiagramm ohne Loch, Anzahl in den Stücken.
  function torte(ctx, teile, groesse) {
    const sichtbar = teile.filter(([, v]) => v > 0);
    const summe = sichtbar.reduce((a, [, v]) => a + v, 0);
    const c = groesse / 2;
    const r = c - 1;
    if (!summe) return svg(groesse, groesse, `<circle cx="${c}" cy="${c}" r="${r}" fill="var(--grid)"/>`);
    const p = (rad, a) => `${(c + rad * Math.cos(a)).toFixed(2)},${(c + rad * Math.sin(a)).toFixed(2)}`;
    let a = -Math.PI / 2;
    let inhalt = '';
    let labels = '';
    sichtbar.forEach(([id, v]) => {
      const w = (v / summe) * Math.PI * 2;
      const titelText = `<title>${esc(B.stufeById[id].name)}: ${v}</title>`;
      inhalt += w >= Math.PI * 2 - 1e-6
        ? `<circle cx="${c}" cy="${c}" r="${r}" fill="${farbe(id)}"${kontur(id)}>${titelText}</circle>`
        : `<path d="M${c},${c} L${p(r, a)} A${r},${r} 0 ${w > Math.PI ? 1 : 0} 1 ${p(r, a + w)} Z" fill="${farbe(id)}" stroke="var(--surface)" stroke-width="2" stroke-linejoin="round">${titelText}</path>`;
      if (v / summe >= 0.12) {
        const am = a + w / 2;
        labels += `<text x="${(c + r * 0.6 * Math.cos(am)).toFixed(1)}" y="${(c + r * 0.6 * Math.sin(am) + 4).toFixed(1)}" text-anchor="middle" class="t-in1" fill="${B.tinteAuf(D.stufenfarben[ctx.modus][id])}">${v}</text>`;
      }
      a += w;
    });
    return svg(groesse, groesse, inhalt + labels);
  }

  function slots(wert, ziel, breite) {
    const n = Math.max(1, Math.min(12, ziel));
    const w = (breite - 4 * (n - 1)) / n;
    let inhalt = '';
    for (let i = 0; i < n; i++) inhalt += `<rect x="${(i * (w + 4)).toFixed(1)}" y="0" width="${w.toFixed(1)}" height="10" rx="3" fill="${i < wert ? 'var(--primary)' : 'var(--primary-lite)'}"/>`;
    return svg(breite, 10, inhalt);
  }

  function eigen4(ctx, g, kachel) {
    const teile = Object.entries(kachel.aufteilung || {}).filter(([, v]) => v > 0);
    const hatZiel = kachel.ziel > 0;
    const zielZeile = hatZiel ? `<div class="stat-sub">${kachel.wert} von ${kachel.ziel} ${esc(kachel.zielText || '')}</div>` : '';
    if (g === '1x1') {
      if (teile.length) {
        return `<div class="pie-1x1"><div><div class="zk-val">${kachel.wert}</div>${miniKeys(teile, false)}</div>${torte(ctx, teile, 76)}</div>`;
      }
      if (hatZiel) return fuellen(`<div class="zk-val">${kachel.wert}</div>`, `${slots(kachel.wert, kachel.ziel, INNEN['1x1'])}${zielZeile}`);
      return fuellen(`<div class="zk-val">${kachel.wert}</div>`, '<div class="stat-sub">Personen</div>');
    }
    const links = `<div class="zk-links"><div class="zk-val gross">${kachel.wert}</div><div class="stat-sub">Personen</div></div>`;
    if (R5) {
      const rechts = teile.length
        ? `${stufenTeile(teile, 200, 18, { zahlen: true, modus: ctx.modus })}${miniKeys(teile)}`
        : hatZiel ? `${slots(kachel.wert, kachel.ziel, 200)}${zielZeile}` : '';
      return `<div class="zk-drittel">${links}<div class="zk-rechts">${rechts}</div></div>`;
    }
    if (teile.length) {
      return `<div class="zk-2x1 r4"><div><div class="zk-val gross">${kachel.wert}</div><div class="stat-sub">Personen</div></div>
        <div class="zk-right r4">${stufenTeile(teile, 200, 18, { zahlen: true, modus: ctx.modus })}${miniKeys(teile)}</div></div>`;
    }
    if (hatZiel) {
      return `<div class="zk-2x1 r4"><div><div class="zk-val gross">${kachel.wert}</div><div class="stat-sub">Personen</div></div><div class="zk-right r4">${slots(kachel.wert, kachel.ziel, 200)}${zielZeile}</div></div>`;
    }
    return `<div class="zk-2x1 r4"><div><div class="zk-val gross">${kachel.wert}</div><div class="stat-sub">Personen</div></div><div></div></div>`;
  }

  const KATALOG = [
    { id: 'personen', titel: 'Personen', bereich: 'Mitglieder', groessen: ['1x1', '2x1'], render: personen },
    { id: 'stufen', titel: 'Stufen', bereich: 'Mitglieder', groessen: ['2x1'], render: stufen },
    { id: 'gruppen', titel: 'Gruppen', bereich: 'Stufen', groessen: ['2x1', '2x2'], render: gruppen },
    { id: 'alter', titel: 'Altersstruktur', bereich: 'Stufen', groessen: ['2x2'], render: alter },
    { id: 'alterZahlen', titel: 'Alter in Zahlen', bereich: 'Stufen', groessen: ['2x1', '2x2'], render: alterZahlen },
    { id: 'wechsel', titel: 'Stufenwechsel', bereich: 'Entwicklung', groessen: ['1x1', '2x1', '2x2'], render: wechsel },
    { id: 'bindung', titel: 'Neu in 12 Monaten', titel2: 'Bindung', bereich: 'Entwicklung', groessen: ['1x1', '2x1'], render: bindung },
    { id: 'verlauf', titel: 'Verlauf', bereich: 'Entwicklung', groessen: R3 ? ['1x1', '2x1'] : ['2x1'], render: verlauf },
    { id: 'geschlecht', titel: 'Geschlecht', bereich: 'Zusammensetzung', groessen: ['1x1', '2x1'], render: (c, g) => merkmal(c, c.k.geschlecht, g, 'Kinder') },
    { id: 'konfession', titel: 'Konfession', bereich: 'Zusammensetzung', groessen: ['1x1', '2x1'], render: (c, g) => merkmal(c, c.k.konfession, g, 'Kinder') },
    { id: 'standorte', titel: 'Standorte', bereich: 'Zusammensetzung', groessen: ['2x1', '2x2'], render: standorte },
  ];
  const katalogById = Object.fromEntries(KATALOG.map((w) => [w.id, w]));

  function widgetFuer(ctx, ref) {
    if (ref.startsWith('eigen:')) {
      const kachel = ctx.k.eigeneKacheln[Number(ref.split(':')[1])];
      return { id: ref, titel: kachel.titel, bereich: 'Eigene', groessen: ['1x1', '2x1'], render: (c, g) => eigen(c, g, kachel), eigen: true };
    }
    return katalogById[ref];
  }

  function kachel(ctx, ref, groesse, opts = {}) {
    const w = widgetFuer(ctx, ref);
    const titel = groesse !== '1x1' && w.titel2 ? w.titel2 : w.titel;
    const minus = R3
      ? '<button class="k-minus r3" data-aktion="entfernen" title="Entfernen" aria-label="Entfernen"><i></i></button>'
      : '<button class="k-minus" data-aktion="entfernen" title="Entfernen">−</button>';
    const bearbeiten = opts.bearbeiten
      ? `${minus}${w.groessen.length > 1 ? '<span class="k-resize" data-aktion="groesse" title="Ecke ziehen"></span>' : ''}`
      : '';
    // Runde 3: Kacheln sind (noch) nicht antippbar, daher kein Chevron.
    const kopfZeile = `<div class="tile-head"><span class="th">${esc(titel)}</span>${R3 ? '' : '<span class="tile-more">›</span>'}</div>`;
    const inhalt = `${kopfZeile}<div class="tile-body">${w.render(ctx, groesse, opts)}</div>`;
    return `<div class="tile t${groesse}${opts.klasse ? ` ${opts.klasse}` : ''}" data-ref="${esc(ref)}" data-groesse="${groesse}"${opts.index !== undefined ? ` data-i="${opts.index}"` : ''}>
      ${R3 ? `<div class="tile-clip">${inhalt}</div>` : inhalt}${bearbeiten}</div>`;
  }

  function raster(ctx, liste, opts = {}) {
    return `<div class="kgrid">${liste.filter(Boolean).map(([ref, g, o]) => kachel(ctx, ref, g, { ...opts, ...(o || {}) })).join('')}</div>`;
  }

  // ------------------------------------------------------------- Kopf
  function stufenbandZeile(ctx, breite) {
    const teile = ctx.k.proStufe.filter((s) => s.kinder.length);
    const band = B.stufenband(ctx, { breite, hoehe: 10, legende: false });
    return `${R5 ? band.replace(` width="${breite}"`, ' width="100%" preserveAspectRatio="none"') : band}
      <div class="band-leg">${teile.map((s) => `<span><i class="sw${s.stufe.id === 'biber' ? ' biber' : ''}" style="background:${farbe(s.stufe.id)}"></i>${esc(s.stufe.kurz)} <b>${s.kinder.length}</b></span>`).join('')}</div>`;
  }

  function kopf(ctx, variante, aktiverTab = 0) {
    const { k } = ctx;
    let zeile1;
    let zeile2;
    const pille = (eintraege, aktiv) => `<div class="pill pr">${eintraege.map((t, i) => `<span class="${i === aktiv ? 'on' : ''}">${esc(t)}</span>`).join('')}</div>`;
    if (variante === 'H1') {
      zeile1 = `<div class="h1"><div class="h1-num"><b>${k.personen}</b><span>Personen</span></div><div class="h1-band">${stufenbandZeile(ctx, 262)}</div></div>`;
      zeile2 = pille([k.stamm.name, 'Bundesweit'], 0);
    } else if (variante === 'H2') {
      const t = (wert, text, hl) => `<div class="kpi${hl ? ' hl' : ''}"><b>${wert}</b><span>${text}</span></div>`;
      zeile1 = `<div class="kpis">${t(k.personen, 'Personen', true)}${t(k.kinder.length, 'Kinder & Jugendl.')}${t(k.leitende.length, 'Leitende')}</div>`;
      zeile2 = pille([k.stamm.name, 'Bundesweit'], 0);
    } else {
      zeile1 = `<div class="h3"><div class="h3-name">${esc(k.stamm.name)}</div><div class="h1-num r"><b>${k.personen}</b><span>Personen</span></div></div>`;
      zeile2 = pille(['Überblick', 'Stufen', 'Entwicklung', 'Bundesweit'], aktiverTab);
    }
    return `<header class="hdr pr"><div class="row1">${zeile1}</div><div class="row2">${zeile2}</div></header>`;
  }

  const THEMEN = ['Überblick', 'Stufen', 'Entwicklung'];
  function themenLeiste(aktiv, sichtbar = [true, true, true]) {
    // Sind Stufen und Entwicklung ausgeblendet, entfällt die Leiste ganz.
    if (!sichtbar[1] && !sichtbar[2]) return '<div class="themen-leer"></div>';
    // Runde 3: Stift nur im Überblick, denn nur dieser ist anpassbar.
    // Runde 4: Bearbeiten nur noch über den Knopf unten.
    const stift = !R4 && (!R3 || aktiv === 0) ? '<span class="themen-edit" data-aktion="bearbeiten">✎</span>' : '';
    return `<div class="themen">${THEMEN.map((t, i) => (sichtbar[i] ? `<span class="${i === aktiv ? 'on' : ''}">${t}</span>` : '')).join('')}${stift}</div>`;
  }

  function tabKacheln(kopfVariante, tab) {
    if (tab === 0) {
      return [
        kopfVariante === 'H1' ? ['gruppen', '2x1'] : ['stufen', '2x1'],
        ['wechsel', '1x1'], ['bindung', '1x1'],
        ['geschlecht', '1x1'], ['konfession', '1x1'],
        ['standorte', '2x1'],
        ['eigen:0', '1x1'], ['eigen:1', '1x1'],
      ];
    }
    if (tab === 1) return [['gruppen', '2x2'], ['alter', '2x2'], ['alterZahlen', '2x1']];
    return [['wechsel', '2x2'], ['bindung', '2x1'], ['verlauf', '2x1']];
  }

  function seite(ctx, kopfVariante, tab, sichtbar) {
    const kopfHtml = kopf(ctx, kopfVariante, tab);
    const leiste = kopfVariante === 'H3' ? '' : themenLeiste(tab, sichtbar);
    // Runde 3: nur der Überblick ist anpassbar; Stufen und Entwicklung sind fest.
    const knopf = !R3 || tab === 0 ? '<div class="adjust"><span>✎ Bearbeiten</span></div>' : '';
    const inhalt = `${leiste}${raster(ctx, tabKacheln(kopfVariante, tab))}${knopf}`;
    return { kopfHtml, inhalt };
  }

  window.KACHELN = {
    SPALTE, get ZEILE() { return ZEILE; }, get SKALA() { return SKALA; }, setzeSkala, mitSkala,
    LUECKE, INNEN, HOEHE, KATALOG, katalogById, widgetFuer,
    kachel, raster, kopf, themenLeiste, tabKacheln, seite, gruppen, wechsel, zielFuerStufe,
  };
})();

// Bausteine der Statistik-Entwürfe: Kennzahlen aus daten.js und ihre
// Darstellung in den Stilen "punkte", "balken" und "zahlen".
//
// Regeln (dataviz): Farbe trägt Identität, Text bleibt in Texttönen; jede
// Stufenmarke hat ein Textlabel (Pfadi/Rover sind für Rot-Grün-Schwäche
// kaum trennbar); 2 px Flächenabstand statt Rahmen; Biber-Weiß bekommt auf
// hellem Grund eine feine Kontur. Leitung = Ring in Stufenfarbe, Kinder =
// gefüllter Punkt (Form statt fünfter Farbe).
(function () {
  const D = window.STATISTIK;
  const MS_JAHR = 365.25 * 24 * 3600 * 1000;

  const zahl = (n, d = 0) =>
    Number(n).toLocaleString('de-DE', { minimumFractionDigits: d, maximumFractionDigits: d });
  const datum = (d) => d.toLocaleDateString('de-DE', { day: '2-digit', month: '2-digit', year: 'numeric' });
  const datumKurz = (d) => d.toLocaleDateString('de-DE', { day: '2-digit', month: '2-digit' });
  const esc = (s) =>
    String(s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]);
  const alter = (p, am = D.heute) => (am - p.geburt) / MS_JAHR;
  const median = (xs) => {
    if (!xs.length) return 0;
    const s = [...xs].sort((a, b) => a - b);
    const m = s.length >> 1;
    return s.length % 2 ? s[m] : (s[m - 1] + s[m]) / 2;
  };
  const stufeById = Object.fromEntries(D.stufen.map((s, i) => [s.id, { ...s, index: i }]));
  const farbe = (id) => `var(--st-${id})`;
  const kontur = (id) => (id === 'biber' ? ' stroke="var(--biber-ring)" stroke-width="1"' : '');

  function luminanz(hex) {
    const n = hex.replace('#', '');
    const [r, g, b] = [0, 2, 4].map((i) => {
      const c = parseInt(n.slice(i, i + 2), 16) / 255;
      return c <= 0.03928 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4);
    });
    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
  }
  // Schrift auf Farbfläche: Weiß oder Tinte, je nachdem was mehr Kontrast hat.
  const tinteAuf = (hex) => {
    const l = luminanz(hex);
    return (1.05) / (l + 0.05) >= (l + 0.05) / 0.0588 ? '#ffffff' : '#111114';
  };

  // ---------------------------------------------------------------- Kennzahlen
  // Platzhalter 1900-01-01 wie Mitglied.hatBekanntesGeburtsdatum in der App.
  const bekannt = (datumWert) => datumWert && datumWert.getFullYear() > 1900;

  function kennzahlen(stamm) {
    const kinder = stamm.personen.filter((p) => !p.leitung);
    const leitende = stamm.personen.filter((p) => p.leitung);
    const proStufe = D.stufen.map((s) => ({
      stufe: s,
      gruppen: stamm.gruppen
        .filter((g) => g.stufe === s.id)
        .map((g) => ({
          ...g,
          kinder: kinder.filter((p) => p.gruppe === g.id),
          leitende: leitende.filter((p) => p.gruppe === g.id),
        })),
      kinder: kinder.filter((p) => p.stufe === s.id),
      kinderAlter: kinder.filter((p) => p.stufe === s.id && bekannt(p.geburt)),
      leitende: leitende.filter((p) => p.stufe === s.id),
    }));

    // Stufenwechsel wie ErmittleStufenwechselVorschlaegeUseCase: fällig ab
    // Mindestalter der Zielstufe im Stichtagsjahr, überfällig nach Höchstalter.
    const jahr = D.stichtag.getFullYear();
    const wechsel = [];
    for (const p of kinder) {
      if (!bekannt(p.geburt)) continue;
      const s = stufeById[p.stufe];
      const geburtsjahr = p.geburt.getFullYear();
      if (s.id === 'rover') {
        if (jahr > geburtsjahr + s.max) wechsel.push({ p, von: 'rover', nach: null, ueberfaellig: false });
        continue;
      }
      const ziel = D.stufen[s.index + 1];
      if (jahr >= geburtsjahr + ziel.min) {
        wechsel.push({ p, von: s.id, nach: ziel.id, ueberfaellig: jahr > geburtsjahr + s.max });
      }
    }
    const prognose = proStufe.map((ps) => {
      const ab = wechsel.filter((w) => w.von === ps.stufe.id);
      const zu = wechsel.filter((w) => w.nach === ps.stufe.id);
      return {
        stufe: ps.stufe,
        jetzt: ps.kinder.length,
        ab: ab.length,
        zu: zu.length,
        danach: ps.kinder.length - ab.length + zu.length,
        bleiben: ps.kinder.filter((p) => !ab.some((w) => w.p === p)),
        gehen: ab.map((w) => w.p),
        kommen: zu.map((w) => w.p),
        ueberfaellig: ab.filter((w) => w.ueberfaellig).length,
      };
    });

    const vor12 = new Date(D.heute);
    vor12.setFullYear(vor12.getFullYear() - 1);
    // Eintritt in der Zukunft zählt als 0 Jahre, Platzhalter-Eintritte fallen heraus.
    const dauer = (p) => Math.max(0, (D.heute - p.eintritt) / MS_JAHR);
    const mitEintritt = (liste) => liste.filter((p) => bekannt(p.eintritt));
    const jahre = [];
    const bisJahr = D.heute.getFullYear();
    for (let y = bisJahr - 9; y <= bisJahr; y++) jahre.push(y);
    const eintritte = [
      { label: 'früher', wert: mitEintritt(stamm.personen).filter((p) => p.eintritt.getFullYear() < jahre[0]).length },
      ...jahre.map((y) => ({ label: String(y), kurz: `’${String(y).slice(2)}`, wert: stamm.personen.filter((p) => p.eintritt.getFullYear() === y).length })),
    ];

    const zaehle = (liste, f) => liste.filter(f).length;
    const geschlecht = [
      { label: 'weiblich', kurz: 'w', wert: zaehle(kinder, (p) => p.gender === 'w') },
      { label: 'männlich', kurz: 'm', wert: zaehle(kinder, (p) => p.gender === 'm') },
      { label: 'divers', kurz: 'd', wert: zaehle(kinder, (p) => p.gender === 'd') },
      { label: 'ohne Angabe', kurz: 'k. A.', wert: zaehle(kinder, (p) => !p.gender) },
    ];
    // Konfession wie _buildMockConfessionLegend (feste Anteile).
    const n = kinder.length;
    const kath = Math.round(n * 0.62);
    const ev = Math.round(n * 0.18);
    const los = Math.round(n * 0.14);
    const konfession = [
      { label: 'katholisch', kurz: 'kath.', wert: kath },
      { label: 'evangelisch', kurz: 'ev.', wert: ev },
      { label: 'konfessionslos', kurz: 'ohne', wert: los },
      { label: 'andere', kurz: 'and.', wert: Math.max(0, n - kath - ev - los) },
    ];

    return {
      stamm, kinder, leitende, sonstige: stamm.sonstige,
      personen: stamm.personen.length + stamm.sonstige,
      proStufe, wechsel, prognose,
      wechselAnzahl: wechsel.filter((w) => w.nach).length,
      ueberfaellig: wechsel.filter((w) => w.ueberfaellig).length,
      roverRaus: wechsel.filter((w) => !w.nach).length,
      neu: stamm.personen.filter((p) => p.eintritt >= vor12),
      dauerKinder: median(mitEintritt(kinder).map(dauer)),
      dauerLeitende: median(mitEintritt(leitende).map(dauer)),
      ohneGeburt: stamm.personen.filter((p) => !bekannt(p.geburt)).length,
      eintritte, geschlecht, konfession,
      ziele: stamm.ziele,
      eigeneKacheln: stamm.eigeneKacheln,
      gruppenMax: Math.max(0, ...proStufe.flatMap((s) => s.gruppen.map((g) => g.kinder.length))),
    };
  }

  // ----------------------------------------------------------- SVG-Helfer
  const svg = (w, h, inhalt, extra = '') =>
    `<svg class="viz" width="${w}" height="${h}" viewBox="0 0 ${w} ${h}" ${extra}>${inhalt}</svg>`;
  const titel = (t) => `<title>${esc(t)}</title>`;

  // Balken mit 4 px gerundetem Datenende, eckig an der Grundlinie.
  const schliessen = (tag, tip) => (tip ? `>${titel(tip)}</${tag}>` : '/>');
  function balkenH(x, y, w, h, fill, extra = '', tip = '') {
    if (w <= 0) return '';
    const r = Math.min(4, w, h / 2);
    return `<path d="M${x},${y} h${w - r} a${r},${r} 0 0 1 ${r},${r} v${h - 2 * r} a${r},${r} 0 0 1 -${r},${r} h-${w - r} z" fill="${fill}"${extra}${schliessen('path', tip)}`;
  }
  function saeule(x, yBasis, w, h, fill, extra = '', tip = '') {
    if (h <= 0) return '';
    const r = Math.min(3, w / 2, h);
    return `<path d="M${x},${yBasis} v-${h - r} a${r},${r} 0 0 1 ${r},-${r} h${w - 2 * r} a${r},${r} 0 0 1 ${r},${r} v${h - r} z" fill="${fill}"${extra}${schliessen('path', tip)}`;
  }
  function punkt(cx, cy, stufe, art, tip = '') {
    // art: kind | leitung | geht | kommt | ueber
    const r = 4;
    if (art === 'leitung') {
      const stroke = stufe === 'biber' ? 'var(--biber-ring-stark)' : farbe(stufe);
      return `<circle cx="${cx}" cy="${cy}" r="${r - 0.75}" fill="var(--surface)" stroke="${stroke}" stroke-width="1.75"${schliessen('circle', tip)}`;
    }
    const opacity = art === 'geht' ? ' opacity="0.28"' : '';
    const ring = art === 'kommt' || art === 'ueber'
      ? ` stroke="var(--fg)" stroke-width="1.5"`
      : kontur(stufe);
    return `<circle cx="${cx}" cy="${cy}" r="${art === 'kommt' || art === 'ueber' ? r - 0.5 : r}" fill="${farbe(stufe)}"${ring}${opacity}${schliessen('circle', tip)}`;
  }
  // Punkte in Zeilen umbrechen.
  function punktfluss(liste, breite, startY = 5) {
    const schritt = 11;
    const proZeile = Math.max(1, Math.floor((breite + 3) / schritt));
    let inhalt = '';
    liste.forEach((e, i) => {
      const cx = 5 + (i % proZeile) * schritt;
      const cy = startY + Math.floor(i / proZeile) * schritt;
      inhalt += punkt(cx, cy, e.stufe, e.art, e.titel);
    });
    const zeilen = Math.max(1, Math.ceil(liste.length / proZeile));
    return { inhalt, hoehe: startY + (zeilen - 1) * schritt + 6 };
  }

  const schluessel = (id, text, wert) =>
    `<span class="key"><i class="sw${id === 'biber' ? ' biber' : ''}" style="background:${farbe(id)}"></i>${esc(text)}${wert !== undefined ? ` <b>${wert}</b>` : ''}</span>`;

  // ----------------------------------------------------------- Stufenband
  function stufenband(ctx, { breite = 326, hoehe = 12, legende = true } = {}) {
    const teile = ctx.k.proStufe.filter((s) => s.kinder.length);
    const summe = teile.reduce((a, s) => a + s.kinder.length, 0);
    if (!summe) return svg(breite, hoehe, `<rect width="${breite}" height="${hoehe}" rx="3" fill="var(--grid)"/>`) + (legende ? '<div class="keys">Noch keine Kinder & Jugendlichen</div>' : '');
    const gap = 2;
    const nutz = breite - gap * (teile.length - 1);
    let x = 0;
    let inhalt = '';
    for (const s of teile) {
      const w = (nutz * s.kinder.length) / summe;
      inhalt += `<rect x="${x.toFixed(1)}" y="0" width="${w.toFixed(1)}" height="${hoehe}" rx="3" fill="${farbe(s.stufe.id)}"${kontur(s.stufe.id)}>${titel(`${s.stufe.name}: ${s.kinder.length}`)}</rect>`;
      x += w + gap;
    }
    const leg = legende
      ? `<div class="keys">${teile.map((s) => schluessel(s.stufe.id, s.stufe.kurz, s.kinder.length)).join('')}</div>`
      : '';
    return svg(breite, hoehe, inhalt) + leg;
  }

  // ------------------------------------------------------- Stufen & Gruppen
  function stufenZeilen(ctx, { breite = 326, kompakt = false } = {}) {
    const { k, stil } = ctx;
    const skala = Math.max(1, k.gruppenMax, ...Object.values(k.ziele.gruppeMax));
    const vizBreite = breite - 118;
    const zeilen = k.proStufe.flatMap((ps) =>
      ps.gruppen.map((g) => {
        const ziel = k.ziele.gruppeMax[ps.stufe.id];
        let viz = '';
        if (stil === 'balken') {
          const w = (vizBreite * g.kinder.length) / skala;
          const zx = (vizBreite * ziel) / skala;
          viz = svg(vizBreite, 12,
            `<rect x="0" y="5" width="${vizBreite}" height="2" rx="1" fill="var(--grid)"/>` +
            balkenH(0, 1, w, 10, farbe(ps.stufe.id), kontur(ps.stufe.id)) +
            (ziel ? `<rect x="${(zx - 0.5).toFixed(1)}" y="0" width="1" height="12" fill="var(--fg2)">${titel(`Ziel: höchstens ${ziel}`)}</rect>` : ''));
        } else if (stil === 'punkte') {
          const liste = [
            ...g.kinder.map(() => ({ stufe: ps.stufe.id, art: 'kind' })),
            ...g.leitende.map(() => ({ stufe: ps.stufe.id, art: 'leitung' })),
          ];
          const f = punktfluss(liste, vizBreite);
          viz = svg(vizBreite, f.hoehe, f.inhalt);
        } else {
          const w = (vizBreite * g.kinder.length) / skala;
          viz = svg(vizBreite, 4, `<rect x="0" y="0" width="${vizBreite}" height="4" rx="2" fill="var(--grid)"/><rect x="0" y="0" width="${w.toFixed(1)}" height="4" rx="2" fill="${farbe(ps.stufe.id)}"${kontur(ps.stufe.id)}/>`);
        }
        const wert = stil === 'zahlen'
          ? `<div class="grp-val big">${g.kinder.length}<small>+${g.leitende.length}</small></div>`
          : `<div class="grp-val">${g.kinder.length}</div>`;
        return `<div class="grp-row${kompakt ? ' kompakt' : ''}">
          <i class="dot${ps.stufe.id === 'biber' ? ' biber' : ''}" style="background:${farbe(ps.stufe.id)}"></i>
          <div class="grp-main"><div class="grp-name">${esc(g.name)}</div>
            <div class="grp-sub">${esc(ps.stufe.name)} · ${g.leitende.length} Leitende</div>
            <div class="grp-viz">${viz}</div></div>
          ${wert}<span class="chev">›</span></div>`;
      }),
    );
    let fuss = '';
    if (stil === 'balken') fuss = '<div class="foot"><span class="tick"></span> Zielwert „höchstens" je Gruppe</div>';
    if (stil === 'punkte') fuss = `<div class="foot">${svg(10, 10, punkt(5, 5, 'jufi', 'kind'))} Kind/Jugendliche ${svg(10, 10, punkt(5, 5, 'jufi', 'leitung'))} Leitung</div>`;
    if (stil === 'zahlen') fuss = '<div class="foot">Zahl = Kinder und Jugendliche, +Leitende</div>';
    return `<div class="grp-list">${zeilen.join('')}</div>${fuss}`;
  }

  // --------------------------------------------------------- Altersstruktur
  function altersstruktur(ctx, { breite = 326, nurStufe = null, achse = true, einheit = 6, legende: mitLegende = true, ueberLabel = true, achsHoehe = 14 } = {}) {
    const { k, stil } = ctx;
    const reihen = k.proStufe
      .map((ps) => ({ ...ps, kinder: ps.kinderAlter || ps.kinder }))
      .filter((ps) => ps.kinder.length && (!nurStufe || ps.stufe.id === nurStufe));
    if (stil === 'zahlen') return altersZahlen(ctx, reihen, breite);
    const labelBreite = nurStufe ? 0 : 38;
    const rechts = 34;
    const [von, bis] = nurStufe
      ? [stufeById[nurStufe].min - 1, stufeById[nurStufe].max + 3]
      : [3, 23];
    const x0 = labelBreite;
    const pw = breite - labelBreite - (ueberLabel ? rechts : 6);
    const x = (a) => x0 + ((Math.max(von, Math.min(bis, a)) - von) / (bis - von)) * pw;
    const jahrBin = (a) => Math.max(von, Math.min(bis - 1, Math.floor(a)));
    const proJahr = pw / (bis - von);
    let y = 0;
    let inhalt = '';
    const maxProJahr = Math.max(1, ...reihen.flatMap((ps) => {
      const z = {};
      ps.kinder.forEach((p) => { const a = jahrBin(alter(p)); z[a] = (z[a] || 0) + 1; });
      return Object.values(z);
    }));
    for (const ps of reihen) {
      const s = ps.stufe;
      const ueber = ps.kinder.filter((p) => alter(p) >= s.max + 1);
      let marks = '';
      let hoehe;
      if (stil === 'punkte') {
        const stapel = {};
        const pts = ps.kinder
          .map((p) => ({ p, a: alter(p) }))
          .sort((l, r) => l.a - r.a)
          .map(({ p, a }) => {
            const bin = Math.round((x(a) - x0) / 9);
            const c = stapel[bin] || 0;
            stapel[bin] = c + 1;
            return { p, a, cx: x0 + bin * 9, c };
          });
        const maxStapel = Math.max(1, ...Object.values(stapel));
        hoehe = maxStapel * 9 + 10;
        for (const e of pts) {
          const art = e.a >= s.max + 1 ? 'ueber' : 'kind';
          marks += punkt(e.cx, y + hoehe - 9 - e.c * 9, s.id, art, `${s.kurz}: ${zahl(e.a, 1)} Jahre`);
        }
      } else {
        const z = {};
        ps.kinder.forEach((p) => { const a = jahrBin(alter(p)); z[a] = (z[a] || 0) + 1; });
        hoehe = maxProJahr * einheit + 10;
        const w = Math.min(10, proJahr - 3);
        for (const [a, c] of Object.entries(z)) {
          const ax = x(Number(a)) + (proJahr - w) / 2;
          marks += saeule(ax, y + hoehe - 4, w, c * einheit, farbe(s.id), kontur(s.id), `${s.kurz}, ${a} Jahre: ${c}`);
        }
      }
      const bandFill = s.id === 'biber' ? 'var(--biber-band)' : farbe(s.id);
      const bandOp = s.id === 'biber' ? 1 : 0.13;
      inhalt += `<rect x="${x(s.min).toFixed(1)}" y="${y + 1}" width="${(x(s.max + 1) - x(s.min)).toFixed(1)}" height="${hoehe - 4}" rx="4" fill="${bandFill}" opacity="${bandOp}">${titel(`Altersgrenze ${s.kurz}: ${s.min}–${s.max} Jahre`)}</rect>`;
      inhalt += `<line x1="${x0}" x2="${x0 + pw}" y1="${y + hoehe - 3.5}" y2="${y + hoehe - 3.5}" stroke="var(--grid)" stroke-width="1"/>`;
      if (!nurStufe) inhalt += `<text x="0" y="${y + hoehe / 2 + 3}" class="t-lab">${esc(s.kurz)}</text>`;
      inhalt += marks;
      if (ueber.length && ueberLabel) {
        inhalt += `<text x="${breite}" y="${y + hoehe / 2 + 3}" class="t-val" text-anchor="end">↑${ueber.length}</text>`;
      }
      y += hoehe + 4;
    }
    if (achse) {
      for (let a = Math.ceil(von / 2) * 2; a <= bis; a += 2) {
        if (a === bis) continue;
        inhalt += `<text x="${(x(a) + proJahr / 2).toFixed(1)}" y="${y + achsHoehe - 4}" class="t-axis" text-anchor="middle">${a}</text>`;
      }
      y += achsHoehe;
    }
    const legende = nurStufe || !mitLegende ? '' : `<div class="foot"><span class="band"></span> Altersgrenze der Stufe · ↑ über der Grenze${stil === 'punkte' ? ` · ${svg(10, 10, punkt(5, 5, 'woe', 'ueber'))} betroffen` : ''} · Achse: Jahre</div>`;
    return svg(breite, y, inhalt) + legende;
  }

  function altersZahlen(ctx, reihen, breite) {
    const stripB = Math.min(110, breite - 190);
    const zeilen = reihen.map((ps) => {
      const s = ps.stufe;
      const alters = ps.kinder.map((p) => alter(p));
      const lo = Math.min(...alters);
      const hi = Math.max(...alters);
      const med = median(alters);
      const ueber = alters.filter((a) => a >= s.max + 1).length;
      const [von, bis] = [s.min - 2, s.max + 3];
      const x = (a) => ((Math.max(von, Math.min(bis, a)) - von) / (bis - von)) * stripB;
      const bandFill = s.id === 'biber' ? 'var(--biber-band)' : farbe(s.id);
      const strip = svg(stripB, 12,
        `<rect x="${x(s.min)}" y="1" width="${x(s.max + 1) - x(s.min)}" height="10" rx="3" fill="${bandFill}" opacity="${s.id === 'biber' ? 1 : 0.14}"/>` +
        `<rect x="${x(lo)}" y="5" width="${Math.max(2, x(hi) - x(lo))}" height="2" rx="1" fill="${s.id === 'biber' ? 'var(--fg2)' : farbe(s.id)}"/>` +
        `<circle cx="${x(med)}" cy="6" r="4" fill="${farbe(s.id)}" stroke="var(--surface)" stroke-width="2"/>` +
        (s.id === 'biber' ? `<circle cx="${x(med)}" cy="6" r="3.5" fill="none" stroke="var(--biber-ring)" stroke-width="1"/>` : ''));
      return `<div class="num-row"><span class="num-lab">${schluessel(s.id, s.kurz)}</span>
        <span class="num-big">${zahl(med, 1)}<small> J.</small></span>
        <span class="num-strip">${strip}<small>${Math.floor(lo)}–${Math.floor(hi)}</small></span>
        <span class="num-flag">${ueber ? `↑${ueber}` : ''}</span></div>`;
    });
    return `<div class="num-list">${zeilen.join('')}</div><div class="foot">Median · Spanne jüngste bis älteste · Fläche = Altersgrenze · ↑ über der Grenze</div>`;
  }

  // -------------------------------------------------------------- Prognose
  function prognose(ctx, { breite = 326, kopf = true } = {}) {
    const { k, stil } = ctx;
    const reihen = k.prognose.filter((r) => r.jetzt || r.danach);
    const lead = kopf
      ? `<div class="lead"><b>${k.wechselAnzahl}</b> wechseln zum ${datum(D.stichtag)}${k.ueberfaellig ? ` · <b>${k.ueberfaellig}</b> überfällig` : ''}</div>`
      : '';
    let koerper = '';
    if (stil === 'zahlen') {
      koerper = `<table class="tbl"><thead><tr><th></th><th>jetzt</th><th>ab</th><th>zu</th><th>danach</th></tr></thead><tbody>${reihen
        .map((r) => `<tr><td>${schluessel(r.stufe.id, r.stufe.kurz)}</td><td>${r.jetzt}</td><td>${r.ab ? `−${r.ab}` : '–'}</td><td>${r.zu ? `+${r.zu}` : '–'}</td><td><b>${r.danach}</b></td></tr>`)
        .join('')}</tbody></table>`;
    } else if (stil === 'balken') {
      const labelB = 40;
      const rechts = 58;
      const pw = breite - labelB - rechts;
      // Zielwert je Stufe = Höchstgröße je Gruppe × Anzahl Gruppen der Stufe.
      const zielFuer = (id) => (k.ziele.gruppeMax[id] || 0) * Math.max(1, k.proStufe.find((ps) => ps.stufe.id === id).gruppen.length);
      const max = Math.max(...reihen.map((r) => Math.max(r.jetzt, r.danach, zielFuer(r.stufe.id))));
      const x = (v) => labelB + 6 + (v / max) * (pw - 12);
      let inhalt = '';
      reihen.forEach((r, i) => {
        const y = i * 26 + 13;
        const id = r.stufe.id;
        const ziel = zielFuer(id);
        inhalt += `<text x="0" y="${y + 4}" class="t-lab">${esc(r.stufe.kurz)}</text>`;
        inhalt += `<line x1="${labelB}" x2="${labelB + pw}" y1="${y}" y2="${y}" stroke="var(--grid)" stroke-width="1"/>`;
        if (ziel) inhalt += `<rect x="${x(ziel) - 0.5}" y="${y - 9}" width="1" height="18" fill="var(--muted)" opacity="0.7">${titel(`Ziel ${r.stufe.kurz}: höchstens ${ziel}`)}</rect>`;
        inhalt += `<line x1="${x(r.jetzt)}" x2="${x(r.danach)}" y1="${y}" y2="${y}" stroke="var(--muted)" stroke-width="2"/>`;
        inhalt += `<rect x="${x(r.jetzt) - 1}" y="${y - 7}" width="2" height="14" rx="1" fill="var(--fg2)">${titel(`${r.stufe.kurz} jetzt: ${r.jetzt}`)}</rect>`;
        inhalt += `<circle cx="${x(r.danach)}" cy="${y}" r="5.5" fill="${farbe(id)}" stroke="${id === 'biber' ? 'var(--biber-ring-stark)' : 'var(--surface)'}" stroke-width="${id === 'biber' ? 1 : 2}">${titel(`${r.stufe.kurz} danach: ${r.danach}`)}</circle>`;
        const drueber = ziel && r.danach > ziel;
        inhalt += `<text x="${breite}" y="${y + 4}" class="t-val" text-anchor="end">${r.jetzt} → <tspan font-weight="700">${r.danach}</tspan>${drueber ? ' ▲' : ''}</text>`;
      });
      koerper = svg(breite, reihen.length * 26 + 2, inhalt) +
        `<div class="foot">${svg(6, 14, `<rect x="2" y="0" width="2" height="14" rx="1" fill="var(--fg2)"/>`)} jetzt ${svg(12, 12, `<circle cx="6" cy="6" r="5" fill="var(--fg2)"/>`)} nach dem Stichtag ${svg(4, 14, `<rect x="1.5" y="0" width="1" height="14" fill="var(--muted)"/>`)} Zielwert · ▲ darüber</div>`;
    } else {
      const vizB = breite - 40 - 34;
      koerper = reihen
        .map((r) => {
          const liste = [
            ...r.bleiben.map(() => ({ stufe: r.stufe.id, art: 'kind' })),
            ...r.kommen.map(() => ({ stufe: r.stufe.id, art: 'kommt' })),
            ...r.gehen.map(() => ({ stufe: r.stufe.id, art: 'geht' })),
          ];
          const f = punktfluss(liste, vizB);
          return `<div class="prog-row"><span class="num-lab">${esc(r.stufe.kurz)}</span>${svg(vizB, f.hoehe, f.inhalt)}<span class="prog-val">${r.danach}</span></div>`;
        })
        .join('') +
        `<div class="foot">${svg(10, 10, punkt(5, 5, 'pfadi', 'kind'))} bleibt ${svg(10, 10, punkt(5, 5, 'pfadi', 'kommt'))} kommt dazu ${svg(10, 10, punkt(5, 5, 'pfadi', 'geht'))} wechselt weiter</div>`;
    }
    const hinweis = [
      k.roverRaus ? `Rover: ${k.roverRaus} ${k.roverRaus === 1 ? 'wird' : 'werden'} 21` : '',
      'Biber: Neuaufnahmen offen',
    ].filter(Boolean).join(' · ');
    return `${lead}${koerper}<div class="foot muted">${hinweis}</div>`;
  }

  // ---------------------------------------------------------------- Bindung
  function statKachel(label, wert, sub, meter) {
    const m = meter
      ? `<div class="meter"><i style="width:${Math.min(100, (meter.wert / meter.ziel) * 100)}%"></i></div>`
      : '';
    return `<div class="stat"><div class="stat-lab">${esc(label)}</div><div class="stat-val">${wert}</div>${m}<div class="stat-sub">${sub}</div></div>`;
  }

  function bindungKacheln(ctx) {
    const { k } = ctx;
    return `<div class="stats">
      ${statKachel('Neu in 12 Monaten', k.neu.length, `Ziel ${k.ziele.neuProJahr}`, { wert: k.neu.length, ziel: k.ziele.neuProJahr })}
      ${statKachel('Dabei (Median)', `${zahl(k.dauerKinder, 1)}<small> J.</small>`, 'Kinder & Jugendliche')}
      ${statKachel('Leitende (Median)', `${zahl(k.dauerLeitende, 1)}<small> J.</small>`, 'seit Eintritt')}
    </div>`;
  }

  function eintrittsjahre(ctx, { breite = 326 } = {}) {
    const { k, stil } = ctx;
    const e = k.eintritte;
    const max = Math.max(...e.map((x) => x.wert));
    const slot = breite / e.length;
    let inhalt = '';
    let hoehe;
    if (stil === 'punkte') {
      const r = 3.5;
      const schritt = 8.5;
      hoehe = max * schritt + 26;
      e.forEach((x, i) => {
        const cx = i * slot + slot / 2;
        for (let j = 0; j < x.wert; j++) {
          inhalt += `<circle cx="${cx.toFixed(1)}" cy="${(hoehe - 18 - j * schritt).toFixed(1)}" r="${r}" fill="var(--primary)"/>`;
        }
        inhalt += `<rect x="${i * slot}" y="0" width="${slot}" height="${hoehe - 14}" fill="transparent">${titel(`${x.label}: ${x.wert}`)}</rect>`;
      });
    } else {
      const ph = 70;
      hoehe = ph + 30;
      const w = Math.min(18, slot - 6);
      e.forEach((x, i) => {
        const h = (x.wert / max) * ph;
        const bx = i * slot + (slot - w) / 2;
        inhalt += saeule(bx, hoehe - 16, w, h, 'var(--primary)', '', `${x.label}: ${x.wert}`);
        if (x.wert === max || i === e.length - 1) {
          inhalt += `<text x="${(bx + w / 2).toFixed(1)}" y="${(hoehe - 20 - h).toFixed(1)}" class="t-val" text-anchor="middle">${x.wert}</text>`;
        }
      });
      inhalt += `<line x1="0" x2="${breite}" y1="${hoehe - 15.5}" y2="${hoehe - 15.5}" stroke="var(--grid)"/>`;
    }
    e.forEach((x, i) => {
      if (i === 0 || i % 2 === 1 || i === e.length - 1) {
        inhalt += `<text x="${(i * slot + slot / 2).toFixed(1)}" y="${hoehe - 3}" class="t-axis" text-anchor="middle">${x.kurz || x.label}</text>`;
      }
    });
    return svg(breite, hoehe, inhalt);
  }

  function bindung(ctx, { breite = 326 } = {}) {
    const { k, stil } = ctx;
    const chart = stil === 'zahlen'
      ? `<div class="spark-row"><span>Eintritte je Jahr</span>${sparkline(k.eintritte.slice(1).map((x) => x.wert), 120, 24)}<b>${k.eintritte[k.eintritte.length - 1].wert}</b><small>in ${D.heute.getFullYear()}</small></div>`
      : `<div class="sub-head">Eintrittsjahr der heutigen Mitglieder</div>${eintrittsjahre(ctx, { breite })}`;
    return `${bindungKacheln(ctx)}${chart}
      <div class="foot muted">Nur heutige Mitglieder – wer ausgetreten ist, fehlt in den Daten.</div>
      <div class="verlauf"><span class="pulse"></span> Verlauf ab jetzt: Summen werden monatlich auf dem Gerät gespeichert, erste Kurve ab November.</div>`;
  }

  function sparkline(werte, w, h) {
    const max = Math.max(...werte, 1);
    const pts = werte.map((v, i) => `${((i / (werte.length - 1)) * (w - 6) + 3).toFixed(1)},${(h - 3 - (v / max) * (h - 6)).toFixed(1)}`);
    const letzter = pts[pts.length - 1].split(',');
    return svg(w, h, `<polyline points="${pts.join(' ')}" fill="none" stroke="var(--muted)" stroke-width="1.5" stroke-linejoin="round" stroke-linecap="round"/><circle cx="${letzter[0]}" cy="${letzter[1]}" r="3" fill="var(--primary)"/>`);
  }

  // ------------------------------------------------ Donut (Geschlecht, Konfession)
  function donut(ctx, items, { groesse, ring, zentrum, unter }) {
    const farben = D.merkmal[ctx.modus];
    const summe = items.reduce((a, x) => a + x.wert, 0) || 1;
    const c = groesse / 2;
    const ra = c - 1;
    const ri = ra - ring;
    let winkel = -Math.PI / 2;
    let inhalt = '';
    const labels = [];
    items.forEach((it, i) => {
      if (!it.wert) return;
      const anteil = it.wert / summe;
      const w = anteil * Math.PI * 2;
      const a0 = winkel;
      const a1 = winkel + w;
      const gross = w > Math.PI ? 1 : 0;
      const p = (r, a) => `${(c + r * Math.cos(a)).toFixed(2)},${(c + r * Math.sin(a)).toFixed(2)}`;
      const d = anteil >= 0.999
        ? `M${p(ra, 0)} A${ra},${ra} 0 1 1 ${p(ra, Math.PI)} A${ra},${ra} 0 1 1 ${p(ra, 0)} M${p(ri, 0)} A${ri},${ri} 0 1 0 ${p(ri, Math.PI)} A${ri},${ri} 0 1 0 ${p(ri, 0)} Z`
        : `M${p(ra, a0)} A${ra},${ra} 0 ${gross} 1 ${p(ra, a1)} L${p(ri, a1)} A${ri},${ri} 0 ${gross} 0 ${p(ri, a0)} Z`;
      const fill = it.farbe || farben[i];
      inhalt += `<path d="${d}" fill="${fill}" stroke="var(--surface)" stroke-width="2" stroke-linejoin="round">${titel(`${it.label}: ${it.wert} (${zahl(anteil * 100)} %)`)}</path>`;
      if (unter === 'inlay' && anteil >= 0.12) {
        const am = a0 + w / 2;
        const rm = (ra + ri) / 2;
        const tinte = tinteAuf(it.hex || fill);
        const zweite = it.inlay !== undefined ? it.inlay : `${zahl(anteil * 100)} %`;
        const dy = zweite === '' ? 0 : -1;
        labels.push(`<text x="${(c + rm * Math.cos(am)).toFixed(1)}" y="${(c + rm * Math.sin(am) + dy).toFixed(1)}"${zweite === '' ? ' dominant-baseline="central"' : ''} text-anchor="middle" class="${zweite === '' ? 't-in1' : 't-in'}" fill="${tinte}">${esc(it.kurz)}</text><text x="${(c + rm * Math.cos(am)).toFixed(1)}" y="${(c + rm * Math.sin(am) + 9).toFixed(1)}" text-anchor="middle" class="t-in2" fill="${tinte}">${zweite}</text>`);
      }
      winkel = a1;
    });
    inhalt += labels.join('');
    if (zentrum && zentrum[1] === '') {
      // Nur die Zahl: exakt mittig, auch bei größerer Schrift.
      inhalt += `<text x="${c}" y="${c}" dominant-baseline="central" text-anchor="middle" class="t-center">${zentrum[0]}</text>`;
    } else if (zentrum) {
      inhalt += `<text x="${c}" y="${c + 3}" text-anchor="middle" class="t-center">${zentrum[0]}</text><text x="${c}" y="${c + 16}" text-anchor="middle" class="t-center2">${esc(zentrum[1])}</text>`;
    }
    return svg(groesse, groesse, inhalt);
  }

  function merkmalKarte(ctx, items, groesse, einheit) {
    const farben = D.merkmal[ctx.modus];
    const summe = items.reduce((a, x) => a + x.wert, 0) || 1;
    if (groesse === '1x1') {
      const klein = items.filter((x) => x.wert && x.wert / summe < 0.12);
      return `<div class="donut-1x1">${donut(ctx, items, { groesse: 132, ring: 30, zentrum: [summe, einheit], unter: 'inlay' })}</div>` +
        (klein.length ? `<div class="donut-rest">${klein.map((x) => `${esc(x.kurz)} ${zahl((x.wert / summe) * 100)} %`).join(' · ')}</div>` : '<div class="donut-rest">&nbsp;</div>');
    }
    const legende = items
      .map((x, i) => `<div class="leg-row"><i class="sw" style="background:${farben[i]}"></i><span>${esc(x.label)}</span><b>${x.wert}</b><small>${zahl((x.wert / summe) * 100)} %</small></div>`)
      .join('');
    return `<div class="donut-2x1">${donut(ctx, items, { groesse: 116, ring: 22, zentrum: [summe, einheit] })}<div class="leg">${legende}</div></div>`;
  }

  const geschlecht = (ctx, groesse) => merkmalKarte(ctx, ctx.k.geschlecht, groesse, 'Kinder');
  const konfession = (ctx, groesse) => merkmalKarte(ctx, ctx.k.konfession, groesse, 'Kinder');

  // --------------------------------------------------------------- Standorte
  function karte(ctx, w, h, seed) {
    let a = seed;
    const r = () => ((a = (a * 16807) % 2147483647) / 2147483647);
    const cx = w * 0.52;
    const cy = h * 0.5;
    let inhalt = `<rect width="${w}" height="${h}" rx="10" fill="var(--map-bg)"/>`;
    inhalt += `<path d="M-10,${h * 0.72} C${w * 0.3},${h * 0.6} ${w * 0.55},${h * 0.95} ${w + 10},${h * 0.78}" stroke="var(--map-water)" stroke-width="7" fill="none"/>`;
    inhalt += `<path d="M${w * 0.15},-5 L${w * 0.38},${h + 5} M-5,${h * 0.3} L${w + 5},${h * 0.22} M${w * 0.7},-5 C${w * 0.62},${h * 0.4} ${w * 0.8},${h * 0.7} ${w * 0.74},${h + 5}" stroke="var(--map-road)" stroke-width="3" fill="none"/>`;
    const n = ctx.k.kinder.length + ctx.k.leitende.length;
    for (let i = 0; i < n; i++) {
      const ang = r() * Math.PI * 2;
      const dist = Math.pow(r(), 0.8) * Math.min(w, h) * 0.46;
      const px = cx + Math.cos(ang) * dist * (w / h > 1.4 ? 1.5 : 1);
      const py = cy + Math.sin(ang) * dist;
      if (px < 6 || px > w - 6 || py < 6 || py > h - 6) continue;
      inhalt += `<circle cx="${px.toFixed(1)}" cy="${py.toFixed(1)}" r="3.5" fill="var(--primary)" stroke="var(--map-bg)" stroke-width="1.5"/>`;
    }
    inhalt += `<g transform="translate(${cx - 8},${cy - 9})"><path d="M8,0 L16,7 V17 H0 V7 Z" fill="var(--fg)" stroke="var(--map-bg)" stroke-width="2"/></g>`;
    // Straßen und Fluss laufen über den Rand hinaus: die Karte schneidet selbst ab.
    return svg(w, h, inhalt).replace('<svg class="viz"', '<svg class="viz karte" style="overflow:hidden;border-radius:10px"');
  }

  function standorte(ctx, groesse, breite) {
    const n = ctx.k.kinder.length + ctx.k.leitende.length;
    if (groesse === '1x1') {
      return `<div class="map-wrap">${karte(ctx, breite, breite, 7)}<span class="map-chip">${n} Adressen</span></div>`;
    }
    return `<div class="map-2x1">${karte(ctx, 196, 150, 7)}<div class="leg">
      <div class="leg-row"><i class="sw round" style="background:var(--primary)"></i><span>Wohnorte</span><b>${n}</b></div>
      <div class="leg-row"><i class="sw house"></i><span>Stammesheim</span></div>
      <div class="leg-note">Median 2,1 km zum Heim</div></div></div>`;
  }

  // ----------------------------------------------------------- Zählkachel
  function zaehlkachel(ctx, kachel, groesse) {
    const meter = kachel.ziel
      ? `<div class="meter"><i style="width:${Math.min(100, (kachel.wert / kachel.ziel) * 100)}%"></i></div><div class="stat-sub">${kachel.wert} von ${kachel.ziel} ${esc(kachel.zielText || '')}</div>`
      : '';
    if (groesse === '1x1') {
      return `<div class="zk"><div class="zk-val">${kachel.wert}</div>${meter}<div class="zk-filter"><span class="zk-own">Eigene Kachel</span> ${esc(kachel.filter)}</div></div>`;
    }
    let rechts = meter;
    if (kachel.aufteilung) {
      const teile = Object.entries(kachel.aufteilung);
      const summe = teile.reduce((a, [, v]) => a + v, 0);
      const bw = 170;
      let x = 0;
      let inhalt = '';
      const nutz = bw - 2 * (teile.length - 1);
      teile.forEach(([id, v]) => {
        const w = (nutz * v) / summe;
        inhalt += `<rect x="${x.toFixed(1)}" y="0" width="${w.toFixed(1)}" height="10" rx="3" fill="${farbe(id)}"${kontur(id)}/>`;
        x += w + 2;
      });
      rechts = `${svg(bw, 10, inhalt)}<div class="keys">${teile.map(([id, v]) => schluessel(id, stufeById[id].kurz, v)).join('')}</div>`;
    }
    return `<div class="zk-2x1"><div><div class="zk-val">${kachel.wert}</div><div class="zk-filter"><span class="zk-own">Eigene Kachel</span> ${esc(kachel.filter)}</div></div><div class="zk-right">${rechts}</div></div>`;
  }

  // ------------------------------------------------------------ Hüllen
  const abschnitt = (titelText, inhalt, extra = '') =>
    `<section class="blk"><h4 class="sec">${esc(titelText)}</h4><div class="card ${extra}">${inhalt}</div></section>`;
  const kachel = (groesse, titelText, inhalt, extra = '') =>
    `<div class="tile t${groesse} ${extra}"><div class="tile-head">${esc(titelText)}<span class="tile-more">›</span></div>${inhalt}</div>`;

  window.BAUSTEINE = {
    kennzahlen, stufenband, stufenZeilen, altersstruktur, prognose, bindung, bindungKacheln,
    eintrittsjahre, geschlecht, konfession, standorte, zaehlkachel, statKachel, sparkline,
    donut, karte, luminanz, tinteAuf, median, balkenH, saeule,
    abschnitt, kachel, schluessel, punkt, svg, zahl, datum, datumKurz, esc, alter, farbe, kontur, stufeById,
  };
})();

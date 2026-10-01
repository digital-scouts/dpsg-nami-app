// Runde 2: Was hinter den Kacheln liegt – Detailseiten beim Antippen.
(function () {
  const D = window.STATISTIK;
  const B = window.BAUSTEINE;
  const K = window.KACHELN;
  const { esc, zahl, datum, farbe, svg, schluessel } = B;
  const MS_JAHR = 365.25 * 24 * 3600 * 1000;

  const name = (p) => `${p.vorname || 'Mitglied'}${p.nachname ? ` ${p.nachname}` : ''}`;
  const appBar = (titel, zurueck = 'Statistik') =>
    `<header class="hdr sheet-hdr"><span class="lnk">‹ ${esc(zurueck)}</span><b>${esc(titel)}</b><span class="lnk"></span></header>`;
  const liste = (zeilen) => `<div class="card nopad">${zeilen.join('')}</div>`;
  const zeile = (links, rechts = '', sub = '', chev = true) =>
    `<div class="li"><div><div class="li-t">${links}</div>${sub ? `<div class="li-s">${sub}</div>` : ''}</div><div class="li-r">${rechts}</div>${chev ? '<span class="chev">›</span>' : ''}</div>`;
  const link = (text) => `<div class="li link">${esc(text)}<span class="chev">›</span></div>`;

  // Kennzahlen für eine einzelne Gruppe (für die Diagramm-Bausteine).
  function gruppenCtx(ctx, gr, stufeId) {
    const k = ctx.k;
    return { ...ctx, stil: 'balken', k: { ...k, proStufe: k.proStufe.map((ps) => (ps.stufe.id === stufeId ? { ...ps, kinder: gr.kinder } : { ...ps, kinder: [] })) } };
  }

  function geschlechtBalken(ctx, kinder, breite) {
    const farben = D.merkmal[ctx.modus];
    const teile = [
      ['w', kinder.filter((p) => p.gender === 'w').length],
      ['m', kinder.filter((p) => p.gender === 'm').length],
      ['d', kinder.filter((p) => p.gender === 'd').length],
      ['k. A.', kinder.filter((p) => !p.gender).length],
    ];
    const summe = kinder.length || 1;
    const sichtbar = teile.filter(([, v]) => v);
    const nutz = breite - 2 * (sichtbar.length - 1);
    let x = 0;
    let inhalt = '';
    teile.forEach(([kurz, v], i) => {
      if (!v) return;
      const w = (nutz * v) / summe;
      inhalt += `<rect x="${x.toFixed(1)}" y="0" width="${w.toFixed(1)}" height="14" rx="3" fill="${farben[i]}"><title>${kurz}: ${v}</title></rect>`;
      if (w > 26) inhalt += `<text x="${(x + w / 2).toFixed(1)}" y="10.5" text-anchor="middle" class="t-in2" fill="${B.tinteAuf(farben[i])}">${v}</text>`;
      x += w + 2;
    });
    return svg(breite, 14, inhalt);
  }

  // ---------------------------------------------------------- Gruppe
  function gruppe(ctx, gruppenId = 'w1') {
    const { k } = ctx;
    const ps = k.proStufe.find((s) => s.gruppen.some((g) => g.id === gruppenId)) || k.proStufe[1];
    const gr = ps.gruppen.find((g) => g.id === gruppenId) || ps.gruppen[0];
    const s = ps.stufe;
    const ziel = k.ziele.gruppeMax[s.id];
    const vor12 = new Date(D.heute);
    vor12.setFullYear(vor12.getFullYear() - 1);
    const neu = gr.kinder.filter((p) => p.eintritt >= vor12).length;
    const gehen = k.wechsel.filter((w) => w.p.gruppe === gr.id && w.nach);
    const ueber = gehen.filter((w) => w.ueberfaellig).length;
    const ziel2 = D.stufen[D.stufen.findIndex((x) => x.id === s.id) + 1];
    const karte = `<div class="station-card">
      <div class="st-head"><div><div class="st-name">${esc(s.name)}</div><div class="st-groups">${gr.kinder.length} Kinder & Jugendliche · ${gr.leitende.length} Leitende</div></div>
        <div class="st-count">${gr.kinder.length}<small>/${ziel}</small></div></div>
      <div class="st-viz">${B.altersstruktur(gruppenCtx(ctx, gr, s.id), { breite: 326, nurStufe: s.id })}</div>
      <div class="st-meta"><span class="gm">${geschlechtBalken(ctx, gr.kinder, 150)}</span><span>${neu ? `${neu} neu in 12 Monaten` : ''}</span></div>
    </div>`;
    const wechselChip = gehen.length && ziel2
      ? `<div class="uebergang wide"><span>↓ <b>${gehen.length}</b> ${gehen.length === 1 ? 'wechselt' : 'wechseln'} zum ${B.datumKurz(D.stichtag)} zu ${esc(ziel2.name)}${ueber ? ` · ${ueber} überfällig` : ''}</span><span class="chev">›</span></div>`
      : '';
    const leitung = gr.leitende.map((p) => zeile(esc(name(p)), '', `seit ${Math.floor((D.heute - p.eintritt) / MS_JAHR)} Jahren im Stamm`));
    const kinder = [...gr.kinder].sort((a, b) => B.alter(b) - B.alter(a)).slice(0, 4)
      .map((p) => zeile(esc(name(p)), `${Math.floor(B.alter(p))} J.`, '', true));
    const inhalt = `${karte}${wechselChip}
      <h4 class="sec">Leitung</h4>${liste(leitung)}
      <h4 class="sec">Kinder & Jugendliche</h4>${liste([...kinder, link(`Alle ${gr.kinder.length} in der Mitgliederliste`)])}`;
    return { kopfHtml: appBar(gr.name), inhalt };
  }

  // -------------------------------------------------------- Personen
  function personen(ctx) {
    const { k } = ctx;
    const proStufe = (feld) => k.proStufe.filter((ps) => ps[feld].length)
      .map((ps) => zeile(schluessel(ps.stufe.id, ps.stufe.name), `<b>${ps[feld].length}</b>`, '', false));
    const sonst = k.stamm.sonstigeRollen.map((r) => zeile(esc(r.rolle), `<b>${r.anzahl}</b>`, '', true));
    const inhalt = `<div class="big-kpi"><b>${k.personen}</b><span>Personen im ${esc(k.stamm.name)}</span></div>
      <h4 class="sec">Kinder & Jugendliche · ${k.kinder.length}</h4>${liste(proStufe('kinder'))}
      <h4 class="sec">Leitende · ${k.leitende.length}</h4>${liste(proStufe('leitende'))}
      ${k.sonstige ? `<h4 class="sec">Sonstige · ${k.sonstige}</h4>${liste(sonst)}<div class="foot muted">Personen mit Rolle im Stamm, aber ohne Rolle in einer Stufengruppe.</div>` : ''}`;
    return { kopfHtml: appBar('Personen'), inhalt };
  }

  // ---------------------------------------------------- Altersstruktur
  function alter(ctx) {
    const { k } = ctx;
    const ueber = k.kinder.filter((p) => B.alter(p) >= B.stufeById[p.stufe].max + 1)
      .map((p) => zeile(esc(name(p)), `${Math.floor(B.alter(p))} J.`, `${esc(B.stufeById[p.stufe].name)} · Grenze ${B.stufeById[p.stufe].max} J.`));
    const inhalt = `<div class="seg wide top"><i class="on">Kinder & Jugendliche</i><i>Leitende</i></div>
      <div class="card">${B.altersstruktur({ ...ctx, stil: 'balken' }, { breite: 326 })}</div>
      <h4 class="sec">Über der Altersgrenze · ${ueber.length}</h4>${liste([...ueber, link('Zum Stufenwechsel')])}
      ${k.stamm.ohneGeburtsdatum ? `<h4 class="sec">Datenpflege</h4>${liste([zeile(`${k.stamm.ohneGeburtsdatum} Personen ohne Geburtsdatum`, '', 'fehlen in dieser Auswertung', true)])}` : ''}
      <div class="card nopad top12">${link('Altersgrenzen anpassen')}</div>`;
    return { kopfHtml: appBar('Altersstruktur'), inhalt };
  }

  // ---------------------------------------------------------- Bindung
  function bindung(ctx) {
    const { k } = ctx;
    const vor12 = new Date(D.heute);
    vor12.setFullYear(vor12.getFullYear() - 1);
    const dauer = (p) => (D.heute - p.eintritt) / MS_JAHR;
    const tabelle = `<table class="tbl"><thead><tr><th></th><th>Kinder</th><th>neu</th><th>dabei (Median)</th></tr></thead><tbody>${k.proStufe.filter((ps) => ps.kinder.length).map((ps) =>
      `<tr><td>${schluessel(ps.stufe.id, ps.stufe.kurz)}</td><td>${ps.kinder.length}</td><td>${ps.kinder.filter((p) => p.eintritt >= vor12).length || '–'}</td><td>${zahl(B.median(ps.kinder.map(dauer)), 1)} J.</td></tr>`).join('')}</tbody></table>`;
    const neu = [...k.neu].sort((a, b) => b.eintritt - a.eintritt).slice(0, 5)
      .map((p) => zeile(esc(name(p)), datum(p.eintritt), esc(k.stamm.gruppen.find((g) => g.id === p.gruppe)?.name || '')));
    const jahr = D.heute.getFullYear();
    const jubi = k.stamm.personen.filter((p) => [5, 10, 15, 20, 25].includes(jahr - p.eintritt.getFullYear()))
      .sort((a, b) => a.eintritt - b.eintritt)
      .map((p) => zeile(esc(name(p)), `<b>${jahr - p.eintritt.getFullYear()} J.</b>`, `${p.leitung ? 'Leitung · ' : ''}${esc(k.stamm.gruppen.find((g) => g.id === p.gruppe)?.name || '')}`));
    const inhalt = `<div class="card">${tabelle}</div>
      <h4 class="sec">Neu in 12 Monaten · ${k.neu.length}</h4>${liste([...neu, ...(k.neu.length > 5 ? [link(`Alle ${k.neu.length} anzeigen`)] : [])])}
      <h4 class="sec">Jubiläen ${jahr} · ${jubi.length}</h4>${liste(jubi.slice(0, 5))}
      <div class="foot muted">Nur heutige Mitglieder – wer ausgetreten ist, fehlt in den Daten.</div>`;
    return { kopfHtml: appBar('Bindung'), inhalt };
  }

  // -------------------------------------------------------- Geschlecht
  function merkmal(ctx) {
    const { k } = ctx;
    const farben = D.merkmal[ctx.modus];
    const zeilen = k.proStufe.filter((ps) => ps.kinder.length).map((ps) =>
      `<div class="gb-row"><span class="gb-lab">${esc(ps.stufe.kurz)}</span>${geschlechtBalken(ctx, ps.kinder, 230)}<span class="gb-n">${ps.kinder.length}</span></div>`);
    const leg = k.geschlecht.filter((x) => x.wert).map((x) => `<span class="key"><i class="sw" style="background:${farben[k.geschlecht.indexOf(x)]}"></i>${esc(x.label)} <b>${x.wert}</b></span>`).join('');
    const inhalt = `<div class="seg wide top"><i class="on">Geschlecht</i><i>Konfession</i></div>
      <div class="card"><div class="sub-head first">Je Stufe</div>${zeilen.join('')}<div class="keys">${leg}</div></div>
      <div class="card nopad top12">${link('Mit dem Bund vergleichen')}</div>`;
    return { kopfHtml: appBar('Zusammensetzung'), inhalt };
  }

  // ---------------------------------------------------------- Standorte
  function standorte(ctx) {
    const { k } = ctx;
    const n = k.kinder.length + k.leitende.length;
    const chips = ['Alle', ...k.proStufe.filter((ps) => ps.kinder.length).map((ps) => ps.stufe.kurz), 'Leitende'];
    const nah = Math.round(n * 0.44);
    const mittel = Math.round(n * 0.4);
    const inhalt = `<div class="chips">${chips.map((c, i) => `<span class="${i === 0 ? 'on' : ''}">${esc(c)}</span>`).join('')}</div>
      <div class="map-full">${B.karte(ctx, 358, 400, 11)}</div>
      <div class="card top12"><div class="sub-head first">Einzugsgebiet <span class="idee">Idee</span></div>
        <div class="trio"><div><div class="stat-val">${nah}</div><div class="stat-sub">bis 2 km</div></div><div><div class="stat-val">${mittel}</div><div class="stat-sub">2–5 km</div></div><div><div class="stat-val">${n - nah - mittel}</div><div class="stat-sub">über 5 km</div></div></div>
        <div class="foot muted">Luftlinie zum Stammesheim, aus den bereits geocodierten Adressen.</div></div>`;
    return { kopfHtml: appBar('Standorte'), inhalt };
  }

  // ----------------------------------------------- Eigene Kachel → Liste
  function eigeneListe(ctx) {
    const { k } = ctx;
    const kachel = k.eigeneKacheln[0];
    const leute = k.leitende.slice(0, kachel.wert);
    const inhalt = `<div class="search">Suchen</div>
      <div class="chips"><span class="on">${esc(kachel.titel)} ×</span><span>Stufe</span><span>Rolle</span></div>
      ${liste(leute.map((p) => zeile(esc(name(p)), '', 'Stammesvorstand')))}
      <div class="foot muted">Gleicher Filter wie in der Kachel – die Kachel zählt, die Liste zeigt.</div>`;
    return { kopfHtml: '<header class="hdr sheet-hdr"><span class="lnk">‹ Statistik</span><b>Mitglieder</b><span class="lnk"></span></header>', inhalt };
  }

  window.DETAILS = { gruppe, personen, alter, bindung, merkmal, standorte, eigeneListe };
})();

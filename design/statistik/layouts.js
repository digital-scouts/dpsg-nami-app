// Layout-Varianten A–D und die Anpassen-Ansichten als Handy-Seiten.
// Jede Funktion bekommt ctx = { k, stil, modus } und liefert den Seiteninhalt.
(function () {
  const D = window.STATISTIK;
  const B = window.BAUSTEINE;
  const { esc, zahl, datum } = B;

  const BREITE = 358; // 390 pt minus 2 × 16 Seitenrand
  const KARTE = BREITE - 32;
  const HALB = (BREITE - 12) / 2 - 24; // Innenbreite 1×1-Kachel
  const KACHEL = BREITE - 24; // Innenbreite 2×1-Kachel

  // ------------------------------------------------------------- Rahmen
  function tabs(eintraege, aktiv) {
    return `<div class="pill">${eintraege.map((t, i) => `<span class="${i === aktiv ? 'on' : ''}">${esc(t)}</span>`).join('')}</div>`;
  }
  function kopf(ctx, variante, { tabEintraege = ['Stamm', 'Bundesweit'], aktiv = 0 } = {}) {
    const { k } = ctx;
    const titel = `<div class="hdr-title">${esc(k.stamm.name)}</div>`;
    const rest = [
      `${k.kinder.length} Kinder & Jugendliche`,
      `${k.leitende.length} Leitende`,
      k.sonstige ? `${k.sonstige} Sonstige` : '',
    ].filter(Boolean).join(' · ');
    let mitte = '';
    if (variante === 'hero') {
      mitte = `<div class="hero">${k.personen}<span> Personen</span></div><div class="hero-sub">${rest}</div><div class="hdr-band">${B.stufenband(ctx, { breite: BREITE - 0, hoehe: 10 })}</div>`;
    } else if (variante === 'zeile') {
      mitte = `<div class="hdr-line"><b>${k.personen} Personen</b><br>${rest}</div>`;
    }
    return `<header class="hdr">${titel}${mitte}${tabs(tabEintraege, aktiv)}</header>`;
  }
  function telefon(ctx, inhalt, { shot, beschriftung = '', kopfHtml = '', tabbar = true, fest = false } = {}) {
    return `<figure class="phone ${ctx.modus}" data-shot="${esc(shot)}">
      <div class="screen${fest ? ' fest' : ''}">
        <div class="status"><span>9:41</span><i class="island"></i><span class="sys"></span></div>
        ${kopfHtml}
        <div class="body">${inhalt}</div>
        ${tabbar ? '<nav class="tabbar"><span>Mitglieder</span><span class="on">Statistik</span><span>Stufenwechsel</span><span>Einstellungen</span></nav>' : ''}
      </div>
      ${beschriftung ? `<figcaption>${beschriftung}</figcaption>` : ''}
    </figure>`;
  }
  const anpassen = '<div class="adjust"><span>✎ Seite anpassen</span><span>＋ Eigene Kachel</span></div>';

  function merkmalRaster(ctx) {
    const [vorstand, foerder] = ctx.k.eigeneKacheln;
    return `<div class="grid">
      ${B.kachel('1x1', 'Geschlecht', B.geschlecht(ctx, '1x1'))}
      ${B.kachel('1x1', 'Konfession', B.konfession(ctx, '1x1'))}
      ${B.kachel('2x1', 'Standorte', B.standorte(ctx, '2x1', KACHEL))}
      ${B.kachel('1x1', vorstand.titel, B.zaehlkachel(ctx, vorstand, '1x1'), 'eigen')}
      ${B.kachel('1x1', foerder.titel, B.zaehlkachel(ctx, foerder, '1x1'), 'eigen')}
    </div>`;
  }

  // ------------------------------------------------------ A Lagebericht
  function layoutA(ctx) {
    const inhalt = [
      B.abschnitt('Stufen & Gruppen', B.stufenZeilen(ctx, { breite: KARTE })),
      B.abschnitt(`Nächster Stufenwechsel`, B.prognose(ctx, { breite: KARTE })),
      B.abschnitt('Altersstruktur', B.altersstruktur(ctx, { breite: KARTE })),
      B.abschnitt('Bindung', B.bindung(ctx, { breite: KARTE })),
      `<section class="blk"><h4 class="sec">Zusammensetzung</h4>${merkmalRaster(ctx)}</section>`,
      anpassen,
    ].join('');
    return { kopfHtml: kopf(ctx, 'hero'), inhalt };
  }

  // ----------------------------------------------------------- B Pfad
  function geschlechtMini(ctx, liste) {
    const farben = D.merkmal[ctx.modus];
    const teile = [
      ['w', liste.filter((p) => p.gender === 'w').length],
      ['m', liste.filter((p) => p.gender === 'm').length],
      ['d', liste.filter((p) => p.gender === 'd').length],
      ['k. A.', liste.filter((p) => !p.gender).length],
    ];
    const summe = liste.length || 1;
    const bw = 120;
    let x = 0;
    let inhalt = '';
    const sichtbar = teile.filter(([, v]) => v);
    const nutz = bw - 2 * (sichtbar.length - 1);
    teile.forEach(([, v], i) => {
      if (!v) return;
      const w = (nutz * v) / summe;
      inhalt += `<rect x="${x.toFixed(1)}" y="0" width="${w.toFixed(1)}" height="6" rx="3" fill="${farben[i]}"/>`;
      x += w + 2;
    });
    return `<span class="gmini">${B.svg(bw, 6, inhalt)}<small>${sichtbar.map(([kurz, v]) => `${kurz} ${v}`).join(' · ')}</small></span>`;
  }

  function layoutB(ctx) {
    const { k } = ctx;
    const vor12 = new Date(D.heute);
    vor12.setFullYear(vor12.getFullYear() - 1);
    const stationen = k.proStufe.filter((ps) => ps.kinder.length || ps.leitende.length);
    const html = stationen.map((ps, i) => {
      const s = ps.stufe;
      const prog = k.prognose.find((r) => r.stufe.id === s.id);
      const neu = ps.kinder.filter((p) => p.eintritt >= vor12).length;
      const ueber = ps.kinder.filter((p) => B.alter(p) >= s.max + 1).length;
      const karte = `<div class="station-card">
        <div class="st-head"><div><div class="st-name">${esc(s.name)}</div><div class="st-groups">${ps.gruppen.map((g) => esc(g.name)).join(' · ')}</div></div>
          <div class="st-count">${ps.kinder.length}<small>+${ps.leitende.length}</small></div></div>
        <div class="st-viz">${B.altersstruktur(ctx, { breite: BREITE - 60, nurStufe: s.id })}</div>
        <div class="st-meta">${geschlechtMini(ctx, ps.kinder)}<span>${[neu ? `${neu} neu` : '', ueber ? `↑${ueber} über Grenze` : ''].filter(Boolean).join(' · ')}</span></div>
      </div>`;
      let uebergang = '';
      const naechste = stationen[i + 1];
      if (naechste && prog.ab) {
        uebergang = `<div class="uebergang">↓ <b>${prog.ab}</b> ${prog.ab === 1 ? 'wechselt' : 'wechseln'} zum ${B.datumKurz(D.stichtag)}${prog.ueberfaellig ? ` · ${prog.ueberfaellig} überfällig` : ''}</div>`;
      } else if (!naechste && k.roverRaus) {
        uebergang = `<div class="uebergang">→ <b>${k.roverRaus}</b> ${k.roverRaus === 1 ? 'wird' : 'werden'} 21 · Leitung oder Abschied</div>`;
      }
      return `<div class="station"><i class="node${s.id === 'biber' ? ' biber' : ''}" style="background:${B.farbe(s.id)}"></i>${karte}</div>${uebergang}`;
    }).join('');
    const legende = ctx.stil === 'punkte'
      ? `<div class="foot pfad-foot">Zahl = Kinder +Leitende · Punkte nach Alter, Fläche = Altersgrenze</div>`
      : `<div class="foot pfad-foot">Zahl = Kinder +Leitende · Fläche = Altersgrenze der Stufe</div>`;
    const inhalt = [
      `<div class="pfad">${html}</div>${legende}`,
      B.abschnitt('Bindung', B.bindung(ctx, { breite: KARTE })),
      `<section class="blk"><h4 class="sec">Zusammensetzung</h4>${merkmalRaster(ctx)}</section>`,
      anpassen,
    ].join('');
    return { kopfHtml: kopf(ctx, 'zeile'), inhalt };
  }

  // -------------------------------------------------------- C Kacheln
  function layoutC(ctx) {
    const { k } = ctx;
    const [vorstand, foerder] = k.eigeneKacheln;
    const inhalt = `<div class="grid">
      ${B.kachel('1x1', 'Personen', `<div class="zk-val">${k.personen}</div><div class="stat-sub">${k.kinder.length} Kinder & Jugendl.<br>${k.leitende.length} Leitende${k.sonstige ? ` · ${k.sonstige} Sonstige` : ''}</div>`)}
      ${B.kachel('1x1', 'Neu in 12 Monaten', `<div class="zk-val">${k.neu.length}</div><div class="meter"><i style="width:${Math.min(100, (k.neu.length / k.ziele.neuProJahr) * 100)}%"></i></div><div class="stat-sub">Ziel ${k.ziele.neuProJahr} pro Jahr</div>`)}
      ${B.kachel('2x1', 'Stufen', B.stufenband(ctx, { breite: KACHEL, hoehe: 12 }))}
      ${B.kachel('1x1', 'Stufenwechsel', `<div class="zk-val">${k.wechselAnzahl}</div><div class="stat-sub">zum ${datum(D.stichtag)}</div>${k.ueberfaellig ? `<div class="flag">↑ ${k.ueberfaellig} überfällig</div>` : ''}`)}
      ${B.kachel('1x1', 'Dabei (Median)', `<div class="zk-val">${zahl(k.dauerKinder, 1)}<small> J.</small></div><div class="stat-sub">Kinder & Jugendliche<br>Leitende ${zahl(k.dauerLeitende, 1)} J.</div>`)}
      ${B.kachel('2x1', 'Altersstruktur', B.altersstruktur(ctx, { breite: KACHEL }))}
      ${B.kachel('2x1', `Nach dem Stufenwechsel`, B.prognose(ctx, { breite: KACHEL }))}
      ${B.kachel('2x1', 'Gruppen', B.stufenZeilen(ctx, { breite: KACHEL, kompakt: true }))}
      ${B.kachel('1x1', 'Geschlecht', B.geschlecht(ctx, '1x1'))}
      ${B.kachel('1x1', 'Konfession', B.konfession(ctx, '1x1'))}
      ${B.kachel('2x1', 'Standorte', B.standorte(ctx, '2x1', KACHEL))}
      ${B.kachel('1x1', vorstand.titel, B.zaehlkachel(ctx, vorstand, '1x1'), 'eigen')}
      ${B.kachel('1x1', foerder.titel, B.zaehlkachel(ctx, foerder, '1x1'), 'eigen')}
      <div class="tile t1x1 add"><span>＋</span>Kachel hinzufügen</div>
      <div class="tile t1x1 add"><span>✎</span>Anordnen</div>
    </div>`;
    return { kopfHtml: kopf(ctx, 'ohne'), inhalt };
  }

  // --------------------------------------------------------- D Themen
  const D_TABS = ['Überblick', 'Stufen', 'Entwicklung', 'Bundesweit'];
  function layoutD(ctx, tab = 0) {
    const { k } = ctx;
    let inhalt;
    if (tab === 0) {
      inhalt = [
        `<div class="card">${B.stufenband(ctx, { breite: KARTE, hoehe: 12 })}</div>`,
        `<div class="grid top12">
          ${B.kachel('1x1', 'Neu in 12 Monaten', `<div class="zk-val">${k.neu.length}</div><div class="meter"><i style="width:${Math.min(100, (k.neu.length / k.ziele.neuProJahr) * 100)}%"></i></div><div class="stat-sub">Ziel ${k.ziele.neuProJahr} pro Jahr</div>`)}
          ${B.kachel('1x1', 'Stufenwechsel', `<div class="zk-val">${k.wechselAnzahl}</div><div class="stat-sub">zum ${datum(D.stichtag)}</div>${k.ueberfaellig ? `<div class="flag">↑ ${k.ueberfaellig} überfällig</div>` : ''}`)}
        </div>`,
        `<section class="blk"><h4 class="sec">Zusammensetzung</h4>${merkmalRaster(ctx)}</section>`,
        anpassen,
      ].join('');
    } else if (tab === 1) {
      inhalt = [
        B.abschnitt('Gruppen', B.stufenZeilen(ctx, { breite: KARTE })),
        B.abschnitt('Altersstruktur', B.altersstruktur(ctx, { breite: KARTE })),
      ].join('');
    } else {
      inhalt = [
        B.abschnitt('Nächster Stufenwechsel', B.prognose(ctx, { breite: KARTE })),
        B.abschnitt('Bindung', B.bindung(ctx, { breite: KARTE })),
      ].join('');
    }
    return { kopfHtml: kopf(ctx, 'zeile', { tabEintraege: D_TABS, aktiv: tab }), inhalt };
  }

  // ------------------------------------------------ Anpassen-Ansichten
  function bearbeiten(ctx) {
    const eintrag = (titel, breite, sichtbar = true, eigen = false) =>
      `<div class="edit-row${sichtbar ? '' : ' aus'}"><span class="handle">⠿</span><span class="edit-title">${esc(titel)}${eigen ? ' <em>eigene</em>' : ''}</span>
        <span class="seg"><i class="${breite === '1x1' ? 'on' : ''}">1×1</i><i class="${breite === '2x1' ? 'on' : ''}">2×1</i></span>
        <span class="eye">${sichtbar ? '👁' : '⊘'}</span></div>`;
    const inhalt = `<div class="edit-hint">Ziehen zum Sortieren · Breite je Karte · Auge blendet aus</div>
      <div class="card nopad">
        ${eintrag('Stufen & Gruppen', '2x1')}
        ${eintrag('Nächster Stufenwechsel', '2x1')}
        ${eintrag('Altersstruktur', '2x1')}
        ${eintrag('Bindung', '2x1')}
        ${eintrag('Geschlecht', '1x1')}
        ${eintrag('Konfession', '1x1', false)}
        ${eintrag('Standorte', '2x1')}
        ${eintrag('Stammesvorstand', '1x1', true, true)}
        ${eintrag('Fördermitglieder', '1x1', true, true)}
      </div>
      <div class="edit-add">＋ Eigene Kachel</div>
      <div class="edit-add ghost">◎ Zielwerte festlegen</div>
      <div class="foot muted center">Einstellungen gelten für diesen Stamm und bleiben auf dem Gerät.</div>`;
    const kopfHtml = `<header class="hdr sheet-hdr"><span class="lnk">Abbrechen</span><b>Seite anpassen</b><span class="lnk strong">Fertig</span></header>`;
    return { kopfHtml, inhalt };
  }

  function kachelAnlegen(ctx) {
    const kachel = ctx.k.eigeneKacheln[0];
    const inhalt = `<div class="sheet">
      <div class="grabber"></div>
      <div class="sheet-title">Eigene Kachel</div>
      <label class="fld"><span>Name</span><div class="input">${esc(kachel.titel)}</div></label>
      <div class="fld"><span>Wer wird gezählt?</span>
        <div class="rule"><span>hat Rolle in Gruppe <b>Stammesvorstand</b> · beliebige Rolle</span><i>×</i></div>
        <div class="rule-add">＋ Bedingung</div>
        <div class="seg wide"><i class="on">alle Bedingungen</i><i>eine reicht</i></div>
      </div>
      <div class="fld"><span>Vorschau</span>
        <div class="preview">${B.kachel('1x1', kachel.titel, B.zaehlkachel(ctx, kachel, '1x1'), 'eigen')}
          <div class="preview-note">Gleiche Filter wie in der Mitgliederliste. Live mit den Daten dieses Stamms.</div></div>
      </div>
      <div class="fld"><span>Darstellung</span>
        <div class="seg wide"><i class="on">Zahl</i><i>nach Stufe</i></div></div>
      <div class="fld row"><span>Zielwert</span><div class="stepper"><i>−</i><b>${kachel.ziel}</b><i>＋</i></div><em class="toggle on"></em></div>
      <div class="fld row"><span>Breite</span><div class="seg"><i class="on">1×1</i><i>2×1</i></div></div>
      <div class="btn">Kachel speichern</div>
    </div>`;
    return { kopfHtml: '<div class="dim"></div>', inhalt };
  }

  function zielwerte(ctx) {
    const z = ctx.k.ziele;
    const zeile = (id, wert) =>
      `<div class="set-row">${B.schluessel(id, B.stufeById[id].name)}<div class="stepper"><i>−</i><b>${wert}</b><i>＋</i></div></div>`;
    const inhalt = `
      <h4 class="sec">Gruppengröße (höchstens)</h4>
      <div class="card nopad">${Object.entries(z.gruppeMax).map(([id, v]) => zeile(id, v)).join('')}</div>
      <div class="foot muted">Erscheint als Marke an den Gruppenbalken und in der Prognose.</div>
      <h4 class="sec">Nachwuchs</h4>
      <div class="card nopad"><div class="set-row"><span>Neue pro Jahr</span><div class="stepper"><i>−</i><b>${z.neuProJahr}</b><i>＋</i></div></div></div>
      <h4 class="sec">Anzeige</h4>
      <div class="card nopad"><div class="set-row"><span>Zielmarken in Diagrammen</span><em class="toggle on"></em></div>
        <div class="set-row"><span>Nur Abweichungen hervorheben</span><em class="toggle"></em></div></div>`;
    const kopfHtml = `<header class="hdr sheet-hdr"><span class="lnk">‹ Zurück</span><b>Zielwerte</b><span class="lnk"></span></header>`;
    return { kopfHtml, inhalt };
  }

  window.LAYOUTS = {
    BREITE, KARTE, HALB, KACHEL, telefon,
    A: layoutA, B: layoutB, C: layoutC, D: layoutD,
    bearbeiten, kachelAnlegen, zielwerte,
  };
})();

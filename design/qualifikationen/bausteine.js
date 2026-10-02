// Bausteine der Entwürfe zur Qualifikationen-Übersicht.
// ctx = { modus: 'hell'|'dunkel', einstellungen?, angezeigt? }
(function () {
  const Q = window.QDATEN;
  const L = window.LILIE;
  const BILD = '../../assets/images/';

  // Ab Runde 2 gelten die Festlegungen aus Runde 1; die Seite von Runde 1 bleibt unverändert.
  const R2 = (x) => (x?.runde || 1) >= 2;
  const esc = (s) => String(s ?? '').replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));
  const dmy = (s) => { const [y, m, d] = s.split('-'); return `${d}.${m}.${y}`; };
  const PFADE = {
    back: 'M19 12H5M11 6l-6 6 6 6',
    gear: 'M12 9a3 3 0 1 0 0 6 3 3 0 0 0 0-6zM19.4 15a1.7 1.7 0 0 0 .3 1.8l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.7 1.7 0 0 0-1.8-.3 1.7 1.7 0 0 0-1 1.5V21a2 2 0 1 1-4 0v-.1a1.7 1.7 0 0 0-1.1-1.5 1.7 1.7 0 0 0-1.8.3l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1a1.7 1.7 0 0 0 .3-1.8 1.7 1.7 0 0 0-1.5-1H3a2 2 0 1 1 0-4h.1a1.7 1.7 0 0 0 1.5-1.1 1.7 1.7 0 0 0-.3-1.8l-.1-.1a2 2 0 1 1 2.8-2.8l.1.1a1.7 1.7 0 0 0 1.8.3H9a1.7 1.7 0 0 0 1-1.5V3a2 2 0 1 1 4 0v.1a1.7 1.7 0 0 0 1 1.5 1.7 1.7 0 0 0 1.8-.3l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1.7 1.7 0 0 0-.3 1.8V9a1.7 1.7 0 0 0 1.5 1H21a2 2 0 1 1 0 4h-.1a1.7 1.7 0 0 0-1.5 1z',
    plus: 'M12 5v14M5 12h14',
    shield: 'M12 3l8 3v6c0 5-3.5 8-8 9-4.5-1-8-4-8-9V6zM9 12l2 2 4-4',
    hand: 'M8 13V5.5a1.5 1.5 0 0 1 3 0V11M11 10V4.5a1.5 1.5 0 0 1 3 0V11M14 10.5V6a1.5 1.5 0 0 1 3 0v7a7 7 0 0 1-7 7h-.5A6.5 6.5 0 0 1 4 15.2L2.8 12a1.5 1.5 0 0 1 2.7-1.3L8 14',
    cross: 'M9 3h6v6h6v6h-6v6H9v-6H3V9h6z',
    award: 'M12 3a6 6 0 1 0 0 12 6 6 0 0 0 0-12zM8.5 14 7 21l5-3 5 3-1.5-7',
    book: 'M4 5a2 2 0 0 1 2-2h13v16H6a2 2 0 0 0-2 2zM4 21V5M8 7h7',
    id: 'M3 5h18v14H3zM7 15h4M7 11h10',
    right: 'M9 6l6 6-6 6',
    down: 'M6 9l6 6 6-6',
    bell: 'M6 16V11a6 6 0 1 1 12 0v5l2 2H4zM10 20a2 2 0 0 0 4 0',
    lock: 'M6 11h12v9H6zM8.5 11V8a3.5 3.5 0 0 1 7 0v3',
    check: 'M5 12l5 5 9-10',
    grip: 'M9 6h.01M15 6h.01M9 12h.01M15 12h.01M9 18h.01M15 18h.01',
    person: 'M12 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8zM4 21a8 8 0 0 1 16 0',
    group: 'M9 11a3.5 3.5 0 1 0 0-7 3.5 3.5 0 0 0 0 7zM2.5 20a6.5 6.5 0 0 1 13 0M16 4.5a3.5 3.5 0 0 1 0 6.5M18 14a6 6 0 0 1 3.5 6',
    clock: 'M12 3a9 9 0 1 0 0 18 9 9 0 0 0 0-18zM12 7v5l3 2',
    info: 'M12 3a9 9 0 1 0 0 18 9 9 0 0 0 0-18zM12 11v6M12 7.5h.01',
    x: 'M6 6l12 12M18 6 6 18',
    minus: 'M5 12h14',
    heart: 'M12 20s-7-4.4-7-10a4 4 0 0 1 7-2.6A4 4 0 0 1 19 10c0 5.6-7 10-7 10z',
    sparkle: 'M12 3l1.8 5.2L19 10l-5.2 1.8L12 17l-1.8-5.2L5 10l5.2-1.8z',
    sync: 'M20 12a8 8 0 1 1-2.3-5.6M20 4v5h-5',
  };
  const ico = (name, size = 20, cls = '') => `<svg class="ico ${cls}" width="${size}" height="${size}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="${PFADE[name]}"/></svg>`;
  const lilie = (size, farbe) => `<svg class="lilie" width="${size}" height="${size}" viewBox="${L.viewBox}" aria-hidden="true"><g transform="${L.transform}"><path d="${L.d}" fill="${farbe}"/></g></svg>`;
  const maskottchen = (stufe, size) => `<img class="mask" src="${BILD}${Q.M.stufen[stufe].bild}" width="${size}" height="${size}" alt="">`;
  const sec = (x, n) => `<div class="sec">${x}${n != null ? ` <span class="n">${n}</span>` : ''}</div>`;

  // ------------------------------------------------------------- Rahmen
  function telefon(ctx, kopfHtml, inhalt, { shot, beschriftung = '', overlay = '', lang = false } = {}) {
    return `<figure class="phone ${ctx.modus}" data-shot="${esc(shot)}">
      <div class="screen${lang ? '' : ' fest'}">
        <div class="status"><span>9:41</span><i class="island"></i><span class="sys"></span></div>
        ${kopfHtml}
        <div class="body">${inhalt}</div>
        <nav class="tabbar"><span>Mitglieder</span><span>Statistik</span><span>Stufenwechsel</span><span class="on">Einstellungen</span></nav>
        ${overlay}
      </div>
      ${beschriftung ? `<figcaption>${beschriftung}</figcaption>` : ''}
    </figure>`;
  }
  function panel(ctx, inhalt, { shot, titel = '' } = {}) {
    return `<figure class="mpanel ${ctx.modus}" data-shot="${esc(shot)}">
      ${titel ? `<figcaption>${titel}</figcaption>` : ''}<div class="mpanel-in">${inhalt}</div></figure>`;
  }
  const kopf = (titel, rechts = '') => `<header class="ab"><div class="k-row q-kopf">${ico('back', 22)}<div class="k-t"><b>${esc(titel)}</b></div>${rechts}</div></header>`;

  // ------------------------------------------------------------- Karten
  const artIcon = (art, size = 40) => `<span class="q-ai" style="--a:${art.farbe};width:${size}px;height:${size}px">${ico(art.icon, Math.round(size * 0.5))}</span>`;
  const regel = (art, einst) => {
    const j = art.id === 'efz' ? (einst?.gueltig ?? art.gueltig) : art.gueltig;
    return j ? `Alle ${j} Jahre` : 'ohne Ablauf';
  };
  function statusText(a, kurz = false) {
    const teile = [];
    if (R2(a)) {
      const offen = a.fehlt + a.ueber;
      if (offen) teile.push(`<span class="q-rot">${offen} ${offen === 1 ? 'fehlt' : 'fehlen'}</span>`);
      if (a.bald) teile.push(`<span class="q-orange">${a.bald} ${kurz ? 'bald' : 'demnächst fällig'}</span>`);
      if (!teile.length) teile.push('<span class="q-gruen">alle gültig</span>');
      return teile.join('<i class="q-sep">·</i>');
    }
    if (kurz) {
      const offen = a.fehlt + a.ueber;
      if (offen) teile.push(`<span class="q-rot">${offen} offen</span>`);
      if (a.bald) teile.push(`<span class="q-orange">${a.bald} bald</span>`);
      if (!teile.length) teile.push('<span class="q-gruen">alle gültig</span>');
      return teile.join('<i class="q-sep">·</i>');
    }
    if (a.fehlt) teile.push(`<span class="q-rot">${a.fehlt} ${kurz ? 'fehlt' : a.fehlt === 1 ? 'fehlt' : 'fehlen'}</span>`);
    if (a.ueber) teile.push(`<span class="q-rot">${a.ueber} überfällig</span>`);
    if (a.bald) teile.push(`<span class="q-orange">${a.bald} ${kurz ? 'bald' : 'demnächst fällig'}</span>`);
    if (!teile.length) teile.push('<span class="q-gruen">alle gültig</span>');
    return teile.join('<i class="q-sep">·</i>');
  }
  function balken(a, hoch = 5) {
    const seg = (n, cls) => (n ? `<i class="${cls}" style="flex:${n}"></i>` : '');
    if (R2(a)) return `<div class="q-bal" style="height:${hoch}px">${seg(a.ok, 'ok')}${seg(a.bald, 'bald')}${seg(a.ueber + a.fehlt, 'fehlt')}</div>`;
    return `<div class="q-bal" style="height:${hoch}px">${seg(a.ok, 'ok')}${seg(a.bald, 'bald')}${seg(a.ueber, 'ueber')}${seg(a.fehlt, 'fehlt')}</div>`;
  }
  function gesperrtKarte(art, variante) {
    const zeile = '<span class="q-leise">Keine Berechtigung für EFZ-Einsicht</span>';
    if (variante === 'U3') return `<div class="q-zeile">${artIcon(art, 34)}<div class="q-zt"><b>${esc(art.label)}</b>${zeile}</div>${ico('lock', 18, 'muted')}</div>`;
    if (variante === 'U2') return `<div class="q-k2 gesperrt">${artIcon(art, 30)}<b class="q-k2-l">${esc(art.kurz)}</b><div class="q-k2-n">${ico('lock', 22, 'muted')}</div>${zeile}</div>`;
    return `<div class="q-k1 gesperrt"><div class="q-k1-kopf"><b>${esc(art.label)}</b></div><div class="q-k1-mitte">${artIcon(art)}<span class="q-zahl leise">${ico('lock', 26, 'muted')}</span></div>${zeile}</div>`;
  }
  function karte(a, variante, { zahnrad = true, gesperrt = false } = {}) {
    const art = a.art;
    if (gesperrt) return gesperrtKarte(art, variante);
    if (variante === 'U3') {
      return `<div class="q-zeile">${artIcon(art, 34)}<div class="q-zt"><b>${esc(art.label)}</b><small>${regel(art, a.einst)} · ${statusText(a, true)}</small>${balken(a, 4)}</div>
        <span class="q-zr"><b>${a.erfuellt}</b>/${a.benoetigt}</span>${ico('right', 18, 'muted')}</div>`;
    }
    if (variante === 'U2') {
      return `<div class="q-k2">${artIcon(art, 30)}<b class="q-k2-l">${esc(art.kurz)}</b>
        <div class="q-k2-n"><b>${a.erfuellt}</b><span>/ ${a.benoetigt}</span></div>
        <small>${regel(art, a.einst)}</small><div class="q-k2-s">${statusText(a, true)}</div>${balken(a, 4)}</div>`;
    }
    return `<div class="q-k1"><div class="q-k1-kopf"><b>${esc(art.label)}</b>${zahnrad ? ico('gear', 19, 'muted') : ''}</div>
      <div class="q-k1-mitte">${artIcon(art)}<span class="q-zahl">${a.erfuellt}<i>/</i>${a.benoetigt}</span></div>
      <small class="q-regel">${regel(art, a.einst)}</small><div class="q-status">${statusText(a)}</div>${balken(a, 5)}</div>`;
  }
  function uebersicht(ctx, variante, { angezeigt = Q.standard.angezeigt, einstellungen = Q.standard.einstellungen, efzGesperrt = false } = {}) {
    // Ab Runde 2 erscheinen nur Arten, die im Kontext jemand hat (EFZ immer).
    const sichtbar = R2(ctx) ? angezeigt.filter((id) => id === 'efz' || anzahlInhaber(id) > 0) : angezeigt;
    const karten = sichtbar.map((id) => karte({ ...Q.auswertung(id, einstellungen), runde: ctx.runde }, variante, { gesperrt: efzGesperrt && id === 'efz' }));
    const hinzu = variante === 'U3'
      ? `<div class="q-zeile q-hinzu">${ico('plus', 20)}<b>Qualifikation hinzufügen</b></div>`
      : `<div class="${variante === 'U2' ? 'q-k2' : 'q-k1'} q-hinzu">${ico('plus', 22)}<b>Qualifikation hinzufügen</b></div>`;
    const kopfzeile = `<div class="q-ue-kopf"><span>Stamm Silberfels · ${ctx.n ?? 12} Personen mit Rolle</span></div>`;
    if (variante === 'U2') return `${kopfzeile}<div class="q-raster">${karten.join('')}${hinzu}</div>`;
    if (variante === 'U3') return `${kopfzeile}<div class="card q-liste">${karten.join('')}${hinzu}</div>`;
    return `${kopfzeile}<div class="q-stapel">${karten.join('')}${hinzu}</div>`;
  }

  // ------------------------------------------------------------- Detail
  const PILL = { fehlt: ['schlecht', 'fehlt'], ueber: ['schlecht', 'überfällig'], bald: ['warn', 'bald fällig'], ok: ['gut', 'gültig'] };
  function rollenKurz(p) {
    return p.rollen.map((r) => (r.art === 's' ? r.label : `${Q.M.stufen[r.stufe].kurz}${r.art === 'l' ? '-Leitung' : ''}`)).join(', ');
  }
  function personIcon(p) {
    const r = p.rollen.find((x) => x.art === 'l') || p.rollen[0];
    if (r.art === 's') return `<span class="q-pi neutral">${lilie(16, 'var(--fg2)')}</span>`;
    if (r.art === 'l') return `<span class="q-pi" style="--c:var(--st-${r.stufe})">${lilie(16, `var(--st-${r.stufe})`)}</span>`;
    return `<span class="q-pi mit" style="--c:var(--st-${r.stufe})">${maskottchen(r.stufe, 22)}</span>`;
  }
  function personZeile(x, r2 = false) {
    const [ton, text] = r2 && x.s === 'ueber' ? ['schlecht', 'abgelaufen'] : PILL[x.s];
    const datum = x.bis === null ? 'nicht hinterlegt' : x.bis === 'ohne' ? 'ohne Ablauf' : x.s === 'ueber' ? (r2 ? `seit ${dmy(x.bis)}` : `abgelaufen ${dmy(x.bis)}`) : `bis ${dmy(x.bis)}`;
    return `<div class="q-pz">${personIcon(x.p)}<div class="q-pzt"><b>${esc(x.p.name)}${x.p.eigene ? ' <span class="q-du">du</span>' : ''}</b><small>${datum} · ${esc(rollenKurz(x.p))}</small></div><span class="spill ${ton}">${text}</span></div>`;
  }
  function detailKopfkarte(a) {
    return `<div class="card q-dk">${artIcon(a.art, 44)}<div><b class="q-dk-n">${a.erfuellt} von ${a.benoetigt} erfüllt</b><small>${regel(a.art, a.einst)} · ${a.art.quelle === 'app' ? (R2(a) ? 'fest für das EFZ' : 'Gültigkeit in der App eingestellt') : 'Gültigkeit aus Hitobito'}</small><div class="q-status">${statusText(a)}</div></div></div>
      <div class="q-kreiszeile">${ico('group', 16)}<span>Benötigt von: <b>${esc(a.kreis.label)}</b> · ${a.benoetigt} Personen</span></div>${balken(a, 6)}`;
  }
  function detail(ctx, artId, variante, einstellungen = Q.standard.einstellungen, { alle = false } = {}) {
    const a = { ...Q.auswertung(artId, einstellungen), runde: ctx.runde };
    if (variante === 'D2' && R2(ctx)) {
      const bedarf = a.fehlt + a.ueber + a.bald;
      const liste = alle ? a.leute : a.leute.filter((x) => x.s !== 'ok');
      return `${detailKopfkarte(a)}<div class="segf q-seg"><span class="${alle ? '' : 'on'}">Handlungsbedarf <i>${bedarf}</i></span><span class="${alle ? 'on' : ''}">Alle <i>${a.benoetigt}</i></span></div>
        <div class="card q-pliste">${liste.map((x) => personZeile(x, true)).join('')}</div>`;
    }
    if (variante === 'D2') {
      return `${detailKopfkarte(a)}<div class="segf q-seg"><span class="on">Handlungsbedarf <i>${a.fehlt + a.ueber + a.bald}</i></span><span>Alle <i>${a.benoetigt}</i></span></div>
        <div class="card q-pliste">${a.leute.filter((x) => x.s !== 'ok').map(personZeile).join('')}</div>`;
    }
    const gruppen = [['fehlt', 'Fehlt'], ['ueber', 'Überfällig'], ['bald', 'Demnächst fällig'], ['ok', 'Gültig']];
    return `${detailKopfkarte(a)}${gruppen.map(([s, titel]) => {
      const leute = a.leute.filter((x) => x.s === s);
      if (!leute.length) return '';
      const zeilen = s === 'ok' && leute.length > 4 ? `${leute.slice(0, 3).map(personZeile).join('')}<div class="mehr">${leute.length - 3} weitere${ico('down', 16)}</div>` : leute.map(personZeile).join('');
      return `${sec(titel, leute.length)}<div class="card q-pliste">${zeilen}</div>`;
    }).join('')}`;
  }

  // ------------------------------------------------------------- Einstellungen je Qualifikation
  function stepper(wert, einheit) {
    return `<span class="q-step"><span>${ico('minus', 16)}</span><b>${wert}</b><small>${einheit}</small><span>${ico('plus', 16)}</span></span>`;
  }
  const radio = (an, text, sub = '', rechts = '') => `<div class="q-radio${an ? ' on' : ''}"><i></i><div><span>${text}</span>${sub ? `<small>${sub}</small>` : ''}</div>${rechts}</div>`;
  function kreisVorschau(einst) {
    const kreis = Q.kreise[einst.kreis];
    const leute = Q.personen.filter(kreis.test);
    return `<div class="q-vorschau">${ico('group', 16)}<span>betrifft <b>${leute.length} Personen</b></span><span class="q-av">${leute.slice(0, 5).map((p) => `<i>${esc(p.name.split(' ').map((w) => w[0]).join('').slice(0, 2))}</i>`).join('')}${leute.length > 5 ? `<i class="n">+${leute.length - 5}</i>` : ''}</span>${ico('right', 16, 'muted')}</div>`;
  }
  function kreisP1(einst) {
    const regeln = einst.kreis === 'leitungAmt'
      ? [['hat', 'Rollenart', 'Leitung'], ['oder', 'Rollenart', 'Amt']]
      : einst.kreis === 'leitung' ? [['hat', 'Rollenart', 'Leitung']] : [['hat', 'Rollentyp', 'Stammesvorstand'], ['oder', 'Rollentyp', 'Kurat*in']];
    return `<div class="card q-regeln">${regeln.map(([v, k, w], i) => `<div class="q-regel">${i ? `<span class="q-und">${v}</span>` : '<span class="q-und erst">wer</span>'}<span class="q-feld">${k}${ico('down', 14)}</span><span class="q-feld wert">${w}${ico('down', 14)}</span>${ico('x', 16, 'muted')}</div>`).join('')}
      <div class="q-regel neu">${ico('plus', 16)}<div>Regel hinzufügen<small>Rollenart, Stufe, Rollentyp oder Alter, verknüpft mit „und“ oder „oder“</small></div></div></div>${kreisVorschau(einst)}`;
  }
  function kreisP2(einst) {
    return `<div class="card q-radios">${Object.entries(Q.kreise).map(([id, k]) => radio(einst.kreis === id, k.label, k.desc, `<small class="q-anz">${Q.personen.filter(k.test).length}</small>`)).join('')}
      ${radio(false, 'Eigene Regeln …', 'Rollenart, Stufe, Rollentyp und Alter kombinieren', ico('right', 16, 'muted'))}</div>${kreisVorschau(einst)}`;
  }
  function einstellungen(ctx, artId, variante) {
    if (R2(ctx)) return einstellungenR2(ctx, artId);
    const art = Q.arten[artId];
    const einst = Q.standard.einstellungen[artId];
    const kreis = variante === 'P1' ? kreisP1(einst) : kreisP2(einst);
    const tage = einst.vorlauf;
    const erinnerung = `<div class="card q-erin">
        <div class="segf"><span class="${tage ? '' : 'on'}">Aus</span><span class="${tage ? 'on' : ''}">Vorher erinnern</span></div>
        ${tage ? `<div class="q-zeile-e"><span>Erinnern</span>${stepper(tage, 'Tage vorher')}</div>
        <div class="q-zeile-e"><span>An wen</span></div>
        ${radio(einst.umfang === 'alle', 'Alle im Personenkreis', `Abläufe anderer gebündelt, eine Mitteilung pro Tag`)}
        ${radio(einst.umfang === 'meine', 'Nur meine', 'Nur wenn deine eigene Qualifikation abläuft')}` : ''}
      </div><div class="q-fuss">Gilt auch als Warnschwelle: „demnächst fällig“ ab ${tage || 90} Tagen vorher.</div>`;
    const gueltig = art.id === 'efz'
      ? `${sec('Gültigkeit')}<div class="card q-erin"><div class="q-zeile-e"><span>Gültig für</span>${stepper(einst.gueltig, 'Jahre')}</div></div><div class="q-fuss">Hitobito kennt für das EFZ keine Gültigkeit. Gerechnet wird ab dem Ausstellungsdatum der letzten Einsichtnahme.</div>`
      : `${sec('Gültigkeit')}<div class="card q-erin"><div class="q-zeile-e"><span>${regel(art, einst)}</span><small class="q-leise">aus Hitobito</small></div></div>`;
    return `<div class="q-ek">${artIcon(art, 36)}<b>${esc(art.label)}</b></div>
      ${sec('Wer braucht sie?')}${kreis}
      ${sec('Erinnerung')}${erinnerung}
      ${gueltig}
      <div class="q-entfernen">Aus der Übersicht entfernen</div>`;
  }

  function einstellungenR2(ctx, artId) {
    const art = Q.arten[artId];
    const einst = Q.standard.einstellungen[artId];
    const tage = einst.vorlauf;
    const erinnerung = `<div class="card q-erin">
        <div class="segf"><span class="${tage ? '' : 'on'}">Aus</span><span class="${tage ? 'on' : ''}">Vorher erinnern</span></div>
        ${tage ? `<div class="q-zeile-e"><span>Erinnern</span>${stepper(tage, 'Tage vorher')}</div>
        <div class="q-zeile-e"><span>Von wem</span></div>
        ${radio(einst.umfang === 'alle', 'Von allen im Personenkreis', 'Läuft bei jemandem die Qualifikation ab, wirst du erinnert. Gebündelt, eine Mitteilung pro Tag.')}
        ${radio(einst.umfang === 'meine', 'Nur von mir', 'Nur wenn deine eigene Qualifikation abläuft')}` : ''}
      </div><div class="q-fuss">Gilt auch als Warnschwelle: „demnächst fällig“ ab ${tage || 90} Tagen vorher.</div>`;
    const gueltig = `${sec('Gültigkeit')}<div class="card q-erin"><div class="q-zeile-e"><span>${regel(art, einst)}</span><small class="q-leise">${art.id === 'efz' ? 'fest für das EFZ' : 'aus Hitobito'}</small></div></div>${art.id === 'efz' ? '<div class="q-fuss">Gerechnet ab dem Ausstellungsdatum der letzten Einsichtnahme.</div>' : ''}`;
    return `<div class="q-ek">${artIcon(art, 36)}<b>${esc(art.label)}</b></div>
      ${sec('Wer braucht sie?')}${kreisP1(einst)}
      ${sec('Erinnerung')}${erinnerung}
      ${gueltig}`;
  }

  // Zwischen Übersicht und Einstellungen: welche Arten angezeigt werden, Reihenfolge, Einstieg je Art.
  function auswahl(ctx, angezeigt = Q.standard.angezeigt) {
    const im = Object.values(Q.arten).filter((a) => !a.nichtImKontext && (a.id === 'efz' || anzahlInhaber(a.id) > 0));
    const zeile = (a) => {
      const an = angezeigt.includes(a.id);
      const sub = a.id === 'efz' ? 'Einsichtnahmen · Alle 5 Jahre' : `${anzahlInhaber(a.id)} im Stamm · ${regel(a)}`;
      return `<div class="q-wahl${an ? '' : ' aus2'}">${ico('grip', 18, 'muted')}${artIcon(a, 30)}<div><b>${esc(a.label)}</b><small>${sub}</small></div>${schalter(an)}<span class="q-chev">${ico('right', 16)}</span></div>`;
    };
    return `<p class="q-sheet-h" style="margin-top:16px">Angezeigt werden nur Qualifikationen, die im Stamm Silberfels jemand hat. Ausgeblendete und gerade fehlende Arten behalten ihre Einstellungen.</p>
      ${sec('In der Übersicht')}<div class="card q-wliste">${im.filter((a) => angezeigt.includes(a.id)).map(zeile).join('')}</div>
      ${sec('Ausgeblendet')}<div class="card q-wliste">${im.filter((a) => !angezeigt.includes(a.id)).map(zeile).join('')}</div>
      <div class="q-fuss">Schalter: in der Übersicht zeigen. Pfeil: Personenkreis und Erinnerung einstellen. Reihenfolge per Ziehen.</div>`;
  }
  function debugTools(ctx, an) {
    return `<div class="card q-nz"><div class="q-dbg-t">Supporter (Test)</div><div class="q-dbg-s">Übergangsweise, bis die Store-Anbindung steht.</div>
      <div class="q-zeile-e"><div><span>Supporter-Zugang</span><small>Schaltet Supporter-Funktionen frei, etwa die Qualifikationen-Übersicht</small></div>${schalter(an)}</div></div>`;
  }

  // ------------------------------------------------------------- Hinzufügen
  function anzahlInhaber(artId) { return Q.personen.filter((p) => p.q[artId]).length; }
  function hinzufuegenSheet(ctx, angezeigt = Q.standard.angezeigt) {
    const im = Object.values(Q.arten).filter((a) => !a.nichtImKontext);
    const weg = Object.values(Q.arten).filter((a) => a.nichtImKontext);
    const zeile = (a) => {
      const an = angezeigt.includes(a.id);
      const sub = a.id === 'efz' ? 'Einsichtnahmen · Vorgabe' : `${anzahlInhaber(a.id)} im Stamm · ${regel(a)}${['praev', 'eh'].includes(a.id) ? ' · Vorgabe' : ''}`;
      return `<div class="q-wahl${an ? ' on' : ''}${a.nichtImKontext ? ' weg' : ''}">${ico('grip', 18, 'muted')}${artIcon(a, 30)}<div><b>${esc(a.label)}</b><small>${a.nichtImKontext ? 'Im aktuellen Stamm hat sie niemand · Einstellungen bleiben' : sub}</small></div><i class="q-check">${an ? ico('check', 16) : ''}</i></div>`;
    };
    return `<div class="q-sheet-bg"></div><div class="q-sheet"><i class="q-griff"></i>
      <div class="q-sheet-k"><b>Qualifikationen in der Übersicht</b><span class="tbtn">Fertig</span></div>
      <p class="q-sheet-h">Zur Auswahl stehen alle Arten, die jemand im Stamm Silberfels hat. Reihenfolge per Ziehen.</p>
      <div class="card q-wliste">${im.map(zeile).join('')}</div>
      ${sec('Früher gesehen')}<div class="card q-wliste">${weg.map(zeile).join('')}</div></div>`;
  }

  // ------------------------------------------------------------- Benachrichtigungen
  function schalter(an) { return `<i class="q-sw${an ? ' on' : ''}"></i>`; }
  function benachrichtigungen(ctx, { an = true } = {}) {
    const chips = ['efz', 'praev', 'eh', 'juleica', 'wb'].map((id) => {
      const art = Q.arten[id];
      const gewaehlt = ['efz', 'praev', 'eh'].includes(id);
      return `<span class="q-chip${gewaehlt ? ' on' : ''}${art.gueltig ? '' : ' aus'}">${gewaehlt ? ico('check', 14) : ''}${esc(art.kurz)}${art.gueltig ? '' : ' <small>ohne Ablauf</small>'}</span>`;
    }).join('');
    return `<div class="card q-nz"><div class="q-zeile-e"><div><span>Push-Mitteilungen</span><small>Erlaubt in den iOS-Einstellungen</small></div>${schalter(true)}</div></div>
      ${sec('Geburtstage')}<div class="card q-nz"><div class="q-zeile-e"><span>Geburtstage der Stufe</span>${schalter(true)}</div></div>
      ${sec('Meine Qualifikationen')}<div class="card q-nz">
        <div class="q-zeile-e"><div><span>Vor dem Ablauf erinnern</span><small>Als Mitteilung und unter Meldungen</small></div>${schalter(an)}</div>
        ${an ? `<div class="q-nz-u">Welche</div><div class="q-chips">${chips}</div>
        <div class="q-zeile-e"><span>Wann</span>${stepper(90, 'Tage vorher')}</div>` : ''}
      </div><div class="q-fuss">Erinnerungen für andere Personen stellst du in der Qualifikationen-Übersicht ein.</div>`;
  }
  function sperrbildschirm(ctx) {
    const m = (app, zeit, titel, text) => `<div class="q-push"><div class="q-push-k"><i class="q-appicon">${lilie(14, '#fff')}</i><span>${app}</span><small>${zeit}</small></div><b>${titel}</b><span>${text}</span></div>`;
    return `<div class="q-lock"><div class="q-lock-zeit">9:41</div><div class="q-lock-d">Freitag, 2. Oktober</div>
      ${m('NaMi', 'jetzt', 'Dein EFZ läuft bald ab', 'Gültig bis 20.11.2026, noch 49 Tage. Antrag in deinen Mitgliedsdetails.')}
      ${m('NaMi', '8:00', 'Qualifikationen laufen ab', 'Präventionsschulung: Bernd Hollmann und 1 weitere Person in den nächsten 90 Tagen.')}
      ${m('NaMi', 'gestern', 'Erste-Hilfe-Kurs läuft bald ab', 'Jonas Keller: gültig bis 01.11.2026.')}</div>`;
  }
  function meldungen(ctx) {
    const z = (ton, titel, text, aktion) => `<div class="card q-meld ${ton}"><span class="q-meld-i">${ico(ton === 'warn' ? 'clock' : 'info', 18)}</span><div><b>${titel}</b><span>${text}</span>${aktion ? `<u>${aktion}</u>` : ''}</div></div>`;
    return `${z('warn', 'Dein EFZ läuft bald ab', 'Gültig bis 20.11.2026, noch 49 Tage.', 'Mitgliedsdetails öffnen')}
      ${z('info', 'Neue App-Version verfügbar', 'Version 1.0.1 steht im App Store bereit.', '')}`;
  }

  // ------------------------------------------------------------- Premium
  function schnellzugriff(ctx, gesperrt) {
    const z = (icon, titel, sub, extra = '') => `<div class="q-sz">${ico(icon, 20)}<div><b>${titel}</b><small>${sub}</small></div>${extra}${ico('right', 16, 'muted')}</div>`;
    return `${sec('Schnellzugriff')}<div class="card q-szl">
      ${z('clock', 'Stufenwechsel', 'Wer steht zum Wechsel an')}
      ${z('shield', 'Qualifikationen', 'EFZ, Prävention, Erste Hilfe', gesperrt ? '<span class="q-sup">Supporter</span>' : '')}
      ${z('sparkle', 'NaMi AI', 'Fragen an deine Daten')}</div>`;
  }
  function gesperrt(ctx, variante) {
    if (variante === 'L2') {
      return `<div class="q-lock-l2">${ico('lock', 30)}<b>Teil des Supporter-Pakets</b>
        <span>Mit der Übersicht siehst du für den ganzen Stamm, wer welche Qualifikation braucht und wann sie abläuft, und kannst dich erinnern lassen.</span>
        <span class="q-btn">Supporter werden</span>
        <small>Deine eigenen Qualifikationen siehst du weiter in deinen Mitgliedsdetails, Erinnerungen dafür gibt es unter Benachrichtigungen.</small></div>`;
    }
    return `<div class="q-teaser"><div class="q-blur">${uebersicht(ctx, 'U1')}</div>
      <div class="q-teaser-box">${ico('lock', 22)}<b>Qualifikationen im Überblick</b>
        <span>Für den ganzen Stamm sehen, was fehlt und was bald abläuft. Teil des Supporter-Pakets.</span><span class="q-btn">Supporter werden</span>
        <small>Eigene Qualifikationen: Mitgliedsdetails und Benachrichtigungen, kostenlos.</small></div></div>`;
  }

  // ------------------------------------------------------------- Zustände
  function zustand(ctx, art) {
    if (art === 'nichtSync') return `<div class="q-leer">${ico('sync', 30)}<b>Noch nicht synchronisiert</b><span>Qualifikationen werden beim nächsten Sync geladen und sind danach auch offline verfügbar.</span></div>`;
    if (art === 'leer' && R2(ctx)) {
      const efz = { ...Q.auswertung('efz'), runde: ctx.runde };
      return `<div class="q-ue-kopf"><span>Stamm Silberfels · 12 Personen mit Rolle</span></div><div class="card q-liste">${karte(efz, 'U3')}</div>
        <div class="banner">${ico('info', 17)}<span>Im Stamm hat noch niemand eine Qualifikation aus Hitobito. Präventionsschulung und Erste Hilfe erscheinen, sobald sie jemand hat.</span></div>`;
    }
    if (art === 'leer') {
      return `<div class="q-ue-kopf"><span>Stamm Silberfels · 12 Personen mit Rolle</span></div><div class="q-stapel">${karte(Q.auswertung('efz'), 'U1')}
        <div class="banner">${ico('info', 17)}<span>Im Stamm hat noch niemand eine Qualifikation aus Hitobito. Präventionsschulung und Erste Hilfe erscheinen, sobald sie jemand hat.</span></div>
        <div class="q-k1 q-hinzu">${ico('plus', 22)}<b>Qualifikation hinzufügen</b></div></div>`;
    }
    return '';
  }

  window.QBAU = { esc, ico, telefon, panel, kopf, sec, karte, uebersicht, detail, einstellungen, auswahl, debugTools, hinzufuegenSheet, benachrichtigungen, sperrbildschirm, meldungen, schnellzugriff, gesperrt, zustand };
})();

// Bausteine der Mitgliedsdetail-Entwürfe: Rahmen, Kopf, Daten, Rollen, Verlauf, Qualifikationen.
// ctx = { modus: 'hell'|'dunkel', historie: true|false, offen: bool, daten, rollen, verlauf, efz, karte }
(function () {
  const D = window.MITGLIED;
  const L = window.LILIE;
  const BILD = '../../assets/images/';
  const TAG = 864e5;

  // ------------------------------------------------------------- Hilfen
  const esc = (s) => String(s ?? '').replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));
  const t = (s) => Date.parse(`${s}T00:00:00Z`);
  const HEUTE = t(D.HEUTE);
  const dmy = (s) => { const [y, m, d] = s.split('-'); return `${d}.${m}.${y}`; };
  const MONATE = ['Jan', 'Feb', 'März', 'Apr', 'Mai', 'Juni', 'Juli', 'Aug', 'Sep', 'Okt', 'Nov', 'Dez'];
  const my = (s) => { const [y, m] = s.split('-'); return `${MONATE[+m - 1]} ${y}`; };
  const jahr = (s) => s.slice(0, 4);
  function monate(a, b) {
    const [ya, ma, da] = a.split('-').map(Number);
    const [yb, mb, db] = b.split('-').map(Number);
    return (yb - ya) * 12 + (mb - ma) - (db < da ? 1 : 0);
  }
  const heuteIso = D.HEUTE;
  function alter(geb) { return Math.floor(monate(geb, heuteIso) / 12); }
  function dauer(a, b = heuteIso, kurz = false) {
    const tage = Math.round((t(b) - t(a)) / TAG);
    if (tage < 14) return kurz ? `${tage} T.` : `${tage} ${tage === 1 ? 'Tag' : 'Tagen'}`;
    if (tage < 70) return kurz ? `${Math.round(tage / 7)} Wo.` : `${Math.round(tage / 7)} Wochen`;
    const mon = monate(a, b);
    if (mon < 24) return kurz ? `${mon} Mon.` : `${mon} Monaten`;
    const j = Math.floor(mon / 12);
    return kurz ? `${j} J.` : `${j} Jahren`;
  }
  const plural = (n, eins, viele) => `${n} ${n === 1 ? eins : viele}`;
  // Ab Runde 2 gelten die Festlegungen aus Runde 1; ältere Runden-Seiten bleiben unverändert.
  const R2 = (ctx) => (ctx.runde || 1) >= 2;
  const R3 = (ctx) => (ctx.runde || 1) >= 3;
  const R4 = (ctx) => (ctx.runde || 1) >= 4;
  const MONATE_LANG = ['Januar', 'Februar', 'März', 'April', 'Mai', 'Juni', 'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember'];
  // Nächster Geburtstag ab dem Stichtag; liefert Tage bis dahin.
  function naechsterGeburtstag(geb) {
    const [, m, d] = geb.split('-').map(Number);
    const j = Number(heuteIso.slice(0, 4));
    let ziel = Date.UTC(j, m - 1, d);
    if (ziel < HEUTE) ziel = Date.UTC(j + 1, m - 1, d);
    return { tage: Math.round((ziel - HEUTE) / TAG), text: `${d}. ${MONATE_LANG[m - 1]}` };
  }
  // Altersgrenzen wie StufenDefaults.build() in lib/domain/stufe/altersgrenzen.dart.
  const ALTER_MIN = { biber: 4, woe: 6, jufi: 9, pfadi: 12, rover: 15 };
  const ALTER_MAX = { biber: 7, woe: 10, jufi: 13, pfadi: 16, rover: 20 };
  const ROVER_MAX = 20;
  const NAECHSTE = { biber: 'woe', woe: 'jufi', jufi: 'pfadi', pfadi: 'rover' };
  const ZIELNAME = { woe: 'den Wölflingen', jufi: 'den Jufis', pfadi: 'den Pfadis', rover: 'den Rovern' };

  // ------------------------------------------------------------- Symbole
  const PFADE = {
    back: 'M19 12H5M11 6l-6 6 6 6',
    phone: 'M5 4h4l2 5-2.5 1.5a11 11 0 0 0 5 5L15 13l5 2v4a2 2 0 0 1-2 2A16 16 0 0 1 3 6a2 2 0 0 1 2-2',
    mail: 'M3 6h18v12H3zM3 7l9 6 9-6',
    edit: 'M4 20h4L19 9l-4-4L4 16zM14 6l4 4',
    pin: 'M12 21s-7-6.5-7-12a7 7 0 0 1 14 0c0 5.5-7 12-7 12zM12 7a2.5 2.5 0 1 0 0 5 2.5 2.5 0 0 0 0-5',
    home: 'M3 11l9-7 9 7v9H3zM9 20v-6h6v6',
    down: 'M6 9l6 6 6-6',
    up: 'M6 15l6-6 6 6',
    right: 'M9 6l6 6-6 6',
    download: 'M12 4v11M7 10l5 5 5-5M5 20h14',
    shield: 'M12 3l8 3v6c0 5-3.5 8-8 9-4.5-1-8-4-8-9V6z',
    people: 'M9 11a3.5 3.5 0 1 0 0-7 3.5 3.5 0 0 0 0 7zM2.5 20a6.5 6.5 0 0 1 13 0M16 4.5a3.5 3.5 0 0 1 0 6.5M18 14a6 6 0 0 1 3.5 6',
    cake: 'M4 20h16v-7H4zM4 16c2 1.5 4 1.5 6 0s4-1.5 6 0 3 1 4 0M12 9v4M12 6v1',
    id: 'M3 5h18v14H3zM7 15h4M7 11h10',
    refresh: 'M20 12a8 8 0 1 1-2.3-5.6M20 4v5h-5',
    wifioff: 'M3 3l18 18M8.5 16.5a5 5 0 0 1 7 0M5 12.5a10 10 0 0 1 5-2.7M19 12.5a10 10 0 0 0-2.4-1.7M12 20h.01',
    map: 'M9 4 3 6v14l6-2 6 2 6-2V4l-6 2zM9 4v14M15 6v14',
    alert: 'M12 3 2 20h20zM12 10v4M12 17h.01',
    clock: 'M12 3a9 9 0 1 0 0 18 9 9 0 0 0 0-18zM12 7v5l3 2',
    lock: 'M6 11h12v9H6zM8.5 11V8a3.5 3.5 0 0 1 7 0v3',
    check: 'M12 3a9 9 0 1 0 0 18 9 9 0 0 0 0-18zM8 12l3 3 5-6',
    award: 'M12 3a6 6 0 1 0 0 12 6 6 0 0 0 0-12zM8.5 14 7 21l5-3 5 3-1.5-7',
    copy: 'M9 9h11v11H9zM5 15H4V4h11v1',
    euro: 'M17 6.5A6 6 0 0 0 7.5 9v6a6 6 0 0 0 9.5 2.5M5 10.5h8M5 13.5h8',
    calendar: 'M4 6h16v14H4zM4 10h16M8 3v4M16 3v4',
    person: 'M12 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8zM4 21a8 8 0 0 1 16 0',
    group: 'M3 21V8l9-5 9 5v13M8 21v-6h8v6',
  };
  const ico = (name, size = 20, cls = '') => `<svg class="ico ${cls}" width="${size}" height="${size}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="${PFADE[name]}"/></svg>`;
  const lilie = (size, farbe) => `<svg class="lilie" width="${size}" height="${size}" viewBox="${L.viewBox}" aria-hidden="true"><g transform="${L.transform}"><path d="${L.d}" fill="${farbe}"/></g></svg>`;
  const maskottchen = (stufe, size) => `<img class="mask" src="${BILD}${D.stufen[stufe].bild}" width="${size}" height="${size}" alt="">`;

  // ------------------------------------------------------------- Rollenlogik
  function status(rolle) {
    if (t(rolle.start) > HEUTE) return 'zukunft';
    if (rolle.ende && t(rolle.ende) < HEUTE) return 'vergangen';
    return 'aktiv';
  }
  // historie=false bildet die heutige API nach: vergangene Rollen fehlen.
  function rollenVon(p, ctx) {
    const alle = p.rollen.map((r) => ({ ...r, status: status(r) }));
    return ctx.historie ? alle : alle.filter((r) => r.status !== 'vergangen');
  }
  const RANG = { rover: 5, pfadi: 4, jufi: 3, woe: 2, biber: 1 };
  function hauptRolle(p) {
    const aktiv = p.rollen.filter((r) => status(r) === 'aktiv');
    const best = (art) => aktiv.filter((r) => r.art === art && r.stufe).sort((a, b) => RANG[b.stufe] - RANG[a.stufe])[0];
    return best('l') || best('m') || (aktiv.length ? { art: 's' } : null);
  }
  function rollenTitel(r) {
    if (r.art === 'm' && r.stufe) return D.stufen[r.stufe].name;
    if (r.art === 'l' && r.stufe) return `${r.label} · ${D.stufen[r.stufe].kurz}`;
    return r.label;
  }
  function rollenOrt(r) {
    const teile = [r.gruppe];
    if (r.layer !== r.gruppe) teile.push(r.layer);
    return teile.join(' · ');
  }
  function zeitraum(r, kurz = false) {
    if (r.status === 'zukunft') return `ab ${my(r.start)}`;
    const von = r.ohneStart ? 'Start unbekannt' : my(r.start);
    if (r.status === 'aktiv') return r.ohneStart ? 'seit ? (kein Startdatum)' : `seit ${my(r.start)}`;
    if (kurz) return !r.ohneStart && jahr(r.start) === jahr(r.ende) ? jahr(r.ende) : `${r.ohneStart ? '?' : jahr(r.start)}–${jahr(r.ende)}`;
    return `${von} – ${my(r.ende)} · ${dauer(r.start, r.ende, true)}`;
  }
  function rollenIcon(r, size = 30) {
    if (r.art === 'm' && r.stufe) return `<span class="ri" style="width:${size}px;height:${size}px">${maskottchen(r.stufe, size)}</span>`;
    const farbe = r.stufe ? `var(--st-${r.stufe})` : 'var(--muted)';
    return `<span class="ri lil" style="width:${size}px;height:${size}px">${lilie(Math.round(size * 0.78), farbe)}</span>`;
  }
  const sortiere = (liste) => [...liste].sort((a, b) => t(b.start) - t(a.start));

  // ------------------------------------------------------------- Rahmen
  function telefon(ctx, kopfHtml, inhalt, { shot, beschriftung = '', fest = false } = {}) {
    return `<figure class="phone ${ctx.modus}" data-shot="${esc(shot)}">
      <div class="screen${fest ? ' fest' : ''}">
        <div class="status"><span>9:41</span><i class="island"></i><span class="sys"></span></div>
        ${kopfHtml}
        <div class="body">${inhalt}</div>
        <nav class="tabbar"><span class="on">Mitglieder</span><span>Statistik</span><span>Stufenwechsel</span><span>Einstellungen</span></nav>
      </div>
      ${beschriftung ? `<figcaption>${beschriftung}</figcaption>` : ''}
    </figure>`;
  }
  function panel(ctx, inhalt, { shot, titel = '', breit = false } = {}) {
    return `<figure class="mpanel ${ctx.modus}${breit ? ' breit' : ''}" data-shot="${esc(shot)}">
      ${titel ? `<figcaption>${titel}</figcaption>` : ''}<div class="mpanel-in">${inhalt}</div></figure>`;
  }

  // ------------------------------------------------------------- Kopf
  const TABS = ['Daten', 'Rollen', 'Qualifikationen'];
  const initialen = (p) => (p.vorname[0] + p.nachname[0]).toUpperCase();
  const titel = (p) => p.fahrtenname || `${p.vorname} ${p.nachname}`;
  function stufenBadge(p) {
    const h = hauptRolle(p);
    if (!h) return '';
    if (h.art === 's') return `<span class="sbadge neutral">${lilie(13, 'var(--fg)')}Sonstige</span>`;
    const st = D.stufen[h.stufe];
    const icon = h.art === 'l' ? lilie(13, `var(--st-${h.stufe})`) : maskottchen(h.stufe, 14);
    return `<span class="sbadge" style="--c:var(--st-${h.stufe})">${icon}${esc(st.kurz)}${h.art === 'l' ? '-Leitung' : ''}</span>`;
  }
  function tabZeile(aktiv) {
    return `<div class="tabs">${TABS.map((x, i) => `<span class="${i === aktiv ? 'on' : ''}">${x}</span>`).join('')}</div>`;
  }
  function kopf(ctx, p, variante, aktiv = 0) {
    const sub = p.fahrtenname ? `${p.vorname} ${p.nachname}` : '';
    if (variante === 'S2') return steckbriefKopf(ctx, p, aktiv);
    const zeile = `<div class="ab-row">${ico('back', 22)}<span class="av">${initialen(p)}</span>
      <div class="ab-t"><b>${esc(titel(p))}</b>${sub ? `<small>${esc(sub)}</small>` : ''}</div>${stufenBadge(p)}</div>`;
    if (variante === 'S3') {
      return `<header class="ab">${zeile}<div class="anker">${TABS.map((x, i) => `<span class="${i === aktiv ? 'on' : ''}">${x}</span>`).join('')}</div></header>`;
    }
    return `<header class="ab">${zeile}${tabZeile(aktiv)}</header>`;
  }
  function steckbriefKopf(ctx, p, aktiv) {
    const aktive = p.rollen.filter((r) => status(r) === 'aktiv' && r.stufe);
    const chips = aktive.slice(0, 3).map((r) => {
      const st = D.stufen[r.stufe];
      const icon = r.art === 'l' ? lilie(12, `var(--st-${r.stufe})`) : maskottchen(r.stufe, 13);
      return `<span class="sbadge" style="--c:var(--st-${r.stufe})">${icon}${st.kurz}${r.art === 'l' ? '-Leitung' : ''}</span>`;
    });
    if (aktive.length > 3) chips.push(`<span class="sbadge neutral">+${aktive.length - 3}</span>`);
    if (!aktive.length && p.rollen.some((r) => status(r) === 'aktiv')) chips.push(`<span class="sbadge neutral">${lilie(12, 'var(--fg)')}Sonstige</span>`);
    const fakten = [];
    if (p.geburtsdatum) fakten.push(`${alter(p.geburtsdatum)} Jahre`);
    if (p.pronomen) fakten.push(p.pronomen);
    if (R3(ctx)) {
      if (p.geschlecht) fakten.push(p.geschlecht);
      if (p.austritt) fakten.push(`ausgetreten ${jahr(p.austritt)}`);
    } else fakten.push(p.austritt ? `ausgetreten ${my(p.austritt)}` : `seit ${dauer(p.eintritt)} dabei`);
    const efz = efzInfo(p.efz, ctx);
    return `<header class="ab steck">
      <div class="ab-row">${ico('back', 22)}<span class="grow"></span>${ico('edit', 20, 'muted')}</div>
      <div class="steck-main"><span class="av gross">${initialen(p)}</span>
        <div class="steck-t"><b>${esc(titel(p))}</b>${p.fahrtenname ? `<small>${esc(`${p.vorname} ${p.nachname}`)}</small>` : ''}
          <div class="steck-f">${fakten.map(esc).join(' · ')}</div></div></div>
      <div class="steck-chips${chips.length || !R2(ctx) ? '' : ' leer'}">${chips.join('')}${R2(ctx) ? '' : `<span class="sbadge efz ${efz.ton}"><i class="punkt"></i>EFZ ${esc(efz.kurz)}</span>`}</div>
      ${tabZeile(aktiv)}</header>`;
  }

  // ------------------------------------------------------------- Daten
  function zeile(wert, label, { icon = '', aktion = '', klasse = '' } = {}) {
    return `<div class="zl ${klasse}">${icon ? `<span class="zl-i">${icon}</span>` : ''}<div class="zl-t"><div class="zl-w">${wert}</div>${label ? `<div class="zl-l">${label}</div>` : ''}</div>${aktion ? `<span class="zl-a">${aktion}</span>` : ''}</div>`;
  }
  const aufklapp = (text, offen) => `<div class="mehr">${esc(text)}${ico(offen ? 'up' : 'down', 16)}</div>`;
  function kontaktListe(p, ctx, { icons = false, aktionen = false, zuerst = 1 } = {}) {
    const tel = p.telefon.map((x) => ({ ...x, typ: 'phone' }));
    const mail = p.mail.map((x) => ({ ...x, typ: 'mail' }));
    const sichtbar = [...tel.slice(0, zuerst), ...mail.slice(0, zuerst)];
    const rest = [...tel.slice(zuerst), ...mail.slice(zuerst)];
    const z = (x) => zeile(esc(x.wert), esc(x.label), {
      icon: icons ? ico(x.typ, 19, 'muted') : '',
      aktion: aktionen ? `<span class="rund">${ico(x.typ, 17)}</span>` : ico('copy', 17, 'muted'),
      klasse: 'link',
    });
    if (!sichtbar.length) return `<div class="leer">Keine Kontaktangaben vorhanden</div>`;
    let html = sichtbar.map(z).join('');
    if (rest.length) {
      const nT = tel.length - Math.min(tel.length, zuerst);
      const nM = mail.length - Math.min(mail.length, zuerst);
      const text = [nT ? plural(nT, 'weitere Telefonnummer', 'weitere Telefonnummern') : '', nM ? plural(nM, 'weitere E-Mail', 'weitere E-Mails') : ''].filter(Boolean).join(', ');
      html += ctx.offen ? rest.map(z).join('') + aufklapp('Weniger anzeigen', true) : aufklapp(text, false);
    }
    return html;
  }
  function karteSvg(breite, hoehe, marker = true) {
    return `<svg class="map" width="${breite}" height="${hoehe}" viewBox="0 0 ${breite} ${hoehe}" preserveAspectRatio="none" aria-hidden="true">
      <rect width="${breite}" height="${hoehe}" fill="var(--map-bg)"/>
      <path d="M0 ${hoehe * 0.78} C ${breite * 0.3} ${hoehe * 0.62}, ${breite * 0.55} ${hoehe}, ${breite} ${hoehe * 0.7} L ${breite} ${hoehe} L 0 ${hoehe} Z" fill="var(--map-water)"/>
      <rect x="${breite * 0.62}" y="${hoehe * 0.12}" width="${breite * 0.22}" height="${hoehe * 0.3}" rx="6" fill="var(--map-park)"/>
      <g stroke="var(--map-road)" stroke-linecap="round" fill="none">
        <path d="M-10 ${hoehe * 0.35} L ${breite + 10} ${hoehe * 0.22}" stroke-width="9"/>
        <path d="M${breite * 0.3} -10 L ${breite * 0.42} ${hoehe + 10}" stroke-width="7"/>
        <path d="M${breite * 0.7} -10 L ${breite * 0.58} ${hoehe * 0.7}" stroke-width="5"/>
        <path d="M-10 ${hoehe * 0.6} L ${breite * 0.5} ${hoehe * 0.5}" stroke-width="4"/>
      </g>
      ${marker ? `<g transform="translate(${breite * 0.46} ${hoehe * 0.44})"><path d="M0 0c-7-8-11-12-11-18a11 11 0 0 1 22 0c0 6-4 10-11 18z" fill="#cc1f2f" stroke="#fff" stroke-width="2"/><circle cy="-18" r="4" fill="#fff"/></g>
      <g transform="translate(${breite * 0.2} ${hoehe * 0.3})"><circle r="11" fill="var(--primary)" stroke="#fff" stroke-width="2"/><path d="M-5 1l5-5 5 5v5h-10z" fill="#fff"/></g>` : ''}
    </svg>`;
  }
  const KARTENTEXT = {
    fehler: { icon: 'alert', titel: 'Karte nicht verfügbar', grund: 'Technischer Fehler', knopf: 'Erneut versuchen' },
    offline: { icon: 'wifioff', titel: 'Karte offline nicht verfügbar', grund: 'Erscheint wieder, sobald du online bist', knopf: '' },
    wlan: { icon: 'wifioff', titel: 'Karte lädt nur im WLAN', grund: 'Einstellung: keine mobilen Daten', knopf: 'Trotzdem laden' },
    nichtGefunden: { icon: 'map', titel: 'Adresse nicht auf der Karte gefunden', grund: '', knopf: 'In Karten-App öffnen' },
  };
  function karte(zustand, variante, hoehe = 150) {
    const B = 358;
    if (!zustand) return '';
    if (zustand === 'ok') return `<div class="mapbox">${karteSvg(B, hoehe)}<span class="recenter">${ico('pin', 16)}</span></div>`;
    if (zustand === 'laden') return `<div class="mapbox skel" style="height:${hoehe}px"><i class="sk sk1"></i><i class="sk sk2"></i><i class="sk sk3"></i><span class="spin"></span></div>`;
    const k = KARTENTEXT[zustand];
    if (variante === 'M2') return '';
    if (variante === 'M3') {
      return `<div class="mapbox mini">${karteSvg(B, 76, false)}<div class="mini-in">${ico(k.icon, 18)}<div><b>${k.titel}</b>${k.grund ? `<small>${k.grund}</small>` : ''}</div>${k.knopf ? `<span class="tbtn">${k.knopf}</span>` : ''}</div></div>`;
    }
    return `<div class="mapstrip">${ico(k.icon, 17, 'muted')}<div><b>${k.titel}</b>${k.grund ? ` <small>${k.grund}</small>` : ''}</div>${k.knopf ? `<span class="tbtn">${k.knopf}</span>` : ''}</div>`;
  }
  function adressKarte(p, ctx, { icons = false, kartenOben = false } = {}) {
    if (!p.adressen.length) return '';
    const [haupt, ...rest] = p.adressen;
    const kv = ctx.karte || 'M1';
    const zustand = ctx.kartenZustand || p.karte;
    let unter = esc(haupt.label);
    if (kv === 'M2' && zustand && zustand !== 'ok' && zustand !== 'laden') {
      const k = KARTENTEXT[zustand];
      unter += `<br><span class="hinweis">${ico(k.icon, 13)}${k.titel}${k.knopf ? ` · <u>${k.knopf}</u>` : ''}</span>`;
    }
    const hauptZeile = zeile(haupt.zeilen.map(esc).join('<br>'), unter, { icon: icons ? ico('home', 19, 'muted') : '', aktion: ico('copy', 17, 'muted'), klasse: 'link' });
    const k = karte(zustand, kv);
    let weitere = '';
    if (rest.length) {
      weitere = ctx.offen
        ? rest.map((a) => zeile(a.zeilen.map(esc).join('<br>'), esc(a.label), { icon: icons ? ico('pin', 19, 'muted') : '', aktion: ico('copy', 17, 'muted'), klasse: 'link' })).join('') + aufklapp('Weniger anzeigen', true)
        : aufklapp(plural(rest.length, 'weitere Adresse', 'weitere Adressen'), false);
    }
    const kOben = kartenOben && zustand === 'ok';
    return `<div class="card nopad adr">${kOben ? k : ''}<div class="pad">${hauptZeile}</div>${kOben ? '' : k}${weitere ? `<div class="pad">${weitere}</div>` : ''}</div>`;
  }
  function familie(p, { icons = false, chips = false } = {}) {
    if (!p.haushalt.length) return '';
    if (chips) {
      return `<div class="fam-chips">${p.haushalt.map((h) => `<span class="fchip">${maskottchen(h.stufe, 20)}<b>${esc(h.name.split(' ')[0])}</b><small>${D.stufen[h.stufe].kurz} · ${h.alter}</small></span>`).join('')}</div>`;
    }
    return `<div class="card">${p.haushalt.map((h) => zeile(esc(h.name), `${D.stufen[h.stufe].name} · ${h.alter} Jahre`, { icon: icons ? ico('person', 19, 'muted') : `<span class="ri" style="width:26px;height:26px">${maskottchen(h.stufe, 26)}</span>`, aktion: ico('right', 17, 'muted'), klasse: 'link' })).join('')}<div class="fussnote">Gleicher Haushalt in Hitobito</div></div>`;
  }
  // Kachelwert ohne Dativ: „7 Tage“, „3 Monate“, ab zwei Jahren „22 J.“.
  const faktDauer = (a, b) => (monate(a, b) < 24 ? dauer(a, b).replace('Tagen', 'Tage').replace('Monaten', 'Monate') : dauer(a, b, true));
  function mitgliedschaftsZeilen(p, icons, { ohneDauer = false } = {}) {
    const i = (n) => (icons ? ico(n, 19, 'muted') : '');
    const z = [];
    z.push(zeile(esc(p.mitgliedsnummer), 'Mitgliedsnummer', { icon: i('id'), aktion: ico('copy', 17, 'muted') }));
    if (ohneDauer) { /* steht in der Kachel */ } else if (p.austritt) z.push(zeile(`${dmy(p.eintritt)} – ${dmy(p.austritt)}`, `Mitglied von ${jahr(p.eintritt)} bis ${jahr(p.austritt)} · ${dauer(p.eintritt, p.austritt)}`, { icon: i('calendar') }));
    else z.push(zeile(`seit ${dauer(p.eintritt)}`, `Eintritt ${dmy(p.eintritt)}`, { icon: i('calendar') }));
    z.push(zeile(esc(p.beitragsart), 'Beitragsart', { icon: i('euro') }));
    z.push(zeile(D.STAMM, 'Stamm', { icon: i('group') }));
    return z.join('');
  }
  function persoenlichZeilen(p, icons, { ohneAlter = false, konfession = true } = {}) {
    const i = (n) => (icons ? ico(n, 19, 'muted') : '');
    const z = [];
    if (p.geburtsdatum && !ohneAlter) z.push(zeile(`${alter(p.geburtsdatum)} Jahre`, `Geburtstag ${dmy(p.geburtsdatum)}`, { icon: i('cake') }));
    if (p.geschlecht) z.push(zeile(esc(p.geschlecht), 'Geschlecht', { icon: i('person') }));
    if (p.pronomen) z.push(zeile(esc(p.pronomen), 'Pronomen', { icon: i('person') }));
    if (konfession) z.push(zeile('<span class="platzhalter">noch nicht verfügbar</span>', 'Konfession', { icon: i('person'), klasse: 'blass' }));
    return z.join('');
  }
  const faktKacheln = (fakten) => `<div class="fakten">${fakten.map(([w, e, l, cls = '']) => `<div class="fakt${cls}"><b>${esc(w)}${e ? ` <small>${e}</small>` : ''}</b><span>${cls.includes('g2') ? ico('cake', 14) : ''}${esc(l)}</span></div>`).join('')}</div>`;
  const AKTIONEN = (p) => `<div class="qa"><span class="${p.telefon.length ? '' : 'aus'}">${ico('phone', 17)}Anrufen</span><span class="${p.mail.length ? '' : 'aus'}">${ico('mail', 17)}E-Mail</span><span>${ico('edit', 17)}Bearbeiten</span></div>`;
  const sec = (x, n) => `<div class="sec">${x}${n != null ? ` <span class="n">${n}</span>` : ''}</div>`;
  const austrittsBanner = (p) => (p.austritt ? `<div class="banner">${ico('clock', 17)}Ausgetreten zum ${dmy(p.austritt)}</div>` : '');

  function datenTab(p, ctx) {
    const v = ctx.daten || 'D1';
    if (v === 'D2') {
      return `${austrittsBanner(p)}
        <div class="card">${kontaktListe(p, ctx, { icons: true, aktionen: true, zuerst: 1 })}</div>
        ${p.adressen.length ? `<div class="gap"></div>${adressKarte(p, ctx, { icons: true, kartenOben: true })}` : ''}
        ${p.haushalt.length ? `${sec('Familie')}${familie(p, { icons: false })}` : ''}
        ${sec(`Über ${esc(p.fahrtenname || p.vorname)}`)}<div class="card">${persoenlichZeilen(p, true, { konfession: !R2(ctx) })}${mitgliedschaftsZeilen(p, true)}</div>`;
    }
    if (v === 'D3') {
      const ng = p.geburtsdatum ? naechsterGeburtstag(p.geburtsdatum) : null;
      const gebBald = R4(ctx) && ng && ng.tage <= 7 ? ` geb-bald ${(ctx.gebHervor || 'G1').toLowerCase()}` : '';
      const gebKachel = !ng ? ['–', '', 'Geburtstag unbekannt'] : [ng.text, '', ng.tage === 0 ? 'heute Geburtstag' : ng.tage <= 31 ? `in ${plural(ng.tage, 'Tag', 'Tagen')} · wird ${alter(p.geburtsdatum) + 1}` : `Geburtstag in ${plural(Math.round(ng.tage / 30.44), 'Monat', 'Monaten')}`, gebBald];
      const fakten = [
        R3(ctx) ? gebKachel : p.geburtsdatum ? [`${alter(p.geburtsdatum)}`, 'Jahre', `Geb. ${dmy(p.geburtsdatum)}`] : ['–', '', 'Geburtstag unbekannt'],
        p.austritt ? [faktDauer(p.eintritt, p.austritt), '', `${jahr(p.eintritt)}–${jahr(p.austritt)} dabei`] : [faktDauer(p.eintritt, heuteIso), '', `dabei seit ${dmy(p.eintritt)}`],
      ];
      return `${austrittsBanner(p)}
        ${faktKacheln(fakten)}
        ${p.haushalt.length ? `${sec('Familie im Stamm')}${familie(p, { chips: true })}` : ''}
        ${sec('Kontakt')}<div class="card">${kontaktListe(p, ctx, { icons: true, aktionen: true, zuerst: 1 })}</div>
        ${p.adressen.length ? `${sec('Adresse')}${adressKarte(p, ctx, {})}` : ''}
        ${sec('Details')}<div class="card zwei">${R3(ctx) ? '' : persoenlichZeilen(p, false, { ohneAlter: true, konfession: !R2(ctx) })}${mitgliedschaftsZeilen(p, false, { ohneDauer: true })}</div>`;
    }
    return `${austrittsBanner(p)}${AKTIONEN(p)}
      ${sec('Persönliche Daten')}<div class="card">${persoenlichZeilen(p, false, { konfession: !R2(ctx) })}</div>
      ${sec('Kontakt')}<div class="card">${kontaktListe(p, ctx, { zuerst: 1 })}</div>
      ${p.adressen.length ? `${sec('Adresse')}${adressKarte(p, ctx, {})}` : ''}
      ${p.haushalt.length ? `${sec('Familie')}${familie(p)}` : ''}
      ${sec('Mitgliedschaft')}<div class="card">${mitgliedschaftsZeilen(p, false)}</div>`;
  }

  // ------------------------------------------------------------- Rollen
  function rollenZeile(r, { kompakt = false, layerChip = true } = {}) {
    const fremd = r.layer !== D.AKTIVER_LAYER;
    const chip = layerChip && fremd ? `<span class="lchip">${esc(r.layer.split(' ')[0])}</span>` : '';
    if (kompakt) {
      return `<div class="rz kompakt ${r.status}">${rollenIcon(r, 22)}<div class="rz-t"><b>${esc(rollenTitel(r))}</b></div><span class="rz-z">${zeitraum(r, true)}</span></div>`;
    }
    return `<div class="rz ${r.status}">${rollenIcon(r, 32)}<div class="rz-t"><b>${esc(rollenTitel(r))}${chip}</b><small>${esc(rollenOrt(r))}</small><small class="zeit">${zeitraum(r)}</small></div></div>`;
  }
  function historieHinweis(ctx) {
    return ctx.historie ? '' : `<div class="leer klein">${ico('clock', 15)}Frühere Rollen liefert Hitobito noch nicht.</div>`;
  }
  function rollenListe(p, ctx) {
    const v = ctx.rollen || 'R1';
    const rollen = sortiere(rollenVon(p, ctx));
    const aktiv = rollen.filter((r) => r.status === 'aktiv');
    const zukunft = rollen.filter((r) => r.status === 'zukunft');
    const vergangen = rollen.filter((r) => r.status === 'vergangen');
    if (v === 'R2') {
      const layer = [...new Set(rollen.map((r) => r.layer))].sort((a, b) => (a === D.AKTIVER_LAYER ? -1 : b === D.AKTIVER_LAYER ? 1 : 0));
      return layer.map((l) => {
        const rs = rollen.filter((r) => r.layer === l);
        const jetzt = rs.filter((r) => r.status !== 'vergangen');
        const frueher = rs.filter((r) => r.status === 'vergangen');
        let html = jetzt.map((r) => rollenZeile(r, { layerChip: false })).join('');
        if (frueher.length) {
          html += ctx.offen || !jetzt.length
            ? `<div class="sub">Früher</div>${frueher.map((r) => rollenZeile(r, { kompakt: true })).join('')}`
            : aufklapp(plural(frueher.length, 'frühere Rolle', 'frühere Rollen'), false);
        }
        return `${sec(esc(l), l === D.AKTIVER_LAYER ? '' : 'anderer Layer')}<div class="card">${html}</div>`;
      }).join('') + historieHinweis(ctx);
    }
    if (v === 'R3') return R2(ctx) ? zeitstrahl2(p, ctx, rollen) : zeitstrahl(p, ctx, rollen);
    let html = '';
    if (zukunft.length) html += `${sec('Zukünftig', zukunft.length)}<div class="card">${zukunft.map((r) => rollenZeile(r)).join('')}</div>`;
    html += aktiv.length ? `${sec('Aktiv', aktiv.length)}<div class="card">${aktiv.map((r) => rollenZeile(r)).join('')}</div>` : `${sec('Aktiv')}<div class="card"><div class="leer">Keine aktive Rolle</div></div>`;
    if (vergangen.length) {
      html += `${sec('Vergangen', vergangen.length)}<div class="card">${ctx.offen || !aktiv.length ? vergangen.map((r) => rollenZeile(r, { kompakt: true })).join('') : aufklapp(`${plural(vergangen.length, 'vergangene Rolle', 'vergangene Rollen')} anzeigen`, false)}</div>`;
    }
    return html + historieHinweis(ctx);
  }
  function zeitstrahl(p, ctx, rollen) {
    // Ereignisse: Beginn jeder Rolle, Ende vergangener Rollen werden im Zeitraum genannt.
    const nachJahr = new Map();
    for (const r of rollen) {
      const j = r.status === 'zukunft' ? 'Geplant' : jahr(r.start);
      if (!nachJahr.has(j)) nachJahr.set(j, []);
      nachJahr.get(j).push(r);
    }
    const reihen = [...nachJahr.entries()].sort((a, b) => (a[0] === 'Geplant' ? -1 : b[0] === 'Geplant' ? 1 : b[0] - a[0]));
    const begrenzt = ctx.offen ? reihen : reihen.slice(0, 5);
    let html = begrenzt.map(([j, rs], i) => `<div class="zs ${j === 'Geplant' ? 'plan' : ''}"><span class="zs-j">${j}</span><span class="zs-l${i === begrenzt.length - 1 ? ' ende' : ''}"></span><div class="zs-e">${rs.map((r) => `<div class="zs-r ${r.status}">${rollenIcon(r, 24)}<div><b>${esc(rollenTitel(r))}${r.layer !== D.AKTIVER_LAYER ? `<span class="lchip">${esc(r.layer.split(' ')[0])}</span>` : ''}</b><small>${esc(r.gruppe)} · ${r.status === 'vergangen' ? `bis ${my(r.ende)}` : r.status === 'aktiv' ? 'aktiv' : `ab ${my(r.start)}`}</small></div></div>`).join('')}</div></div>`).join('');
    if (!ctx.offen && reihen.length > 5) html += aufklapp(`${reihen.length - 5} frühere Jahre anzeigen`, false);
    html += `<div class="zs eintritt"><span class="zs-j">${jahr(p.eintritt)}</span><span class="zs-l ende"></span><div class="zs-e"><small>Eintritt in die DPSG</small></div></div>`;
    return `${sec('Rollen', rollen.length)}<div class="card">${html}</div>${historieHinweis(ctx)}`;
  }

  // Runde 2: Zeitstrahl mit Layer-Filter (F1 Umschalter, F2 Hinweis am Ende)
  // und Hervorhebung aktiver Rollen (H1 getönte Zeile, H2 gefüllte Punkte, H3 Block „Jetzt“).
  function zeitstrahl2(p, ctx, alle) {
    const fremd = alle.filter((r) => r.layer !== D.AKTIVER_LAYER);
    const nurAktiv = ctx.layerFilter === 'aktiv' && fremd.length > 0;
    const rollen = nurAktiv ? alle.filter((r) => r.layer === D.AKTIVER_LAYER) : alle;
    const h = ctx.hervor || 'H1';
    const f = ctx.filterUi || 'F1';
    const zeit = (r) => (r.status === 'vergangen' ? (!r.ohneStart && jahr(r.start) === jahr(r.ende) ? `${MONATE[+r.start.slice(5, 7) - 1]} – ${my(r.ende)}` : `${r.ohneStart ? '?' : my(r.start)} – ${my(r.ende)}`) : r.status === 'aktiv' ? (r.ohneStart ? 'aktiv' : `aktiv seit ${my(r.start)}`) : `ab ${my(r.start)}`);
    const eintrag = (r) => `<div class="zs-r ${r.status}">${rollenIcon(r, 24)}<div><b>${esc(rollenTitel(r))}${r.layer !== D.AKTIVER_LAYER ? `<span class="lchip">${esc(r.layer.split(' ')[0])}</span>` : ''}</b><small>${esc(r.gruppe)} · ${zeit(r)}</small></div></div>`;
    let jetzt = '';
    let strahl = rollen;
    if (h === 'H3') {
      const oben = rollen.filter((r) => r.status !== 'vergangen').sort((a, b) => (a.status === 'zukunft' ? -1 : b.status === 'zukunft' ? 1 : t(b.start) - t(a.start)));
      strahl = rollen.filter((r) => r.status === 'vergangen');
      jetzt = oben.length ? `<div class="card jetzt">${oben.map(eintrag).join('')}</div>` : '';
    }
    const nachJahr = new Map();
    for (const r of strahl) {
      const j = r.status === 'zukunft' ? 'Geplant' : jahr(r.start);
      if (!nachJahr.has(j)) nachJahr.set(j, []);
      nachJahr.get(j).push(r);
    }
    const reihen = [...nachJahr.entries()].sort((a, b) => (a[0] === 'Geplant' ? -1 : b[0] === 'Geplant' ? 1 : b[0] - a[0]));
    const grenze = h === 'H3' ? 4 : 5;
    const begrenzt = ctx.offen ? reihen : reihen.slice(0, grenze);
    let html = begrenzt.map(([j, rs], i) => `<div class="zs ${j === 'Geplant' ? 'plan' : ''} ${rs.some((r) => r.status === 'aktiv') ? 'hat-aktiv' : ''}"><span class="zs-j">${j}</span><span class="zs-l${i === begrenzt.length - 1 && !reihen.length ? ' ende' : ''}"></span><div class="zs-e">${rs.map(eintrag).join('')}</div></div>`).join('');
    if (!ctx.offen && reihen.length > grenze) html += `<div class="zs mehrzeile"><span></span><span class="zs-l"></span>${aufklapp(`${reihen.length - grenze} frühere Jahre anzeigen`, false)}</div>`;
    html += `<div class="zs eintritt"><span class="zs-j">${jahr(p.eintritt)}</span><span class="zs-l ende"></span><div class="zs-e"><small>Eintritt in die DPSG</small></div></div>`;
    const anzahl = nurAktiv ? `${rollen.length} (${alle.length - rollen.length} ausgeblendet)` : alle.length;
    let filterOben = '';
    let filterUnten = '';
    if (fremd.length && f === 'F1') {
      filterOben = `<div class="segf"><span class="${nurAktiv ? 'on' : ''}">${esc(D.AKTIVER_LAYER)}</span><span class="${nurAktiv ? '' : 'on'}">Alle Layer</span></div>`;
    } else if (fremd.length && f === 'F2') {
      const ebenen = [...new Set(fremd.map((r) => r.layer.split(' ')[0]))].join(' und ');
      filterUnten = nurAktiv
        ? `<div class="filterzeile">${ico('people', 15)}<span>${plural(fremd.length, 'Rolle', 'Rollen')} aus ${esc(ebenen)} ausgeblendet</span><u>Anzeigen</u></div>`
        : `<div class="filterzeile">${ico('people', 15)}<span>Alle Layer</span><u>Nur ${esc(D.AKTIVER_LAYER)}</u></div>`;
    }
    const titel = h === 'H3' ? `${sec('Rollen', anzahl)}${filterOben}${jetzt}${strahl.length ? sec('Früher') : ''}` : `${sec('Rollen', anzahl)}${filterOben}`;
    const strahlKarte = strahl.length || h !== 'H3' ? `<div class="card zstrahl ${h.toLowerCase()}">${html}${filterUnten}</div>` : `<div class="card zstrahl">${html}${filterUnten}</div>`;
    return `${titel}${strahlKarte}${historieHinweis(ctx)}`;
  }

  // ------------------------------------------------------------- Verlauf
  function intervalle(p, ctx) {
    const ende = (r) => (r.ende && t(r.ende) < HEUTE ? t(r.ende) : HEUTE);
    return rollenVon(p, ctx).filter((r) => r.status !== 'zukunft').map((r) => ({ ...r, a: t(r.start), b: ende(r) }));
  }
  function vereinigt(iv) {
    const s = [...iv].sort((x, y) => x.a - y.a);
    let summe = 0; let cur = null;
    for (const x of s) {
      if (!cur || x.a > cur.b) { if (cur) summe += cur.b - cur.a; cur = { a: x.a, b: x.b }; } else cur.b = Math.max(cur.b, x.b);
    }
    if (cur) summe += cur.b - cur.a;
    return summe / (365.25 * TAG);
  }
  function kennzahlen(p, ctx) {
    const iv = intervalle(p, ctx);
    const leitJahre = vereinigt(iv.filter((x) => x.art === 'l'));
    const stufenM = [...new Set(iv.filter((x) => x.art === 'm' && x.stufe).map((x) => x.stufe))];
    const ende = p.austritt || heuteIso;
    return { iv, leitJahre, stufenM, dabei: dauer(p.eintritt, ende), dabeiKurz: dauer(p.eintritt, ende, true), jung: (t(ende) - t(p.eintritt)) / TAG < 180 };
  }
  function packen(segmente) {
    // Überlappende Segmente auf Unterzeilen verteilen (gierig).
    const reihen = [];
    for (const s of [...segmente].sort((x, y) => x.a - y.a)) {
      let i = reihen.findIndex((ende) => ende <= s.a);
      if (i < 0) { i = reihen.length; reihen.push(0); }
      reihen[i] = s.b;
      s.reihe = i;
    }
    return Math.max(1, reihen.length);
  }
  function achse(von, bis) {
    const j0 = new Date(von).getUTCFullYear();
    const j1 = new Date(bis).getUTCFullYear();
    const span = j1 - j0;
    const schritt = span > 14 ? 5 : span > 6 ? 2 : 1;
    const ticks = [];
    for (let j = Math.ceil(j0 / schritt) * schritt; j <= j1; j += schritt) ticks.push(j);
    return ticks;
  }
  function verlaufKopf(p, k) {
    const leit = k.leitJahre >= 1 ? ` · davon ${Math.round(k.leitJahre)} J. Leitung` : k.leitJahre > 0 ? ' · Leitung seit Kurzem' : '';
    const titel = p.austritt ? `${k.dabei} dabei gewesen` : `Seit ${k.dabei} dabei`;
    return `<div class="vk"><b>${titel}</b><small>${jahr(p.eintritt)}–${p.austritt ? jahr(p.austritt) : 'heute'}${leit}</small></div>`;
  }
  function neulingKarte(p, k) {
    const r = p.rollen.find((x) => x.stufe) || {};
    return `<div class="card vl neu">${r.stufe ? maskottchen(r.stufe, 40) : ''}<div><b>Seit ${k.dabei} dabei</b><small>Der Pfadfinder-Verlauf wächst mit jeder Stufe.</small></div></div>`;
  }
  function verlauf(p, ctx) {
    const v = ctx.verlauf || 'V1';
    const k = kennzahlen(p, ctx);
    if (v === 'K1' || v === 'K2') return verlaufKombi(p, ctx, k, v);
    if (k.jung) return neulingKarte(p, k);
    if (v === 'V3') return verlaufZahlen(p, ctx, k);
    if (v === 'V2') return verlaufTreppe(p, ctx, k);
    return verlaufBand(p, ctx, k);
  }
  function luecke(p, ctx, k, x, von) {
    // Ohne Historie: Zeit vor der ersten bekannten Rolle als „früher, unbekannt“ markieren.
    if (ctx.historie || !k.iv.length) return null;
    const erste = Math.min(...k.iv.map((s) => s.a));
    const a = t(p.eintritt);
    return erste - a > 180 * TAG ? { a, b: erste } : null;
  }
  function verlaufBand(p, ctx, k, { nurDiagramm = false } = {}) {
    const W = 326; const LAB = 54; const PW = W - LAB; const H = 14; const G = 3;
    const von = t(p.eintritt); const bis = p.austritt ? t(p.austritt) : HEUTE;
    const x = (d) => LAB + ((d - von) / (bis - von || 1)) * PW;
    const bahnen = [
      { id: 'm', name: 'Mitglied', segs: k.iv.filter((s) => s.art === 'm') },
      { id: 'l', name: 'Leitung', segs: k.iv.filter((s) => s.art === 'l') },
      { id: 's', name: 'Ämter', segs: k.iv.filter((s) => s.art === 's') },
    ].filter((b) => b.segs.length);
    const lu = luecke(p, ctx, k, x, von);
    let y = 4; let svg = '';
    for (const b of bahnen) {
      const n = packen(b.segs);
      const hb = n * H + (n - 1) * 2;
      svg += `<text class="t-lab" x="0" y="${y + hb / 2 + 4}">${b.name}</text>`;
      if (lu) svg += `<rect x="${x(lu.a)}" y="${y}" width="${Math.max(2, x(lu.b) - x(lu.a) - 2)}" height="${hb}" rx="4" fill="url(#schraffur-${ctx.modus})"/>`;
      for (const s of b.segs) {
        const sx = x(s.a); const sw = Math.max(6, x(s.b) - sx - 2); const sy = y + s.reihe * (H + 2);
        const farbe = s.stufe && b.id !== 's' ? `var(--st-${s.stufe})` : 'var(--amt)';
        const kurz = s.stufe && b.id !== 's' ? D.stufen[s.stufe].kurz : '';
        const tip = `${rollenTitel(s)} · ${s.gruppe} · ${jahr(s.start)}–${s.status === 'aktiv' ? 'heute' : jahr(s.ende)}`;
        svg += `<g><title>${esc(tip)}</title><rect x="${sx}" y="${sy}" width="${sw}" height="${H}" rx="4" fill="${farbe}" ${s.stufe === 'biber' ? 'stroke="var(--biber-ring-stark)" stroke-width="1"' : ''}/>`;
        // Kürzel als zweite Codierung (Pfadi-Grün/Rover-Rot sind bei Rot-Grün-Schwäche kaum trennbar).
        const text = kurz && (sw >= kurz.length * 5.6 + 6 ? kurz : sw >= 11 && !R2(ctx) ? kurz[0] : '');
        if (text) svg += `<text class="t-in" x="${sx + sw / 2}" y="${sy + 10.5}" text-anchor="middle" fill="${s.stufe === 'biber' ? '#1c1c1e' : '#fff'}">${text}</text>`;
        svg += '</g>';
      }
      y += hb + G + 6;
    }
    const ticks = achse(von, bis);
    const tickSvg = ticks.map((j) => { const tx = x(Date.UTC(j, 0, 1)); return tx < LAB - 1 ? '' : `<line x1="${tx}" x2="${tx}" y1="0" y2="${y - 4}" class="gl"/><text class="t-axis" x="${tx}" y="${y + 9}" text-anchor="middle">${j}</text>`; }).join('');
    const hoehe = y + 14;
    const defs = `<defs><pattern id="schraffur-${ctx.modus}" width="6" height="6" patternUnits="userSpaceOnUse" patternTransform="rotate(45)"><rect width="6" height="6" fill="var(--surface2)"/><line x1="0" y1="0" x2="0" y2="6" stroke="var(--border)" stroke-width="3"/></pattern></defs>`;
    const fuss = lu ? `<div class="foot muted"><span class="band schraffur"></span>früher, noch nicht abrufbar</div>` : '';
    const diagramm = `<svg class="viz" width="${W}" height="${hoehe}" viewBox="0 0 ${W} ${hoehe}">${defs}${tickSvg}${svg}</svg>${fuss}`;
    if (nurDiagramm) return diagramm;
    return `<div class="card vl">${verlaufKopf(p, k)}${diagramm}</div>`;
  }
  function verlaufTreppe(p, ctx, k) {
    // Je Stufe und Art eine Zeile, auf gemeinsamer Zeitachse; ergibt die Treppe.
    const W = 326; const LAB = 96; const DUR = 34; const PW = W - LAB - DUR; const H = 10; const RH = 22;
    const von = t(p.eintritt); const bis = p.austritt ? t(p.austritt) : HEUTE;
    const x = (d) => LAB + ((d - von) / (bis - von || 1)) * PW;
    const gruppen = new Map();
    for (const s of k.iv) {
      const key = s.art === 's' ? 's' : `${s.art}-${s.stufe}`;
      if (!gruppen.has(key)) gruppen.set(key, []);
      gruppen.get(key).push(s);
    }
    const zeilen = [...gruppen.entries()].map(([key, segs]) => ({ key, segs, a: Math.min(...segs.map((s) => s.a)) })).sort((a, b) => a.a - b.a);
    let svg = ''; let y = 0;
    for (const z of zeilen) {
      const s0 = z.segs[0];
      const ist = z.key === 's';
      const name = ist ? `Ämter (${z.segs.length})` : s0.art === 'l' ? `Leitung ${D.stufen[s0.stufe].kurz}` : D.stufen[s0.stufe].name;
      const farbe = ist ? 'var(--amt)' : `var(--st-${s0.stufe})`;
      const jahre = vereinigt(z.segs);
      const aktiv = z.segs.some((s) => s.status === 'aktiv');
      svg += `<text class="t-lab" x="0" y="${y + 14}">${esc(name)}</text>`;
      for (const s of z.segs) {
        const sx = x(s.a); const sw = Math.max(3, x(s.b) - sx - 2);
        svg += `<g><title>${esc(`${rollenTitel(s)} · ${jahr(s.start)}–${s.status === 'aktiv' ? 'heute' : jahr(s.ende)}`)}</title><rect x="${sx}" y="${y + 6}" width="${sw}" height="${H}" rx="4" fill="${farbe}" ${s0.stufe === 'biber' && !ist ? 'stroke="var(--biber-ring-stark)"' : ''}/></g>`;
      }
      svg += `<text class="t-val" x="${W}" y="${y + 14}" text-anchor="end">${jahre < 1 ? '<1' : Math.round(jahre)} J.${aktiv ? '' : ''}</text>`;
      y += RH;
    }
    const lu = luecke(p, ctx, k, x, von);
    if (lu) svg = `<rect x="${x(lu.a)}" y="0" width="${x(lu.b) - x(lu.a) - 2}" height="${y}" rx="4" fill="url(#schraffur2-${ctx.modus})" opacity=".8"/>` + svg;
    const ticks = achse(von, bis);
    const tickSvg = ticks.map((j) => { const tx = x(Date.UTC(j, 0, 1)); return tx < LAB - 1 ? '' : `<line x1="${tx}" x2="${tx}" y1="0" y2="${y}" class="gl"/><text class="t-axis" x="${tx}" y="${y + 11}" text-anchor="middle">${j}</text>`; }).join('');
    const defs = `<defs><pattern id="schraffur2-${ctx.modus}" width="6" height="6" patternUnits="userSpaceOnUse" patternTransform="rotate(45)"><rect width="6" height="6" fill="var(--surface2)"/><line x1="0" y1="0" x2="0" y2="6" stroke="var(--border)" stroke-width="3"/></pattern></defs>`;
    const fuss = lu ? `<div class="foot muted"><span class="band schraffur"></span>früher, noch nicht abrufbar</div>` : '';
    return `<div class="card vl">${verlaufKopf(p, k)}<svg class="viz" width="${W}" height="${y + 16}" viewBox="0 0 ${W} ${y + 16}">${defs}${tickSvg}${svg}</svg>${fuss}</div>`;
  }
  function verlaufZahlen(p, ctx, k) {
    const alleStufen = ['woe', 'jufi', 'pfadi', 'rover'];
    const leitStufen = [...new Set(k.iv.filter((s) => s.art === 'l' && s.stufe).map((s) => s.stufe))];
    const kacheln = [
      [k.dabeiKurz, p.austritt ? 'dabei gewesen' : 'dabei', `seit ${jahr(p.eintritt)}`],
      zweite || [k.leitJahre >= 1 ? `${Math.round(k.leitJahre)} J.` : k.leitJahre > 0 ? '<1 J.' : '–', 'in der Leitung', leitStufen.length ? leitStufen.map((s) => D.stufen[s].kurz).join(', ') : 'noch nicht'],
      [`${k.stufenM.filter((s) => alleStufen.includes(s)).length}/4`, 'Stufen', ctx.historie ? 'durchlaufen' : 'bekannt'],
    ];
    const pfad = alleStufen.map((s) => {
      const segs = k.iv.filter((x) => x.art === 'm' && x.stufe === s);
      const j = segs.length ? vereinigt(segs) : 0;
      const aktiv = segs.some((x) => x.status === 'aktiv');
      return `<span class="pstep ${segs.length ? '' : 'leer'}" style="--c:var(--st-${s})"><i></i>${D.stufen[s].kurz}<small>${segs.length ? (aktiv ? 'jetzt' : `${j < 1 ? '<1' : Math.round(j)} J.`) : '–'}</small></span>`;
    }).join('<span class="pfeil">›</span>');
    return `<div class="card vl"><div class="stats">${kacheln.map(([w, l, s]) => `<div class="stat"><div class="stat-val">${esc(w)}</div><div class="stat-lab">${esc(l)}</div><div class="stat-sub">${esc(s)}</div></div>`).join('')}</div><div class="pfadzeile">${pfad}</div>${ctx.historie ? '' : '<div class="foot muted">Frühere Stufen erscheinen, sobald Hitobito sie liefert.</div>'}</div>`;
  }
  // Runde 2: erst Kennzahlen (aus V3), dann Bahnen (V1). K1 in einer Karte, K2 Kacheln frei darüber.
  function kennKacheln(p, ctx, k) {
    const leitStufen = [...new Set(k.iv.filter((s) => s.art === 'l' && s.stufe).map((s) => s.stufe))];
    const stufen = k.stufenM.filter((s) => ['woe', 'jufi', 'pfadi', 'rover'].includes(s)).length;
    const zweite = R3(ctx) && k.leitJahre === 0 ? stufenwechselKachel(p, ctx) : null;
    return [
      [faktDauer(p.eintritt, p.austritt || heuteIso), p.austritt ? 'dabei gewesen' : 'dabei', p.austritt ? `${jahr(p.eintritt)}–${jahr(p.austritt)}` : `seit ${jahr(p.eintritt)}`],
      zweite || [k.leitJahre >= 1 ? `${Math.round(k.leitJahre)} J.` : k.leitJahre > 0 ? '<1 J.' : '–', 'in der Leitung', leitStufen.length ? leitStufen.map((s) => D.stufen[s].kurz).join(', ') : 'noch nicht'],
      [`${stufen}/4`, 'Stufen', ctx.historie ? 'durchlaufen' : 'bekannt'],
    ].map(([w, l, s]) => `<div class="stat"><div class="stat-val">${esc(w)}</div><div class="stat-lab">${esc(l)}</div><div class="stat-sub">${esc(s)}</div></div>`).join('');
  }
  // Nächster Stufenwechsel wie ErmittleStufenwechselVorschlaegeUseCase: fällig ab Geburtsjahr + Mindestalter der Zielstufe.
  function stufenwechselKachel(p, ctx) {
    if (!p.geburtsdatum || p.austritt) return null;
    if (R4(ctx)) return stufenwechselKachel4(p);
    const aktiv = p.rollen.filter((r) => status(r) === 'aktiv' && r.art === 'm' && r.stufe);
    if (!aktiv.length) return null;
    const st = aktiv.sort((a, b) => RANG[a.stufe] - RANG[b.stufe])[0].stufe;
    const gebJahr = Number(jahr(p.geburtsdatum));
    const jetzt = Number(heuteIso.slice(0, 4));
    if (st === 'rover') {
      const ende = gebJahr + ROVER_MAX;
      return [String(ende), 'Ende Roverzeit', 'mit 20 Jahren'];
    }
    const ziel = NAECHSTE[st];
    if (aktiv.some((r) => r.stufe === ziel)) return ['läuft', 'Wechsel', `zu ${ZIELNAME[ziel]}`];
    const faellig = gebJahr + ALTER_MIN[ziel];
    if (faellig <= jetzt) return ['jetzt', 'Wechsel möglich', `zu ${ZIELNAME[ziel]}`];
    return [String(faellig), 'nächster Wechsel', `zu ${ZIELNAME[ziel]}`];
  }
  // Runde 4: maßgeblich ist die höchste aktive Mitgliedsstufe; kein Zustand „läuft“.
  // fällig ab = Geburtsjahr + Mindestalter Zielstufe, spätestens = Geburtsjahr + Höchstalter aktuelle Stufe.
  function stufenwechselKachel4(p) {
    const aktiv = p.rollen.filter((r) => status(r) === 'aktiv' && r.art === 'm' && r.stufe);
    if (!aktiv.length) return null;
    const st = aktiv.sort((a, b) => RANG[b.stufe] - RANG[a.stufe])[0].stufe;
    const gebJahr = Number(jahr(p.geburtsdatum));
    const jetzt = Number(heuteIso.slice(0, 4));
    const spaetestens = gebJahr + ALTER_MAX[st];
    if (st === 'rover') return [spaetestens < jetzt ? 'jetzt' : `bis ${spaetestens}`, 'Ende Roverzeit', 'mit 20 Jahren'];
    const ziel = NAECHSTE[st];
    const ab = gebJahr + ALTER_MIN[ziel];
    const wert = spaetestens < jetzt ? 'jetzt' : ab > jetzt ? `ab ${ab}` : `bis ${spaetestens}`;
    return [wert, 'Stufenwechsel', `zu ${ZIELNAME[ziel]}`];
  }
  function verlaufKombi(p, ctx, k, v) {
    const diagramm = k.jung ? '<div class="foot muted">Der Verlauf wächst mit jeder Stufe.</div>' : verlaufBand(p, ctx, k, { nurDiagramm: true });
    if (v === 'K2') return `<div class="stats frei">${kennKacheln(p, ctx, k)}</div><div class="card vl">${diagramm}</div>`;
    return `<div class="card vl"><div class="stats">${kennKacheln(p, ctx, k)}</div><div class="trenn"></div>${diagramm}</div>`;
  }
  function rollenTab(p, ctx) {
    return `${sec('Pfadfinder-Verlauf')}${verlauf(p, ctx)}${rollenListe(p, ctx)}`;
  }

  // ------------------------------------------------------------- Qualifikationen
  function efzInfo(efz, ctx = {}) {
    const z = ctx.efzZustand || efz.status;
    switch (z) {
      case 'gueltig': return { ton: 'gut', kurz: 'gültig', pill: 'Gültig', zeile: `Gültig bis ${dmy(efz.bis)}`, detail: R2(ctx) ? '' : `ausgestellt ${dmy(efz.ausgestellt)} · eingesehen ${dmy(efz.eingesehen)}`, icon: 'shield' };
      case 'bald': return { ton: 'warn', kurz: 'läuft ab', pill: 'Läuft bald ab', zeile: `Gültig bis ${dmy(efz.bis)}`, detail: R2(ctx) ? `noch ${dauer(heuteIso, efz.bis)}` : `noch ${dauer(heuteIso, efz.bis)} · eingesehen ${dmy(efz.eingesehen)}`, icon: 'shield' };
      case 'abgelaufen': return { ton: 'schlecht', kurz: 'abgelaufen', pill: 'Abgelaufen', zeile: `Abgelaufen am ${dmy(efz.bis)}`, detail: R2(ctx) ? '' : `ausgestellt ${dmy(efz.ausgestellt)}`, icon: 'shield' };
      case 'unbekannt': return { ton: 'leise', kurz: '?', pill: '', zeile: 'Noch nicht synchronisiert', detail: 'Wird beim nächsten Abgleich geladen', icon: 'clock' };
      case 'verboten': return { ton: 'leise', kurz: '–', pill: '', zeile: 'Keine Berechtigung', detail: 'Nur Erfasser*innen Führungszeugnis sehen den Status', icon: 'lock' };
      default: return { ton: 'neutral', kurz: 'keines', pill: '', zeile: 'Keines hinterlegt', detail: '', icon: 'shield' };
    }
  }
  const pill = (ton, text) => (text ? `<span class="spill ${ton}">${text}</span>` : '');
  function efzZeile(p, ctx) {
    const v = ctx.efz || 'E1';
    const i = efzInfo(p.efz, ctx);
    const darfLaden = !['verboten'].includes(ctx.efzZustand || p.efz.status);
    if (v === 'E2') {
      const knopf = R3(ctx) && darfLaden ? `<span class="rund" title="Antragsunterlagen herunterladen">${ico('download', 17)}</span>` : '';
      return `<div class="card efz e2"><div class="zl"><span class="dotbig ${i.ton}"></span><div class="zl-t"><div class="zl-l oben">Erweitertes Führungszeugnis</div><div class="zl-w">${i.zeile}</div>${i.detail ? `<div class="zl-l">${i.detail}</div>` : ''}</div>${knopf}</div>${darfLaden && !R3(ctx) ? `<div class="linkzeile">${ico('download', 17)}Antragsunterlagen herunterladen</div>` : ''}</div>`;
    }
    if (v === 'E3') {
      const knapp = i.ton === 'gut' || i.ton === 'warn' ? i.zeile.replace('Gültig bis', 'bis') : i.zeile;
      const p3 = i.ton === 'warn' ? pill('warn', 'bald') : '';
      return `<div class="card efz e3"><div class="zl"><span class="zl-i">${ico(i.icon, 19, i.ton)}</span><div class="zl-t"><div class="zl-w">EFZ <span class="leise-t ${i.ton === 'schlecht' ? 'rot' : ''}">· ${knapp}</span></div></div>${p3}${darfLaden ? `<span class="rund klein" title="Antragsunterlagen herunterladen">${ico('download', 15)}</span>` : ''}</div></div>`;
    }
    return `<div class="card efz e1"><div class="zl"><span class="zl-i">${ico(i.icon, 20, i.ton)}</span><div class="zl-t"><div class="zl-w">Erweitertes Führungszeugnis</div><div class="zl-l">${i.zeile}</div>${i.detail ? `<div class="zl-l klein">${i.detail}</div>` : ''}</div>${pill(i.ton, i.pill)}${darfLaden ? `<span class="rund" title="Antragsunterlagen herunterladen">${ico('download', 17)}</span>` : ''}</div></div>`;
  }
  function qualiStatus(q) {
    if (!q.bis) return { ton: 'neutral', text: `erworben ${dmy(q.am)} · ohne Ablauf`, pill: '' };
    const rest = (t(q.bis) - HEUTE) / TAG;
    if (rest < 0) return { ton: 'schlecht', text: `abgelaufen ${dmy(q.bis)}${q.reaktivierbar ? ' · reaktivierbar' : ''}`, pill: 'Abgelaufen', alt: true };
    if (rest <= 90) return { ton: 'warn', text: `gültig bis ${dmy(q.bis)}`, pill: 'Läuft bald ab' };
    return { ton: 'gut', text: `gültig bis ${dmy(q.bis)}`, pill: 'Gültig' };
  }
  function qualiListe(p, ctx) {
    const v = ctx.efz || 'E1';
    if (ctx.qualiZustand === 'unbekannt') return `${sec('Qualifikationen')}<div class="card"><div class="leer">${ico('clock', 16)}Noch nicht synchronisiert</div></div>`;
    if (!p.qualis.length) return `${sec('Qualifikationen')}<div class="card"><div class="leer">Keine Qualifikationen hinterlegt</div></div>`;
    const qs = p.qualis.map((q) => ({ ...q, s: qualiStatus(q) })).sort((a, b) => (a.s.alt ? 1 : 0) - (b.s.alt ? 1 : 0) || t(b.am) - t(a.am));
    const z = (q) => {
      if (v === 'E2') return `<div class="zl ${q.s.alt ? 'blass' : ''}"><span class="dotbig ${q.s.ton}"></span><div class="zl-t"><div class="zl-w">${esc(q.label)}</div><div class="zl-l">${q.s.text}</div></div></div>`;
      if (v === 'E3') return `<div class="zl ${q.s.alt ? 'blass' : ''}"><span class="zl-i">${ico('award', 19, q.s.ton)}</span><div class="zl-t"><div class="zl-w">${esc(q.label)} <span class="leise-t">· ${q.s.text}</span></div></div></div>`;
      return `<div class="zl ${q.s.alt ? 'blass' : ''}"><span class="zl-i">${ico('award', 20, 'muted')}</span><div class="zl-t"><div class="zl-w">${esc(q.label)}</div><div class="zl-l">${q.s.text}</div></div>${q.s.ton !== 'gut' ? pill(q.s.ton, q.s.pill) : ''}</div>`;
    };
    return `${sec('Qualifikationen', qs.length)}<div class="card">${qs.map(z).join('')}</div>`;
  }
  function qualiTab(p, ctx) {
    return `${sec('Führungszeugnis')}${efzZeile(p, ctx)}${qualiListe(p, ctx)}`;
  }

  // ------------------------------------------------------------- Ganze Seiten
  function seite(p, ctx, tab) {
    if (tab === 1) return rollenTab(p, ctx);
    if (tab === 2) return qualiTab(p, ctx);
    return datenTab(p, ctx);
  }
  function ankerSeite(p, ctx, ab) {
    const teile = [
      `<h2 class="anker-h">Daten</h2>${datenTab(p, ctx)}`,
      `<h2 class="anker-h">Rollen</h2>${rollenTab(p, ctx)}`,
      `<h2 class="anker-h">Qualifikationen</h2>${qualiTab(p, ctx)}`,
    ];
    return teile.slice(ab).join('');
  }
  function bildschirm(p, ctx, struktur, tab, opts) {
    const k = kopf(ctx, p, struktur, tab);
    const inhalt = struktur === 'S3' ? ankerSeite(p, ctx, tab) : seite(p, ctx, tab);
    return telefon(ctx, k, inhalt, opts);
  }

  window.MBAU = {
    esc, ico, telefon, panel, naechsterGeburtstag, kopf, seite, bildschirm, datenTab, rollenTab, qualiTab,
    adressKarte, karte, verlauf, rollenListe, efzZeile, qualiListe, sec, TABS,
  };
})();

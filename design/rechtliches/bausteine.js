// Bausteine der Entwürfe zu Impressum, Datenschutz, Einwilligungen und Kartenquellen.
// ctx = { modus: 'hell'|'dunkel', plattform?: 'ios'|'android' }
// Alle Daten sind synthetisch.
(function () {
  const M = window.MITGLIED;
  const L = window.LILIE;
  const esc = (s) => String(s ?? '').replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));

  // ------------------------------------------------------------- Farben
  const zusatz = {
    hell: { '--dlg': '#ffffff', '--wd-bg': '#eef0f4', '--map-bg': '#edf0e9', '--map-road': '#ffffff', '--map-water': '#d3e2ee', '--map-park': '#dbe8d2', '--map-bau': '#e2e2dc' },
    dunkel: { '--dlg': '#24242e', '--wd-bg': '#15151b', '--map-bg': '#1c2320', '--map-road': '#2c3531', '--map-water': '#1d2e3b', '--map-park': '#1f2d22', '--map-bau': '#252b28' },
  };
  function farbenEinfuegen() {
    let css = '';
    for (const modus of ['hell', 'dunkel']) {
      const p = M.palette[modus];
      const vars = { '--bg': p.bg, '--surface': p.surface, '--surface2': p.surface2, '--fg': p.fg, '--fg2': p.fg2, '--muted': p.muted, '--border': p.border,
        '--primary': p.primary, '--on-primary': p.onPrimary, '--primary-lite': p.primaryLite, '--grid': p.grid, '--success': p.success, '--error': p.error, '--warn': p.warn, ...zusatz[modus] };
      css += `.phone.${modus},.mpanel.${modus}{${Object.entries(vars).map(([k, v]) => `${k}:${v}`).join(';')}}`;
    }
    document.head.insertAdjacentHTML('beforeend', `<style>${css}</style>`);
  }

  // ------------------------------------------------------------- Icons
  const PFADE = {
    back: 'M19 12H5M11 6l-6 6 6 6',
    right: 'M9 6l6 6-6 6',
    down: 'M6 9l6 6 6-6',
    up: 'M6 15l6-6 6 6',
    mail: 'M3 6h18v12H3zM3 7l9 6 9-6',
    shield: 'M12 3l8 3v6c0 5-3.5 8-8 9-4.5-1-8-4-8-9V6z',
    shieldCheck: 'M12 3l8 3v6c0 5-3.5 8-8 9-4.5-1-8-4-8-9V6zM9 12l2 2 4-4',
    user: 'M12 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8zM4 21a8 8 0 0 1 16 0',
    server: 'M4 4h16v6H4zM4 14h16v6H4zM8 7h.01M8 17h.01',
    chart: 'M5 20V11M11 20V5M17 20v-6M3 20h18',
    chat: 'M4 5h16v11H9l-5 4z',
    pin: 'M12 21s-7-6.2-7-11.5a7 7 0 0 1 14 0C19 14.8 12 21 12 21zM12 7.5a2.5 2.5 0 1 0 0 5 2.5 2.5 0 0 0 0-5',
    map: 'M9 4 3 6v14l6-2 6 2 6-2V4l-6 2zM9 4v14M15 6v14',
    layers: 'M12 3l9 5-9 5-9-5zM3 13l9 5 9-5',
    download: 'M12 4v11M7 10l5 5 5-5M5 20h14',
    search: 'M11 4a7 7 0 1 0 0 14 7 7 0 0 0 0-14zM20 20l-4-4',
    lock: 'M6 11h12v9H6zM8.5 11V8a3.5 3.5 0 0 1 7 0v3',
    device: 'M8 3h8a1 1 0 0 1 1 1v16a1 1 0 0 1-1 1H8a1 1 0 0 1-1-1V4a1 1 0 0 1 1-1zM11 18h2',
    copy: 'M9 9h11v11H9zM5 15H4V4h11v1',
    ext: 'M14 4h6v6M20 4l-9 9M18 14v6H4V6h6',
    star: 'M12 3.5l2.6 5.3 5.9.9-4.3 4.1 1 5.8-5.2-2.7-5.2 2.7 1-5.8-4.3-4.1 5.9-.9z',
    check: 'M5 12l5 5 9-10',
    x: 'M6 6l12 12M18 6 6 18',
    clock: 'M12 3a9 9 0 1 0 0 18 9 9 0 0 0 0-18zM12 7v5l3 2',
    info: 'M12 3a9 9 0 1 0 0 18 9 9 0 0 0 0-18zM12 11v6M12 7.5h.01',
    doc: 'M6 3h9l4 4v14H6zM14 3v5h5M9 13h7M9 17h7',
    scale: 'M12 4v16M7 20h10M5 7h14M5 7l-3 6a3 3 0 0 0 6 0zM19 7l-3 6a3 3 0 0 0 6 0z',
    globe: 'M12 3a9 9 0 1 0 0 18 9 9 0 0 0 0-18zM3 12h18M12 3c3 3.5 3 14.5 0 18M12 3c-3 3.5-3 14.5 0 18',
    crosshair: 'M12 2v4M12 18v4M2 12h4M18 12h4M12 7a5 5 0 1 0 0 10 5 5 0 0 0 0-10z',
    send: 'M4 12l16-8-6 16-3-7z',
    building: 'M4 21V8l8-5 8 5v13M9 21v-6h6v6',
    pen: 'M4 20l4-1 11-11-3-3L5 16zM14 6l3 3',
    camera: 'M4 8h4l2-3h4l2 3h4v11H4zM12 10a3.5 3.5 0 1 0 0 7 3.5 3.5 0 0 0 0-7',
    eyeOff: 'M3 3l18 18M10.6 6.1A9.7 9.7 0 0 1 12 6c5 0 9 6 9 6a16 16 0 0 1-2.6 3.2M6.3 7.6C4.2 9.2 3 12 3 12s4 6 9 6a8.6 8.6 0 0 0 4.1-1M9.9 10a3 3 0 0 0 4.1 4.1',
    gavel: 'M14 4l6 6M11 7l6 6M12.5 5.5l-5 5M18.5 11.5l-5 5M10 13l-7 7',
    heart: 'M12 20s-7-4.4-7-10a4 4 0 0 1 7-2.6A4 4 0 0 1 19 10c0 5.6-7 10-7 10z',
    forum: 'M3 5h12v8H7l-4 3zM9 15v2h8l4 3V9h-4',
    fire: 'M12 21a6 6 0 0 0 6-6c0-4-3-6-4-9-1 2-2 3-3 3 0-2-1-4-2-5-1 4-3 6-3 11a6 6 0 0 0 6 6z',
    edit: 'M4 20h4L19 9l-4-4L4 16zM4 6h6M4 10h3',
    insights: 'M4 18l5-6 4 3 7-8M17 7h3v3',
    palette: 'M12 3a9 9 0 0 0 0 18c1.5 0 2-1 2-2s-1-1.5-1-2.5S14 15 15 15h2a4 4 0 0 0 4-4c0-4.4-4-8-9-8zM7.5 11h.01M10 7.5h.01M14.5 7.5h.01',
    bell: 'M6 16V11a6 6 0 1 1 12 0v5l2 2H4zM10 20a2 2 0 0 0 4 0',
    apps: 'M4 4h6v6H4zM14 4h6v6h-6zM4 14h6v6H4zM14 14h6v6h-6z',
    bug: 'M8 9h8v7a4 4 0 0 1-8 0zM9 9a3 3 0 0 1 6 0M4 13h4M16 13h4M5 8l3 2M19 8l-3 2M5 19l3-2M19 19l-3-2',
    users: 'M9 11a3.5 3.5 0 1 0 0-7 3.5 3.5 0 0 0 0 7zM2.5 20a6.5 6.5 0 0 1 13 0M16 4.5a3.5 3.5 0 0 1 0 6.5M18 14a6 6 0 0 1 3.5 6',
    trash: 'M4 7h16M9 7V4h6v3M6 7l1 13h10l1-13',
    sparkle: 'M12 3l1.8 5.2L19 10l-5.2 1.8L12 17l-1.8-5.2L5 10l5.2-1.8z',
    id: 'M3 5h18v14H3zM7 15h4M7 11h10',
    award: 'M12 3a6 6 0 1 0 0 12 6 6 0 0 0 0-12zM8.5 14 7 21l5-3 5 3-1.5-7',
    sync: 'M20 12a8 8 0 1 1-2.3-5.6M20 4v5h-5',
    face: 'M4 8V5a1 1 0 0 1 1-1h3M16 4h3a1 1 0 0 1 1 1v3M20 16v3a1 1 0 0 1-1 1h-3M8 20H5a1 1 0 0 1-1-1v-3M9 9.5v1M15 9.5v1M12 9.5v3.5h-1M9.5 16a3.5 3.5 0 0 0 5 0',
    swap: 'M7 4v13M3 13l4 4 4-4M17 20V7M13 11l4-4 4 4',
  };
  const ico = (name, size = 20, cls = '') => `<svg class="ico ${cls}" width="${size}" height="${size}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="${PFADE[name]}"/></svg>`;
  const lilie = (size, farbe) => `<svg class="lilie" width="${size}" height="${size}" viewBox="${L.viewBox}" aria-hidden="true"><g transform="${L.transform}"><path d="${L.d}" fill="${farbe}"/></g></svg>`;
  const sec = (x) => `<div class="sec">${x}</div>`;
  const quad = (icon, farbe, cls = '', size = 18) => `<span class="r-quad ${cls}" style="--c:${farbe}">${ico(icon, size)}</span>`;
  const sw = (an) => `<span class="r-sw${an ? ' on' : ''}"></span>`;
  const OFFEN = '<span class="r-offen">Angabe folgt</span>';

  // ------------------------------------------------------------- Rahmen
  function statusLeiste(ctx) {
    return `<div class="status"><span>9:41</span><i class="island"></i><span class="sys"></span></div>`;
  }
  function telefon(ctx, kopfHtml, inhalt, { shot, beschriftung = '', overlay = '', lang = false, falz = false, tabbar = true, bodyCls = '' } = {}) {
    const android = ctx.plattform === 'android';
    return `<figure class="phone ${ctx.modus}" data-shot="${esc(shot)}">
      <div class="screen${lang ? ' lang' : ' fest'}${android ? ' android' : ''}">
        ${statusLeiste(ctx)}
        ${kopfHtml}
        <div class="body ${bodyCls}">${inhalt}</div>
        ${tabbar === true ? '<nav class="tabbar"><span>Mitglieder</span><span>Statistik</span><span>Stufenwechsel</span><span class="on">Einstellungen</span></nav>' : tabbar || ''}
        ${overlay}
        ${lang && falz ? '<i class="falz"><span>Ende 1. Bildschirm</span></i>' : ''}
      </div>
      ${beschriftung ? `<figcaption>${beschriftung}</figcaption>` : ''}
    </figure>`;
  }
  function panel(ctx, inhalt, { shot, titel = '' } = {}) {
    return `<figure class="mpanel ${ctx.modus}" data-shot="${esc(shot)}">
      ${titel ? `<figcaption>${titel}</figcaption>` : ''}<div class="mpanel-in">${inhalt}</div></figure>`;
  }
  const kopf = (titel, rechts = '') => `<header class="ab"><div class="k-row">${ico('back', 22)}<div class="k-t"><b>${esc(titel)}</b></div>${rechts}</div></header>`;
  const kopfOhne = (titel, rechts = '') => `<header class="ab"><div class="k-row" style="padding-left:10px"><div class="k-t"><b style="font-size:22px">${esc(titel)}</b></div>${rechts}</div></header>`;

  // ------------------------------------------------------------- Empfänger
  const WANN = {
    login: ['immer', 'bei der Anmeldung'],
    nutzung: ['immer', 'beim Laden'],
    einw: ['einw', 'nur mit Einwilligung'],
    teils: ['einw', 'teils mit Einwilligung'],
    aktion: ['aktion', 'nur auf deine Aktion'],
  };
  const wann = (w) => `<span class="r-wann ${WANN[w][0]}">${WANN[w][1]}</span>`;
  const EMPF = [
    { id: 'hitobito', name: 'Hitobito (DPSG)', kurz: 'Anmeldung und Mitgliederdaten', icon: 'building', farbe: 'var(--primary)', wann: 'login',
      zweck: 'Anmeldung und Abruf der Mitgliederdaten, die du in Hitobito sehen darfst. Änderungen schreibt die App dorthin zurück.',
      daten: 'Zugangsdaten, Mitgliederdaten im Rahmen deiner Rechte',
      grundlage: 'deine Mitgliedschaft bzw. dein Amt in der DPSG',
      dauer: 'nach den Regeln der DPSG',
      hinweis: 'Für die Mitgliederdaten ist die DPSG verantwortlich. Es gilt das kirchliche Datenschutzrecht (KDG).' },
    { id: 'statistik', name: 'Statistikserver der App', kurz: 'Bundesweiter Vergleich', icon: 'chart', farbe: '#00823c', wann: 'einw',
      zweck: 'Zählwerte deines Stammes für den bundesweiten Vergleich.',
      daten: 'Anzahlen je Gruppe. Stamm, Gruppen und Installation pseudonym, Bezirks- und Diözesannummer im Klartext. Keine Speicherung der IP&#8209;Adresse.',
      grundlage: 'Einwilligung je Stamm, jederzeit widerrufbar',
      dauer: '14 Monate, Backups 14 Tage',
      hinweis: 'Auskunft oder Löschung: Mail an dev@jannecklange.de mit deiner Installations-ID (steht im Bundesvergleich).' },
    { id: 'wiredash', name: 'Wiredash', kurz: 'Feedback und Nutzungsanalyse', icon: 'chat', farbe: '#AF52DE', wann: 'teils',
      zweck: 'Feedback und Zufriedenheitsumfrage, wenn du sie abschickst. Nutzungsereignisse und Fehlerberichte nur mit Einwilligung.',
      daten: 'Technischer Ping mit App-Version, Gerät und Sprache',
      grundlage: 'Einwilligung bzw. eigene Aktion; Ping: berechtigtes Interesse',
      dauer: 'beim Anbieter nach dessen Regeln' },
    { id: 'geoapify', name: 'Geoapify', kurz: 'Adressen auf der Karte', icon: 'pin', farbe: '#FF9500', wann: 'nutzung',
      zweck: 'Wandelt Adressen in Koordinaten für Karten und die Standorte-Statistik.',
      daten: 'Nur der Adresstext, ohne Namen',
      grundlage: 'berechtigtes Interesse',
      dauer: 'Koordinaten auf dem Gerät bis zum Abmelden, beim Anbieter nach dessen Regeln' },
    { id: 'kacheln', name: 'Kartenkacheln', kurz: 'MapTiler bzw. OpenStreetMap', icon: 'layers', farbe: '#30B0C7', wann: 'nutzung',
      zweck: 'Lädt die Kartenbilder.', daten: 'IP&#8209;Adresse beim Laden', grundlage: 'berechtigtes Interesse', dauer: 'beim Anbieter nach dessen Regeln, Kacheln zwischengespeichert' },
    { id: 'github', name: 'GitHub', kurz: 'Update-Hinweis und Mitteilungen', icon: 'download', farbe: '#8E8E93', wann: 'nutzung',
      zweck: 'Prüft auf neue Versionen und lädt Mitteilungen.', daten: 'IP&#8209;Adresse', grundlage: 'berechtigtes Interesse', dauer: 'bei GitHub nach dessen Regeln' },
    { id: 'dpsg', name: 'DPSG-Stammessuche', kurz: 'tools.dpsg.de, Stammeskarte', icon: 'map', farbe: '#cc1f2f', wann: 'nutzung',
      zweck: 'Lädt die Stämme für die Stammeskarte.', daten: 'IP&#8209;Adresse', grundlage: 'berechtigtes Interesse', dauer: 'bei der DPSG nach deren Regeln' },
    { id: 'logmail', name: 'Log-Mail an den Entwickler', kurz: 'Hilfe bei der Fehlersuche', icon: 'send', farbe: '#007AFF', wann: 'aktion',
      zweck: 'Hilft bei der Fehlersuche.', daten: 'App-Protokolle, die du selbst per Mail verschickst', grundlage: 'eigene Aktion', dauer: 'bis die Fehlersuche abgeschlossen ist' },
  ];
  const empf = (id) => EMPF.find((e) => e.id === id);
  const RECHTE = ['Auskunft', 'Berichtigung', 'Löschung', 'Einschränkung', 'Widerspruch', 'Widerruf von Einwilligungen', 'Beschwerde bei einer Aufsichtsbehörde'];

  function anbieterKarte(kompakt = false) {
    return `<div class="card r-pad"><div class="r-anb${kompakt ? ' kompakt' : ''}"><span class="r-av">JL</span><div><b>Janneck Lange</b><span class="r-link">${ico('mail', 15)}dev@jannecklange.de</span></div></div>
      <div class="r-privat">${ico('info', 16)}<span>Privates Projekt. Nicht von der DPSG betrieben oder autorisiert.</span></div></div>`;
  }
  const kvListe = (e) => `<dl class="r-kv"><dt>Zweck</dt><dd>${e.zweck}</dd><dt>Daten</dt><dd>${e.daten}</dd><dt>Grundlage</dt><dd>${e.grundlage}</dd><dt>Speicherdauer</dt><dd>${e.dauer}</dd></dl>`;
  const geraetKarte = () => `<div class="card r-pad"><div class="r-anb">${quad('lock', 'var(--primary)', 'gross', 19)}<div class="r-text">Mitgliederdaten liegen verschlüsselt auf deinem Gerät und werden beim Abmelden gelöscht.</div></div></div>`;
  const rechteKarte = () => `<div class="card r-pad"><div class="r-text">Du kannst jederzeit verlangen:</div>
      <div class="r-rechte">${RECHTE.map((r) => `<span>${r}</span>`).join('')}</div>
      <div class="r-text" style="margin-top:10px">Schreib an <span class="r-link">dev@jannecklange.de</span>. Für Mitgliederdaten in Hitobito ist die DPSG zuständig.</div></div>`;
  const quellenKarte = () => `<div class="card r-zeilen"><div class="r-quellen">Kartendaten ©&nbsp;OpenStreetMap-Mitwirkende · Karten ©&nbsp;MapTiler · Adresssuche ©&nbsp;Geoapify</div>
      <div class="r-zeile">${quad('doc', '#8E8E93', 'klein', 15)}<span>Open-Source-Lizenzen</span>${ico('right', 18)}</div></div>`;
  const webLink = () => `<div class="card r-zeilen"><div class="r-zeile link">${ico('doc', 19)}<span>Ausführliche Datenschutzerklärung</span>${ico('ext', 17)}</div></div>`;

  function seiteD1(ctx, { offen = 'statistik' } = {}) {
    const zeilen = EMPF.map((e) => {
      const auf = e.id === offen;
      return `<div class="r-ez">${quad(e.icon, e.farbe)}<div><b>${e.name}</b><small class="r-ez-u">${wann(e.wann)}<span>${e.kurz}</span></small></div>${ico(auf ? 'up' : 'down', 18)}</div>
        ${auf ? `<div class="r-ez-auf">${kvListe(e)}${e.hinweis ? `<div class="r-hin">${e.hinweis}</div>` : ''}</div>` : ''}`;
    }).join('');
    return `<div style="height:14px"></div>${anbieterKarte()}
      ${sec('Welche Daten gehen wohin')}<div class="card r-emp">${zeilen}</div>
      ${sec('Auf deinem Gerät')}${geraetKarte()}
      ${sec('Deine Rechte')}${rechteKarte()}
      ${sec('Quellen')}${quellenKarte()}
      <div style="height:16px"></div>${webLink()}
      <div class="r-stand">Stand: Oktober 2026</div>`;
  }

  function seiteD2(ctx) {
    return `<div style="height:14px"></div>${anbieterKarte(true)}${d2Rest(ctx)}`;
  }
  function d2Rest(ctx) {
    const kacheln = EMPF.map((e) => `<div class="r-k">${quad(e.icon, e.farbe, 'klein', 16)}<b>${e.name}</b><small>${e.kurz}</small>${wann(e.wann)}</div>`).join('');
    return `${sec('Welche Daten gehen wohin')}<div class="r-sec-u">Antippen für Zweck, Rechtsgrundlage und Speicherdauer.</div>
      <div class="r-kach">${kacheln}</div>
      <div style="height:16px"></div>
      <div class="card r-zeilen">
        <div class="r-zeile">${quad('lock', 'var(--primary)', 'klein', 15)}<span>Auf deinem Gerät</span>${ico('right', 18)}</div>
        <div class="r-zeile">${quad('scale', '#5856D6', 'klein', 15)}<span>Deine Rechte</span>${ico('right', 18)}</div>
        <div class="r-zeile">${quad('map', '#30B0C7', 'klein', 15)}<span>Quellen</span>${ico('right', 18)}</div>
        <div class="r-zeile">${quad('doc', '#8E8E93', 'klein', 15)}<span>Open-Source-Lizenzen</span>${ico('right', 18)}</div>
      </div>
      <div style="height:16px"></div>${webLink()}`;
  }
  function sheetD2(ctx, id = 'statistik') {
    const e = empf(id);
    return `<div class="r-sheet-bg"></div><div class="r-sheet"><i class="r-griff"></i>
      <div class="r-sheet-k">${quad(e.icon, e.farbe, 'gross', 20)}<div><b>${e.name}</b><small>${WANN[e.wann][1]}</small></div></div>
      <div class="r-feld"><small>Zweck</small><div>${e.zweck}</div></div>
      <div class="r-feld"><small>Welche Daten</small><div>${e.daten}</div></div>
      <div class="r-feld"><small>Rechtsgrundlage</small><div>${e.grundlage}</div></div>
      <div class="r-feld"><small>Speicherdauer</small><div>${e.dauer}</div></div>
      ${e.hinweis ? `<div class="r-box">${e.hinweis}</div>` : ''}
      ${id === 'statistik' ? `<div class="r-knopfreihe"><span class="r-btn tonal">${ico('copy', 16)}ID kopieren</span><span class="r-btn filled">${ico('mail', 16)}Mail schreiben</span></div>` : ''}
    </div>`;
  }

  const KURZ = [
      ['lock', 'Mitgliederdaten kommen aus Hitobito und liegen verschlüsselt nur auf deinem Gerät.'],
      ['shieldCheck', 'Statistik und Nutzungsanalyse gibt es nur mit deiner Einwilligung.'],
      ['send', 'Feedback und Log-Mails gehen nur raus, wenn du sie abschickst.'],
      ['globe', 'Karten und Update-Hinweise laden Daten von Anbietern; dabei wird deine IP&#8209;Adresse übertragen.'],
      ['mail', 'Fragen, Auskunft, Löschung: <span class="r-link">dev@jannecklange.de</span>'],
    ];
  function seiteD3(ctx) {
    const zeilen = EMPF.map((e) => `<tr><td><b>${e.name}</b><small>${e.kurz}</small><div class="r-tab-z">${wann(e.wann)}<small>${e.grundlage.replace(/;.*$/, '').replace(/^deine /, '')}</small></div></td><td>${e.dauer === OFFEN ? '<span class="r-offen">folgt</span>' : e.id === 'statistik' ? '14 Monate' : e.id === 'hitobito' ? 'DPSG' : 'beim Anbieter'}</td></tr>`).join('');
    return `<div style="height:14px"></div>
      <div class="card r-kurz"><h4>Kurz gesagt</h4>${KURZ.map(([i, t]) => `<div class="r-kp">${ico(i, 17)}<span>${t}</span></div>`).join('')}</div>
      ${sec('Anbieter')}<div class="card r-pad"><div class="r-text"><b>Janneck Lange</b> · <span class="r-link">dev@jannecklange.de</span></div><div class="r-klein" style="margin-top:4px">Privates Projekt. Nicht von der DPSG betrieben oder autorisiert.</div></div>
      ${sec('Welche Daten gehen wohin')}<div class="card r-pad" style="padding:6px 10px 10px"><table class="r-tab"><tr><th>Empfänger, Wann, Grundlage</th><th style="text-align:right">Dauer</th></tr>${zeilen}</table></div>
      <div class="r-sec-u" style="margin-top:8px">Hitobito: Verantwortlich für Mitgliederdaten ist die DPSG (KDG). Statistikserver: keine IP-Speicherung, Backups 14 Tage, Löschung auf Anfrage mit Installations-ID.</div>
      ${sec('Deine Rechte')}${rechteKarte()}
      ${sec('Quellen')}${quellenKarte()}
      <div style="height:16px"></div>${webLink()}`;
  }

  // ------------------------------------------------------------- Einstellungen
  function einstellungen(ctx, variante) {
    const zeile = (icon, farbe, titel, sub, cls = '') => `<div class="r-setz ${cls}">${quad(icon, farbe, 'gross', 20)}<div><b>${titel}</b>${sub ? `<small>${sub}</small>` : ''}</div>${ico('right', 20)}</div>`;
    const oben = `${sec('Einstellungen')}<div class="r-set">
        ${zeile('building', 'var(--primary)', 'Stammeseinstellungen', 'Daten, Altersgrenzen')}
        ${zeile('apps', '#007AFF', 'App-Einstellungen', 'Sicherheit, Sprache, Verhalten')}
        ${zeile('palette', '#AF52DE', 'Erscheinungsbild', 'Design, Farben, App-Icon, Badge')}
        ${zeile('bell', '#FF9500', 'Benachrichtigungen', 'Geburtstage, Erinnerungen')}</div>
      ${sec('Entwicklung')}<div class="r-set">${zeile('bug', '#8E8E93', 'Debug & Tools', 'Fehlerberichte, Cache, Tools')}</div>`;
    const fuss = (mitLink) => `<div class="r-fuss">Entwickelt mit <span class="herz">♥</span> in Hamburg<small>Version 1.0.0 (412)</small>${mitLink ? '<div style="margin-top:8px"><span class="r-link">Impressum & Datenschutz</span></div>' : ''}</div>`;
    if (variante === 'E1') {
      return `${oben}${sec('Rechtliches')}<div class="r-set">${zeile('shield', '#8E8E93', 'Impressum & Datenschutz', 'Anbieter, Daten, deine Rechte', 'neu')}</div>${fuss(false)}`;
    }
    return `${oben}${fuss(true)}`;
  }

  // ------------------------------------------------------------- Hintergründe
  function mitgliederliste(ctx) {
    const P = [['LB', 'Lena Brandt', 'Leiterin · Trupp Kompass'], ['TK', 'Tom Krüger', 'Wölfling · Meute Seeonee'], ['MA', 'Mira Aydın', 'Pfadfinderin · Trupp Polarstern'], ['JS', 'Jonas Schmitt', 'Rover · Runde Fernweh'], ['EW', 'Ella Wagner', 'Biber · Biberbau'], ['NH', 'Noah Hoffmann', 'Jungpfadfinder · Trupp Kompass'], ['SR', 'Sophie Richter', 'Leiterin · Meute Seeonee'], ['FB', 'Finn Becker', 'Pfadfinder · Trupp Polarstern'], ['LM', 'Lea Meyer', 'Wölfling · Meute Seeonee'], ['PZ', 'Paul Zimmermann', 'Rover · Runde Fernweh']];
    return `<div class="r-suche" style="position:static;margin:12px 0 10px;box-shadow:none">${ico('search', 18)}Mitglieder suchen</div>
      <div class="r-set">${P.map(([k, n, s]) => `<div class="r-setz"><span class="av">${k}</span><div><b>${n}</b><small>${s}</small></div></div>`).join('')}</div>`;
  }
  const tabbarMitglieder = '<nav class="tabbar"><span class="on">Mitglieder</span><span>Statistik</span><span>Stufenwechsel</span><span>Einstellungen</span></nav>';

  // ------------------------------------------------------------- Willkommen
  const analyseOpt = () => `<div class="r-opt"><div><b>Nutzungsanalyse</b><small>Nutzungsereignisse und Fehlerberichte an Wiredash senden. Jederzeit in den Einstellungen änderbar.</small></div>${sw(false)}</div>`;
  function willkommen(ctx, variante) {
    if (variante === 'W1') {
      return `<div class="r-dim"></div><div class="r-dlg">
        <div class="r-dlg-ico">${lilie(40, 'var(--primary)')}</div>
        <h3 style="text-align:center">Willkommen!</h3>
        <div class="r-text">Schön, dass du da bist. Deine Mitgliederdaten kommen aus Hitobito und bleiben verschlüsselt auf diesem Gerät.</div>
        ${analyseOpt()}
        <span class="r-linkzeile">${ico('shield', 16)}Impressum & Datenschutz${ico('right', 15)}</span>
        <div class="r-akt"><span class="r-btn filled">Los geht’s</span></div>
      </div>`;
    }
    return `<div class="r-dim"></div><div class="r-bs">
      <div class="r-bs-logo">${lilie(34, '#ffffff')}</div>
      <h3>Willkommen!</h3>
      <div class="r-text" style="color:var(--fg2)">Schön, dass du da bist. Kurz zum Datenschutz:</div>
      <div style="margin-top:10px">
        <div class="r-pkt info">${ico('lock', 19)}<span>Mitgliederdaten kommen aus Hitobito und bleiben verschlüsselt auf diesem Gerät.</span></div>
        <div class="r-pkt info">${ico('shieldCheck', 19)}<span>Statistik und Analyse nur, wenn du zustimmst.</span></div>
      </div>
      ${analyseOpt()}
      <div style="text-align:center"><span class="r-linkzeile">Impressum & Datenschutz${ico('right', 15)}</span></div>
      <div style="margin-top:16px"><span class="r-btn filled breit">Los geht’s</span></div>
    </div>`;
  }

  // ------------------------------------------------------------- Feedback
  function feedbackDialog(ctx, variante) {
    const text = 'Du nutzt die App jetzt seit einer Weile. Was läuft gut, was fehlt dir? Dein Feedback hilft, sie weiter zu verbessern.';
    if (variante === 'I1') {
      return `<div class="r-dim"></div><div class="r-dlg"><h3>Wie gefällt dir die App?</h3><div class="r-text">${text}</div>
        <div class="r-akt"><span class="r-btn text">Später</span><span class="r-btn filled">Feedback geben</span></div></div>`;
    }
    const textA = 'Du nutzt die App jetzt seit einer Weile. Dein Feedback hilft, sie weiter zu verbessern – und eine Bewertung im Play Store hilft anderen Leitenden, die App zu finden.';
    if (variante === 'G1') {
      return `<div class="r-dim"></div><div class="r-dlg"><h3>Wie gefällt dir die App?</h3><div class="r-text">${textA}</div>
        <div class="r-akt" style="gap:0"><span class="r-btn text">Später</span><span class="r-btn text">Feedback geben</span><span class="r-btn filled" style="margin-left:6px">App bewerten</span></div></div>`;
    }
    return `<div class="r-dim"></div><div class="r-dlg"><h3>Wie gefällt dir die App?</h3><div class="r-text">${textA}</div>
      <div class="r-akt gestapelt"><span class="r-btn filled breit">${ico('star', 17)}App bewerten</span><span class="r-btn tonal breit">${ico('chat', 17)}Feedback geben</span><span class="r-btn text breit">Später</span></div></div>`;
  }
  function iosReview(ctx) {
    const stern = ico('star', 30);
    return `<div class="r-dim" style="background:rgba(0,0,0,.25)"></div><div class="r-ios"><div class="r-ios-in">
      <div class="r-ios-icon">${lilie(36, '#ffffff')}</div>
      <b>Gefällt dir NaMi?</b><p>Tippe auf einen Stern, um sie im App Store zu bewerten.</p>
      <div class="r-sterne">${stern.repeat(5)}</div></div>
      <div class="r-ios-btn">Nicht jetzt</div></div>`;
  }
  function playReview(ctx) {
    return `<div class="r-dim"></div><div class="r-play">
      <div class="r-play-k"><span class="r-ios-icon">${lilie(26, '#ffffff')}</span><div><b>NaMi</b><small>Janneck Lange</small></div></div>
      <h4>App bewerten</h4><div class="r-klein">Bewertungen sind öffentlich und enthalten deine Kontoinformationen.</div>
      <div class="r-sterne" style="margin-top:16px">${ico('star', 36).repeat(5)}</div>
      <div class="r-akt"><span class="r-btn text">Nicht jetzt</span><span class="r-btn filled" style="opacity:.45">Senden</span></div></div>`;
  }

  // Abzeichen im Stil von AchievementBadge: gesperrt grau, einmaliger Erfolg blau mit gewelltem Goldrand.
  function abzeichen(ctx, icon, erreicht, size = 72) {
    const r = size / 2;
    const hell = ctx.modus === 'hell';
    const n = 14;
    const punkte = [];
    for (let i = 0; i < n * 8; i++) {
      const w = (i / (n * 8)) * Math.PI * 2;
      const rr = r * (0.94 + 0.05 * Math.cos(w * n));
      punkte.push(`${(r + rr * Math.cos(w)).toFixed(2)},${(r + rr * Math.sin(w)).toFixed(2)}`);
    }
    const gid = `g${Math.random().toString(36).slice(2, 8)}`;
    const disc = erreicht ? `url(#${gid})` : hell ? '#e8e8ed' : '#24242d';
    const rand = erreicht ? '#E6B422' : hell ? '#d6d6dd' : '#3a3a46';
    const motiv = erreicht ? '#ffffff' : hell ? '#b2b2ba' : '#5e5e6c';
    const is = size * 0.42;
    return `<svg width="${size}" height="${size}" viewBox="0 0 ${size} ${size}" aria-hidden="true">
      <defs><linearGradient id="${gid}" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#2F6FA8"/><stop offset=".55" stop-color="#0B4A7F"/><stop offset="1" stop-color="#002544"/></linearGradient></defs>
      ${erreicht ? `<polygon points="${punkte.join(' ')}" fill="${rand}" stroke="#94690B" stroke-width="1"/>` : `<circle cx="${r}" cy="${r}" r="${r * 0.96}" fill="${rand}"/>`}
      <circle cx="${r}" cy="${r}" r="${r * 0.8}" fill="${disc}"/>
      <circle cx="${r}" cy="${r}" r="${r * 0.7}" fill="none" stroke="${erreicht ? 'rgba(255,255,255,.35)' : motiv}" stroke-opacity="${erreicht ? 1 : 0.5}" stroke-width="1" stroke-dasharray="2.5 2.5"/>
      <g transform="translate(${r - is / 2} ${r - is / 2}) scale(${is / 24})"><path d="${PFADE[icon]}" fill="${erreicht && icon === 'star' ? motiv : 'none'}" stroke="${motiv}" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></g>
    </svg>`;
  }
  function erfolge(ctx, { bewertung = null, hinweis = false, mitgestalten = 'erreicht', hinweisMit = false } = {}) {
    // bewertung: null (Android, keine Kachel), 'offen', 'erreicht'
    const ios = ctx.plattform !== 'android';
    const zellen = [];
    if (ios && bewertung) {
      const erreicht = bewertung === 'erreicht';
      zellen.push(`<div class="r-abz${erreicht ? '' : ' offen'}${!erreicht && hinweis ? ' markiert' : ''}">${abzeichen(ctx, 'star', erreicht)}<b>App bewertet</b>${!erreicht && hinweis ? `<small>Jetzt bewerten${ico('ext', 11)}</small>` : ''}</div>`);
    }
    const mitOffen = mitgestalten === 'offen';
    zellen.push(`<div class="r-abz${mitOffen ? ' offen' : ''}${mitOffen && hinweisMit ? ' markiert' : ''}">${abzeichen(ctx, 'forum', !mitOffen)}<b>Mitgestalten</b>${mitOffen && hinweisMit ? `<small>Feedback geben${ico('ext', 11)}</small>` : ''}</div>`);
    const gesamt = ios ? 18 : 17;
    const erreichtN = 3 + (bewertung === 'erreicht' ? 1 : 0) + (mitOffen ? 0 : 1);
    return `<div class="r-erf-sum">${abzeichen({ modus: 'hell' }, mitOffen ? 'fire' : 'forum', true, 64)}<div style="flex:1"><b>${erreichtN} von ${gesamt} Erfolgen erreicht</b><small>Weiter so! Jeder Schritt zählt.</small><i style="--p:${Math.round((erreichtN / gesamt) * 100)}%"></i></div></div>
      ${sec('Stufen')}<div class="r-set">
        <div class="r-stufenz">${abzeichen(ctx, 'fire', false, 44)}<div><b>Immer dabei</b><small>An 3 Tagen die App geöffnet</small></div>${ico('right', 18, 'muted')}</div>
        <div class="r-stufenz">${abzeichen(ctx, 'edit', false, 44)}<div><b>Daten gepflegt</b><small>1 Mitglied bearbeitet</small></div>${ico('right', 18, 'muted')}</div>
        <div class="r-stufenz">${abzeichen(ctx, 'insights', false, 44)}<div><b>Statistik-Fan</b><small>10-mal die Statistik geöffnet</small></div>${ico('right', 18, 'muted')}</div></div>
      ${sec('Besondere')}<div class="r-abz-card">${zellen.join('')}</div>
      <div class="r-erf-hin">${ico('lock', 14)}Erfolge werden nur auf diesem Gerät gespeichert.</div>`;
  }
  function abzeichenSheet(ctx) {
    return `<div class="r-sheet-bg"></div><div class="r-sheet"><i class="r-griff"></i>
      <div class="r-abz-gross">${abzeichen(ctx, 'star', false, 96)}<b>App bewertet</b><span>Bewerte die App im App Store.</span></div>
      <div style="margin-top:18px"><span class="r-btn filled breit">${ico('ext', 17)}Im App Store bewerten</span></div>
      <div class="r-klein" style="text-align:center;margin-top:10px">Öffnet den App Store. Das Abzeichen gilt, sobald du dort warst.</div></div>`;
  }

  // ------------------------------------------------------------- Wiredash
  const WD_TEXTE = {
    T1: {
      de: ['Du kannst die App normal bedienen, bevor du einen Screenshot erstellst. <mark>Achte darauf, dass keine Mitgliederdaten zu sehen sind, oder übermale sie.</mark>'],
      en: ['You can use the app normally before taking a screenshot. <mark>Make sure no member data is visible, or paint over it.</mark>'],
    },
    T2: {
      de: ['Du kannst die App normal bedienen, bevor du einen Screenshot erstellst.'], hinDe: 'Mitgliederdaten vorher ausblenden oder im nächsten Schritt übermalen.',
      en: ['You can use the app normally before taking a screenshot.'], hinEn: 'Hide member data first or paint over it in the next step.',
    },
    T3: {
      de: ['Bediene die App bis zur passenden Stelle und erstelle dann den Screenshot. <mark>Bitte keine Namen oder Kontaktdaten von Mitgliedern im Bild – übermale sie mit dem Stift.</mark>'],
      en: ['Navigate to the right spot in the app, then take the screenshot. <mark>Please keep member names and contact details out of the picture – paint over them with the pen.</mark>'],
    },
  };
  function wiredash(ctx, variante, sprache = 'de') {
    const t = WD_TEXTE[variante];
    const absaetze = t[sprache].map((x) => `<p>${x.replace(/<\/?mark>/g, '')}</p>`).join('');
    const hin = sprache === 'de' ? t.hinDe : t.hinEn;
    const titel = sprache === 'de' ? 'Screenshots hinzufügen?' : 'Add screenshots?';
    const schritt = sprache === 'de' ? 'Schritt 3 von 5' : 'Step 3 of 5';
    const skip = sprache === 'de' ? 'Überspringen' : 'Skip';
    const add = sprache === 'de' ? 'Screenshot hinzufügen' : 'Add screenshot';
    return `<div class="r-wd-app"><div class="mini" style="padding:14px 16px">${mitgliederliste(ctx)}</div></div>
      <div class="r-wd-in"><div class="r-wd-schritt">${schritt}</div><h3>${titel}</h3>${absaetze}
        ${hin ? `<div class="r-wd-hin">${ico('eyeOff', 17)}<span>${hin}</span></div>` : ''}
        <div class="r-akt"><span class="r-btn outline">${skip}</span><span class="r-btn filled">${ico('camera', 16)}${add}</span></div></div>`;
  }
  function wiredashText(variante) {
    const t = WD_TEXTE[variante];
    const z = (spr) => t[spr].join(' ') + ((spr === 'de' ? t.hinDe : t.hinEn) ? ` <mark>${spr === 'de' ? t.hinDe : t.hinEn}</mark>` : '');
    return `<div class="r-wd-text"><b>Deutsch</b>${z('de')}</div><div class="r-wd-text"><b>Englisch</b>${z('en')}</div>`;
  }

  // ------------------------------------------------------------- Bundesstatistik
  const STAMM = 'Stamm St. Georg, Musterstadt';
  const stammChip = () => `<span class="r-stamm">${lilie(16, 'var(--primary)')}${STAMM}</span>`;
  function bundHintergrund(ctx) {
    return `<div style="height:14px"></div><div class="card r-pad"><div class="r-anb" style="align-items:center">${ico('globe', 22)}<b style="font-size:16px">Mit Stämmen bundesweit vergleichen</b></div>
      <div class="r-text" style="margin-top:8px;color:var(--fg2)">Teile die zusammengefassten Anzahlen deines Stammes und sieh im Gegenzug, wie sich Stufen, Leitende und Geschlechter bundesweit verteilen.</div>
      <div style="text-align:right;margin-top:12px"><span class="r-btn filled">${ico('check', 16)}Jetzt teilnehmen</span></div></div>`;
  }
  function einwilligung(ctx, variante, { mehr = false } = {}) {
    const akt = '<div class="r-akt"><span class="r-btn text">Abbrechen</span><span class="r-btn filled">Teilen aktivieren</span></div>';
    if (variante === 'B1') {
      return `<div class="r-dim"></div><div class="r-dlg oben" style="top:70px;padding:22px 22px 16px"><h3 style="margin-bottom:12px">Stammesdaten teilen?</h3>${stammChip()}
        <div class="r-text" style="font-size:13.5px">Für den bundesweiten Vergleich sendet die App etwa einmal pro Woche Zahlen dieses Stammes an den Statistikserver der App.</div>
        <div class="r-lab">Geteilt werden nur Anzahlen</div>
        <div class="r-li">Mitglieder und Leitende je Gruppe, nach Geschlecht</div>
        <div class="r-li">Leitende nach Altersgruppen, stammweit</div>
        <div class="r-li">Mitgliedschaftsarten</div>
        <div class="r-lab">Nicht geteilt</div>
        <div class="r-li">Namen, Geburtsdaten, Adressen, Kontaktdaten</div>
        <div class="r-li">deine Person und dein Hitobito-Zugang</div>
        <div class="r-box">Bezirks- und Diözesannummer im Klartext, Stamm, Gruppen und Installation pseudonym. Keine Speicherung der IP&#8209;Adresse, Löschung nach 14 Monaten.<br><b>Widerruf jederzeit</b> in den App-Einstellungen; er stoppt weitere Sendungen. Geteilte Zahlen löschen wir auf Anfrage.</div>
        <div class="r-klein" style="margin-top:10px">Verantwortlich: Janneck Lange · <span class="r-link">Impressum & Datenschutz</span></div>
        ${akt}</div>`;
    }
    const kurz = `<div class="r-pkt ja">${ico('check', 19)}<span>Nur Anzahlen je Gruppe nach Geschlecht, Leitende nach Altersgruppe</span></div>
      <div class="r-pkt nein">${ico('x', 19)}<span>Keine Namen, Geburtsdaten, Adressen oder Kontaktdaten</span></div>
      <div class="r-pkt info">${ico('clock', 19)}<span>Gelöscht nach 14 Monaten, Widerruf jederzeit</span></div>`;
    const details = `<div class="r-box" style="margin-top:6px">
        <b>Geteilt:</b> Mitglieder und Leitende je Gruppe nach Geschlecht, Leitende stammweit nach Altersgruppen, Mitgliedschaftsarten.<br>
        <b>Nicht geteilt:</b> deine Person und dein Hitobito-Zugang.<br>
        <b>Auf dem Server:</b> Bezirks- und Diözesannummer im Klartext, Stamm, Gruppen und Installation pseudonym, keine IP&#8209;Adresse.<br>
        <b>Widerruf</b> stoppt weitere Sendungen; geteilte Zahlen löschen wir auf Anfrage.</div>
      <div class="r-klein" style="margin-top:8px">Verantwortlich: Janneck Lange · <span class="r-link">Impressum & Datenschutz</span></div>`;
    return `<div class="r-dim"></div><div class="r-dlg${mehr ? ' oben' : ''}" style="${mehr ? 'top:90px;' : ''}padding:22px 22px 16px"><h3 style="margin-bottom:12px">Stammesdaten teilen?</h3>${stammChip()}
      <div class="r-text" style="font-size:13.5px;margin-bottom:6px">Etwa einmal pro Woche gehen Zahlen dieses Stammes an den Statistikserver der App.</div>
      ${kurz}
      ${mehr ? `<span class="r-mehr">Weniger anzeigen${ico('up', 16)}</span>${details}` : `<span class="r-mehr">Mehr erfahren${ico('down', 16)}</span>`}
      ${mehr ? '' : '<div class="r-klein" style="margin-top:6px">Verantwortlich: Janneck Lange · <span class="r-link">Impressum & Datenschutz</span></div>'}
      ${akt}</div>`;
  }
  function transparenz(ctx, variante) {
    const werte = [['Biber', 8], ['Wölflinge', 21], ['Jungpfadfinder', 17], ['Pfadfinder', 14], ['Rover', 9], ['Leitende', 16], ['Ordentliche Mitgliedschaften', 81], ['Sonstige Mitglieder', 4]];
    const fuss = 'Zusätzlich je Gruppe die Aufteilung nach Geschlecht und stammweit die Leitenden nach Altersgruppen. Stamm, Gruppen und Installation werden auf dem Server pseudonymisiert.';
    const idText = 'Für Auskunft oder Löschung schreib an <span class="r-link">dev@jannecklange.de</span> und nenne diese ID. Nach einem App-Reset ist die ID weg.';
    const einw = `<div class="card r-pad"><div class="r-swz"><div><b>Stammesdaten teilen</b><small>Aktiv seit 12.09.2026</small></div>${sw(true)}</div>
      <div class="r-klein" style="margin-top:8px">Geteilt werden nur zusammengefasste Anzahlen deines Stammes, keine Namen oder Einzeldaten. Ein Widerruf stoppt weitere Sendungen; geteilte Zahlen fallen nach zwei Monaten aus dem Vergleich und werden nach 14 Monaten gelöscht, auf Anfrage sofort.</div></div>`;
    const tabelle = werte.map(([l, w]) => `<div class="r-wz"><span>${l}</span><span>${w}</span></div>`).join('');
    let idTeil;
    if (variante === 'K1') {
      idTeil = `<div class="r-klein" style="margin-top:10px">${fuss}</div>
        <div class="r-id"><div><small>Installations-ID</small><code>q3Zk…9fA2</code></div><span class="r-copy">${ico('copy', 17)}</span></div>
        <div class="r-klein" style="margin-top:6px">${idText}</div>`;
    } else {
      idTeil = `<div class="r-klein" style="margin-top:10px">${fuss}</div>
        <div class="r-idbox"><div class="r-id"><div><small>Installations-ID</small><code>q3Zk…9fA2</code></div><span class="r-btn tonal" style="padding:7px 12px;font-size:13px">${ico('copy', 15)}Kopieren</span></div><p>${idText}</p></div>`;
    }
    return `<div style="height:14px"></div>${einw}<div style="height:14px"></div>
      <div class="card r-pad"><div class="r-stat-t">Was dein Stamm geteilt hat</div><div class="r-klein" style="margin-bottom:8px">Zuletzt gesendet am 05.10.2026, 18:12</div>${tabelle}${idTeil}</div>`;
  }

  // ------------------------------------------------------------- Karten
  function karteSvg(b, h, { marker = 'adresse' } = {}) {
    const lilienPunkte = [[0.22, 0.28], [0.55, 0.2], [0.7, 0.45], [0.35, 0.55], [0.82, 0.68], [0.15, 0.72], [0.5, 0.82], [0.62, 0.32]];
    const markerSvg = marker === 'adresse'
      ? `<g transform="translate(${b * 0.46} ${h * 0.5})"><circle r="14" fill="var(--surface)" stroke="rgba(0,0,0,.15)"/><path d="M-6 1l6-6 6 6v6h-12z" fill="#1565C0"/></g>`
      : lilienPunkte.map(([x, y]) => `<g transform="translate(${b * x} ${h * y})"><circle r="12" fill="var(--primary)" stroke="#fff" stroke-width="2"/><svg x="-7" y="-7" width="14" height="14" viewBox="${L.viewBox}"><g transform="${L.transform}"><path d="${L.d}" fill="#fff"/></g></svg></g>`).join('');
    return `<svg class="map" width="${b}" height="${h}" viewBox="0 0 ${b} ${h}" preserveAspectRatio="none" aria-hidden="true" style="display:block">
      <rect width="${b}" height="${h}" fill="var(--map-bg)"/>
      <path d="M0 ${h * 0.8} C ${b * 0.3} ${h * 0.66}, ${b * 0.55} ${h * 0.98}, ${b} ${h * 0.74} L ${b} ${h} L 0 ${h} Z" fill="var(--map-water)"/>
      <rect x="${b * 0.6}" y="${h * 0.1}" width="${b * 0.24}" height="${h * 0.22}" rx="6" fill="var(--map-park)"/>
      <rect x="${b * 0.08}" y="${h * 0.4}" width="${b * 0.16}" height="${h * 0.14}" rx="3" fill="var(--map-bau)"/>
      <g stroke="var(--map-road)" stroke-linecap="round" fill="none">
        <path d="M-10 ${h * 0.36} L ${b + 10} ${h * 0.24}" stroke-width="9"/>
        <path d="M${b * 0.3} -10 L ${b * 0.42} ${h + 10}" stroke-width="7"/>
        <path d="M${b * 0.72} -10 L ${b * 0.58} ${h * 0.72}" stroke-width="5"/>
        <path d="M-10 ${h * 0.62} L ${b * 0.5} ${h * 0.52}" stroke-width="4"/>
      </g>${markerSvg}</svg>`;
  }
  const ATTR_OSM = '© OpenStreetMap-Mitwirkende';
  const ATTR_MT = '© MapTiler © OpenStreetMap-Mitwirkende';
  function adresskarte(ctx, variante, breite = 358) {
    const h = 160;
    let innen = '';
    let unter = '';
    if (variante === 'Q1') innen = `<span class="r-attr" style="right:6px;bottom:6px">${ATTR_OSM}</span><span class="r-recenter" style="right:8px;top:8px">${ico('crosshair', 17)}</span>`;
    if (variante === 'Q2') innen = `<span class="r-attr" style="left:6px;bottom:6px">${ATTR_OSM}</span><span class="r-recenter" style="right:8px;bottom:8px">${ico('crosshair', 17)}</span>`;
    if (variante === 'Q3') { innen = `<span class="r-recenter" style="right:8px;bottom:8px">${ico('crosshair', 17)}</span>`; unter = `<div class="r-attr-unter">${ATTR_OSM}</div>`; }
    return `${sec('Adresse')}<div class="r-karte mit-fuss"><div style="position:relative;line-height:0">${karteSvg(breite, h)}${innen}</div>${unter}
      <div class="r-adr">${ico('pin', 20, 'muted')}<div><b>Lindenstraße 12</b><small>12345 Musterstadt</small></div></div></div>`;
  }
  function vollkarte(ctx, variante) {
    const b = 390, h = 700;
    let innen = '';
    let leiste = '';
    if (variante === 'Q1') innen = `<span class="r-attr" style="right:8px;bottom:8px">${ATTR_MT}</span><span class="r-recenter" style="right:14px;bottom:40px;width:46px;height:46px;border-radius:14px">${ico('crosshair', 22)}</span>`;
    if (variante === 'Q2') innen = `<span class="r-attr" style="left:8px;bottom:8px">${ATTR_MT}</span><span class="r-recenter" style="right:14px;bottom:14px;width:46px;height:46px;border-radius:14px">${ico('crosshair', 22)}</span>`;
    if (variante === 'Q3') { innen = `<span class="r-recenter" style="right:14px;bottom:14px;width:46px;height:46px;border-radius:14px">${ico('crosshair', 22)}</span>`; leiste = `<div class="r-attr-leiste">${ATTR_MT}</div>`; }
    return `<div class="r-vk">${karteSvg(b, h, { marker: 'lilien' })}<div class="r-suche">${ico('search', 18)}Stamm oder Ort suchen</div>${innen}</div>${leiste}`;
  }

  // ------------------------------------------------------------- Runde 2
  const kurzZeilen = (n) => KURZ.slice(0, n).map(([i, t]) => `<div class="r-kp">${ico(i, 17)}<span>${t}</span></div>`).join('');
  // S1: „Kurz gesagt“ als eigene Karte, dann Anbieter, dann Kacheln. S2: Anbieter im „Kurz gesagt“-Block.
  function seiteR2(ctx, variante) {
    if (variante === 'S1') {
      return `<div style="height:14px"></div><div class="card r-kurz"><h4>Kurz gesagt</h4>${kurzZeilen(5)}</div>
        <div style="height:12px"></div>${anbieterKarte(true)}${d2Rest(ctx)}`;
    }
    return `<div style="height:14px"></div><div class="card r-kurz"><h4>Kurz gesagt</h4>${kurzZeilen(4)}
        <div class="r-kurz-anb"><span class="r-av">JL</span><div><b>Janneck Lange</b><span class="r-link">${ico('mail', 14)}dev@jannecklange.de</span>
          <small>Fragen, Auskunft, Löschung. Privates Projekt, nicht von der DPSG betrieben oder autorisiert.</small></div></div></div>${d2Rest(ctx)}`;
  }
  function einstiegE2(ctx) {
    return `${sec('Entwicklung')}<div class="r-set"><div class="r-setz">${quad('bug', '#8E8E93', 'gross', 20)}<div><b>Debug & Tools</b><small>Fehlerberichte, Cache, Tools</small></div>${ico('right', 20)}</div></div>
      <div class="r-fuss">Entwickelt mit <span class="herz">♥</span> in Hamburg<small>Version 1.0.0 (412)</small><div style="margin-top:8px"><span class="r-link r-markiert">Impressum & Datenschutz</span></div></div>`;
  }

  // Willkommen als Stepper. schritt: 'schutz' | 'daten' | 'intro'; schritte: Liste der Schritte (ohne Biometrie nur zwei).
  const SCHRITTE = {
    schutz: { icon: 'lock', titel: 'App schützen', inhalt: () => `<div class="r-text">Sperre die App mit Face ID, damit niemand ohne dich Mitgliederdaten sieht.</div>
        <div class="r-opt"><div><b>App-Sperre mit Face ID</b><small>Beim Öffnen und nach kurzer Pause entsperren. Auf Android: Fingerabdruck.</small></div>${sw(false)}</div>
        <div class="r-klein" style="margin-top:10px">Kannst du später in den App-Einstellungen ändern.</div>` },
    daten: { icon: 'shieldCheck', titel: 'Daten und Datenschutz', inhalt: () => `<div class="r-text">Deine Mitgliederdaten kommen aus Hitobito und bleiben verschlüsselt auf diesem Gerät.</div>
        <div class="r-opt"><div><b>Nutzungsanalyse</b><small>Nutzungsereignisse und Fehlerberichte an Wiredash senden. Jederzeit in den Einstellungen änderbar.</small></div>${sw(false)}</div>
        <div class="r-opt" style="margin-top:8px"><div><b>Keine mobilen Daten</b><small>Synchronisation und Karten nur im WLAN laden.</small></div>${sw(false)}</div>
        <span class="r-linkzeile">${ico('shield', 16)}Impressum & Datenschutz${ico('right', 15)}</span>` },
    intro: { icon: 'sparkle', titel: 'Kurze Einführung?', inhalt: () => `<div class="r-text">Möchtest du eine kurze Einführung? Sie zeigt dir in einer Minute, wo du Mitglieder, Statistik und Stufenwechsel findest.</div>` },
  };
  function punkte(n, aktiv) {
    return `<div class="r-punkte">${Array.from({ length: n }, (_, i) => `<i class="${i === aktiv ? 'on' : i < aktiv ? 'fertig' : ''}"></i>`).join('')}</div>`;
  }
  function balkenSchritte(n, aktiv) {
    return `<div class="r-fort">${Array.from({ length: n }, (_, i) => `<i class="${i <= aktiv ? 'on' : ''}"></i>`).join('')}</div>`;
  }
  function willkommenStepper(ctx, variante, schritt, schritte = ['schutz', 'daten', 'intro']) {
    const i = schritte.indexOf(schritt);
    const n = schritte.length;
    const S = SCHRITTE[schritt];
    const letzter = i === n - 1;
    const zurueck = i > 0 ? '<span class="r-btn text">Zurück</span>' : '<span></span>';
    if (variante === 'WS1') {
      const akt = letzter
        ? `<div class="r-akt gestapelt"><span class="r-btn filled breit">Ja, zeig mir die App</span><span class="r-btn tonal breit">Nein, direkt loslegen</span></div><div class="r-akt" style="justify-content:flex-start;margin-top:4px">${zurueck}</div>`
        : `<div class="r-akt" style="justify-content:space-between">${zurueck}<span class="r-btn filled">Weiter</span></div>`;
      return `<div class="r-dim"></div><div class="r-dlg r-stepdlg">
        ${punkte(n, i)}
        <div class="r-dlg-ico">${i === 0 ? lilie(36, 'var(--primary)') : `<span class="r-rundico">${ico(S.icon, 24)}</span>`}</div>
        ${i === 0 ? '<div class="r-gruss">Willkommen!</div>' : ''}
        <h3 style="text-align:center">${S.titel}</h3>
        <div class="r-step-in">${S.inhalt()}</div>
        <div class="r-step-fuss">${akt}</div></div>`;
    }
    const akt = letzter
      ? `<span class="r-btn filled breit">Ja, zeig mir die App</span><span class="r-btn tonal breit" style="margin-top:8px">Nein, direkt loslegen</span>${i > 0 ? '<span class="r-btn text breit" style="margin-top:2px">Zurück</span>' : ''}`
      : `<span class="r-btn filled breit">Weiter</span>${i > 0 ? '<span class="r-btn text breit" style="margin-top:2px">Zurück</span>' : '<span class="r-btn text breit" style="margin-top:2px;visibility:hidden">Zurück</span>'}`;
    return `<div class="r-voll-dlg">
      ${balkenSchritte(n, i)}<div class="r-schritt-t">Schritt ${i + 1} von ${n}</div>
      <div class="r-voll-kopf">${i === 0 ? `<span class="r-bs-logo">${lilie(34, '#ffffff')}</span>` : `<span class="r-rundico gross">${ico(S.icon, 28)}</span>`}
        ${i === 0 ? '<div class="r-gruss" style="text-align:left">Willkommen!</div>' : ''}<h3>${S.titel}</h3></div>
      <div class="r-step-in">${S.inhalt()}</div>
      <div class="r-voll-fuss">${akt}</div></div>`;
  }

  // Mitglied-Detail für den I2-Zeitpunkt
  function mitgliedDetail(ctx) {
    const z = (icon, w, l) => `<div class="r-setz">${quad(icon, 'var(--primary)', 'klein', 15)}<div><b style="font-weight:500">${w}</b><small>${l}</small></div></div>`;
    return `<div class="r-md-kopf"><span class="av gross">LB</span><div><b>Lena „Funke“ Brandt</b><small>Leiterin · Trupp Kompass</small></div></div>
      ${sec('Kontakt')}<div class="r-set">${z('device', '+49 170 1234567', 'Mobil')}${z('mail', 'lena.brandt@example.org', 'E-Mail')}</div>
      ${sec('Adresse')}<div class="r-set">${z('pin', 'Lindenstraße 12', '12345 Musterstadt')}</div>
      ${sec('Mitgliedschaft')}<div class="r-set">${z('users', 'Seit 01.04.2004', 'Eintritt')}${z('id', '4711203', 'Mitgliedsnummer')}</div>`;
  }
  const snack = (text) => `<div class="r-snack">${text}</div>`;

  // ------------------------------------------------------------- Runde 3
  // Stepper mit vier Schritten in der Optik von WS2. Varianten für die „Warum“-Punkte:
  // WA = Liste mit Icons über der Karte, WB = aufklappbare Info-Box „Warum?“ unter der Karte.
  const R3 = {
    schutz: {
      icon: 'lock', titel: 'App schützen',
      text: 'Sperre die App mit Face ID. Dann sieht niemand ohne dich die Mitgliederdaten.',
      warumTitel: 'Warum ist das sinnvoll?',
      warum: [
        ['device', 'Mitgliederdaten liegen offline auf dem Gerät, viele von Minderjährigen, mit Adressen, Geburtsdaten und Angaben zum Führungszeugnis.'],
        ['user', 'Schützt, wenn das Handy entsperrt herumliegt oder verliehen wird.'],
        ['eyeOff', 'Fragt beim Öffnen und nach kurzer Pause erneut nach Face ID.'],
      ],
      karte: { icon: 'face', titel: 'App-Sperre', sub: 'Face ID beim Öffnen und nach kurzer Pause' },
      spaeter: 'Kannst du später in den App-Einstellungen ändern.',
    },
    benach: {
      icon: 'bell', titel: 'Benachrichtigungen',
      text: 'Die App erinnert dich an Fristen, damit nichts unbemerkt abläuft.',
      warumTitel: 'Wofür braucht die App das?',
      warum: [
        ['award', 'Erinnerung, bevor Qualifikationen ablaufen, etwa Präventionsschulung, EFZ oder Erste Hilfe, je nach Einstellung.'],
        ['sync', 'Hinweis, bevor die Offline-Daten ablaufen und du dich neu anmelden musst.'],
        ['shield', 'Keine Werbung, kein Tracking: nur lokale Erinnerungen von deinem Gerät.'],
      ],
      karte: { icon: 'bell', titel: 'Benachrichtigungen', sub: 'Erinnerungen von diesem Gerät' },
      spaeter: 'Kannst du später in den App-Einstellungen ändern.',
    },
  };
  function aktivKarte(k, zustand) {
    let rechts = '<span class="r-btn tonal r-akt-btn">Aktivieren</span>';
    let unten = '';
    if (zustand === 'aktiv') rechts = `<span class="r-aktiv">${ico('check', 17)}Aktiv</span>`;
    if (zustand === 'abgelehnt') {
      rechts = '<span class="r-aus">Aus</span>';
      unten = `<div class="r-abgelehnt">${ico('info', 16)}<div>Nicht erlaubt. In den iOS-Einstellungen änderbar.<span class="r-link">Einstellungen öffnen${ico('ext', 13)}</span></div></div>`;
    }
    return `<div class="r-aktk${zustand === 'aktiv' ? ' an' : ''}"><div class="r-aktk-z"><span class="r-rundico klein">${ico(k.icon, 20)}</span><div><b>${k.titel}</b><small>${k.sub}</small></div>${rechts}</div>${unten}</div>`;
  }
  const warumListe = (S) => `<div class="r-warum">${S.warum.map(([i, t]) => `<div class="r-pkt info">${ico(i, 19)}<span>${t}</span></div>`).join('')}</div>`;
  const warumBox = (S, auf) => `<div class="r-warumbox${auf ? ' auf' : ''}"><div class="r-warumbox-k">${ico('info', 17)}<b>${S.warumTitel}</b>${ico(auf ? 'up' : 'down', 17)}</div>
      ${auf ? S.warum.map(([i, t]) => `<div class="r-wz3">${ico(i, 16)}<span>${t}</span></div>`).join('') : ''}</div>`;
  function iosMitteilungen() {
    return `<div class="r-dim" style="background:rgba(0,0,0,.3);z-index:5"></div><div class="r-ios" style="z-index:6"><div class="r-ios-in">
      <b>„NaMi“ möchte dir Mitteilungen senden</b><p>Mitteilungen können Hinweise, Töne und Kennzeichensymbole enthalten. Diese können in den Einstellungen konfiguriert werden.</p></div>
      <div class="r-ios-2"><span>Nicht erlauben</span><span><b>Erlauben</b></span></div></div>`;
  }
  // schritt: 'schutz' | 'benach' | 'daten' | 'intro'; opts: { zustand, warumAuf, schritte }
  function stepperR3(ctx, variante, schritt, { zustand = 'vorher', warumAuf = false, schritte = ['schutz', 'benach', 'daten', 'intro'] } = {}) {
    const i = schritte.indexOf(schritt);
    const n = schritte.length;
    const letzter = i === n - 1;
    const erster = i === 0;
    let titel, icon, inhalt;
    if (R3[schritt]) {
      const S = R3[schritt];
      titel = S.titel; icon = S.icon;
      inhalt = variante === 'WA'
        ? `<div class="r-text">${S.text}</div>${warumListe(S)}${aktivKarte(S.karte, zustand)}`
        : `<div class="r-text">${S.text}</div>${aktivKarte(S.karte, zustand)}${warumBox(S, warumAuf)}`;
      inhalt += `<div class="r-klein" style="margin-top:10px">${S.spaeter}</div>`;
    } else {
      titel = SCHRITTE[schritt].titel; icon = SCHRITTE[schritt].icon; inhalt = SCHRITTE[schritt].inhalt();
    }
    const zurueck = erster ? '<span class="r-btn text breit" style="margin-top:2px;visibility:hidden">Zurück</span>' : '<span class="r-btn text breit" style="margin-top:2px">Zurück</span>';
    const akt = letzter
      ? `<span class="r-btn filled breit">Ja, zeig mir die App</span><span class="r-btn tonal breit" style="margin-top:8px">Nein, direkt loslegen</span>${zurueck}`
      : `<span class="r-btn filled breit">Weiter</span>${zurueck}`;
    return `<div class="r-voll-dlg r3">
      ${balkenSchritte(n, i)}<div class="r-schritt-t">Schritt ${i + 1} von ${n}</div>
      <div class="r-voll-kopf">${erster ? `<span class="r-bs-logo">${lilie(34, '#ffffff')}</span><div class="r-gruss" style="text-align:left">Willkommen!</div>` : `<span class="r-rundico gross">${ico(icon, 28)}</span>`}<h3>${titel}</h3></div>
      <div class="r-step-in">${inhalt}</div>
      <div class="r-voll-fuss">${akt}</div></div>`;
  }

  window.RBAU = {
    esc, ico, lilie, sec, farbenEinfuegen, telefon, panel, kopf, kopfOhne, tabbarMitglieder,
    EMPF, seiteD1, seiteD2, sheetD2, seiteD3, einstellungen, mitgliederliste, willkommen,
    feedbackDialog, iosReview, playReview, erfolge, abzeichenSheet, wiredash, wiredashText,
    bundHintergrund, einwilligung, transparenz, adresskarte, vollkarte,
    seiteR2, einstiegE2, willkommenStepper, mitgliedDetail, snack,
    stepperR3, iosMitteilungen,
  };
})();

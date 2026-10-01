// Synthetische Beispieldaten für die Statistik-Entwürfe. Keine echten Personen.
//
// - "Stamm Silberfels" spiegelt lib/stories/store/store_showcase_data.dart
//   (Store-Screenshots), damit Entwurf und App dieselben Menschen zeigen.
// - "Stamm Weitblick" ist größer und bewusst ungleichmäßig (Neue, Überfällige,
//   zwei Meuten), um zu prüfen, ob die Darstellungen bei mehr Personen tragen.
//
// Farben: Stufenfarben aus DPSGColors (lib/presentation/theme/theme.dart),
// Paletten-Tokens "standard" aus design/supporter/palettes.json.
(function () {
  const heute = new Date(2026, 8, 30);
  const stichtag = new Date(2026, 10, 1);

  const stufen = [
    { id: 'biber', name: 'Biber', kurz: 'Biber', min: 4, max: 7 },
    { id: 'woe', name: 'Wölflinge', kurz: 'Wö', min: 6, max: 10 },
    { id: 'jufi', name: 'Jungpfadfinder', kurz: 'Jufi', min: 9, max: 13 },
    { id: 'pfadi', name: 'Pfadfinder', kurz: 'Pfadi', min: 12, max: 16 },
    { id: 'rover', name: 'Rover', kurz: 'Rover', min: 15, max: 20 },
  ];

  // Stufenfarben bleiben Markenfarben. Hell: Biber-Weiß ist auf weißen Karten
  // unsichtbar und als Punkt nicht von einem Leitungsring zu unterscheiden,
  // daher Hellgrau mit Kontur. Dunkel: Jufi angehoben, weil #2f53a7 auf
  // #1a1a22 nur 2,4:1 erreicht. Beides Vorschlag, siehe Entwurfsseite.
  const stufenfarben = {
    hell: { biber: '#dcdce2', woe: '#ff6400', jufi: '#2f53a7', pfadi: '#00823c', rover: '#cc1f2f' },
    dunkel: { biber: '#ffffff', woe: '#ff6400', jufi: '#5b7fd6', pfadi: '#00823c', rover: '#cc1f2f' },
  };

  // Merkmals-Palette für Geschlecht und Konfession: validiert (dataviz
  // validate_palette.js, hell und dunkel), keine Überschneidung mit Stufen.
  const merkmal = {
    hell: ['#4a3aa7', '#1baf7a', '#eda100', '#8e8e93'],
    dunkel: ['#9085e9', '#199e70', '#c98500', '#8a8a9a'],
  };

  const palette = {
    hell: {
      primary: '#003056', onPrimary: '#ffffff', bg: '#f5f5f7', surface: '#ffffff',
      surface2: '#f2f2f5', fg: '#1c1c1e', fg2: '#48484d', muted: '#8e8e93',
      border: '#e5e5ea', primaryLite: '#e8edf5', grid: '#ececf0',
    },
    dunkel: {
      primary: '#5a9ad8', onPrimary: '#0e0e12', bg: '#0e0e12', surface: '#1a1a22',
      surface2: '#23232d', fg: '#f0f0f5', fg2: '#c4c4ce', muted: '#8a8a9a',
      border: '#2e2e3a', primaryLite: '#1a253a', grid: '#2a2a35',
    },
  };

  function rng(seed) {
    let a = seed >>> 0;
    return function () {
      a = (a + 0x6d2b79f5) >>> 0;
      let t = a;
      t = Math.imul(t ^ (t >>> 15), t | 1);
      t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
      return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
  }

  // Erfundene Namen für Detaillisten (Runde 2).
  const namenW = ['Lina', 'Emma', 'Mia', 'Paula', 'Juna', 'Ronja', 'Maja', 'Tilda', 'Frida', 'Merle', 'Ella', 'Romy', 'Carla', 'Luise', 'Pia', 'Jule', 'Nora', 'Ylvi', 'Enna', 'Lotte', 'Hedda', 'Svea', 'Alma', 'Wilma', 'Elif', 'Amira', 'Zoe', 'Mara', 'Ida', 'Lene', 'Rieke', 'Thea'];
  const namenM = ['Ole', 'Jonte', 'Mats', 'Lio', 'Henri', 'Emil', 'Anton', 'Bela', 'Janne', 'Milan', 'Theo', 'Carlo', 'Levi', 'Juri', 'Piet', 'Linus', 'Fiete', 'Noel', 'Tom', 'Aaron', 'Mika', 'Jakob', 'Karl', 'Leon', 'Malte', 'Nils', 'Oskar', 'Paul', 'Rasmus', 'Tjark', 'Yusuf', 'Ben'];
  const namenD = ['Kim', 'Robin', 'Alex'];
  const initialen = 'ABDFGHKLMNPRSTW';

  function minusJahre(datum, jahre) {
    const ms = jahre * 365.25 * 24 * 3600 * 1000;
    return new Date(datum.getTime() - ms);
  }

  // --- Stamm Silberfels (gespiegelt aus der Store-Szene) --------------------
  const silberfelsListe = [
    ['1001', 'Mila', 4, 3, 'biber', 'bi', false, 'w'],
    ['1002', 'Theo', 4, 8, 'biber', 'bi', false, 'm'],
    ['1003', 'Ida', 5, 5, 'biber', 'bi', false, 'w'],
    ['1011', 'Emil', 6, 5, 'woe', 'woe', false, 'm'],
    ['1012', 'Lotta', 7, 2, 'woe', 'woe', false, 'w'],
    ['1013', 'Paul', 7, 11, 'woe', 'woe', false, 'm'],
    ['1014', 'Frieda', 8, 6, 'woe', 'woe', false, 'w'],
    ['1015', 'Anton', 9, 4, 'woe', 'woe', false, 'm'],
    ['1016', 'Greta', 10, 6, 'woe', 'woe', false, 'w'],
    ['1021', 'Jonas', 9, 7, 'jufi', 'jufi', false, 'm'],
    ['1022', 'Hanna', 10, 0, 'jufi', 'jufi', false, 'w'],
    ['1023', 'Luis', 10, 9, 'jufi', 'jufi', false, 'm'],
    ['1024', 'Marie', 11, 2, 'jufi', 'jufi', false, 'w'],
    ['1025', 'Ben', 12, 10, 'jufi', 'jufi', false, 'm'],
    ['1031', 'Clara', 12, 3, 'pfadi', 'pfadi', false, 'w'],
    ['1032', 'Finn', 13, 8, 'pfadi', 'pfadi', false, 'm'],
    ['1033', 'Lea', 14, 5, 'pfadi', 'pfadi', false, 'w'],
    ['1034', 'Noah', 15, 2, 'pfadi', 'pfadi', false, 'm'],
    ['1041', 'Sophie', 16, 5, 'rover', 'rover', false, 'w'],
    ['1042', 'Jakob', 18, 1, 'rover', 'rover', false, 'm'],
    ['1043', 'Nele', 19, 9, 'rover', 'rover', false, 'w'],
    ['1051', 'Katharina', 27, 4, 'woe', 'woe', true, 'w'],
    ['1052', 'David', 24, 7, 'jufi', 'jufi', true, 'm'],
    ['1053', 'Lena', 23, 2, 'pfadi', 'pfadi', true, 'w'],
    ['1054', 'Tobias', 31, 10, 'rover', 'rover', true, 'm'],
    ['1055', 'Miriam', 29, 6, 'biber', 'bi', true, 'w'],
  ];

  const silberfels = {
    id: 'klein',
    name: 'Stamm Silberfels',
    gruppen: [
      { id: 'bi', name: 'Biberbande', stufe: 'biber' },
      { id: 'woe', name: 'Meute Seeadler', stufe: 'woe' },
      { id: 'jufi', name: 'Trupp Kompass', stufe: 'jufi' },
      { id: 'pfadi', name: 'Trupp Nordlicht', stufe: 'pfadi' },
      { id: 'rover', name: 'Runde Fernweh', stufe: 'rover' },
    ],
    personen: silberfelsListe.map(([id, vorname, j, m, stufe, gruppe, leitung, gender]) => {
      const geburt = new Date(heute.getFullYear() - j, heute.getMonth() - m, (Number(id) % 27) + 1);
      const jahre = leitung ? 12 : Math.min(6, Math.max(1, j - 4));
      return {
        id, vorname, stufe, gruppe, leitung, gender, geburt,
        eintritt: new Date(heute.getFullYear() - jahre, 8, 1),
      };
    }),
    sonstige: 0,
    sonstigeRollen: [],
    ohneGeburtsdatum: 0,
    eigeneKacheln: [
      { titel: 'Stammesvorstand', wert: 2, ziel: 3, zielText: 'besetzt', filter: 'Rolle in „Stammesvorstand"', aufteilung: null },
      { titel: 'Fördermitglieder', wert: 2, ziel: null, filter: 'Rolle „Fördermitgliedschaft"', aufteilung: { woe: 1, rover: 1 } },
    ],
    ziele: { neuProJahr: 5, gruppeMax: { biber: 8, woe: 12, jufi: 12, pfadi: 12, rover: 10 } },
  };

  // --- Stamm Weitblick (größer, gestreut) -----------------------------------
  function weitblick() {
    const r = rng(99);
    const gruppen = [
      { id: 'bi', name: 'Biberburg', stufe: 'biber', kinder: 7, leitung: 2 },
      { id: 'w1', name: 'Meute Wirbelwind', stufe: 'woe', kinder: 11, leitung: 3 },
      { id: 'w2', name: 'Meute Sternschnuppe', stufe: 'woe', kinder: 9, leitung: 2 },
      { id: 'jf', name: 'Trupp Wegweiser', stufe: 'jufi', kinder: 13, leitung: 3 },
      { id: 'pf', name: 'Trupp Nordwind', stufe: 'pfadi', kinder: 10, leitung: 2 },
      { id: 'ro', name: 'Runde Horizont', stufe: 'rover', kinder: 7, leitung: 2 },
    ];
    // Einzelne bewusst über der Altersgrenze (überfällige Wechsel).
    const sonderalter = { w1: [11.2, 10.9], jf: [14.1], ro: [21.3] };
    const personen = [];
    let nr = 2000;
    for (const g of gruppen) {
      const s = stufen.find((x) => x.id === g.stufe);
      const extra = sonderalter[g.id] || [];
      for (let i = 0; i < g.kinder; i++) {
        // Die meisten wechseln, sobald sie dürfen: Alter eher im unteren Teil
        // der Spanne, sonst wären fast alle am Stichtag "fällig".
        const alter = i < extra.length
          ? extra[i]
          : s.min + 0.2 + Math.pow(r(), 1.2) * (s.max - s.min) * 0.85;
        const geburt = minusJahre(heute, alter);
        let jahreDabei = Math.min(alter - 4, 1 + Math.pow(r(), 1.2) * Math.max(0, alter - 5));
        // Neun Neue in den letzten zwölf Monaten, vor allem bei Biber und Wö;
        // Neue sind die Jüngsten ihrer Gruppe (nach den Sonderaltern).
        const neuQuote = { bi: 3, w1: 2, w2: 2, jf: 1, pf: 1 }[g.id] || 0;
        if (i >= extra.length && i < extra.length + neuQuote) {
          jahreDabei = Math.min(alter - 4, 0.1 + r() * 0.8);
        }
        const u = r();
        personen.push({
          id: String(nr++), stufe: g.stufe, gruppe: g.id, leitung: false,
          gender: u < 0.49 ? 'w' : u < 0.97 ? 'm' : u < 0.99 ? 'd' : null,
          geburt, eintritt: minusJahre(heute, jahreDabei),
        });
      }
      for (let i = 0; i < g.leitung; i++) {
        const alter = 19 + r() * 16;
        const u = r();
        personen.push({
          id: String(nr++), stufe: g.stufe, gruppe: g.id, leitung: true,
          gender: u < 0.52 ? 'w' : 'm',
          geburt: minusJahre(heute, alter),
          eintritt: minusJahre(heute, Math.min(alter - 5, 4 + r() * 14)),
        });
      }
    }
    const zaehler = { w: 0, m: 0, d: 0 };
    personen.forEach((p, i) => {
      const art = p.gender === 'w' ? 'w' : p.gender === 'm' ? 'm' : 'd';
      const liste = art === 'w' ? namenW : art === 'm' ? namenM : namenD;
      p.vorname = liste[zaehler[art]++ % liste.length];
      p.nachname = `${initialen[(i * 7) % initialen.length]}.`;
    });
    return {
      id: 'gross',
      name: 'Stamm Weitblick',
      gruppen: gruppen.map(({ id, name, stufe }) => ({ id, name, stufe })),
      personen,
      sonstige: 4,
      sonstigeRollen: [
        { rolle: 'Stammesvorstand', anzahl: 2 },
        { rolle: 'Kurat*in', anzahl: 1 },
        { rolle: 'Elternvertretung', anzahl: 1 },
      ],
      ohneGeburtsdatum: 2,
      eigeneKacheln: [
        { titel: 'Stammesvorstand', wert: 3, ziel: 3, zielText: 'besetzt', filter: 'Rolle in „Stammesvorstand"', aufteilung: null },
        { titel: 'Fördermitglieder', wert: 6, ziel: null, filter: 'Rolle „Fördermitgliedschaft"', aufteilung: { woe: 2, jufi: 1, pfadi: 1, rover: 2 } },
      ],
      ziele: { neuProJahr: 10, gruppeMax: { biber: 10, woe: 14, jufi: 16, pfadi: 14, rover: 12 } },
    };
  }

  // --- Stamm Querfeld: absichtlich krumme Daten (Runde 4) -----------------
  // Darf seltsam aussehen, darf aber nichts kaputt machen: Mehrheit außerhalb
  // der Altersgrenzen, Platzhalter-Geburtsdaten (1900), Eintritte in der
  // Zukunft, leere Gruppen, eine Riesengruppe, viele Gruppen, fehlende
  // Zielwerte, Ziel 0, leere Aufteilung, kaum Geschlechtsangaben.
  function querfeld() {
    const r = rng(4242);
    const platzhalter = new Date(1900, 0, 1);
    const gruppen = [
      { id: 'q-w', name: 'Meute Riesig', stufe: 'woe' },
      { id: 'q-j', name: 'Trupp Leer', stufe: 'jufi' },
      { id: 'q-p1', name: 'Trupp Eins', stufe: 'pfadi' },
      { id: 'q-p2', name: 'Trupp Zwei', stufe: 'pfadi' },
      { id: 'q-p3', name: 'Trupp Drei', stufe: 'pfadi' },
      { id: 'q-p4', name: 'Trupp Vier', stufe: 'pfadi' },
      { id: 'q-p5', name: 'Trupp Fünf mit einem sehr langen Gruppennamen', stufe: 'pfadi' },
      { id: 'q-r', name: 'Runde 30plus', stufe: 'rover' },
    ];
    const personen = [];
    let nr = 3000;
    const kind = (gruppe, stufe, alter, extra = {}) => personen.push({
      id: String(nr++), stufe, gruppe, leitung: false,
      gender: r() < 0.8 ? null : r() < 0.5 ? 'w' : 'm',
      geburt: alter === null ? platzhalter : minusJahre(heute, alter),
      eintritt: minusJahre(heute, r() * 10),
      ...extra,
    });
    for (let i = 0; i < 38; i++) {
      const extra = i < 2 ? { eintritt: new Date(2027, 0, 1) } : i === 2 ? { eintritt: platzhalter } : {};
      kind('q-w', 'woe', i < 3 ? null : 3 + r() * 12, extra);
    }
    [['q-p1', 2], ['q-p2', 1], ['q-p3', 0], ['q-p4', 3], ['q-p5', 1]].forEach(([g, n]) => {
      for (let i = 0; i < n; i++) kind(g, 'pfadi', 10 + r() * 9);
    });
    for (let i = 0; i < 6; i++) kind('q-r', 'rover', 24 + r() * 10);
    const leitung = (gruppe, stufe) => personen.push({
      id: String(nr++), stufe, gruppe, leitung: true, gender: null,
      geburt: minusJahre(heute, 22 + r() * 20), eintritt: minusJahre(heute, 2 + r() * 8),
    });
    leitung('q-w', 'woe');
    leitung('q-j', 'jufi');
    leitung('q-j', 'jufi');
    leitung('q-p1', 'pfadi');
    personen.forEach((p, i) => {
      p.vorname = (p.gender === 'm' ? namenM : namenW)[i % 30];
      p.nachname = `${initialen[i % initialen.length]}.`;
    });
    return {
      id: 'krumm',
      name: 'Stamm Querfeld',
      gruppen,
      personen,
      sonstige: 0,
      sonstigeRollen: [],
      ohneGeburtsdatum: 3,
      eigeneKacheln: [
        { titel: 'Ohne Treffer', wert: 0, ziel: 0, zielText: 'besetzt', filter: 'Rolle in „Kassenprüfung"', aufteilung: null },
        { titel: 'Leere Aufteilung', wert: 0, ziel: null, filter: 'Rolle „Fördermitgliedschaft"', aufteilung: {} },
      ],
      ziele: { neuProJahr: 0, gruppeMax: { woe: 14 } },
    };
  }

  window.STATISTIK = {
    heute, stichtag, stufen, stufenfarben, merkmal, palette,
    staemme: { klein: silberfels, gross: weitblick(), krumm: querfeld() },
  };
})();

// Synthetische Personen für die Entwürfe der Mitgliedsdetails.
// Jede Person deckt Edge Cases aus specs/mitgliedsdetails-redesign.md ab.
// Stichtag ist fest, damit die Entwürfe nicht vom echten Datum abhängen.
(function () {
  const HEUTE = '2026-10-02';

  // Paletten-Tokens "standard" aus design/supporter/palettes.json.
  const palette = {
    hell: { primary: '#003056', onPrimary: '#ffffff', bg: '#f5f5f7', surface: '#ffffff', surface2: '#f2f2f5', fg: '#1c1c1e', fg2: '#48484d', muted: '#8e8e93', border: '#e5e5ea', primaryLite: '#e8edf5', grid: '#ececf0', error: '#cc1f2f', success: '#00823c', warn: '#b35c00' },
    dunkel: { primary: '#5a9ad8', onPrimary: '#0e0e12', bg: '#0e0e12', surface: '#1a1a22', surface2: '#23232d', fg: '#f0f0f5', fg2: '#c4c4ce', muted: '#8a8a9a', border: '#2e2e3a', primaryLite: '#1a253a', grid: '#2a2a35', error: '#ff5050', success: '#22c65a', warn: '#ff9f2e' },
  };
  // Stufenfarben aus lib/presentation/theme/theme.dart (Biber hell und Jufi dunkel angepasst wie in design/statistik).
  const stufenfarben = {
    hell: { biber: '#dcdce2', woe: '#ff6400', jufi: '#2f53a7', pfadi: '#00823c', rover: '#cc1f2f' },
    dunkel: { biber: '#ffffff', woe: '#ff6400', jufi: '#5b7fd6', pfadi: '#00823c', rover: '#cc1f2f' },
  };
  const stufen = {
    biber: { name: 'Biber', kurz: 'Biber', bild: 'biber.png', gruppe: 'Biberbau' },
    woe: { name: 'Wölfling', kurz: 'Wö', bild: 'woe.png', gruppe: 'Meute Seeonee' },
    jufi: { name: 'Jungpfadfinder', kurz: 'Jufi', bild: 'jufi.png', gruppe: 'Trupp Kompass' },
    pfadi: { name: 'Pfadfinder', kurz: 'Pfadi', bild: 'pfadi.png', gruppe: 'Trupp Polarstern' },
    rover: { name: 'Rover', kurz: 'Rover', bild: 'rover.png', gruppe: 'Runde Fernweh' },
  };
  const STAMM = 'Stamm Silberfels';
  const BEZIRK = 'Bezirk Rheinauen';
  const DV = 'DV Talheim';
  const AKTIVER_LAYER = STAMM;

  // Rollen-Kurzschreibweise: art m = Mitglied, l = Leitung, h = Hilfsleitung, s = Sonstiges.
  function r(art, stufe, start, ende, extra = {}) {
    const st = stufe ? stufen[stufe] : null;
    const label = extra.label || (art === 'm' ? 'Mitglied' : art === 'l' ? 'Leiter*in' : art === 'h' ? 'Hilfsleiter*in' : 'Rolle');
    return {
      art: art === 'h' ? 'l' : art,
      stufe,
      label,
      gruppe: extra.gruppe || (st ? st.gruppe : STAMM),
      layer: extra.layer || STAMM,
      start,
      ende,
      ohneStart: !!extra.ohneStart,
    };
  }

  const personen = {
    lena: {
      id: 'lena', titel: 'Lena „Funke“ Brandt', vorname: 'Lena', nachname: 'Brandt', fahrtenname: 'Funke',
      kurz: 'Funke · Vielrolle, Mehrlayer, Leitung parallel',
      geburtsdatum: '1996-03-14', geschlecht: 'weiblich', pronomen: 'sie/ihr',
      eintritt: '2004-04-01', austritt: null, mitgliedsnummer: '4711203', beitragsart: 'Voller Beitrag', aktualisiert: '2026-09-14',
      telefon: [{ wert: '+49 170 1234567', label: 'Mobil' }, { wert: '+49 221 998877', label: 'Arbeit' }],
      mail: [{ wert: 'lena.brandt@example.org', label: 'Privat' }, { wert: 'funke@stamm-silberfels.de', label: 'Stamm' }],
      adressen: [{ label: 'Wohnort', zeilen: ['Lindenstraße 12', '50667 Köln'] }],
      karte: 'ok', haushalt: [],
      rollen: [
        r('m', 'woe', '2004-04-01', '2007-08-31'),
        r('m', 'jufi', '2007-09-01', '2010-08-31'),
        r('m', 'pfadi', '2010-09-01', '2013-08-31'),
        r('m', 'rover', '2013-09-01', '2016-08-31'),
        r('h', 'jufi', '2014-09-01', '2017-08-31'),
        r('s', null, '2016-01-01', '2019-12-31', { label: 'Materialwart*in' }),
        r('l', 'pfadi', '2017-09-01', '2022-08-31'),
        r('s', null, '2020-05-01', '2024-04-30', { label: 'Stv. Stammesführer*in' }),
        r('s', null, '2022-07-01', '2022-08-15', { label: 'Mitarbeiter*in Unterlager', gruppe: 'Bundeslager 2022', layer: DV }),
        r('l', 'rover', '2022-09-01', null),
        r('s', null, '2023-01-01', null, { label: 'AK Mitarbeiter*in', gruppe: 'Wölflingsstufe', layer: BEZIRK }),
        r('l', 'woe', '2024-09-01', null),
        r('s', null, '2024-05-01', null, { label: 'Bezirksdelegierte*r' }),
        r('s', null, '2025-03-01', null, { label: 'AK Leiter*in', gruppe: 'Ausbildung', layer: DV }),
        r('s', null, '2026-11-01', null, { label: 'Stammesbeauftragte*r Prävention' }),
      ],
      efz: { status: 'bald', ausgestellt: '2021-11-20', eingesehen: '2021-12-02', bis: '2026-11-20' },
      qualis: [
        { label: 'Woodbadge', am: '2019-06-10', bis: null },
        { label: 'Präventionsschulung', am: '2023-03-04', bis: '2028-03-04' },
        { label: 'Erste-Hilfe-Kurs', am: '2025-02-15', bis: '2027-02-15' },
        { label: 'Juleica', am: '2020-05-01', bis: '2023-05-01', reaktivierbar: true },
        { label: 'Modulausbildung', am: '2016-11-12', bis: null },
      ],
    },
    mats: {
      id: 'mats', titel: 'Mats Okafor', vorname: 'Mats', nachname: 'Okafor', fahrtenname: null,
      kurz: 'Neuling, Familie, viele Kontakte, Kartenfehler',
      geburtsdatum: '2018-05-09', geschlecht: 'männlich', pronomen: null,
      eintritt: '2026-09-25', austritt: null, mitgliedsnummer: '4729981', beitragsart: 'Familienermäßigt', aktualisiert: '2026-09-25',
      telefon: [
        { wert: '+49 171 5550101', label: 'Mama mobil' }, { wert: '+49 172 5550102', label: 'Papa mobil' },
        { wert: '+49 221 555010', label: 'Festnetz' }, { wert: '+49 228 777123', label: 'Oma Ruth' },
        { wert: '+49 160 9988776', label: 'Notfall Nachbarin' },
      ],
      mail: [{ wert: 'ada.okafor@example.org', label: 'Mama' }, { wert: 'ben.okafor@example.org', label: 'Papa' }, { wert: 'familie.okafor@example.org', label: 'Familie' }],
      adressen: [
        { label: 'Wohnort', zeilen: ['Am Mühlbach 3', '50999 Köln'] },
        { label: 'Papa', zeilen: ['Venloer Straße 210', '50823 Köln'] },
        { label: 'Oma', zeilen: ['Kirchweg 5', '53111 Bonn'] },
      ],
      karte: 'fehler',
      haushalt: [{ name: 'Ida Okafor', stufe: 'jufi', alter: 12 }, { name: 'Noah Okafor', stufe: 'biber', alter: 5 }],
      rollen: [r('m', 'woe', '2026-09-25', null)],
      efz: { status: 'keins' },
      qualis: [],
    },
    jonas: {
      id: 'jonas', titel: 'Jonas Weber', vorname: 'Jonas', nachname: 'Weber', fahrtenname: null,
      kurz: 'Parallel Jufi und Pfadi, Karte offline',
      geburtsdatum: '2013-02-11', geschlecht: 'männlich', pronomen: null,
      eintritt: '2020-09-01', austritt: null, mitgliedsnummer: '4720450', beitragsart: 'Voller Beitrag', aktualisiert: '2026-09-02',
      telefon: [{ wert: '+49 176 4433221', label: 'Eltern' }],
      mail: [{ wert: 'weber.familie@example.org', label: 'Eltern' }],
      adressen: [{ label: 'Wohnort', zeilen: ['Rosenweg 8', '50735 Köln'] }],
      karte: 'offline', haushalt: [],
      rollen: [
        r('m', 'woe', '2020-09-01', '2023-08-31'),
        r('m', 'jufi', '2023-09-01', null),
        r('m', 'pfadi', '2026-09-01', null),
      ],
      efz: { status: 'keins' },
      qualis: [],
    },
    sami: {
      id: 'sami', titel: 'Sami Yilmaz', vorname: 'Sami', nachname: 'Yilmaz', fahrtenname: null,
      kurz: 'Rover und Wö-Hilfsleitung, Rolle ohne Start, künftige Rolle',
      geburtsdatum: '2006-07-22', geschlecht: 'divers', pronomen: 'er/ihm',
      eintritt: '2013-09-01', austritt: null, mitgliedsnummer: '4715532', beitragsart: 'Voller Beitrag', aktualisiert: '2026-08-30',
      telefon: [{ wert: '+49 157 3216549', label: 'Mobil' }],
      mail: [{ wert: 'sami.y@example.org', label: 'Privat' }],
      adressen: [{ label: 'Wohnort', zeilen: ['Hinterhof 2b', '50999 Köln-Sürth'] }],
      karte: 'nichtGefunden', haushalt: [],
      rollen: [
        r('m', 'woe', '2013-09-01', '2016-08-31', { ohneStart: true }),
        r('m', 'jufi', '2016-09-01', '2019-08-31'),
        r('m', 'pfadi', '2019-09-01', '2022-08-31'),
        r('m', 'rover', '2022-09-01', null),
        r('h', 'woe', '2025-09-01', null),
        r('l', 'woe', '2026-11-01', null),
      ],
      efz: { status: 'gueltig', ausgestellt: '2025-08-30', eingesehen: '2025-09-12', bis: '2030-08-30' },
      qualis: [{ label: 'Präventionsschulung', am: '2025-06-01', bis: '2030-06-01' }],
    },
    petra: {
      id: 'petra', titel: 'Petra Lindner', vorname: 'Petra', nachname: 'Lindner', fahrtenname: null,
      kurz: 'Nur Sonstiges, keine Adresse, Geburtstag unbekannt',
      geburtsdatum: null, geschlecht: null, pronomen: null,
      eintritt: '2019-03-01', austritt: null, mitgliedsnummer: '4718870', beitragsart: 'Fördermitgliedschaft', aktualisiert: '2026-01-10',
      telefon: [{ wert: '+49 221 4455667', label: 'Privat' }],
      mail: [],
      adressen: [],
      karte: null, haushalt: [],
      rollen: [
        r('s', null, '2019-03-01', null, { label: 'Stammesschatzmeister*in' }),
        r('s', null, '2021-04-01', null, { label: 'Kassenprüfer*in', gruppe: BEZIRK, layer: BEZIRK }),
      ],
      efz: { status: 'keins' },
      qualis: [],
    },
    karl: {
      id: 'karl', titel: 'Karl Hoffmann', vorname: 'Karl', nachname: 'Hoffmann', fahrtenname: null,
      kurz: 'Ausgetreten, nur vergangene Rollen, EFZ abgelaufen',
      geburtsdatum: '2002-01-05', geschlecht: 'männlich', pronomen: null,
      eintritt: '2009-09-01', austritt: '2025-12-31', mitgliedsnummer: '4709914', beitragsart: 'Voller Beitrag', aktualisiert: '2026-01-02',
      telefon: [{ wert: '+49 151 1112223', label: 'Mobil' }],
      mail: [{ wert: 'karl.h@example.org', label: 'Privat' }],
      adressen: [{ label: 'Wohnort', zeilen: ['Bergstraße 40', '51063 Köln'] }],
      karte: 'ok', haushalt: [],
      rollen: [
        r('m', 'woe', '2009-09-01', '2011-08-31'),
        r('m', 'jufi', '2011-09-01', '2014-08-31'),
        r('m', 'pfadi', '2014-09-01', '2017-08-31'),
        r('m', 'rover', '2017-09-01', '2020-08-31'),
        r('h', 'pfadi', '2019-09-01', '2025-12-31'),
      ],
      efz: { status: 'abgelaufen', ausgestellt: '2019-10-01', eingesehen: '2019-10-15', bis: '2024-10-01' },
      qualis: [{ label: 'Präventionsschulung', am: '2019-05-11', bis: '2024-05-11', reaktivierbar: true }],
    },
  };

  window.MITGLIED = { HEUTE, palette, stufenfarben, stufen, personen, AKTIVER_LAYER, STAMM, BEZIRK, DV };
})();

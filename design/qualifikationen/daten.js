// Synthetische Daten für die Entwürfe der Qualifikationen-Übersicht.
// Palette und Stufen kommen aus ../mitglied/daten.js (window.MITGLIED).
// Stichtag ist fest, damit die Entwürfe nicht vom echten Datum abhängen.
(function () {
  const M = window.MITGLIED;
  const HEUTE = '2026-10-02';

  // Farben je Art. Grün, Orange und Rot sind für den Status reserviert.
  const arten = {
    efz: { id: 'efz', label: 'Erweitertes Führungszeugnis', kurz: 'EFZ', icon: 'shield', farbe: '#2f5d8a', gueltig: 5, quelle: 'app' },
    praev: { id: 'praev', label: 'Präventionsschulung', kurz: 'Prävention', icon: 'hand', farbe: '#7b4fa0', gueltig: 5, quelle: 'hitobito', hitobitoId: 14 },
    eh: { id: 'eh', label: 'Erste-Hilfe-Kurs', kurz: 'Erste Hilfe', icon: 'cross', farbe: '#00838f', gueltig: 2, quelle: 'hitobito', hitobitoId: 9 },
    wb: { id: 'wb', label: 'Woodbadge', kurz: 'Woodbadge', icon: 'award', farbe: '#8d6e63', gueltig: null, quelle: 'hitobito', hitobitoId: 3 },
    modul: { id: 'modul', label: 'Modulausbildung', kurz: 'Modul', icon: 'book', farbe: '#546e7a', gueltig: null, quelle: 'hitobito', hitobitoId: 5 },
    juleica: { id: 'juleica', label: 'Juleica', kurz: 'Juleica', icon: 'id', farbe: '#3d6fb6', gueltig: 3, quelle: 'hitobito', hitobitoId: 21, reaktivierbar: true },
    // Früher in einem anderen Stamm gesehen, im aktuellen Kontext niemand.
    san: { id: 'san', label: 'Sanitätsdienst', kurz: 'Sanitätsdienst', icon: 'cross', farbe: '#6d4c41', gueltig: 3, quelle: 'hitobito', hitobitoId: 30, nichtImKontext: true },
  };

  // Rollen: l = Leitung (mit Stufe), s = Amt (mit Label), m = Mitglied (mit Stufe).
  const L = (stufe) => ({ art: 'l', stufe });
  const S = (label) => ({ art: 's', label });
  const Mi = (stufe) => ({ art: 'm', stufe });
  // q: Art → Ausstellung (ISO) bzw. bei EFZ das Ausstellungsdatum der Einsichtnahme.
  const personen = [
    { id: 1, name: 'Funke', voll: 'Lena Brandt', alter: 30, rollen: [L('rover'), L('woe')], eigene: true, q: { efz: '2021-11-20', praev: '2023-03-04', eh: '2025-02-15', wb: '2019-06-10', juleica: '2020-05-01' } },
    { id: 2, name: 'Jonas Keller', alter: 24, rollen: [L('pfadi')], q: { efz: '2023-05-12', praev: '2021-09-10', eh: '2024-11-01', modul: '2022-04-02' } },
    { id: 3, name: 'Mira Schulz', alter: 27, rollen: [L('jufi')], q: { efz: '2022-01-15', praev: '2024-02-03' } },
    { id: 4, name: 'Tobias Wendt', alter: 35, rollen: [S('Stammesvorstand')], q: { efz: '2024-03-01', praev: '2022-06-18', eh: '2023-03-11', wb: '2015-07-01' } },
    { id: 5, name: 'Anna Petersen', alter: 22, rollen: [L('biber')], q: { praev: '2025-05-10', eh: '2025-04-12' } },
    { id: 6, name: 'Paul Brandt', alter: 19, rollen: [L('woe'), Mi('rover')], q: { efz: '2025-01-20', praev: '2025-03-01', eh: '2024-08-24' } },
    { id: 7, name: 'Bernd Hollmann', alter: 58, rollen: [S('Kurat')], q: { efz: '2021-12-01', praev: '2021-12-04' } },
    { id: 8, name: 'Sophie Lang', alter: 29, rollen: [L('rover')], q: { efz: '2024-06-02', praev: '2024-06-15', eh: '2025-09-20', modul: '2023-11-11' } },
    { id: 9, name: 'Malte Fischer', alter: 31, rollen: [S('Kassenwart*in')], q: { efz: '2023-02-14', praev: '2023-02-25' } },
    { id: 10, name: 'Clara Neumann', alter: 26, rollen: [L('pfadi')], q: { efz: '2020-10-01', praev: '2020-09-12', eh: '2025-06-07' } },
    { id: 11, name: 'Erik Wolf', alter: 23, rollen: [L('jufi')], q: { efz: '2025-08-30', praev: '2025-09-06', eh: '2026-01-17' } },
    { id: 12, name: 'Jana Krüger', alter: 40, rollen: [S('Stammesvorstand')], q: { efz: '2022-12-03', praev: '2023-01-21', eh: '2024-12-10' } },
    { id: 13, name: 'Sami Yilmaz', alter: 20, rollen: [Mi('rover')], q: { eh: '2025-03-08' } },
    { id: 14, name: 'Lea Hahn', alter: 17, rollen: [Mi('rover')], q: {} },
    { id: 15, name: 'Ida Okafor', alter: 12, rollen: [Mi('jufi')], q: {} },
    { id: 16, name: 'Mats Okafor', alter: 8, rollen: [Mi('woe')], q: {} },
  ];

  // Vorgefertigte Personenkreise; „Leitung oder Amt“ entspricht der heutigen EFZ-Regel.
  const kreise = {
    leitungAmt: { label: 'Leitung oder Amt', desc: 'Jede aktive Rolle außer Mitglied', test: (p) => p.rollen.some((r) => r.art !== 'm') },
    leitung: { label: 'Leitende', desc: 'Leitung oder Hilfsleitung in einer Stufe', test: (p) => p.rollen.some((r) => r.art === 'l') },
    vorstand: { label: 'Vorstand und Kurat', desc: 'Stammesvorstand, Kurat*in', test: (p) => p.rollen.some((r) => r.art === 's' && /vorstand|kurat/i.test(r.label)) },
    ab16: { label: 'Alle ab 16 Jahren', desc: 'Jede Rolle, Alter ab 16', test: (p) => p.alter >= 16 },
  };

  const standard = {
    angezeigt: ['efz', 'praev', 'eh'],
    einstellungen: {
      efz: { kreis: 'leitungAmt', vorlauf: 90, umfang: 'alle', gueltig: 5 },
      praev: { kreis: 'leitungAmt', vorlauf: 90, umfang: 'alle' },
      eh: { kreis: 'leitung', vorlauf: 60, umfang: 'meine' },
      juleica: { kreis: 'leitung', vorlauf: 90, umfang: 'meine' },
      wb: { kreis: 'leitung', vorlauf: null, umfang: 'meine' },
      modul: { kreis: 'leitung', vorlauf: null, umfang: 'meine' },
      san: { kreis: 'leitung', vorlauf: 90, umfang: 'meine' },
    },
  };

  // ------------------------------------------------------------- Berechnung
  const t = (s) => Date.parse(`${s}T00:00:00Z`);
  const TAG = 864e5;
  const plusJahre = (iso, j) => { const [y, m, d] = iso.split('-'); return `${Number(y) + j}-${m}-${d}`; };
  function gueltigBis(p, art, einst) {
    const am = p.q[art.id];
    if (!am) return null;
    const jahre = art.id === 'efz' ? (einst?.gueltig ?? art.gueltig) : art.gueltig;
    return jahre ? plusJahre(am, jahre) : 'ohne';
  }
  function status(p, art, einst) {
    const bis = gueltigBis(p, art, einst);
    if (bis === null) return { s: 'fehlt', bis };
    if (bis === 'ohne') return { s: 'ok', bis };
    const tage = Math.round((t(bis) - t(HEUTE)) / TAG);
    if (tage < 0) return { s: 'ueber', bis, tage };
    if (tage <= (einst?.vorlauf ?? 90)) return { s: 'bald', bis, tage };
    return { s: 'ok', bis, tage };
  }
  function kreisVon(einst) { return kreise[einst?.kreis || 'leitung']; }
  function auswertung(artId, einstellungen = standard.einstellungen) {
    const art = arten[artId];
    const einst = einstellungen[artId];
    const kreis = kreisVon(einst);
    const leute = personen.filter(kreis.test).map((p) => ({ p, ...status(p, art, einst) }));
    const n = (s) => leute.filter((x) => x.s === s).length;
    const ord = { fehlt: 0, ueber: 1, bald: 2, ok: 3 };
    leute.sort((a, b) => ord[a.s] - ord[b.s] || String(a.bis).localeCompare(String(b.bis)));
    return { art, einst, kreis, leute, benoetigt: leute.length, ok: n('ok'), bald: n('bald'), ueber: n('ueber'), fehlt: n('fehlt'), erfuellt: n('ok') + n('bald') };
  }

  window.QDATEN = { M, HEUTE, arten, personen, kreise, standard, gueltigBis, status, auswertung, plusJahre };
})();

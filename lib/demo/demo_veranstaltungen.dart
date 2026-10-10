import '../domain/veranstaltung/veranstaltung.dart';
import 'demo_staemme.dart';

/// Kurse und Veranstaltungen im Demo, alle Termine relativ zu [jetzt]. Nur
/// Hitobito-Core-Felder; ein externer Anmeldelink fehlt bewusst, weil das
/// Demo keine Seiten im Netz oeffnet.
List<Veranstaltung> demoVeranstaltungen(DateTime jetzt) {
  final heute = DateTime(jetzt.year, jetzt.month, jetzt.day);
  DateTime um(int tage, int stunde, [int minute = 0]) =>
      DateTime(heute.year, heute.month, heute.day + tage, stunde, minute);
  DateTime tag(int tage) => DateTime(heute.year, heute.month, heute.day + tage);

  const ausbildung = KursartKategorie(id: 1, label: 'Ausbildung');
  const ersteHilfe = KursartKategorie(id: 2, label: 'Erste Hilfe');
  const gruppenleitung = Kursart(
    id: 1,
    label: 'Gruppenleitungskurs',
    kurzname: 'GLK',
    kategorie: ausbildung,
    mindestalter: 16,
    allgemeineInfos:
        'Grundlagen der Gruppenarbeit: Methoden, Aufsicht, Spielpädagogik.',
    voraussetzungen: 'Gültige Erste-Hilfe-Ausbildung.',
  );
  const ersteHilfeKurs = Kursart(
    id: 2,
    label: 'Erste-Hilfe-Kurs',
    kurzname: 'EH',
    kategorie: ersteHilfe,
    mindestalter: 14,
    allgemeineInfos: 'Neun Unterrichtseinheiten Erste Hilfe mit Outdoor-Teil.',
  );
  const praevention = Kursart(
    id: 3,
    label: 'Präventionsschulung',
    kurzname: 'PRÄ',
    kategorie: ausbildung,
    mindestalter: 16,
    allgemeineInfos: 'Pflichtschulung für alle Leitenden.',
  );
  const johanna = VeranstaltungsPerson(id: 1061, name: 'Johanna Becker');
  const martin = VeranstaltungsPerson(id: 3001, name: 'Martin Krause');
  const svenja = VeranstaltungsPerson(id: 3002, name: 'Svenja Albers');

  return <Veranstaltung>[
    Veranstaltung(
      id: 9101,
      art: VeranstaltungsArt.veranstaltung,
      name: 'Herbstaktion Silberfels',
      motto: 'Gemeinsam unterwegs',
      beschreibung: 'Tagesaktion für alle Stufen mit Geländespiel und Grillen.',
      ort: 'Stammesheim Silberfels',
      kosten: '5 €',
      anmeldungAb: tag(-14),
      anmeldungBis: tag(10),
      kontakt: johanna,
      gruppenIds: const [DemoBezirk.silberfelsId],
      termine: [
        VeranstaltungsTermin(
          label: 'Aktionstag',
          beginn: um(14, 10),
          ende: um(14, 17),
        ),
      ],
    ),
    Veranstaltung(
      id: 9102,
      art: VeranstaltungsArt.veranstaltung,
      name: 'Winterlager Silberfels',
      beschreibung: 'Ein Wochenende im Selbstversorgerhaus für alle Stufen.',
      ort: 'Jugendhaus am See',
      kosten: '45 €',
      anmeldungAb: tag(-30),
      anmeldungBis: tag(30),
      kontakt: johanna,
      gruppenIds: const [DemoBezirk.silberfelsId],
      termine: [
        VeranstaltungsTermin(
          label: 'Vorbereitungstreffen',
          beginn: um(21, 18),
          ende: um(21, 20),
          ort: 'Stammesheim Silberfels',
        ),
        VeranstaltungsTermin(
          label: 'Lager',
          beginn: um(42, 17),
          ende: um(44, 13),
          ort: 'Jugendhaus am See',
        ),
      ],
    ),
    Veranstaltung(
      id: 9103,
      art: VeranstaltungsArt.veranstaltung,
      name: 'Kinoabend Birkenhain',
      beschreibung:
          'Filmabend im Gemeindesaal, Gäste aus dem Bezirk willkommen.',
      ort: 'Gemeindesaal Birkenhain',
      anmeldungAb: tag(-7),
      anmeldungBis: tag(18),
      gruppenIds: const [DemoBezirk.birkenhainId],
      termine: [VeranstaltungsTermin(beginn: um(20, 19), ende: um(20, 22))],
    ),
    Veranstaltung(
      id: 9104,
      art: VeranstaltungsArt.kurs,
      rohTyp: 'Event::Course',
      name: 'Gruppenleitungskurs Bezirk Silbertal',
      beschreibung: 'Zwei Wochenenden Ausbildung für neue Leitende im Bezirk.',
      ort: 'Jugendhaus Silbertal',
      kosten: '60 € inkl. Verpflegung',
      anmeldungAb: tag(-20),
      anmeldungBis: tag(25),
      maxTeilnehmende: 12,
      teilnehmende: 4,
      kursart: gruppenleitung,
      kontakt: martin,
      leitung: const [svenja],
      gruppenIds: const [DemoBezirk.bezirkId],
      termine: [
        VeranstaltungsTermin(
          label: 'Wochenende 1',
          beginn: um(35, 18),
          ende: um(37, 14),
        ),
        VeranstaltungsTermin(
          label: 'Wochenende 2',
          beginn: um(49, 18),
          ende: um(51, 14),
        ),
      ],
    ),
    Veranstaltung(
      id: 9105,
      art: VeranstaltungsArt.kurs,
      rohTyp: 'Event::Course',
      name: 'Erste-Hilfe-Kurs ${DemoBezirk.dioezeseName}',
      beschreibung: 'Erste Hilfe mit Schwerpunkt Lager und Fahrt.',
      ort: 'Diözesanzentrum',
      kosten: '25 €',
      anmeldungAb: tag(21),
      anmeldungBis: tag(60),
      maxTeilnehmende: 16,
      teilnehmende: 0,
      kursart: ersteHilfeKurs,
      gruppenIds: const [DemoBezirk.dioezeseId],
      termine: [
        VeranstaltungsTermin(
          label: 'Kurstag',
          beginn: um(76, 9),
          ende: um(76, 17),
        ),
      ],
    ),
    Veranstaltung(
      id: 9106,
      art: VeranstaltungsArt.kurs,
      rohTyp: 'Event::Course',
      name: 'Präventionsschulung ${DemoBezirk.dioezeseName}',
      beschreibung: 'Präventionsschulung für Leitende aller Stufen.',
      ort: 'Online',
      anmeldungAb: tag(-60),
      anmeldungBis: tag(-5),
      maxTeilnehmende: 10,
      teilnehmende: 10,
      kursart: praevention,
      gruppenIds: const [DemoBezirk.dioezeseId],
      termine: [
        VeranstaltungsTermin(
          label: 'Schulung',
          beginn: um(14, 10),
          ende: um(14, 16),
        ),
      ],
    ),
    Veranstaltung(
      id: 9107,
      art: VeranstaltungsArt.veranstaltung,
      name: 'Bezirksversammlung Silbertal',
      gruppenIds: const [DemoBezirk.bezirkId],
      termine: [VeranstaltungsTermin(beginn: um(28, 19), ende: um(28, 21, 30))],
    ),
    Veranstaltung(
      id: 9108,
      art: VeranstaltungsArt.veranstaltung,
      name: 'Waldputzaktion Silberfels',
      ort: 'Parkplatz Silberwald',
      gruppenIds: const [DemoBezirk.silberfelsId],
      termine: [VeranstaltungsTermin(beginn: um(-30, 9), ende: um(-30, 13))],
    ),
  ];
}

/// Namen der veranstaltenden Gruppen im Demo.
const Map<int, String> demoVeranstalterNamen = {
  DemoBezirk.silberfelsId: 'Stamm Silberfels',
  DemoBezirk.birkenhainId: 'Stamm Birkenhain',
  DemoBezirk.bezirkId: 'Bezirk Silbertal',
  DemoBezirk.dioezeseId: DemoBezirk.dioezeseName,
};

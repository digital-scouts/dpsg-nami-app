/// Art eines Hitobito-Events. Im Core gibt es nur `Event` und
/// `Event::Course`; andere Typen aus Wagons gelten als Veranstaltung.
enum VeranstaltungsArt { kurs, veranstaltung }

/// Ein Termin (`Event::Date`) eines Events. Ein Event hat mindestens einen.
class VeranstaltungsTermin {
  const VeranstaltungsTermin({
    required this.beginn,
    this.ende,
    this.label,
    this.ort,
  });

  final DateTime beginn;
  final DateTime? ende;
  final String? label;
  final String? ort;

  /// Ende oder, falls keines gepflegt ist, der Beginn.
  DateTime get letzterZeitpunkt => ende ?? beginn;
}

/// Kurskategorie (`Event::KindCategory`), z. B. „Ausbildung“.
class KursartKategorie {
  const KursartKategorie({required this.id, required this.label});

  final int id;
  final String label;

  @override
  bool operator ==(Object other) =>
      other is KursartKategorie && other.id == id && other.label == label;

  @override
  int get hashCode => Object.hash(id, label);
}

/// Kursart (`Event::Kind`) eines Kurses. Welche Qualifikationen sie vergibt,
/// liefert die API nicht.
class Kursart {
  const Kursart({
    required this.id,
    required this.label,
    this.kurzname,
    this.kategorie,
    this.mindestalter,
    this.allgemeineInfos,
    this.voraussetzungen,
  });

  final int id;
  final String label;
  final String? kurzname;
  final KursartKategorie? kategorie;
  final int? mindestalter;
  final String? allgemeineInfos;
  final String? voraussetzungen;
}

/// Kontakt- oder Leitungsperson eines Events.
class VeranstaltungsPerson {
  const VeranstaltungsPerson({required this.id, required this.name});

  final int id;
  final String name;
}

/// Ein Kurs oder eine Veranstaltung aus `/api/events`.
class Veranstaltung {
  Veranstaltung({
    required this.id,
    required this.art,
    required this.name,
    required List<VeranstaltungsTermin> termine,
    required this.gruppenIds,
    this.rohTyp,
    this.motto,
    this.beschreibung,
    this.ort,
    this.kosten,
    this.anmeldungAb,
    this.anmeldungBis,
    this.maxTeilnehmende,
    this.teilnehmende,
    this.kursart,
    this.anmeldeLinkExtern,
    this.voraussetzungen,
    this.kontakt,
    this.leitung = const <VeranstaltungsPerson>[],
  }) : termine = List.unmodifiable(
         [...termine]..sort((a, b) => a.beginn.compareTo(b.beginn)),
       );

  final int id;
  final VeranstaltungsArt art;

  /// `type` aus der API; `null` bei einfachen Events.
  final String? rohTyp;
  final String name;

  /// Nach Beginn sortiert.
  final List<VeranstaltungsTermin> termine;
  final List<int> gruppenIds;
  final String? motto;
  final String? beschreibung;
  final String? ort;
  final String? kosten;

  /// Anmeldefenster als Kalendertage (Hitobito speichert Daten ohne Zeit).
  final DateTime? anmeldungAb;
  final DateTime? anmeldungBis;
  final int? maxTeilnehmende;

  /// Nur bei Kursen von der API geliefert.
  final int? teilnehmende;
  final Kursart? kursart;

  /// Oeffentliche Anmeldeseite, wenn das Event externe Anmeldungen erlaubt.
  final Uri? anmeldeLinkExtern;

  /// Anmeldebedingungen des Events (`application_conditions`).
  final String? voraussetzungen;
  final VeranstaltungsPerson? kontakt;
  final List<VeranstaltungsPerson> leitung;

  bool get istKurs => art == VeranstaltungsArt.kurs;

  VeranstaltungsTermin? get ersterTermin =>
      termine.isEmpty ? null : termine.first;

  DateTime? get beginn => ersterTermin?.beginn;

  /// Spaetester Zeitpunkt ueber alle Termine.
  DateTime? get ende {
    DateTime? ende;
    for (final termin in termine) {
      final zeitpunkt = termin.letzterZeitpunkt;
      if (ende == null || zeitpunkt.isAfter(ende)) {
        ende = zeitpunkt;
      }
    }
    return ende;
  }

  /// Freie Plaetze, sofern Maximum und Belegung bekannt sind.
  int? get freiePlaetze {
    final max = maxTeilnehmende;
    final belegt = teilnehmende;
    if (max == null || max <= 0 || belegt == null) {
      return null;
    }
    final frei = max - belegt;
    return frei < 0 ? 0 : frei;
  }

  Veranstaltung copyWith({
    VeranstaltungsPerson? kontakt,
    List<VeranstaltungsPerson>? leitung,
    Kursart? kursart,
  }) {
    return Veranstaltung(
      id: id,
      art: art,
      rohTyp: rohTyp,
      name: name,
      termine: termine,
      gruppenIds: gruppenIds,
      motto: motto,
      beschreibung: beschreibung,
      ort: ort,
      kosten: kosten,
      anmeldungAb: anmeldungAb,
      anmeldungBis: anmeldungBis,
      maxTeilnehmende: maxTeilnehmende,
      teilnehmende: teilnehmende,
      kursart: kursart ?? this.kursart,
      anmeldeLinkExtern: anmeldeLinkExtern,
      voraussetzungen: voraussetzungen,
      kontakt: kontakt ?? this.kontakt,
      leitung: leitung ?? this.leitung,
    );
  }
}

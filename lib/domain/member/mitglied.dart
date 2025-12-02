import '../taetigkeit/stufe.dart';
import '../taetigkeit/taetigkeit.dart';

/// Repräsentiert ein Mitglied der DPSG – reine Domain-Entität (keine Flutter Abhängigkeiten).
/// Pflichtfelder: Vorname, Nachname, Geburtsdatum, Eintrittsdatum, Mitgliedsnummer.
/// Optionale Felder: Fahrtenname, Austrittsdatum.
class Mitglied {
  Mitglied({
    required this.vorname,
    required this.nachname,
    this.fahrtenname,
    required this.geburtsdatum,
    required this.eintrittsdatum,
    this.austrittsdatum,
    required this.mitgliedsnummer,
    this.telefon1,
    this.telefon2,
    this.telefon3,
    this.email1,
    this.email2,
    List<Taetigkeit>? taetigkeiten,
  }) : assert(vorname.isNotEmpty),
       assert(nachname.isNotEmpty),
       assert(mitgliedsnummer.isNotEmpty),
       taetigkeiten = List.unmodifiable(taetigkeiten ?? const []);

  final String vorname;
  final String nachname;
  final String? fahrtenname;
  final DateTime geburtsdatum;
  final DateTime eintrittsdatum;
  final DateTime? austrittsdatum;
  final String mitgliedsnummer;
  final String? telefon1; // Festnetz
  final String? telefon2; // Mobil
  final String? telefon3; // Geschäftlich
  final String? email1;
  final String? email2;
  final List<Taetigkeit> taetigkeiten;

  bool get istAusgetreten =>
      austrittsdatum != null && austrittsdatum!.isBefore(DateTime.now());

  Mitglied copyWith({
    String? vorname,
    String? nachname,
    String? fahrtenname,
    DateTime? geburtsdatum,
    DateTime? eintrittsdatum,
    DateTime? austrittsdatum,
    String? mitgliedsnummer,
    String? telefon1,
    String? telefon2,
    String? telefon3,
    String? email1,
    String? email2,
    List<Taetigkeit>? taetigkeiten,
  }) => Mitglied(
    vorname: vorname ?? this.vorname,
    nachname: nachname ?? this.nachname,
    fahrtenname: fahrtenname ?? this.fahrtenname,
    geburtsdatum: geburtsdatum ?? this.geburtsdatum,
    eintrittsdatum: eintrittsdatum ?? this.eintrittsdatum,
    austrittsdatum: austrittsdatum ?? this.austrittsdatum,
    mitgliedsnummer: mitgliedsnummer ?? this.mitgliedsnummer,
    telefon1: telefon1 ?? this.telefon1,
    telefon2: telefon2 ?? this.telefon2,
    telefon3: telefon3 ?? this.telefon3,
    email1: email1 ?? this.email1,
    email2: email2 ?? this.email2,
    taetigkeiten: taetigkeiten ?? this.taetigkeiten,
  );

  Mitglied addTaetigkeit(Taetigkeit t) =>
      copyWith(taetigkeiten: [...taetigkeiten, t]);

  @override
  bool operator ==(Object other) {
    return other is Mitglied &&
        other.vorname == vorname &&
        other.nachname == nachname &&
        other.fahrtenname == fahrtenname &&
        other.geburtsdatum == geburtsdatum &&
        other.eintrittsdatum == eintrittsdatum &&
        other.austrittsdatum == austrittsdatum &&
        other.mitgliedsnummer == mitgliedsnummer &&
        other.telefon1 == telefon1 &&
        other.telefon2 == telefon2 &&
        other.telefon3 == telefon3 &&
        other.email1 == email1 &&
        other.email2 == email2 &&
        _listEquals(other.taetigkeiten, taetigkeiten);
  }

  @override
  int get hashCode => Object.hash(
    vorname,
    nachname,
    fahrtenname,
    geburtsdatum,
    eintrittsdatum,
    austrittsdatum,
    mitgliedsnummer,
    telefon1,
    telefon2,
    telefon3,
    email1,
    email2,
    Object.hashAll(taetigkeiten),
  );

  static bool _listEquals(List<Taetigkeit> a, List<Taetigkeit> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  String toString() {
    final buffer = StringBuffer('Mitglied(');
    buffer.write('mitgliedsnummer: $mitgliedsnummer, ');
    buffer.write('vorname: $vorname, ');
    buffer.write('nachname: $nachname');

    if (fahrtenname != null) {
      buffer.write(', fahrtenname: $fahrtenname');
    }

    buffer.write(
      ', geburtsdatum: ${geburtsdatum.toIso8601String().split('T')[0]}',
    );
    buffer.write(
      ', eintrittsdatum: ${eintrittsdatum.toIso8601String().split('T')[0]}',
    );

    if (austrittsdatum != null) {
      buffer.write(
        ', austrittsdatum: ${austrittsdatum!.toIso8601String().split('T')[0]}',
      );
    }

    if (taetigkeiten.isNotEmpty) {
      buffer.write(', taetigkeiten: [');
      for (var i = 0; i < taetigkeiten.length; i++) {
        if (i > 0) buffer.write(', ');
        buffer.write(taetigkeiten[i].toString());
      }
      buffer.write(']');
    }

    buffer.write(')');
    return buffer.toString();
  }
}

/// Beispiel-Fabrik für Demo/Storybook / Reinschnuppern-Modus.
class MitgliedFactory {
  static Mitglied demo({int index = 1}) {
    final now = DateTime.now();
    // Streuung für Demo-Daten: Alter, Eintrittsdatum, Telefonnummern, Tätigkeiten variieren anhand Index.
    final ageYears = 12 + (index % 17); // 12..28
    final birthMonth = 1 + (index % 12);
    final birthDay = 1 + (index % 28);
    final geburtsdatum = DateTime(now.year - ageYears, birthMonth, birthDay);

    final membershipYears = 1 + (index % 10); // 1..10 Jahre Mitglied
    final eintrittsdatum = DateTime(
      now.year - membershipYears,
      (birthMonth % 12) + 1,
      (birthDay % 27) + 1,
    );

    // Fahrtenname Variationen
    const fahrtenNamen = [
      'Falke',
      'Luchs',
      'Bergwolf',
      'Rotfuchs',
      'Habicht',
      'Milan',
      'Dachs',
      'Iltis',
      'Marder',
      'Wiesel',
      'Eisvogel',
      'Fjord',
    ];
    final fahrtenname = index % 2 == 0
        ? fahrtenNamen[index % fahrtenNamen.length]
        : null;

    // Telefonnummern (einige optional)
    final telMobil =
        '+49 17${(10 + index % 80).toString().padLeft(2, '0')} ${900000 + index}';
    final telFestnetz = index % 2 == 0 ? '+49 30 ${400000 + index}' : null;
    final telBusiness = index % 5 == 0 ? '+49 221 ${500000 + index}' : null;

    // E-Mails (zweite manchmal optional)
    final email1 = 'mitglied$index@example.org';
    final email2 = index % 4 == 0
        ? '${fahrtenname?.toLowerCase() ?? 'alias'}$index@scoutmail.de'
        : null;

    // Dynamische Tätigkeiten: Grundmitglied plus optional Leitung / Stufenwechsel
    return Mitglied(
      vorname: 'Max',
      nachname: 'Mustermann$index',
      fahrtenname: fahrtenname,
      geburtsdatum: geburtsdatum,
      eintrittsdatum: eintrittsdatum,
      mitgliedsnummer: 'M-${DateTime.now().millisecondsSinceEpoch}-$index',
      telefon1: telFestnetz,
      telefon2: telMobil,
      telefon3: telBusiness,
      email1: email1,
      email2: email2,
      taetigkeiten: [
        Taetigkeit(
          stufe: switch (index % 5) {
            0 => Stufe.woelfling,
            1 => Stufe.jungpfadfinder,
            2 => Stufe.pfadfinder,
            3 => Stufe.rover,
            _ => Stufe.pfadfinder,
          },
          art: TaetigkeitsArt.mitglied,
          start: eintrittsdatum,
        ),
        if (index % 6 == 0)
          Taetigkeit(
            stufe: Stufe.rover,
            art: TaetigkeitsArt.leitung,
            start: DateTime(
              eintrittsdatum.year + 2,
              eintrittsdatum.month,
              eintrittsdatum.day,
            ),
          ),
      ],
    );
  }
}

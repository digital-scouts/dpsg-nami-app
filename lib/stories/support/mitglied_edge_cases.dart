import 'package:nami/domain/member/efz_einsichtnahme.dart';
import 'package:nami/domain/member/mitglied.dart';
import 'package:nami/domain/qualifikation/qualifikation.dart';
import 'package:nami/domain/taetigkeit/roles.dart';

/// Edge-Case-Personen der Mitgliedsdetails, angelehnt an die Entwuerfe in
/// `design/mitglied/daten.js`. Fester Stichtag, damit Stories nicht vom
/// echten Datum abhaengen. Vergangene Rollen sind enthalten, obwohl die API
/// sie derzeit nicht liefert.
abstract final class MitgliedEdgeCases {
  static final DateTime heute = DateTime(2026, 10, 2);

  static const String stamm = 'Stamm Silberfels';
  static const String bezirk = 'Bezirk Rheinauen';
  static const String dv = 'DV Talheim';

  static Role _rolle(
    String typ,
    String label, {
    required String gruppe,
    String layer = stamm,
    required DateTime start,
    DateTime? ende,
    bool ohneStart = false,
  }) => Role(
    id: Object.hash(typ, label, start).abs(),
    type: typ,
    label: label,
    startOn: ohneStart ? null : start,
    createdAt: start,
    endOn: ende,
    groupName: gruppe,
    layerName: layer,
  );

  static Role _mitglied(
    String stufe,
    String gruppe,
    DateTime start, [
    DateTime? ende,
    bool ohneStart = false,
  ]) => _rolle(
    'Group::StammGruppe$stufe::Mitglied',
    'Mitglied',
    gruppe: gruppe,
    start: start,
    ende: ende,
    ohneStart: ohneStart,
  );

  static Role _leitung(
    String stufe,
    String gruppe,
    DateTime start, [
    DateTime? ende,
    String label = 'Leiter*in',
  ]) => _rolle(
    'Group::StammGruppe$stufe::Leitung',
    label,
    gruppe: gruppe,
    start: start,
    ende: ende,
  );

  static Role _amt(
    String label, {
    String gruppe = stamm,
    String layer = stamm,
    required DateTime start,
    DateTime? ende,
  }) => _rolle(
    'Group::Amt',
    label,
    gruppe: gruppe,
    layer: layer,
    start: start,
    ende: ende,
  );

  /// Funke: viele Rollen ueber 22 Jahre, mehrere Layer, Leitung in zwei
  /// Stufen parallel, eine geplante Rolle.
  static final Mitglied funke = Mitglied(
    personId: 9101,
    mitgliedsnummer: '4711203',
    vorname: 'Lena',
    nachname: 'Brandt',
    fahrtenname: 'Funke',
    geburtsdatum: DateTime(1996, 3, 14),
    eintrittsdatum: DateTime(2004, 4, 1),
    gender: 'w',
    pronoun: 'sie/ihr',
    telefonnummern: const <MitgliedKontaktTelefon>[
      MitgliedKontaktTelefon(wert: '+49 170 1234567', label: 'Mobil'),
      MitgliedKontaktTelefon(wert: '+49 221 998877', label: 'Arbeit'),
    ],
    emailAdressen: const <MitgliedKontaktEmail>[
      MitgliedKontaktEmail(
        wert: 'lena.brandt@example.org',
        label: 'Privat',
        istPrimaer: true,
      ),
      MitgliedKontaktEmail(wert: 'funke@stamm-silberfels.de', label: 'Stamm'),
    ],
    adressen: const <MitgliedKontaktAdresse>[
      MitgliedKontaktAdresse(
        additionalAddressId: 0,
        street: 'Lindenstraße',
        housenumber: '12',
        zipCode: '50667',
        town: 'Köln',
        country: 'DE',
      ),
    ],
    roles: <Role>[
      _mitglied(
        'Woelflinge',
        'Meute Seeonee',
        DateTime(2004, 4, 1),
        DateTime(2007, 8, 31),
      ),
      _mitglied(
        'Jungpfadfinder',
        'Trupp Kompass',
        DateTime(2007, 9, 1),
        DateTime(2010, 8, 31),
      ),
      _mitglied(
        'Pfadfinder',
        'Trupp Polarstern',
        DateTime(2010, 9, 1),
        DateTime(2013, 8, 31),
      ),
      _mitglied(
        'Rover',
        'Runde Fernweh',
        DateTime(2013, 9, 1),
        DateTime(2016, 8, 31),
      ),
      _leitung(
        'Jungpfadfinder',
        'Trupp Kompass',
        DateTime(2014, 9, 1),
        DateTime(2017, 8, 31),
        'Hilfsleiter*in',
      ),
      _amt(
        'Materialwart*in',
        start: DateTime(2016, 1, 1),
        ende: DateTime(2019, 12, 31),
      ),
      _leitung(
        'Pfadfinder',
        'Trupp Polarstern',
        DateTime(2017, 9, 1),
        DateTime(2022, 8, 31),
      ),
      _amt(
        'Stv. Stammesführer*in',
        start: DateTime(2020, 5, 1),
        ende: DateTime(2024, 4, 30),
      ),
      _amt(
        'Mitarbeiter*in Unterlager',
        gruppe: 'Bundeslager 2022',
        layer: dv,
        start: DateTime(2022, 7, 1),
        ende: DateTime(2022, 8, 15),
      ),
      _leitung('Rover', 'Runde Fernweh', DateTime(2022, 9, 1)),
      _amt(
        'AK Mitarbeiter*in',
        gruppe: 'AK Wölflingsstufe',
        layer: bezirk,
        start: DateTime(2023, 1, 1),
      ),
      _leitung('Woelflinge', 'Meute Seeonee', DateTime(2024, 9, 1)),
      _amt('Bezirksdelegierte*r', start: DateTime(2024, 5, 1)),
      _amt(
        'AK Leiter*in',
        gruppe: 'Ausbildung',
        layer: dv,
        start: DateTime(2025, 3, 1),
      ),
      _amt('Stammesbeauftragte*r Prävention', start: DateTime(2026, 11, 1)),
    ],
  );

  /// Mats: seit einer Woche dabei, viele Kontakte, Zusatzadressen, Familie.
  static final Mitglied mats = Mitglied(
    personId: 9102,
    mitgliedsnummer: '4729981',
    vorname: 'Mats',
    nachname: 'Okafor',
    geburtsdatum: DateTime(2018, 5, 9),
    eintrittsdatum: DateTime(2026, 9, 25),
    gender: 'm',
    householdKey: 'story-okafor',
    telefonnummern: const <MitgliedKontaktTelefon>[
      MitgliedKontaktTelefon(wert: '+49 171 5550101', label: 'Mama mobil'),
      MitgliedKontaktTelefon(wert: '+49 172 5550102', label: 'Papa mobil'),
      MitgliedKontaktTelefon(wert: '+49 221 555010', label: 'Festnetz'),
      MitgliedKontaktTelefon(wert: '+49 228 777123', label: 'Oma Ruth'),
      MitgliedKontaktTelefon(wert: '+49 160 9988776', label: 'Notfall'),
    ],
    emailAdressen: const <MitgliedKontaktEmail>[
      MitgliedKontaktEmail(
        wert: 'ada.okafor@example.org',
        label: 'Mama',
        istPrimaer: true,
      ),
      MitgliedKontaktEmail(wert: 'ben.okafor@example.org', label: 'Papa'),
      MitgliedKontaktEmail(
        wert: 'familie.okafor@example.org',
        label: 'Familie',
      ),
    ],
    adressen: const <MitgliedKontaktAdresse>[
      MitgliedKontaktAdresse(
        additionalAddressId: 0,
        street: 'Am Mühlbach',
        housenumber: '3',
        zipCode: '50999',
        town: 'Köln',
        country: 'DE',
      ),
      MitgliedKontaktAdresse(
        additionalAddressId: 21,
        label: 'Papa',
        street: 'Venloer Straße',
        housenumber: '210',
        zipCode: '50823',
        town: 'Köln',
        country: 'DE',
      ),
      MitgliedKontaktAdresse(
        additionalAddressId: 22,
        label: 'Oma',
        street: 'Kirchweg',
        housenumber: '5',
        zipCode: '53111',
        town: 'Bonn',
        country: 'DE',
      ),
    ],
    roles: <Role>[
      _mitglied('Woelflinge', 'Meute Seeonee', DateTime(2026, 9, 25)),
    ],
  );

  /// Geschwister von Mats im selben Haushalt.
  static final List<Mitglied> matsHaushalt = <Mitglied>[
    Mitglied(
      personId: 9111,
      mitgliedsnummer: '4729982',
      vorname: 'Ida',
      nachname: 'Okafor',
      geburtsdatum: DateTime(2014, 3, 2),
      eintrittsdatum: DateTime(2021, 9, 1),
      householdKey: 'story-okafor',
      roles: <Role>[
        _mitglied('Jungpfadfinder', 'Trupp Kompass', DateTime(2024, 9, 1)),
      ],
    ),
    Mitglied(
      personId: 9112,
      mitgliedsnummer: '4729983',
      vorname: 'Noah',
      nachname: 'Okafor',
      geburtsdatum: DateTime(2021, 6, 11),
      eintrittsdatum: DateTime(2025, 9, 1),
      householdKey: 'story-okafor',
      roles: <Role>[_mitglied('Biber', 'Biberbau', DateTime(2025, 9, 1))],
    ),
  ];

  /// Jonas: gleichzeitig Jufi und Pfadi.
  static final Mitglied jonas = Mitglied(
    personId: 9103,
    mitgliedsnummer: '4720450',
    vorname: 'Jonas',
    nachname: 'Weber',
    geburtsdatum: DateTime(2013, 2, 11),
    eintrittsdatum: DateTime(2020, 9, 1),
    gender: 'm',
    telefonnummern: const <MitgliedKontaktTelefon>[
      MitgliedKontaktTelefon(wert: '+49 176 4433221', label: 'Eltern'),
    ],
    roles: <Role>[
      _mitglied(
        'Woelflinge',
        'Meute Seeonee',
        DateTime(2020, 9, 1),
        DateTime(2023, 8, 31),
      ),
      _mitglied('Jungpfadfinder', 'Trupp Kompass', DateTime(2023, 9, 1)),
      _mitglied('Pfadfinder', 'Trupp Polarstern', DateTime(2026, 9, 1)),
    ],
  );

  /// Sami: Rover und Woelflings-Hilfsleitung, eine Rolle ohne Startdatum,
  /// eine geplante Leitung.
  static final Mitglied sami = Mitglied(
    personId: 9104,
    mitgliedsnummer: '4715532',
    vorname: 'Sami',
    nachname: 'Yilmaz',
    geburtsdatum: DateTime(2006, 7, 22),
    eintrittsdatum: DateTime(2013, 9, 1),
    gender: 'd',
    pronoun: 'er/ihm',
    roles: <Role>[
      _mitglied(
        'Woelflinge',
        'Meute Seeonee',
        DateTime(2013, 9, 1),
        DateTime(2016, 8, 31),
        true,
      ),
      _mitglied(
        'Jungpfadfinder',
        'Trupp Kompass',
        DateTime(2016, 9, 1),
        DateTime(2019, 8, 31),
      ),
      _mitglied(
        'Pfadfinder',
        'Trupp Polarstern',
        DateTime(2019, 9, 1),
        DateTime(2022, 8, 31),
      ),
      _mitglied('Rover', 'Runde Fernweh', DateTime(2022, 9, 1)),
      _leitung(
        'Woelflinge',
        'Meute Seeonee',
        DateTime(2025, 9, 1),
        null,
        'Hilfsleiter*in',
      ),
      _leitung('Woelflinge', 'Meute Seeonee', DateTime(2026, 11, 1)),
    ],
  );

  /// Petra: nur Aemter, keine Adresse, Geburtstag unbekannt.
  static final Mitglied petra = Mitglied(
    personId: 9105,
    mitgliedsnummer: '4718870',
    vorname: 'Petra',
    nachname: 'Lindner',
    geburtsdatum: Mitglied.peoplePlaceholderDate,
    eintrittsdatum: DateTime(2019, 3, 1),
    telefonnummern: const <MitgliedKontaktTelefon>[
      MitgliedKontaktTelefon(wert: '+49 221 4455667', label: 'Privat'),
    ],
    roles: <Role>[
      _amt('Stammesschatzmeister*in', start: DateTime(2019, 3, 1)),
      _amt(
        'Kassenprüfer*in',
        gruppe: bezirk,
        layer: bezirk,
        start: DateTime(2021, 4, 1),
      ),
    ],
  );

  /// Karl: ausgetreten, nur vergangene Rollen.
  static final Mitglied karl = Mitglied(
    personId: 9106,
    mitgliedsnummer: '4709914',
    vorname: 'Karl',
    nachname: 'Hoffmann',
    geburtsdatum: DateTime(2002, 1, 5),
    eintrittsdatum: DateTime(2009, 9, 1),
    austrittsdatum: DateTime(2025, 12, 31),
    gender: 'm',
    roles: <Role>[
      _mitglied(
        'Woelflinge',
        'Meute Seeonee',
        DateTime(2009, 9, 1),
        DateTime(2011, 8, 31),
      ),
      _mitglied(
        'Jungpfadfinder',
        'Trupp Kompass',
        DateTime(2011, 9, 1),
        DateTime(2014, 8, 31),
      ),
      _mitglied(
        'Pfadfinder',
        'Trupp Polarstern',
        DateTime(2014, 9, 1),
        DateTime(2017, 8, 31),
      ),
      _mitglied(
        'Rover',
        'Runde Fernweh',
        DateTime(2017, 9, 1),
        DateTime(2020, 8, 31),
      ),
      _leitung(
        'Pfadfinder',
        'Trupp Polarstern',
        DateTime(2019, 9, 1),
        DateTime(2025, 12, 31),
        'Hilfsleiter*in',
      ),
    ],
  );

  static final Map<String, Mitglied> alle = <String, Mitglied>{
    'Funke · Vielrolle, Mehrlayer': funke,
    'Mats · Neuling, Familie, viele Kontakte': mats,
    'Jonas · Jufi und Pfadi parallel': jonas,
    'Sami · Rover und Wö-Hilfsleitung': sami,
    'Petra · nur Ämter, ohne Adresse': petra,
    'Karl · ausgetreten': karl,
  };

  /// EFZ-Einsichtnahmen passend zu den Personen (Funke laeuft bald ab, Sami
  /// gueltig, Karl abgelaufen).
  static final List<EfzEinsichtnahme> efzEinsichtnahmen = <EfzEinsichtnahme>[
    EfzEinsichtnahme(
      id: 1,
      personId: funke.personId!,
      issuedOn: DateTime(2021, 11, 20),
      einsichtOn: DateTime(2021, 12, 2),
    ),
    EfzEinsichtnahme(
      id: 2,
      personId: sami.personId!,
      issuedOn: DateTime(2025, 8, 30),
      einsichtOn: DateTime(2025, 9, 12),
    ),
    EfzEinsichtnahme(
      id: 3,
      personId: karl.personId!,
      issuedOn: DateTime(2019, 10, 1),
      einsichtOn: DateTime(2019, 10, 15),
    ),
  ];

  static final List<Qualifikation> qualifikationen = <Qualifikation>[
    Qualifikation(
      id: 1,
      personId: funke.personId!,
      label: 'Woodbadge',
      qualifiedAt: DateTime(2019, 6, 10),
    ),
    Qualifikation(
      id: 2,
      personId: funke.personId!,
      label: 'Präventionsschulung',
      qualifiedAt: DateTime(2023, 3, 4),
      finishAt: DateTime(2028, 3, 4),
    ),
    Qualifikation(
      id: 3,
      personId: funke.personId!,
      label: 'Erste-Hilfe-Kurs',
      qualifiedAt: DateTime(2025, 2, 15),
      finishAt: DateTime(2027, 2, 15),
    ),
    Qualifikation(
      id: 4,
      personId: funke.personId!,
      label: 'Juleica',
      qualifiedAt: DateTime(2020, 5, 1),
      finishAt: DateTime(2023, 5, 1),
      reaktivierbar: true,
    ),
    Qualifikation(
      id: 5,
      personId: funke.personId!,
      label: 'Modulausbildung',
      qualifiedAt: DateTime(2016, 11, 12),
    ),
    Qualifikation(
      id: 6,
      personId: sami.personId!,
      label: 'Präventionsschulung',
      qualifiedAt: DateTime(2025, 6, 1),
      finishAt: DateTime(2030, 6, 1),
    ),
    Qualifikation(
      id: 7,
      personId: karl.personId!,
      label: 'Präventionsschulung',
      qualifiedAt: DateTime(2019, 5, 11),
      finishAt: DateTime(2024, 5, 11),
      reaktivierbar: true,
    ),
  ];
}

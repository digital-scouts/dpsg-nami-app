import 'package:nami/domain/arbeitskontext/arbeitskontext_read_model.dart';
import 'package:nami/domain/member/mitglied.dart';
import 'package:nami/domain/taetigkeit/role_derivation.dart';
import 'package:nami/domain/taetigkeit/roles.dart';
import 'package:nami/domain/taetigkeit/stufe.dart';

/// Erfundene Organisation fuer den Demo-Zugang: ein Bezirk mit zwei
/// Staemmen.
///
/// Alle Namen und Kontaktdaten sind erfunden. Geburtsdaten sind relativ zum
/// heutigen Tag angegeben, damit Stufenwechsel und Altersverteilung auch in
/// spaeteren Jahren gleich aussehen.
abstract final class DemoBezirk {
  static const int dioezeseId = 990002;
  static const String dioezeseName = 'Diözese Silberland';
  static const int bezirkId = 990003;
  static const int silberfelsId = 990011;
  static const int birkenhainId = 990012;

  static const int biberSilberfelsId = 990021;
  static const int woelflingeSilberfelsId = 990022;
  static const int truppKompassId = 990023;
  static const int pfadfinderSilberfelsId = 990024;
  static const int roverSilberfelsId = 990025;

  static const int biberBirkenhainId = 990031;
  static const int woelflingeBirkenhainId = 990032;
  static const int jungpfadfinderBirkenhainId = 990033;
  static const int pfadfinderBirkenhainId = 990034;
  static const int roverBirkenhainId = 990035;

  /// Arbeitskreis im Bezirk; nur als Rolle sichtbar, nicht als Gruppe eines
  /// Demo-Layers.
  static const int akWoelflingeBezirkId = 990041;

  static const DemoLayer bezirk = DemoLayer(
    id: bezirkId,
    name: 'Bezirk Silbertal',
    typ: 'Group::Bezirk',
    parentId: dioezeseId,
    strasse: 'Talstraße',
    plz: '49084',
    ort: 'Osnabrück',
    personen: <DemoPerson>[
      DemoPerson(
        '3001',
        'Martin',
        'Krause',
        38,
        2,
        Stufe.leitung,
        bezirkId,
        leitung: true,
        rolle: 'Bezirkssprecher*in',
      ),
      DemoPerson(
        '3002',
        'Svenja',
        'Albers',
        33,
        7,
        Stufe.leitung,
        bezirkId,
        leitung: true,
        rolle: 'Stv. Bezirkssprecher*in',
        fahrtenname: 'Möwe',
      ),
      DemoPerson(
        '3003',
        'Florian',
        'Brück',
        45,
        0,
        Stufe.leitung,
        bezirkId,
        leitung: true,
        rolle: 'Bezirksschatzmeister*in',
      ),
    ],
  );

  static const DemoLayer silberfels = DemoLayer(
    id: silberfelsId,
    name: 'Stamm Silberfels',
    typ: 'Group::Stamm',
    parentId: bezirkId,
    strasse: 'Am Silberbach',
    plz: '49074',
    ort: 'Osnabrück',
    gruppen: <ArbeitskontextGruppe>[
      ArbeitskontextGruppe(
        id: biberSilberfelsId,
        name: 'Biberbande',
        layerId: silberfelsId,
        gruppenTyp: 'Group::StammGruppeBiber',
      ),
      ArbeitskontextGruppe(
        id: woelflingeSilberfelsId,
        name: 'Meute Seeadler',
        layerId: silberfelsId,
        gruppenTyp: 'Group::StammGruppeWoelflinge',
      ),
      ArbeitskontextGruppe(
        id: truppKompassId,
        name: 'Trupp Kompass',
        layerId: silberfelsId,
        gruppenTyp: 'Group::StammGruppeJungpfadfinder',
      ),
      ArbeitskontextGruppe(
        id: pfadfinderSilberfelsId,
        name: 'Trupp Nordlicht',
        layerId: silberfelsId,
        gruppenTyp: 'Group::StammGruppePfadfinder',
      ),
      ArbeitskontextGruppe(
        id: roverSilberfelsId,
        name: 'Runde Fernweh',
        layerId: silberfelsId,
        gruppenTyp: 'Group::StammGruppeRover',
      ),
    ],
    personen: <DemoPerson>[
      // Biber
      DemoPerson(
        '1001',
        'Mila',
        'Brandt',
        4,
        3,
        Stufe.biber,
        biberSilberfelsId,
        haushalt: 'demo-haushalt-brandt',
      ),
      DemoPerson(
        '1002',
        'Theo',
        'Hartmann',
        4,
        8,
        Stufe.biber,
        biberSilberfelsId,
      ),
      DemoPerson(
        '1003',
        'Ida',
        'Schuster',
        5,
        5,
        Stufe.biber,
        biberSilberfelsId,
      ),
      // Woelflinge
      DemoPerson(
        '1011',
        'Emil',
        'Voigt',
        6,
        5,
        Stufe.woelfling,
        woelflingeSilberfelsId,
      ),
      DemoPerson(
        '1012',
        'Lotta',
        'Krüger',
        7,
        2,
        Stufe.woelfling,
        woelflingeSilberfelsId,
      ),
      DemoPerson(
        '1013',
        'Paul',
        'Brandt',
        7,
        11,
        Stufe.woelfling,
        woelflingeSilberfelsId,
        haushalt: 'demo-haushalt-brandt',
      ),
      DemoPerson(
        '1014',
        'Frieda',
        'Lorenz',
        8,
        6,
        Stufe.woelfling,
        woelflingeSilberfelsId,
      ),
      DemoPerson(
        '1015',
        'Anton',
        'Engel',
        9,
        4,
        Stufe.woelfling,
        woelflingeSilberfelsId,
      ),
      DemoPerson(
        '1016',
        'Greta',
        'Winter',
        10,
        6,
        Stufe.woelfling,
        woelflingeSilberfelsId,
      ),
      // Jungpfadfinder
      DemoPerson(
        '1021',
        'Jonas',
        'Peters',
        9,
        7,
        Stufe.jungpfadfinder,
        truppKompassId,
      ),
      DemoPerson(
        '1022',
        'Hanna',
        'Albrecht',
        10,
        0,
        Stufe.jungpfadfinder,
        truppKompassId,
      ),
      DemoPerson(
        '1023',
        'Luis',
        'Franke',
        10,
        9,
        Stufe.jungpfadfinder,
        truppKompassId,
      ),
      DemoPerson(
        '1024',
        'Marie',
        'Graf',
        11,
        2,
        Stufe.jungpfadfinder,
        truppKompassId,
      ),
      DemoPerson(
        '1025',
        'Ben',
        'Kuhn',
        12,
        10,
        Stufe.jungpfadfinder,
        truppKompassId,
      ),
      // Pfadfinder
      DemoPerson(
        '1031',
        'Clara',
        'Böhm',
        12,
        3,
        Stufe.pfadfinder,
        pfadfinderSilberfelsId,
      ),
      DemoPerson(
        '1032',
        'Finn',
        'Arnold',
        13,
        8,
        Stufe.pfadfinder,
        pfadfinderSilberfelsId,
      ),
      DemoPerson(
        '1033',
        'Lea',
        'Busch',
        14,
        5,
        Stufe.pfadfinder,
        pfadfinderSilberfelsId,
      ),
      DemoPerson(
        '1034',
        'Noah',
        'Ludwig',
        15,
        2,
        Stufe.pfadfinder,
        pfadfinderSilberfelsId,
      ),
      // Rover
      DemoPerson(
        '1041',
        'Sophie',
        'Haas',
        16,
        5,
        Stufe.rover,
        roverSilberfelsId,
      ),
      DemoPerson(
        '1042',
        'Jakob',
        'Sommer',
        18,
        1,
        Stufe.rover,
        roverSilberfelsId,
      ),
      DemoPerson('1043', 'Nele', 'Pohl', 19, 9, Stufe.rover, roverSilberfelsId),
      // Leitende
      DemoPerson(
        '1051',
        'Katharina',
        'Wolf',
        27,
        4,
        Stufe.woelfling,
        woelflingeSilberfelsId,
        leitung: true,
        fahrtenname: 'Eule',
        weitereRollen: <DemoRolle>[
          DemoRolle(
            label: 'AK Mitarbeiter*in',
            gruppenId: akWoelflingeBezirkId,
            gruppenName: 'AK Wölflingsstufe',
            layerName: 'Bezirk Silbertal',
            seitJahren: 2,
          ),
        ],
      ),
      DemoPerson(
        '1052',
        'David',
        'Neumann',
        24,
        7,
        Stufe.jungpfadfinder,
        truppKompassId,
        leitung: true,
      ),
      DemoPerson(
        '1053',
        'Lena',
        'Schreiber',
        23,
        2,
        Stufe.pfadfinder,
        pfadfinderSilberfelsId,
        leitung: true,
        fahrtenname: 'Luchs',
      ),
      DemoPerson(
        '1054',
        'Tobias',
        'Richter',
        31,
        10,
        Stufe.rover,
        roverSilberfelsId,
        leitung: true,
      ),
      DemoPerson(
        '1055',
        'Miriam',
        'Keller',
        29,
        6,
        Stufe.biber,
        biberSilberfelsId,
        leitung: true,
      ),
      // Stammesvorstand, Rolle direkt am Stamm
      DemoPerson(
        '1061',
        'Johanna',
        'Becker',
        34,
        9,
        Stufe.leitung,
        silberfelsId,
        leitung: true,
        rolle: 'Stammesführer*in',
      ),
    ],
  );

  static const DemoLayer birkenhain = DemoLayer(
    id: birkenhainId,
    name: 'Stamm Birkenhain',
    typ: 'Group::Stamm',
    parentId: bezirkId,
    strasse: 'Birkenallee',
    plz: '49090',
    ort: 'Osnabrück',
    gruppen: <ArbeitskontextGruppe>[
      ArbeitskontextGruppe(
        id: biberBirkenhainId,
        name: 'Biberbau',
        layerId: birkenhainId,
        gruppenTyp: 'Group::StammGruppeBiber',
      ),
      ArbeitskontextGruppe(
        id: woelflingeBirkenhainId,
        name: 'Meute Graufell',
        layerId: birkenhainId,
        gruppenTyp: 'Group::StammGruppeWoelflinge',
      ),
      ArbeitskontextGruppe(
        id: jungpfadfinderBirkenhainId,
        name: 'Trupp Wegweiser',
        layerId: birkenhainId,
        gruppenTyp: 'Group::StammGruppeJungpfadfinder',
      ),
      ArbeitskontextGruppe(
        id: pfadfinderBirkenhainId,
        name: 'Trupp Sternschnuppe',
        layerId: birkenhainId,
        gruppenTyp: 'Group::StammGruppePfadfinder',
      ),
      ArbeitskontextGruppe(
        id: roverBirkenhainId,
        name: 'Runde Horizont',
        layerId: birkenhainId,
        gruppenTyp: 'Group::StammGruppeRover',
      ),
    ],
    personen: <DemoPerson>[
      // Biber
      DemoPerson('2001', 'Juna', 'Meyer', 5, 2, Stufe.biber, biberBirkenhainId),
      DemoPerson(
        '2002',
        'Oskar',
        'Fuchs',
        5,
        9,
        Stufe.biber,
        biberBirkenhainId,
      ),
      // Woelflinge
      DemoPerson(
        '2011',
        'Mats',
        'Weber',
        7,
        1,
        Stufe.woelfling,
        woelflingeBirkenhainId,
      ),
      DemoPerson(
        '2012',
        'Pia',
        'Schulz',
        7,
        8,
        Stufe.woelfling,
        woelflingeBirkenhainId,
      ),
      DemoPerson(
        '2013',
        'Leon',
        'Hofmann',
        8,
        4,
        Stufe.woelfling,
        woelflingeBirkenhainId,
      ),
      DemoPerson(
        '2014',
        'Mira',
        'Roth',
        8,
        9,
        Stufe.woelfling,
        woelflingeBirkenhainId,
      ),
      DemoPerson(
        '2015',
        'Romy',
        'Simon',
        9,
        0,
        Stufe.woelfling,
        woelflingeBirkenhainId,
      ),
      DemoPerson(
        '2016',
        'Elias',
        'Jung',
        9,
        10,
        Stufe.woelfling,
        woelflingeBirkenhainId,
      ),
      // Jungpfadfinder
      DemoPerson(
        '2021',
        'Karl',
        'Vogel',
        10,
        3,
        Stufe.jungpfadfinder,
        jungpfadfinderBirkenhainId,
      ),
      DemoPerson(
        '2022',
        'Ella',
        'Schröder',
        11,
        6,
        Stufe.jungpfadfinder,
        jungpfadfinderBirkenhainId,
      ),
      DemoPerson(
        '2023',
        'Henri',
        'Berger',
        12,
        1,
        Stufe.jungpfadfinder,
        jungpfadfinderBirkenhainId,
      ),
      // Pfadfinder
      DemoPerson(
        '2031',
        'Lina',
        'Kaiser',
        13,
        4,
        Stufe.pfadfinder,
        pfadfinderBirkenhainId,
      ),
      DemoPerson(
        '2032',
        'Moritz',
        'Huber',
        14,
        0,
        Stufe.pfadfinder,
        pfadfinderBirkenhainId,
      ),
      DemoPerson(
        '2033',
        'Amelie',
        'Ziegler',
        14,
        9,
        Stufe.pfadfinder,
        pfadfinderBirkenhainId,
      ),
      DemoPerson(
        '2034',
        'Jan',
        'Möller',
        15,
        7,
        Stufe.pfadfinder,
        pfadfinderBirkenhainId,
      ),
      // Rover
      DemoPerson(
        '2041',
        'Toni',
        'Walter',
        17,
        2,
        Stufe.rover,
        roverBirkenhainId,
      ),
      // Leitende
      DemoPerson(
        '2051',
        'Carla',
        'Brenner',
        26,
        3,
        Stufe.woelfling,
        woelflingeBirkenhainId,
        leitung: true,
        fahrtenname: 'Dachs',
      ),
      DemoPerson(
        '2052',
        'Simon',
        'Thiel',
        22,
        8,
        Stufe.pfadfinder,
        pfadfinderBirkenhainId,
        leitung: true,
      ),
      DemoPerson(
        '2053',
        'Marlene',
        'Kraus',
        30,
        1,
        Stufe.biber,
        biberBirkenhainId,
        leitung: true,
      ),
      DemoPerson(
        '2054',
        'Philipp',
        'Dietrich',
        35,
        6,
        Stufe.jungpfadfinder,
        jungpfadfinderBirkenhainId,
        leitung: true,
      ),
      // Stammesvorstand, Rolle direkt am Stamm
      DemoPerson(
        '2061',
        'Ronja',
        'Pfeiffer',
        41,
        0,
        Stufe.leitung,
        birkenhainId,
        leitung: true,
        rolle: 'Stammesführer*in',
        fahrtenname: 'Elster',
      ),
    ],
  );

  /// Alle Layer unterhalb der Dioezese. Die Dioezese selbst hat im Demo keine
  /// Personen.
  static const List<DemoLayer> layer = <DemoLayer>[
    bezirk,
    silberfels,
    birkenhain,
  ];

  static DemoLayer? findeLayer(int id) {
    for (final kandidat in layer) {
      if (kandidat.id == id) {
        return kandidat;
      }
    }
    return null;
  }

  /// Ausstellungsalter der Fuehrungszeugnisse in Monaten. Einige laufen bald
  /// ab, einige sind abgelaufen, manche Leitende haben keines vorgelegt.
  static const Map<String, int> efzAlterMonate = <String, int>{
    '1051': 58,
    '1052': 14,
    '1053': 26,
    '1054': 64,
    '1061': 30,
    '2051': 8,
    '2052': 61,
    '2053': 55,
    '2061': 20,
    '3001': 18,
    '3002': 40,
    '3003': 50,
  };

  /// Qualifikationen der Leitenden: Erwerb vor [DemoQualifikation.vorMonaten]
  /// Monaten, gueltig fuer [DemoQualifikation.gueltigJahre] (null = ohne
  /// Ablauf).
  static const Map<String, List<DemoQualifikation>>
  qualifikationen = <String, List<DemoQualifikation>>{
    '1051': <DemoQualifikation>[
      DemoQualifikation('Woodbadge', 40, artId: 3),
      DemoQualifikation('Präventionsschulung', 30, artId: 14, gueltigJahre: 5),
      DemoQualifikation('Erste-Hilfe-Kurs', 22, artId: 9, gueltigJahre: 2),
      DemoQualifikation(
        'Juleica',
        44,
        artId: 21,
        gueltigJahre: 3,
        reaktivierbar: true,
      ),
    ],
    '1052': <DemoQualifikation>[
      DemoQualifikation('Präventionsschulung', 10, artId: 14, gueltigJahre: 5),
    ],
    '1053': <DemoQualifikation>[
      DemoQualifikation('Modulausbildung', 60, artId: 5),
      DemoQualifikation('Präventionsschulung', 58, artId: 14, gueltigJahre: 5),
    ],
    '1061': <DemoQualifikation>[
      DemoQualifikation('Woodbadge', 90, artId: 3),
      DemoQualifikation('Präventionsschulung', 20, artId: 14, gueltigJahre: 5),
    ],
    '2051': <DemoQualifikation>[
      DemoQualifikation('Präventionsschulung', 6, artId: 14, gueltigJahre: 5),
    ],
  };
}

class DemoQualifikation {
  const DemoQualifikation(
    this.label,
    this.vorMonaten, {
    required this.artId,
    this.gueltigJahre,
    this.reaktivierbar = false,
  });

  final String label;

  /// Feste Art-ID wie `qualification_kind_id` in Hitobito.
  final int artId;
  final int vorMonaten;
  final int? gueltigJahre;
  final bool reaktivierbar;
}

class DemoLayer {
  const DemoLayer({
    required this.id,
    required this.name,
    required this.typ,
    required this.parentId,
    required this.strasse,
    required this.plz,
    required this.ort,
    this.gruppen = const <ArbeitskontextGruppe>[],
    this.personen = const <DemoPerson>[],
  });

  final int id;
  final String name;
  final String typ;
  final int parentId;
  final String strasse;
  final String plz;
  final String ort;
  final List<ArbeitskontextGruppe> gruppen;
  final List<DemoPerson> personen;

  bool enthaeltGruppe(int gruppenId) =>
      gruppen.any((gruppe) => gruppe.id == gruppenId);
}

/// Zusaetzliche Rolle einer Person, etwa in einem anderen Layer.
class DemoRolle {
  const DemoRolle({
    required this.label,
    required this.gruppenId,
    required this.gruppenName,
    required this.layerName,
    required this.seitJahren,
  });

  final String label;
  final int gruppenId;
  final String gruppenName;
  final String layerName;
  final int seitJahren;
}

/// Person mit einer Hauptrolle und optional [weitereRollen]. [gruppenId] ist
/// entweder eine Gruppe des Layers oder, bei Vorstandsrollen, der Layer
/// selbst. Personen mit gleichem [haushalt] bilden einen Hitobito-Haushalt.
class DemoPerson {
  const DemoPerson(
    this.mitgliedsnummer,
    this.vorname,
    this.nachname,
    this.alterJahre,
    this.alterMonate,
    this.stufe,
    this.gruppenId, {
    this.leitung = false,
    this.fahrtenname,
    this.rolle,
    this.haushalt,
    this.weitereRollen = const <DemoRolle>[],
  });

  final String mitgliedsnummer;
  final String vorname;
  final String nachname;
  final int alterJahre;
  final int alterMonate;
  final Stufe stufe;
  final int gruppenId;
  final bool leitung;
  final String? fahrtenname;

  /// Bezeichnung der Rolle, wenn sie nicht „Leiter*in“ oder „Mitglied“ ist.
  final String? rolle;
  final String? haushalt;
  final List<DemoRolle> weitereRollen;

  int get personId => int.parse(mitgliedsnummer);

  String get rollenLabel => rolle ?? (leitung ? 'Leiter*in' : 'Mitglied');

  Mitglied toMitglied(DateTime today, DemoLayer layer) {
    final geburtsdatum = DateTime(
      today.year - alterJahre,
      today.month - alterMonate,
      (personId % 27) + 1,
    );
    final mitgliedsjahre = leitung ? 12 : (alterJahre - 4).clamp(1, 6);
    final eintrittsdatum = DateTime(today.year - mitgliedsjahre, 9, 1);
    final stufenStart = DateTime(today.year - (leitung ? 3 : 1), 9, 1);
    final emailName =
        '${_ascii(vorname).toLowerCase()}.${_ascii(nachname).toLowerCase()}';
    final gruppenName = gruppenId == layer.id
        ? layer.name
        : layer.gruppen
              .where((gruppe) => gruppe.id == gruppenId)
              .map((gruppe) => gruppe.name)
              .firstOrNull;
    // Ein Haushalt teilt sich die Hausnummer, damit die Adresse passt.
    final hausnummer = haushalt == null
        ? '${personId % 40 + 1}'
        : '${haushalt!.length % 40 + 1}';

    return Mitglied(
      vorname: vorname,
      nachname: nachname,
      fahrtenname: fahrtenname,
      geburtsdatum: geburtsdatum,
      eintrittsdatum: eintrittsdatum,
      mitgliedsnummer: mitgliedsnummer,
      personId: personId,
      primaryGroupId: gruppenId,
      gender: _weiblicheVornamen.contains(vorname) ? 'w' : 'm',
      householdKey: haushalt,
      telefonnummern: <MitgliedKontaktTelefon>[
        MitgliedKontaktTelefon(
          wert: '+49 151 ${2340000 + personId * 37}',
          label: Mitglied.phoneMobileLabel,
        ),
      ],
      emailAdressen: <MitgliedKontaktEmail>[
        MitgliedKontaktEmail(
          wert: '$emailName@example.org',
          label: Mitglied.primaryEmailLabel,
          istPrimaer: true,
        ),
      ],
      adressen: <MitgliedKontaktAdresse>[
        MitgliedKontaktAdresse(
          additionalAddressId: 0,
          street: layer.strasse,
          housenumber: hausnummer,
          zipCode: layer.plz,
          town: layer.ort,
          country: 'DE',
        ),
      ],
      roles: <Role>[
        roleFromLegacy(
          stufe: stufe,
          art: leitung ? RoleCategory.leitung : RoleCategory.mitglied,
          start: stufenStart,
          groupId: gruppenId,
          permission: rolle,
        ).copyWith(groupName: gruppenName, layerName: layer.name),
        for (final weitere in weitereRollen)
          roleFromLegacy(
            stufe: Stufe.leitung,
            art: RoleCategory.sonstiges,
            start: DateTime(today.year - weitere.seitJahren, 1, 1),
            groupId: weitere.gruppenId,
            permission: weitere.label,
          ).copyWith(
            groupName: weitere.gruppenName,
            layerName: weitere.layerName,
          ),
      ],
    );
  }

  static const Set<String> _weiblicheVornamen = <String>{
    'Mila',
    'Ida',
    'Lotta',
    'Frieda',
    'Greta',
    'Hanna',
    'Marie',
    'Clara',
    'Lea',
    'Sophie',
    'Nele',
    'Katharina',
    'Lena',
    'Miriam',
    'Johanna',
    'Juna',
    'Pia',
    'Mira',
    'Romy',
    'Ella',
    'Lina',
    'Amelie',
    'Carla',
    'Marlene',
    'Ronja',
    'Svenja',
  };

  static String _ascii(String value) => value
      .replaceAll('ä', 'ae')
      .replaceAll('ö', 'oe')
      .replaceAll('ü', 'ue')
      .replaceAll('ß', 'ss');
}

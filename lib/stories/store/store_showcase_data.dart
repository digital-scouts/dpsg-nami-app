import 'package:nami/domain/arbeitskontext/arbeitskontext.dart';
import 'package:nami/domain/arbeitskontext/arbeitskontext_read_model.dart';
import 'package:nami/domain/member/mitglied.dart';
import 'package:nami/domain/taetigkeit/role_derivation.dart';
import 'package:nami/domain/taetigkeit/roles.dart';
import 'package:nami/domain/taetigkeit/stufe.dart';

/// Fiktiver Stamm fuer Store-Screenshots und Storybook-Szenen.
///
/// Alle Namen und Kontaktdaten sind erfunden. Geburtsdaten sind relativ zum
/// heutigen Tag angegeben, damit Stufenwechsel und Altersverteilung auch in
/// spaeteren Jahren gleich aussehen.
class StoreShowcaseData {
  StoreShowcaseData._();

  static const int layerId = 11;
  static const String stammName = 'Stamm Silberfels';

  static const int _biberId = 21;
  static const int _woelflingeId = 22;
  static const int _jungpfadfinderId = 23;
  static const int _pfadfinderId = 24;
  static const int _roverId = 25;

  static const List<ArbeitskontextGruppe> gruppen = <ArbeitskontextGruppe>[
    ArbeitskontextGruppe(
      id: _biberId,
      name: 'Biberbande',
      layerId: layerId,
      gruppenTyp: 'Group::StammGruppeBiber',
    ),
    ArbeitskontextGruppe(
      id: _woelflingeId,
      name: 'Meute Seeadler',
      layerId: layerId,
      gruppenTyp: 'Group::StammGruppeWoelflinge',
    ),
    ArbeitskontextGruppe(
      id: _jungpfadfinderId,
      name: 'Trupp Kompass',
      layerId: layerId,
      gruppenTyp: 'Group::StammGruppeJungpfadfinder',
    ),
    ArbeitskontextGruppe(
      id: _pfadfinderId,
      name: 'Trupp Nordlicht',
      layerId: layerId,
      gruppenTyp: 'Group::StammGruppePfadfinder',
    ),
    ArbeitskontextGruppe(
      id: _roverId,
      name: 'Runde Fernweh',
      layerId: layerId,
      gruppenTyp: 'Group::StammGruppeRover',
    ),
  ];

  static final List<_ShowcaseMember> _members = <_ShowcaseMember>[
    // Biber
    _ShowcaseMember('1001', 'Mila', 'Brandt', 4, 3, Stufe.biber, _biberId),
    _ShowcaseMember('1002', 'Theo', 'Hartmann', 4, 8, Stufe.biber, _biberId),
    _ShowcaseMember('1003', 'Ida', 'Schuster', 5, 5, Stufe.biber, _biberId),
    // Woelflinge
    _ShowcaseMember(
      '1011',
      'Emil',
      'Voigt',
      6,
      5,
      Stufe.woelfling,
      _woelflingeId,
    ),
    _ShowcaseMember(
      '1012',
      'Lotta',
      'Krüger',
      7,
      2,
      Stufe.woelfling,
      _woelflingeId,
    ),
    _ShowcaseMember(
      '1013',
      'Paul',
      'Seidel',
      7,
      11,
      Stufe.woelfling,
      _woelflingeId,
    ),
    _ShowcaseMember(
      '1014',
      'Frieda',
      'Lorenz',
      8,
      6,
      Stufe.woelfling,
      _woelflingeId,
    ),
    _ShowcaseMember(
      '1015',
      'Anton',
      'Engel',
      9,
      4,
      Stufe.woelfling,
      _woelflingeId,
    ),
    _ShowcaseMember(
      '1016',
      'Greta',
      'Winter',
      10,
      6,
      Stufe.woelfling,
      _woelflingeId,
    ),
    // Jungpfadfinder
    _ShowcaseMember(
      '1021',
      'Jonas',
      'Peters',
      9,
      7,
      Stufe.jungpfadfinder,
      _jungpfadfinderId,
    ),
    _ShowcaseMember(
      '1022',
      'Hanna',
      'Albrecht',
      10,
      0,
      Stufe.jungpfadfinder,
      _jungpfadfinderId,
    ),
    _ShowcaseMember(
      '1023',
      'Luis',
      'Franke',
      10,
      9,
      Stufe.jungpfadfinder,
      _jungpfadfinderId,
    ),
    _ShowcaseMember(
      '1024',
      'Marie',
      'Graf',
      11,
      2,
      Stufe.jungpfadfinder,
      _jungpfadfinderId,
    ),
    _ShowcaseMember(
      '1025',
      'Ben',
      'Kuhn',
      12,
      10,
      Stufe.jungpfadfinder,
      _jungpfadfinderId,
    ),
    // Pfadfinder
    _ShowcaseMember(
      '1031',
      'Clara',
      'Böhm',
      12,
      3,
      Stufe.pfadfinder,
      _pfadfinderId,
    ),
    _ShowcaseMember(
      '1032',
      'Finn',
      'Arnold',
      13,
      8,
      Stufe.pfadfinder,
      _pfadfinderId,
    ),
    _ShowcaseMember(
      '1033',
      'Lea',
      'Busch',
      14,
      5,
      Stufe.pfadfinder,
      _pfadfinderId,
    ),
    _ShowcaseMember(
      '1034',
      'Noah',
      'Ludwig',
      15,
      2,
      Stufe.pfadfinder,
      _pfadfinderId,
    ),
    // Rover
    _ShowcaseMember('1041', 'Sophie', 'Haas', 16, 5, Stufe.rover, _roverId),
    _ShowcaseMember('1042', 'Jakob', 'Sommer', 18, 1, Stufe.rover, _roverId),
    _ShowcaseMember('1043', 'Nele', 'Pohl', 19, 9, Stufe.rover, _roverId),
    // Leitende
    _ShowcaseMember(
      '1051',
      'Katharina',
      'Wolf',
      27,
      4,
      Stufe.woelfling,
      _woelflingeId,
      leitung: true,
      fahrtenname: 'Eule',
    ),
    _ShowcaseMember(
      '1052',
      'David',
      'Neumann',
      24,
      7,
      Stufe.jungpfadfinder,
      _jungpfadfinderId,
      leitung: true,
    ),
    _ShowcaseMember(
      '1053',
      'Lena',
      'Schreiber',
      23,
      2,
      Stufe.pfadfinder,
      _pfadfinderId,
      leitung: true,
      fahrtenname: 'Luchs',
    ),
    _ShowcaseMember(
      '1054',
      'Tobias',
      'Richter',
      31,
      10,
      Stufe.rover,
      _roverId,
      leitung: true,
    ),
    _ShowcaseMember(
      '1055',
      'Miriam',
      'Keller',
      29,
      6,
      Stufe.biber,
      _biberId,
      leitung: true,
    ),
  ];

  /// Mitglied, das dem eingeloggten Story-Profil (`namiId: 1`) entspricht und
  /// deshalb das eigene Supporter-Badge traegt.
  static const String eigeneMitgliedsnummer = '1022';

  /// Mitglied, das in der Detailansicht gezeigt wird.
  static const String featuredMitgliedsnummer = '1053';

  static ArbeitskontextReadModel readModel({DateTime? today}) {
    final referenceDate = today ?? DateTime.now();
    return ArbeitskontextReadModel(
      arbeitskontext: Arbeitskontext(
        aktiverLayer: const ArbeitskontextLayer(id: layerId, name: stammName),
      ),
      rolesSindGeladen: true,
      mitglieder: mitglieder(today: referenceDate),
      gruppen: gruppen,
      mitgliedsZuordnungen: <ArbeitskontextMitgliedsZuordnung>[
        for (final member in _members)
          ArbeitskontextMitgliedsZuordnung(
            mitgliedsnummer: member.mitgliedsnummer,
            gruppenId: member.gruppenId,
            rollenLabel: member.leitung ? 'Leiter*in' : 'Mitglied',
          ),
      ],
    );
  }

  static List<Mitglied> mitglieder({DateTime? today}) {
    final referenceDate = today ?? DateTime.now();
    return <Mitglied>[
      for (final member in _members) member.toMitglied(referenceDate),
    ];
  }

  static Mitglied featuredMitglied({DateTime? today}) {
    return mitglieder(
      today: today,
    ).firstWhere((m) => m.mitgliedsnummer == featuredMitgliedsnummer);
  }
}

class _ShowcaseMember {
  _ShowcaseMember(
    this.mitgliedsnummer,
    this.vorname,
    this.nachname,
    this.alterJahre,
    this.alterMonate,
    this.stufe,
    this.gruppenId, {
    this.leitung = false,
    this.fahrtenname,
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

  Mitglied toMitglied(DateTime today) {
    final geburtsdatum = DateTime(
      today.year - alterJahre,
      today.month - alterMonate,
      (int.parse(mitgliedsnummer) % 27) + 1,
    );
    final mitgliedsjahre = leitung ? 12 : (alterJahre - 4).clamp(1, 6);
    final eintrittsdatum = DateTime(today.year - mitgliedsjahre, 9, 1);
    final stufenStart = DateTime(today.year - (leitung ? 3 : 1), 9, 1);
    final nummer = int.parse(mitgliedsnummer);
    final emailName =
        '${_ascii(vorname).toLowerCase()}.${_ascii(nachname).toLowerCase()}';

    return Mitglied(
      vorname: vorname,
      nachname: nachname,
      fahrtenname: fahrtenname,
      geburtsdatum: geburtsdatum,
      eintrittsdatum: eintrittsdatum,
      mitgliedsnummer: mitgliedsnummer,
      personId: mitgliedsnummer == StoreShowcaseData.eigeneMitgliedsnummer
          ? 1
          : null,
      primaryGroupId: gruppenId,
      gender: _weiblicheVornamen.contains(vorname) ? 'w' : 'm',
      telefonnummern: <MitgliedKontaktTelefon>[
        MitgliedKontaktTelefon(
          wert: '+49 151 ${2340000 + nummer * 37}',
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
          street: 'Am Silberbach',
          housenumber: '${nummer % 40 + 1}',
          zipCode: '49074',
          town: 'Osnabrück',
          country: 'DE',
        ),
      ],
      roles: <Role>[
        roleFromLegacy(
          stufe: stufe,
          art: leitung ? RoleCategory.leitung : RoleCategory.mitglied,
          start: stufenStart,
          groupId: gruppenId,
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
  };

  static String _ascii(String value) => value
      .replaceAll('ä', 'ae')
      .replaceAll('ö', 'oe')
      .replaceAll('ü', 'ue')
      .replaceAll('ß', 'ss');
}

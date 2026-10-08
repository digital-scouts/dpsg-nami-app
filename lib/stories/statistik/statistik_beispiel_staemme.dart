import 'dart:math' as math;

import 'package:nami/domain/arbeitskontext/arbeitskontext.dart';
import 'package:nami/domain/arbeitskontext/arbeitskontext_read_model.dart';
import 'package:nami/domain/member/mitglied.dart';
import 'package:nami/domain/member_filters/member_custom_filter.dart';
import 'package:nami/domain/statistiks/statistik_kachel_einstellungen.dart';
import 'package:nami/domain/statistiks/statistik_kachel_typen.dart';
import 'package:nami/domain/taetigkeit/role_derivation.dart';
import 'package:nami/domain/taetigkeit/roles.dart';
import 'package:nami/domain/taetigkeit/stufe.dart';

/// Erfundene Stämme für Statistik-Stories und -Tests, portiert aus den
/// Entwürfen der Stammesstatistik
/// (`design/entscheidung/2026-10-02-stammesstatistik.md`):
///
/// - **Weitblick**: 75 Personen, zwei Meuten, Neue, Überfällige, Sonstige.
/// - **Querfeld**: absichtlich krumme Daten – Mehrheit außerhalb der
///   Altersgrenzen, Platzhalter-Geburtsdaten, Eintritte in der Zukunft,
///   leere und riesige Gruppen, kaum Geschlechtsangaben.
///
/// Alter und Eintritte sind relativ zu `heute`, damit die Bilder in jedem
/// Jahr gleich aussehen. Für Silberfels siehe `StoreShowcaseData`.
class StatistikBeispielStaemme {
  StatistikBeispielStaemme._();

  static const int weitblickLayerId = 31;
  static const int querfeldLayerId = 32;

  static const Map<Stufe, (int, int)> _grenzen = {
    Stufe.biber: (4, 7),
    Stufe.woelfling: (6, 10),
    Stufe.jungpfadfinder: (9, 13),
    Stufe.pfadfinder: (12, 16),
    Stufe.rover: (15, 20),
  };

  static const Map<Stufe, String> _gruppenTyp = {
    Stufe.biber: 'Group::StammGruppeBiber',
    Stufe.woelfling: 'Group::StammGruppeWoelflinge',
    Stufe.jungpfadfinder: 'Group::StammGruppeJungpfadfinder',
    Stufe.pfadfinder: 'Group::StammGruppePfadfinder',
    Stufe.rover: 'Group::StammGruppeRover',
  };

  static const List<String> _namenW = [
    'Lina', 'Emma', 'Mia', 'Paula', 'Juna', 'Ronja', 'Maja', 'Tilda', //
    'Frida', 'Merle', 'Ella', 'Romy', 'Carla', 'Luise', 'Pia', 'Jule',
    'Nora', 'Ylvi', 'Enna', 'Lotte', 'Hedda', 'Svea', 'Alma', 'Wilma',
    'Elif', 'Amira', 'Zoe', 'Mara', 'Ida', 'Lene', 'Rieke', 'Thea',
  ];
  static const List<String> _namenM = [
    'Ole', 'Jonte', 'Mats', 'Lio', 'Henri', 'Emil', 'Anton', 'Bela', //
    'Janne', 'Milan', 'Theo', 'Carlo', 'Levi', 'Juri', 'Piet', 'Linus',
    'Fiete', 'Noel', 'Tom', 'Aaron', 'Mika', 'Jakob', 'Karl', 'Leon',
    'Malte', 'Nils', 'Oskar', 'Paul', 'Rasmus', 'Tjark', 'Yusuf', 'Ben',
  ];
  static const List<String> _namenD = ['Kim', 'Robin', 'Alex'];
  static const String _initialen = 'ABDFGHKLMNPRSTW';

  // Gruppen-IDs
  static const int _vorstandId = 3100;
  static const int _foerderId = 3101;
  static const int _stammesratId = 3102;

  /// Stamm Weitblick: 75 Personen.
  static ArbeitskontextReadModel weitblick({DateTime? heute}) {
    final h = _tag(heute);
    final r = _Zufall(99);
    final gruppen = <(int, String, Stufe, int, int)>[
      (3110, 'Biberburg', Stufe.biber, 7, 2),
      (3111, 'Meute Wirbelwind', Stufe.woelfling, 11, 3),
      (3112, 'Meute Sternschnuppe', Stufe.woelfling, 9, 2),
      (3113, 'Trupp Wegweiser', Stufe.jungpfadfinder, 13, 3),
      (3114, 'Trupp Nordwind', Stufe.pfadfinder, 10, 2),
      (3115, 'Runde Horizont', Stufe.rover, 7, 2),
    ];
    // Einzelne bewusst über der Altersgrenze (überfällige Wechsel).
    const sonderalter = <int, List<double>>{
      3111: [11.2, 10.9],
      3113: [14.1],
      3115: [21.3],
    };
    const neuQuote = <int, int>{3110: 3, 3111: 2, 3112: 2, 3113: 1, 3114: 1};
    final personen = <_Person>[];
    var nr = 2000;
    for (final (id, _, stufe, kinder, leitung) in gruppen) {
      final (min, max) = _grenzen[stufe]!;
      final extra = sonderalter[id] ?? const <double>[];
      for (var i = 0; i < kinder; i++) {
        final alter = i < extra.length
            ? extra[i]
            : min + 0.2 + _pow(r.naechste(), 1.2) * (max - min) * 0.85;
        var dabei = _min(
          alter - 4,
          1 + _pow(r.naechste(), 1.2) * _max(0, alter - 5),
        );
        final quote = neuQuote[id] ?? 0;
        if (i >= extra.length && i < extra.length + quote) {
          dabei = _min(alter - 4, 0.1 + r.naechste() * 0.8);
        }
        final u = r.naechste();
        personen.add(
          _Person(
            nummer: '${nr++}',
            gruppe: id,
            stufe: stufe,
            leitung: false,
            gender: u < 0.49
                ? 'w'
                : u < 0.97
                ? 'm'
                : u < 0.99
                ? 'd'
                : null,
            geburt: _minusJahre(h, alter),
            eintritt: _minusJahre(h, dabei),
          ),
        );
      }
      for (var i = 0; i < leitung; i++) {
        final alter = 19 + r.naechste() * 16;
        final u = r.naechste();
        personen.add(
          _Person(
            nummer: '${nr++}',
            gruppe: id,
            stufe: stufe,
            leitung: true,
            gender: u < 0.52 ? 'w' : 'm',
            geburt: _minusJahre(h, alter),
            eintritt: _minusJahre(h, _min(alter - 5, 4 + r.naechste() * 14)),
          ),
        );
      }
    }
    // Sonstige: Stammesvorstand, Kurat*in, Elternvertretung.
    for (final rolle in const [
      'Stammesvorstand',
      'Stammesvorstand',
      'Kurat*in',
      'Elternvertretung',
    ]) {
      personen.add(
        _Person(
          nummer: '${nr++}',
          gruppe: rolle == 'Stammesvorstand' ? _vorstandId : _stammesratId,
          stufe: null,
          leitung: false,
          gender: 'w',
          geburt: _minusJahre(h, 38),
          eintritt: _minusJahre(h, 9),
          rollenLabel: rolle,
        ),
      );
    }
    _benennen(personen);

    final zusatzZuordnungen = <ArbeitskontextMitgliedsZuordnung>[
      // Eine Leitung sitzt zusätzlich im Stammesvorstand.
      ArbeitskontextMitgliedsZuordnung(
        mitgliedsnummer: personen.firstWhere((p) => p.leitung).nummer,
        gruppenId: _vorstandId,
        rollenLabel: 'Stammesvorstand',
      ),
      // Fördermitgliedschaften: 2 Wö, 1 Jufi, 1 Pfadi, 2 Rover.
      for (final (stufe, anzahl) in const [
        (Stufe.woelfling, 2),
        (Stufe.jungpfadfinder, 1),
        (Stufe.pfadfinder, 1),
        (Stufe.rover, 2),
      ])
        for (final p
            in personen
                .where((p) => p.stufe == stufe && !p.leitung)
                .take(anzahl))
          ArbeitskontextMitgliedsZuordnung(
            mitgliedsnummer: p.nummer,
            gruppenId: _foerderId,
            rollenLabel: 'Fördermitgliedschaft',
          ),
    ];

    return _readModel(
      layerId: weitblickLayerId,
      name: 'Stamm Weitblick',
      heute: h,
      gruppen: [
        for (final (id, name, stufe, _, _) in gruppen)
          _gruppe(id, name, weitblickLayerId, _gruppenTyp[stufe]!),
        _gruppe(
          _vorstandId,
          'Stammesvorstand',
          weitblickLayerId,
          'Group::Stammesleitung',
        ),
        _gruppe(
          _foerderId,
          'Fördermitglieder',
          weitblickLayerId,
          'Group::Mitglieder',
        ),
        _gruppe(
          _stammesratId,
          'Stammesrat',
          weitblickLayerId,
          'Group::Stammesrat',
        ),
      ],
      personen: personen,
      zusatzZuordnungen: zusatzZuordnungen,
    );
  }

  /// Stamm Querfeld: krumme Daten, die nichts kaputt machen dürfen.
  static ArbeitskontextReadModel querfeld({DateTime? heute}) {
    final h = _tag(heute);
    final r = _Zufall(4242);
    final platzhalter = Mitglied.peoplePlaceholderDate;
    final personen = <_Person>[];
    var nr = 3000;
    void kind(int gruppe, Stufe stufe, double? alter, {DateTime? eintritt}) {
      final gender = r.naechste() < 0.8
          ? null
          : r.naechste() < 0.5
          ? 'w'
          : 'm';
      final standardEintritt = _minusJahre(h, r.naechste() * 10);
      personen.add(
        _Person(
          nummer: '${nr++}',
          gruppe: gruppe,
          stufe: stufe,
          leitung: false,
          gender: gender,
          geburt: alter == null ? platzhalter : _minusJahre(h, alter),
          eintritt: eintritt ?? standardEintritt,
        ),
      );
    }

    for (var i = 0; i < 38; i++) {
      final alter = i < 3 ? null : 3 + r.naechste() * 12;
      kind(
        3210,
        Stufe.woelfling,
        alter,
        eintritt: i < 2
            ? DateTime(h.year + 1, 1, 1)
            : i == 2
            ? platzhalter
            : null,
      );
    }
    for (final (gruppe, anzahl) in const [
      (3212, 2),
      (3213, 1),
      (3214, 0),
      (3215, 3),
      (3216, 1),
    ]) {
      for (var i = 0; i < anzahl; i++) {
        kind(gruppe, Stufe.pfadfinder, 10 + r.naechste() * 9);
      }
    }
    for (var i = 0; i < 6; i++) {
      kind(3217, Stufe.rover, 24 + r.naechste() * 10);
    }
    void leitung(int gruppe, Stufe stufe) {
      final geburt = _minusJahre(h, 22 + r.naechste() * 20);
      personen.add(
        _Person(
          nummer: '${nr++}',
          gruppe: gruppe,
          stufe: stufe,
          leitung: true,
          gender: null,
          geburt: geburt,
          eintritt: _minusJahre(h, 2 + r.naechste() * 8),
        ),
      );
    }

    leitung(3210, Stufe.woelfling);
    leitung(3211, Stufe.jungpfadfinder);
    leitung(3211, Stufe.jungpfadfinder);
    leitung(3212, Stufe.pfadfinder);
    _benennen(personen);

    return _readModel(
      layerId: querfeldLayerId,
      name: 'Stamm Querfeld',
      heute: h,
      gruppen: [
        _gruppe(
          3210,
          'Meute Riesig',
          querfeldLayerId,
          _gruppenTyp[Stufe.woelfling]!,
        ),
        _gruppe(
          3211,
          'Trupp Leer',
          querfeldLayerId,
          _gruppenTyp[Stufe.jungpfadfinder]!,
        ),
        _gruppe(
          3212,
          'Trupp Eins',
          querfeldLayerId,
          _gruppenTyp[Stufe.pfadfinder]!,
        ),
        _gruppe(
          3213,
          'Trupp Zwei',
          querfeldLayerId,
          _gruppenTyp[Stufe.pfadfinder]!,
        ),
        _gruppe(
          3214,
          'Trupp Drei',
          querfeldLayerId,
          _gruppenTyp[Stufe.pfadfinder]!,
        ),
        _gruppe(
          3215,
          'Trupp Vier',
          querfeldLayerId,
          _gruppenTyp[Stufe.pfadfinder]!,
        ),
        _gruppe(
          3216,
          'Trupp Fünf mit einem sehr langen Gruppennamen',
          querfeldLayerId,
          _gruppenTyp[Stufe.pfadfinder]!,
        ),
        _gruppe(
          3217,
          'Runde 30plus',
          querfeldLayerId,
          _gruppenTyp[Stufe.rover]!,
        ),
      ],
      personen: personen,
    );
  }

  /// Einstellungen mit eigenen Kacheln und Zielwerten für Weitblick.
  static StatistikKachelEinstellungen einstellungenWeitblick() =>
      StatistikKachelEinstellungen(
        ueberblick: [
          ...StatistikKachelEinstellungen.standardUeberblick,
          const KachelEintrag(
            id: 'beispiel-vorstand',
            typId: StatistikKachelTypen.eigene,
            groesse: KachelGroesse.klein,
            eigeneKachelId: 'kachel-vorstand',
          ),
          const KachelEintrag(
            id: 'beispiel-foerder',
            typId: StatistikKachelTypen.eigene,
            groesse: KachelGroesse.klein,
            eigeneKachelId: 'kachel-foerder',
          ),
        ],
        eigeneKacheln: [
          EigeneKachel(
            id: 'kachel-vorstand',
            titel: 'Stammesvorstand',
            filter: _gruppenFilter(
              'kachel-vorstand',
              'Vorstand',
              _vorstandId,
              'Stammesvorstand',
            ),
            ziel: 3,
            zielText: 'besetzt',
          ),
          EigeneKachel(
            id: 'kachel-foerder',
            titel: 'Fördermitglieder',
            filter: _gruppenFilter(
              'kachel-foerder',
              'Förder',
              _foerderId,
              'Fördermitglieder',
            ),
            darstellung: EigeneKachelDarstellung.nachStufe,
          ),
        ],
        ziele: const StatistikZielwerte(
          neuProJahr: 10,
          gruppeMax: {
            Stufe.biber: 10,
            Stufe.woelfling: 14,
            Stufe.jungpfadfinder: 16,
            Stufe.pfadfinder: 14,
            Stufe.rover: 12,
          },
        ),
      );

  /// Einstellungen mit leeren eigenen Kacheln und unvollständigen Zielen.
  static StatistikKachelEinstellungen einstellungenQuerfeld() =>
      StatistikKachelEinstellungen(
        ueberblick: [
          ...StatistikKachelEinstellungen.standardUeberblick,
          const KachelEintrag(
            id: 'beispiel-ohne',
            typId: StatistikKachelTypen.eigene,
            groesse: KachelGroesse.klein,
            eigeneKachelId: 'kachel-ohne',
          ),
          const KachelEintrag(
            id: 'beispiel-leer',
            typId: StatistikKachelTypen.eigene,
            groesse: KachelGroesse.breit,
            eigeneKachelId: 'kachel-leer',
          ),
        ],
        eigeneKacheln: [
          EigeneKachel(
            id: 'kachel-ohne',
            titel: 'Ohne Treffer',
            filter: _gruppenFilter(
              'kachel-ohne',
              'Ohne',
              999999,
              'Kassenprüfung',
            ),
          ),
          EigeneKachel(
            id: 'kachel-leer',
            titel: 'Leere Aufteilung',
            filter: _gruppenFilter(
              'kachel-leer',
              'Leer',
              999998,
              'Fördermitglieder',
            ),
            darstellung: EigeneKachelDarstellung.nachStufe,
          ),
        ],
        ziele: const StatistikZielwerte(gruppeMax: {Stufe.woelfling: 14}),
      );

  static MemberCustomFilterGroup _gruppenFilter(
    String id,
    String label,
    int gruppenId,
    String gruppenName,
  ) => MemberCustomFilterGroup(
    id: id,
    shortLabel: label,
    isActive: true,
    logic: MemberCustomFilterLogic.und,
    rules: [
      MemberCustomFilterRule(
        operator: MemberCustomFilterRuleOperator.hat,
        criterion: MemberCustomFilterCriterion.groupRole(
          groupId: gruppenId,
          groupName: gruppenName,
        ),
      ),
    ],
  );

  static ArbeitskontextReadModel _readModel({
    required int layerId,
    required String name,
    required DateTime heute,
    required List<ArbeitskontextGruppe> gruppen,
    required List<_Person> personen,
    List<ArbeitskontextMitgliedsZuordnung> zusatzZuordnungen = const [],
  }) {
    final rollenStart = DateTime(heute.year - 1, 9, 1);
    return ArbeitskontextReadModel(
      arbeitskontext: Arbeitskontext(
        aktiverLayer: ArbeitskontextLayer(id: layerId, name: name),
      ),
      rolesSindGeladen: true,
      gruppen: gruppen,
      mitglieder: [
        for (final p in personen)
          Mitglied(
            vorname: p.vorname,
            nachname: p.nachname,
            geburtsdatum: p.geburt,
            eintrittsdatum: p.eintritt,
            mitgliedsnummer: p.nummer,
            primaryGroupId: p.gruppe,
            gender: p.gender,
            roles: [
              if (p.stufe != null)
                roleFromLegacy(
                  stufe: p.stufe!,
                  art: p.leitung ? RoleCategory.leitung : RoleCategory.mitglied,
                  start: rollenStart,
                  groupId: p.gruppe,
                ),
            ],
          ),
      ],
      mitgliedsZuordnungen: [
        for (final p in personen)
          ArbeitskontextMitgliedsZuordnung(
            mitgliedsnummer: p.nummer,
            gruppenId: p.gruppe,
            rollenLabel:
                p.rollenLabel ?? (p.leitung ? 'Leiter*in' : 'Mitglied'),
          ),
        ...zusatzZuordnungen,
      ],
    );
  }

  static ArbeitskontextGruppe _gruppe(
    int id,
    String name,
    int layerId,
    String typ,
  ) => ArbeitskontextGruppe(
    id: id,
    name: name,
    layerId: layerId,
    gruppenTyp: typ,
  );

  static void _benennen(List<_Person> personen) {
    final zaehler = {'w': 0, 'm': 0, 'd': 0};
    for (var i = 0; i < personen.length; i++) {
      final p = personen[i];
      final art = p.gender == 'w'
          ? 'w'
          : p.gender == 'm'
          ? 'm'
          : 'd';
      final liste = switch (art) {
        'w' => _namenW,
        'm' => _namenM,
        _ => p.gender == null ? _namenW : _namenD,
      };
      p.vorname = liste[zaehler[art]! % liste.length];
      zaehler[art] = zaehler[art]! + 1;
      p.nachname = '${_initialen[(i * 7) % _initialen.length]}.';
    }
  }

  static DateTime _tag(DateTime? heute) {
    final h = heute ?? DateTime.now();
    return DateTime(h.year, h.month, h.day);
  }

  static DateTime _minusJahre(DateTime datum, double jahre) =>
      datum.subtract(Duration(minutes: (jahre * 365.25 * 24 * 60).round()));

  static double _pow(double basis, double exponent) =>
      basis <= 0 ? 0 : math.pow(basis, exponent).toDouble();
  static double _min(double a, double b) => math.min(a, b);
  static double _max(double a, double b) => math.max(a, b);
}

class _Person {
  _Person({
    required this.nummer,
    required this.gruppe,
    required this.stufe,
    required this.leitung,
    required this.gender,
    required this.geburt,
    required this.eintritt,
    this.rollenLabel,
  });

  final String nummer;
  final int gruppe;
  final Stufe? stufe;
  final bool leitung;
  final String? gender;
  final DateTime geburt;
  final DateTime eintritt;
  final String? rollenLabel;
  String vorname = 'Mitglied';
  String nachname = '';
}

/// mulberry32 wie in den Entwürfen, damit die Stämme dort und in der App
/// gleich aussahen.
class _Zufall {
  _Zufall(int seed) : _a = seed & 0xFFFFFFFF;

  int _a;

  static int _imul(int x, int y) => (x * y) & 0xFFFFFFFF;

  double naechste() {
    _a = (_a + 0x6d2b79f5) & 0xFFFFFFFF;
    var t = _a;
    t = _imul(t ^ (t >> 15), t | 1);
    t = (t ^ ((t + _imul(t ^ (t >> 7), t | 61)) & 0xFFFFFFFF)) & 0xFFFFFFFF;
    return ((t ^ (t >> 14)) & 0xFFFFFFFF) / 4294967296;
  }
}

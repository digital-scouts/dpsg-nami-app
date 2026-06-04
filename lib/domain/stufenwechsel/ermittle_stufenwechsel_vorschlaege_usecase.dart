import 'package:nami/domain/member/member_utils.dart';
import 'package:nami/domain/member/mitglied.dart';
import 'package:nami/domain/stufe/altersgrenzen.dart';
import 'package:nami/domain/taetigkeit/role_derivation.dart';
import 'package:nami/domain/taetigkeit/roles.dart';
import 'package:nami/domain/taetigkeit/stufe.dart';

class StufenwechselVorschlag {
  const StufenwechselVorschlag({
    required this.mitglied,
    required this.aktuelleStufe,
    required this.zielStufe,
    required this.alterAmStichtag,
    required this.faelligSeitJahr,
    required this.spaetestensJahr,
    required this.istUeberfaellig,
  });

  final Mitglied mitglied;
  final Stufe aktuelleStufe;
  final Stufe zielStufe;
  final int alterAmStichtag;
  final int faelligSeitJahr;
  final int spaetestensJahr;
  final bool istUeberfaellig;
}

class StufenwechselVorschlagsSection {
  const StufenwechselVorschlagsSection({
    required this.stageFrom,
    required this.stageTo,
    required this.vorschlaege,
  });

  final Stufe stageFrom;
  final Stufe stageTo;
  final List<StufenwechselVorschlag> vorschlaege;
}

class ErmittleStufenwechselVorschlaegeUseCase {
  const ErmittleStufenwechselVorschlaegeUseCase();

  static const List<Stufe> wechselStufen = <Stufe>[
    Stufe.biber,
    Stufe.woelfling,
    Stufe.jungpfadfinder,
    Stufe.pfadfinder,
  ];

  List<StufenwechselVorschlagsSection> call({
    required Iterable<Mitglied> mitglieder,
    required DateTime stichtag,
    required Altersgrenzen altersgrenzen,
  }) {
    final vorschlaegeByStage = <Stufe, List<StufenwechselVorschlag>>{
      for (final stufe in wechselStufen) stufe: <StufenwechselVorschlag>[],
    };

    for (final mitglied in mitglieder) {
      if (!mitglied.hatBekanntesGeburtsdatum) {
        continue;
      }

      final aktuelleStufe = MemberUtils.aktiveStufe(mitglied);
      if (aktuelleStufe == null || !wechselStufen.contains(aktuelleStufe)) {
        continue;
      }
      if (!_hatAktiveStufenMitgliedsrolle(mitglied, aktuelleStufe, stichtag)) {
        continue;
      }

      final zielStufe = aktuelleStufe.nextStufe;
      if (zielStufe == null ||
          _hatGeplanteZielstufenrolle(mitglied, zielStufe, stichtag)) {
        continue;
      }

      final zielIntervall = altersgrenzen.forStufe(zielStufe);
      final aktuellesIntervall = altersgrenzen.forStufe(aktuelleStufe);
      final faelligSeitJahr =
          mitglied.geburtsdatum.year + zielIntervall.minJahre;
      final spaetestensJahr =
          mitglied.geburtsdatum.year + aktuellesIntervall.maxJahre;

      if (stichtag.year < faelligSeitJahr) {
        continue;
      }

      vorschlaegeByStage[aktuelleStufe]!.add(
        StufenwechselVorschlag(
          mitglied: mitglied,
          aktuelleStufe: aktuelleStufe,
          zielStufe: zielStufe,
          alterAmStichtag: MemberUtils.alterInJahren(
            mitglied,
            stichtag: stichtag,
          ),
          faelligSeitJahr: faelligSeitJahr,
          spaetestensJahr: spaetestensJahr,
          istUeberfaellig: stichtag.year > spaetestensJahr,
        ),
      );
    }

    for (final vorschlaege in vorschlaegeByStage.values) {
      vorschlaege.sort((left, right) {
        final dueCompare = left.spaetestensJahr.compareTo(
          right.spaetestensJahr,
        );
        if (dueCompare != 0) {
          return dueCompare;
        }
        return left.mitglied.nachname.compareTo(right.mitglied.nachname);
      });
    }

    return wechselStufen
        .map(
          (stage) => StufenwechselVorschlagsSection(
            stageFrom: stage,
            stageTo: stage.nextStufe!,
            vorschlaege: List.unmodifiable(vorschlaegeByStage[stage]!),
          ),
        )
        .toList(growable: false);
  }

  bool _hatAktiveStufenMitgliedsrolle(
    Mitglied mitglied,
    Stufe stufe,
    DateTime stichtag,
  ) {
    return mitglied.roles.any(
      (role) =>
          role.isActiveAt(stichtag) &&
          !MemberUtils.istMitgliederRolle(role) &&
          role.stufe == stufe &&
          role.art == RoleCategory.mitglied,
    );
  }

  bool _hatGeplanteZielstufenrolle(
    Mitglied mitglied,
    Stufe zielStufe,
    DateTime stichtag,
  ) {
    return mitglied.roles.any(
      (role) =>
          role.effectiveStart.isAfter(stichtag) &&
          !MemberUtils.istMitgliederRolle(role) &&
          role.stufe == zielStufe &&
          role.art == RoleCategory.mitglied,
    );
  }
}

import '../arbeitskontext/arbeitskontext_read_model.dart';
import '../member/mitglied.dart';
import '../member_filters/beitragsart.dart';
import '../member_filters/usecases/ermittle_beitragsart_im_arbeitskontext_usecase.dart';
import '../stufe/arbeitskontext_stufen_mapping.dart';
import '../taetigkeit/klassifiziere_mitglied_usecase.dart';
import '../taetigkeit/roles.dart';
import '../taetigkeit/stufe.dart';
import 'stammes_snapshot.dart';

/// Leitet aus dem Arbeitskontext die aggregierten Kennzahlen eines Stammes ab.
///
/// Es werden ausschliesslich Zaehlwerte gebildet; Namen, Geburtsdaten oder
/// andere Einzeldaten verlassen diese Funktion nicht.
class BaueStammesKennzahlenUseCase {
  const BaueStammesKennzahlenUseCase({
    KlassifiziereMitgliedUseCase klassifiziereMitgliedUseCase =
        const KlassifiziereMitgliedUseCase(),
    ErmittleBeitragsartImArbeitskontextUseCase ermittleBeitragsartUseCase =
        const ErmittleBeitragsartImArbeitskontextUseCase(),
  }) : _klassifiziere = klassifiziereMitgliedUseCase,
       _ermittleBeitragsart = ermittleBeitragsartUseCase;

  final KlassifiziereMitgliedUseCase _klassifiziere;
  final ErmittleBeitragsartImArbeitskontextUseCase _ermittleBeitragsart;

  StammesKennzahlen call(
    ArbeitskontextReadModel readModel, {
    required DateTime stichtag,
  }) {
    final memberById = <String, Mitglied>{
      for (final mitglied in readModel.mitglieder)
        mitglied.mitgliedsnummer: mitglied,
    };
    final gruppenById = <int, ArbeitskontextGruppe>{
      for (final gruppe in readModel.gruppen) gruppe.id: gruppe,
    };

    final mitgliederJeStufe = <Stufe, Set<String>>{};
    final leitendeJeStufe = <Stufe, Set<String>>{};

    for (final zuordnung in readModel.mitgliedsZuordnungen) {
      if (!memberById.containsKey(zuordnung.mitgliedsnummer)) {
        continue;
      }
      final stufe = _stufeFuer(gruppenById[zuordnung.gruppenId]?.gruppenTyp);
      if (stufe == null) {
        continue;
      }
      if (_klassifiziere.istLeitungsrolleInStammGruppe(
        zuordnung,
        gruppenById,
      )) {
        leitendeJeStufe
            .putIfAbsent(stufe, () => <String>{})
            .add(zuordnung.mitgliedsnummer);
      } else if (_klassifiziere.istMitgliedsrolleInStammGruppe(
        zuordnung,
        gruppenById,
      )) {
        mitgliederJeStufe
            .putIfAbsent(stufe, () => <String>{})
            .add(zuordnung.mitgliedsnummer);
      }
    }

    final leitende = <Mitglied>[];
    var sonstige = 0;
    for (final mitglied in readModel.mitglieder) {
      switch (_klassifiziere.klassifiziere(
        mitglied.mitgliedsnummer,
        readModel,
      )) {
        case RoleCategory.leitung:
          leitende.add(mitglied);
        case RoleCategory.sonstiges:
          sonstige++;
        case RoleCategory.mitglied:
          break;
      }
    }

    final beitragsarten = _ermittleBeitragsart(readModel);

    GeschlechterVerteilung verteilung(
      Map<Stufe, Set<String>> source,
      Stufe s,
    ) => _geschlechterVerteilung(source[s] ?? const <String>{}, memberById);

    return StammesKennzahlen(
      // Ohne sichtbare Mitgliedschaftsrollen ist die Zahl unbekannt, nicht 0.
      aktiveMitglieder: beitragsarten.isEmpty
          ? null
          : beitragsarten.values
                .where((art) => art == Beitragsart.ordentlicheMitgliedschaft)
                .length,
      biber: verteilung(mitgliederJeStufe, Stufe.biber),
      woelflinge: verteilung(mitgliederJeStufe, Stufe.woelfling),
      jungpfadfinder: verteilung(mitgliederJeStufe, Stufe.jungpfadfinder),
      pfadfinder: verteilung(mitgliederJeStufe, Stufe.pfadfinder),
      rover: verteilung(mitgliederJeStufe, Stufe.rover),
      leitende: _altersVerteilung(leitende, stichtag),
      leitendeBiber: verteilung(leitendeJeStufe, Stufe.biber),
      leitendeWoelflinge: verteilung(leitendeJeStufe, Stufe.woelfling),
      leitendeJungpfadfinder: verteilung(leitendeJeStufe, Stufe.jungpfadfinder),
      leitendePfadfinder: verteilung(leitendeJeStufe, Stufe.pfadfinder),
      leitendeRover: verteilung(leitendeJeStufe, Stufe.rover),
      nichtLeitendeErwachsene: sonstige,
    );
  }

  Stufe? _stufeFuer(String? gruppenTyp) {
    for (final regel in ArbeitskontextStufenMapping.regeln) {
      if (regel.passtZu(gruppenTyp: gruppenTyp)) {
        return regel.stufe;
      }
    }
    return null;
  }

  GeschlechterVerteilung _geschlechterVerteilung(
    Set<String> mitgliedsnummern,
    Map<String, Mitglied> memberById,
  ) {
    var maennlich = 0;
    var weiblich = 0;
    var divers = 0;
    var unbekannt = 0;

    for (final nummer in mitgliedsnummern) {
      final gender = (memberById[nummer]?.gender ?? '').trim().toLowerCase();
      if (gender == 'm' || gender == 'male' || gender == 'maennlich') {
        maennlich++;
      } else if (gender == 'w' || gender == 'female' || gender == 'weiblich') {
        weiblich++;
      } else if (gender == 'd' || gender == 'divers') {
        divers++;
      } else {
        unbekannt++;
      }
    }

    return GeschlechterVerteilung(
      gesamt: mitgliedsnummern.length,
      maennlich: maennlich,
      weiblich: weiblich,
      divers: divers,
      geschlechtUnbekannt: unbekannt,
    );
  }

  /// Leitende ohne bekanntes Geburtsdatum zaehlen nur in `gesamt`.
  LeitendeAltersVerteilung _altersVerteilung(
    List<Mitglied> leitende,
    DateTime stichtag,
  ) {
    var unter21 = 0;
    var von21Bis30 = 0;
    var von31Bis40 = 0;
    var von41Bis50 = 0;
    var von51Bis60 = 0;
    var ueber60 = 0;

    for (final mitglied in leitende) {
      if (mitglied.geburtsdatum == Mitglied.peoplePlaceholderDate) {
        continue;
      }
      final alter = _alterInJahren(mitglied.geburtsdatum, stichtag);
      if (alter < 21) {
        unter21++;
      } else if (alter <= 30) {
        von21Bis30++;
      } else if (alter <= 40) {
        von31Bis40++;
      } else if (alter <= 50) {
        von41Bis50++;
      } else if (alter <= 60) {
        von51Bis60++;
      } else {
        ueber60++;
      }
    }

    return LeitendeAltersVerteilung(
      gesamt: leitende.length,
      unter21: unter21,
      von21Bis30: von21Bis30,
      von31Bis40: von31Bis40,
      von41Bis50: von41Bis50,
      von51Bis60: von51Bis60,
      ueber60: ueber60,
    );
  }

  int _alterInJahren(DateTime geburtsdatum, DateTime stichtag) {
    var alter = stichtag.year - geburtsdatum.year;
    final hatteGeburtstag =
        stichtag.month > geburtsdatum.month ||
        (stichtag.month == geburtsdatum.month &&
            stichtag.day >= geburtsdatum.day);
    if (!hatteGeburtstag) {
      alter--;
    }
    return alter;
  }
}

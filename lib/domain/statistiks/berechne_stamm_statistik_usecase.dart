import '../arbeitskontext/arbeitskontext_read_model.dart';
import '../member/mitglied.dart';
import '../stufe/altersgrenzen.dart';
import '../stufe/arbeitskontext_stufen_mapping.dart';
import '../stufenwechsel/ermittle_stufenwechsel_vorschlaege_usecase.dart';
import '../taetigkeit/klassifiziere_mitglied_usecase.dart';
import '../taetigkeit/roles.dart';
import '../taetigkeit/stufe.dart';
import 'stamm_statistik.dart';
import 'statistik_mathe.dart';

/// Berechnet die Kennzahlen eines Stamms für die Statistik-Kacheln.
///
/// Grundlage sind die Mitgliedszuordnungen des Arbeitskontexts. Die Prognose
/// zum Stufenwechsel braucht zusätzlich die Rollen der Mitglieder und wird
/// erst berechnet, wenn sie geladen sind.
class BerechneStammStatistikUseCase {
  const BerechneStammStatistikUseCase({
    KlassifiziereMitgliedUseCase klassifiziereMitgliedUseCase =
        const KlassifiziereMitgliedUseCase(),
    ErmittleStufenwechselVorschlaegeUseCase stufenwechselUseCase =
        const ErmittleStufenwechselVorschlaegeUseCase(),
  }) : _klassifiziere = klassifiziereMitgliedUseCase,
       _stufenwechsel = stufenwechselUseCase;

  final KlassifiziereMitgliedUseCase _klassifiziere;
  final ErmittleStufenwechselVorschlaegeUseCase _stufenwechsel;

  static const List<Stufe> stufen = <Stufe>[
    Stufe.biber,
    Stufe.woelfling,
    Stufe.jungpfadfinder,
    Stufe.pfadfinder,
    Stufe.rover,
  ];

  StammStatistik call(
    ArbeitskontextReadModel readModel, {
    required DateTime heute,
    Altersgrenzen? altersgrenzen,
    DateTime? stichtag,
  }) {
    final grenzen = altersgrenzen ?? StufenDefaults.build();
    final gruppenById = <int, ArbeitskontextGruppe>{
      for (final gruppe in readModel.gruppen) gruppe.id: gruppe,
    };
    final mitgliedById = <String, Mitglied>{
      for (final mitglied in readModel.mitglieder)
        mitglied.mitgliedsnummer: mitglied,
    };

    // Kinder & Jugendliche, Leitende, Sonstige – jede Person genau einmal.
    final kinderIds = <String>{};
    final leitungsIds = <String>{};
    var sonstige = 0;
    for (final mitglied in readModel.mitglieder) {
      switch (_klassifiziere.klassifiziere(
        mitglied.mitgliedsnummer,
        readModel,
      )) {
        case RoleCategory.mitglied:
          kinderIds.add(mitglied.mitgliedsnummer);
        case RoleCategory.leitung:
          leitungsIds.add(mitglied.mitgliedsnummer);
        case RoleCategory.sonstiges:
          sonstige++;
      }
    }

    // Gruppen und Stufen aus den Zuordnungen.
    final zuordnungenJeGruppe = <int, List<ArbeitskontextMitgliedsZuordnung>>{};
    for (final zuordnung in readModel.mitgliedsZuordnungen) {
      zuordnungenJeGruppe
          .putIfAbsent(
            zuordnung.gruppenId,
            () => <ArbeitskontextMitgliedsZuordnung>[],
          )
          .add(zuordnung);
    }
    final kinderJeStufe = {for (final s in stufen) s: <String>{}};
    final leitendeJeStufe = {for (final s in stufen) s: <String>{}};
    final gruppenJeStufe = {for (final s in stufen) s: <GruppenStatistik>[]};
    for (final gruppe in readModel.gruppen) {
      final stufe = _stufeFuer(gruppe.gruppenTyp);
      final zuordnungen = zuordnungenJeGruppe[gruppe.id];
      if (stufe == null || zuordnungen == null || zuordnungen.isEmpty) {
        continue;
      }
      final kinderInGruppe = <String>{};
      final leitendeInGruppe = <String>{};
      for (final zuordnung in zuordnungen) {
        if (_klassifiziere.istLeitungsrolleInStammGruppe(
          zuordnung,
          gruppenById,
        )) {
          leitendeInGruppe.add(zuordnung.mitgliedsnummer);
        } else if (_klassifiziere.istMitgliedsrolleInStammGruppe(
          zuordnung,
          gruppenById,
        )) {
          kinderInGruppe.add(zuordnung.mitgliedsnummer);
        }
      }
      gruppenJeStufe[stufe]!.add(
        GruppenStatistik(
          gruppenId: gruppe.id,
          name: gruppe.anzeigename,
          stufe: stufe,
          kinder: kinderInGruppe.length,
          leitende: leitendeInGruppe.length,
        ),
      );
      kinderJeStufe[stufe]!.addAll(kinderInGruppe);
      leitendeJeStufe[stufe]!.addAll(leitendeInGruppe);
    }

    final ohneGeburtsdatum = <String>{};
    final stufenStatistik = stufen
        .map((stufe) {
          final alter = <double>[];
          for (final id in kinderJeStufe[stufe]!) {
            final mitglied = mitgliedById[id];
            if (mitglied == null) continue;
            if (!mitglied.hatBekanntesGeburtsdatum) {
              ohneGeburtsdatum.add(id);
              continue;
            }
            alter.add(jahreZwischen(mitglied.geburtsdatum, heute));
          }
          alter.sort();
          final gruppen = gruppenJeStufe[stufe]!
            ..sort((a, b) => a.name.compareTo(b.name));
          return StufenStatistik(
            stufe: stufe,
            gruppen: List.unmodifiable(gruppen),
            kinder: kinderJeStufe[stufe]!.length,
            leitende: leitendeJeStufe[stufe]!.length,
            alter: List.unmodifiable(alter),
          );
        })
        .toList(growable: false);

    final geschlecht = {for (final k in GeschlechtKategorie.values) k: 0};
    for (final id in kinderIds) {
      final kategorie = GeschlechtKategorie.aus(mitgliedById[id]?.gender);
      geschlecht[kategorie] = geschlecht[kategorie]! + 1;
    }

    return StammStatistik(
      stammName: readModel.arbeitskontext.aktiverLayer.name,
      personen: readModel.mitglieder.length,
      kinder: kinderIds.length,
      leitende: leitungsIds.length,
      sonstige: sonstige,
      stufen: stufenStatistik,
      prognose: stichtag != null && readModel.rolesSindGeladen
          ? _prognose(
              readModel,
              stufenStatistik,
              kinderJeStufe[Stufe.rover]!,
              mitgliedById,
              grenzen,
              stichtag,
            )
          : null,
      bindung: _bindung(readModel.mitglieder, kinderIds, leitungsIds, heute),
      geschlecht: Map.unmodifiable(geschlecht),
      ohneGeburtsdatum: ohneGeburtsdatum.length,
    );
  }

  StufenwechselPrognose _prognose(
    ArbeitskontextReadModel readModel,
    List<StufenStatistik> stufenStatistik,
    Set<String> roverIds,
    Map<String, Mitglied> mitgliedById,
    Altersgrenzen grenzen,
    DateTime stichtag,
  ) {
    final ab = {for (final s in stufen) s: 0};
    final zu = {for (final s in stufen) s: 0};
    var anzahl = 0;
    final sections = _stufenwechsel(
      mitglieder: readModel.mitglieder,
      stichtag: stichtag,
      altersgrenzen: grenzen,
    );
    for (final section in sections) {
      final n = section.vorschlaege.length;
      anzahl += n;
      if (ab.containsKey(section.stageFrom)) {
        ab[section.stageFrom] = ab[section.stageFrom]! + n;
      }
      if (zu.containsKey(section.stageTo)) {
        zu[section.stageTo] = zu[section.stageTo]! + n;
      }
    }
    // Rover wechseln in keine Stufe mehr, werden aber zu alt für die Runde.
    final roverHoechstalter = grenzen.forStufe(Stufe.rover).maxJahre;
    for (final id in roverIds) {
      final mitglied = mitgliedById[id];
      if (mitglied == null || !mitglied.hatBekanntesGeburtsdatum) continue;
      if (mitglied.geburtsdatum.year + roverHoechstalter < stichtag.year) {
        ab[Stufe.rover] = ab[Stufe.rover]! + 1;
      }
    }
    return StufenwechselPrognose(
      stichtag: stichtag,
      anzahl: anzahl,
      stufen: stufenStatistik
          .map(
            (s) => StufenwechselStufe(
              stufe: s.stufe,
              heute: s.kinder,
              ab: ab[s.stufe]!,
              zu: zu[s.stufe]!,
            ),
          )
          .toList(growable: false),
    );
  }

  BindungStatistik _bindung(
    List<Mitglied> mitglieder,
    Set<String> kinderIds,
    Set<String> leitungsIds,
    DateTime heute,
  ) {
    final mitEintritt = mitglieder
        .where((m) => m.hatBekanntesEintrittsdatum)
        .toList(growable: false);
    final vorZwoelfMonaten = DateTime(heute.year - 1, heute.month, heute.day);
    final neu = mitEintritt
        .where(
          (m) =>
              m.eintrittsdatum.isAfter(vorZwoelfMonaten) &&
              !m.eintrittsdatum.isAfter(heute),
        )
        .length;
    final monate = <EintritteImMonat>[];
    for (var i = 11; i >= 0; i--) {
      final monat = DateTime(heute.year, heute.month - i, 1);
      monate.add(
        EintritteImMonat(
          jahr: monat.year,
          monat: monat.month,
          anzahl: mitEintritt
              .where(
                (m) =>
                    m.eintrittsdatum.year == monat.year &&
                    m.eintrittsdatum.month == monat.month &&
                    !m.eintrittsdatum.isAfter(heute),
              )
              .length,
        ),
      );
    }
    double? dauer(Set<String> ids) => median(
      mitEintritt
          .where((m) => ids.contains(m.mitgliedsnummer))
          .map((m) => jahreZwischen(m.eintrittsdatum, heute)),
    );
    return BindungStatistik(
      neuInZwoelfMonaten: neu,
      eintritteJeMonat: List.unmodifiable(monate),
      medianJahreKinder: dauer(kinderIds),
      medianJahreLeitende: dauer(leitungsIds),
    );
  }

  Stufe? _stufeFuer(String? gruppenTyp) {
    for (final regel in ArbeitskontextStufenMapping.regeln) {
      if (regel.passtZu(gruppenTyp: gruppenTyp)) return regel.stufe;
    }
    return null;
  }
}

import '../arbeitskontext/arbeitskontext_read_model.dart';
import '../member/mitglied.dart';
import 'ermittle_qualifikations_uebersicht_usecase.dart';
import 'qualifikations_einstellungen.dart';
import 'qualifikations_status.dart';

/// Eine geplante Mitteilung: eigene Ablaeufe einzeln, fremde je Tag und Art
/// gebuendelt.
class GeplanteQualifikationsErinnerung {
  const GeplanteQualifikationsErinnerung({
    required this.zeitpunkt,
    required this.eigene,
    required this.artSchluessel,
    required this.artLabel,
    required this.personen,
    required this.gueltigBis,
    required this.meldeSchluessel,
  });

  final DateTime zeitpunkt;
  final bool eigene;
  final String artSchluessel;
  final String artLabel;

  /// Anzeigenamen der betroffenen Personen; bei eigenen leer.
  final List<String> personen;

  /// Fruehestes Ablaufdatum der gebuendelten Eintraege.
  final DateTime gueltigBis;

  /// Je Person, Art und Ablaufdatum ein Schluessel, um Gemeldetes nicht
  /// erneut zu schicken.
  final List<String> meldeSchluessel;
}

/// Eigene Qualifikation, die bald ablaeuft oder abgelaufen ist (Meldung im
/// Hub).
class EigenerQualifikationsAblauf {
  const EigenerQualifikationsAblauf({
    required this.artLabel,
    required this.gueltigBis,
    required this.abgelaufen,
  });

  final String artLabel;
  final DateTime gueltigBis;
  final bool abgelaufen;
}

class PlaneQualifikationsErinnerungenUseCase {
  const PlaneQualifikationsErinnerungenUseCase({
    this.uebersicht = const ErmittleQualifikationsUebersichtUseCase(),
  });

  /// iOS behaelt hoechstens 64 geplante Mitteilungen je App; Platz fuer
  /// andere Erinnerungen bleibt.
  static const maxMitteilungen = 48;
  static const stunde = 9;

  final ErmittleQualifikationsUebersichtUseCase uebersicht;

  /// Plant Mitteilungen um 9 Uhr. Fremde Ablaeufe nur mit Supporter-Zugang
  /// und „von allen“; eigene aus der Erinnerung je Art oder aus der
  /// eigenen Erinnerung, ohne Dopplung. Liegt der Termin schon zurueck, die
  /// Qualifikation ist aber noch gueltig, kommt die Mitteilung einmalig am
  /// naechsten Morgen. [bereitsGeplant] enthaelt frueher geplante Zeitpunkte
  /// je Meldeschluessel; vergangene gelten als gemeldet.
  List<GeplanteQualifikationsErinnerung> call({
    required ArbeitskontextReadModel readModel,
    required QualifikationsEinstellungen einstellungen,
    required int? eigenePersonId,
    required bool supporter,
    required DateTime jetzt,
    Map<String, DateTime> bereitsGeplant = const <String, DateTime>{},
  }) {
    final heute = DateTime(jetzt.year, jetzt.month, jetzt.day);
    final katalog = uebersicht.katalog(
      readModel: readModel,
      einstellungen: einstellungen,
    );
    final kandidaten = <String, _Kandidat>{};

    void merke(_Kandidat kandidat) {
      final vorhanden = kandidaten[kandidat.meldeSchluessel];
      if (vorhanden == null || kandidat.tageVorher > vorhanden.tageVorher) {
        kandidaten[kandidat.meldeSchluessel] = kandidat;
      }
    }

    if (supporter) {
      for (final eintrag in katalog) {
        if (!eintrag.angezeigt || !eintrag.erinnerung.aktiv) {
          continue;
        }
        final zeile = uebersicht.zeile(
          readModel: readModel,
          katalog: eintrag,
          heute: heute,
        );
        for (final person in zeile.eintraege) {
          final eigene = person.mitglied.personId == eigenePersonId;
          if (eintrag.erinnerung.vonWem == ErinnerungVonWem.ich && !eigene) {
            continue;
          }
          final kandidat = _Kandidat.von(
            art: eintrag.art,
            eintrag: person,
            eigene: eigene,
            tageVorher: eintrag.erinnerung.tageVorher,
            heute: heute,
          );
          if (kandidat != null) {
            merke(kandidat);
          }
        }
      }
    }

    final ich = _eigenesMitglied(readModel, eigenePersonId);
    if (einstellungen.eigene.aktiv && ich != null) {
      for (final eintrag in _eigeneArten(katalog, einstellungen)) {
        final kandidat = _Kandidat.von(
          art: eintrag.art,
          eintrag: uebersicht.eintragFuer(
            readModel: readModel,
            art: eintrag.art,
            mitglied: ich,
            warnschwelleTage: einstellungen.eigene.tageVorher,
            heute: heute,
          ),
          eigene: true,
          tageVorher: einstellungen.eigene.tageVorher,
          heute: heute,
        );
        if (kandidat != null) {
          merke(kandidat);
        }
      }
    }

    final naechsterMorgen = DateTime(
      jetzt.year,
      jetzt.month,
      jetzt.day + (jetzt.hour < stunde ? 0 : 1),
      stunde,
    );
    final eigene = <GeplanteQualifikationsErinnerung>[];
    final gebuendelt = <String, List<_Kandidat>>{};
    final zeitpunkte = <String, DateTime>{};
    for (final kandidat in kandidaten.values) {
      final frueher = bereitsGeplant[kandidat.meldeSchluessel];
      if (frueher != null && !frueher.isAfter(jetzt)) {
        continue;
      }
      final regulaer = DateTime(
        kandidat.gueltigBis.year,
        kandidat.gueltigBis.month,
        kandidat.gueltigBis.day - kandidat.tageVorher,
        stunde,
      );
      final zeitpunkt = regulaer.isAfter(jetzt) ? regulaer : naechsterMorgen;
      if (DateTime(
        zeitpunkt.year,
        zeitpunkt.month,
        zeitpunkt.day,
      ).isAfter(kandidat.gueltigBis)) {
        continue;
      }
      if (kandidat.eigene) {
        eigene.add(
          GeplanteQualifikationsErinnerung(
            zeitpunkt: zeitpunkt,
            eigene: true,
            artSchluessel: kandidat.art.schluessel,
            artLabel: kandidat.art.label,
            personen: const <String>[],
            gueltigBis: kandidat.gueltigBis,
            meldeSchluessel: <String>[kandidat.meldeSchluessel],
          ),
        );
        continue;
      }
      final buendel = '${kandidat.art.schluessel}|$zeitpunkt';
      gebuendelt.putIfAbsent(buendel, () => <_Kandidat>[]).add(kandidat);
      zeitpunkte[buendel] = zeitpunkt;
    }

    final fremde = gebuendelt.entries.map((buendel) {
      final eintraege = buendel.value
        ..sort((a, b) => a.gueltigBis.compareTo(b.gueltigBis));
      return GeplanteQualifikationsErinnerung(
        zeitpunkt: zeitpunkte[buendel.key]!,
        eigene: false,
        artSchluessel: eintraege.first.art.schluessel,
        artLabel: eintraege.first.art.label,
        personen: eintraege.map((k) => k.name).toList(growable: false),
        gueltigBis: eintraege.first.gueltigBis,
        meldeSchluessel: eintraege
            .map((k) => k.meldeSchluessel)
            .toList(growable: false),
      );
    });

    final alle = <GeplanteQualifikationsErinnerung>[...eigene, ...fremde]
      ..sort((a, b) {
        final zeit = a.zeitpunkt.compareTo(b.zeitpunkt);
        if (zeit != 0) {
          return zeit;
        }
        if (a.eigene != b.eigene) {
          return a.eigene ? -1 : 1;
        }
        return a.artLabel.compareTo(b.artLabel);
      });
    return alle.take(maxMitteilungen).toList(growable: false);
  }

  /// Eigene Qualifikationen der gewaehlten Arten, die innerhalb des
  /// Vorlaufs ablaufen oder schon abgelaufen sind.
  List<EigenerQualifikationsAblauf> eigeneAblaeufe({
    required ArbeitskontextReadModel readModel,
    required QualifikationsEinstellungen einstellungen,
    required int? eigenePersonId,
    required DateTime heute,
  }) {
    final ich = _eigenesMitglied(readModel, eigenePersonId);
    if (!einstellungen.eigene.aktiv || ich == null) {
      return const <EigenerQualifikationsAblauf>[];
    }
    final katalog = uebersicht.katalog(
      readModel: readModel,
      einstellungen: einstellungen,
    );
    final ablaeufe = <EigenerQualifikationsAblauf>[];
    for (final eintrag in _eigeneArten(katalog, einstellungen)) {
      final stand = uebersicht.eintragFuer(
        readModel: readModel,
        art: eintrag.art,
        mitglied: ich,
        warnschwelleTage: einstellungen.eigene.tageVorher,
        heute: heute,
      );
      final gueltigBis = stand.gueltigBis;
      if (gueltigBis == null) {
        continue;
      }
      if (stand.status == QualifikationsStatus.baldAblaufend ||
          stand.status == QualifikationsStatus.abgelaufen) {
        ablaeufe.add(
          EigenerQualifikationsAblauf(
            artLabel: eintrag.art.label,
            gueltigBis: gueltigBis,
            abgelaufen: stand.status == QualifikationsStatus.abgelaufen,
          ),
        );
      }
    }
    ablaeufe.sort((a, b) => a.gueltigBis.compareTo(b.gueltigBis));
    return ablaeufe;
  }

  /// Gewaehlte Arten der eigenen Erinnerung; ohne Auswahl die Vorgaben.
  Iterable<KatalogEintrag> _eigeneArten(
    List<KatalogEintrag> katalog,
    QualifikationsEinstellungen einstellungen,
  ) {
    final gewaehlt = einstellungen.eigene.arten;
    return katalog.where(
      (eintrag) => gewaehlt == null
          ? QualifikationsVorgaben.istVorgabe(
              eintrag.art.schluessel,
              eintrag.art.label,
            )
          : gewaehlt.contains(eintrag.art.schluessel),
    );
  }

  Mitglied? _eigenesMitglied(
    ArbeitskontextReadModel readModel,
    int? eigenePersonId,
  ) {
    if (eigenePersonId == null) {
      return null;
    }
    for (final mitglied in readModel.mitglieder) {
      if (mitglied.personId == eigenePersonId) {
        return mitglied;
      }
    }
    return null;
  }
}

class _Kandidat {
  const _Kandidat({
    required this.art,
    required this.name,
    required this.gueltigBis,
    required this.eigene,
    required this.tageVorher,
    required this.meldeSchluessel,
  });

  final UebersichtArt art;
  final String name;
  final DateTime gueltigBis;
  final bool eigene;
  final int tageVorher;
  final String meldeSchluessel;

  /// `null`, wenn es nichts zu erinnern gibt: kein Datum, ohne Ablauf oder
  /// schon abgelaufen.
  static _Kandidat? von({
    required UebersichtArt art,
    required UebersichtEintrag eintrag,
    required bool eigene,
    required int tageVorher,
    required DateTime heute,
  }) {
    final gueltigBis = eintrag.gueltigBis;
    if (gueltigBis == null ||
        eintrag.ohneAblauf ||
        gueltigBis.isBefore(heute)) {
      return null;
    }
    final tag = DateTime(gueltigBis.year, gueltigBis.month, gueltigBis.day);
    return _Kandidat(
      art: art,
      name: anzeigenameFuerErinnerung(eintrag.mitglied),
      gueltigBis: tag,
      eigene: eigene,
      tageVorher: tageVorher,
      meldeSchluessel:
          'p${eintrag.mitglied.personId}|${art.schluessel}|'
          '${tag.toIso8601String().substring(0, 10)}',
    );
  }
}

/// Fahrtenname oder voller Name.
String anzeigenameFuerErinnerung(Mitglied mitglied) {
  final fahrtenname = mitglied.fahrtenname?.trim();
  if (fahrtenname != null && fahrtenname.isNotEmpty) {
    return fahrtenname;
  }
  final name = mitglied.fullName.trim();
  return name.isEmpty ? mitglied.mitgliedsnummer : name;
}

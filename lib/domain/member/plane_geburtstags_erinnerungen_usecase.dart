import '../arbeitskontext/arbeitskontext_read_model.dart';
import '../taetigkeit/stufe.dart';
import 'member_utils.dart';
import 'mitglied.dart';

/// Ein Geburtstagskind mit datensparsamem Namen (Vorname und Initial des
/// Nachnamens) und dem neuen Alter.
typedef GeburtstagsPerson = ({String kurzname, int alter});

/// Eine geplante Geburtstags-Mitteilung je Tag; mehrere Geburtstage am
/// selben Tag kommen gebuendelt.
class GeplanteGeburtstagsErinnerung {
  const GeplanteGeburtstagsErinnerung({
    required this.zeitpunkt,
    required this.personen,
  });

  final DateTime zeitpunkt;

  /// Nach Kurzname und Mitgliedsnummer sortiert, nie leer.
  final List<GeburtstagsPerson> personen;

  @override
  bool operator ==(Object other) {
    if (other is! GeplanteGeburtstagsErinnerung ||
        other.zeitpunkt != zeitpunkt ||
        other.personen.length != personen.length) {
      return false;
    }
    for (var i = 0; i < personen.length; i++) {
      if (other.personen[i] != personen[i]) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(zeitpunkt, Object.hashAll(personen));
}

class PlaneGeburtstagsErinnerungenUseCase {
  const PlaneGeburtstagsErinnerungenUseCase();

  /// iOS behaelt hoechstens 64 geplante Mitteilungen je App; Platz fuer
  /// Qualifikationen und Datenablauf bleibt. Gezaehlt werden Tage.
  static const maxMitteilungen = 30;
  static const fensterTage = 60;
  static const stunde = 9;

  /// Plant die naechsten Geburtstage innerhalb von [fensterTage] Tagen
  /// (heute eingeschlossen) jeweils um 9 Uhr Ortszeit, je Tag eine
  /// Mitteilung, fruehester zuerst. Beruecksichtigt nur Mitglieder, deren
  /// Stufe in [stufen] liegt; ohne bekanntes Geburtsdatum oder ohne aktive
  /// Rolle entfaellt die Person. Ist es heute schon 9 Uhr oder spaeter, kommt
  /// der heutige nicht mehr. Ab [datenEnde] (Datenablauf) wird nichts mehr
  /// geplant.
  List<GeplanteGeburtstagsErinnerung> call({
    required ArbeitskontextReadModel readModel,
    required Set<Stufe> stufen,
    required DateTime jetzt,
    DateTime? datenEnde,
  }) {
    if (stufen.isEmpty) {
      return const <GeplanteGeburtstagsErinnerung>[];
    }
    final heute = DateTime(jetzt.year, jetzt.month, jetzt.day);
    final fensterEnde = DateTime(
      heute.year,
      heute.month,
      heute.day + fensterTage,
    );
    final kandidaten = <(DateTime, GeburtstagsPerson, Mitglied)>[];
    for (final mitglied in readModel.mitglieder) {
      if (!mitglied.hatBekanntesGeburtsdatum) {
        continue;
      }
      final stufe = stufeFuerGeburtstag(mitglied, heute: heute);
      if (stufe == null || !stufen.contains(stufe)) {
        continue;
      }
      final zeitpunkt = _naechsterTermin(mitglied.geburtsdatum, jetzt);
      if (!zeitpunkt.isBefore(fensterEnde) ||
          (datenEnde != null && !zeitpunkt.isBefore(datenEnde))) {
        continue;
      }
      final alter = zeitpunkt.year - mitglied.geburtsdatum.year;
      if (alter < 1) {
        continue;
      }
      kandidaten.add((
        zeitpunkt,
        (kurzname: kurzname(mitglied), alter: alter),
        mitglied,
      ));
    }
    kandidaten.sort((a, b) {
      final zeit = a.$1.compareTo(b.$1);
      if (zeit != 0) {
        return zeit;
      }
      final name = a.$2.kurzname.compareTo(b.$2.kurzname);
      if (name != 0) {
        return name;
      }
      return a.$3.mitgliedsnummer.compareTo(b.$3.mitgliedsnummer);
    });
    final jeTag = <DateTime, List<GeburtstagsPerson>>{};
    for (final kandidat in kandidaten) {
      jeTag
          .putIfAbsent(kandidat.$1, () => <GeburtstagsPerson>[])
          .add(kandidat.$2);
    }
    return jeTag.entries
        .take(maxMitteilungen)
        .map(
          (tag) => GeplanteGeburtstagsErinnerung(
            zeitpunkt: tag.key,
            personen: List<GeburtstagsPerson>.unmodifiable(tag.value),
          ),
        )
        .toList(growable: false);
  }

  /// Stufe wie in der Mitgliederliste ([MemberUtils]): Wer aktiv leitet,
  /// zaehlt zu [Stufe.leitung]; sonst gilt die Stufe der priorisierten
  /// aktiven Rolle. Ohne aktive Rolle `null`.
  static Stufe? stufeFuerGeburtstag(Mitglied mitglied, {DateTime? heute}) {
    if (MemberUtils.isLeitung(mitglied, heute: heute)) {
      return Stufe.leitung;
    }
    return MemberUtils.aktiveStufe(mitglied, heute: heute);
  }

  /// Vorname und Initial des Nachnamens, z. B. „Lena B.“.
  static String kurzname(Mitglied mitglied) {
    final vorname = mitglied.vorname.trim();
    final nachname = mitglied.nachname.trim();
    final initial = nachname.isEmpty
        ? ''
        : '${String.fromCharCode(nachname.runes.first)}.';
    return [vorname, initial].where((teil) => teil.isNotEmpty).join(' ');
  }

  DateTime _naechsterTermin(DateTime geburtsdatum, DateTime jetzt) {
    final diesesJahr = _terminIm(geburtsdatum, jetzt.year);
    if (diesesJahr.isAfter(jetzt)) {
      return diesesJahr;
    }
    return _terminIm(geburtsdatum, jetzt.year + 1);
  }

  /// Wer am 29.02. geboren ist, bekommt die Erinnerung in Nicht-Schaltjahren
  /// am 28.02.
  DateTime _terminIm(DateTime geburtsdatum, int jahr) {
    var tag = geburtsdatum.day;
    if (geburtsdatum.month == DateTime.february &&
        tag == 29 &&
        !_istSchaltjahr(jahr)) {
      tag = 28;
    }
    return DateTime(jahr, geburtsdatum.month, tag, stunde);
  }

  static bool _istSchaltjahr(int jahr) =>
      (jahr % 4 == 0 && jahr % 100 != 0) || jahr % 400 == 0;
}

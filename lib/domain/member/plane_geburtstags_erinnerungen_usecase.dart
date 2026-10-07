import '../arbeitskontext/arbeitskontext_read_model.dart';
import '../taetigkeit/stufe.dart';
import 'member_utils.dart';
import 'mitglied.dart';

/// Eine geplante Geburtstags-Mitteilung mit datensparsamem Namen
/// (Vorname und Initial des Nachnamens) und dem neuen Alter.
class GeplanteGeburtstagsErinnerung {
  const GeplanteGeburtstagsErinnerung({
    required this.zeitpunkt,
    required this.kurzname,
    required this.alter,
  });

  final DateTime zeitpunkt;
  final String kurzname;
  final int alter;

  @override
  bool operator ==(Object other) =>
      other is GeplanteGeburtstagsErinnerung &&
      other.zeitpunkt == zeitpunkt &&
      other.kurzname == kurzname &&
      other.alter == alter;

  @override
  int get hashCode => Object.hash(zeitpunkt, kurzname, alter);
}

class PlaneGeburtstagsErinnerungenUseCase {
  const PlaneGeburtstagsErinnerungenUseCase();

  /// iOS behaelt hoechstens 64 geplante Mitteilungen je App; Platz fuer
  /// Qualifikationen und Datenablauf bleibt.
  static const maxMitteilungen = 30;
  static const fensterTage = 60;
  static const stunde = 9;

  /// Plant die naechsten Geburtstage innerhalb von [fensterTage] Tagen
  /// (heute eingeschlossen) jeweils um 9 Uhr Ortszeit, fruehester zuerst.
  /// Beruecksichtigt nur Mitglieder, deren Stufe in [stufen] liegt; ohne
  /// bekanntes Geburtsdatum oder ohne aktive Rolle entfaellt die Person.
  /// Ist es heute schon 9 Uhr oder spaeter, kommt der heutige nicht mehr.
  List<GeplanteGeburtstagsErinnerung> call({
    required ArbeitskontextReadModel readModel,
    required Set<Stufe> stufen,
    required DateTime jetzt,
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
    final kandidaten = <(GeplanteGeburtstagsErinnerung, Mitglied)>[];
    for (final mitglied in readModel.mitglieder) {
      if (!mitglied.hatBekanntesGeburtsdatum) {
        continue;
      }
      final stufe = stufeFuerGeburtstag(mitglied, heute: heute);
      if (stufe == null || !stufen.contains(stufe)) {
        continue;
      }
      final zeitpunkt = _naechsterTermin(mitglied.geburtsdatum, jetzt);
      if (!zeitpunkt.isBefore(fensterEnde)) {
        continue;
      }
      final alter = zeitpunkt.year - mitglied.geburtsdatum.year;
      if (alter < 1) {
        continue;
      }
      kandidaten.add((
        GeplanteGeburtstagsErinnerung(
          zeitpunkt: zeitpunkt,
          kurzname: kurzname(mitglied),
          alter: alter,
        ),
        mitglied,
      ));
    }
    kandidaten.sort((a, b) {
      final zeit = a.$1.zeitpunkt.compareTo(b.$1.zeitpunkt);
      if (zeit != 0) {
        return zeit;
      }
      final name = a.$1.kurzname.compareTo(b.$1.kurzname);
      if (name != 0) {
        return name;
      }
      return a.$2.mitgliedsnummer.compareTo(b.$2.mitgliedsnummer);
    });
    return kandidaten
        .take(maxMitteilungen)
        .map((kandidat) => kandidat.$1)
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

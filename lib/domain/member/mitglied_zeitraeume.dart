import 'mitglied.dart';

/// Naechster Geburtstag ab [heute] (nur Datum), mit Tagen bis dahin und dem
/// Alter, das dann erreicht wird.
class NaechsterGeburtstag {
  const NaechsterGeburtstag({
    required this.datum,
    required this.tage,
    required this.wirdAlter,
  });

  final DateTime datum;
  final int tage;
  final int wirdAlter;
}

NaechsterGeburtstag? naechsterGeburtstag(Mitglied mitglied, DateTime heute) {
  if (!mitglied.hatBekanntesGeburtsdatum) {
    return null;
  }
  final geburt = mitglied.geburtsdatum;
  final tag = DateTime(heute.year, heute.month, heute.day);
  var datum = DateTime(tag.year, geburt.month, geburt.day);
  if (datum.isBefore(tag)) {
    datum = DateTime(tag.year + 1, geburt.month, geburt.day);
  }
  return NaechsterGeburtstag(
    datum: datum,
    tage: _tageZwischen(tag, datum),
    wirdAlter: datum.year - geburt.year,
  );
}

/// Ganze Kalendermonate von [von] bis [bis].
int monateZwischen(DateTime von, DateTime bis) {
  var monate = (bis.year - von.year) * 12 + bis.month - von.month;
  if (bis.day < von.day) {
    monate -= 1;
  }
  return monate < 0 ? 0 : monate;
}

int tageZwischen(DateTime von, DateTime bis) => _tageZwischen(
  DateTime(von.year, von.month, von.day),
  DateTime(bis.year, bis.month, bis.day),
);

// UTC-Rechnung vermeidet Spruenge durch die Zeitumstellung.
int _tageZwischen(DateTime von, DateTime bis) => DateTime.utc(
  bis.year,
  bis.month,
  bis.day,
).difference(DateTime.utc(von.year, von.month, von.day)).inDays;

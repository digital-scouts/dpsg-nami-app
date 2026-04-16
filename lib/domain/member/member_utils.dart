import '../taetigkeit/role_derivation.dart';
import '../taetigkeit/roles.dart';
import '../taetigkeit/stufe.dart';
import 'mitglied.dart';

/// Reine Domain-Hilfsfunktionen rund um `Mitglied` und `Taetigkeit`.
/// Keine Flutter-Abhängigkeiten, leicht testbar.
class MemberUtils {
  /// Hat das Mitglied aktuell eine aktive Tätigkeit mit Art `Leitung`?
  static bool isLeitung(Mitglied m) {
    return m.roles.any((t) => t.istAktiv && t.art == RoleCategory.leitung);
  }

  /// Liefert die Stufe der neuesten aktiven Tätigkeit.
  /// Falls keine aktive Tätigkeit existiert, gibt `null` zurück.
  static Stufe? aktiveStufe(Mitglied m) {
    final aktive = m.roles.where((t) => t.istAktiv).toList();
    if (aktive.isEmpty) return null;

    aktive.sort((a, b) => b.start.compareTo(a.start));
    return aktive.first.stufe;
  }

  /// Alter in vollen Jahren zum [stichtag] (Default: heute).
  static int alterInJahren(Mitglied m, {DateTime? stichtag}) {
    final now = stichtag ?? DateTime.now();
    var years = now.year - m.geburtsdatum.year;
    final hatGeburtstagSchon =
        (now.month > m.geburtsdatum.month) ||
        (now.month == m.geburtsdatum.month && now.day >= m.geburtsdatum.day);
    if (!hatGeburtstagSchon) {
      years -= 1;
    }
    return years;
  }
}

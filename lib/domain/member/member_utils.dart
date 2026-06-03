import '../taetigkeit/role_derivation.dart';
import '../taetigkeit/roles.dart';
import '../taetigkeit/stufe.dart';
import 'mitglied.dart';

/// Reine Domain-Hilfsfunktionen rund um `Mitglied` und `Taetigkeit`.
/// Keine Flutter-Abhängigkeiten, leicht testbar.
class MemberUtils {
  /// Hat das Mitglied aktuell eine aktive Tätigkeit mit Art `Leitung`?
  static bool isLeitung(Mitglied m) {
    return m.roles.any(
      (t) =>
          t.istAktiv && !istMitgliederRolle(t) && t.art == RoleCategory.leitung,
    );
  }

  /// Liefert die visuell priorisierte Stufe einer aktiven Tätigkeit.
  /// Priorität: Leitung vor Mitglied vor Sonstiges.
  /// Innerhalb derselben Art: rover vor pfadfinder vor jungpfadfinder vor
  /// woelfling vor biber vor leitung.
  /// Rollen vom Typ Group::Mitglieder werden ignoriert.
  static Stufe? aktiveStufe(Mitglied m) {
    return visualRole(m)?.stufe;
  }

  static MemberVisualRole? visualRole(Mitglied m) {
    final aktive = m.roles
        .where((t) => t.istAktiv && !istMitgliederRolle(t))
        .toList(growable: false);
    if (aktive.isEmpty) {
      return null;
    }

    final sortiert = [...aktive]
      ..sort((left, right) {
        final categoryCompare = _categoryPriority(
          left.art,
        ).compareTo(_categoryPriority(right.art));
        if (categoryCompare != 0) {
          return categoryCompare;
        }

        final stageCompare = _stagePriority(
          left.stufe,
        ).compareTo(_stagePriority(right.stufe));
        if (stageCompare != 0) {
          return stageCompare;
        }

        return right.start.compareTo(left.start);
      });

    final best = sortiert.first;
    return MemberVisualRole(stufe: best.stufe, category: best.art);
  }

  static bool istMitgliederRolle(Role role) {
    final type = role.type?.trim().toLowerCase();
    return type != null && type.startsWith('group::mitglieder::');
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

  static int _categoryPriority(RoleCategory category) {
    return switch (category) {
      RoleCategory.leitung => 0,
      RoleCategory.mitglied => 1,
      RoleCategory.sonstiges => 2,
    };
  }

  static int _stagePriority(Stufe stufe) {
    return switch (stufe) {
      Stufe.rover => 0,
      Stufe.pfadfinder => 1,
      Stufe.jungpfadfinder => 2,
      Stufe.woelfling => 3,
      Stufe.biber => 4,
      Stufe.leitung => 5,
    };
  }
}

class MemberVisualRole {
  const MemberVisualRole({required this.stufe, required this.category});

  final Stufe stufe;
  final RoleCategory category;
}

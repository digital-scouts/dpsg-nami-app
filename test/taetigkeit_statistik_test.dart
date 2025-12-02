import 'package:flutter_test/flutter_test.dart';
import 'package:nami/domain/member/stufe.dart';
import 'package:nami/domain/member/taetigkeit.dart';
import 'package:nami/domain/member/taetigkeit_statistik.dart';

void main() {
  group('cleanForStatistiks', () {
    test('ignores future roles and returns empty when none past/active', () {
      final now = DateTime.now();
      final roles = [
        Taetigkeit(
          stufe: Stufe.rover,
          art: TaetigkeitsArt.mitglied,
          start: now.add(const Duration(days: 10)),
          ende: now.add(const Duration(days: 20)),
        ),
      ];
      final res = cleanForStatistiks(roles);
      expect(res, isEmpty);
    });

    test('includes past roles unchanged when no overlaps', () {
      final now = DateTime.now();
      final roles = [
        Taetigkeit(
          stufe: Stufe.woelfling,
          art: TaetigkeitsArt.mitglied,
          start: now.subtract(const Duration(days: 100)),
          ende: now.subtract(const Duration(days: 50)),
        ),
      ];
      final res = cleanForStatistiks(roles);
      expect(res.length, 1);
      expect(res.first.stufe, Stufe.woelfling);
      expect(res.first.art, TaetigkeitsArt.mitglied);
      expect(
        res.first.start,
        DateTime(
          roles.first.start.year,
          roles.first.start.month,
          roles.first.start.day,
        ),
      );
      expect(
        res.first.ende,
        DateTime(
          roles.first.ende!.year,
          roles.first.ende!.month,
          roles.first.ende!.day,
        ),
      );
    });

    test('active role is capped at now', () {
      final now = DateTime.now();
      final start = now.subtract(const Duration(days: 30));
      final roles = [
        Taetigkeit(
          stufe: Stufe.pfadfinder,
          art: TaetigkeitsArt.leitung,
          start: start,
          ende: null,
        ),
      ];
      final res = cleanForStatistiks(roles);
      expect(res.length, 1);
      expect(res.first.start, DateTime(start.year, start.month, start.day));
      final cappedEnd = DateTime(now.year, now.month, now.day);
      expect(res.first.ende, cappedEnd);
    });

    test('overlap chooses newer start and splits segments', () {
      final now = DateTime.now();
      final a1 = DateTime(now.year - 2, 1, 1); // 2023-01-01
      final a2 = DateTime(now.year - 1, 6, 1); // 2024-06-01
      final b1 = DateTime(now.year - 1, 12, 31); // 2024-12-31
      final b2 = DateTime(now.year, 6, 1); // 2025-06-01
      final roles = <Taetigkeit>[
        Taetigkeit(
          stufe: Stufe.pfadfinder,
          art: TaetigkeitsArt.mitglied,
          start: a1,
          ende: b1,
        ),
        Taetigkeit(
          stufe: Stufe.rover,
          art: TaetigkeitsArt.leitung,
          start: a2,
          ende: b2,
        ),
      ];
      final res = cleanForStatistiks(roles);
      // Erwartet: mindestens Pfadi-Segment am Anfang und Rover (Leitung) im Overlap/Rest.
      expect(res.isNotEmpty, isTrue);
      expect(res.length, 2);

      expect(res.first.start, DateTime(a1.year, a1.month, a1.day));
      expect(res.first.ende, DateTime(a2.year, a2.month, a2.day));
      expect(res.first.stufe, Stufe.pfadfinder);

      expect(res.last.start, DateTime(a2.year, a2.month, a2.day));
      expect(res.last.ende, DateTime(b2.year, b2.month, b2.day));
      expect(res.last.stufe, Stufe.rover);
    });

    test('overlap chooses leader over member and splits segments', () {
      final now = DateTime.now();
      final a1 = DateTime(now.year - 2, 1, 1); // 2023-01-01
      final a2 = DateTime(now.year - 1, 6, 1); // 2024-06-01
      final b1 = DateTime(now.year - 1, 12, 31); // 2024-12-31
      final b2 = DateTime(now.year, 6, 1); // 2025-06-01
      final roles = <Taetigkeit>[
        Taetigkeit(
          stufe: Stufe.pfadfinder,
          art: TaetigkeitsArt.leitung,
          start: a1,
          ende: b1,
        ),
        Taetigkeit(
          stufe: Stufe.rover,
          art: TaetigkeitsArt.mitglied,
          start: a2,
          ende: b2,
        ),
      ];
      final res = cleanForStatistiks(roles);
      expect(res.isNotEmpty, isTrue);
      expect(res.length, 2);

      expect(res.first.start, DateTime(a1.year, a1.month, a1.day));
      expect(res.first.ende, DateTime(b1.year, b1.month, b1.day));
      expect(res.first.stufe, Stufe.pfadfinder);
      expect(res.first.art, TaetigkeitsArt.leitung);

      expect(res.last.start, DateTime(b1.year, b1.month, b1.day));
      expect(res.last.ende, DateTime(b2.year, b2.month, b2.day));
      expect(res.last.stufe, Stufe.rover);
      expect(res.last.art, TaetigkeitsArt.mitglied);
    });

    test('overlap chooses member over sonstige and splits segments', () {
      final now = DateTime.now();
      final a1 = DateTime(now.year - 2, 1, 1); // 2023-01-01
      final a2 = DateTime(now.year - 1, 6, 1); // 2024-06-01
      final b1 = DateTime(now.year - 1, 12, 31); // 2024-12-31
      final b2 = DateTime(now.year, 6, 1); // 2025-06-01
      final roles = <Taetigkeit>[
        Taetigkeit(
          stufe: Stufe.pfadfinder,
          art: TaetigkeitsArt.mitglied,
          start: a1,
          ende: b1,
        ),
        Taetigkeit(
          stufe: Stufe.rover,
          art: TaetigkeitsArt.sonstiges,
          start: a2,
          ende: b2,
        ),
      ];
      final res = cleanForStatistiks(roles);
      expect(res.isNotEmpty, isTrue);
      expect(res.length, 2);

      expect(res.first.start, DateTime(a1.year, a1.month, a1.day));
      expect(res.first.ende, DateTime(b1.year, b1.month, b1.day));
      expect(res.first.stufe, Stufe.pfadfinder);
      expect(res.first.art, TaetigkeitsArt.mitglied);

      expect(res.last.start, DateTime(b1.year, b1.month, b1.day));
      expect(res.last.ende, DateTime(b2.year, b2.month, b2.day));
      expect(res.last.stufe, Stufe.rover);
      expect(res.last.art, TaetigkeitsArt.sonstiges);
    });

    test('merge segments of same role', () {
      // Zwei Segmente mit gleicher (Stufe, Art). Diese sollten gemerged werden.
      // Dazwischenliegende Segmente werden bei bedarf auf spätere start/ende angepasst.
      final now = DateTime.now();
      final s = Stufe.jungpfadfinder;
      final roles = [
        Taetigkeit(
          stufe: s,
          art: TaetigkeitsArt.mitglied,
          start: DateTime(now.year - 2, 1, 1),
          ende: DateTime(now.year - 2, 2, 1),
        ),
        Taetigkeit(
          stufe: s,
          art: TaetigkeitsArt.leitung,
          start: DateTime(now.year - 2, 2, 1),
          ende: DateTime(now.year - 2, 3, 1),
        ),
        Taetigkeit(
          stufe: s,
          art: TaetigkeitsArt.mitglied,
          start: DateTime(now.year - 2, 3, 1),
          ende: DateTime(now.year - 2, 4, 1),
        ),
      ];
      final res = cleanForStatistiks(roles);

      expect(res.length, 2);

      expect(res.first.start, DateTime(now.year - 2, 1, 1));
      expect(res.first.ende, DateTime(now.year - 2, 3, 1));

      expect(res.last.start, DateTime(now.year - 2, 3, 1));
      expect(res.last.ende, DateTime(now.year - 2, 4, 1));
    });

    test('priority Leitung over Mitglied for same start in overlap', () {
      final now = DateTime.now();
      final start = DateTime(now.year - 1, 1, 1);
      final end = DateTime(now.year - 1, 6, 1);
      final roles = [
        Taetigkeit(
          stufe: Stufe.pfadfinder,
          art: TaetigkeitsArt.mitglied,
          start: start,
          ende: end,
        ),
        Taetigkeit(
          stufe: Stufe.rover,
          art: TaetigkeitsArt.leitung,
          start: start,
          ende: end,
        ),
      ];
      final res = cleanForStatistiks(roles);
      expect(res.length, 1);
      expect(res.first.art, TaetigkeitsArt.leitung);
      expect(res.first.stufe, Stufe.rover);
    });
  });

  group('durationsByRoleDays', () {
    test('returns empty list for only future roles', () {
      final now = DateTime.now();
      final roles = [
        Taetigkeit(
          stufe: Stufe.biber,
          art: TaetigkeitsArt.mitglied,
          start: DateTime(now.year + 1, 1, 1),
          ende: DateTime(now.year + 1, 1, 10),
        ),
      ];
      final res = durationsByRoleDays(roles);
      expect(res.isEmpty, true);
    });

    test('aggregates member days for same stufe', () {
      final now = DateTime.now();
      final roles = [
        Taetigkeit(
          stufe: Stufe.woelfling,
          art: TaetigkeitsArt.mitglied,
          start: DateTime(now.year - 1, 1, 1),
          ende: DateTime(now.year - 1, 1, 11), // 10 Tage
        ),
        Taetigkeit(
          stufe: Stufe.woelfling,
          art: TaetigkeitsArt.mitglied,
          start: DateTime(now.year - 1, 2, 1),
          ende: DateTime(now.year - 1, 2, 6), // 5 Tage
        ),
      ];
      final res = durationsByRoleDays(roles);
      expect(res.length, 1);
      expect(res.first.stufe, Stufe.woelfling);
      expect(res.first.art, TaetigkeitsArt.mitglied);
      expect(res.first.days, 15);
    });

    test('leader days aggregated separately (art == leitung)', () {
      final now = DateTime.now();
      final roles = [
        Taetigkeit(
          stufe: Stufe.jungpfadfinder,
          art: TaetigkeitsArt.leitung,
          start: DateTime(now.year - 2, 3, 1),
          ende: DateTime(now.year - 2, 3, 11), // 10 Tage
        ),
      ];
      final res = durationsByRoleDays(roles);
      expect(res.length, 1);
      expect(res.first.stufe, Stufe.jungpfadfinder);
      expect(res.first.art, TaetigkeitsArt.leitung);
      expect(res.first.days, 10);
    });

    test('overlap resolution reflected in day counts', () {
      final now = DateTime.now();
      final s = Stufe.pfadfinder;
      final roles = [
        Taetigkeit(
          stufe: s,
          art: TaetigkeitsArt.mitglied,
          start: DateTime(now.year - 2, 1, 1),
          ende: DateTime(now.year - 2, 3, 1),
        ),
        Taetigkeit(
          stufe: s,
          art: TaetigkeitsArt.leitung,
          start: DateTime(now.year - 2, 2, 1),
          ende: DateTime(now.year - 2, 4, 1),
        ),
      ];
      final res = durationsByRoleDays(roles);
      expect(res.length, 2);
      final member = res.firstWhere((e) => e.art == TaetigkeitsArt.mitglied);
      final leader = res.firstWhere((e) => e.art == TaetigkeitsArt.leitung);
      expect(leader.days > member.days, true);
      expect(member.days > 0, true);
    });

    test('active role capped at now', () {
      final now = DateTime.now();
      final start = DateTime(now.year - 1, now.month, 1);
      final roles = [
        Taetigkeit(
          stufe: Stufe.rover,
          art: TaetigkeitsArt.mitglied,
          start: start,
          ende: null,
        ),
      ];
      final res = durationsByRoleDays(roles);
      expect(res.length, 1);
      final expectedDays = DateTime(
        now.year,
        now.month,
        now.day,
      ).difference(DateTime(now.year - 1, now.month, 1)).inDays;
      expect(res.first.days, expectedDays);
    });
  });

  group('membershipDuration', () {
    test('returns zero for empty or only future roles', () {
      final now = DateTime.now();
      final roles = [
        Taetigkeit(
          stufe: Stufe.biber,
          art: TaetigkeitsArt.mitglied,
          start: DateTime(now.year + 1, 1, 1),
          ende: DateTime(now.year + 1, 1, 10),
        ),
      ];
      expect(membershipDuration(const []).inDays, 0);
      expect(membershipDuration(roles).inDays, 0);
    });

    test('sums all cleaned segments regardless of art/stufe', () {
      final now = DateTime.now();
      final roles = [
        // 10 Tage Mitglied
        Taetigkeit(
          stufe: Stufe.woelfling,
          art: TaetigkeitsArt.mitglied,
          start: DateTime(now.year - 1, 1, 1),
          ende: DateTime(now.year - 1, 1, 11),
        ),
        // 5 Tage Leitung (nicht überlappend)
        Taetigkeit(
          stufe: Stufe.rover,
          art: TaetigkeitsArt.leitung,
          start: DateTime(now.year - 1, 2, 1),
          ende: DateTime(now.year - 1, 2, 6),
        ),
      ];
      expect(membershipDuration(roles).inDays, 15);
    });

    test('overlap reduces total to non-overlapping sum per rules', () {
      final now = DateTime.now();
      final roles = [
        // Mitglied: Jan 01 - Mar 01
        Taetigkeit(
          stufe: Stufe.pfadfinder,
          art: TaetigkeitsArt.mitglied,
          start: DateTime(now.year - 2, 1, 1),
          ende: DateTime(now.year - 2, 3, 1),
        ),
        // Leitung: Feb 01 - Apr 01 (überlappt; Leitung gewinnt ab Feb)
        Taetigkeit(
          stufe: Stufe.pfadfinder,
          art: TaetigkeitsArt.leitung,
          start: DateTime(now.year - 2, 2, 1),
          ende: DateTime(now.year - 2, 4, 1),
        ),
      ];
      final d = membershipDuration(roles).inDays;
      // Erwartung: ungefähr Jan (Mitglied) + Feb-März (Leitung) + April-Anteil
      expect(d > 0, true);
    });

    test('active role capped at now contributes correctly', () {
      final now = DateTime.now();
      final start = DateTime(now.year - 1, now.month, 1);
      final roles = [
        Taetigkeit(
          stufe: Stufe.rover,
          art: TaetigkeitsArt.mitglied,
          start: start,
          ende: null,
        ),
      ];
      final expectedDays = DateTime(
        now.year,
        now.month,
        now.day,
      ).difference(DateTime(now.year - 1, now.month, 1)).inDays;
      expect(membershipDuration(roles).inDays, expectedDays);
    });
  });
}

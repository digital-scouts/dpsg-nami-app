import 'package:flutter_test/flutter_test.dart';
import 'package:nami/domain/member/age_distribution.dart';
import 'package:nami/domain/member/stufe.dart';
import 'package:nami/domain/member/taetigkeit.dart';

void main() {
  group('computeAgeDistribution', () {
    test('returns empty for no members or no mitglied art', () {
      expect(computeAgeDistribution(const []).bars.isEmpty, true);
      final now = DateTime.now();
      final members = [
        MemberAgeInfo(
          stufe: Stufe.woelfling,
          birthDate: DateTime(now.year - 9, 1, 1),
          art: TaetigkeitsArt.leitung,
        ),
      ];
      final data = computeAgeDistribution(members);
      expect(data.bars.isEmpty, true);
    });

    test('stacks counts per age across stufen', () {
      final now = DateTime.now();
      final members = [
        MemberAgeInfo(
          stufe: Stufe.woelfling,
          birthDate: DateTime(now.year - 9, now.month, now.day - 1),
          art: TaetigkeitsArt.mitglied,
        ),
        MemberAgeInfo(
          stufe: Stufe.woelfling,
          birthDate: DateTime(now.year - 9, now.month, now.day - 2),
          art: TaetigkeitsArt.mitglied,
        ),
        MemberAgeInfo(
          stufe: Stufe.jungpfadfinder,
          birthDate: DateTime(now.year - 9, now.month, now.day - 3),
          art: TaetigkeitsArt.mitglied,
        ),
      ];
      final data = computeAgeDistribution(members);
      expect(data.minAge, data.maxAge);
      expect(data.bars.length, 1);
      final bar = data.bars.first;
      expect(bar.totalCount, 3);
      expect(bar.entries.length, 2);
      final woelfCount = bar.entries
          .firstWhere((e) => e.stufe == Stufe.woelfling)
          .count;
      final jufiCount = bar.entries
          .firstWhere((e) => e.stufe == Stufe.jungpfadfinder)
          .count;
      expect(woelfCount, 2);
      expect(jufiCount, 1);
      expect(data.maxCount, 3);
    });

    test('fills gap ages with empty bars', () {
      final now = DateTime.now();
      final members = [
        MemberAgeInfo(
          stufe: Stufe.woelfling,
          birthDate: DateTime(now.year - 9, 1, 1),
          art: TaetigkeitsArt.mitglied,
        ),
        MemberAgeInfo(
          stufe: Stufe.jungpfadfinder,
          birthDate: DateTime(now.year - 11, 1, 1),
          art: TaetigkeitsArt.mitglied,
        ),
      ];
      final data = computeAgeDistribution(
        members,
        referenceDate: DateTime(now.year, 2, 1),
      );
      expect(data.minAge < data.maxAge, true);
      final expectedSpan = data.maxAge - data.minAge + 1;
      expect(data.bars.length, expectedSpan);
      final agesWithMembers = {
        for (final b in data.bars.where((b) => b.entries.isNotEmpty)) b.age,
      };
      expect(agesWithMembers.contains(data.minAge), true);
      expect(agesWithMembers.contains(data.maxAge), true);
    });

    test('age calculation handles upcoming birthday correctly', () {
      final ref = DateTime(2025, 6, 1);
      final members = [
        MemberAgeInfo(
          stufe: Stufe.woelfling,
          birthDate: DateTime(2015, 7, 10),
          art: TaetigkeitsArt.mitglied,
        ), // birthday next month
        MemberAgeInfo(
          stufe: Stufe.woelfling,
          birthDate: DateTime(2015, 5, 20),
          art: TaetigkeitsArt.mitglied,
        ), // birthday passed
      ];
      final data = computeAgeDistribution(members, referenceDate: ref);
      // First member age should be 9 (not yet 10), second already 10
      final ages = data.bars
          .where((b) => b.entries.isNotEmpty)
          .map((b) => b.age)
          .toSet();
      expect(ages.contains(9), true);
      expect(ages.contains(10), true);
    });
  });
}

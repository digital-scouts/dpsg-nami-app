import 'package:flutter_test/flutter_test.dart';
import 'package:nami/domain/statistiks/age_distribution.dart';
import 'package:nami/domain/taetigkeit/roles.dart';
import 'package:nami/domain/taetigkeit/stufe.dart';

void main() {
  group('computeAgeDistribution', () {
    test('returns empty for no members or no mitglied art', () {
      expect(computeAgeDistribution(const []).bars.isEmpty, true);
      final now = DateTime.now();
      final members = [
        MemberAgeInfo(
          stufe: Stufe.woelfling,
          birthDate: DateTime(now.year - 9, 1, 1),
          art: RoleCategory.leitung,
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
          art: RoleCategory.mitglied,
        ),
        MemberAgeInfo(
          stufe: Stufe.woelfling,
          birthDate: DateTime(now.year - 9, now.month, now.day - 2),
          art: RoleCategory.mitglied,
        ),
        MemberAgeInfo(
          stufe: Stufe.jungpfadfinder,
          birthDate: DateTime(now.year - 9, now.month, now.day - 3),
          art: RoleCategory.mitglied,
        ),
      ];
      final data = computeAgeDistribution(members);
      expect(data.minAge, 6);
      expect(data.maxAge, 14);
      expect(data.bars.length, 9);
      final bar = data.bars.firstWhere((b) => b.age == 9);
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
          art: RoleCategory.mitglied,
        ),
        MemberAgeInfo(
          stufe: Stufe.jungpfadfinder,
          birthDate: DateTime(now.year - 11, 1, 1),
          art: RoleCategory.mitglied,
        ),
      ];
      final data = computeAgeDistribution(
        members,
        referenceDate: DateTime(now.year, 2, 1),
      );
      expect(data.minAge, 6);
      expect(data.maxAge, 14);
      final expectedSpan = data.maxAge - data.minAge + 1;
      expect(data.bars.length, expectedSpan);
      final agesWithMembers = {
        for (final b in data.bars.where((b) => b.entries.isNotEmpty)) b.age,
      };
      expect(agesWithMembers.contains(9), true);
      expect(agesWithMembers.contains(11), true);
    });

    test('age calculation handles upcoming birthday correctly', () {
      final ref = DateTime(2025, 6, 1);
      final members = [
        MemberAgeInfo(
          stufe: Stufe.woelfling,
          birthDate: DateTime(2015, 7, 10),
          art: RoleCategory.mitglied,
        ), // birthday next month
        MemberAgeInfo(
          stufe: Stufe.woelfling,
          birthDate: DateTime(2015, 5, 20),
          art: RoleCategory.mitglied,
        ), // birthday passed
      ];
      final data = computeAgeDistribution(members, referenceDate: ref);
      // First member age should be 9 (not yet 10), second already 10
      final ages = data.bars
          .where((b) => b.entries.isNotEmpty)
          .map((b) => b.age)
          .toSet();
      expect(data.minAge, 6);
      expect(data.maxAge, 11);
      expect(ages.contains(9), true);
      expect(ages.contains(10), true);
    });

    test('ignores Leitung entries for age distribution', () {
      final ref = DateTime(2025, 6, 1);
      final members = [
        MemberAgeInfo(
          stufe: Stufe.leitung,
          birthDate: DateTime(1990, 1, 1),
          art: RoleCategory.mitglied,
        ),
      ];

      final data = computeAgeDistribution(members, referenceDate: ref);
      expect(data.bars.isEmpty, true);
    });

    test('extends max age when oldest child is above stage max', () {
      final ref = DateTime(2025, 6, 1);
      final members = [
        MemberAgeInfo(
          stufe: Stufe.rover,
          birthDate: DateTime(2002, 1, 1),
          art: RoleCategory.mitglied,
        ),
      ];

      final data = computeAgeDistribution(members, referenceDate: ref);
      expect(data.minAge, 15);
      expect(data.maxAge, 23);
      expect(data.bars.firstWhere((bar) => bar.age == 23).totalCount, 1);
    });

    test('does not extend max when only outliers above +2 exist', () {
      final ref = DateTime(2025, 6, 1);
      final members = [
        MemberAgeInfo(
          stufe: Stufe.woelfling,
          birthDate: DateTime(2017, 1, 1),
          art: RoleCategory.mitglied,
        ), // age 8
        MemberAgeInfo(
          stufe: Stufe.woelfling,
          birthDate: DateTime(2012, 1, 1),
          art: RoleCategory.mitglied,
        ), // age 13 -> 3 above base max 10
      ];

      final data = computeAgeDistribution(
        members,
        referenceDate: ref,
        bounds: const AgeDistributionBounds(baseMinAge: 6, baseMaxAge: 10),
      );

      expect(data.minAge, 6);
      expect(data.maxAge, 10);
      expect(data.bars.where((bar) => bar.age == 13), isEmpty);
    });

    test('extends max up to +2 when members are in that range', () {
      final ref = DateTime(2025, 6, 1);
      final members = [
        MemberAgeInfo(
          stufe: Stufe.woelfling,
          birthDate: DateTime(2017, 1, 1),
          art: RoleCategory.mitglied,
        ), // age 8
        MemberAgeInfo(
          stufe: Stufe.woelfling,
          birthDate: DateTime(2014, 1, 1),
          art: RoleCategory.mitglied,
        ), // age 11 -> base max +1
        MemberAgeInfo(
          stufe: Stufe.woelfling,
          birthDate: DateTime(2013, 1, 1),
          art: RoleCategory.mitglied,
        ), // age 12 -> base max +2
      ];

      final data = computeAgeDistribution(
        members,
        referenceDate: ref,
        bounds: const AgeDistributionBounds(baseMinAge: 6, baseMaxAge: 10),
      );

      expect(data.maxAge, 12);
      expect(data.bars.firstWhere((bar) => bar.age == 12).totalCount, 1);
    });

    test('extends two years below lower bound but not more', () {
      final ref = DateTime(2025, 6, 1);
      final members = [
        MemberAgeInfo(
          stufe: Stufe.woelfling,
          birthDate: DateTime(2016, 1, 1),
          art: RoleCategory.mitglied,
        ), // age 9
        MemberAgeInfo(
          stufe: Stufe.woelfling,
          birthDate: DateTime(2020, 1, 1),
          art: RoleCategory.mitglied,
        ), // age 5
        MemberAgeInfo(
          stufe: Stufe.woelfling,
          birthDate: DateTime(2022, 1, 1),
          art: RoleCategory.mitglied,
        ), // age 3 -> more than two below base min 6
      ];

      final data = computeAgeDistribution(
        members,
        referenceDate: ref,
        bounds: const AgeDistributionBounds(baseMinAge: 6, baseMaxAge: 10),
      );

      expect(data.minAge, 4);
      expect(data.bars.where((bar) => bar.age == 3), isEmpty);
      expect(data.bars.firstWhere((bar) => bar.age == 5).totalCount, 1);
    });
  });
}

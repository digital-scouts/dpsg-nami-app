import '../taetigkeit/roles.dart';
import '../taetigkeit/stufe.dart';

class MemberAgeInfo {
  MemberAgeInfo({
    required this.stufe,
    required this.birthDate,
    required this.art,
  });
  final Stufe stufe;
  final DateTime birthDate;
  final RoleCategory art;
}

class AgeDistributionEntry {
  AgeDistributionEntry({required this.stufe, required this.count});
  final Stufe stufe;
  final int count;
}

class AgeDistributionBar {
  AgeDistributionBar({required this.age, required this.entries})
    : totalCount = entries.fold(0, (s, e) => s + e.count);
  final int age;
  final List<AgeDistributionEntry> entries;
  final int totalCount;
}

class AgeDistributionData {
  const AgeDistributionData({
    required this.minAge,
    required this.maxAge,
    required this.maxCount,
    required this.bars,
  });
  final int minAge;
  final int maxAge;
  final int maxCount;
  final List<AgeDistributionBar> bars;
  static const empty = AgeDistributionData(
    minAge: 0,
    maxAge: 0,
    maxCount: 0,
    bars: [],
  );
}

class AgeDistributionBounds {
  const AgeDistributionBounds({
    required this.baseMinAge,
    required this.baseMaxAge,
    this.maxYearsBelow = 2,
    this.maxYearsAbove = 2,
  });

  final int baseMinAge;
  final int baseMaxAge;
  final int maxYearsBelow;
  final int maxYearsAbove;
}

AgeDistributionData computeAgeDistribution(
  List<MemberAgeInfo> members, {
  DateTime? referenceDate,
  AgeDistributionBounds? bounds,
}) {
  if (members.isEmpty) return AgeDistributionData.empty;
  final now = referenceDate ?? DateTime.now();
  final filtered = members
      .where((m) => m.art == RoleCategory.mitglied && m.stufe != Stufe.leitung)
      .toList();
  if (filtered.isEmpty) return AgeDistributionData.empty;

  int calcAge(DateTime birth) {
    int age = now.year - birth.year;
    final hasHadBirthday =
        (now.month > birth.month) ||
        (now.month == birth.month && now.day >= birth.day);
    if (!hasHadBirthday) age -= 1;
    return age;
  }

  final ages = <int>[];
  final stagedCounts = <int, Map<Stufe, int>>{};
  for (final m in filtered) {
    final age = calcAge(m.birthDate);
    if (age < 0) continue;
    ages.add(age);
    final stufeMap = stagedCounts.putIfAbsent(age, () => {});
    stufeMap.update(m.stufe, (v) => v + 1, ifAbsent: () => 1);
  }
  if (stagedCounts.isEmpty || ages.isEmpty) return AgeDistributionData.empty;

  final youngestAge = ages.reduce((a, b) => a < b ? a : b);
  final oldestAge = ages.reduce((a, b) => a > b ? a : b);

  late final int minAge;
  late final int maxAge;
  if (bounds != null) {
    final lowerFloor = bounds.baseMinAge - bounds.maxYearsBelow;
    final upperCeil = bounds.baseMaxAge + bounds.maxYearsAbove;
    final nearbyAgesAboveBase = ages
        .where((age) => age > bounds.baseMaxAge && age <= upperCeil)
        .toList(growable: false);

    minAge = youngestAge < bounds.baseMinAge
        ? (youngestAge < lowerFloor ? lowerFloor : youngestAge)
        : bounds.baseMinAge;
    if (nearbyAgesAboveBase.isNotEmpty) {
      final nearestVisibleMax = nearbyAgesAboveBase.reduce(
        (a, b) => a > b ? a : b,
      );
      maxAge = nearestVisibleMax;
    } else {
      maxAge = bounds.baseMaxAge;
    }
  } else {
    final stufenMinAge = filtered
        .map((entry) => entry.stufe.defaultMinAge.toInt())
        .reduce((a, b) => a < b ? a : b);
    final stufenMaxAge = filtered
        .map((entry) => entry.stufe.defaultMaxAge.toInt())
        .reduce((a, b) => a > b ? a : b);

    minAge = youngestAge < stufenMinAge ? youngestAge : stufenMinAge;
    maxAge = oldestAge > stufenMaxAge ? oldestAge : stufenMaxAge;
  }

  final bars = <AgeDistributionBar>[];
  int maxCount = 0;
  for (int age = minAge; age <= maxAge; age++) {
    final stufeMap = stagedCounts[age];
    if (stufeMap == null) {
      bars.add(AgeDistributionBar(age: age, entries: const []));
      continue;
    }
    final entries = [
      for (final e in stufeMap.entries)
        AgeDistributionEntry(stufe: e.key, count: e.value),
    ]..sort((a, b) => a.stufe.index.compareTo(b.stufe.index));
    final bar = AgeDistributionBar(age: age, entries: entries);
    maxCount = bar.totalCount > maxCount ? bar.totalCount : maxCount;
    bars.add(bar);
  }
  return AgeDistributionData(
    minAge: minAge,
    maxAge: maxAge,
    maxCount: maxCount,
    bars: bars,
  );
}

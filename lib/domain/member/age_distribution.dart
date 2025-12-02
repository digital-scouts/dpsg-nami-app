import 'stufe.dart';
import 'taetigkeit.dart';

class MemberAgeInfo {
  MemberAgeInfo({
    required this.stufe,
    required this.birthDate,
    required this.art,
  });
  final Stufe stufe;
  final DateTime birthDate;
  final TaetigkeitsArt art;
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

AgeDistributionData computeAgeDistribution(
  List<MemberAgeInfo> members, {
  DateTime? referenceDate,
}) {
  if (members.isEmpty) return AgeDistributionData.empty;
  final now = referenceDate ?? DateTime.now();
  final filtered = members
      .where((m) => m.art == TaetigkeitsArt.mitglied)
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

  final Map<int, Map<Stufe, int>> byAge = {};
  for (final m in filtered) {
    final age = calcAge(m.birthDate);
    if (age < 0) continue;
    final stufeMap = byAge.putIfAbsent(age, () => {});
    stufeMap.update(m.stufe, (v) => v + 1, ifAbsent: () => 1);
  }
  if (byAge.isEmpty) return AgeDistributionData.empty;

  final ages = byAge.keys.toList()..sort();
  final minAge = ages.first;
  final maxAge = ages.last;

  final bars = <AgeDistributionBar>[];
  int maxCount = 0;
  for (int age = minAge; age <= maxAge; age++) {
    final stufeMap = byAge[age];
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

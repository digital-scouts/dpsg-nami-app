import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:nami/domain/statistiks/age_distribution.dart';
import 'package:nami/domain/statistiks/group_distribution.dart';
import 'package:nami/domain/taetigkeit/stufe.dart';

class StatisticsDummyData {
  const StatisticsDummyData._();

  static const String stammTitle = 'Stamm St. Georg - Uebersicht';

  static const StammSummary summary = StammSummary(
    mitglieder: 18,
    sonstige: 16,
    leitende: 2,
  );

  static const List<StammGroupItem> groups = <StammGroupItem>[
    StammGroupItem(
      id: 'woe',
      name: 'Rudel Silberpfeil',
      stageLabel: 'Woelflinge',
      stageShort: 'Woe',
      icon: Icons.child_care,
      memberCount: 4,
      stageColor: Color(0xFFFF6400),
      stageBackground: Color(0xFFFFF0E6),
    ),
    StammGroupItem(
      id: 'jup',
      name: 'Sippe Adler',
      stageLabel: 'Jungpfadfinder',
      stageShort: 'JuPf',
      icon: Icons.hiking,
      memberCount: 5,
      stageColor: Color(0xFF2F53A7),
      stageBackground: Color(0xFFE8EDF7),
    ),
    StammGroupItem(
      id: 'pf',
      name: 'Sippe Edelweiss',
      stageLabel: 'Pfadfinder',
      stageShort: 'Pf',
      icon: Icons.forest,
      memberCount: 5,
      stageColor: Color(0xFF00823C),
      stageBackground: Color(0xFFE0F2EA),
    ),
    StammGroupItem(
      id: 'rov',
      name: 'Runde',
      stageLabel: 'Rover',
      stageShort: 'Rov',
      icon: Icons.explore,
      memberCount: 2,
      stageColor: Color(0xFFCC1F2F),
      stageBackground: Color(0xFFFCEAEB),
    ),
  ];

  static const List<LegendDatum> gruppenverteilung = <LegendDatum>[
    LegendDatum(label: 'Woelflinge', value: 5, color: Color(0xFFFF6400)),
    LegendDatum(label: 'Jungpfadfinder', value: 6, color: Color(0xFF2F53A7)),
    LegendDatum(label: 'Pfadfinder', value: 6, color: Color(0xFF00823C)),
    LegendDatum(label: 'Rover', value: 3, color: Color(0xFFCC1F2F)),
  ];

  static const List<LegendDatum> altersverteilung = <LegendDatum>[
    LegendDatum(label: '7-10 Jahre', value: 4, color: Color(0xFFFF6400)),
    LegendDatum(label: '11-14 Jahre', value: 5, color: Color(0xFF2F53A7)),
    LegendDatum(label: '15-17 Jahre', value: 5, color: Color(0xFF00823C)),
    LegendDatum(label: '18-21 Jahre', value: 4, color: Color(0xFFCC1F2F)),
  ];

  static const List<LegendDatum> geschlecht = <LegendDatum>[
    LegendDatum(label: 'Maennlich', value: 10, color: Color(0xFF2F53A7)),
    LegendDatum(label: 'Weiblich', value: 8, color: Color(0xFFE6007E)),
  ];

  static const List<LegendDatum> konfession = <LegendDatum>[
    LegendDatum(label: 'Katholisch', value: 12, color: Color(0xFF003056)),
    LegendDatum(label: 'Evangelisch', value: 3, color: Color(0xFF5A9AD8)),
    LegendDatum(label: 'Ohne Angabe', value: 3, color: Color(0xFF8E8E93)),
  ];

  static const List<LatLng> stammLocations = <LatLng>[
    LatLng(51.2003, 6.6893),
    LatLng(51.1985, 6.6912),
    LatLng(51.2021, 6.6874),
    LatLng(51.1978, 6.6855),
    LatLng(51.2014, 6.6934),
  ];

  static const GroupDetails defaultGroup = GroupDetails(
    id: 'woe',
    name: 'Rudel Silberpfeil',
    stageLabel: 'Woelflinge',
    stageShort: 'Woe',
    stufe: Stufe.woelfling,
    stageColor: Color(0xFFFF6400),
    stageBackground: Color(0xFFFFF0E6),
    members: 4,
    leitende: 1,
    ages: <LegendDatum>[
      LegendDatum(label: '7 Jahre', value: 1, color: Color(0xFFFF6400)),
      LegendDatum(label: '8 Jahre', value: 1, color: Color(0xFFFF6400)),
      LegendDatum(label: '9 Jahre', value: 1, color: Color(0xFFFF6400)),
      LegendDatum(label: '10 Jahre', value: 1, color: Color(0xFFFF6400)),
    ],
    gender: <LegendDatum>[
      LegendDatum(label: 'Maennlich', value: 2, color: Color(0xFF2F53A7)),
      LegendDatum(label: 'Weiblich', value: 2, color: Color(0xFFE6007E)),
    ],
    locations: <LatLng>[
      LatLng(51.2003, 6.6893),
      LatLng(51.1985, 6.6912),
      LatLng(51.2021, 6.6874),
      LatLng(51.1978, 6.6855),
    ],
    membersList: <VisualMemberItem>[
      VisualMemberItem(name: 'Emma Mueller', subtitle: '8 Jahre'),
      VisualMemberItem(name: 'Leon Schaefer', subtitle: '9 Jahre'),
      VisualMemberItem(name: 'Lena Weber', subtitle: '10 Jahre'),
      VisualMemberItem(name: 'Noah Fischer', subtitle: '7 Jahre'),
    ],
  );

  static const GroupDetails jup = GroupDetails(
    id: 'jup',
    name: 'Sippe Adler',
    stageLabel: 'Jungpfadfinder',
    stageShort: 'JuPf',
    stufe: Stufe.jungpfadfinder,
    stageColor: Color(0xFF2F53A7),
    stageBackground: Color(0xFFE8EDF7),
    members: 5,
    leitende: 1,
    ages: <LegendDatum>[
      LegendDatum(label: '11 Jahre', value: 1, color: Color(0xFF2F53A7)),
      LegendDatum(label: '12 Jahre', value: 2, color: Color(0xFF2F53A7)),
      LegendDatum(label: '13 Jahre', value: 1, color: Color(0xFF2F53A7)),
      LegendDatum(label: '14 Jahre', value: 1, color: Color(0xFF2F53A7)),
    ],
    gender: <LegendDatum>[
      LegendDatum(label: 'Maennlich', value: 3, color: Color(0xFF2F53A7)),
      LegendDatum(label: 'Weiblich', value: 2, color: Color(0xFFE6007E)),
    ],
    locations: <LatLng>[
      LatLng(51.2045, 6.6930),
      LatLng(51.2012, 6.6948),
      LatLng(51.1994, 6.6868),
      LatLng(51.2033, 6.6840),
      LatLng(51.2060, 6.6905),
    ],
    membersList: <VisualMemberItem>[
      VisualMemberItem(name: 'Felix Braun', subtitle: '12 Jahre'),
      VisualMemberItem(name: 'Sophie Wagner', subtitle: '13 Jahre'),
      VisualMemberItem(name: 'Lukas Hoffmann', subtitle: '11 Jahre'),
      VisualMemberItem(name: 'Marie Schmidt', subtitle: '12 Jahre'),
      VisualMemberItem(name: 'Jan Koch', subtitle: '14 Jahre'),
    ],
  );

  static const GroupDetails pf = GroupDetails(
    id: 'pf',
    name: 'Sippe Edelweiss',
    stageLabel: 'Pfadfinder',
    stageShort: 'Pf',
    stufe: Stufe.pfadfinder,
    stageColor: Color(0xFF00823C),
    stageBackground: Color(0xFFE0F2EA),
    members: 5,
    leitende: 1,
    ages: <LegendDatum>[
      LegendDatum(label: '15 Jahre', value: 1, color: Color(0xFF00823C)),
      LegendDatum(label: '16 Jahre', value: 2, color: Color(0xFF00823C)),
      LegendDatum(label: '17 Jahre', value: 2, color: Color(0xFF00823C)),
    ],
    gender: <LegendDatum>[
      LegendDatum(label: 'Maennlich', value: 2, color: Color(0xFF2F53A7)),
      LegendDatum(label: 'Weiblich', value: 3, color: Color(0xFFE6007E)),
    ],
    locations: <LatLng>[
      LatLng(51.2008, 6.6960),
      LatLng(51.1972, 6.6922),
      LatLng(51.2038, 6.6833),
      LatLng(51.2055, 6.6878),
      LatLng(51.1965, 6.6900),
    ],
    membersList: <VisualMemberItem>[
      VisualMemberItem(name: 'Clara Braun', subtitle: '16 Jahre'),
      VisualMemberItem(name: 'Max Neumann', subtitle: '17 Jahre'),
      VisualMemberItem(name: 'Anna Becker', subtitle: '15 Jahre'),
      VisualMemberItem(name: 'Tim Koch', subtitle: '17 Jahre'),
      VisualMemberItem(name: 'Hanna Richter', subtitle: '16 Jahre'),
    ],
  );

  static const GroupDetails rov = GroupDetails(
    id: 'rov',
    name: 'Runde',
    stageLabel: 'Rover',
    stageShort: 'Rov',
    stufe: Stufe.rover,
    stageColor: Color(0xFFCC1F2F),
    stageBackground: Color(0xFFFCEAEB),
    members: 2,
    leitende: 1,
    ages: <LegendDatum>[
      LegendDatum(label: '20 Jahre', value: 1, color: Color(0xFFCC1F2F)),
      LegendDatum(label: '21 Jahre', value: 1, color: Color(0xFFCC1F2F)),
    ],
    gender: <LegendDatum>[
      LegendDatum(label: 'Maennlich', value: 1, color: Color(0xFF2F53A7)),
      LegendDatum(label: 'Weiblich', value: 1, color: Color(0xFFE6007E)),
    ],
    locations: <LatLng>[LatLng(51.1968, 6.6888), LatLng(51.2027, 6.6917)],
    membersList: <VisualMemberItem>[
      VisualMemberItem(name: 'Jonas Weber', subtitle: '20 Jahre'),
      VisualMemberItem(name: 'Sarah Neumann', subtitle: '21 Jahre'),
    ],
  );

  static GroupDetails groupById(String id) {
    switch (id) {
      case 'jup':
        return jup;
      case 'pf':
        return pf;
      case 'rov':
        return rov;
      case 'woe':
      default:
        return defaultGroup;
    }
  }

  static List<GroupDetails> get allGroupDetails => <GroupDetails>[
    defaultGroup,
    jup,
    pf,
    rov,
  ];

  static List<GroupDistribution> stammGroupDistributionData() {
    return allGroupDetails
        .map(
          (group) => GroupDistribution(
            stufe: group.stufe,
            leitungCount: group.leitende,
            mitgliedCount: group.members,
          ),
        )
        .toList(growable: false);
  }

  static AgeDistributionData stammAgeDistributionData() {
    final Map<int, Map<Stufe, int>> byAge = <int, Map<Stufe, int>>{};
    for (final group in allGroupDetails) {
      for (final ageSlice in group.ages) {
        final age = _parseAge(ageSlice.label);
        if (age == null) {
          continue;
        }
        final stageMap = byAge.putIfAbsent(age, () => <Stufe, int>{});
        stageMap.update(
          group.stufe,
          (value) => value + ageSlice.value,
          ifAbsent: () => ageSlice.value,
        );
      }
    }
    return _toAgeDistribution(byAge);
  }

  static AgeDistributionData ageDistributionForGroup(GroupDetails group) {
    final Map<int, Map<Stufe, int>> byAge = <int, Map<Stufe, int>>{};
    for (final ageSlice in group.ages) {
      final age = _parseAge(ageSlice.label);
      if (age == null) {
        continue;
      }
      byAge[age] = <Stufe, int>{group.stufe: ageSlice.value};
    }
    return _toAgeDistribution(byAge);
  }

  static AgeDistributionData _toAgeDistribution(
    Map<int, Map<Stufe, int>> byAge,
  ) {
    if (byAge.isEmpty) {
      return AgeDistributionData.empty;
    }
    final ages = byAge.keys.toList()..sort();
    final bars = <AgeDistributionBar>[];
    var maxCount = 0;

    for (final age in ages) {
      final stageMap = byAge[age] ?? <Stufe, int>{};
      final entries =
          stageMap.entries
              .map(
                (entry) =>
                    AgeDistributionEntry(stufe: entry.key, count: entry.value),
              )
              .toList()
            ..sort((a, b) => a.stufe.order.compareTo(b.stufe.order));
      final bar = AgeDistributionBar(age: age, entries: entries);
      if (bar.totalCount > maxCount) {
        maxCount = bar.totalCount;
      }
      bars.add(bar);
    }

    return AgeDistributionData(
      minAge: ages.first,
      maxAge: ages.last,
      maxCount: maxCount,
      bars: bars,
    );
  }

  static int? _parseAge(String label) {
    final match = RegExp(r'\d+').firstMatch(label);
    if (match == null) {
      return null;
    }
    return int.tryParse(match.group(0)!);
  }
}

class StammSummary {
  const StammSummary({
    required this.mitglieder,
    required this.sonstige,
    required this.leitende,
  });

  final int mitglieder;
  final int sonstige;
  final int leitende;
}

class StammGroupItem {
  const StammGroupItem({
    required this.id,
    required this.name,
    required this.stageLabel,
    required this.stageShort,
    required this.icon,
    required this.memberCount,
    required this.stageColor,
    required this.stageBackground,
  });

  final String id;
  final String name;
  final String stageLabel;
  final String stageShort;
  final IconData icon;
  final int memberCount;
  final Color stageColor;
  final Color stageBackground;
}

class LegendDatum {
  const LegendDatum({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;
}

class VisualMemberItem {
  const VisualMemberItem({required this.name, required this.subtitle});

  final String name;
  final String subtitle;
}

class GroupDetails {
  const GroupDetails({
    required this.id,
    required this.name,
    required this.stageLabel,
    required this.stageShort,
    required this.stufe,
    required this.stageColor,
    required this.stageBackground,
    required this.members,
    required this.leitende,
    required this.ages,
    required this.gender,
    required this.locations,
    required this.membersList,
  });

  final String id;
  final String name;
  final String stageLabel;
  final String stageShort;
  final Stufe stufe;
  final Color stageColor;
  final Color stageBackground;
  final int members;
  final int leitende;
  final List<LegendDatum> ages;
  final List<LegendDatum> gender;
  final List<LatLng> locations;
  final List<VisualMemberItem> membersList;
}

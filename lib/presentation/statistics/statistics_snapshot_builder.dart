import 'package:flutter/material.dart';

import '../../domain/arbeitskontext/arbeitskontext_read_model.dart';
import '../../domain/member/mitglied.dart';
import '../../domain/statistiks/age_distribution.dart';
import '../../domain/statistiks/group_distribution.dart';
import '../../domain/stufe/altersgrenzen.dart';
import '../../domain/stufe/arbeitskontext_stufen_mapping.dart';
import '../../domain/stufe/usecases/ermittle_stufen_im_arbeitskontext_usecase.dart';
import '../../domain/taetigkeit/klassifiziere_mitglied_usecase.dart';
import '../../domain/taetigkeit/roles.dart';
import '../../domain/taetigkeit/stufe.dart';
import '../stufe/stufe_visuals.dart';

class StatisticsLegendItem {
  const StatisticsLegendItem({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;
}

class StatisticsGroupItem {
  const StatisticsGroupItem({
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

class StatisticsGroupDetailSnapshot {
  const StatisticsGroupDetailSnapshot({
    required this.id,
    required this.name,
    required this.stageLabel,
    required this.stageShort,
    required this.members,
    required this.leaders,
    required this.ageDistribution,
    required this.gender,
    required this.confessions,
    required this.memberIds,
  });

  final String id;
  final String name;
  final String stageLabel;
  final String stageShort;
  final int members;
  final int leaders;
  final AgeDistributionData ageDistribution;
  final List<StatisticsLegendItem> gender;
  final List<StatisticsLegendItem> confessions;
  final List<String> memberIds;
}

class StatisticsSnapshot {
  const StatisticsSnapshot({
    required this.stammTitle,
    required this.members,
    required this.sonstige,
    required this.leaders,
    required this.groups,
    required this.groupDistributions,
    required this.ageDistribution,
    required this.gender,
    required this.confessions,
    required this.groupDetails,
    required this.memberById,
    required this.memberClassification,
  });

  final String stammTitle;
  final int members;
  final int sonstige;
  final int leaders;
  final List<StatisticsGroupItem> groups;
  final List<GroupDistribution> groupDistributions;
  final AgeDistributionData ageDistribution;
  final List<StatisticsLegendItem> gender;
  final List<StatisticsLegendItem> confessions;
  final Map<String, StatisticsGroupDetailSnapshot> groupDetails;
  final Map<String, Mitglied> memberById;
  final Map<String, RoleCategory> memberClassification;

  StatisticsGroupDetailSnapshot? detailById(String id) => groupDetails[id];
}

class StatisticsSnapshotBuilder {
  const StatisticsSnapshotBuilder({
    ErmittleStufenImArbeitskontextUseCase ermittleStufenUseCase =
        const ErmittleStufenImArbeitskontextUseCase(),
    KlassifiziereMitgliedUseCase klassifiziereMitgliedUseCase =
        const KlassifiziereMitgliedUseCase(),
  }) : _ermittleStufenUseCase = ermittleStufenUseCase,
       _klassifiziereMitgliedUseCase = klassifiziereMitgliedUseCase;

  final ErmittleStufenImArbeitskontextUseCase _ermittleStufenUseCase;
  final KlassifiziereMitgliedUseCase _klassifiziereMitgliedUseCase;

  StatisticsSnapshot build(
    ArbeitskontextReadModel readModel, {
    Altersgrenzen? altersgrenzen,
  }) {
    final grenzen = altersgrenzen ?? StufenDefaults.build();
    final stufenByMember = _ermittleStufenUseCase(readModel);
    final memberById = <String, Mitglied>{
      for (final member in readModel.mitglieder) member.mitgliedsnummer: member,
    };
    final gruppenById = <int, ArbeitskontextGruppe>{
      for (final gruppe in readModel.gruppen) gruppe.id: gruppe,
    };
    final stammMemberIds = _collectMemberRoleIds(
      readModel.mitgliedsZuordnungen,
      memberById,
      gruppenById,
    );

    final assignmentByGroup = <int, List<ArbeitskontextMitgliedsZuordnung>>{};
    for (final assignment in readModel.mitgliedsZuordnungen) {
      assignmentByGroup
          .putIfAbsent(
            assignment.gruppenId,
            () => <ArbeitskontextMitgliedsZuordnung>[],
          )
          .add(assignment);
    }

    final groupItems = <StatisticsGroupItem>[];
    final detailById = <String, StatisticsGroupDetailSnapshot>{};
    final distributionByStage = <Stufe, _MemberLeaderCount>{};

    for (final group in readModel.gruppen) {
      final assignments =
          assignmentByGroup[group.id] ??
          const <ArbeitskontextMitgliedsZuordnung>[];
      if (assignments.isEmpty) {
        continue;
      }

      final stage = _resolveStage(group.gruppenTyp);
      if (stage == null) {
        continue;
      }

      final roleFlagsByMember = <String, _RoleFlags>{};
      for (final assignment in assignments) {
        final flags = roleFlagsByMember.putIfAbsent(
          assignment.mitgliedsnummer,
          () => const _RoleFlags.none(),
        );
        final isLeader = _klassifiziereMitgliedUseCase
            .istLeitungsrolleInStammGruppe(assignment, gruppenById);
        final isMember = _klassifiziereMitgliedUseCase
            .istMitgliedsrolleInStammGruppe(assignment, gruppenById);
        roleFlagsByMember[assignment.mitgliedsnummer] = flags.copyWith(
          hasLeaderRole: flags.hasLeaderRole || isLeader,
          hasMemberRole: flags.hasMemberRole || isMember,
        );
      }

      final memberCount = roleFlagsByMember.values
          .where((flags) => flags.hasMemberRole)
          .length;
      final leaderCount = roleFlagsByMember.values
          .where((flags) => flags.hasLeaderRole)
          .length;
      if (memberCount == 0 && leaderCount == 0) {
        continue;
      }

      distributionByStage.update(
        stage,
        (value) => value.copyWith(
          members: value.members + memberCount,
          leaders: value.leaders + leaderCount,
        ),
        ifAbsent: () =>
            _MemberLeaderCount(members: memberCount, leaders: leaderCount),
      );

      final groupMemberIds = roleFlagsByMember.keys
          .where(memberById.containsKey)
          .toList(growable: false);
      final groupMemberRoleIds = roleFlagsByMember.entries
          .where((entry) => entry.value.hasMemberRole)
          .map((entry) => entry.key)
          .where(memberById.containsKey)
          .toList(growable: false);

      groupItems.add(
        StatisticsGroupItem(
          id: group.id.toString(),
          name: group.anzeigename,
          stageLabel: stage.displayName,
          stageShort: stage.shortDisplayName,
          icon: _iconFor(stage),
          memberCount: memberCount,
          stageColor: StufeVisuals.colorFor(stage),
          stageBackground: _backgroundColorFor(stage),
        ),
      );

      detailById[group.id.toString()] = StatisticsGroupDetailSnapshot(
        id: group.id.toString(),
        name: group.anzeigename,
        stageLabel: stage.displayName,
        stageShort: stage.shortDisplayName,
        members: memberCount,
        leaders: leaderCount,
        ageDistribution: _buildAgeDistributionForGroup(
          memberIds: groupMemberRoleIds,
          memberById: memberById,
          stufe: stage,
          grenzen: grenzen,
        ),
        gender: _buildGenderLegend(groupMemberRoleIds, memberById),
        confessions: _buildMockConfessionLegend(groupMemberRoleIds),
        memberIds: groupMemberIds,
      );
    }

    groupItems.sort((a, b) => a.name.compareTo(b.name));

    var members = 0;
    var leaders = 0;
    var sonstige = 0;
    final memberClassification = <String, RoleCategory>{};

    for (final member in readModel.mitglieder) {
      final classification = _klassifiziereMitgliedUseCase.klassifiziere(
        member.mitgliedsnummer,
        readModel,
      );
      memberClassification[member.mitgliedsnummer] = classification;

      switch (classification) {
        case RoleCategory.mitglied:
          members++;
        case RoleCategory.leitung:
          leaders++;
        case RoleCategory.sonstiges:
          sonstige++;
      }
    }

    final groupDistributions =
        distributionByStage.entries
            .map(
              (entry) => GroupDistribution(
                stufe: entry.key,
                leitungCount: entry.value.leaders,
                mitgliedCount: entry.value.members,
              ),
            )
            .toList(growable: false)
          ..sort((a, b) => a.stufe.order.compareTo(b.stufe.order));

    final ageEntries = <MemberAgeInfo>[];
    for (final memberId in stammMemberIds) {
      final member = memberById[memberId];
      if (member == null || _isPlaceholderDate(member.geburtsdatum)) {
        continue;
      }
      final stages = stufenByMember[memberId] ?? const <Stufe>{};
      for (final stage in stages) {
        if (stage == Stufe.leitung) {
          continue;
        }
        ageEntries.add(
          MemberAgeInfo(
            stufe: stage,
            birthDate: member.geburtsdatum,
            art: RoleCategory.mitglied,
          ),
        );
      }
    }

    return StatisticsSnapshot(
      stammTitle: '${readModel.arbeitskontext.aktiverLayer.name} - Übersicht',
      members: members,
      sonstige: sonstige,
      leaders: leaders,
      groups: groupItems,
      groupDistributions: groupDistributions,
      ageDistribution: computeAgeDistribution(
        ageEntries,
        bounds: _buildStammBounds(ageEntries, grenzen),
      ),
      gender: _buildGenderLegend(
        stammMemberIds.toList(growable: false),
        memberById,
      ),
      confessions: _buildMockConfessionLegend(
        stammMemberIds.toList(growable: false),
      ),
      groupDetails: detailById,
      memberById: memberById,
      memberClassification: memberClassification,
    );
  }

  List<StatisticsLegendItem> _buildMockConfessionLegend(
    List<String> memberIds,
  ) {
    final total = memberIds.toSet().length;
    if (total <= 0) {
      return const <StatisticsLegendItem>[];
    }

    final katholisch = (total * 0.62).round();
    final evangelisch = (total * 0.18).round();
    final konfessionslos = (total * 0.14).round();
    final sonstige = (total - katholisch - evangelisch - konfessionslos)
        .clamp(0, total)
        .toInt();

    final items = <StatisticsLegendItem>[];
    if (katholisch > 0) {
      items.add(
        StatisticsLegendItem(
          label: 'Katholisch',
          value: katholisch,
          color: Color(0xFF1B5E20),
        ),
      );
    }
    if (evangelisch > 0) {
      items.add(
        StatisticsLegendItem(
          label: 'Evangelisch',
          value: evangelisch,
          color: Color(0xFF0277BD),
        ),
      );
    }
    if (konfessionslos > 0) {
      items.add(
        StatisticsLegendItem(
          label: 'Konfessionslos',
          value: konfessionslos,
          color: Color(0xFF616161),
        ),
      );
    }
    if (sonstige > 0) {
      items.add(
        StatisticsLegendItem(
          label: 'Andere',
          value: sonstige,
          color: Color(0xFF6A1B9A),
        ),
      );
    }
    return items;
  }

  List<StatisticsLegendItem> _buildGenderLegend(
    List<String> memberIds,
    Map<String, Mitglied> memberById,
  ) {
    var male = 0;
    var female = 0;
    var diverse = 0;
    var unknown = 0;

    final seen = <String>{};
    for (final memberId in memberIds) {
      if (!seen.add(memberId)) {
        continue;
      }
      final member = memberById[memberId];
      if (member == null) {
        continue;
      }
      final gender = (member.gender ?? '').trim().toLowerCase();
      if (gender == 'm' || gender == 'male' || gender == 'maennlich') {
        male++;
      } else if (gender == 'w' || gender == 'female' || gender == 'weiblich') {
        female++;
      } else if (gender == 'd' || gender == 'divers') {
        diverse++;
      } else {
        unknown++;
      }
    }

    final items = <StatisticsLegendItem>[];
    if (male > 0) {
      items.add(
        StatisticsLegendItem(
          label: 'Männlich',
          value: male,
          color: Color(0xFF2F53A7),
        ),
      );
    }
    if (female > 0) {
      items.add(
        StatisticsLegendItem(
          label: 'Weiblich',
          value: female,
          color: Color(0xFFE6007E),
        ),
      );
    }
    if (diverse > 0) {
      items.add(
        StatisticsLegendItem(
          label: 'Divers',
          value: diverse,
          color: Color(0xFF00796B),
        ),
      );
    }
    if (unknown > 0 || items.isEmpty) {
      items.add(
        StatisticsLegendItem(
          label: 'Ohne Angabe',
          value: unknown,
          color: Color(0xFF8E8E93),
        ),
      );
    }
    return items;
  }

  AgeDistributionData _buildAgeDistributionForGroup({
    required List<String> memberIds,
    required Map<String, Mitglied> memberById,
    required Stufe stufe,
    required Altersgrenzen grenzen,
  }) {
    final entries = <MemberAgeInfo>[];
    final seen = <String>{};
    for (final memberId in memberIds) {
      if (!seen.add(memberId)) {
        continue;
      }
      final member = memberById[memberId];
      if (member == null || _isPlaceholderDate(member.geburtsdatum)) {
        continue;
      }
      entries.add(
        MemberAgeInfo(
          stufe: stufe,
          birthDate: member.geburtsdatum,
          art: RoleCategory.mitglied,
        ),
      );
    }
    final interval = grenzen.forStufe(stufe);
    return computeAgeDistribution(
      entries,
      bounds: AgeDistributionBounds(
        baseMinAge: interval.minJahre,
        baseMaxAge: interval.maxJahre,
      ),
    );
  }

  Set<String> _collectMemberRoleIds(
    Iterable<ArbeitskontextMitgliedsZuordnung> assignments,
    Map<String, Mitglied> memberById,
    Map<int, ArbeitskontextGruppe> gruppenById,
  ) {
    final memberIds = <String>{};
    for (final assignment in assignments) {
      if (_klassifiziereMitgliedUseCase.istMitgliedsrolleInStammGruppe(
        assignment,
        gruppenById,
      )) {
        if (memberById.containsKey(assignment.mitgliedsnummer)) {
          memberIds.add(assignment.mitgliedsnummer);
        }
      }
    }
    return memberIds;
  }

  AgeDistributionBounds _buildStammBounds(
    List<MemberAgeInfo> entries,
    Altersgrenzen grenzen,
  ) {
    final hasBiber = entries.any((entry) => entry.stufe == Stufe.biber);
    final woelflingMin = grenzen.forStufe(Stufe.woelfling).minJahre;
    final biberMin = grenzen.forStufe(Stufe.biber).minJahre;
    final roverMax = grenzen.forStufe(Stufe.rover).maxJahre;
    return AgeDistributionBounds(
      baseMinAge: hasBiber ? biberMin : woelflingMin,
      baseMaxAge: roverMax,
    );
  }

  Stufe? _resolveStage(String? gruppenTyp) {
    for (final rule in ArbeitskontextStufenMapping.regeln) {
      if (rule.passtZu(gruppenTyp: gruppenTyp)) {
        return rule.stufe;
      }
    }
    return null;
  }

  bool _isPlaceholderDate(DateTime date) {
    return date == Mitglied.peoplePlaceholderDate;
  }

  IconData _iconFor(Stufe stage) {
    return switch (stage) {
      Stufe.biber => Icons.pets,
      Stufe.woelfling => Icons.child_care,
      Stufe.jungpfadfinder => Icons.hiking,
      Stufe.pfadfinder => Icons.forest,
      Stufe.rover => Icons.explore,
      Stufe.leitung => Icons.groups,
    };
  }

  Color _backgroundColorFor(Stufe stage) {
    return StufeVisuals.colorFor(stage).withValues(alpha: 0.14);
  }
}

class _RoleFlags {
  const _RoleFlags({required this.hasMemberRole, required this.hasLeaderRole});

  const _RoleFlags.none() : this(hasMemberRole: false, hasLeaderRole: false);

  final bool hasMemberRole;
  final bool hasLeaderRole;

  _RoleFlags copyWith({bool? hasMemberRole, bool? hasLeaderRole}) {
    return _RoleFlags(
      hasMemberRole: hasMemberRole ?? this.hasMemberRole,
      hasLeaderRole: hasLeaderRole ?? this.hasLeaderRole,
    );
  }
}

class _MemberLeaderCount {
  const _MemberLeaderCount({required this.members, required this.leaders});

  final int members;
  final int leaders;

  _MemberLeaderCount copyWith({int? members, int? leaders}) {
    return _MemberLeaderCount(
      members: members ?? this.members,
      leaders: leaders ?? this.leaders,
    );
  }
}

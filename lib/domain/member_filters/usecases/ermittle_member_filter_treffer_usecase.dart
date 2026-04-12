import '../../arbeitskontext/arbeitskontext_read_model.dart';
import '../../stufe/usecases/ermittle_stufen_im_arbeitskontext_usecase.dart';
import '../../taetigkeit/stufe.dart';
import '../member_custom_filter.dart';

class ErmittleMemberFilterTrefferUseCase {
  const ErmittleMemberFilterTrefferUseCase();

  static const ErmittleStufenImArbeitskontextUseCase _stufenUseCase =
      ErmittleStufenImArbeitskontextUseCase();

  Map<String, Set<String>> call(
    ArbeitskontextReadModel readModel, {
    Iterable<MemberCustomFilterGroup> customGroups =
        const <MemberCustomFilterGroup>[],
  }) {
    final treffer = <String, Set<String>>{};
    final stufenTreffer = _stufenUseCase(readModel);
    final zuordnungenByMember =
        <String, List<ArbeitskontextMitgliedsZuordnung>>{};

    for (final zuordnung in readModel.mitgliedsZuordnungen) {
      zuordnungenByMember
          .putIfAbsent(
            zuordnung.mitgliedsnummer,
            () => <ArbeitskontextMitgliedsZuordnung>[],
          )
          .add(zuordnung);
    }

    for (final member in readModel.mitglieder) {
      final memberKeys = treffer.putIfAbsent(
        member.mitgliedsnummer,
        () => <String>{},
      );
      final memberStufen =
          stufenTreffer[member.mitgliedsnummer] ?? const <Stufe>{};
      for (final stufe in memberStufen) {
        memberKeys.add(stufe.name);
      }

      final memberZuordnungen =
          zuordnungenByMember[member.mitgliedsnummer] ??
          const <ArbeitskontextMitgliedsZuordnung>[];
      for (final group in customGroups) {
        if (_matchesGroup(group, memberZuordnungen, memberStufen.isEmpty)) {
          memberKeys.add(group.filterKey);
        }
      }
    }

    return treffer;
  }

  bool _matchesGroup(
    MemberCustomFilterGroup group,
    List<ArbeitskontextMitgliedsZuordnung> zuordnungen,
    bool hasNoStage,
  ) {
    if (group.rules.isEmpty) {
      return false;
    }

    final results = group.rules
        .map((rule) => _matchesRule(rule, zuordnungen, hasNoStage))
        .toList(growable: false);

    switch (group.logic) {
      case MemberCustomFilterLogic.und:
        return results.every((value) => value);
      case MemberCustomFilterLogic.oder:
        return results.any((value) => value);
    }
  }

  bool _matchesRule(
    MemberCustomFilterRule rule,
    List<ArbeitskontextMitgliedsZuordnung> zuordnungen,
    bool hasNoStage,
  ) {
    final criterionMatches = switch (rule.criterion.type) {
      MemberCustomFilterCriterionType.stufe => !hasNoStage,
      MemberCustomFilterCriterionType.groupRole => zuordnungen.any(
        (zuordnung) =>
            zuordnung.gruppenId == rule.criterion.groupId &&
            ((rule.criterion.roleType == null &&
                    rule.criterion.roleLabel == null) ||
                (zuordnung.rollenTyp == rule.criterion.roleType &&
                    zuordnung.rollenLabel == rule.criterion.roleLabel)),
      ),
    };

    switch (rule.operator) {
      case MemberCustomFilterRuleOperator.hat:
        return criterionMatches;
      case MemberCustomFilterRuleOperator.hatNicht:
        return !criterionMatches;
    }
  }
}

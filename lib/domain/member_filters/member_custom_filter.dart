enum MemberCustomFilterLogic { und, oder }

enum MemberCustomFilterRuleOperator { hat, hatNicht }

enum MemberCustomFilterCriterionType { groupRole, stufe }

class MemberCustomFilterCriterion {
  const MemberCustomFilterCriterion.groupRole({
    required this.groupId,
    required this.groupName,
    this.groupType,
    this.roleType,
    this.roleLabel,
  }) : type = MemberCustomFilterCriterionType.groupRole;

  const MemberCustomFilterCriterion.stufe()
    : type = MemberCustomFilterCriterionType.stufe,
      groupId = null,
      groupName = null,
      groupType = null,
      roleType = null,
      roleLabel = null;

  final MemberCustomFilterCriterionType type;
  final int? groupId;
  final String? groupName;
  final String? groupType;
  final String? roleType;
  final String? roleLabel;

  String get stableKey {
    switch (type) {
      case MemberCustomFilterCriterionType.stufe:
        return 'stufe';
      case MemberCustomFilterCriterionType.groupRole:
        return [
          'group_role',
          '${groupId ?? ''}',
          roleType ?? '',
          roleLabel ?? '',
        ].join('|');
    }
  }

  MemberCustomFilterCriterion copyWith({
    int? groupId,
    String? groupName,
    String? groupType,
    String? roleType,
    String? roleLabel,
  }) {
    switch (type) {
      case MemberCustomFilterCriterionType.stufe:
        return const MemberCustomFilterCriterion.stufe();
      case MemberCustomFilterCriterionType.groupRole:
        return MemberCustomFilterCriterion.groupRole(
          groupId: groupId ?? this.groupId!,
          groupName: groupName ?? this.groupName!,
          groupType: groupType ?? this.groupType,
          roleType: roleType ?? this.roleType,
          roleLabel: roleLabel ?? this.roleLabel,
        );
    }
  }

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'groupId': groupId,
    'groupName': groupName,
    'groupType': groupType,
    'roleType': roleType,
    'roleLabel': roleLabel,
  };

  factory MemberCustomFilterCriterion.fromJson(Map<String, dynamic> json) {
    final typeName = json['type'] as String?;
    final type = switch (typeName) {
      'stufe' => MemberCustomFilterCriterionType.stufe,
      'keineStufe' => MemberCustomFilterCriterionType.stufe,
      _ => MemberCustomFilterCriterionType.values.firstWhere(
        (value) => value.name == typeName,
        orElse: () => MemberCustomFilterCriterionType.groupRole,
      ),
    };
    switch (type) {
      case MemberCustomFilterCriterionType.stufe:
        return const MemberCustomFilterCriterion.stufe();
      case MemberCustomFilterCriterionType.groupRole:
        final groupId = json['groupId'];
        final groupName = json['groupName'] as String?;
        return MemberCustomFilterCriterion.groupRole(
          groupId: groupId is int ? groupId : int.parse('$groupId'),
          groupName: groupName ?? '',
          groupType: json['groupType'] as String?,
          roleType: json['roleType'] as String?,
          roleLabel: json['roleLabel'] as String?,
        );
    }
  }

  @override
  bool operator ==(Object other) {
    return other is MemberCustomFilterCriterion &&
        other.type == type &&
        other.groupId == groupId &&
        other.groupName == groupName &&
        other.groupType == groupType &&
        other.roleType == roleType &&
        other.roleLabel == roleLabel;
  }

  @override
  int get hashCode =>
      Object.hash(type, groupId, groupName, groupType, roleType, roleLabel);
}

class MemberCustomFilterRule {
  const MemberCustomFilterRule({
    required this.operator,
    required this.criterion,
  });

  final MemberCustomFilterRuleOperator operator;
  final MemberCustomFilterCriterion criterion;

  MemberCustomFilterRule copyWith({
    MemberCustomFilterRuleOperator? operator,
    MemberCustomFilterCriterion? criterion,
  }) => MemberCustomFilterRule(
    operator: operator ?? this.operator,
    criterion: criterion ?? this.criterion,
  );

  Map<String, dynamic> toJson() => {
    'operator': operator.name,
    'criterion': criterion.toJson(),
  };

  factory MemberCustomFilterRule.fromJson(Map<String, dynamic> json) {
    final operatorName = json['operator'] as String?;
    final operator = MemberCustomFilterRuleOperator.values.firstWhere(
      (value) => value.name == operatorName,
      orElse: () => MemberCustomFilterRuleOperator.hat,
    );
    final criterionJson = json['criterion'];
    final criterion = criterionJson is Map<String, dynamic>
        ? MemberCustomFilterCriterion.fromJson(criterionJson)
        : const MemberCustomFilterCriterion.stufe();
    final rawTypeName = criterionJson is Map<String, dynamic>
        ? criterionJson['type'] as String?
        : null;

    if (rawTypeName == 'keineStufe') {
      return MemberCustomFilterRule(
        operator: MemberCustomFilterRuleOperator.hatNicht,
        criterion: const MemberCustomFilterCriterion.stufe(),
      );
    }

    return MemberCustomFilterRule(operator: operator, criterion: criterion);
  }

  @override
  bool operator ==(Object other) {
    return other is MemberCustomFilterRule &&
        other.operator == operator &&
        other.criterion == criterion;
  }

  @override
  int get hashCode => Object.hash(operator, criterion);
}

class MemberCustomFilterGroup {
  const MemberCustomFilterGroup({
    required this.id,
    required this.shortLabel,
    required this.isActive,
    required this.logic,
    required this.rules,
    this.iconKey,
    this.isDefault = false,
  }) : assert(id != ''),
       assert(shortLabel != '');

  final String id;
  final String shortLabel;
  final bool isActive;
  final MemberCustomFilterLogic logic;
  final List<MemberCustomFilterRule> rules;
  final String? iconKey;
  final bool isDefault;

  String get filterKey => 'custom:$id';

  String get displayChipLabel => shortLabel.trim();

  MemberCustomFilterGroup copyWith({
    String? id,
    String? shortLabel,
    bool? isActive,
    MemberCustomFilterLogic? logic,
    List<MemberCustomFilterRule>? rules,
    String? iconKey,
    bool? isDefault,
    bool iconKeyLoeschen = false,
  }) => MemberCustomFilterGroup(
    id: id ?? this.id,
    shortLabel: shortLabel ?? this.shortLabel,
    isActive: isActive ?? this.isActive,
    logic: logic ?? this.logic,
    rules: rules ?? this.rules,
    iconKey: iconKeyLoeschen ? null : iconKey ?? this.iconKey,
    isDefault: isDefault ?? this.isDefault,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'shortLabel': shortLabel,
    'isActive': isActive,
    'logic': logic.name,
    'rules': rules.map((rule) => rule.toJson()).toList(growable: false),
    'iconKey': iconKey,
    'isDefault': isDefault,
  };

  factory MemberCustomFilterGroup.fromJson(Map<String, dynamic> json) {
    final logicName = json['logic'] as String?;
    final logic = MemberCustomFilterLogic.values.firstWhere(
      (value) => value.name == logicName,
      orElse: () => MemberCustomFilterLogic.oder,
    );
    final rawRules = json['rules'];
    final shortLabel =
        (json['shortLabel'] as String?) ?? (json['name'] as String?) ?? '';
    return MemberCustomFilterGroup(
      id: json['id'] as String? ?? '',
      shortLabel: shortLabel,
      isActive: json['isActive'] as bool? ?? true,
      logic: logic,
      rules: rawRules is List
          ? rawRules
                .whereType<Map<String, dynamic>>()
                .map(MemberCustomFilterRule.fromJson)
                .toList(growable: false)
          : const <MemberCustomFilterRule>[],
      iconKey: json['iconKey'] as String?,
      isDefault: json['isDefault'] as bool? ?? false,
    );
  }

  static const MemberCustomFilterGroup defaultRest = MemberCustomFilterGroup(
    id: 'rest',
    shortLabel: 'Rest',
    isActive: true,
    isDefault: true,
    logic: MemberCustomFilterLogic.oder,
    rules: <MemberCustomFilterRule>[
      MemberCustomFilterRule(
        operator: MemberCustomFilterRuleOperator.hatNicht,
        criterion: MemberCustomFilterCriterion.stufe(),
      ),
    ],
  );

  @override
  bool operator ==(Object other) {
    return other is MemberCustomFilterGroup &&
        other.id == id &&
        other.shortLabel == shortLabel &&
        other.isActive == isActive &&
        other.logic == logic &&
        _listEquals(other.rules, rules) &&
        other.iconKey == iconKey &&
        other.isDefault == isDefault;
  }

  @override
  int get hashCode => Object.hash(
    id,
    shortLabel,
    isActive,
    logic,
    Object.hashAll(rules),
    iconKey,
    isDefault,
  );

  static bool _listEquals<T>(List<T> a, List<T> b) {
    if (identical(a, b)) {
      return true;
    }
    if (a.length != b.length) {
      return false;
    }
    for (var index = 0; index < a.length; index += 1) {
      if (a[index] != b[index]) {
        return false;
      }
    }
    return true;
  }
}

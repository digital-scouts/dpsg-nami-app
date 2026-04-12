import 'package:flutter/material.dart';

import '../../domain/arbeitskontext/arbeitskontext_read_model.dart';
import '../../domain/member/member_list_preferences.dart';
import '../../domain/member_filters/member_custom_filter.dart';
import '../../l10n/app_localizations.dart';
import '../model/member_filters_model.dart';
import 'member_custom_filter_icons.dart';

Future<void> showMemberFilterSortSheet(
  BuildContext context, {
  required MemberFiltersModel model,
  required ArbeitskontextReadModel readModel,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) =>
        _MemberFilterSortSheet(model: model, readModel: readModel),
  );
}

class _MemberFilterSortSheet extends StatelessWidget {
  const _MemberFilterSortSheet({required this.model, required this.readModel});

  final MemberFiltersModel model;
  final ArbeitskontextReadModel readModel;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);

    return SafeArea(
      child: AnimatedBuilder(
        animation: model,
        builder: (context, _) {
          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    t.t('member_filter_sheet_title'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<MemberSortKey>(
                    initialValue: model.sortKey,
                    decoration: InputDecoration(
                      labelText: t.t('member_filter_sort_label'),
                      border: const OutlineInputBorder(),
                    ),
                    items: MemberSortKey.values
                        .map(
                          (value) => DropdownMenuItem<MemberSortKey>(
                            value: value,
                            child: Text(_sortLabel(t, value)),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      model.setSortKey(value);
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<MemberSubtitleMode>(
                    initialValue: model.subtitleMode,
                    decoration: InputDecoration(
                      labelText: t.t('member_filter_subtitle_label'),
                      border: const OutlineInputBorder(),
                    ),
                    items: MemberSubtitleMode.values
                        .map(
                          (value) => DropdownMenuItem<MemberSubtitleMode>(
                            value: value,
                            child: Text(_subtitleLabel(t, value)),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      model.setSubtitleMode(value);
                    },
                  ),
                  const SizedBox(height: 20),
                  Text(
                    t.t('member_filter_custom_groups_title'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  if (model.customGroups.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(t.t('member_filter_custom_groups_empty')),
                    ),
                  ...model.customGroups.map(
                    (group) => Card(
                      child: ListTile(
                        leading: Switch(
                          value: group.isActive,
                          onChanged: (value) {
                            model.setCustomGroupActive(group.id, value);
                          },
                        ),
                        title: Text(group.displayChipLabel),
                        subtitle: Text(
                          _groupSubtitle(t, group),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit),
                              tooltip: t.t('member_filter_edit'),
                              onPressed: () async {
                                final edited =
                                    await showModalBottomSheet<
                                      MemberCustomFilterGroup
                                    >(
                                      context: context,
                                      isScrollControlled: true,
                                      builder: (editorContext) =>
                                          _CustomGroupEditorSheet(
                                            readModel: readModel,
                                            initialGroup: group,
                                          ),
                                    );
                                if (edited != null) {
                                  await model.saveCustomGroup(edited);
                                }
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              tooltip: t.t('member_filter_delete'),
                              onPressed: () async {
                                await model.deleteCustomGroup(group.id);
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () async {
                        final result =
                            await showModalBottomSheet<MemberCustomFilterGroup>(
                              context: context,
                              isScrollControlled: true,
                              builder: (editorContext) =>
                                  _CustomGroupEditorSheet(readModel: readModel),
                            );
                        if (result != null) {
                          await model.saveCustomGroup(result);
                        }
                      },
                      icon: const Icon(Icons.add),
                      label: Text(t.t('member_filter_create')),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _sortLabel(AppLocalizations t, MemberSortKey value) {
    switch (value) {
      case MemberSortKey.age:
        return t.t('member_filter_sort_age');
      case MemberSortKey.group:
        return t.t('member_filter_sort_group');
      case MemberSortKey.name:
        return t.t('member_filter_sort_name');
      case MemberSortKey.vorname:
        return t.t('member_filter_sort_vorname');
      case MemberSortKey.memberTime:
        return t.t('member_filter_sort_member_time');
    }
  }

  String _subtitleLabel(AppLocalizations t, MemberSubtitleMode value) {
    switch (value) {
      case MemberSubtitleMode.mitgliedsnummer:
        return t.t('member_filter_subtitle_member_id');
      case MemberSubtitleMode.geburtstag:
        return t.t('member_filter_subtitle_birthday');
      case MemberSubtitleMode.spitzname:
        return t.t('member_filter_subtitle_nickname');
      case MemberSubtitleMode.eintrittsdatum:
        return t.t('member_filter_subtitle_joined');
    }
  }

  String _groupSubtitle(AppLocalizations t, MemberCustomFilterGroup group) {
    final logicLabel = group.logic == MemberCustomFilterLogic.und
        ? t.t('member_filter_logic_and')
        : t.t('member_filter_logic_or');
    return '${group.rules.length} ${t.t('member_filter_rules_count')} · $logicLabel';
  }
}

class _CustomGroupEditorSheet extends StatefulWidget {
  const _CustomGroupEditorSheet({required this.readModel, this.initialGroup});

  final ArbeitskontextReadModel readModel;
  final MemberCustomFilterGroup? initialGroup;

  @override
  State<_CustomGroupEditorSheet> createState() =>
      _CustomGroupEditorSheetState();
}

class _CustomGroupEditorSheetState extends State<_CustomGroupEditorSheet> {
  late final TextEditingController _shortLabelController;
  late MemberCustomFilterLogic _logic;
  late String? _iconKey;
  late List<MemberCustomFilterRule> _rules;

  @override
  void initState() {
    super.initState();
    final group = widget.initialGroup;
    _shortLabelController = TextEditingController(
      text: group?.shortLabel ?? '',
    );
    _logic = group?.logic ?? MemberCustomFilterLogic.oder;
    _iconKey = group?.iconKey;
    _rules = List<MemberCustomFilterRule>.from(
      group?.rules ??
          const <MemberCustomFilterRule>[
            MemberCustomFilterRule(
              operator: MemberCustomFilterRuleOperator.hat,
              criterion: MemberCustomFilterCriterion.stufe(),
            ),
          ],
    );
  }

  @override
  void dispose() {
    _shortLabelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final selectorData = _buildSelectorData(t, widget.readModel);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.initialGroup == null
                    ? t.t('member_filter_create')
                    : t.t('member_filter_edit'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 1,
                    child: DropdownButtonFormField<String?>(
                      initialValue: _iconKey,
                      decoration: InputDecoration(
                        labelText: t.t('member_filter_icon_label'),
                        border: const OutlineInputBorder(),
                      ),
                      items: <DropdownMenuItem<String?>>[
                        DropdownMenuItem<String?>(
                          value: null,
                          child: Text(t.t('member_filter_icon_none')),
                        ),
                        ...memberCustomFilterIconOptions.map(
                          (option) => DropdownMenuItem<String?>(
                            value: option.key,
                            child: Row(
                              children: [
                                Icon(option.icon),
                                const SizedBox(width: 8),
                                Text(t.t(option.labelKey)),
                              ],
                            ),
                          ),
                        ),
                      ],
                      onChanged: (value) => setState(() => _iconKey = value),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 1,
                    child: TextField(
                      controller: _shortLabelController,
                      maxLength: 8,
                      decoration: InputDecoration(
                        labelText: t.t('member_filter_name_label'),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<MemberCustomFilterLogic>(
                initialValue: _logic,
                decoration: InputDecoration(
                  labelText: t.t('member_filter_logic_label'),
                  border: const OutlineInputBorder(),
                ),
                items: MemberCustomFilterLogic.values
                    .map(
                      (value) => DropdownMenuItem<MemberCustomFilterLogic>(
                        value: value,
                        child: Text(
                          value == MemberCustomFilterLogic.und
                              ? t.t('member_filter_logic_and')
                              : t.t('member_filter_logic_or'),
                        ),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() => _logic = value);
                },
              ),
              const SizedBox(height: 16),
              Text(
                t.t('member_filter_rules_title'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              ..._rules.asMap().entries.map((entry) {
                final index = entry.key;
                final rule = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DropdownButtonFormField<MemberCustomFilterRuleOperator>(
                        initialValue: rule.operator,
                        decoration: InputDecoration(
                          labelText: t.t('member_filter_rule_operator_label'),
                          border: const OutlineInputBorder(),
                        ),
                        items: MemberCustomFilterRuleOperator.values
                            .map(
                              (value) =>
                                  DropdownMenuItem<
                                    MemberCustomFilterRuleOperator
                                  >(
                                    value: value,
                                    child: Text(
                                      value ==
                                              MemberCustomFilterRuleOperator.hat
                                          ? t.t('member_filter_operator_has')
                                          : t.t(
                                              'member_filter_operator_has_not',
                                            ),
                                    ),
                                  ),
                            )
                            .toList(growable: false),
                        onChanged: (value) {
                          if (value == null) {
                            return;
                          }
                          setState(() {
                            _rules[index] = _rules[index].copyWith(
                              operator: value,
                            );
                          });
                        },
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedGroupKey(
                          rule.criterion,
                          selectorData,
                        ),
                        decoration: InputDecoration(
                          labelText: t.t('member_filter_rule_group_label'),
                          border: const OutlineInputBorder(),
                        ),
                        items: selectorData.groups
                            .map(
                              (option) => DropdownMenuItem<String>(
                                value: option.key,
                                child: Text(option.label),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (value) {
                          if (value == null) {
                            return;
                          }
                          final groupOption = selectorData.groups.firstWhere(
                            (option) => option.key == value,
                          );
                          setState(() {
                            _rules[index] = _rules[index].copyWith(
                              criterion: groupOption.defaultCriterion,
                            );
                          });
                        },
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedRoleKey(rule.criterion),
                        decoration: InputDecoration(
                          labelText: t.t('member_filter_rule_role_label'),
                          border: const OutlineInputBorder(),
                        ),
                        items:
                            _roleOptionsForRule(t, rule.criterion, selectorData)
                                .map(
                                  (option) => DropdownMenuItem<String>(
                                    value: option.key,
                                    child: Text(option.label),
                                  ),
                                )
                                .toList(growable: false),
                        onChanged:
                            rule.criterion.type ==
                                MemberCustomFilterCriterionType.stufe
                            ? null
                            : (value) {
                                if (value == null) {
                                  return;
                                }
                                final roleOption = _roleOptionsForRule(
                                  t,
                                  rule.criterion,
                                  selectorData,
                                ).firstWhere((option) => option.key == value);
                                setState(() {
                                  _rules[index] = _rules[index].copyWith(
                                    criterion: roleOption.criterion,
                                  );
                                });
                              },
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          tooltip: t.t('member_filter_rule_remove'),
                          onPressed: _rules.length <= 1
                              ? null
                              : () {
                                  setState(() {
                                    _rules.removeAt(index);
                                  });
                                },
                        ),
                      ),
                    ],
                  ),
                );
              }),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _rules.add(
                      const MemberCustomFilterRule(
                        operator: MemberCustomFilterRuleOperator.hat,
                        criterion: MemberCustomFilterCriterion.stufe(),
                      ),
                    );
                  });
                },
                icon: const Icon(Icons.add),
                label: Text(t.t('member_filter_rule_add')),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    final shortLabel = _shortLabelController.text.trim();
                    if (shortLabel.isEmpty || _rules.isEmpty) {
                      return;
                    }
                    Navigator.of(context).pop(
                      MemberCustomFilterGroup(
                        id:
                            widget.initialGroup?.id ??
                            DateTime.now().microsecondsSinceEpoch.toString(),
                        shortLabel: shortLabel,
                        isActive: widget.initialGroup?.isActive ?? true,
                        logic: _logic,
                        rules: List<MemberCustomFilterRule>.from(_rules),
                        iconKey: _iconKey,
                        isDefault: widget.initialGroup?.isDefault ?? false,
                      ),
                    );
                  },
                  child: Text(t.t('save')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  _SelectorData _buildSelectorData(
    AppLocalizations t,
    ArbeitskontextReadModel readModel,
  ) {
    final groupOptions = <_GroupOption>[
      _GroupOption(
        key: const MemberCustomFilterCriterion.stufe().stableKey,
        label: t.t('member_filter_criterion_stage'),
        defaultCriterion: const MemberCustomFilterCriterion.stufe(),
      ),
    ];
    final rolesByGroup = <String, List<_RoleOption>>{};
    final seenGroupKeys = <String>{groupOptions.first.key};
    final seenRoleKeysByGroup = <String, Set<String>>{};

    void ensureAllRolesOption(
      String groupKey,
      MemberCustomFilterCriterion criterion,
    ) {
      final options = rolesByGroup.putIfAbsent(groupKey, () => <_RoleOption>[]);
      final seen = seenRoleKeysByGroup.putIfAbsent(groupKey, () => <String>{});
      if (seen.add(_allRolesRoleKey)) {
        options.add(
          _RoleOption(
            key: _allRolesRoleKey,
            label: t.t('member_filter_all_roles'),
            criterion: criterion.copyWith(roleType: null, roleLabel: null),
          ),
        );
      }
    }

    for (final zuordnung in readModel.mitgliedsZuordnungen) {
      final gruppe = readModel.findeGruppe(zuordnung.gruppenId);
      if (gruppe == null) {
        continue;
      }
      final criterion = MemberCustomFilterCriterion.groupRole(
        groupId: gruppe.id,
        groupName: gruppe.anzeigename,
        groupType: gruppe.gruppenTyp,
        roleType: zuordnung.rollenTyp,
        roleLabel: zuordnung.rollenLabel,
      );
      final groupKey = _groupKeyForId(gruppe.id);
      if (seenGroupKeys.add(groupKey)) {
        groupOptions.add(
          _GroupOption(
            key: groupKey,
            label: gruppe.anzeigename,
            defaultCriterion: MemberCustomFilterCriterion.groupRole(
              groupId: gruppe.id,
              groupName: gruppe.anzeigename,
              groupType: gruppe.gruppenTyp,
            ),
          ),
        );
      }
      ensureAllRolesOption(
        groupKey,
        MemberCustomFilterCriterion.groupRole(
          groupId: gruppe.id,
          groupName: gruppe.anzeigename,
          groupType: gruppe.gruppenTyp,
        ),
      );
      final roleLabel =
          zuordnung.displayRollenLabel ?? t.t('member_filter_role_unknown');
      final roleKey = _roleKeyForCriterion(criterion);
      final seenRoleKeys = seenRoleKeysByGroup.putIfAbsent(
        groupKey,
        () => <String>{},
      );
      if (!seenRoleKeys.add(roleKey)) {
        continue;
      }
      rolesByGroup
          .putIfAbsent(groupKey, () => <_RoleOption>[])
          .add(
            _RoleOption(key: roleKey, label: roleLabel, criterion: criterion),
          );
    }

    for (final rule in _rules) {
      if (rule.criterion.type == MemberCustomFilterCriterionType.stufe) {
        continue;
      }
      final groupId = rule.criterion.groupId;
      if (groupId == null) {
        continue;
      }
      final groupKey = _groupKeyForId(groupId);
      if (seenGroupKeys.add(groupKey)) {
        groupOptions.add(
          _GroupOption(
            key: groupKey,
            label:
                rule.criterion.groupName ?? t.t('member_filter_group_unknown'),
            defaultCriterion: MemberCustomFilterCriterion.groupRole(
              groupId: groupId,
              groupName:
                  rule.criterion.groupName ??
                  t.t('member_filter_group_unknown'),
              groupType: rule.criterion.groupType,
            ),
          ),
        );
      }
      ensureAllRolesOption(
        groupKey,
        MemberCustomFilterCriterion.groupRole(
          groupId: groupId,
          groupName:
              rule.criterion.groupName ?? t.t('member_filter_group_unknown'),
          groupType: rule.criterion.groupType,
        ),
      );
      final roleKey = _roleKeyForCriterion(rule.criterion);
      final seenRoleKeys = seenRoleKeysByGroup.putIfAbsent(
        groupKey,
        () => <String>{},
      );
      if (!seenRoleKeys.add(roleKey) || roleKey == _allRolesRoleKey) {
        continue;
      }
      rolesByGroup
          .putIfAbsent(groupKey, () => <_RoleOption>[])
          .add(
            _RoleOption(
              key: roleKey,
              label: _fallbackCriterionLabel(t, rule.criterion),
              criterion: rule.criterion,
            ),
          );
    }

    return _SelectorData(groups: groupOptions, rolesByGroup: rolesByGroup);
  }

  String _selectedGroupKey(
    MemberCustomFilterCriterion criterion,
    _SelectorData selectorData,
  ) {
    if (criterion.type == MemberCustomFilterCriterionType.stufe) {
      return selectorData.groups.first.key;
    }
    return _groupKeyForId(criterion.groupId!);
  }

  String _selectedRoleKey(MemberCustomFilterCriterion criterion) {
    if (criterion.type == MemberCustomFilterCriterionType.stufe) {
      return _noRoleNeededKey;
    }
    return _roleKeyForCriterion(criterion);
  }

  List<_RoleOption> _roleOptionsForRule(
    AppLocalizations t,
    MemberCustomFilterCriterion criterion,
    _SelectorData selectorData,
  ) {
    if (criterion.type == MemberCustomFilterCriterionType.stufe) {
      return <_RoleOption>[
        _RoleOption(
          key: _noRoleNeededKey,
          label: t.t('member_filter_role_not_applicable'),
          criterion: const MemberCustomFilterCriterion.stufe(),
        ),
      ];
    }

    return selectorData.rolesByGroup[_groupKeyForId(criterion.groupId!)] ??
        <_RoleOption>[
          _RoleOption(
            key: _allRolesRoleKey,
            label: t.t('member_filter_all_roles'),
            criterion: criterion.copyWith(roleType: null, roleLabel: null),
          ),
        ];
  }

  String _groupKeyForId(int id) => 'group:$id';

  String _roleKeyForCriterion(MemberCustomFilterCriterion criterion) {
    if (criterion.roleType == null && criterion.roleLabel == null) {
      return _allRolesRoleKey;
    }
    return 'role:${criterion.roleType ?? ''}|${criterion.roleLabel ?? ''}';
  }

  String _fallbackCriterionLabel(
    AppLocalizations t,
    MemberCustomFilterCriterion criterion,
  ) {
    switch (criterion.type) {
      case MemberCustomFilterCriterionType.stufe:
        return t.t('member_filter_criterion_stage');
      case MemberCustomFilterCriterionType.groupRole:
        final groupName =
            criterion.groupName ?? t.t('member_filter_group_unknown');
        final roleLabel =
            (criterion.roleType == null && criterion.roleLabel == null)
            ? t.t('member_filter_all_roles')
            : criterion.roleLabel ??
                  criterion.roleType ??
                  t.t('member_filter_role_unknown');
        return '$groupName - $roleLabel';
    }
  }
}

const String _allRolesRoleKey = 'all_roles';
const String _noRoleNeededKey = 'no_role_needed';

class _SelectorData {
  const _SelectorData({required this.groups, required this.rolesByGroup});

  final List<_GroupOption> groups;
  final Map<String, List<_RoleOption>> rolesByGroup;
}

class _GroupOption {
  const _GroupOption({
    required this.key,
    required this.label,
    required this.defaultCriterion,
  });

  final String key;
  final String label;
  final MemberCustomFilterCriterion defaultCriterion;
}

class _RoleOption {
  const _RoleOption({
    required this.key,
    required this.label,
    required this.criterion,
  });

  final String key;
  final String label;
  final MemberCustomFilterCriterion criterion;
}

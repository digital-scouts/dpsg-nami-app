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
    backgroundColor: Colors.transparent,
    builder: (sheetContext) =>
        _MemberFilterSortSheet(model: model, readModel: readModel),
  );
}

class _MemberFilterSortSheet extends StatefulWidget {
  const _MemberFilterSortSheet({required this.model, required this.readModel});

  final MemberFiltersModel model;
  final ArbeitskontextReadModel readModel;

  @override
  State<_MemberFilterSortSheet> createState() => _MemberFilterSortSheetState();
}

class _MemberFilterSortSheetState extends State<_MemberFilterSortSheet> {
  late MemberSortKey _draftSortKey;
  late MemberSubtitleMode _draftSubtitleMode;
  late List<MemberCustomFilterGroup> _draftCustomGroups;

  @override
  void initState() {
    super.initState();
    _draftSortKey = widget.model.sortKey;
    _draftSubtitleMode = widget.model.subtitleMode;
    _draftCustomGroups = List<MemberCustomFilterGroup>.from(
      widget.model.customGroups,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);
    final keyboardInset = mediaQuery.viewInsets.bottom;
    final bottomPadding = keyboardInset > 0
        ? keyboardInset + 16
        : mediaQuery.viewPadding.bottom + 16;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.9,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _SheetHandle(),
          Padding(
            padding: EdgeInsets.fromLTRB(
              16 + mediaQuery.viewPadding.left,
              12,
              16 + mediaQuery.viewPadding.right,
              4,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    t.t('member_filter_sheet_title'),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _resetToDefaults,
                  child: Text(t.t('member_filter_reset')),
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                left: mediaQuery.viewPadding.left,
                right: mediaQuery.viewPadding.right,
                bottom: 8,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: _SheetDropdownField<MemberSortKey>(
                      label: t.t('member_filter_sort_label'),
                      value: _draftSortKey,
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
                        setState(() => _draftSortKey = value);
                      },
                    ),
                  ),
                  const _SheetDivider(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: _SheetDropdownField<MemberSubtitleMode>(
                      label: t.t('member_filter_subtitle_label'),
                      value: _draftSubtitleMode,
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
                        setState(() => _draftSubtitleMode = value);
                      },
                    ),
                  ),
                  const _SheetDivider(),
                  _SheetSectionLabel(t.t('member_filter_custom_groups_title')),
                  if (_draftCustomGroups.isEmpty)
                    _SheetEmptyState(
                      icon: Icons.folder_open,
                      text: t.t('member_filter_custom_groups_empty'),
                    )
                  else
                    _SheetOptions(
                      children: _draftCustomGroups
                          .map(
                            (group) => _CustomGroupRow(
                              group: group,
                              subtitle: _groupSubtitle(t, group),
                              onActiveChanged: (value) {
                                setState(() {
                                  _draftCustomGroups = _draftCustomGroups
                                      .map(
                                        (existing) => existing.id == group.id
                                            ? existing.copyWith(isActive: value)
                                            : existing,
                                      )
                                      .toList(growable: false);
                                });
                              },
                              onEdit: () => _editGroup(group),
                              onDelete: () {
                                setState(() {
                                  _draftCustomGroups = _draftCustomGroups
                                      .where(
                                        (existing) => existing.id != group.id,
                                      )
                                      .toList(growable: false);
                                });
                              },
                            ),
                          )
                          .toList(growable: false),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _createGroup,
                        icon: const Icon(Icons.add),
                        label: Text(t.t('member_filter_create')),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              16 + mediaQuery.viewPadding.left,
              8,
              16 + mediaQuery.viewPadding.right,
              bottomPadding,
            ),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  textStyle: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onPressed: _applyDraft,
                child: Text(t.t('member_filter_apply')),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editGroup(MemberCustomFilterGroup group) async {
    final edited = await showModalBottomSheet<MemberCustomFilterGroup>(
      context: context,
      isScrollControlled: true,
      builder: (editorContext) => _CustomGroupEditorSheet(
        readModel: widget.readModel,
        initialGroup: group,
      ),
    );
    if (edited == null) {
      return;
    }
    setState(() {
      _draftCustomGroups = _upsertGroup(_draftCustomGroups, edited);
    });
  }

  Future<void> _createGroup() async {
    final result = await showModalBottomSheet<MemberCustomFilterGroup>(
      context: context,
      isScrollControlled: true,
      builder: (editorContext) =>
          _CustomGroupEditorSheet(readModel: widget.readModel),
    );
    if (result == null) {
      return;
    }
    setState(() {
      _draftCustomGroups = _upsertGroup(_draftCustomGroups, result);
    });
  }

  void _resetToDefaults() {
    setState(() {
      _draftSortKey = MemberSortKey.name;
      _draftSubtitleMode = MemberSubtitleMode.mitgliedsnummer;
      _draftCustomGroups = _draftCustomGroups
          .map((group) => group.copyWith(isActive: group.isDefault))
          .toList(growable: false);
    });
  }

  Future<void> _applyDraft() async {
    await widget.model.applySettings(
      sortKey: _draftSortKey,
      subtitleMode: _draftSubtitleMode,
      customGroups: _draftCustomGroups,
    );
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  List<MemberCustomFilterGroup> _upsertGroup(
    List<MemberCustomFilterGroup> groups,
    MemberCustomFilterGroup candidate,
  ) {
    var replaced = false;
    final next = groups
        .map((group) {
          if (group.id == candidate.id) {
            replaced = true;
            return candidate;
          }
          return group;
        })
        .toList(growable: true);
    if (!replaced) {
      next.add(candidate);
    }
    return next;
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

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 4,
      margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.outline,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

class _SheetSectionLabel extends StatelessWidget {
  const _SheetSectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.outlineVariant,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _SheetDropdownField<T> extends StatelessWidget {
  const _SheetDropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DropdownButtonFormField<T>(
      initialValue: value,
      items: items,
      onChanged: onChanged,
      isExpanded: true,
      borderRadius: BorderRadius.circular(12),
      icon: const Icon(Icons.keyboard_arrow_down),
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurface,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        filled: true,
        fillColor: theme.colorScheme.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }
}

class _SheetOptions extends StatelessWidget {
  const _SheetOptions({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(children: children),
    );
  }
}

class _CustomGroupRow extends StatelessWidget {
  const _CustomGroupRow({
    required this.group,
    required this.subtitle,
    required this.onActiveChanged,
    required this.onEdit,
    required this.onDelete,
  });

  final MemberCustomFilterGroup group;
  final String subtitle;
  final ValueChanged<bool> onActiveChanged;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context);
    return Material(
      color: group.isActive
          ? theme.colorScheme.primaryContainer
          : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
        child: Row(
          children: [
            Switch(value: group.isActive, onChanged: onActiveChanged),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.displayChipLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 15,
                      color: group.isActive
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface,
                      fontWeight: group.isActive
                          ? FontWeight.w500
                          : FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.outlineVariant,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: t.t('member_filter_edit'),
              onPressed: onEdit,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: t.t('member_filter_delete'),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetEmptyState extends StatelessWidget {
  const _SheetEmptyState({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.outline),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetDivider extends StatelessWidget {
  const _SheetDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.45),
    );
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
                    child: _SheetSelectField(
                      label: t.t('member_filter_icon_label'),
                      value: _iconLabel(t, _iconKey),
                      leading: _iconKey == null
                          ? null
                          : Icon(memberCustomFilterIconForKey(_iconKey)),
                      onTap: () async {
                        final selected = await _showOptionPickerSheet<String?>(
                          context,
                          title: t.t('member_filter_icon_label'),
                          selected: _iconKey,
                          options: <_SelectOption<String?>>[
                            _SelectOption<String?>(
                              value: null,
                              label: t.t('member_filter_icon_none'),
                            ),
                            ...memberCustomFilterIconOptions.map(
                              (option) => _SelectOption<String?>(
                                value: option.key,
                                label: t.t(option.labelKey),
                                icon: option.icon,
                              ),
                            ),
                          ],
                        );
                        if (selected != null || _iconKey != null) {
                          setState(() => _iconKey = selected);
                        }
                      },
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
              _SheetSelectField(
                label: t.t('member_filter_logic_label'),
                value: _logic == MemberCustomFilterLogic.und
                    ? t.t('member_filter_logic_and')
                    : t.t('member_filter_logic_or'),
                onTap: () async {
                  final selected =
                      await _showOptionPickerSheet<MemberCustomFilterLogic>(
                        context,
                        title: t.t('member_filter_logic_label'),
                        selected: _logic,
                        options: MemberCustomFilterLogic.values
                            .map(
                              (value) => _SelectOption<MemberCustomFilterLogic>(
                                value: value,
                                label: value == MemberCustomFilterLogic.und
                                    ? t.t('member_filter_logic_and')
                                    : t.t('member_filter_logic_or'),
                              ),
                            )
                            .toList(growable: false),
                      );
                  if (selected != null) {
                    setState(() => _logic = selected);
                  }
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
                  child: Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _SheetSelectField(
                            label: t.t('member_filter_rule_operator_label'),
                            value:
                                rule.operator ==
                                    MemberCustomFilterRuleOperator.hat
                                ? t.t('member_filter_operator_has')
                                : t.t('member_filter_operator_has_not'),
                            onTap: () async {
                              final selected =
                                  await _showOptionPickerSheet<
                                    MemberCustomFilterRuleOperator
                                  >(
                                    context,
                                    title: t.t(
                                      'member_filter_rule_operator_label',
                                    ),
                                    selected: rule.operator,
                                    options: MemberCustomFilterRuleOperator
                                        .values
                                        .map(
                                          (value) =>
                                              _SelectOption<
                                                MemberCustomFilterRuleOperator
                                              >(
                                                value: value,
                                                label:
                                                    value ==
                                                        MemberCustomFilterRuleOperator
                                                            .hat
                                                    ? t.t(
                                                        'member_filter_operator_has',
                                                      )
                                                    : t.t(
                                                        'member_filter_operator_has_not',
                                                      ),
                                              ),
                                        )
                                        .toList(growable: false),
                                  );
                              if (selected != null) {
                                setState(() {
                                  _rules[index] = _rules[index].copyWith(
                                    operator: selected,
                                  );
                                });
                              }
                            },
                          ),
                          const SizedBox(height: 8),
                          _SheetSelectField(
                            label: t.t('member_filter_rule_group_label'),
                            value: selectorData.groups
                                .firstWhere(
                                  (option) =>
                                      option.key ==
                                      _selectedGroupKey(
                                        rule.criterion,
                                        selectorData,
                                      ),
                                )
                                .label,
                            onTap: () async {
                              final selected =
                                  await _showOptionPickerSheet<String>(
                                    context,
                                    title: t.t(
                                      'member_filter_rule_group_label',
                                    ),
                                    selected: _selectedGroupKey(
                                      rule.criterion,
                                      selectorData,
                                    ),
                                    options: selectorData.groups
                                        .map(
                                          (option) => _SelectOption<String>(
                                            value: option.key,
                                            label: option.label,
                                          ),
                                        )
                                        .toList(growable: false),
                                  );
                              if (selected == null) {
                                return;
                              }
                              final groupOption = selectorData.groups
                                  .firstWhere(
                                    (option) => option.key == selected,
                                  );
                              setState(() {
                                _rules[index] = _rules[index].copyWith(
                                  criterion: groupOption.defaultCriterion,
                                );
                              });
                            },
                          ),
                          const SizedBox(height: 8),
                          _SheetSelectField(
                            label: t.t('member_filter_rule_role_label'),
                            value:
                                _roleOptionsForRule(
                                      t,
                                      rule.criterion,
                                      selectorData,
                                    )
                                    .firstWhere(
                                      (option) =>
                                          option.key ==
                                          _selectedRoleKey(rule.criterion),
                                      orElse: () => _roleOptionsForRule(
                                        t,
                                        rule.criterion,
                                        selectorData,
                                      ).first,
                                    )
                                    .label,
                            enabled:
                                rule.criterion.type !=
                                MemberCustomFilterCriterionType.stufe,
                            onTap:
                                rule.criterion.type ==
                                    MemberCustomFilterCriterionType.stufe
                                ? null
                                : () async {
                                    final roleOptions = _roleOptionsForRule(
                                      t,
                                      rule.criterion,
                                      selectorData,
                                    );
                                    final selected =
                                        await _showOptionPickerSheet<String>(
                                          context,
                                          title: t.t(
                                            'member_filter_rule_role_label',
                                          ),
                                          selected: _selectedRoleKey(
                                            rule.criterion,
                                          ),
                                          options: roleOptions
                                              .map(
                                                (option) =>
                                                    _SelectOption<String>(
                                                      value: option.key,
                                                      label: option.label,
                                                    ),
                                              )
                                              .toList(growable: false),
                                        );
                                    if (selected == null) {
                                      return;
                                    }
                                    final roleOption = roleOptions.firstWhere(
                                      (option) => option.key == selected,
                                    );
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
                    ),
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

  String _iconLabel(AppLocalizations t, String? iconKey) {
    if (iconKey == null) {
      return t.t('member_filter_icon_none');
    }
    for (final option in memberCustomFilterIconOptions) {
      if (option.key == iconKey) {
        return t.t(option.labelKey);
      }
    }
    return t.t('member_filter_icon_none');
  }

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

class _SheetSelectField extends StatelessWidget {
  const _SheetSelectField({
    required this.label,
    required this.value,
    required this.onTap,
    this.leading,
    this.enabled = true,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;
  final Widget? leading;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = enabled
        ? theme.colorScheme.outline.withValues(alpha: 0.5)
        : theme.colorScheme.outline.withValues(alpha: 0.25);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
          color: enabled
              ? theme.colorScheme.surface
              : theme.colorScheme.surfaceContainerLowest,
        ),
        child: Row(
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 8)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: enabled
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down,
              color: enabled
                  ? theme.colorScheme.outline
                  : theme.colorScheme.outline.withValues(alpha: 0.45),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectOption<T> {
  const _SelectOption({required this.value, required this.label, this.icon});

  final T value;
  final String label;
  final IconData? icon;
}

Future<T?> _showOptionPickerSheet<T>(
  BuildContext context, {
  required String title,
  required T selected,
  required List<_SelectOption<T>> options,
}) {
  return showModalBottomSheet<T>(
    context: context,
    builder: (sheetContext) {
      final theme = Theme.of(sheetContext);
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
                child: Text(title, style: theme.textTheme.titleMedium),
              ),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: options.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 4),
                  itemBuilder: (context, index) {
                    final option = options[index];
                    final isSelected = option.value == selected;
                    return Material(
                      borderRadius: BorderRadius.circular(12),
                      color: isSelected
                          ? theme.colorScheme.primary.withValues(alpha: 0.1)
                          : theme.colorScheme.surface,
                      child: ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        onTap: () =>
                            Navigator.of(sheetContext).pop(option.value),
                        leading: option.icon == null
                            ? null
                            : Icon(option.icon, size: 20),
                        title: Text(option.label),
                        trailing: isSelected
                            ? Icon(
                                Icons.check,
                                color: theme.colorScheme.primary,
                              )
                            : null,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

import 'package:flutter/material.dart';
import 'package:nami/domain/member/mitglied.dart';
import 'package:nami/domain/taetigkeit/stufe.dart';
import 'package:nami/presentation/navigation/app_router.dart';
import 'package:nami/presentation/screens/member_detail_page.dart';
import 'package:nami/presentation/stufe/stufe_visuals.dart';
import 'package:nami/presentation/theme/theme.dart';

enum StufenwechselDummyMode { populated, empty }

class SettingsStufenwechselPage extends StatefulWidget {
  final StufenwechselDummyMode mode;
  final void Function(int selectedCount)? onTransferTap;
  final bool showAppBar;

  const SettingsStufenwechselPage({
    super.key,
    this.mode = StufenwechselDummyMode.populated,
    this.onTransferTap,
    this.showAppBar = true,
  });

  @override
  State<SettingsStufenwechselPage> createState() =>
      _SettingsStufenwechselPageState();
}

class _SettingsStufenwechselPageState extends State<SettingsStufenwechselPage> {
  final Map<Stufe, Set<String>> _selectedIdsByStage = <Stufe, Set<String>>{};

  static const List<Stufe> _transferStages = <Stufe>[
    Stufe.biber,
    Stufe.woelfling,
    Stufe.jungpfadfinder,
    Stufe.pfadfinder,
  ];

  static final Map<Stufe, List<_DummyMember>> _membersByStage = {
    Stufe.woelfling: const [
      _DummyMember(
        id: 'w1',
        name: 'Emma Mueller',
        subtitle: '10 Jahre · Sep. 2026',
        dueLabel: 'Sep. 2026',
        dueState: _DueState.upcoming,
      ),
      _DummyMember(
        id: 'w2',
        name: 'Lukas Hoffmann',
        subtitle: '10 Jahre · Sep. 2026 - Sep. 2027',
        dueLabel: 'Sep. 2027',
        dueState: _DueState.upcoming,
      ),
    ],
    Stufe.pfadfinder: const [
      _DummyMember(
        id: 'p1',
        name: 'Mia Becker',
        subtitle: '15 Jahre · Sep. 2026',
        dueLabel: 'Sep. 2026',
        dueState: _DueState.upcoming,
      ),
    ],
  };

  static final List<_DummyMember> _roverMembers = [
    const _DummyMember(
      id: 'r1',
      name: 'Tim Koch',
      subtitle: '21 Jahre · Austritt überfällig',
      dueLabel: 'Überfällig',
      dueState: _DueState.overdue,
    ),
  ];

  List<_DummyStageSection> get _visibleSections {
    if (widget.mode == StufenwechselDummyMode.empty) {
      return const <_DummyStageSection>[];
    }

    return _transferStages
        .map(
          (stage) => _DummyStageSection(
            stageFrom: stage,
            stageTo: stage.nextStufe!,
            members: _membersByStage[stage] ?? const <_DummyMember>[],
          ),
        )
        .toList(growable: false);
  }

  int get _summaryCount => _visibleSections.fold<int>(
    0,
    (sum, section) => sum + section.members.length,
  );

  Set<String> _selectedIdsFor(Stufe stage) {
    return _selectedIdsByStage[stage] ?? <String>{};
  }

  int _selectedCountFor(Stufe stage) => _selectedIdsFor(stage).length;

  void _toggleSelection(Stufe stage, String id) {
    setState(() {
      final selectedForStage = _selectedIdsByStage.putIfAbsent(
        stage,
        () => <String>{},
      );

      if (selectedForStage.contains(id)) {
        selectedForStage.remove(id);
      } else {
        selectedForStage.add(id);
      }
    });
  }

  void _onTransferPressed(Stufe stage) {
    final selectedCount = _selectedCountFor(stage);
    debugPrint(
      'Stufenwechsel Dummy ${stage.name}: $selectedCount Elemente ausgewählt',
    );
    widget.onTransferTap?.call(selectedCount);
  }

  Future<void> _openMemberDetails(_DummyMember member) async {
    final mitglied = member.toMitglied();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: RouteSettings(
          name: AppRoutes.memberDetail,
          arguments: mitglied.mitgliedsnummer,
        ),
        builder: (_) => MemberDetailPage(mitglied: mitglied),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(title: const Text('Stufenwechsel'))
          : null,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.swap_horiz, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$_summaryCount',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Mitglieder im Wechselfenster',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  color: theme.colorScheme.outlineVariant,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mitglieder erscheinen hier, sobald sie bis zum Stufenwechsel-Termin das Mindestalter der nächsten Stufe erreichen.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outlineVariant,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: () => Navigator.pushNamed(
                          context,
                          AppRoutes.settingsStamm,
                        ),
                        child: Text(
                          'Altersgrenzen in Stammeseinstellungen anpassen',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.primary,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (_visibleSections.isEmpty)
            Container(
              key: const Key('stufenwechsel-empty-state'),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: theme.colorScheme.outline.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 40,
                    color: theme.colorScheme.outline,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Kein Stufenwechsel fällig',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Alle Mitglieder sind für den nächsten Termin in der passenden Stufe.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outlineVariant,
                    ),
                  ),
                ],
              ),
            ),
          for (final section in _visibleSections) ...[
            _StageSectionCard(
              section: section,
              selectedIds: _selectedIdsFor(section.stageFrom),
              onMemberTap: (id) => _toggleSelection(section.stageFrom, id),
              onMemberDetailsTap: _openMemberDetails,
              onTransferTap: () => _onTransferPressed(section.stageFrom),
            ),
            const SizedBox(height: 12),
          ],
          if (_roverMembers.isNotEmpty)
            _RoverInfoCard(
              members: _roverMembers,
              onMemberDetailsTap: _openMemberDetails,
            ),
        ],
      ),
    );
  }
}

class _StageSectionCard extends StatelessWidget {
  final _DummyStageSection section;
  final Set<String> selectedIds;
  final ValueChanged<String> onMemberTap;
  final ValueChanged<_DummyMember> onMemberDetailsTap;
  final VoidCallback onTransferTap;

  const _StageSectionCard({
    required this.section,
    required this.selectedIds,
    required this.onMemberTap,
    required this.onMemberDetailsTap,
    required this.onTransferTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stageColor = StufeVisuals.colorFor(section.stageFrom);
    final stageBgColor = _stageBackgroundFor(
      section.stageFrom,
      theme.brightness,
    );

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                _StageIconBubble(stage: section.stageFrom),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _stagePlural(section.stageFrom),
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Row(
                        children: [
                          Text(
                            '->',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.outlineVariant,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _stagePlural(section.stageTo),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.outlineVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: stageBgColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${section.members.length}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: stageColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 1,
            color: theme.colorScheme.outline.withValues(alpha: 0.18),
          ),
          Container(
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.35,
            ),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                const SizedBox(width: 28),
                Expanded(
                  child: Text(
                    'MITGLIED',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.outlineVariant,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Text(
                  'SPÄTESTENS',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.outlineVariant,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          for (var i = 0; i < section.members.length; i++) ...[
            _SelectableMemberRow(
              member: section.members[i],
              isSelected: selectedIds.contains(section.members[i].id),
              onTap: () => onMemberTap(section.members[i].id),
              onOpenDetails: () => onMemberDetailsTap(section.members[i]),
              stage: section.stageFrom,
            ),
            if (i < section.members.length - 1)
              const Divider(height: 1, indent: 16, endIndent: 16),
          ],
          if (section.members.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 14,
                    color: theme.colorScheme.outlineVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Keine passenden Mitglieder für diese Stufe.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outlineVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (section.members.isNotEmpty)
            Container(
              key: Key('stufenwechsel-transfer-row-${section.stageFrom.name}'),
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: theme.colorScheme.outline.withValues(alpha: 0.22),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Text(
                    '${selectedIds.length} ausgewählt',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outlineVariant,
                    ),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    key: Key(
                      'stufenwechsel-transfer-button-${section.stageFrom.name}',
                    ),
                    onPressed: selectedIds.isNotEmpty ? onTransferTap : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: stageColor,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: theme.colorScheme.outline
                          .withValues(alpha: 0.35),
                      disabledForegroundColor: Colors.white.withValues(
                        alpha: 0.85,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                    ),
                    icon: const Icon(Icons.done_all, size: 16),
                    label: const Text('Auswahl übernehmen'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SelectableMemberRow extends StatelessWidget {
  final _DummyMember member;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onOpenDetails;
  final Stufe stage;
  final bool showCheckbox;

  const _SelectableMemberRow({
    required this.member,
    required this.isSelected,
    required this.onTap,
    required this.onOpenDetails,
    required this.stage,
    this.showCheckbox = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stageColor = StufeVisuals.colorFor(stage);

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
      child: Row(
        children: [
          if (showCheckbox)
            Theme(
              data: theme.copyWith(
                checkboxTheme: CheckboxThemeData(
                  fillColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return stageColor;
                    }
                    return Colors.transparent;
                  }),
                  side: BorderSide(
                    color: theme.colorScheme.outline.withValues(alpha: 0.7),
                    width: 1.8,
                  ),
                  checkColor: WidgetStateProperty.all(Colors.white),
                  visualDensity: VisualDensity.compact,
                ),
              ),
              child: Checkbox(
                key: Key('stufenwechsel-checkbox-${member.id}'),
                value: isSelected,
                onChanged: (_) => onTap(),
              ),
            )
          else
            const SizedBox(width: 20),
          if (showCheckbox) const SizedBox(width: 4),
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: stageColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              key: Key('stufenwechsel-member-row-${member.id}'),
              behavior: HitTestBehavior.opaque,
              onTap: onOpenDetails,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(member.name, style: theme.textTheme.bodyMedium),
                        const SizedBox(height: 2),
                        Text(
                          member.subtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outlineVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (member.dueLabel != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _dueBackgroundColor(
                          member.dueState,
                          theme.brightness,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        member.dueLabel!,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: _dueForegroundColor(member.dueState),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoverInfoCard extends StatelessWidget {
  final List<_DummyMember> members;
  final ValueChanged<_DummyMember> onMemberDetailsTap;

  const _RoverInfoCard({
    required this.members,
    required this.onMemberDetailsTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final roverColor = StufeVisuals.colorFor(Stufe.rover);
    final roverBg = _stageBackgroundFor(Stufe.rover, theme.brightness);

    return Container(
      key: const Key('stufenwechsel-rover-section'),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                _StageIconBubble(stage: Stufe.rover),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mitgliedschaft endet',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: roverColor,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        'Rover erreichen Maximalalter',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outlineVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: roverBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${members.length}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: roverColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Container(
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.35,
            ),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                const SizedBox(width: 28),
                Expanded(
                  child: Text(
                    'MITGLIED',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.outlineVariant,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Text(
                  'TERMIN',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.outlineVariant,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          for (var i = 0; i < members.length; i++) ...[
            _SelectableMemberRow(
              member: members[i],
              isSelected: false,
              onTap: () {},
              onOpenDetails: () => onMemberDetailsTap(members[i]),
              stage: Stufe.rover,
              showCheckbox: false,
            ),
            if (i < members.length - 1)
              const Divider(height: 1, indent: 16, endIndent: 16),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 14,
                  color: theme.colorScheme.outlineVariant,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Nur zur Information - kein Stufenwechsel möglich.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outlineVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DummyStageSection {
  final Stufe stageFrom;
  final Stufe stageTo;
  final List<_DummyMember> members;

  const _DummyStageSection({
    required this.stageFrom,
    required this.stageTo,
    required this.members,
  });
}

class _DummyMember {
  final String id;
  final String name;
  final String subtitle;
  final String? dueLabel;
  final _DueState dueState;

  const _DummyMember({
    required this.id,
    required this.name,
    required this.subtitle,
    this.dueLabel,
    this.dueState = _DueState.none,
  });

  Mitglied toMitglied() {
    final parts = name.trim().split(RegExp(r'\s+'));
    final vorname = parts.isEmpty ? name : parts.first;
    final nachname = parts.length <= 1 ? '' : parts.skip(1).join(' ');

    return Mitglied.peopleListItem(
      mitgliedsnummer: id,
      vorname: vorname,
      nachname: nachname,
    );
  }
}

enum _DueState { none, upcoming, overdue }

class _StageIconBubble extends StatelessWidget {
  final Stufe stage;

  const _StageIconBubble({required this.stage});

  @override
  Widget build(BuildContext context) {
    final color = StufeVisuals.colorFor(stage);
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Center(
            child: Image.asset(
              StufeVisuals.assetFor(stage),
              width: 20,
              height: 20,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) =>
                  Icon(Icons.groups, color: color, size: 16),
            ),
          ),
        ),
      ),
    );
  }
}

String _stagePlural(Stufe stage) {
  return switch (stage) {
    Stufe.biber => 'Biber',
    Stufe.woelfling => 'Wölflinge',
    Stufe.jungpfadfinder => 'Jungpfadfinder',
    Stufe.pfadfinder => 'Pfadfinder',
    Stufe.rover => 'Rover',
    Stufe.leitung => 'Leitung',
  };
}

Color _stageBackgroundFor(Stufe stage, Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  return switch (stage) {
    Stufe.biber => isDark ? const Color(0xFF2A2218) : const Color(0xFFF5EDE5),
    Stufe.woelfling =>
      isDark ? const Color(0xFF3A1A00) : const Color(0xFFFFF0E6),
    Stufe.jungpfadfinder =>
      isDark ? const Color(0xFF0E1828) : const Color(0xFFE8EDF7),
    Stufe.pfadfinder =>
      isDark ? const Color(0xFF0A1C10) : const Color(0xFFE0F2EA),
    Stufe.rover => isDark ? const Color(0xFF240808) : const Color(0xFFFCEAEB),
    Stufe.leitung =>
      isDark ? DPSGColors.darkPrimaryLite : DPSGColors.lightPrimaryLite,
  };
}

Color _dueBackgroundColor(_DueState state, Brightness brightness) {
  return switch (state) {
    _DueState.none => Colors.transparent,
    _DueState.upcoming =>
      brightness == Brightness.dark
          ? const Color(0xFF0E1828)
          : const Color(0xFFE8EDF7),
    _DueState.overdue =>
      brightness == Brightness.dark
          ? const Color(0xFF240808)
          : const Color(0xFFFCEAEB),
  };
}

Color _dueForegroundColor(_DueState state) {
  return switch (state) {
    _DueState.none => Colors.transparent,
    _DueState.upcoming => DPSGColors.jungpfadfinderFarbe,
    _DueState.overdue => DPSGColors.roverFarbe,
  };
}

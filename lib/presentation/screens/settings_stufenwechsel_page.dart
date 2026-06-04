import 'package:flutter/material.dart';
import 'package:nami/data/settings/shared_prefs_stufen_settings_repository.dart';
import 'package:nami/domain/arbeitskontext/arbeitskontext_read_model.dart';
import 'package:nami/domain/member/mitglied.dart';
import 'package:nami/domain/settings/stufen_settings.dart';
import 'package:nami/domain/stufenwechsel/ermittle_stufenwechsel_vorschlaege_usecase.dart';
import 'package:nami/domain/taetigkeit/stufe.dart';
import 'package:nami/presentation/model/arbeitskontext_model.dart';
import 'package:nami/presentation/navigation/app_router.dart';
import 'package:nami/presentation/screens/member_detail_page.dart';
import 'package:nami/presentation/stufe/stufe_visuals.dart';
import 'package:nami/presentation/theme/theme.dart';
import 'package:provider/provider.dart';

class SettingsStufenwechselPage extends StatefulWidget {
  final bool showAppBar;
  final ArbeitskontextReadModel? debugReadModel;
  final Future<StufenSettings> Function()? stufenSettingsLoader;
  final DateTime Function()? todayProvider;

  const SettingsStufenwechselPage({
    super.key,
    this.showAppBar = true,
    this.debugReadModel,
    this.stufenSettingsLoader,
    this.todayProvider,
  });

  @override
  State<SettingsStufenwechselPage> createState() =>
      _SettingsStufenwechselPageState();
}

class _SettingsStufenwechselPageState extends State<SettingsStufenwechselPage> {
  static const ErmittleStufenwechselVorschlaegeUseCase _useCase =
      ErmittleStufenwechselVorschlaegeUseCase();

  late Future<StufenSettings> _settingsFuture;

  @override
  void initState() {
    super.initState();
    _settingsFuture = _loadSettings();
  }

  @override
  void didUpdateWidget(covariant SettingsStufenwechselPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stufenSettingsLoader != widget.stufenSettingsLoader) {
      _settingsFuture = _loadSettings();
    }
  }

  Future<StufenSettings> _loadSettings() {
    final loader = widget.stufenSettingsLoader;
    if (loader != null) {
      return loader();
    }
    return SharedPrefsStufenSettingsRepository().load();
  }

  DateTime _today() {
    final now = widget.todayProvider?.call() ?? DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  Future<void> _openMemberDetails(StufenwechselVorschlag vorschlag) async {
    final mitglied = vorschlag.mitglied;
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
    final readModel = _resolveReadModel(context);

    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(title: const Text('Stufenwechsel'))
          : null,
      body: FutureBuilder<StufenSettings>(
        future: _settingsFuture,
        builder: (context, snapshot) {
          if (readModel == null ||
              snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || snapshot.data == null) {
            return const _StufenwechselStatusView(
              icon: Icons.error_outline,
              title: 'Stufenwechsel konnte nicht geladen werden',
              message: 'Bitte versuche es später erneut.',
            );
          }

          final settings = snapshot.data!;
          final stichtag = settings.stufenwechselDatum ?? _today();
          final sections = _useCase(
            mitglieder: readModel.mitglieder,
            stichtag: stichtag,
            altersgrenzen: settings.grenzen,
          );
          final summaryCount = sections.fold<int>(
            0,
            (sum, section) => sum + section.vorschlaege.length,
          );

          return _StufenwechselContent(
            stichtag: stichtag,
            hasConfiguredDate: settings.stufenwechselDatum != null,
            sections: sections,
            summaryCount: summaryCount,
            onMemberDetailsTap: _openMemberDetails,
          );
        },
      ),
    );
  }

  ArbeitskontextReadModel? _resolveReadModel(BuildContext context) {
    final debugReadModel = widget.debugReadModel;
    if (debugReadModel != null) {
      return debugReadModel;
    }

    final arbeitskontextModel = context.watch<ArbeitskontextModel>();
    final readModel = arbeitskontextModel.readModel;
    if (readModel == null) {
      return null;
    }
    if (!arbeitskontextModel.areRolesLoaded) {
      if (!arbeitskontextModel.isLoadingRoles) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            arbeitskontextModel.ensureRolesLoaded();
          }
        });
      }
      return null;
    }
    return readModel;
  }
}

class _StufenwechselContent extends StatelessWidget {
  const _StufenwechselContent({
    required this.stichtag,
    required this.hasConfiguredDate,
    required this.sections,
    required this.summaryCount,
    required this.onMemberDetailsTap,
  });

  final DateTime stichtag;
  final bool hasConfiguredDate;
  final List<StufenwechselVorschlagsSection> sections;
  final int summaryCount;
  final ValueChanged<StufenwechselVorschlag> onMemberDetailsTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
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
                      '$summaryCount',
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
                    const SizedBox(height: 2),
                    Text(
                      'Stichtag: ${_formatDate(stichtag)}',
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
        _StufenwechselHintCard(
          stichtag: stichtag,
          isWarning: !hasConfiguredDate,
        ),
        const SizedBox(height: 12),
        if (summaryCount == 0) ...[
          const _NoStageChangeCard(),
          const SizedBox(height: 12),
        ],
        for (final section in sections) ...[
          _StageSectionCard(
            section: section,
            onMemberDetailsTap: onMemberDetailsTap,
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _StufenwechselHintCard extends StatelessWidget {
  const _StufenwechselHintCard({
    required this.stichtag,
    required this.isWarning,
  });

  final DateTime stichtag;
  final bool isWarning;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foregroundColor = isWarning
        ? theme.colorScheme.onTertiaryContainer
        : theme.colorScheme.outlineVariant;
    final backgroundColor = isWarning
        ? theme.colorScheme.tertiaryContainer.withValues(alpha: 0.42)
        : theme.colorScheme.surface;
    final borderColor = isWarning
        ? theme.colorScheme.tertiary.withValues(alpha: 0.38)
        : theme.colorScheme.outline.withValues(alpha: 0.3);

    return Container(
      key: Key(isWarning ? 'stufenwechsel-date-warning' : 'stufenwechsel-hint'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isWarning ? Icons.warning_amber_outlined : Icons.info_outline,
            color: foregroundColor,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isWarning
                      ? 'Kein Datum für den nächsten Stufenwechsel festgelegt. Es wird vorläufig mit heute gerechnet. Bitte Datum setzen.'
                      : 'Mitglieder erscheinen hier, sobald sie bis zum Stufenwechsel-Termin das Mindestalter der nächsten Stufe erreichen.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: foregroundColor,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: () =>
                      Navigator.pushNamed(context, AppRoutes.settingsStamm),
                  child: Text(
                    'Altersgrenzen und Datum in Stammeseinstellungen anpassen',
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
    );
  }
}

class _NoStageChangeCard extends StatelessWidget {
  const _NoStageChangeCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
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
          Text('Kein Stufenwechsel fällig', style: theme.textTheme.titleMedium),
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
    );
  }
}

class _StufenwechselStatusView extends StatelessWidget {
  const _StufenwechselStatusView({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: theme.colorScheme.outline),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outlineVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StageSectionCard extends StatelessWidget {
  final StufenwechselVorschlagsSection section;
  final ValueChanged<StufenwechselVorschlag> onMemberDetailsTap;

  const _StageSectionCard({
    required this.section,
    required this.onMemberDetailsTap,
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
                    '${section.vorschlaege.length}',
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
                const SizedBox(width: 16),
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
          for (var i = 0; i < section.vorschlaege.length; i++) ...[
            _MemberSuggestionRow(
              vorschlag: section.vorschlaege[i],
              onOpenDetails: () => onMemberDetailsTap(section.vorschlaege[i]),
            ),
            if (i < section.vorschlaege.length - 1)
              const Divider(height: 1, indent: 16, endIndent: 16),
          ],
          if (section.vorschlaege.isEmpty)
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
        ],
      ),
    );
  }
}

class _MemberSuggestionRow extends StatelessWidget {
  final StufenwechselVorschlag vorschlag;
  final VoidCallback onOpenDetails;

  const _MemberSuggestionRow({
    required this.vorschlag,
    required this.onOpenDetails,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stageColor = StufeVisuals.colorFor(vorschlag.aktuelleStufe);
    final mitglied = vorschlag.mitglied;
    final dueLabel = vorschlag.istUeberfaellig
        ? 'Überfällig'
        : vorschlag.spaetestensJahr.toString();
    final dueState = vorschlag.istUeberfaellig
        ? _DueState.overdue
        : _DueState.upcoming;

    return InkWell(
      key: Key('stufenwechsel-member-row-${mitglied.mitgliedsnummer}'),
      onTap: onOpenDetails,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
        child: Row(
          children: [
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _memberName(mitglied),
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${vorschlag.alterAmStichtag} Jahre · seit ${vorschlag.faelligSeitJahr}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outlineVariant,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _dueBackgroundColor(dueState, theme.brightness),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                dueLabel,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: _dueForegroundColor(dueState),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _DueState { upcoming, overdue }

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

String _memberName(Mitglied mitglied) {
  final fahrtenname = mitglied.fahrtenname?.trim();
  if (fahrtenname != null && fahrtenname.isNotEmpty) {
    return fahrtenname;
  }
  final fullName = '${mitglied.vorname} ${mitglied.nachname}'.trim();
  return fullName.isEmpty ? mitglied.mitgliedsnummer : fullName;
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

String _formatDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day.$month.${date.year}';
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
    _DueState.upcoming => DPSGColors.jungpfadfinderFarbe,
    _DueState.overdue => DPSGColors.roverFarbe,
  };
}

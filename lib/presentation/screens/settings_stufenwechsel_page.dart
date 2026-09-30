import 'package:flutter/material.dart';
import 'package:nami/data/settings/shared_prefs_stufen_settings_repository.dart';
import 'package:nami/domain/arbeitskontext/arbeitskontext_read_model.dart';
import 'package:nami/domain/member/mitglied.dart';
import 'package:nami/domain/settings/stufen_settings.dart';
import 'package:nami/domain/stufenwechsel/ermittle_stufenwechsel_vorschlaege_usecase.dart';
import 'package:nami/domain/taetigkeit/stufe.dart';
import 'package:nami/presentation/model/appearance_model.dart';
import 'package:nami/presentation/model/arbeitskontext_model.dart';
import 'package:nami/presentation/navigation/app_router.dart';
import 'package:nami/presentation/screens/member_detail_page.dart';
import 'package:nami/presentation/stufe/stufe_visuals.dart';
import 'package:nami/presentation/theme/theme.dart';
import 'package:nami/presentation/widgets/app_page_header.dart';
import 'package:nami/presentation/widgets/stufenwechsel_date_row.dart';
import 'package:provider/provider.dart';

class SettingsStufenwechselPage extends StatefulWidget {
  final bool showAppBar;
  final ArbeitskontextReadModel? debugReadModel;
  final Future<StufenSettings> Function()? stufenSettingsLoader;
  final Future<void> Function(DateTime date)? stufenwechselDatumSaver;
  final DateTime Function()? todayProvider;

  const SettingsStufenwechselPage({
    super.key,
    this.showAppBar = true,
    this.debugReadModel,
    this.stufenSettingsLoader,
    this.stufenwechselDatumSaver,
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

  Future<void> _pickStufenwechselDatum(StufenSettings settings) async {
    final picked = await pickStufenwechselDatum(
      context,
      initial: settings.stufenwechselDatum,
    );
    if (picked == null || !mounted) {
      return;
    }
    final saver =
        widget.stufenwechselDatumSaver ??
        SharedPrefsStufenSettingsRepository().saveStufenwechselDatum;
    await saver(picked);
    if (!mounted) {
      return;
    }
    setState(() {
      _settingsFuture = Future.value(
        settings.copyWith(stufenwechselDatum: picked),
      );
    });
  }

  Future<void> _openAltersgrenzen() async {
    await Navigator.of(context).pushNamed(AppRoutes.settingsStamm);
    if (!mounted) {
      return;
    }
    // Altersgrenzen und Datum koennen dort geaendert worden sein.
    setState(() {
      _settingsFuture = _loadSettings();
    });
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
    final background = context.watch<AppearanceModel?>()?.background;

    final body = FutureBuilder<StufenSettings>(
      future: _settingsFuture,
      builder: (context, snapshot) {
        // Beim Neuladen nach einer Aenderung bleibt der alte Stand sichtbar.
        if (readModel == null ||
            (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData)) {
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

        return Column(
          children: [
            AppPageHeader(
              background: background,
              child: _StufenwechselHeader(
                sections: sections,
                summaryCount: summaryCount,
                stichtag: settings.stufenwechselDatum,
                onPickDate: () => _pickStufenwechselDatum(settings),
                onOpenAltersgrenzen: _openAltersgrenzen,
              ),
            ),
            Expanded(
              child: _StufenwechselContent(
                sections: sections,
                summaryCount: summaryCount,
                onMemberDetailsTap: _openMemberDetails,
              ),
            ),
          ],
        );
      },
    );

    // Im Tab liegt die Seite ohne eigenes Scaffold direkt im Tab-Rahmen,
    // damit dessen Header-Flaeche hinter dem Header sichtbar bleibt.
    if (!widget.showAppBar) {
      return body;
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Stufenwechsel')),
      body: body,
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

/// Kopf des Stufenwechsels als deckende Karte: Anzahl im Wechselalter und
/// darunter Stufenwechsel-Datum und Altersgrenzen.
class _StufenwechselHeader extends StatelessWidget {
  const _StufenwechselHeader({
    required this.sections,
    required this.summaryCount,
    required this.stichtag,
    required this.onPickDate,
    required this.onOpenAltersgrenzen,
  });

  final List<StufenwechselVorschlagsSection> sections;
  final int summaryCount;

  /// `null`: kein Datum festgelegt, gerechnet wird mit heute.
  final DateTime? stichtag;
  final VoidCallback onPickDate;
  final VoidCallback onOpenAltersgrenzen;

  int get _ueberfaellig => sections.fold<int>(
    0,
    (sum, s) => sum + s.vorschlaege.where((v) => v.istUeberfaellig).length,
  );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: _buildKarte(context),
    );
  }

  Widget _buildKarte(BuildContext context) {
    final theme = Theme.of(context);
    final ueberfaellig = _ueberfaellig;
    final stichtag = this.stichtag;
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(
              children: [
                const Icon(Icons.swap_horiz),
                const SizedBox(width: 10),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '$summaryCount ',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        TextSpan(
                          text: 'im Wechselalter',
                          style: theme.textTheme.titleSmall,
                        ),
                      ],
                    ),
                    key: const Key('stufenwechsel-summary-count'),
                  ),
                ),
                if (ueberfaellig > 0)
                  _Badge(
                    label: '$ueberfaellig überfällig',
                    color: theme.colorScheme.error,
                  ),
              ],
            ),
          ),
          Divider(height: 1, color: theme.colorScheme.outline),
          IntrinsicHeight(
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    key: Key(
                      stichtag == null
                          ? 'stufenwechsel-date-warning'
                          : 'stufenwechsel-date-button',
                    ),
                    onTap: onPickDate,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            stichtag == null
                                ? Icons.warning_amber_rounded
                                : Icons.event,
                            size: 18,
                            color: stichtag == null
                                ? const Color(0xFFC67C00)
                                : null,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: _PillLabel(
                              caption: 'Stufenwechsel',
                              label: stichtag == null
                                  ? 'Datum festlegen'
                                  : _formatDate(stichtag),
                              color: stichtag == null
                                  ? const Color(0xFFC67C00)
                                  : theme.colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                VerticalDivider(width: 1, color: theme.colorScheme.outline),
                InkWell(
                  key: const Key('stufenwechsel-altersgrenzen-button'),
                  onTap: onOpenAltersgrenzen,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.tune, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Altersgrenzen',
                          style: theme.textTheme.labelLarge,
                        ),
                      ],
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

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PillLabel extends StatelessWidget {
  const _PillLabel({required this.label, required this.color, this.caption});

  final String? caption;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final caption = this.caption;
    final text = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.labelLarge?.copyWith(color: color),
    );
    if (caption == null) {
      return text;
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          caption,
          maxLines: 1,
          style: theme.textTheme.labelSmall?.copyWith(
            color: color.withValues(alpha: 0.75),
            height: 1.1,
          ),
        ),
        text,
      ],
    );
  }
}

class _StufenwechselContent extends StatelessWidget {
  const _StufenwechselContent({
    required this.sections,
    required this.summaryCount,
    required this.onMemberDetailsTap,
  });

  final List<StufenwechselVorschlagsSection> sections;
  final int summaryCount;
  final ValueChanged<StufenwechselVorschlag> onMemberDetailsTap;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      children: [
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

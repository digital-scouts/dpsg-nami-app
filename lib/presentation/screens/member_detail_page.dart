import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../../domain/arbeitskontext/arbeitskontext_read_model.dart';
import '../../domain/maps/address_map_location_repository.dart';
import '../../domain/member/member_utils.dart';
import '../../domain/member/mitglied.dart';
import '../../domain/member/pending_person_update.dart';
import '../../domain/member_filters/beitragsart.dart';
import '../../domain/member_filters/usecases/ermittle_beitragsart_im_arbeitskontext_usecase.dart';
import '../../domain/settings/address_settings_repository.dart';
import '../../domain/taetigkeit/klassifiziere_mitglied_usecase.dart';
import '../../domain/taetigkeit/roles.dart';
import '../../domain/taetigkeit/stufe.dart';
import '../../l10n/app_localizations.dart';
import '../../services/geoapify_address_map_service.dart';
import '../../services/map_tile_cache_service.dart';
import '../model/arbeitskontext_model.dart';
import '../model/auth_session_model.dart';
import '../model/member_edit_model.dart';
import '../notifications/app_snackbar.dart';
import '../stufe/stufe_visuals.dart';
import '../widgets/member_basis.dart';
import '../widgets/member_roles_list.dart';
import 'member_edit_page.dart';

class MemberDetailPage extends StatefulWidget {
  const MemberDetailPage({
    super.key,
    required this.mitglied,
    this.addressLocationRepository,
    this.mapService,
    this.addressSettingsRepository,
    this.tileCacheService,
    this.previewTimeout,
  });

  final Mitglied mitglied;
  final AddressMapLocationRepository? addressLocationRepository;
  final GeoapifyAddressMapService? mapService;
  final AddressSettingsRepository? addressSettingsRepository;
  final MapTileCacheService? tileCacheService;
  final Duration? previewTimeout;

  @override
  State<MemberDetailPage> createState() => _MemberDetailPageState();
}

class _MemberDetailPageState extends State<MemberDetailPage> {
  static const ErmittleBeitragsartImArbeitskontextUseCase
  _ermittleBeitragsartImArbeitskontextUseCase =
      ErmittleBeitragsartImArbeitskontextUseCase();
  static const KlassifiziereMitgliedUseCase _klassifiziereMitgliedUseCase =
      KlassifiziereMitgliedUseCase();

  bool _isPreparingEdit = false;

  static const _quickActionSpacing = 8.0;

  Future<void> _openEditPage(
    Mitglied mitglied, {
    PendingPersonUpdate? pendingEntry,
    String? initialNoticeMessage,
    String? resolutionEntryPoint,
  }) async {
    final result = await Navigator.of(context).push<MemberEditSubmitResult>(
      MaterialPageRoute<MemberEditSubmitResult>(
        builder: (_) => MemberEditPage(
          mitglied: mitglied,
          pendingEntry: pendingEntry,
          initialNoticeMessage: initialNoticeMessage,
          resolutionEntryPoint: resolutionEntryPoint,
        ),
      ),
    );
    if (!mounted || result == null) {
      return;
    }

    if (result.suppressNotice) {
      return;
    }

    final t = AppLocalizations.of(context);
    final message = result.success
        ? t.t('member_detail_updated_success')
        : result.resolveMessage(t);
    if (message != null && message.isNotEmpty) {
      final type = switch (result.notice) {
        MemberEditSubmitNotice.success => AppSnackbarType.success,
        MemberEditSubmitNotice.warning => AppSnackbarType.warning,
        MemberEditSubmitNotice.error => AppSnackbarType.error,
      };
      AppSnackbar.show(context, message: message, type: type);
    }
  }

  Future<void> _prepareAndOpenEditPage(Mitglied mitglied) async {
    if (_isPreparingEdit) {
      return;
    }

    final authModel = context.read<AuthSessionModel?>();
    final memberEditModel = context.read<MemberEditModel?>();
    final pendingEntry = memberEditModel?.pendingForMitglied(
      mitglied.mitgliedsnummer,
    );
    if (pendingEntry?.needsResolution ?? false) {
      await _openEditPage(
        pendingEntry!.zielMitglied,
        pendingEntry: pendingEntry,
        initialNoticeMessage: AppLocalizations.of(
          context,
        ).t('member_detail_resolution_required_notice'),
        resolutionEntryPoint: 'detail',
      );
      return;
    }
    final accessToken = authModel?.session?.accessToken;
    if (memberEditModel == null || accessToken == null || accessToken.isEmpty) {
      _showMessage(
        AppLocalizations.of(context).t('member_detail_session_missing'),
        type: AppSnackbarType.warning,
      );
      return;
    }

    setState(() {
      _isPreparingEdit = true;
    });

    try {
      final result = await memberEditModel.prepareForEdit(
        accessToken: accessToken,
        mitglied: mitglied,
        trigger: 'detail_edit',
      );
      if (!mounted) {
        return;
      }
      final refreshedMember = result.member;
      if (!result.success || refreshedMember == null) {
        _showMessage(
          result.resolveMessage(AppLocalizations.of(context)) ??
              AppLocalizations.of(context).t('member_detail_reload_failed'),
          type: AppSnackbarType.warning,
        );
        return;
      }
      await _openEditPage(
        refreshedMember,
        initialNoticeMessage: result.preferDeferredSaveUi
            ? null
            : result.resolveMessage(AppLocalizations.of(context)),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isPreparingEdit = false;
        });
      }
    }
  }

  void _showMessage(
    String message, {
    AppSnackbarType type = AppSnackbarType.info,
  }) {
    AppSnackbar.show(context, message: message, type: type);
  }

  Future<void> _launchQuickPhone(Mitglied mitglied) async {
    final options = mitglied.telefonnummern
        .where((entry) => entry.wert.trim().isNotEmpty)
        .map(
          (entry) => _ContactOption(
            label:
                entry.label ??
                AppLocalizations.of(context).t('member_info_default_phone'),
            value: entry.wert,
          ),
        )
        .toList(growable: false);
    await _launchQuickContact(
      options: options,
      emptyMessage: 'Keine Telefonnummer vorhanden',
      scheme: 'tel',
    );
  }

  Future<void> _launchQuickMail(Mitglied mitglied) async {
    final options = mitglied.emailAdressen
        .where((entry) => entry.wert.trim().isNotEmpty)
        .map(
          (entry) => _ContactOption(
            label:
                entry.label ??
                AppLocalizations.of(context).t('member_info_default_email'),
            value: entry.wert,
          ),
        )
        .toList(growable: false);
    await _launchQuickContact(
      options: options,
      emptyMessage: 'Keine E-Mail-Adresse vorhanden',
      scheme: 'mailto',
    );
  }

  Future<void> _launchQuickContact({
    required List<_ContactOption> options,
    required String emptyMessage,
    required String scheme,
  }) async {
    if (options.isEmpty) {
      _showMessage(emptyMessage, type: AppSnackbarType.info);
      return;
    }

    _ContactOption selected;
    if (options.length == 1) {
      selected = options.first;
    } else {
      final chosen = await showModalBottomSheet<_ContactOption>(
        context: context,
        showDragHandle: true,
        builder: (context) {
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: Text(
                    scheme == 'tel'
                        ? 'Telefonnummer auswählen'
                        : 'E-Mail auswählen',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                for (final option in options)
                  ListTile(
                    leading: Icon(
                      scheme == 'tel' ? Icons.phone_outlined : Icons.email,
                    ),
                    title: Text('${option.label} - ${option.value}'),
                    onTap: () => Navigator.of(context).pop(option),
                  ),
                const SizedBox(height: 6),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Abbrechen'),
                ),
                const SizedBox(height: 10),
              ],
            ),
          );
        },
      );
      if (!mounted || chosen == null) {
        return;
      }
      selected = chosen;
    }

    final uri = Uri(scheme: scheme, path: selected.value).toString();
    if (await canLaunchUrlString(uri)) {
      await launchUrlString(uri);
      return;
    }
    if (!mounted) {
      return;
    }
    _showMessage(
      AppLocalizations.of(context).t('member_info_link_open_failed'),
      type: AppSnackbarType.error,
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentMitglied = _resolveCurrentMitglied(context);
    final memberEditModel = _maybeWatch<MemberEditModel>(context);
    final arbeitskontextModel = _maybeWatch<ArbeitskontextModel>(context);
    final hasPending =
        memberEditModel?.hasPendingForMitglied(
          currentMitglied.mitgliedsnummer,
        ) ??
        false;
    final pendingEntry = memberEditModel?.pendingForMitglied(
      currentMitglied.mitgliedsnummer,
    );
    final needsResolution = pendingEntry?.needsResolution ?? false;
    final isWritable =
        arbeitskontextModel?.istMitgliedSchreibbar(currentMitglied) ?? false;
    final fullName = currentMitglied.fullName.trim().isEmpty
        ? currentMitglied.mitgliedsnummer
        : currentMitglied.fullName;
    final nickname = currentMitglied.fahrtenname?.trim();
    final hasNickname = nickname != null && nickname.isNotEmpty;
    final String title = hasNickname ? nickname : fullName;
    final roleCategory = arbeitskontextModel?.readModel == null
        ? MemberUtils.visualRole(currentMitglied)?.category
        : _klassifiziereMitgliedUseCase.klassifiziere(
            currentMitglied.mitgliedsnummer,
            arbeitskontextModel!.readModel!,
          );
    final activeStufe = MemberUtils.aktiveStufe(currentMitglied);
    final sichtbareRollen = currentMitglied.roles
        .where((role) => !MemberUtils.istMitgliederRolle(role))
        .toList(growable: false);
    final stammNamen = _resolveAnzeigeStaemme(
      arbeitskontextModel?.readModel,
      currentMitglied.mitgliedsnummer,
    );
    final gruppenNamen = _resolveAnzeigeGruppen(
      arbeitskontextModel?.readModel,
      currentMitglied.mitgliedsnummer,
    );
    final mitgliedsBeitragsarten = arbeitskontextModel?.readModel == null
        ? const <String, Beitragsart>{}
        : _ermittleBeitragsartImArbeitskontextUseCase(
            arbeitskontextModel!.readModel!,
          );
    final beitragsart = mitgliedsBeitragsarten[currentMitglied.mitgliedsnummer];
    final t = AppLocalizations.of(context);
    final hasCallablePhone = currentMitglied.telefonnummern.any(
      (entry) => entry.wert.trim().isNotEmpty,
    );
    final hasMailableEmail = currentMitglied.emailAdressen.any(
      (entry) => entry.wert.trim().isNotEmpty,
    );

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          toolbarHeight: 64,
          titleSpacing: 0,
          title: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _MemberDetailTopBar(
              title: title,
              subtitle: hasNickname ? fullName : null,
              stage: activeStufe,
              roleCategory: roleCategory,
              member: currentMitglied,
              hasPending: hasPending,
              needsResolution: needsResolution,
              onBack: () => Navigator.of(context).maybePop(),
            ),
          ),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Daten'),
              Tab(text: 'Rollen'),
              Tab(text: 'Qualifikationen'),
            ],
          ),
        ),
        body: Column(
          children: [
            if (hasPending)
              MaterialBanner(
                content: Text(
                  needsResolution
                      ? t.t('member_detail_pending_resolution_banner')
                      : t.t('member_detail_pending_retry_banner'),
                ),
                actions: <Widget>[
                  if (needsResolution && pendingEntry != null)
                    TextButton(
                      onPressed: () => _openEditPage(
                        pendingEntry.zielMitglied,
                        pendingEntry: pendingEntry,
                        resolutionEntryPoint: 'detail',
                      ),
                      child: Text(t.t('member_detail_resolve_action')),
                    )
                  else
                    const SizedBox.shrink(),
                ],
              ),
            Expanded(
              child: TabBarView(
                children: [
                  MemberDetails(
                    mitglied: currentMitglied,
                    beitragsart: beitragsart,
                    stammNamen: stammNamen,
                    gruppenNamen: gruppenNamen,
                    addressLocationRepository: widget.addressLocationRepository,
                    mapService: widget.mapService,
                    addressSettingsRepository: widget.addressSettingsRepository,
                    tileCacheService: widget.tileCacheService,
                    previewTimeout: widget.previewTimeout,
                    leadingChildren: [
                      Row(
                        children: [
                          Expanded(
                            child: _MemberQuickActionChip(
                              icon: Icons.phone_outlined,
                              label: 'Anrufen',
                              onPressed: hasCallablePhone
                                  ? () => _launchQuickPhone(currentMitglied)
                                  : null,
                            ),
                          ),
                          const SizedBox(width: _quickActionSpacing),
                          Expanded(
                            child: _MemberQuickActionChip(
                              icon: Icons.email_outlined,
                              label: 'E-Mail',
                              onPressed: hasMailableEmail
                                  ? () => _launchQuickMail(currentMitglied)
                                  : null,
                            ),
                          ),
                          const SizedBox(width: _quickActionSpacing),
                          Expanded(
                            child: _MemberQuickActionChip(
                              icon: Icons.edit_outlined,
                              label: 'Bearbeiten',
                              onPressed: isWritable && !_isPreparingEdit
                                  ? () =>
                                        _prepareAndOpenEditPage(currentMitglied)
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  sichtbareRollen.isEmpty
                      ? Center(
                          child: Text(
                            'Keine Rollen',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        )
                      : MemberRolesList(roles: sichtbareRollen),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.workspace_premium_outlined,
                            size: 44,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Qualifikationen',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Geplant (Dummy)',
                            style: Theme.of(context).textTheme.bodyMedium,
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
      ),
    );
  }

  Mitglied _resolveCurrentMitglied(BuildContext context) {
    final arbeitskontextModel = _maybeWatch<ArbeitskontextModel>(context);
    return arbeitskontextModel?.readModel?.findeMitglied(
          widget.mitglied.mitgliedsnummer,
        ) ??
        widget.mitglied;
  }

  T? _maybeWatch<T>(BuildContext context) {
    try {
      return context.watch<T>();
    } catch (_) {
      return null;
    }
  }

  List<String> _resolveAnzeigeStaemme(
    ArbeitskontextReadModel? readModel,
    String mitgliedsnummer,
  ) {
    if (readModel == null) {
      return const <String>[];
    }

    final aktiverLayerName = readModel.arbeitskontext.aktiverLayer.name;
    if (_istStammKontext(readModel)) {
      return aktiverLayerName.trim().isEmpty
          ? const <String>[]
          : <String>[aktiverLayerName];
    }

    final gruppen = _resolveAnzeigeGruppen(readModel, mitgliedsnummer);
    if (gruppen.isNotEmpty) {
      return <String>[aktiverLayerName];
    }

    return aktiverLayerName.trim().isEmpty
        ? const <String>[]
        : <String>[aktiverLayerName];
  }

  List<String> _resolveAnzeigeGruppen(
    ArbeitskontextReadModel? readModel,
    String mitgliedsnummer,
  ) {
    if (readModel == null) {
      return const <String>[];
    }

    final zuordnungen = readModel.findeMitgliedsZuordnungen(mitgliedsnummer);
    final gruppen = <ArbeitskontextGruppe>[];
    for (final zuordnung in zuordnungen) {
      final rollenTyp = zuordnung.rollenTyp?.trim().toLowerCase();
      final istMitgliederRolle =
          rollenTyp != null && rollenTyp.startsWith('group::mitglieder::');
      if (istMitgliederRolle) {
        continue;
      }

      final gruppe = readModel.findeGruppe(zuordnung.gruppenId);
      if (gruppe != null && gruppe.anzeigename.trim().isNotEmpty) {
        gruppen.add(gruppe);
      }
    }

    gruppen.sort((left, right) {
      final stageCompare = _gruppenStufenSortierung(
        left.gruppenTyp,
      ).compareTo(_gruppenStufenSortierung(right.gruppenTyp));
      if (stageCompare != 0) {
        return stageCompare;
      }
      return left.anzeigename.toLowerCase().compareTo(
        right.anzeigename.toLowerCase(),
      );
    });

    final deduplicated = gruppen
        .map((gruppe) => gruppe.anzeigename)
        .toSet()
        .toList(growable: false);
    return deduplicated;
  }

  int _gruppenStufenSortierung(String? gruppenTyp) {
    final normalized = gruppenTyp?.trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) {
      return 99;
    }
    if (normalized.contains('stammgruppebiber')) {
      return 0;
    }
    if (normalized.contains('stammgruppewoelflinge')) {
      return 1;
    }
    if (normalized.contains('stammgruppejungpfadfinder')) {
      return 2;
    }
    if (normalized.contains('stammgruppepfadfinder')) {
      return 3;
    }
    if (normalized.contains('stammgrupperover')) {
      return 4;
    }
    return 99;
  }

  bool _istStammKontext(ArbeitskontextReadModel readModel) {
    for (final gruppe in readModel.gruppen) {
      final gruppenTyp = gruppe.gruppenTyp?.trim().toLowerCase();
      if (gruppenTyp != null && gruppenTyp.startsWith('group::stammgruppe')) {
        return true;
      }
    }

    final layerName = readModel.arbeitskontext.aktiverLayer.name.toLowerCase();
    return layerName.contains('stamm');
  }
}

class _ContactOption {
  const _ContactOption({required this.label, required this.value});

  final String label;
  final String value;
}

class _MemberDetailTopBar extends StatelessWidget {
  const _MemberDetailTopBar({
    required this.title,
    required this.member,
    required this.hasPending,
    required this.needsResolution,
    required this.onBack,
    this.subtitle,
    this.stage,
    this.roleCategory,
  });

  final String title;
  final String? subtitle;
  final Stufe? stage;
  final RoleCategory? roleCategory;
  final Mitglied member;
  final bool hasPending;
  final bool needsResolution;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        IconButton(
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back),
        ),
        _MemberAvatar(member: member),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium,
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
            ],
          ),
        ),
        if (roleCategory == RoleCategory.sonstiges) ...[
          const _SonstigesBadge(),
          const SizedBox(width: 6),
        ] else if (stage != null) ...[
          _StageBadge(stage: stage!),
          const SizedBox(width: 6),
        ],
        if (hasPending)
          _PendingBadge(needsResolution: needsResolution)
        else
          const SizedBox(width: 4),
      ],
    );
  }
}

class _MemberAvatar extends StatelessWidget {
  const _MemberAvatar({required this.member});

  final Mitglied member;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initials = [member.vorname, member.nachname]
        .where((value) => value.trim().isNotEmpty)
        .map((value) => value.trim().substring(0, 1).toUpperCase())
        .take(2)
        .join();

    return CircleAvatar(
      radius: 17,
      backgroundColor: theme.colorScheme.surfaceContainerHighest,
      foregroundColor: theme.colorScheme.onSurface,
      child: Text(
        initials.isEmpty ? '?' : initials,
        style: theme.textTheme.labelLarge,
      ),
    );
  }
}

class _StageBadge extends StatelessWidget {
  const _StageBadge({required this.stage});

  final Stufe stage;

  @override
  Widget build(BuildContext context) {
    final color = StufeVisuals.colorFor(stage);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            StufeVisuals.assetFor(stage),
            width: 14,
            height: 14,
            cacheWidth: 40,
            cacheHeight: 40,
          ),
          const SizedBox(width: 4),
          Text(
            stage.shortDisplayName,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _SonstigesBadge extends StatelessWidget {
  const _SonstigesBadge();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final containerColor = colorScheme.surfaceContainerHighest;
    final borderColor = colorScheme.outlineVariant;
    final contentColor = colorScheme.onSurface;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: containerColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            StufeVisuals.assetFor(Stufe.leitung),
            width: 14,
            height: 14,
            color: contentColor,
            colorBlendMode: BlendMode.srcIn,
            cacheWidth: 40,
            cacheHeight: 40,
          ),
          const SizedBox(width: 4),
          Text(
            'Sonstige',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: contentColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingBadge extends StatelessWidget {
  const _PendingBadge({required this.needsResolution});

  final bool needsResolution;

  @override
  Widget build(BuildContext context) {
    final icon = needsResolution
        ? Icons.warning_amber_rounded
        : Icons.schedule_outlined;
    final color = needsResolution
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.secondary;

    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: 18, color: color),
    );
  }
}

class _MemberQuickActionChip extends StatelessWidget {
  const _MemberQuickActionChip({
    required this.icon,
    required this.label,
    this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = onPressed != null;
    final foregroundColor = enabled
        ? theme.colorScheme.onSurface
        : theme.colorScheme.onSurface.withValues(alpha: 0.38);

    return Material(
      color: enabled
          ? theme.colorScheme.surface
          : theme.colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outline.withValues(alpha: 0.28),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onPressed,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isTight = constraints.maxWidth < 100;
            final isCompact = constraints.maxWidth < 116;
            final horizontalPadding = isTight
                ? 6.0
                : isCompact
                ? 8.0
                : 14.0;
            final iconSize = isTight ? 16.0 : 18.0;
            final spacing = isTight
                ? 3.0
                : isCompact
                ? 4.0
                : 6.0;

            return Padding(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: 9,
              ),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: iconSize, color: foregroundColor),
                      SizedBox(width: spacing),
                      Text(
                        label,
                        maxLines: 1,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: foregroundColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

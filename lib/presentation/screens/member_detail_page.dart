import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../domain/appearance/appearance_catalog.dart';
import '../../domain/arbeitskontext/arbeitskontext_read_model.dart';
import '../../domain/arbeitskontext/teildaten_stand.dart';
import '../../domain/maps/address_map_location_repository.dart';
import '../../domain/member/mitglied.dart';
import '../../domain/member/pending_person_update.dart';
import '../../domain/member_filters/beitragsart.dart';
import '../../domain/member_filters/usecases/ermittle_beitragsart_im_arbeitskontext_usecase.dart';
import '../../domain/settings/address_settings_repository.dart';
import '../../domain/settings/stufen_settings.dart';
import '../../data/settings/shared_prefs_stufen_settings_repository.dart';
import '../../l10n/app_localizations.dart';
import '../../services/geoapify_address_map_service.dart';
import '../../services/map_tile_cache_service.dart';
import '../model/appearance_model.dart';
import '../model/arbeitskontext_model.dart';
import '../model/auth_session_model.dart';
import '../model/member_edit_model.dart';
import '../notifications/app_snackbar.dart';
import '../widgets/app_lesebreite.dart';
import '../widgets/member_detail/member_qualifikationen_tab.dart';
import '../widgets/member_basis.dart';
import '../widgets/member_detail/member_rollen_tab.dart';
import '../navigation/app_router.dart';
import '../widgets/member_detail/member_steckbrief_kopf.dart';
import '../widgets/neuanmeldung_sheet.dart';
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
    this.heuteProvider,
    this.stufenSettingsLoader,
    this.eingebettet = false,
  });

  final Mitglied mitglied;

  /// Rechts neben der Mitgliederliste: ohne Zurueck-Pfeil.
  final bool eingebettet;
  final AddressMapLocationRepository? addressLocationRepository;
  final GeoapifyAddressMapService? mapService;
  final AddressSettingsRepository? addressSettingsRepository;
  final MapTileCacheService? tileCacheService;
  final Duration? previewTimeout;

  /// Liefert das heutige Datum; in Tests fest vorgegeben.
  final DateTime Function()? heuteProvider;

  /// Laedt Altersgrenzen und Stufenwechsel-Stichtag; Standard sind die
  /// gespeicherten Stufen-Einstellungen.
  final Future<StufenSettings> Function()? stufenSettingsLoader;

  @override
  State<MemberDetailPage> createState() => _MemberDetailPageState();
}

class _MemberDetailPageState extends State<MemberDetailPage> {
  static const ErmittleBeitragsartImArbeitskontextUseCase
  _ermittleBeitragsartImArbeitskontextUseCase =
      ErmittleBeitragsartImArbeitskontextUseCase();

  bool _isPreparingEdit = false;
  StufenSettings? _stufenSettings;

  @override
  void initState() {
    super.initState();
    _ladeStufenSettings();
  }

  Future<void> _ladeStufenSettings() async {
    try {
      final loader =
          widget.stufenSettingsLoader ??
          SharedPrefsStufenSettingsRepository().load;
      final settings = await loader();
      if (mounted) {
        setState(() => _stufenSettings = settings);
      }
    } catch (_) {
      // Ohne gespeicherte Einstellungen gelten die Standardgrenzen.
    }
  }

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

    final authModel = context.read<AuthSessionModel?>();
    if (result.wasQueued && (authModel?.requiresInteractiveLogin ?? false)) {
      final t = AppLocalizations.of(context);
      AppSnackbar.show(
        context,
        message: t.t('member_detail_queued_relogin'),
        type: AppSnackbarType.warning,
        action: AppSnackbarAction(
          label: t.t('auth_neuanmeldung_action'),
          onPressed: () =>
              unawaited(neuAnmeldenMitHinweis(context, trigger: 'member_save')),
        ),
      );
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
        pendingEntry: result.pendingEntry,
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

  Future<void> _sendPendingNow(PendingPersonUpdate entry) async {
    final t = AppLocalizations.of(context);
    final memberEditModel = context.read<MemberEditModel?>();
    final accessToken = context.read<AuthSessionModel?>()?.session?.accessToken;
    if (memberEditModel == null || accessToken == null || accessToken.isEmpty) {
      _showMessage(
        t.t('member_detail_session_missing'),
        type: AppSnackbarType.warning,
      );
      return;
    }
    final summary = await memberEditModel.retryPending(
      accessToken: accessToken,
      entryIds: <String>[entry.entryId],
      trigger: 'detail_manual',
    );
    if (!mounted || summary.results.isEmpty) {
      return;
    }
    final result = summary.results.single;
    switch (result.disposition) {
      case PendingPersonUpdateRetryDisposition.success:
        _showMessage(
          t.t('member_detail_send_now_success'),
          type: AppSnackbarType.success,
        );
      case PendingPersonUpdateRetryDisposition.retained:
        _showMessage(
          result.grund == PendingRetryGrund.netz
              ? t.t('member_detail_send_now_offline')
              : t.t('member_detail_send_now_retained'),
          type: AppSnackbarType.warning,
        );
      case PendingPersonUpdateRetryDisposition.needsResolution:
        _showMessage(
          t.t('member_detail_send_now_needs_resolution'),
          type: AppSnackbarType.warning,
        );
      case PendingPersonUpdateRetryDisposition.discarded:
        _showMessage(
          t.t('member_detail_send_now_discarded', {
            'details': result.message ?? '',
          }),
          type: AppSnackbarType.error,
        );
    }
  }

  /// Verwirft sofort und bietet „Rückgängig“ an.
  Future<void> _discardPending(PendingPersonUpdate entry) async {
    final t = AppLocalizations.of(context);
    final memberEditModel = context.read<MemberEditModel?>();
    final verworfen = await memberEditModel?.discardPending(entry.entryId);
    if (!mounted || verworfen == null || memberEditModel == null) {
      return;
    }
    AppSnackbar.show(
      context,
      message: t.t('member_detail_discarded'),
      type: AppSnackbarType.info,
      action: AppSnackbarAction(
        label: t.t('common_undo'),
        onPressed: () => unawaited(memberEditModel.restorePending(verworfen)),
      ),
    );
  }

  void _showMessage(
    String message, {
    AppSnackbarType type = AppSnackbarType.info,
  }) {
    AppSnackbar.show(context, message: message, type: type);
  }

  DateTime _heute() {
    final jetzt = widget.heuteProvider?.call() ?? DateTime.now();
    return DateTime(jetzt.year, jetzt.month, jetzt.day);
  }

  /// Eigenes Supporter-Badge; Badges anderer folgen mit der Synchronisation.
  SupporterBadgeId? _ownBadge(BuildContext context, Mitglied mitglied) {
    final ownId = _maybeWatch<AuthSessionModel>(context)?.profile?.namiId;
    if (ownId == null || mitglied.personId != ownId) {
      return null;
    }
    return _maybeWatch<AppearanceModel>(context)?.badge;
  }

  Future<void> _openHaushaltsmitglied(Mitglied mitglied) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: RouteSettings(
          name: AppRoutes.memberDetail,
          arguments: mitglied.mitgliedsnummer,
        ),
        builder: (_) => MemberDetailPage(
          mitglied: mitglied,
          addressLocationRepository: widget.addressLocationRepository,
          mapService: widget.mapService,
          addressSettingsRepository: widget.addressSettingsRepository,
          tileCacheService: widget.tileCacheService,
          previewTimeout: widget.previewTimeout,
          heuteProvider: widget.heuteProvider,
          stufenSettingsLoader: widget.stufenSettingsLoader,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentMitglied = _resolveCurrentMitglied(context);
    final memberEditModel = _maybeWatch<MemberEditModel>(context);
    final arbeitskontextModel = _maybeWatch<ArbeitskontextModel>(context);
    final readModel = arbeitskontextModel?.readModel;
    final heute = _heute();
    final hasPending =
        memberEditModel?.hasPendingForMitglied(
          currentMitglied.mitgliedsnummer,
        ) ??
        false;
    final pendingEntry = memberEditModel?.pendingForMitglied(
      currentMitglied.mitgliedsnummer,
    );
    final needsResolution = pendingEntry?.needsResolution ?? false;
    final abgelehntHinweis = needsResolution
        ? pendingEntry?.resolutionCase?.hinweis
        : null;
    final retryPaused =
        memberEditModel?.isAutomaticRetryPaused(
          currentMitglied.mitgliedsnummer,
        ) ??
        false;
    final isWritable =
        arbeitskontextModel?.istMitgliedSchreibbar(currentMitglied) ?? false;
    final vollLesbar =
        arbeitskontextModel?.istVollLesbar(currentMitglied) ?? true;
    final stammNamen = _resolveAnzeigeStaemme(
      readModel,
      currentMitglied.mitgliedsnummer,
    );
    final gruppenNamen = _resolveAnzeigeGruppen(
      readModel,
      currentMitglied.mitgliedsnummer,
    );
    final mitgliedsBeitragsarten = readModel == null
        ? const <String, Beitragsart>{}
        : _ermittleBeitragsartImArbeitskontextUseCase(readModel);
    final beitragsart = mitgliedsBeitragsarten[currentMitglied.mitgliedsnummer];
    final haushalt = readModel?.findeHaushalt(currentMitglied) ?? const [];
    final t = AppLocalizations.of(context);
    // Steckbrief-Zeile und Tabs bilden eine gemeinsame Kopfflaeche.
    final kopfFarbe = Theme.of(context).colorScheme.surface;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        body: Column(
          children: [
            AnnotatedRegion<SystemUiOverlayStyle>(
              value:
                  ThemeData.estimateBrightnessForColor(kopfFarbe) ==
                      Brightness.dark
                  ? SystemUiOverlayStyle.light
                  : SystemUiOverlayStyle.dark,
              child: Material(
                color: kopfFarbe,
                // Trennlinie ueber die volle Breite, auch wenn Kopf und Tabs
                // auf breiten Fenstern auf die Lesebreite begrenzt sind.
                shape: Border(
                  bottom: BorderSide(
                    color:
                        TabBarTheme.of(context).dividerColor ??
                        Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  // Leiste vollflaechig, Inhalt buendig mit der Lesebreite.
                  child: Builder(
                    builder: (context) => AppLesebreiteBox(
                      child: Column(
                        children: [
                          MemberSteckbriefKopf(
                            mitglied: currentMitglied,
                            heute: heute,
                            supporterBadge: _ownBadge(context, currentMitglied),
                            onStufenTap: () =>
                                DefaultTabController.of(context).animateTo(1),
                            leading: widget.eingebettet
                                ? null
                                : IconButton(
                                    tooltip: MaterialLocalizations.of(
                                      context,
                                    ).backButtonTooltip,
                                    onPressed: () =>
                                        Navigator.of(context).maybePop(),
                                    icon: const Icon(Icons.arrow_back),
                                  ),
                            actions: [
                              if (hasPending) ...[
                                const SizedBox(width: 8),
                                _PendingBadge(needsResolution: needsResolution),
                              ],
                              IconButton(
                                key: const Key('member-detail-edit'),
                                tooltip: t.t('member_detail_edit_tooltip'),
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: isWritable && !_isPreparingEdit
                                    ? () => _prepareAndOpenEditPage(
                                        currentMitglied,
                                      )
                                    : null,
                              ),
                            ],
                          ),
                          // Tabs so breit wie ihr Text, damit nichts
                          // abgeschnitten wird; bei grosser Schrift scrollbar.
                          TabBar(
                            isScrollable: true,
                            tabAlignment: TabAlignment.center,
                            dividerColor: Colors.transparent,
                            tabs: [
                              Tab(text: t.t('member_detail_tab_daten')),
                              Tab(text: t.t('member_detail_tab_rollen')),
                              Tab(
                                text: t.t('member_detail_tab_qualifikationen'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (hasPending)
              MaterialBanner(
                content: _PendingBannerText(
                  text: abgelehntHinweis != null
                      ? t.t('member_detail_pending_rejected_banner')
                      : needsResolution
                      ? t.t('member_detail_pending_resolution_banner')
                      : retryPaused
                      ? t.t('member_detail_pending_paused_banner')
                      : t.t('member_detail_pending_retry_banner'),
                  hinweis: abgelehntHinweis,
                ),
                actions: <Widget>[
                  if (retryPaused && !needsResolution && pendingEntry != null)
                    TextButton(
                      key: const Key('member-detail-discard-pending'),
                      style: TextButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.error,
                      ),
                      onPressed: memberEditModel?.isBusy ?? true
                          ? null
                          : () => _discardPending(pendingEntry),
                      child: Text(t.t('member_detail_discard_action')),
                    ),
                  if (needsResolution && pendingEntry != null)
                    TextButton(
                      onPressed: () => _openEditPage(
                        pendingEntry.zielMitglied,
                        pendingEntry: pendingEntry,
                        resolutionEntryPoint: 'detail',
                      ),
                      child: Text(t.t('member_detail_resolve_action')),
                    )
                  else if (pendingEntry != null)
                    TextButton(
                      key: const Key('member-detail-send-now'),
                      onPressed: memberEditModel?.isBusy ?? true
                          ? null
                          : () => _sendPendingNow(pendingEntry),
                      child: Text(t.t('member_detail_send_now_action')),
                    )
                  else
                    const SizedBox.shrink(),
                ],
              ),
            Expanded(
              child: TabBarView(
                children: [
                  _TabBleibtErhalten(
                    child: MemberDetails(
                      mitglied: currentMitglied,
                      heute: heute,
                      beitragsart: beitragsart,
                      stammNamen: stammNamen,
                      gruppenNamen: gruppenNamen,
                      haushalt: haushalt,
                      onHaushaltTap: _openHaushaltsmitglied,
                      addressLocationRepository:
                          widget.addressLocationRepository,
                      mapService: widget.mapService,
                      addressSettingsRepository:
                          widget.addressSettingsRepository,
                      tileCacheService: widget.tileCacheService,
                      previewTimeout: widget.previewTimeout,
                    ),
                  ),
                  _TabBleibtErhalten(
                    child: MemberRollenTab(
                      mitglied: currentMitglied,
                      heute: heute,
                      stufenSettings: _stufenSettings,
                      aktiverLayerName:
                          readModel?.arbeitskontext.aktiverLayer.name,
                      rollenNichtLesbar: !vollLesbar,
                    ),
                  ),
                  _TabBleibtErhalten(
                    child: MemberQualifikationenTab(
                      mitglied: currentMitglied,
                      heute: heute,
                      vollLesbar: vollLesbar,
                      efzStand: readModel?.efzStand ?? TeildatenStand.unbekannt,
                      efzEinsichtnahmen:
                          readModel?.findeEfzEinsichtnahmen(
                            currentMitglied.personId,
                          ) ??
                          const [],
                      qualifikationenStand:
                          readModel?.qualifikationenStand ??
                          TeildatenStand.unbekannt,
                      qualifikationen:
                          readModel?.findeQualifikationen(
                            currentMitglied.personId,
                          ) ??
                          const [],
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

/// Bannertext; bei einer Ablehnung durch Hitobito mit dem Grund darunter.
class _PendingBannerText extends StatelessWidget {
  const _PendingBannerText({required this.text, this.hinweis});

  final String text;
  final String? hinweis;

  @override
  Widget build(BuildContext context) {
    final hinweis = this.hinweis;
    if (hinweis == null || hinweis.trim().isEmpty) {
      return Text(text);
    }
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(text),
        const SizedBox(height: 8),
        Container(
          key: const Key('member-detail-rejected-reason'),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '„${hinweis.trim()}“',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
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

/// Haelt den Inhalt eines Tabs beim Wechsel am Leben, damit Karte, Listen
/// und Scrollposition nicht neu aufgebaut werden.
class _TabBleibtErhalten extends StatefulWidget {
  const _TabBleibtErhalten({required this.child});

  final Widget child;

  @override
  State<_TabBleibtErhalten> createState() => _TabBleibtErhaltenState();
}

class _TabBleibtErhaltenState extends State<_TabBleibtErhalten>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

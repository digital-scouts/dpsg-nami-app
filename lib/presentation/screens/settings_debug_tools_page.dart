import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nami/data/maps/shared_prefs_address_map_location_repository.dart';
import 'package:nami/domain/appearance/support_access.dart';
import 'package:nami/services/supporter/supporter_env.dart';
import 'package:nami/domain/auth/auth_state.dart';
import 'package:nami/domain/maps/stamm_map_marker_repository.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/main.dart' show navigatorKey;
import 'package:nami/presentation/model/app_settings_model.dart';
import 'package:nami/presentation/model/arbeitskontext_model.dart';
import 'package:nami/presentation/model/auth_session_model.dart';
import 'package:nami/presentation/model/member_edit_model.dart';
import 'package:nami/presentation/notifications/app_snackbar.dart';
import 'package:nami/presentation/notifications/feedback_prompt_dialog.dart';
import 'package:nami/presentation/screens/changelog_page.dart';
import 'package:nami/presentation/screens/log_viewer_page.dart';
import 'package:provider/provider.dart';
import 'package:wiredash/wiredash.dart';

import '../../services/app_runtime_controller.dart';
import '../../services/hitobito_auth_config_controller.dart';
import '../../services/hitobito_groups_service.dart';
import '../../services/hitobito_oauth_service.dart';
import '../../services/hitobito_traffic_log_service.dart';
import '../../services/logger_service.dart';
import '../../services/map_tile_cache_service.dart';
import '../../services/stamm_map_sync_service.dart';

class DebugToolsPage extends StatefulWidget {
  const DebugToolsPage({
    super.key,
    this.oauthServiceFactory,
    this.onResetAllData,
    this.stammMapRepository,
  });

  final HitobitoOauthService Function(
    HitobitoAuthConfigController controller,
    LoggerService logger,
  )?
  oauthServiceFactory;
  final Future<void> Function()? onResetAllData;
  final StammMapMarkerRepository? stammMapRepository;

  @override
  State<DebugToolsPage> createState() => _DebugToolsPageState();
}

class _DebugToolsPageState extends State<DebugToolsPage> {
  static final DateFormat _pendingDateFormat = DateFormat('dd.MM.yyyy, HH:mm');
  final ScrollController _scrollController = ScrollController();
  bool _isRefreshingStammMarkers = false;
  bool _isDiagnosingGroups = false;
  final HitobitoTrafficLogService _fallbackHitobitoTrafficLogService =
      HitobitoTrafficLogService(
        logsDirectoryProvider: () async => Directory.systemTemp,
      );
  int _logRevision = 0;

  Future<void> _trackDebugAction(
    LoggerService logger,
    String action, {
    Map<String, Object?> properties = const <String, Object?>{},
  }) {
    return logger.trackAndLog('debug_tools', 'debug_action', {
      'action': action,
      ...properties,
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _showSnackbar(
    String message, {
    AppSnackbarType type = AppSnackbarType.info,
  }) {
    if (!mounted) {
      return;
    }
    AppSnackbar.show(context, message: message, type: type);
  }

  Future<void> _openOauthOverrideDialog(
    BuildContext context,
    LoggerService logger,
  ) async {
    await _trackDebugAction(logger, 'oauth_override_open');
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          _OauthOverrideDialog(oauthServiceFactory: widget.oauthServiceFactory),
    );
  }

  Future<void> _confirmAndResetApp(
    BuildContext context,
    LoggerService logger,
  ) async {
    final t = AppLocalizations.of(context);
    await _trackDebugAction(logger, 'reset_app_prompt_open');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(t.t('debug_reset_confirm_title')),
          content: Text(t.t('debug_reset_confirm_body')),
          actions: [
            TextButton(
              onPressed: () async {
                await _trackDebugAction(logger, 'reset_app_prompt_cancel');
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop(false);
                }
              },
              child: Text(t.t('ignore')),
            ),
            FilledButton(
              onPressed: () async {
                await _trackDebugAction(logger, 'reset_app_prompt_confirm');
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop(true);
                }
              },
              child: Text(t.t('debug_reset_confirm_action')),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    final handler =
        widget.onResetAllData ?? context.read<AppRuntimeController>().resetApp;
    await handler();
  }

  List<String> _buildSyncStatusLines(
    AppLocalizations t,
    DataSyncStatus status,
  ) {
    return [
      t.t('debug_sync_last_success', {
        'value': _formatSyncDateTime(t, status.lastSuccessfulSyncAt),
      }),
      t.t('debug_sync_last_attempt', {
        'value': _formatLastSyncAttempt(t, status),
      }),
      t.t('debug_sync_next', {'value': _formatNextSync(t, status)}),
    ];
  }

  String _formatLastSyncAttempt(AppLocalizations t, DataSyncStatus status) {
    final attemptedAt = status.lastAttemptAt;
    final result = status.lastAttemptResult;
    if (attemptedAt == null || result == null) {
      return t.t('debug_sync_status_never');
    }
    final time = _formatSyncDateTime(t, attemptedAt);
    if (result == SyncAttemptResult.success) {
      return t.t('debug_sync_attempt_success', {'time': time});
    }
    return t.t('debug_sync_attempt_failed', {
      'time': time,
      'reason': _formatSyncAttemptReason(t, result),
    });
  }

  String _formatSyncAttemptReason(
    AppLocalizations t,
    SyncAttemptResult result,
  ) {
    return switch (result) {
      SyncAttemptResult.success => '',
      SyncAttemptResult.wifiOnly => t.t('debug_sync_reason_wifi'),
      SyncAttemptResult.loginRequired => t.t('debug_sync_reason_login'),
      SyncAttemptResult.networkError => t.t('debug_sync_reason_network'),
      SyncAttemptResult.serverError => t.t('debug_sync_reason_server'),
      SyncAttemptResult.unknownError => t.t('debug_sync_reason_unknown'),
    };
  }

  String _formatNextSync(AppLocalizations t, DataSyncStatus status) {
    return switch (status.nextSyncKind) {
      NextSyncDisplayKind.whenWifiAvailable => t.t('debug_sync_next_wifi'),
      NextSyncDisplayKind.loginRequired => t.t('debug_sync_next_login'),
      NextSyncDisplayKind.atTime => _formatSyncDateTime(t, status.nextSyncAt),
      null => t.t('debug_sync_status_never'),
    };
  }

  String _formatSyncDateTime(AppLocalizations t, DateTime? value) {
    if (value == null) {
      return t.t('debug_sync_status_never');
    }
    final locale = Localizations.localeOf(context).toLanguageTag();
    return DateFormat('dd.MM.yyyy, HH:mm', locale).format(value);
  }

  Future<void> _refreshStammMarkers(LoggerService logger) async {
    final repository =
        widget.stammMapRepository ?? StammMapSyncService(logger: logger);
    await _trackDebugAction(logger, 'refresh_stamm_markers');
    setState(() {
      _isRefreshingStammMarkers = true;
    });

    try {
      final snapshot = await repository.forceRefresh();
      if (!mounted) {
        return;
      }
      _showSnackbar(
        AppLocalizations.of(
          context,
        ).t('debug_map_refresh_success', {'count': snapshot.markers.length}),
        type: AppSnackbarType.success,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showSnackbar(
        AppLocalizations.of(context).t('debug_map_refresh_failed'),
        type: AppSnackbarType.error,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshingStammMarkers = false;
        });
      }
    }
  }

  Future<void> _openAllExternalNotifications(LoggerService logger) async {
    await _trackDebugAction(logger, 'open_external_notifications_all');
    if (!mounted) {
      return;
    }
    Navigator.pushNamed(
      context,
      '/notifications',
      arguments: <String, dynamic>{'showAllAcknowledged': true},
    );
  }

  Future<void> _deleteMapCache(
    LoggerService logger,
    MapTileCacheService mapTileCacheService,
  ) async {
    await _trackDebugAction(logger, 'delete_map_cache');
    await mapTileCacheService.deleteRoot();
    if (!mounted) {
      return;
    }

    setState(() {});
    _showSnackbar(
      AppLocalizations.of(context).t('debug_map_deleted'),
      type: AppSnackbarType.success,
    );
  }

  Future<void> _deleteAddressCoordinateCache(LoggerService logger) async {
    await _trackDebugAction(logger, 'delete_address_coordinate_cache');
    await SharedPrefsAddressMapLocationRepository().clearAll();
    if (!mounted) {
      return;
    }

    setState(() {});
    _showSnackbar(
      AppLocalizations.of(context).t('debug_map_address_cache_deleted'),
      type: AppSnackbarType.success,
    );
  }

  MapTileCacheService _resolveMapTileCacheService(LoggerService logger) {
    try {
      return context.read<MapTileCacheService>();
    } catch (_) {
      return MapTileCacheService(logger: logger);
    }
  }

  HitobitoTrafficLogService _resolveHitobitoTrafficLogService() {
    try {
      return context.read<HitobitoTrafficLogService>();
    } catch (_) {
      return _fallbackHitobitoTrafficLogService;
    }
  }

  HitobitoGroupsService _resolveHitobitoGroupsService(
    HitobitoAuthConfigController configController,
    HitobitoTrafficLogService trafficLogService,
    LoggerService logger,
  ) {
    try {
      return context.read<HitobitoGroupsService>();
    } catch (_) {
      return HitobitoGroupsService(
        config: configController.config,
        trafficLogService: trafficLogService,
        logger: logger,
      );
    }
  }

  Future<int> _loadCachedAddressCount() async {
    final repository = SharedPrefsAddressMapLocationRepository();
    return repository.countEntries();
  }

  Future<void> _showGroupsDiagnosisDialog(
    HitobitoGroupsDiagnosisResult result,
  ) async {
    if (!mounted) {
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Gruppen-Diagnose'),
        content: SizedBox(
          width: double.maxFinite,
          child: result.found
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${result.brokenGroups.length} von '
                      '${result.probedGroupCount} Gruppen mit ungültigem '
                      'zip_code gefunden:',
                    ),
                    const SizedBox(height: 12),
                    Flexible(
                      child: ListView(
                        shrinkWrap: true,
                        children: result.brokenGroups
                            .map(
                              (group) => ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.error_outline),
                                title: Text(
                                  '#${group.groupId} '
                                  '${group.groupName ?? 'unbekannt'}',
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ],
                )
              : Text(
                  'Kein Serialisierungsfehler unter '
                  '${result.probedGroupCount} Gruppen reproduzierbar.',
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Schliessen'),
          ),
        ],
      ),
    );
  }

  Future<void> _retryPendingPersonUpdates(
    MemberEditModel memberEditModel,
    AuthSessionModel authModel, {
    String? entryId,
  }) async {
    final accessToken = authModel.session?.accessToken;
    if (accessToken == null || accessToken.isEmpty) {
      if (!mounted) {
        return;
      }
      _showSnackbar(
        AppLocalizations.of(context).t('debug_retry_missing_token'),
        type: AppSnackbarType.warning,
      );
      return;
    }

    final summary = await memberEditModel.retryPending(
      accessToken: accessToken,
      entryIds: entryId == null ? null : <String>[entryId],
      trigger: 'manual_debug',
    );
    if (!mounted) {
      return;
    }
    _showSnackbar(
      AppLocalizations.of(context).t('debug_retry_summary', {
        'successCount': summary.successCount,
        'discardedCount': summary.discardedCount,
        'retainedCount': summary.retainedCount,
      }),
      type: AppSnackbarType.info,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final logger = Provider.of<LoggerService>(context, listen: false);
    final hitobitoTrafficLogService = _resolveHitobitoTrafficLogService();
    final mapTileCacheService = _resolveMapTileCacheService(logger);
    final authModel = context.watch<AuthSessionModel>();
    final arbeitskontextModel = context.read<ArbeitskontextModel>();
    final memberEditModel = context.watch<MemberEditModel?>();
    final configController = context.watch<HitobitoAuthConfigController>();
    final appSettings = context.watch<AppSettingsModel?>();
    return Scaffold(
      appBar: AppBar(title: Text(t.t('debug_title'))),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colorScheme.surfaceContainerHighest.withValues(alpha: 0.42),
              colorScheme.surface,
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: Scrollbar(
            controller: _scrollController,
            thumbVisibility: true,
            child: ListView(
              controller: _scrollController,
              children: [
                _DebugSectionCard(
                  icon: Icons.article_outlined,
                  title: t.t('debug_logs_section_title'),
                  subtitle: t.t('debug_logs_section_subtitle'),
                  child: _LogEinstiege(
                    key: ValueKey(_logRevision),
                    quellen: [
                      LogQuelle.app(logger),
                      LogQuelle.traffic(hitobitoTrafficLogService),
                    ],
                    onOeffnen: (quelle) async {
                      await _trackDebugAction(
                        logger,
                        'view_logs',
                        properties: <String, Object?>{
                          'source': quelle.dateiKennung,
                        },
                      );
                      if (!context.mounted) {
                        return;
                      }
                      await Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          settings: const RouteSettings(
                            name: '/settings/debug/logs',
                          ),
                          builder: (_) => LogViewerPage(
                            quelle: quelle,
                            onAktion: (aktion) => _trackDebugAction(
                              logger,
                              aktion,
                              properties: <String, Object?>{
                                'source': quelle.dateiKennung,
                              },
                            ),
                          ),
                        ),
                      );
                      if (mounted) {
                        setState(() => _logRevision++);
                      }
                    },
                  ),
                ),
                const SizedBox(height: 16),
                _DebugSectionCard(
                  icon: Icons.schedule_send_outlined,
                  title: t.t('debug_pending_section_title'),
                  subtitle: t.t('debug_pending_section_subtitle'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (memberEditModel == null)
                        Text(
                          t.t('debug_pending_unavailable'),
                          style: theme.textTheme.bodyMedium,
                        )
                      else if (memberEditModel.pendingUpdates.isEmpty)
                        Text(
                          t.t('debug_pending_empty'),
                          style: theme.textTheme.bodyMedium,
                        )
                      else ...[
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton.icon(
                            key: const Key(
                              'debug_retry_all_pending_person_updates_button',
                            ),
                            onPressed: memberEditModel.isBusy
                                ? null
                                : () => _retryPendingPersonUpdates(
                                    memberEditModel,
                                    authModel,
                                  ),
                            icon: memberEditModel.isBusy
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.refresh),
                            label: Text(t.t('debug_pending_retry_all')),
                          ),
                        ),
                        const SizedBox(height: 12),
                        for (final entry in memberEditModel.pendingUpdates)
                          Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              title: Text(entry.displayName),
                              subtitle: Text(
                                t.t('debug_pending_entry_summary', {
                                  'memberNumber': entry.mitgliedsnummer,
                                  'queuedAt': _pendingDateFormat.format(
                                    entry.queuedAt,
                                  ),
                                  'attemptCount': entry.attemptCount,
                                }),
                              ),
                              isThreeLine: true,
                              trailing: IconButton(
                                tooltip: t.t('debug_pending_retry_single'),
                                onPressed: memberEditModel.isBusy
                                    ? null
                                    : () => _retryPendingPersonUpdates(
                                        memberEditModel,
                                        authModel,
                                        entryId: entry.entryId,
                                      ),
                                icon: const Icon(Icons.refresh_outlined),
                              ),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _DebugSectionCard(
                  icon: Icons.feedback_outlined,
                  title: t.t('debug_feedback_section_title'),
                  subtitle: t.t('debug_feedback_section_subtitle'),
                  child: _DebugButtonGroup(
                    children: [
                      _DebugActionButton(
                        icon: Icons.forum_outlined,
                        label: t.t('debug_feedback_prompt'),
                        onPressed: () async {
                          await _trackDebugAction(
                            logger,
                            'open_feedback_prompt',
                          );
                          final ctx = navigatorKey.currentContext;
                          if (ctx != null) {
                            await runFeedbackPromptFlow(
                              ctx,
                              logger: logger,
                              trigger: 'debug',
                            );
                          } else {
                            _showSnackbar(
                              t.t('debug_feedback_missing_root'),
                              type: AppSnackbarType.error,
                            );
                          }
                        },
                      ),
                      _DebugActionButton(
                        icon: Icons.feedback_outlined,
                        label: t.t('debug_feedback_send'),
                        onPressed: () async {
                          await _trackDebugAction(logger, 'open_feedback');
                          final ctx = navigatorKey.currentContext;
                          if (ctx != null) {
                            Wiredash.of(ctx).show(inheritMaterialTheme: true);
                          } else {
                            _showSnackbar(
                              t.t('debug_feedback_missing_root'),
                              type: AppSnackbarType.error,
                            );
                          }
                        },
                      ),
                      _DebugActionButton(
                        icon: Icons.star_outline,
                        label: t.t('debug_feedback_rate'),
                        onPressed: () async {
                          await _trackDebugAction(logger, 'open_app_rating');
                          final ctx = navigatorKey.currentContext;
                          if (ctx != null) {
                            Wiredash.of(ctx).showPromoterSurvey(force: true);
                          } else {
                            _showSnackbar(
                              t.t('debug_feedback_missing_root'),
                              type: AppSnackbarType.error,
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _DebugSectionCard(
                  icon: Icons.sync_alt_outlined,
                  title: t.t('debug_sync_section_title'),
                  subtitle: t.t('debug_sync_section_subtitle'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ..._buildSyncStatusLines(t, authModel.dataSyncStatus).map(
                        (line) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                            line,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _DebugButtonGroup(
                        children: [
                          _DebugActionButton(
                            icon: Icons.refresh_outlined,
                            label: t.t('debug_sync_now'),
                            onPressed: authModel.isSyncingHitobitoData
                                ? null
                                : () async {
                                    await _trackDebugAction(
                                      logger,
                                      'sync_data_now',
                                    );
                                    await authModel.syncHitobitoData(
                                      syncMembers: (accessToken) =>
                                          arbeitskontextModel.syncVollstaendig(
                                            session: authModel.session,
                                            profile: authModel.profile,
                                          ),
                                      force: true,
                                      trigger: 'debug_tools',
                                    );

                                    if (!context.mounted) {
                                      return;
                                    }

                                    final messenger = ScaffoldMessenger.of(
                                      context,
                                    );
                                    final message = switch ((
                                      authModel
                                          .isRemoteAccessBlockedByNetworkPolicy,
                                      authModel.state ==
                                          AuthState.reloginRequired,
                                      authModel.errorMessage?.isNotEmpty ==
                                          true,
                                    )) {
                                      (true, _, _) =>
                                        authModel.remoteAccessIssueMessage ??
                                            authModel.errorMessage ??
                                            t.t('debug_sync_network_blocked'),
                                      (_, true, _) => t.t(
                                        'debug_sync_relogin_required',
                                      ),
                                      (_, _, true) => t.t(
                                        'debug_sync_partial_failure',
                                      ),
                                      _ => t.t('debug_sync_success'),
                                    };
                                    final type = switch ((
                                      authModel
                                          .isRemoteAccessBlockedByNetworkPolicy,
                                      authModel.state ==
                                          AuthState.reloginRequired,
                                      authModel.errorMessage?.isNotEmpty ==
                                          true,
                                    )) {
                                      (true, _, _) => AppSnackbarType.warning,
                                      (_, true, _) => AppSnackbarType.warning,
                                      (_, _, true) => AppSnackbarType.warning,
                                      _ => AppSnackbarType.success,
                                    };
                                    AppSnackbar.showOnMessenger(
                                      messenger: messenger,
                                      context: context,
                                      message: message,
                                      type: type,
                                    );
                                  },
                          ),
                          _DebugActionButton(
                            icon: Icons.visibility_outlined,
                            label: t.t('debug_sync_view_changes'),
                            onPressed: () async {
                              await _trackDebugAction(
                                logger,
                                'view_data_changes',
                              );
                              _showSnackbar(
                                t.t('debug_sync_changes_not_implemented'),
                                type: AppSnackbarType.info,
                              );
                            },
                          ),
                          _DebugActionButton(
                            icon: Icons.bug_report_outlined,
                            label: 'Fehlerhafte Gruppe suchen (zip_code)',
                            onPressed: _isDiagnosingGroups
                                ? null
                                : () async {
                                    final accessToken =
                                        authModel.session?.accessToken;
                                    if (accessToken == null ||
                                        accessToken.isEmpty) {
                                      _showSnackbar(
                                        t.t('debug_retry_missing_token'),
                                        type: AppSnackbarType.warning,
                                      );
                                      return;
                                    }

                                    setState(() => _isDiagnosingGroups = true);
                                    await _trackDebugAction(
                                      logger,
                                      'groups_diagnose_broken_group',
                                    );

                                    final groupsService =
                                        _resolveHitobitoGroupsService(
                                          configController,
                                          hitobitoTrafficLogService,
                                          logger,
                                        );
                                    try {
                                      final result = await groupsService
                                          .diagnoseBrokenGroup(accessToken);
                                      if (!mounted) {
                                        return;
                                      }
                                      await _showGroupsDiagnosisDialog(result);
                                    } catch (error) {
                                      if (!mounted) {
                                        return;
                                      }
                                      _showSnackbar(
                                        'Diagnose fehlgeschlagen: $error',
                                        type: AppSnackbarType.warning,
                                      );
                                    } finally {
                                      if (mounted) {
                                        setState(
                                          () => _isDiagnosingGroups = false,
                                        );
                                      }
                                    }
                                  },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _DebugSectionCard(
                  icon: Icons.map_outlined,
                  title: t.t('debug_map_section_title'),
                  subtitle: t.t('debug_map_section_subtitle'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: FutureBuilder<double>(
                          future: mapTileCacheService.realSizeKiB(),
                          builder: (context, snapshot) {
                            final text = switch (snapshot.connectionState) {
                              ConnectionState.done when snapshot.hasData =>
                                _formatMapCacheSize(snapshot.data!),
                              ConnectionState.done => t.t(
                                'debug_map_size_unavailable',
                              ),
                              _ => t.t('debug_map_size_loading'),
                            };
                            return Row(
                              children: [
                                Icon(
                                  Icons.layers_outlined,
                                  color: colorScheme.primary,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        t.t('debug_map_offline_maps'),
                                        style: theme.textTheme.titleMedium,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        text,
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              color:
                                                  colorScheme.onSurfaceVariant,
                                            ),
                                      ),
                                      const SizedBox(height: 10),
                                      FutureBuilder<int>(
                                        future: _loadCachedAddressCount(),
                                        builder: (context, countSnapshot) {
                                          final countText = switch (countSnapshot
                                              .connectionState) {
                                            ConnectionState.done
                                                when countSnapshot.hasData =>
                                              t.t(
                                                'debug_map_cached_addresses_count',
                                                {'count': countSnapshot.data!},
                                              ),
                                            ConnectionState.done => t.t(
                                              'debug_map_cached_addresses_unavailable',
                                            ),
                                            _ => t.t(
                                              'debug_map_cached_addresses_loading',
                                            ),
                                          };
                                          return Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                t.t(
                                                  'debug_map_cached_addresses_label',
                                                ),
                                                style:
                                                    theme.textTheme.titleMedium,
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                countText,
                                                style: theme
                                                    .textTheme
                                                    .bodyMedium
                                                    ?.copyWith(
                                                      color: colorScheme
                                                          .onSurfaceVariant,
                                                    ),
                                              ),
                                            ],
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      _DebugActionButton(
                        icon: Icons.travel_explore_outlined,
                        label: _isRefreshingStammMarkers
                            ? t.t('debug_map_refresh_markers_loading')
                            : t.t('debug_map_refresh_markers'),
                        buttonKey: const Key(
                          'debug_refresh_stamm_markers_button',
                        ),
                        onPressed: _isRefreshingStammMarkers
                            ? null
                            : () => _refreshStammMarkers(logger),
                      ),
                      const SizedBox(height: 10),
                      _DebugActionButton(
                        icon: Icons.delete_sweep_outlined,
                        label: t.t('debug_map_delete_cache'),
                        isDestructive: true,
                        buttonKey: const Key('debug_delete_map_cache_button'),
                        onPressed: () =>
                            _deleteMapCache(logger, mapTileCacheService),
                      ),
                      const SizedBox(height: 10),
                      _DebugActionButton(
                        icon: Icons.location_off_outlined,
                        label: t.t('debug_map_delete_address_cache'),
                        isDestructive: true,
                        buttonKey: const Key(
                          'debug_delete_address_cache_button',
                        ),
                        onPressed: () => _deleteAddressCoordinateCache(logger),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _DebugSectionCard(
                  icon: Icons.verified_user_outlined,
                  title: t.t('debug_oauth_section_title'),
                  subtitle: t.t('debug_oauth_section_subtitle'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: configController.hasOverride
                              ? colorScheme.tertiaryContainer
                              : colorScheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          configController.hasOverride
                              ? t.t('debug_oauth_override_active', {
                                  'clientId':
                                      configController.effectiveClientId,
                                })
                              : t.t('debug_oauth_env_active'),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: configController.hasOverride
                                ? colorScheme.onTertiaryContainer
                                : colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _DebugActionButton(
                        icon: Icons.verified_user_outlined,
                        label: t.t('debug_oauth_check'),
                        buttonKey: const Key('debug_oauth_override_button'),
                        onPressed: authModel.state == AuthState.authenticating
                            ? null
                            : () => _openOauthOverrideDialog(context, logger),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _DebugSectionCard(
                  icon: Icons.library_books_outlined,
                  title: t.t('debug_references_section_title'),
                  subtitle: t.t('debug_references_section_subtitle'),
                  child: _DebugButtonGroup(
                    children: [
                      _DebugActionButton(
                        icon: Icons.list_alt_outlined,
                        label: t.t('debug_references_show_changelog'),
                        onPressed: () async {
                          await _trackDebugAction(logger, 'open_changelog');
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              settings: const RouteSettings(
                                name: '/settings/debug/changelog',
                              ),
                              builder: (_) => const ChangelogPage(),
                            ),
                          );
                        },
                      ),
                      _DebugActionButton(
                        icon: Icons.notifications_outlined,
                        label: t.t('debug_references_show_notifications'),
                        onPressed: () async {
                          await _trackDebugAction(logger, 'open_notifications');
                          if (!context.mounted) {
                            return;
                          }
                          Navigator.pushNamed(context, '/notifications');
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _DebugSectionCard(
                  icon: Icons.campaign_outlined,
                  title: t.t('debug_external_notifications_section_title'),
                  subtitle: t.t(
                    'debug_external_notifications_section_subtitle',
                  ),
                  child: _DebugButtonGroup(
                    children: [
                      _DebugActionButton(
                        icon: Icons.visibility_outlined,
                        label: t.t('debug_external_notifications_show_all'),
                        onPressed: () => _openAllExternalNotifications(logger),
                      ),
                    ],
                  ),
                ),
                if (appSettings != null) ...[
                  const SizedBox(height: 16),
                  _DebugSectionCard(
                    icon: Icons.workspace_premium_outlined,
                    title: t.t('debug_supporter_section_title'),
                    subtitle: t.t('debug_supporter_section_subtitle'),
                    child: Column(
                      key: const Key('debug-supporter-test-zugang'),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.t('debug_supporter_switch'),
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          t.t('debug_supporter_switch_hint'),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        // Mit Store-Anbindung heisst „Keiner“: der Store
                        // entscheidet; alles andere ueberdeckt ihn.
                        if (SupporterEnv.storeEnabled)
                          Text(
                            t.t('debug_supporter_store_hint'),
                            key: const Key('debug-supporter-store-hinweis'),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final zugang in SupporterTestZugang.values)
                              ChoiceChip(
                                key: Key(
                                  'debug-supporter-zugang-${zugang.name}',
                                ),
                                label: Text(
                                  zugang == SupporterTestZugang.keiner &&
                                          SupporterEnv.storeEnabled
                                      ? t.t('debug_supporter_zugang_store')
                                      : t.t(
                                          'debug_supporter_zugang_${zugang.name}',
                                        ),
                                ),
                                selected:
                                    appSettings.supporterTestZugang == zugang,
                                onSelected: (_) =>
                                    appSettings.setSupporterTestZugang(zugang),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                _DebugSectionCard(
                  icon: Icons.warning_amber_rounded,
                  title: t.t('debug_reset_title'),
                  subtitle: t.t('debug_reset_subtitle'),
                  tone: _DebugSectionTone.danger,
                  child: _DebugActionButton(
                    icon: Icons.delete_forever_outlined,
                    label: t.t('debug_reset_action'),
                    isDestructive: true,
                    buttonKey: const Key('debug_reset_app_button'),
                    onPressed: () => _confirmAndResetApp(context, logger),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatMapCacheSize(double sizeKiB) {
    final t = AppLocalizations.of(context);
    if (sizeKiB <= 0) {
      return t.t('debug_map_size_empty');
    }
    if (sizeKiB < 1024) {
      return t.t('debug_map_size_kib', {'size': sizeKiB.toStringAsFixed(0)});
    }

    final sizeMb = sizeKiB / 1024;
    if (sizeMb < 1024) {
      return t.t('debug_map_size_mib', {'size': sizeMb.toStringAsFixed(2)});
    }

    final sizeGb = sizeMb / 1024;
    return t.t('debug_map_size_gib', {'size': sizeGb.toStringAsFixed(2)});
  }
}

enum _DebugSectionTone { normal, danger }

class _DebugSectionCard extends StatelessWidget {
  const _DebugSectionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
    this.tone = _DebugSectionTone.normal,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;
  final _DebugSectionTone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDanger = tone == _DebugSectionTone.danger;
    final accent = isDanger ? colorScheme.error : colorScheme.primary;
    final containerColor = isDanger
        ? colorScheme.errorContainer.withValues(alpha: 0.45)
        : colorScheme.surfaceContainerLow;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: containerColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDanger
              ? colorScheme.error.withValues(alpha: 0.28)
              : colorScheme.outlineVariant,
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      // Eigene Material-Ebene ueber dem Hintergrund, sonst verdeckt dieser
      // die Ink-Effekte der ListTiles im Inhalt.
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: accent),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            child,
          ],
        ),
      ),
    );
  }
}

class _DebugButtonGroup extends StatelessWidget {
  const _DebugButtonGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          children[i],
          if (i != children.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _DebugActionButton extends StatelessWidget {
  const _DebugActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.isDestructive = false,
    this.buttonKey,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool isDestructive;
  final Key? buttonKey;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final style = isDestructive
        ? FilledButton.styleFrom(
            backgroundColor: colorScheme.error,
            foregroundColor: colorScheme.onError,
            disabledBackgroundColor: colorScheme.error.withValues(alpha: 0.26),
            disabledForegroundColor: colorScheme.onError.withValues(
              alpha: 0.72,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          )
        : FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          );

    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        key: buttonKey,
        onPressed: onPressed,
        style: style,
        icon: Icon(icon),
        label: Align(alignment: Alignment.centerLeft, child: Text(label)),
      ),
    );
  }
}

class _OauthOverrideDialog extends StatefulWidget {
  const _OauthOverrideDialog({this.oauthServiceFactory});

  final HitobitoOauthService Function(
    HitobitoAuthConfigController controller,
    LoggerService logger,
  )?
  oauthServiceFactory;

  @override
  State<_OauthOverrideDialog> createState() => _OauthOverrideDialogState();
}

class _OauthOverrideDialogState extends State<_OauthOverrideDialog> {
  late final TextEditingController _clientIdController;
  late final TextEditingController _clientSecretController;
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final configController = context.read<HitobitoAuthConfigController>();
    _clientIdController = TextEditingController(
      text: configController.effectiveClientId,
    );
    _clientSecretController = TextEditingController();
  }

  @override
  void dispose() {
    _clientIdController.dispose();
    _clientSecretController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final configController = context.read<HitobitoAuthConfigController>();
    final authModel = context.read<AuthSessionModel>();
    final arbeitskontextModel = context.read<ArbeitskontextModel>();
    final logger = context.read<LoggerService>();
    await logger.trackAndLog('debug_tools', 'debug_action', {
      'action': 'oauth_override_submit',
    });
    final clientId = _clientIdController.text.trim();
    final clientSecret = _clientSecretController.text.trim();
    final previousConfig = configController.config;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    configController.applyEphemeralOverride(
      clientId: clientId,
      clientSecret: clientSecret,
    );

    try {
      final oauthService =
          widget.oauthServiceFactory?.call(configController, logger) ??
          HitobitoOauthService(config: configController.config, logger: logger);
      final authenticatedSession = await oauthService.authenticateInteractive();
      await authModel.signInWithAuthenticatedSession(authenticatedSession);
      await configController.saveOverride(
        clientId: clientId,
        clientSecret: clientSecret,
      );
      await arbeitskontextModel.syncForAuth(
        authState: authModel.state,
        session: authModel.session,
        profile: authModel.profile,
      );

      if (!mounted) {
        return;
      }

      await logger.trackAndLog('debug_tools', 'debug_action', {
        'action': 'oauth_override_submit_success',
      });

      Navigator.of(context).pop();
    } catch (error) {
      configController.restoreConfig(previousConfig);
      await logger.logError(
        'debug_tools',
        'oauth_override_submit_failed',
        error: error,
      );
      await logger.trackEvent('debug_action', {
        'action': 'oauth_override_submit_failed',
      });
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(t.t('debug_oauth_dialog_title')),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _clientIdController,
              decoration: InputDecoration(
                labelText: t.t('debug_oauth_client_id'),
              ),
              enabled: !_isSubmitting,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return t.t('debug_oauth_client_id_required');
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _clientSecretController,
              decoration: InputDecoration(
                labelText: t.t('debug_oauth_client_secret'),
              ),
              enabled: !_isSubmitting,
              obscureText: true,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return t.t('debug_oauth_client_secret_required');
                }
                return null;
              },
            ),
            if (_errorMessage != null && _errorMessage!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting
              ? null
              : () async {
                  final logger = context.read<LoggerService>();
                  await logger.trackAndLog('debug_tools', 'debug_action', {
                    'action': 'oauth_override_cancel',
                  });
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                },
          child: Text(t.t('debug_oauth_cancel')),
        ),
        FilledButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(t.t('debug_oauth_submit')),
        ),
      ],
    );
  }
}

/// Zwei Einstiege in die Log-Ansichten, mit Eintraegen und Fehlern von heute.
class _LogEinstiege extends StatefulWidget {
  const _LogEinstiege({
    super.key,
    required this.quellen,
    required this.onOeffnen,
  });

  final List<LogQuelle> quellen;
  final Future<void> Function(LogQuelle quelle) onOeffnen;

  @override
  State<_LogEinstiege> createState() => _LogEinstiegeState();
}

class _LogEinstiegeState extends State<_LogEinstiege> {
  late final Future<List<({int heute, int fehler})>> _zahlen = _zaehlen();

  Future<List<({int heute, int fehler})>> _zaehlen() async {
    final jetzt = DateTime.now();
    final heute = DateTime(jetzt.year, jetzt.month, jetzt.day);
    return [
      for (final quelle in widget.quellen)
        await quelle.lesen().then((content) {
          final infos = quelle
              .eintraege(content)
              .where((info) => !info.zeitpunkt.isBefore(heute))
              .toList(growable: false);
          return (
            heute: infos.length,
            fehler: infos.where((info) => info.fehler).length,
          );
        }),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return FutureBuilder<List<({int heute, int fehler})>>(
      future: _zahlen,
      builder: (context, snapshot) {
        final zahlen = snapshot.data;
        // Material statt DecoratedBox, damit der Tipp-Effekt sichtbar bleibt.
        return Material(
          color: scheme.surfaceContainerHigh,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: scheme.outlineVariant),
          ),
          child: Column(
            children: [
              for (var i = 0; i < widget.quellen.length; i++) ...[
                if (i > 0) Divider(height: 1, color: scheme.outlineVariant),
                ListTile(
                  key: Key('debug_logs_open_${widget.quellen[i].dateiKennung}'),
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      widget.quellen[i].dateiKennung == 'traffic'
                          ? Icons.swap_horiz
                          : Icons.article_outlined,
                      size: 20,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                  title: Text(t.t(widget.quellen[i].titelKey)),
                  subtitle: zahlen == null
                      ? null
                      : Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: t.t(widget.quellen[i].heuteKey, {
                                  'count': zahlen[i].heute,
                                }),
                              ),
                              if (zahlen[i].fehler > 0)
                                TextSpan(
                                  text:
                                      ' · ${t.t('debug_logs_errors', {'count': zahlen[i].fehler})}',
                                  style: TextStyle(
                                    color: scheme.error,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                            ],
                          ),
                        ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => widget.onOeffnen(widget.quellen[i]),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

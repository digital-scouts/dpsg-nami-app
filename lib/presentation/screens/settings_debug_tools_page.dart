import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:intl/intl.dart';
import 'package:nami/domain/auth/auth_state.dart';
import 'package:nami/domain/maps/stamm_map_marker_repository.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/main.dart' show navigatorKey;
import 'package:nami/presentation/model/arbeitskontext_model.dart';
import 'package:nami/presentation/model/auth_session_model.dart';
import 'package:nami/presentation/model/member_edit_model.dart';
import 'package:nami/presentation/notifications/app_snackbar.dart';
import 'package:nami/presentation/screens/changelog_page.dart';
import 'package:provider/provider.dart';
import 'package:wiredash/wiredash.dart';

import '../../services/app_runtime_controller.dart';
import '../../services/hitobito_auth_config_controller.dart';
import '../../services/hitobito_oauth_service.dart';
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
  String _selectedLogSelectionId = LoggerService.allLogsSelectionId;
  int _logFilesRevision = 0;

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

  Future<void> sendLogsEmail(List<File> files) async {
    final existingFiles = <File>[];
    for (final file in files) {
      if (await file.exists()) {
        existingFiles.add(file);
      }
    }

    if (existingFiles.isEmpty) {
      return;
    }
    try {
      final t = AppLocalizations.of(context);
      FlutterEmailSender.send(
        Email(
          body: t.t('debug_logs_email_body'),
          attachmentPaths: existingFiles.map((file) => file.path).toList(),
          subject: t.t('debug_logs_email_subject'),
          recipients: ["dev@jannecklange.de"],
        ),
      );
    } catch (_) {}
  }

  Future<List<String>> _loadLogFileNames(LoggerService logger) {
    return logger.listLogFileNames();
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

  MapTileCacheService _resolveMapTileCacheService(LoggerService logger) {
    try {
      return context.read<MapTileCacheService>();
    } catch (_) {
      return MapTileCacheService(logger: logger);
    }
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
    final mapTileCacheService = _resolveMapTileCacheService(logger);
    final authModel = context.watch<AuthSessionModel>();
    final arbeitskontextModel = context.read<ArbeitskontextModel>();
    final memberEditModel = context.watch<MemberEditModel?>();
    final configController = context.watch<HitobitoAuthConfigController>();
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
                  child: FutureBuilder<List<String>>(
                    key: ValueKey(_logFilesRevision),
                    future: _loadLogFileNames(logger),
                    builder: (context, snapshot) {
                      final names = snapshot.data ?? const <String>[];
                      final hasLogs = names.isNotEmpty;
                      final selectedId = names.contains(_selectedLogSelectionId)
                          ? _selectedLogSelectionId
                          : LoggerService.allLogsSelectionId;

                      if (selectedId != _selectedLogSelectionId) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (!mounted) {
                            return;
                          }
                          setState(() {
                            _selectedLogSelectionId =
                                LoggerService.allLogsSelectionId;
                          });
                        });
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: colorScheme.outlineVariant,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  t.t('debug_logs_selection'),
                                  style: theme.textTheme.titleMedium,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  hasLogs
                                      ? t.t('debug_logs_available_count', {
                                          'count': names.length,
                                          'suffix': names.length == 1
                                              ? ''
                                              : 'en',
                                        })
                                      : t.t('debug_logs_empty'),
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                DropdownButtonFormField<String>(
                                  initialValue: selectedId,
                                  decoration: InputDecoration(
                                    labelText: t.t('debug_logs_selection'),
                                    border: const OutlineInputBorder(),
                                  ),
                                  items: [
                                    DropdownMenuItem<String>(
                                      value: LoggerService.allLogsSelectionId,
                                      child: Text(t.t('debug_logs_all_files')),
                                    ),
                                    ...names.map(
                                      (name) => DropdownMenuItem<String>(
                                        value: name,
                                        child: Text(name),
                                      ),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedLogSelectionId =
                                          value ??
                                          LoggerService.allLogsSelectionId;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          _DebugButtonGroup(
                            children: [
                              _DebugActionButton(
                                icon: Icons.mail_outline,
                                label:
                                    selectedId ==
                                        LoggerService.allLogsSelectionId
                                    ? t.t('debug_logs_send_all')
                                    : t.t('debug_logs_send_selected'),
                                onPressed: !hasLogs
                                    ? null
                                    : () async {
                                        await _trackDebugAction(
                                          logger,
                                          'send_logs_email',
                                          properties: <String, Object?>{
                                            'selection': selectedId,
                                          },
                                        );
                                        final files = await logger
                                            .resolveLogFiles(
                                              selectionId: selectedId,
                                            );
                                        await sendLogsEmail(files);
                                      },
                              ),
                              _DebugActionButton(
                                icon: Icons.article_outlined,
                                label:
                                    selectedId ==
                                        LoggerService.allLogsSelectionId
                                    ? t.t('debug_logs_view_all')
                                    : t.t('debug_logs_view_selected'),
                                onPressed: () async {
                                  await _trackDebugAction(
                                    logger,
                                    'view_logs',
                                    properties: <String, Object?>{
                                      'selection': selectedId,
                                    },
                                  );
                                  final content = await logger.readLogs(
                                    selectionId: selectedId,
                                  );

                                  if (!context.mounted) {
                                    return;
                                  }

                                  final title =
                                      selectedId ==
                                          LoggerService.allLogsSelectionId
                                      ? t.t('debug_logs_viewer_title_all')
                                      : t.t(
                                          'debug_logs_viewer_title_selected',
                                          {'selection': selectedId},
                                        );
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      settings: const RouteSettings(
                                        name: '/settings/debug/logs',
                                      ),
                                      builder: (_) => _LogViewerPage(
                                        title: title,
                                        content: content,
                                      ),
                                    ),
                                  );
                                },
                              ),
                              _DebugActionButton(
                                icon: Icons.delete_outline,
                                label: t.t('debug_logs_delete'),
                                isDestructive: true,
                                buttonKey: const Key(
                                  'debug_logs_delete_button',
                                ),
                                onPressed: !hasLogs
                                    ? null
                                    : () async {
                                        await _trackDebugAction(
                                          logger,
                                          'delete_logs',
                                          properties: <String, Object?>{
                                            'selection': selectedId,
                                          },
                                        );
                                        await logger.clearAllLogs();
                                        if (!mounted) {
                                          return;
                                        }
                                        setState(() {
                                          _selectedLogSelectionId =
                                              LoggerService.allLogsSelectionId;
                                          _logFilesRevision++;
                                        });
                                        _showSnackbar(
                                          t.t('debug_logs_deleted'),
                                          type: AppSnackbarType.success,
                                        );
                                      },
                              ),
                            ],
                          ),
                        ],
                      );
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
                  child: _DebugButtonGroup(
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
                                  syncMembers: (accessToken) async {
                                    await arbeitskontextModel.refreshFromRemote(
                                      session: authModel.session,
                                      profile: authModel.profile,
                                    );
                                  },
                                  force: true,
                                  trigger: 'debug_tools',
                                );

                                if (!context.mounted) {
                                  return;
                                }

                                final messenger = ScaffoldMessenger.of(context);
                                final message = switch ((
                                  authModel
                                      .isRemoteAccessBlockedByNetworkPolicy,
                                  authModel.state == AuthState.reloginRequired,
                                  authModel.errorMessage?.isNotEmpty == true,
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
                                  authModel.state == AuthState.reloginRequired,
                                  authModel.errorMessage?.isNotEmpty == true,
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
                          await _trackDebugAction(logger, 'view_data_changes');
                          _showSnackbar(
                            t.t('debug_sync_changes_not_implemented'),
                            type: AppSnackbarType.info,
                          );
                        },
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

class _LogViewerPage extends StatelessWidget {
  final String title;
  final String content;
  const _LogViewerPage({required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: _ColoredLogView(content: content),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ColoredLogView extends StatelessWidget {
  final String content;
  const _ColoredLogView({required this.content});

  TextSpan _spanForLine(
    String line,
    TextStyle base, {
    required TextStyle tsStyle,
    required TextStyle levelInfoStyle,
    required TextStyle levelWarnStyle,
    required TextStyle levelErrorStyle,
    required TextStyle levelDebugStyle,
    required TextStyle domainStyle,
    required TextStyle msgStyle,
  }) {
    final regex = RegExp(r"^\[(.*?)\]\s*(\[\w+\])?\s*(\[[^\]]+\])?\s*(.*)$");
    final m = regex.firstMatch(line);
    if (m == null) {
      return TextSpan(text: line, style: msgStyle);
    }
    final ts = m.group(1) ?? '';
    final level = m.group(2) ?? '';
    final domain = m.group(3) ?? '';
    final msg = m.group(4) ?? '';

    TextStyle levelStyle = msgStyle;
    if (level.toLowerCase() == '[info]') {
      levelStyle = levelInfoStyle;
    } else if (level.toLowerCase() == '[warn]') {
      levelStyle = levelWarnStyle;
    } else if (level.toLowerCase() == '[error]') {
      levelStyle = levelErrorStyle;
    } else if (level.toLowerCase() == '[debug]') {
      levelStyle = levelDebugStyle;
    } else {
      levelStyle = domainStyle;
    }

    return TextSpan(
      children: [
        TextSpan(text: '[$ts] ', style: tsStyle),
        if (level.isNotEmpty) TextSpan(text: '$level ', style: levelStyle),
        if (domain.isNotEmpty) TextSpan(text: '$domain ', style: domainStyle),
        TextSpan(text: msg, style: msgStyle),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final lines = content.isEmpty ? const <String>[] : content.split('\n');
    final ordered = lines.reversed.toList();
    final base = const TextStyle(fontFamily: 'monospace', fontSize: 13);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tsStyle = base.copyWith(
      color: isDark ? Colors.grey.shade400 : Colors.grey,
    );
    final levelInfoStyle = base.copyWith(color: Colors.green);
    final levelWarnStyle = base.copyWith(color: Colors.orange);
    final levelErrorStyle = base.copyWith(color: Colors.red);
    final domainStyle = base.copyWith(color: Colors.blue);
    final levelDebugStyle = base.copyWith(color: Colors.purple);
    final msgStyle = base.copyWith(color: isDark ? Colors.white : Colors.black);

    return SelectableText.rich(
      TextSpan(
        children: lines.isEmpty
            ? const <TextSpan>[]
            : ordered
                  .expand(
                    (l) => [
                      _spanForLine(
                        l,
                        base,
                        tsStyle: tsStyle,
                        levelInfoStyle: levelInfoStyle,
                        levelWarnStyle: levelWarnStyle,
                        levelErrorStyle: levelErrorStyle,
                        domainStyle: domainStyle,
                        levelDebugStyle: levelDebugStyle,
                        msgStyle: msgStyle,
                      ),
                      const TextSpan(text: '\n'),
                    ],
                  )
                  .toList(),
        style: base,
      ),
    );
  }
}

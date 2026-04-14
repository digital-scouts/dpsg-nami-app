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
      FlutterEmailSender.send(
        Email(
          body:
              'Beschreibe dein Problem. Wie hat sich die App verhalten, was ist passiert? Was hättest du erwartet?',
          attachmentPaths: existingFiles.map((file) => file.path).toList(),
          subject: "NaMi App Logs",
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Stammesuche aktualisiert: ${snapshot.markers.length} Marker geladen.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Stammesuche konnte nicht aktualisiert werden.'),
        ),
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Kartendaten gelöscht')));
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Kein gueltiger Access Token fuer den Retry verfuegbar.',
          ),
        ),
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Retry abgeschlossen: ${summary.successCount} erfolgreich, ${summary.discardedCount} verworfen, ${summary.retainedCount} behalten.',
        ),
      ),
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
    final memberEditModel = context.watch<MemberEditModel>();
    final configController = context.watch<HitobitoAuthConfigController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Debug & Tools')),
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
                  title: 'Logs & Diagnose',
                  subtitle:
                      'Logdateien auswählen, prüfen, versenden oder gesammelt löschen.',
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
                                  'Log-Auswahl',
                                  style: theme.textTheme.titleMedium,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  hasLogs
                                      ? '${names.length} Datei${names.length == 1 ? '' : 'en'} verfügbar'
                                      : 'Aktuell sind keine Logdateien vorhanden.',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                DropdownButtonFormField<String>(
                                  initialValue: selectedId,
                                  decoration: const InputDecoration(
                                    labelText: 'Log-Auswahl',
                                    border: OutlineInputBorder(),
                                  ),
                                  items: [
                                    const DropdownMenuItem<String>(
                                      value: LoggerService.allLogsSelectionId,
                                      child: Text('Alle Dateien'),
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
                                    ? 'Logs per Mail senden'
                                    : 'Gewähltes Log per Mail senden',
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
                                    ? 'Logs anzeigen'
                                    : 'Gewähltes Log anzeigen',
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
                                      ? 'Alle Logs anzeigen'
                                      : '$selectedId anzeigen';
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
                                label: 'Logs löschen',
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
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Alle Logdateien gelöscht',
                                            ),
                                          ),
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
                  title: 'Ausstehende Personenänderungen',
                  subtitle:
                      'Pending-Änderungen prüfen und bei Bedarf manuell erneut senden.',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (memberEditModel.pendingUpdates.isEmpty)
                        Text(
                          'Aktuell sind keine ausstehenden Änderungen gespeichert.',
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
                            label: const Text('Alle erneut senden'),
                          ),
                        ),
                        const SizedBox(height: 12),
                        for (final entry in memberEditModel.pendingUpdates)
                          Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              title: Text(entry.displayName),
                              subtitle: Text(
                                'Mitgliedsnr. ${entry.mitgliedsnummer}\n'
                                'Vorgemerkt: ${_pendingDateFormat.format(entry.queuedAt)}\n'
                                'Versuche: ${entry.attemptCount}',
                              ),
                              isThreeLine: true,
                              trailing: IconButton(
                                tooltip: 'Eintrag erneut senden',
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
                  title: 'Feedback & Bewertung',
                  subtitle:
                      'Öffnet direkt die bestehenden Wiredash-Abläufe für Rückmeldungen und Bewertung.',
                  child: _DebugButtonGroup(
                    children: [
                      _DebugActionButton(
                        icon: Icons.feedback_outlined,
                        label: 'Feedback senden',
                        onPressed: () async {
                          await _trackDebugAction(logger, 'open_feedback');
                          final ctx = navigatorKey.currentContext;
                          if (ctx != null) {
                            Wiredash.of(ctx).show(inheritMaterialTheme: true);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Wiredash konnte nicht gefunden werden (Root-Kontext fehlt).',
                                ),
                              ),
                            );
                          }
                        },
                      ),
                      _DebugActionButton(
                        icon: Icons.star_outline,
                        label: 'App bewerten',
                        onPressed: () async {
                          await _trackDebugAction(logger, 'open_app_rating');
                          final ctx = navigatorKey.currentContext;
                          if (ctx != null) {
                            Wiredash.of(ctx).showPromoterSurvey(force: true);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Wiredash konnte nicht gefunden werden (Root-Kontext fehlt).',
                                ),
                              ),
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
                  title: 'Daten & Synchronisation',
                  subtitle:
                      'Manuelle Aktualisierung und technische Sicht auf Datenänderungen.',
                  child: _DebugButtonGroup(
                    children: [
                      _DebugActionButton(
                        icon: Icons.refresh_outlined,
                        label: 'Daten jetzt aktualisieren',
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
                                final message =
                                    authModel.state == AuthState.reloginRequired
                                    ? 'Neuanmeldung erforderlich, Daten konnten nicht synchronisiert werden.'
                                    : (authModel.errorMessage?.isNotEmpty ==
                                              true
                                          ? 'Hitobito-Daten konnten nicht vollständig synchronisiert werden.'
                                          : 'Hitobito-Daten wurden synchronisiert.');
                                messenger.showSnackBar(
                                  SnackBar(content: Text(message)),
                                );
                              },
                      ),
                      _DebugActionButton(
                        icon: Icons.visibility_outlined,
                        label: 'Datenänderungen anzeigen',
                        onPressed: () async {
                          await _trackDebugAction(logger, 'view_data_changes');
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Nicht implementiert: Datenänderungen angezeigt',
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _DebugSectionCard(
                  icon: Icons.map_outlined,
                  title: 'Karten & Cache',
                  subtitle:
                      'Status des Karten-Caches und manuelle Aktualisierung der Stammesuche.',
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
                              ConnectionState.done =>
                                'Größe derzeit nicht verfügbar',
                              _ => 'Größe wird geladen ...',
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
                                        'Offline-Karten',
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
                            ? 'Stammesuche wird aktualisiert ...'
                            : 'Stammesuche jetzt laden',
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
                        label: 'Kartendaten löschen',
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
                  title: 'Hitobito OAuth',
                  subtitle:
                      'Aktuelle OAuth-Quelle prüfen und temporäre Zugangsdaten testen.',
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
                              ? 'Aktiver Override fuer Client ID ${configController.effectiveClientId}'
                              : 'Aktuell werden die Hitobito OAuth-Werte aus der lokalen Env genutzt.',
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
                        label: 'OAuth-Zugangsdaten prüfen',
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
                  title: 'Referenzen',
                  subtitle:
                      'Schneller Zugriff auf Changelog und eingehende Mitteilungen.',
                  child: _DebugButtonGroup(
                    children: [
                      _DebugActionButton(
                        icon: Icons.list_alt_outlined,
                        label: 'Changelog anzeigen',
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
                        label: 'Mitteilungen anzeigen',
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
                  subtitle:
                      'Diese Aktionen greifen stark ein. Die Darstellung ist bewusst auffälliger, das Verhalten bleibt unverändert.',
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
    if (sizeKiB <= 0) {
      return 'Noch keine Offline-Kartendaten gespeichert';
    }
    if (sizeKiB < 1024) {
      return '${sizeKiB.toStringAsFixed(0)} KB gespeichert';
    }

    final sizeMb = sizeKiB / 1024;
    if (sizeMb < 1024) {
      return '${sizeMb.toStringAsFixed(2)} MB gespeichert';
    }

    final sizeGb = sizeMb / 1024;
    return '${sizeGb.toStringAsFixed(2)} GB gespeichert';
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
    return AlertDialog(
      title: const Text('Hitobito OAuth prüfen'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _clientIdController,
              decoration: const InputDecoration(labelText: 'Client ID'),
              enabled: !_isSubmitting,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Client ID ist erforderlich';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _clientSecretController,
              decoration: const InputDecoration(labelText: 'Client Secret'),
              enabled: !_isSubmitting,
              obscureText: true,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Client Secret ist erforderlich';
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
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Prüfen'),
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

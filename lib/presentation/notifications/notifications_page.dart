import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nami/core/notifications/pull_notification.dart';
import 'package:nami/core/notifications/pull_notifications_repository_factory.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/presentation/model/auth_session_model.dart';
import 'package:nami/presentation/model/member_edit_model.dart';
import 'package:nami/presentation/notifications/app_snackbar.dart';
import 'package:nami/presentation/notifications/notification_card.dart';
import 'package:nami/presentation/notifications/notification_links.dart';
import 'package:nami/presentation/notifications/notifications_hub.dart';
import 'package:nami/services/app_update_service.dart';
import 'package:nami/services/logger_service.dart';
import 'package:nami/services/network_access_policy.dart';
import 'package:nami/presentation/notifications/qualifikations_meldung.dart';
import 'package:nami/presentation/widgets/neuanmeldung_sheet.dart';
import 'package:provider/provider.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({
    super.key,
    this.includeInternalMessages = false,
    this.showStatusButtons = true,
    this.showAllAcknowledged = false,
  });

  final bool includeInternalMessages;
  final bool showStatusButtons;
  final bool showAllAcknowledged;

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  late Future<_ExternalNotificationsData> _externalFuture;
  late Future<AppUpdateInfo?> _appUpdateFuture;

  @override
  void initState() {
    super.initState();
    _externalFuture = _loadExternalData();
    _appUpdateFuture = _loadAppUpdateInfo();
  }

  Future<AppUpdateInfo?> _loadAppUpdateInfo() async {
    try {
      return await _resolveAppUpdateService().checkForUpdate();
    } catch (_) {
      return null;
    }
  }

  Future<_ExternalNotificationsData> _loadExternalData({
    bool forceRefresh = false,
  }) async {
    final logger = context.read<LoggerService>();
    final repo = await createPullNotificationsRepository(
      logger: logger,
      networkAccessPolicy: _resolveNetworkAccessPolicy(),
    );
    final notifications = await repo.fetchNotifications(
      forceRefresh: forceRefresh,
    );
    final acknowledged = await repo.getAcknowledgedIds();
    final lastFetchAt = await repo.getLastFetchAt();
    return _ExternalNotificationsData(
      notifications: notifications,
      acknowledged: acknowledged,
      lastFetchAt: lastFetchAt,
    );
  }

  Future<void> _reload({bool forceRefresh = false}) async {
    final future = _loadExternalData(forceRefresh: forceRefresh);
    setState(() {
      _externalFuture = future;
    });
    try {
      await future;
    } catch (_) {
      // Der Fehler erscheint über den FutureBuilder.
    }
  }

  Future<void> _handleMessageTap(AppHubNotification message) async {
    if (message.id == qualifikationsMeldungId) {
      await oeffneEigeneMitgliedsdetails(context);
      return;
    }
    if (message.id != 'hitobito-issue') {
      return;
    }

    final authModel = context.read<AuthSessionModel>();
    if (authModel.requiresInteractiveLogin) {
      // Das Tippen auf den Hinweis ist die Zustimmung zur Anmeldung.
      await neuAnmeldenMitHinweis(context, trigger: 'notifications_hint');
    }
  }

  Future<void> _acknowledge(String id) async {
    final logger = context.read<LoggerService>();
    final repo = await createPullNotificationsRepository(
      logger: logger,
      networkAccessPolicy: _resolveNetworkAccessPolicy(),
    );
    await repo.acknowledgeNotification(id);
    if (!mounted) {
      return;
    }
    await _reload();
  }

  Future<void> _resetAcknowledged() async {
    final logger = context.read<LoggerService>();
    final repo = await createPullNotificationsRepository(
      logger: logger,
      networkAccessPolicy: _resolveNetworkAccessPolicy(),
    );
    await repo.resetAcknowledgedNotifications();
    if (!mounted) {
      return;
    }
    AppSnackbar.show(
      context,
      message: AppLocalizations.of(context).t('notifications_reset_done'),
      type: AppSnackbarType.success,
    );
    await _reload();
  }

  AppUpdateService _resolveAppUpdateService() {
    try {
      return context.read<AppUpdateService>();
    } catch (_) {
      return AppUpdateService(
        networkAccessPolicy: _resolveNetworkAccessPolicy(),
        logger: context.read<LoggerService>(),
      );
    }
  }

  NetworkAccessPolicy? _resolveNetworkAccessPolicy() {
    try {
      return context.read<NetworkAccessPolicy>();
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(t.t('pull_notifications_title')),
        actions: [
          if (widget.showStatusButtons)
            PopupMenuButton<String>(
              key: const Key('notifications-menu'),
              onSelected: (value) {
                if (value == 'reset') {
                  unawaited(_resetAcknowledged());
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'reset',
                  child: Text(t.t('notifications_reset_read')),
                ),
              ],
            ),
        ],
      ),
      body: Consumer<AuthSessionModel>(
        builder: (context, authModel, _) {
          final unresolvedCount =
              context.watch<MemberEditModel?>()?.openResolutionCount ?? 0;

          return FutureBuilder<AppUpdateInfo?>(
            future: _appUpdateFuture,
            builder: (context, updateSnapshot) {
              return FutureBuilder<_ExternalNotificationsData>(
                future: _externalFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        t.t('notifications_error', {
                          'message': snapshot.error.toString(),
                        }),
                      ),
                    );
                  }

                  final data = snapshot.data;
                  if (data == null) {
                    return Center(child: Text(t.t('notifications_empty')));
                  }

                  final external = NotificationsHub.mapVisibleExternal(
                    notifications: data.notifications,
                    acknowledged: data.acknowledged,
                    includeAcknowledged: widget.showAllAcknowledged,
                  );

                  final internal = widget.includeInternalMessages
                      ? NotificationsHub.buildInternal(
                          authModel: authModel,
                          unresolvedCount: unresolvedCount,
                          updateInfo: updateSnapshot.data,
                          eigeneQualifikationsAblaeufe:
                              eigeneQualifikationsAblaeufe(context),
                        )
                      : const <AppHubNotification>[];

                  final messages = NotificationsHub.mergeSorted(
                    internal: internal,
                    external: external,
                  );

                  if (messages.isEmpty) {
                    return RefreshIndicator(
                      onRefresh: () => _reload(forceRefresh: true),
                      child: _LeererZustand(
                        lastFetchAt: data.lastFetchAt,
                        onShowReadAgain: _resetAcknowledged,
                      ),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () => _reload(forceRefresh: true),
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      children: [
                        for (final severity
                            in AppNotificationSeverity.values.reversed)
                          ..._gruppe(
                            context,
                            severity,
                            messages
                                .where((m) => m.severity == severity)
                                .toList(),
                          ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  /// Abschnitt je Priorität mit Überschrift und kleinem Abstand statt
  /// Trennlinie.
  List<Widget> _gruppe(
    BuildContext context,
    AppNotificationSeverity severity,
    List<AppHubNotification> messages,
  ) {
    if (messages.isEmpty) {
      return const [];
    }
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final titel = t.t(switch (severity) {
      AppNotificationSeverity.urgent => 'notif_prio_urgent',
      AppNotificationSeverity.warn => 'notif_prio_warn',
      AppNotificationSeverity.info => 'notif_prio_info',
    });
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
        child: Text(
          '${titel.toUpperCase()} · ${messages.length}',
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            letterSpacing: 0.6,
          ),
        ),
      ),
      for (final message in messages) ...[
        NotificationCard(
          notification: _toPullNotification(message),
          onTap: () => _handleMessageTap(message),
          onAcknowledge: message.ackable && !message.acknowledged
              ? () => _acknowledge(message.id)
              : null,
          onOpenLink:
              hatMeldungsLink(
                context,
                externalLink: message.externalLink,
                deepLink: message.deepLink,
              )
              ? () => oeffneMeldungsLink(
                  context,
                  externalLink: message.externalLink,
                  deepLink: message.deepLink,
                )
              : null,
        ),
        const SizedBox(height: 12),
      ],
    ];
  }

  PullNotification _toPullNotification(AppHubNotification message) {
    return PullNotification(
      id: message.id,
      title: message.title,
      body: message.body,
      type: switch (message.severity) {
        AppNotificationSeverity.urgent => 'urgent',
        AppNotificationSeverity.warn => 'warn',
        AppNotificationSeverity.info => 'info',
      },
      createdAt: message.createdAt,
      updatedAt: message.updatedAt,
      deepLink: message.deepLink,
      externalLink: message.externalLink,
    );
  }
}

/// Erscheint nur direkt nach dem Bestätigen der letzten Meldung, denn ohne
/// Meldungen gibt es keinen Einstieg in diese Seite.
class _LeererZustand extends StatelessWidget {
  const _LeererZustand({
    required this.lastFetchAt,
    required this.onShowReadAgain,
  });

  final DateTime? lastFetchAt;
  final Future<void> Function() onShowReadAgain;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final geprueft = lastFetchAt;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(32, 72, 32, 32),
      children: [
        Icon(
          Icons.check_circle_outline,
          size: 56,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: 12),
        Text(
          t.t('notif_all_read'),
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge,
        ),
        if (geprueft != null) ...[
          const SizedBox(height: 4),
          Text(
            t.t('notif_last_checked', {
              'zeit': DateFormat.yMd(
                locale,
              ).add_Hm().format(geprueft.toLocal()),
            }),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 16),
        Center(
          child: FilledButton.tonal(
            key: const Key('notifications-show-read-again'),
            onPressed: onShowReadAgain,
            child: Text(t.t('notif_show_read_again')),
          ),
        ),
      ],
    );
  }
}

class _ExternalNotificationsData {
  const _ExternalNotificationsData({
    required this.notifications,
    required this.acknowledged,
    this.lastFetchAt,
  });

  final List<PullNotification> notifications;
  final Set<String> acknowledged;
  final DateTime? lastFetchAt;
}

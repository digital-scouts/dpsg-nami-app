import 'package:flutter/material.dart';
import 'package:nami/core/notifications/pull_notification.dart';
import 'package:nami/core/notifications/pull_notifications_repository_factory.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/presentation/model/auth_session_model.dart';
import 'package:nami/presentation/model/member_edit_model.dart';
import 'package:nami/presentation/notifications/app_snackbar.dart';
import 'package:nami/presentation/notifications/notification_card.dart';
import 'package:nami/presentation/notifications/notifications_hub.dart';
import 'package:nami/services/app_update_service.dart';
import 'package:nami/services/logger_service.dart';
import 'package:nami/services/network_access_policy.dart';
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
    return _ExternalNotificationsData(
      notifications: notifications,
      acknowledged: acknowledged,
    );
  }

  Future<void> _reload({bool forceRefresh = false}) async {
    setState(() {
      _externalFuture = _loadExternalData(forceRefresh: forceRefresh);
    });
  }

  Future<void> _handleMessageTap(AppHubNotification message) async {
    if (message.id != 'hitobito-issue') {
      return;
    }

    final authModel = context.read<AuthSessionModel>();
    if (authModel.requiresInteractiveLogin) {
      await authModel.signIn();
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
      appBar: AppBar(title: Text(t.t('pull_notifications_title'))),
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
                        )
                      : const <AppHubNotification>[];

                  final messages = NotificationsHub.mergeSorted(
                    internal: internal,
                    external: external,
                  );

                  if (messages.isEmpty) {
                    return Center(child: Text(t.t('notifications_empty')));
                  }

                  return Column(
                    children: [
                      if (widget.showStatusButtons)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                          child: Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _reload(forceRefresh: true),
                                  icon: const Icon(Icons.sync),
                                  label: Text(t.t('notifications_refresh')),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _resetAcknowledged,
                                  icon: const Icon(Icons.restart_alt),
                                  label: Text(t.t('notifications_reset_read')),
                                ),
                              ),
                            ],
                          ),
                        ),
                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: messages.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final message = messages[index];
                            return NotificationCard(
                              notification: _toPullNotification(message),
                              onTap: () => _handleMessageTap(message),
                              onClose: message.ackable && !message.acknowledged
                                  ? () => _acknowledge(message.id)
                                  : null,
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
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

class _ExternalNotificationsData {
  const _ExternalNotificationsData({
    required this.notifications,
    required this.acknowledged,
  });

  final List<PullNotification> notifications;
  final Set<String> acknowledged;
}

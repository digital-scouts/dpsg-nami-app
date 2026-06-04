import 'package:flutter/material.dart';
import 'package:nami/core/notifications/pull_notifications_repository_factory.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/presentation/model/auth_session_model.dart';
import 'package:nami/presentation/model/member_edit_model.dart';
import 'package:nami/presentation/notifications/notifications_hub.dart';
import 'package:nami/services/app_update_service.dart';
import 'package:nami/services/logger_service.dart';
import 'package:nami/services/network_access_policy.dart';
import 'package:provider/provider.dart';

class SettingsMessagesPage extends StatefulWidget {
  const SettingsMessagesPage({super.key});

  @override
  State<SettingsMessagesPage> createState() => _SettingsMessagesPageState();
}

class _SettingsMessagesPageState extends State<SettingsMessagesPage> {
  late Future<List<AppHubNotification>> _unreadExternalNotificationsFuture;
  late Future<AppUpdateInfo?> _appUpdateFuture;

  @override
  void initState() {
    super.initState();
    _unreadExternalNotificationsFuture = _loadUnreadExternalNotifications();
    _appUpdateFuture = _loadAppUpdateInfo();
  }

  Future<AppUpdateInfo?> _loadAppUpdateInfo() async {
    try {
      return await _resolveAppUpdateService().checkForUpdate();
    } catch (_) {
      return null;
    }
  }

  Future<List<AppHubNotification>> _loadUnreadExternalNotifications() async {
    try {
      final logger = context.read<LoggerService>();
      final repo = await createPullNotificationsRepository(
        logger: logger,
        networkAccessPolicy: _resolveNetworkAccessPolicy(),
      );
      final notifications = await repo.fetchNotifications();
      final acknowledged = await repo.getAcknowledgedIds();
      return NotificationsHub.mapVisibleExternal(
        notifications: notifications,
        acknowledged: acknowledged,
      );
    } catch (_) {
      return const <AppHubNotification>[];
    }
  }

  Future<void> _acknowledgeIfNeeded(AppHubNotification notification) async {
    if (!notification.ackable || notification.acknowledged) {
      return;
    }

    try {
      final logger = context.read<LoggerService>();
      final repo = await createPullNotificationsRepository(
        logger: logger,
        networkAccessPolicy: _resolveNetworkAccessPolicy(),
      );
      await repo.acknowledgeNotification(notification.id);
      if (!mounted) {
        return;
      }
      setState(() {
        _unreadExternalNotificationsFuture = _loadUnreadExternalNotifications();
      });
    } catch (_) {
      // Ignore ack failures to keep list interaction resilient.
    }
  }

  AppUpdateService _resolveAppUpdateService() {
    try {
      return context.read<AppUpdateService>();
    } catch (_) {
      return AppUpdateService(
        networkAccessPolicy: _resolveNetworkAccessPolicy(),
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
    final locale = Localizations.localeOf(context);

    return Scaffold(
      appBar: AppBar(title: Text(t.t('pull_notifications_title'))),
      body: Consumer<AuthSessionModel>(
        builder: (context, authModel, _) {
          final openResolutionCount =
              context.watch<MemberEditModel?>()?.openResolutionCount ?? 0;
          return FutureBuilder<AppUpdateInfo?>(
            future: _appUpdateFuture,
            builder: (context, updateSnapshot) {
              return FutureBuilder<List<AppHubNotification>>(
                future: _unreadExternalNotificationsFuture,
                builder: (context, notificationSnapshot) {
                  final hubMessages = NotificationsHub.mergeSorted(
                    internal: NotificationsHub.buildInternal(
                      authModel: authModel,
                      unresolvedCount: openResolutionCount,
                      updateInfo: updateSnapshot.data,
                    ),
                    external:
                        notificationSnapshot.data ??
                        const <AppHubNotification>[],
                  );

                  if (hubMessages.isEmpty) {
                    return Center(
                      child: Text(
                        t.t('notifications_empty'),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    );
                  }

                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Card(
                        margin: EdgeInsets.zero,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Column(
                            children: [
                              for (int i = 0; i < hubMessages.length; i++) ...[
                                _HubMessageTile(
                                  notification: hubMessages[i],
                                  locale: locale,
                                  onTap: () =>
                                      _acknowledgeIfNeeded(hubMessages[i]),
                                ),
                                if (i < hubMessages.length - 1)
                                  const Divider(
                                    height: 1,
                                    indent: 16,
                                    endIndent: 16,
                                  ),
                              ],
                            ],
                          ),
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
}

class _HubMessageTile extends StatelessWidget {
  const _HubMessageTile({
    required this.notification,
    required this.locale,
    this.onTap,
  });

  final AppHubNotification notification;
  final Locale locale;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final iconColor = switch (notification.severity) {
      AppNotificationSeverity.urgent => const Color(0xFFE6007E),
      AppNotificationSeverity.warn => const Color(0xFFFFB300),
      AppNotificationSeverity.info => const Color(0xFF003056),
    };
    final iconData = switch (notification.severity) {
      AppNotificationSeverity.urgent => Icons.priority_high,
      AppNotificationSeverity.warn => Icons.warning_amber_rounded,
      AppNotificationSeverity.info => Icons.info_outline,
    };

    final timestamp = notification.updatedAt ?? notification.createdAt;

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      leading: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(iconData, color: iconColor, size: 20),
      ),
      title: Text(notification.title.resolve(locale)),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(notification.body.resolve(locale)),
            if (timestamp != null) ...[
              const SizedBox(height: 4),
              Text(
                _formatRelativeTime(timestamp),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
      trailing: notification.ackable && !notification.acknowledged
          ? Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: Color(0xFFE6007E),
                shape: BoxShape.circle,
              ),
            )
          : null,
    );
  }

  String _formatRelativeTime(DateTime timestamp) {
    final delta = DateTime.now().difference(timestamp.toLocal());
    if (delta.inMinutes < 1) {
      return 'gerade eben';
    }
    if (delta.inHours < 1) {
      return 'vor ${delta.inMinutes} Minuten';
    }
    if (delta.inDays < 1) {
      return 'vor ${delta.inHours} Stunden';
    }
    return 'vor ${delta.inDays} Tagen';
  }
}

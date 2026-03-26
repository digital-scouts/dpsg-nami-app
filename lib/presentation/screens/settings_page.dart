import 'package:flutter/material.dart';
import 'package:nami/core/notifications/pull_notification.dart';
import 'package:nami/core/notifications/pull_notifications_repository_factory.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/presentation/notifications/notification_card.dart';
import 'package:nami/presentation/widgets/confetti_overlay.dart';
import 'package:nami/services/logger_service.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

class SettingsPage extends StatefulWidget {
  final VoidCallback? onStammSettings;
  final VoidCallback? onNotificationSettings;
  final VoidCallback? onAppSettings;
  final VoidCallback? onDebugTools;
  final VoidCallback? onProfile;
  final String? appVersion;

  const SettingsPage({
    super.key,
    this.onStammSettings,
    this.onNotificationSettings,
    this.onAppSettings,
    this.onDebugTools,
    this.onProfile,
    this.appVersion,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  int _tapCount = 0;
  DateTime? _firstTapAt;
  String? _appVersion;
  late Future<PullNotification?> _unreadNotificationFuture;

  int _notificationPriority(PullNotification notification) {
    switch (notification.type) {
      case 'urgent':
        return 0;
      case 'warn':
        return 1;
      case 'info':
      default:
        return 2;
    }
  }

  @override
  void initState() {
    super.initState();
    _unreadNotificationFuture = _loadUnreadNotification();
    _appVersion = widget.appVersion;
    if (_appVersion == null) {
      _loadAppVersion();
    }
  }

  Future<void> _loadAppVersion() async {
    String version = '-';
    try {
      final info = await PackageInfo.fromPlatform();
      version = info.version;
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _appVersion = version;
    });
  }

  Future<void> _acknowledgeNotification(PullNotification notification) async {
    final logger = context.read<LoggerService>();
    final repo = await createPullNotificationsRepository(logger: logger);
    await repo.acknowledgeNotification(notification.id);
    if (!mounted) return;
    setState(() {
      _unreadNotificationFuture = _loadUnreadNotification();
    });
  }

  Future<PullNotification?> _loadUnreadNotification() async {
    final logger = context.read<LoggerService>();
    final repo = await createPullNotificationsRepository(logger: logger);
    final notifications = await repo.fetchNotifications();
    final acknowledged = await repo.getAcknowledgedIds();

    final unread =
        notifications
            .where((notification) => !acknowledged.contains(notification.id))
            .toList()
          ..sort((left, right) {
            final priorityCompare = _notificationPriority(
              left,
            ).compareTo(_notificationPriority(right));
            if (priorityCompare != 0) {
              return priorityCompare;
            }

            final leftDate = left.updatedAt ?? left.createdAt;
            final rightDate = right.updatedAt ?? right.createdAt;

            if (leftDate == null && rightDate == null) {
              return 0;
            }
            if (leftDate == null) {
              return 1;
            }
            if (rightDate == null) {
              return -1;
            }

            return rightDate.compareTo(leftDate);
          });

    if (unread.isEmpty) {
      return null;
    }

    return unread.first;
  }

  void _handleTippleTapInTwoSeconds() {
    final now = DateTime.now();
    if (_firstTapAt == null ||
        now.difference(_firstTapAt!) > const Duration(seconds: 2)) {
      _firstTapAt = now;
      _tapCount = 1;
    } else {
      _tapCount++;
    }
    if (_tapCount >= 3) {
      _tapCount = 0;
      _firstTapAt = null;
      _showConfetti(duration: 2);
    }
  }

  void _showConfetti({num duration = 3}) {
    final dur = Duration(seconds: duration.toInt());
    final overlay = Overlay.of(context);
    final entry = OverlayEntry(builder: (_) => ConfettiOverlay(duration: dur));
    overlay.insert(entry);
    Future.delayed(dur, () {
      entry.remove();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.t('settings_title'))),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(8),
                children: [
                  ListTile(
                    leading: const Icon(Icons.person),
                    trailing: const Icon(Icons.chevron_right),
                    title: Text(t.t('profile')),
                    onTap: widget.onProfile,
                  ),

                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.flag),
                    trailing: const Icon(Icons.chevron_right),
                    title: Text(t.t('settings_stamm')),
                    onTap: widget.onStammSettings,
                  ),
                  ListTile(
                    leading: const Icon(Icons.settings_suggest),
                    trailing: const Icon(Icons.chevron_right),
                    title: Text(t.t('settings_app')),
                    onTap: widget.onAppSettings,
                  ),
                  ListTile(
                    leading: const Icon(Icons.tune),
                    trailing: const Icon(Icons.chevron_right),
                    title: Text(t.t('settings_notifications')),
                    onTap: widget.onNotificationSettings,
                  ),

                  ListTile(
                    leading: const Icon(Icons.build_circle),
                    trailing: const Icon(Icons.chevron_right),
                    title: Text(t.t('settings_debug_tools')),
                    onTap: widget.onDebugTools,
                  ),
                ],
              ),
            ),
            FutureBuilder<PullNotification?>(
              future: _unreadNotificationFuture,
              builder: (context, snapshot) {
                final notification = snapshot.data;
                if (notification == null) {
                  return const SizedBox.shrink();
                }

                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: NotificationCard(
                    notification: notification,
                    onClose: () => _acknowledgeNotification(notification),
                  ),
                );
              },
            ),
            const Divider(height: 1),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _handleTippleTapInTwoSeconds,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 16,
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          t.t('developed_with'),
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.favorite,
                          size: 14,
                          color: theme.colorScheme.error,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          t.t('developed_in_hamburg'),
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${t.t('version_label')}: ${_appVersion ?? '...'}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:nami/core/notifications/pull_notification.dart';
import 'package:nami/core/notifications/pull_notifications_repository_factory.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/presentation/model/auth_session_model.dart';
import 'package:nami/presentation/model/member_edit_model.dart';
import 'package:nami/presentation/notifications/notification_card.dart';
import 'package:nami/presentation/screens/member_edit_page.dart';
import 'package:nami/presentation/widgets/confetti_overlay.dart';
import 'package:nami/services/app_update_service.dart';
import 'package:nami/services/logger_service.dart';
import 'package:nami/services/network_access_policy.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsPage extends StatefulWidget {
  final VoidCallback? onStammSettings;
  final VoidCallback? onNotificationSettings;
  final VoidCallback? onAppSettings;
  final VoidCallback? onMapSettings;
  final VoidCallback? onDebugTools;
  final VoidCallback? onProfile;
  final String? appVersion;

  const SettingsPage({
    super.key,
    this.onStammSettings,
    this.onNotificationSettings,
    this.onAppSettings,
    this.onMapSettings,
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
  late Future<AppUpdateInfo?> _appUpdateFuture;
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
    _appUpdateFuture = _loadAppUpdateInfo();
    _appVersion = widget.appVersion;
    if (_appVersion == null) {
      _loadAppVersion();
    }
  }

  Future<AppUpdateInfo?> _loadAppUpdateInfo() async {
    try {
      return await _resolveAppUpdateService().checkForUpdate();
    } catch (_) {
      return null;
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
    final repo = await createPullNotificationsRepository(
      logger: logger,
      networkAccessPolicy: _resolveNetworkAccessPolicy(),
    );
    await repo.acknowledgeNotification(notification.id);
    if (!mounted) return;
    setState(() {
      _unreadNotificationFuture = _loadUnreadNotification();
    });
  }

  Future<PullNotification?> _loadUnreadNotification() async {
    final logger = context.read<LoggerService>();
    final repo = await createPullNotificationsRepository(
      logger: logger,
      networkAccessPolicy: _resolveNetworkAccessPolicy(),
    );
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

  Future<void> _openStore(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
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

  PullNotification _buildUpdateNotification(
    BuildContext context,
    AppUpdateInfo info,
  ) {
    final t = AppLocalizations.of(context);
    final body = info.isRequired
        ? '${t.t('update_required_body')}\n${t.t('version')} ${info.currentVersion} → ${info.latestVersion}'
        : '${t.t('update_available_body')}\n${t.t('version')} ${info.currentVersion} → ${info.latestVersion}';

    return PullNotification(
      id: 'app-update-${info.latestVersion}-${info.currentVersion}',
      title: LocalizedString(
        de: info.isRequired
            ? t.t('update_required_title')
            : t.t('update_available_title'),
        en: info.isRequired
            ? t.t('update_required_title')
            : t.t('update_available_title'),
      ),
      body: LocalizedString(de: body, en: body),
      type: info.isRequired ? 'urgent' : 'warn',
      externalLink: info.storeUrl,
    );
  }

  PullNotification _buildHitobitoIssueNotification(
    BuildContext context,
    AuthSessionModel authModel,
  ) {
    final t = AppLocalizations.of(context);
    final bodyKey = authModel.requiresInteractiveLogin
        ? 'settings_hitobito_issue_relogin_body'
        : 'settings_hitobito_issue_body';
    final body = t.t(bodyKey);

    return PullNotification(
      id: 'hitobito-issue',
      title: LocalizedString(
        de: t.t('settings_hitobito_issue_title'),
        en: t.t('settings_hitobito_issue_title'),
      ),
      body: LocalizedString(de: body, en: body),
      type: 'warn',
    );
  }

  PullNotification _buildMemberResolutionNotification(int count) {
    return PullNotification(
      id: 'member-resolution-$count',
      title: const LocalizedString(
        de: 'Mitglieds-Aenderungen brauchen Aufmerksamkeit',
        en: 'Member changes need attention',
      ),
      body: LocalizedString(
        de: 'Es gibt $count offene Problemfaelle bei gespeicherten Mitglieds-Aenderungen. Tippe hier, um den ersten Fall zu bearbeiten.',
        en: 'There are $count open issue cases for stored member changes. Tap here to resolve the first one.',
      ),
      type: 'warn',
    );
  }

  Future<void> _openFirstResolution(
    BuildContext context,
    MemberEditModel? memberEditModel,
  ) async {
    final entry = memberEditModel?.firstResolutionEntry;
    if (entry == null) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MemberEditPage(
          mitglied: entry.zielMitglied,
          pendingEntry: entry,
          initialNoticeMessage:
              'Bitte pruefe die betroffenen Felder und sende die Aenderung danach erneut.',
          resolutionEntryPoint: 'settings',
        ),
      ),
    );
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
    final authModel = context.watch<AuthSessionModel>();
    final memberEditModel = context.watch<MemberEditModel?>();
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
                    trailing: widget.onProfile == null
                        ? const Icon(Icons.lock_outline)
                        : const Icon(Icons.chevron_right),
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
                    leading: const Icon(Icons.map_outlined),
                    trailing: const Icon(Icons.chevron_right),
                    title: Text(t.t('settings_map')),
                    onTap: widget.onMapSettings,
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
            if (authModel.hasRemoteAccessIssue)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: NotificationCard(
                  notification: _buildHitobitoIssueNotification(
                    context,
                    authModel,
                  ),
                  onTap: authModel.isConfigured ? authModel.signIn : null,
                ),
              ),
            if ((memberEditModel?.openResolutionCount ?? 0) > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: NotificationCard(
                  notification: _buildMemberResolutionNotification(
                    memberEditModel!.openResolutionCount,
                  ),
                  onTap: () => _openFirstResolution(context, memberEditModel),
                ),
              ),
            FutureBuilder<AppUpdateInfo?>(
              future: _appUpdateFuture,
              builder: (context, snapshot) {
                final updateInfo = snapshot.data;
                if (updateInfo == null) {
                  return const SizedBox.shrink();
                }

                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: NotificationCard(
                    notification: _buildUpdateNotification(context, updateInfo),
                    onTap: () => _openStore(updateInfo.storeUrl),
                  ),
                );
              },
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

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
  final VoidCallback? onMessages;
  final VoidCallback? onImpressum;
  final VoidCallback? onDatenschutz;
  final VoidCallback? onStufenwechsel;
  final VoidCallback? onDebugTools;
  final VoidCallback? onProfile;
  final String? appVersion;

  const SettingsPage({
    super.key,
    this.onStammSettings,
    this.onNotificationSettings,
    this.onAppSettings,
    this.onMapSettings,
    this.onMessages,
    this.onImpressum,
    this.onDatenschutz,
    this.onStufenwechsel,
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
    try {
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
    } catch (_) {}
  }

  Future<PullNotification?> _loadUnreadNotification() async {
    try {
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
    } catch (_) {
      return null;
    }
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

  AppLocalizations _l10nFor(Locale locale) {
    return AppLocalizations(locale);
  }

  PullNotification _buildUpdateNotification(
    BuildContext context,
    AppUpdateInfo info,
  ) {
    final de = _l10nFor(const Locale('de'));
    final en = _l10nFor(const Locale('en'));
    final bodyDe = info.isRequired
        ? '${de.t('update_required_body')}\n${de.t('settings_version_details', {'versionLabel': de.t('version'), 'currentVersion': info.currentVersion, 'latestVersion': info.latestVersion})}'
        : '${de.t('update_available_body')}\n${de.t('settings_version_details', {'versionLabel': de.t('version'), 'currentVersion': info.currentVersion, 'latestVersion': info.latestVersion})}';
    final bodyEn = info.isRequired
        ? '${en.t('update_required_body')}\n${en.t('settings_version_details', {'versionLabel': en.t('version'), 'currentVersion': info.currentVersion, 'latestVersion': info.latestVersion})}'
        : '${en.t('update_available_body')}\n${en.t('settings_version_details', {'versionLabel': en.t('version'), 'currentVersion': info.currentVersion, 'latestVersion': info.latestVersion})}';

    return PullNotification(
      id: 'app-update-${info.latestVersion}-${info.currentVersion}',
      title: LocalizedString(
        de: info.isRequired
            ? de.t('update_required_title')
            : de.t('update_available_title'),
        en: info.isRequired
            ? en.t('update_required_title')
            : en.t('update_available_title'),
      ),
      body: LocalizedString(de: bodyDe, en: bodyEn),
      type: info.isRequired ? 'urgent' : 'warn',
      externalLink: info.storeUrl,
    );
  }

  PullNotification _buildHitobitoIssueNotification(
    BuildContext context,
    AuthSessionModel authModel,
  ) {
    final de = _l10nFor(const Locale('de'));
    final en = _l10nFor(const Locale('en'));
    final bodyKey = authModel.requiresInteractiveLogin
        ? 'settings_hitobito_issue_relogin_body'
        : 'settings_hitobito_issue_body';

    return PullNotification(
      id: 'hitobito-issue',
      title: LocalizedString(
        de: de.t('settings_hitobito_issue_title'),
        en: en.t('settings_hitobito_issue_title'),
      ),
      body: LocalizedString(de: de.t(bodyKey), en: en.t(bodyKey)),
      type: 'warn',
    );
  }

  PullNotification _buildMemberResolutionNotification(
    BuildContext context,
    int count,
  ) {
    final de = _l10nFor(const Locale('de'));
    final en = _l10nFor(const Locale('en'));
    return PullNotification(
      id: 'member-resolution-$count',
      title: LocalizedString(
        de: de.t('settings_member_resolution_title'),
        en: en.t('settings_member_resolution_title'),
      ),
      body: LocalizedString(
        de: de.t('settings_member_resolution_body', {'count': count}),
        en: en.t('settings_member_resolution_body', {'count': count}),
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
          initialNoticeMessage: AppLocalizations.of(
            context,
          ).t('settings_member_resolution_notice'),
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
    final unresolvedCount = (memberEditModel?.openResolutionCount ?? 0);
    final hasIssue = authModel.hasRemoteAccessIssue;
    final visualMessageCount =
        (hasIssue ? 1 : 0) + (unresolvedCount > 0 ? 1 : 0);

    return Scaffold(
      appBar: AppBar(title: Text(t.t('settings_title'))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              margin: EdgeInsets.zero,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: widget.onProfile,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          Icons.person,
                          color: theme.colorScheme.onPrimary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t.t('profile'),
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Arbeitskontext, Rollen und Konto',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        widget.onProfile == null
                            ? Icons.lock_outline
                            : Icons.chevron_right,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              margin: EdgeInsets.zero,
              color: const Color(0xFFFFF8E1),
              child: ListTile(
                onTap: widget.onMessages,
                leading: const Icon(Icons.warning_amber_rounded),
                title: const Text('Meldungen'),
                subtitle: Text(
                  hasIssue
                      ? 'Hitobito nicht erreichbar - lokale Daten aktiv.'
                      : 'Systemhinweise und Sync-Meldungen.',
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade700,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$visualMessageCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (hasIssue)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: NotificationCard(
                  notification: _buildHitobitoIssueNotification(
                    context,
                    authModel,
                  ),
                  onTap: authModel.isConfigured ? authModel.signIn : null,
                ),
              ),
            if (unresolvedCount > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: NotificationCard(
                  notification: _buildMemberResolutionNotification(
                    context,
                    unresolvedCount,
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
                  padding: const EdgeInsets.only(bottom: 12),
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
                  padding: const EdgeInsets.only(bottom: 12),
                  child: NotificationCard(
                    notification: notification,
                    onClose: () => _acknowledgeNotification(notification),
                  ),
                );
              },
            ),
            _SettingsSectionLabel(label: 'Schnellzugriff'),
            Card(
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  _SettingsNavTile(
                    icon: Icons.swap_horiz,
                    title: 'Stufenwechsel',
                    subtitle: 'Mitglieder in neue Stufe versetzen',
                    onTap: widget.onStufenwechsel,
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  _SettingsNavTile(
                    icon: Icons.map,
                    title: t.t('settings_map'),
                    subtitle: 'Stammes- und DV-Karte',
                    onTap: widget.onMapSettings,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _SettingsSectionLabel(label: 'Einstellungen'),
            Card(
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  _SettingsNavTile(
                    icon: Icons.home,
                    title: t.t('settings_stamm'),
                    subtitle: 'Daten, Altersgrenzen',
                    onTap: widget.onStammSettings,
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  _SettingsNavTile(
                    icon: Icons.tune,
                    title: t.t('settings_app'),
                    subtitle: 'Darstellung, Sicherheit, Verhalten',
                    onTap: widget.onAppSettings,
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  _SettingsNavTile(
                    icon: Icons.notifications,
                    title: t.t('settings_notifications'),
                    subtitle: 'Geburtstage, Erinnerungen',
                    onTap: widget.onNotificationSettings,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _SettingsSectionLabel(label: 'Entwicklung'),
            Card(
              margin: EdgeInsets.zero,
              child: _SettingsNavTile(
                icon: Icons.bug_report,
                title: t.t('settings_debug_tools'),
                subtitle: 'Fehlerberichte, Cache, Tools',
                onTap: widget.onDebugTools,
              ),
            ),
            const SizedBox(height: 12),
            _SettingsSectionLabel(label: 'Rechtliches'),
            Card(
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  _SettingsNavTile(
                    icon: Icons.gavel,
                    title: 'Impressum',
                    onTap: widget.onImpressum,
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  _SettingsNavTile(
                    icon: Icons.shield,
                    title: 'Datenschutz',
                    onTap: widget.onDatenschutz,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
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

class _SettingsSectionLabel extends StatelessWidget {
  const _SettingsSectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 6),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _SettingsNavTile extends StatelessWidget {
  const _SettingsNavTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: Icon(onTap == null ? Icons.lock_outline : Icons.chevron_right),
    );
  }
}

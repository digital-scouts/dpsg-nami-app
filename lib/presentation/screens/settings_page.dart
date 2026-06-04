import 'package:flutter/material.dart';
import 'package:nami/core/notifications/pull_notifications_repository_factory.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/presentation/model/auth_session_model.dart';
import 'package:nami/presentation/model/member_edit_model.dart';
import 'package:nami/presentation/notifications/notifications_hub.dart';
import 'package:nami/presentation/widgets/confetti_overlay.dart';
import 'package:nami/presentation/widgets/section_header.dart';
import 'package:nami/services/app_update_service.dart';
import 'package:nami/services/logger_service.dart';
import 'package:nami/services/network_access_policy.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

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
  late Future<List<AppHubNotification>> _unreadExternalNotificationsFuture;

  @override
  void initState() {
    super.initState();
    _unreadExternalNotificationsFuture = _loadUnreadExternalNotifications();
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

  Future<List<AppHubNotification>> _loadUnreadExternalNotifications() async {
    try {
      final logger = context.read<LoggerService>();
      final repo = await createPullNotificationsRepository(
        logger: logger,
        networkAccessPolicy: _resolveNetworkAccessPolicy(),
      );
      final notifications = await repo.fetchNotifications();
      final acknowledged = await repo.getAcknowledgedIds();
      return NotificationsHub.mapUnreadExternal(
        notifications: notifications,
        acknowledged: acknowledged,
      );
    } catch (_) {
      return const <AppHubNotification>[];
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
      _showConfetti();
    }
  }

  void _showConfetti() {
    final overlay = Overlay.of(context);
    final entry = OverlayEntry(builder: (_) => const ConfettiOverlay());
    overlay.insert(entry);
    Future<void>.delayed(const Duration(seconds: 3), () {
      if (entry.mounted) {
        entry.remove();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context);

    return Consumer<AuthSessionModel>(
      builder: (context, authModel, _) {
        final unresolvedCount =
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
                    unresolvedCount: unresolvedCount,
                    updateInfo: updateSnapshot.data,
                  ),
                  external:
                      notificationSnapshot.data ?? const <AppHubNotification>[],
                );
                final primaryMessage = hubMessages.isNotEmpty
                    ? hubMessages.first
                    : null;

                return SafeArea(
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                      if (primaryMessage != null) ...[
                        _SettingsMessagesBanner(
                          key: const Key('settings-messages-banner'),
                          title: primaryMessage.title.resolve(locale),
                          body: primaryMessage.body.resolve(locale),
                          count: hubMessages.length,
                          hasStack: hubMessages.length > 1,
                          onTap: widget.onMessages,
                        ),
                        const SizedBox(height: 12),
                      ],
                      const DpsgSectionHeader(label: 'Schnellzugriff'),
                      Card(
                        margin: EdgeInsets.zero,
                        child: Column(
                          children: [
                            _SettingsNavTile(
                              icon: Icons.swap_horiz,
                              iconBackgroundColor: const Color(0xFF00823C),
                              title: 'Stufenwechsel',
                              subtitle: 'Mitglieder in neue Stufe versetzen',
                              onTap: widget.onStufenwechsel,
                            ),
                            const _SettingsRowDivider(),
                            _SettingsNavTile(
                              icon: Icons.map,
                              iconBackgroundColor: const Color(0xFF007AFF),
                              title: t.t('settings_map'),
                              subtitle: 'Stammes- und DV-Karte',
                              onTap: widget.onMapSettings,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      const DpsgSectionHeader(label: 'Einstellungen'),
                      Card(
                        margin: EdgeInsets.zero,
                        child: Column(
                          children: [
                            _SettingsNavTile(
                              icon: Icons.home,
                              iconBackgroundColor: theme.colorScheme.primary,
                              title: t.t('settings_stamm'),
                              subtitle: 'Daten, Altersgrenzen',
                              onTap: widget.onStammSettings,
                            ),
                            const _SettingsRowDivider(),
                            _SettingsNavTile(
                              icon: Icons.tune,
                              iconBackgroundColor: const Color(0xFF34C759),
                              title: t.t('settings_app'),
                              subtitle: 'Darstellung, Sicherheit, Verhalten',
                              onTap: widget.onAppSettings,
                            ),
                            const _SettingsRowDivider(),
                            _SettingsNavTile(
                              icon: Icons.notifications,
                              iconBackgroundColor: const Color(0xFFFF9500),
                              title: t.t('settings_notifications'),
                              subtitle: 'Geburtstage, Erinnerungen',
                              onTap: widget.onNotificationSettings,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      const DpsgSectionHeader(label: 'Entwicklung'),
                      Card(
                        margin: EdgeInsets.zero,
                        child: _SettingsNavTile(
                          icon: Icons.bug_report,
                          iconBackgroundColor: const Color(0xFF8E8E93),
                          title: t.t('settings_debug_tools'),
                          subtitle: 'Fehlerberichte, Cache, Tools',
                          onTap: widget.onDebugTools,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const DpsgSectionHeader(label: 'Rechtliches'),
                      Card(
                        margin: EdgeInsets.zero,
                        child: Column(
                          children: [
                            _SettingsNavTile(
                              icon: Icons.gavel,
                              iconBackgroundColor: theme.colorScheme.tertiary,
                              title: 'Impressum',
                              onTap: widget.onImpressum,
                            ),
                            const _SettingsRowDivider(),
                            _SettingsNavTile(
                              icon: Icons.shield,
                              iconBackgroundColor: theme.colorScheme.tertiary,
                              title: 'Datenschutz',
                              onTap: widget.onDatenschutz,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      const _SettingsRowDivider(indent: 16),
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
                );
              },
            );
          },
        );
      },
    );
  }
}

class _SettingsMessagesBanner extends StatelessWidget {
  final String title;
  final String body;
  final int count;
  final bool hasStack;
  final VoidCallback? onTap;

  const _SettingsMessagesBanner({
    super.key,
    required this.title,
    required this.body,
    required this.count,
    required this.hasStack,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bannerBackground = isDark
        ? const Color(0xFF2A2010)
        : const Color(0xFFFFF8E1);
    final borderColor = isDark
        ? const Color(0xFF8A6A00)
        : const Color(0xFFFFB300);
    final textColor = isDark
        ? const Color(0xFFFFE7A3)
        : const Color(0xFF795B00);

    final banner = Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: bannerBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: textColor,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    key: const Key('settings-messages-badge'),
                    height: 20,
                    constraints: const BoxConstraints(minWidth: 20),
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCC1F2F),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$count',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 16,
                    color: borderColor,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      body,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: textColor,
                        height: 1.35,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    final showSecondLayer = count >= 2;
    final showFirstLayer = count >= 3;

    if (!showSecondLayer) {
      return banner;
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (showFirstLayer)
          Positioned(
            key: const Key('settings-messages-stack-back-2'),
            left: 12,
            right: 12,
            top: 8,
            bottom: -5,
            child: IgnorePointer(
              child: Opacity(
                opacity: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: bannerBackground,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                  ),
                ),
              ),
            ),
          ),
        Positioned(
          key: const Key('settings-messages-stack-back-1'),
          left: 6,
          right: 6,
          top: 4,
          bottom: 0,
          child: IgnorePointer(
            child: Opacity(
              opacity: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: bannerBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                ),
              ),
            ),
          ),
        ),

        Padding(padding: const EdgeInsets.only(bottom: 8), child: banner),
      ],
    );
  }
}

class _SettingsRowDivider extends StatelessWidget {
  final double indent;
  const _SettingsRowDivider({this.indent = 68});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).dividerColor.withValues(alpha: 0.6);
    return Divider(height: 1, thickness: 1, indent: indent, color: color);
  }
}

class _SettingsNavTile extends StatelessWidget {
  final IconData icon;
  final Color iconBackgroundColor;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  const _SettingsNavTile({
    required this.icon,
    required this.iconBackgroundColor,
    required this.title,
    this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: iconBackgroundColor.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Icon(icon, color: iconBackgroundColor, size: 20),
      ),
      title: Text(title, style: theme.textTheme.titleSmall),
      subtitle: subtitle == null
          ? null
          : Text(subtitle!, style: theme.textTheme.bodySmall),
      trailing: Icon(
        onTap == null ? Icons.lock_outline : Icons.chevron_right,
        size: 20,
      ),
      enabled: onTap != null,
      onTap: onTap,
    );
  }
}

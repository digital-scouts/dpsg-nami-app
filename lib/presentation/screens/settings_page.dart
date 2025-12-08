import 'package:flutter/material.dart';
import 'package:nami/l10n/app_localizations.dart';

class SettingsPage extends StatelessWidget {
  final String userName;
  final String userId;
  final VoidCallback? onStammSettings;
  final VoidCallback? onNotifications;
  final VoidCallback? onAppSettings;
  final VoidCallback? onDebugTools;
  final VoidCallback? onProfile;
  final VoidCallback onLogout;
  final String appVersion;

  const SettingsPage({
    super.key,
    required this.userName,
    required this.userId,
    this.onStammSettings,
    this.onNotifications,
    this.onAppSettings,
    this.onDebugTools,
    this.onProfile,
    required this.onLogout,
    this.appVersion = 'v0.0.0',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.t('settings_title'))),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.asset(
                    'assets/icon/icon-blank.png',
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(userName, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text('ID: $userId', style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(8),
                children: [
                  ListTile(
                    leading: const Icon(Icons.person),
                    trailing: const Icon(Icons.chevron_right),
                    title: Text(t.t('profile')),
                    onTap: onProfile,
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.flag),
                    trailing: const Icon(Icons.chevron_right),
                    title: Text(t.t('stamm_settings')),
                    onTap: onStammSettings,
                  ),
                  ListTile(
                    leading: const Icon(Icons.settings_suggest),
                    trailing: const Icon(Icons.chevron_right),
                    title: Text(t.t('app_settings')),
                    onTap: onAppSettings,
                  ),
                  ListTile(
                    leading: const Icon(Icons.notifications),
                    trailing: const Icon(Icons.chevron_right),
                    title: Text(t.t('notifications_enable')),
                    onTap: onNotifications,
                  ),

                  ListTile(
                    leading: const Icon(Icons.build_circle),
                    trailing: const Icon(Icons.chevron_right),
                    title: Text(t.t('debug_tools')),
                    onTap: onDebugTools,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              child: ListTile(
                leading: Icon(
                  Icons.logout,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: Text(t.t('logout')),
                onTap: onLogout,
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              child: Column(
                children: [
                  Text(
                    t.t('developed_in_hamburg'),
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${t.t('version_label')}: $appVersion',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

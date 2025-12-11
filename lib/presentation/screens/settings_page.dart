import 'package:flutter/material.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/widgets/confetti_overlay.dart';

class SettingsPage extends StatefulWidget {
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
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  int _tapCount = 0;
  DateTime? _firstTapAt;

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
                      Text(widget.userName, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text(
                        'ID: ${widget.userId}',
                        style: theme.textTheme.bodySmall,
                      ),
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
                    onTap: widget.onProfile,
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.flag),
                    trailing: const Icon(Icons.chevron_right),
                    title: Text(t.t('stamm_settings')),
                    onTap: widget.onStammSettings,
                  ),
                  ListTile(
                    leading: const Icon(Icons.settings_suggest),
                    trailing: const Icon(Icons.chevron_right),
                    title: Text(t.t('app_settings')),
                    onTap: widget.onAppSettings,
                  ),
                  ListTile(
                    leading: const Icon(Icons.notifications),
                    trailing: const Icon(Icons.chevron_right),
                    title: Text(t.t('notifications_enable')),
                    onTap: widget.onNotifications,
                  ),

                  ListTile(
                    leading: const Icon(Icons.build_circle),
                    trailing: const Icon(Icons.chevron_right),
                    title: Text(t.t('debug_tools')),
                    onTap: widget.onDebugTools,
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
                onTap: widget.onLogout,
              ),
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
                    Text(
                      t.t('developed_in_hamburg'),
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${t.t('version_label')}: ${widget.appVersion}',
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

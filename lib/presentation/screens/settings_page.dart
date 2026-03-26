import 'package:flutter/material.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/presentation/widgets/confetti_overlay.dart';

class SettingsPage extends StatefulWidget {
  final VoidCallback? onStammSettings;
  final VoidCallback? onNotifications;
  final VoidCallback? onNotificationSettings;
  final VoidCallback? onAppSettings;
  final VoidCallback? onDebugTools;
  final VoidCallback? onProfile;
  final String appVersion;

  const SettingsPage({
    super.key,
    this.onStammSettings,
    this.onNotifications,
    this.onNotificationSettings,
    this.onAppSettings,
    this.onDebugTools,
    this.onProfile,
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
                    leading: const Icon(Icons.notifications),
                    trailing: const Icon(Icons.chevron_right),
                    title: Text(t.t('pull_notifications_title')),
                    onTap: widget.onNotifications,
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

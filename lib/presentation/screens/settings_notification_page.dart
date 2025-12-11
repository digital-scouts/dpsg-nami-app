import 'package:flutter/material.dart';
import 'package:nami/l10n/app_localizations.dart';

class SettingsNotificationPage extends StatefulWidget {
  final bool notificationsEnabled;
  final ValueChanged<bool>? onNotificationsChanged;

  const SettingsNotificationPage({
    super.key,
    this.notificationsEnabled = true,
    this.onNotificationsChanged,
  });

  @override
  State<SettingsNotificationPage> createState() =>
      _SettingsNotificationPageState();
}

class _SettingsNotificationPageState extends State<SettingsNotificationPage> {
  late bool _notificationsEnabled;

  @override
  void initState() {
    super.initState();
    _notificationsEnabled = widget.notificationsEnabled;
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.t('settings_notifications'))),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          SwitchListTile(
            title: Text(t.t('notifications_enable')),
            value: _notificationsEnabled,
            onChanged: (v) {
              setState(() => _notificationsEnabled = v);
              widget.onNotificationsChanged?.call(v);
            },
          ),
        ],
      ),
    );
  }
}

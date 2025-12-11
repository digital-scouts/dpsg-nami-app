import 'package:flutter/material.dart';
import 'package:nami/domain/taetigkeit/stufe.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/presentation/widgets/stufen_choice_chips.dart';

class SettingsNotificationPage extends StatefulWidget {
  final bool notificationsEnabled;
  final ValueChanged<bool>? onNotificationsChanged;
  final Set<Stufe> geburstagsbenachrichtigungStufen;
  final void Function(Set<Stufe> stufen)?
  geburstagsbenachrichtigungStufenChanged;

  const SettingsNotificationPage({
    super.key,
    this.notificationsEnabled = true,
    this.onNotificationsChanged,
    this.geburstagsbenachrichtigungStufen = const {
      Stufe.biber,
      Stufe.woelfling,
      Stufe.jungpfadfinder,
      Stufe.pfadfinder,
      Stufe.rover,
      Stufe.leitung,
    },
    this.geburstagsbenachrichtigungStufenChanged,
  });

  @override
  State<SettingsNotificationPage> createState() =>
      _SettingsNotificationPageState();
}

class _SettingsNotificationPageState extends State<SettingsNotificationPage> {
  late bool _notificationsEnabled;
  late Set<Stufe> _geburstagsbenachrichtigungStufen;

  @override
  void initState() {
    super.initState();
    _notificationsEnabled = widget.notificationsEnabled;
    _geburstagsbenachrichtigungStufen = widget.geburstagsbenachrichtigungStufen;
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
          const SizedBox(height: 16),
          Text(
            'Geburstagsbenachrichtigungen',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          StufenChoiceChips(
            singleSelect: false,
            showBiber: true,
            showLeader: true,
            ausgewaehlteStufen: _geburstagsbenachrichtigungStufen,
            ausgewaehlteStufenChanged: (stufen) {
              setState(() => _geburstagsbenachrichtigungStufen = stufen);
              widget.geburstagsbenachrichtigungStufenChanged?.call(stufen);
            },
          ),
        ],
      ),
    );
  }
}

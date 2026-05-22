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
  bool _birthdayEnabled = true;
  String _birthdayTiming = 'vorabend';
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
          Card(
            margin: EdgeInsets.zero,
            child: SwitchListTile(
              title: Text(t.t('notifications_enable')),
              subtitle: const Text('Push-Mitteilungen empfangen'),
              value: _notificationsEnabled,
              onChanged: (v) {
                setState(() => _notificationsEnabled = v);
                widget.onNotificationsChanged?.call(v);
              },
            ),
          ),
          const SizedBox(height: 16),
          Opacity(
            opacity: _notificationsEnabled ? 1 : 0.45,
            child: IgnorePointer(
              ignoring: !_notificationsEnabled,
              child: Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: const Text('Geburtstagserinnerungen'),
                        subtitle: const Text(
                          'Benachrichtigungen bei Geburtstagen',
                        ),
                        value: _birthdayEnabled,
                        onChanged: (v) {
                          setState(() => _birthdayEnabled = v);
                        },
                      ),
                      if (_birthdayEnabled) ...[
                        const Divider(height: 1, indent: 16, endIndent: 16),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Stufen',
                                style: Theme.of(context).textTheme.labelLarge,
                              ),
                              const SizedBox(height: 8),
                              StufenChoiceChips(
                                singleSelect: false,
                                showBiber: true,
                                showLeader: true,
                                ausgewaehlteStufen:
                                    _geburstagsbenachrichtigungStufen,
                                ausgewaehlteStufenChanged: (stufen) {
                                  setState(
                                    () => _geburstagsbenachrichtigungStufen =
                                        stufen,
                                  );
                                  widget.geburstagsbenachrichtigungStufenChanged
                                      ?.call(stufen);
                                },
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Zeitpunkt',
                                style: Theme.of(context).textTheme.labelLarge,
                              ),
                              RadioGroup<String>(
                                groupValue: _birthdayTiming,
                                onChanged: (value) {
                                  if (value == null) return;
                                  setState(() => _birthdayTiming = value);
                                },
                                child: Column(
                                  children: const [
                                    RadioListTile<String>(
                                      value: 'vorabend',
                                      contentPadding: EdgeInsets.zero,
                                      title: Text('18 Uhr Vorabend'),
                                    ),
                                    RadioListTile<String>(
                                      value: 'morgen',
                                      contentPadding: EdgeInsets.zero,
                                      title: Text('9 Uhr morgens'),
                                    ),
                                    RadioListTile<String>(
                                      value: 'mittag',
                                      contentPadding: EdgeInsets.zero,
                                      title: Text('12 Uhr mittags'),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

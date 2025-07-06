import 'package:flutter/material.dart';
import 'package:nami/screens/widgets/notification_test_widget.dart';
import 'package:nami/utilities/hive/settings.dart';
import 'package:nami/utilities/notifications/birthday_notifications.dart';
import 'package:nami/utilities/stufe.dart';
import 'package:wiredash/wiredash.dart';

class SettingsBenachrichtigung extends StatefulWidget {
  const SettingsBenachrichtigung({super.key});

  @override
  State<SettingsBenachrichtigung> createState() =>
      _SettingsBenachrichtigungState();
}

class _SettingsBenachrichtigungState extends State<SettingsBenachrichtigung> {
  List<Stufe> _selectedStufen = getGeburtstagsbenachrichtigungenGruppen();
  bool _benachrichtigungenActive = getBenachrichtigungenActive();
  bool _benachrichtigungenAmVorabend = getBenachrichtigungenAmVorabend();

  void _onStufeChanged(Stufe stufe, bool selected) {
    setState(() {
      if (selected) {
        _selectedStufen.add(stufe);
      } else {
        _selectedStufen.remove(stufe);
      }
      setGeburtstagsbenachrichtigungenGruppen(_selectedStufen);
      BirthdayNotificationService.scheduleAllBirthdays();
      // Nach dem Setzen die aktuelle Auswahl aus dem Storage neu laden,
      // damit externe Änderungen (z.B. durch andere Widgets) übernommen werden
      _selectedStufen = getGeburtstagsbenachrichtigungenGruppen();
    });
  }

  void _onBenachrichtigungenActiveChanged(bool value) {
    Wiredash.trackEvent(
      'Geburtstagsbenachrichtigung',
      data: {'type': 'Benachrichtigungen aktivieren', 'value': value},
    );
    setState(() {
      _benachrichtigungenActive = value;
      setBenachrichtigungenActive(value);
      if (!value) {
        BirthdayNotificationService.cancelAllBirthdayNotifications();
      } else {
        BirthdayNotificationService.scheduleAllBirthdays();
      }
    });
  }

  void _onBenachrichtigungenAmVorabendChanged(bool value) {
    Wiredash.trackEvent(
      'Geburtstagsbenachrichtigung',
      data: {'type': 'Benachrichtigungszeit ändern', 'amVorabend': value},
    );
    setState(() {
      _benachrichtigungenAmVorabend = value;
      setBenachrichtigungenAmVorabend(value);
      // Alle Benachrichtigungen neu planen mit neuer Zeit
      if (_benachrichtigungenActive) {
        BirthdayNotificationService.scheduleAllBirthdays();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final allStufen = [
      Stufe.BIBER,
      Stufe.WOELFLING,
      Stufe.JUNGPADFINDER,
      Stufe.PFADFINDER,
      Stufe.ROVER,
      Stufe.LEITER,
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Benachrichtigungen')),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Benachrichtigungen aktivieren'),
            value: _benachrichtigungenActive,
            onChanged: (value) => _onBenachrichtigungenActiveChanged(value),
          ),
          SwitchListTile(
            title: const Text('Benachrichtigungen am Vorabend (22 Uhr)'),
            subtitle: Text(
              _benachrichtigungenAmVorabend
                  ? 'Benachrichtigung am Vorabend um 22 Uhr'
                  : 'Benachrichtigung am Geburtstag um 10 Uhr',
            ),
            value: _benachrichtigungenAmVorabend,
            onChanged: _benachrichtigungenActive
                ? (value) => _onBenachrichtigungenAmVorabendChanged(value)
                : null,
          ),
          const Divider(height: 1),
          const ListTile(
            title: Text('Geburtstagsbenachrichtigungen für folgende Stufen:'),
          ),
          ...allStufen.map(
            (stufe) => CheckboxListTile(
              title: Text(stufe.shortDisplay),
              value: _selectedStufen.contains(stufe),
              onChanged: _benachrichtigungenActive
                  ? (val) => _onStufeChanged(stufe, val ?? false)
                  : null,
            ),
          ),
          const NotificationTestWidget(),
        ],
      ),
    );
  }
}

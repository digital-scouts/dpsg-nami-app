import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:nami/utilities/hive/settings.dart';
import 'package:nami/utilities/notifications/birthday_notifications.dart';
import 'package:nami/utilities/stufe.dart';

class SettingsBenachrichtigung extends StatefulWidget {
  const SettingsBenachrichtigung({super.key});

  @override
  State<SettingsBenachrichtigung> createState() =>
      _SettingsBenachrichtigungState();
}

class _SettingsBenachrichtigungState extends State<SettingsBenachrichtigung> {
  List<Stufe> _selectedStufen = getGeburtstagsbenachrichtigungenGruppen();
  bool _benachrichtigungenActive = getBenachrichtigungenActive();

  int _testCountdown = 0;
  bool _testButtonDisabled = false;

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

  Widget _buildShowNotificationsButton() {
    return ListTile(
      title: const Text('Geplante Benachrichtigungen anzeigen'),
      leading: const Icon(Icons.info),
      onTap: () async {
        List<PendingNotificationRequest> notifications =
            await BirthdayNotificationService.getAllPlannedNotifications();

        showDialog(
          context: context,
          builder: (context) {
            if (notifications.isEmpty) {
              return AlertDialog(
                title: const Text('Geplante Benachrichtigungen'),
                content:
                    const Text('Keine geplanten Benachrichtigungen gefunden.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('OK'),
                  ),
                ],
              );
            }
            return AlertDialog(
              title: const Text('Geplante Benachrichtigungen'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: notifications.length,
                  itemBuilder: (context, index) {
                    final n = notifications[index];
                    return ListTile(
                      title: Text(n.title ?? 'Kein Titel'),
                      subtitle: Text(n.body ?? ''),
                      trailing: Text(n.payload.toString()),
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildShowTestnachrichtButton() {
    return ListTile(
      title: _testCountdown > 0
          ? Text('Test-Benachrichtigung in $_testCountdown Sekunden...')
          : const Text('Test-Benachrichtigung senden'),
      leading: const Icon(Icons.notifications),
      onTap: _testButtonDisabled
          ? null
          : () async {
              setState(() {
                _testButtonDisabled = true;
                _testCountdown = 5;
              });

              for (int i = 4; i >= 2; i--) {
                await Future.delayed(const Duration(seconds: 1));
                setState(() {
                  _testCountdown = i;
                });
              }

              BirthdayNotificationService.callTestBenachrichtigung(
                  duration: const Duration(seconds: 1));

              for (int i = 1; i >= 0; i--) {
                await Future.delayed(const Duration(seconds: 1));
                setState(() {
                  _testCountdown = i;
                });
              }

              setState(() {
                _testButtonDisabled = false;
                _testCountdown = 0;
              });
            },
    );
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
      appBar: AppBar(
        title: const Text('Benachrichtigungen'),
      ),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Benachrichtigungen aktivieren'),
            value: _benachrichtigungenActive,
            onChanged: (value) => _onBenachrichtigungenActiveChanged(value),
          ),
          const ListTile(
            title: Text('Geburtstagsbenachrichtigungen für folgende Stufen:'),
          ),
          ...allStufen.map((stufe) => CheckboxListTile(
                title: Text(stufe.shortDisplay),
                value: _selectedStufen.contains(stufe),
                onChanged: _benachrichtigungenActive
                    ? (val) => _onStufeChanged(stufe, val ?? false)
                    : null,
              )),
          const Divider(height: 1),
          _buildShowNotificationsButton(),
          _buildShowTestnachrichtButton(),
        ],
      ),
    );
  }
}

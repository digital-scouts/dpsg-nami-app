import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:nami/screens/settings/data_change_history_page.dart';
import 'package:nami/screens/utilities/new_version_info_screen.dart';
import 'package:nami/utilities/app.state.dart';
import 'package:nami/utilities/hive/settings.dart';
import 'package:nami/utilities/notifications.dart';
import 'package:nami/utilities/notifications/birthday_notifications.dart'
    show BirthdayNotificationService;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:wiredash/wiredash.dart';

class SettingsDebug extends StatefulWidget {
  const SettingsDebug({super.key});

  @override
  State<SettingsDebug> createState() => _SettingsDebugState();
}

class _SettingsDebugState extends State<SettingsDebug> {
  Widget _buildSync() {
    return ListTile(
      title: const Text('Aktualisiere die Mitgliedsdaten'),
      leading: const Icon(Icons.sync),
      onTap: () {
        Wiredash.trackEvent('Settings', data: {'type': 'SyncData'});
        AppStateHandler().setLoadDataState(loadAll: false);
      },
      subtitle: Text(
          "Vor ${DateTime.now().difference(getLastNamiSync()).inDays.toString()} Tagen"),
    );
  }

  Widget _buildForceBSync() {
    return ListTile(
      title: const Text('Fehlerhafte Daten korrigieren'),
      subtitle: const Text('Alle Daten werden neu geladen'),
      leading: const Icon(Icons.sync),
      onTap: () {
        Wiredash.trackEvent('Settings', data: {'type': 'SyncData forced'});
        AppStateHandler().setLoadDataState(loadAll: true);
      },
    );
  }

  Widget _buildShowDataHistory() {
    return ListTile(
      title: const Text('Syncronisationshistorie'),
      leading: const Icon(Icons.info),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const DataChangeHistoryPage(),
          ),
        );
      },
    );
  }

  Widget _buildShareLogs() {
    return ListTile(
      title: const Text('Teile Logs'),
      leading: const Icon(Icons.share),
      onTap: () {
        Wiredash.trackEvent('Settings', data: {'type': 'share logs'});
        showSendLogsDialog();
      },
    );
  }

  Widget _buildChangelogButton() {
    return ListTile(
      title: const Text('Changelog'),
      leading: const Icon(Icons.info),
      onTap: () async {
        final packageInfo = await PackageInfo.fromPlatform();
        final appVersion = packageInfo.version;
        Navigator.push(
          // ignore: use_build_context_synchronously
          context,
          MaterialPageRoute(
              builder: (context) => NewVersionInfoScreen(
                    currentVersion: appVersion,
                  )),
        );
      },
    );
  }

  showNotifications(List<PendingNotificationRequest> notifications) {
    showDialog(
      context: context,
      builder: (context) {
        if (notifications.isEmpty) {
          return AlertDialog(
            title: const Text('Geplante Benachrichtigungen'),
            content: const Text('Keine geplanten Benachrichtigungen gefunden.'),
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
  }

  Widget _buildShowNotificationsButton() {
    return ListTile(
      title: const Text('Geplante Benachrichtigungen anzeigen'),
      leading: const Icon(Icons.info),
      onTap: () async {
        List<PendingNotificationRequest> notifications =
            await BirthdayNotificationService.getAllPlannedNotifications();

        showNotifications(notifications);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug & Tools'),
      ),
      body: ListView(
        children: [
          _buildSync(),
          _buildForceBSync(),
          _buildShowDataHistory(),
          _buildShareLogs(),
          _buildChangelogButton(),
          _buildShowNotificationsButton(),
        ],
      ),
    );
  }
}

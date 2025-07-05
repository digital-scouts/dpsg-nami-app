import 'package:flutter/material.dart';
import 'package:nami/screens/settings/data_change_history_page.dart';
import 'package:nami/screens/utilities/new_version_info_screen.dart';
import 'package:nami/utilities/app.state.dart';
import 'package:nami/utilities/hive/settings.dart';
import 'package:nami/utilities/notifications.dart';
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
        ],
      ),
    );
  }
}

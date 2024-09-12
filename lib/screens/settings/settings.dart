import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:nami/screens/widgets/stamm_heim_setting.dart';
import 'package:nami/screens/widgets/stufenwechsel_alter_setting.dart';
import 'package:nami/screens/widgets/stufenwechsel_datum_setting.dart';
import 'package:nami/utilities/app.state.dart';
import 'package:nami/utilities/helper_functions.dart';
import 'package:nami/utilities/notifications.dart';
import 'package:nami/utilities/stufe.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:wiredash/wiredash.dart';

import '../../utilities/hive/settings.dart';

class Settings extends StatefulWidget {
  const Settings({super.key});

  @override
  State<Settings> createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
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
      title: const Text('Lade alle Daten neu'),
      leading: const Icon(Icons.sync),
      onTap: () {
        Wiredash.trackEvent('Settings', data: {'type': 'SyncData forced'});
        AppStateHandler().setLoadDataState(loadAll: true);
      },
    );
  }

  bool isValidInput(String text) {
    RegExp regex = RegExp(r'^\d{0,2}-\d{0,2}$');
    return regex.hasMatch(text);
  }

  _buildBiometricAuthentication() {
    return ListTile(
      title: const Text('Biometrische Authentifizierung'),
      leading: const Icon(Icons.fingerprint),
      trailing: Switch(
        value: getBiometricAuthenticationEnabled(),
        onChanged: (value) {
          setBiometricAuthenticationEnabled(value);
        },
      ),
    );
  }

  _buildDataLoadingOverWifiOnly() {
    return ListTile(
      title: const Text('Optionale Daten nur über WLAN laden'),
      leading: const Icon(Icons.wifi),
      trailing: Switch(
        value: getDataLoadingOverWifiOnly(),
        onChanged: (value) {
          setDataLoadingOverWifiOnly(value);
        },
      ),
    );
  }

  _buildShareLogs() {
    return ListTile(
      title: const Text('Teile Logs'),
      leading: const Icon(Icons.share),
      onTap: () {
        Wiredash.trackEvent('Settings', data: {'type': 'share logs'});
        showSendLogsDialog();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Center(child: Text('Settings')),
      ),
      body: ValueListenableBuilder(
        valueListenable: settingsBox.listenable(),
        builder: (context, _, __) {
          return ListView(
            children: [
              _buildSync(),
              _buildForceBSync(),
              const Divider(height: 1),
              const StufenwechelDatumSetting(),
              const StufenwechselAlterSetting(stufe: Stufe.BIBER),
              const StufenwechselAlterSetting(stufe: Stufe.WOELFLING),
              const StufenwechselAlterSetting(stufe: Stufe.JUNGPADFINDER),
              const StufenwechselAlterSetting(stufe: Stufe.PFADFINDER),
              const StufenwechselAlterSetting(stufe: Stufe.ROVER),
              const Divider(height: 1),
              const StammHeimSetting(),
              const Divider(height: 1),
              _buildBiometricAuthentication(),
              _buildDataLoadingOverWifiOnly(),
              const Divider(height: 1),
              _buildShareLogs(),
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: FutureBuilder<MapEntry<PackageInfo, String>>(
                  future: Future.wait([
                    PackageInfo.fromPlatform(),
                    getGitCommitId(),
                  ]).then((results) => MapEntry(
                      results[0] as PackageInfo, results[1] as String)),
                  builder: (BuildContext context,
                      AsyncSnapshot<MapEntry<PackageInfo, String>> snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const CircularProgressIndicator();
                    } else {
                      final String version =
                          snapshot.data?.key.version ?? 'Unknown';
                      final String commitId =
                          snapshot.data?.value.substring(0, 8) ?? 'Unknown';
                      return Text('Version: $version | Commit: $commitId');
                    }
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:nami/screens/utilities/welcome_screen.dart';
import 'package:nami/screens/widgets/stamm_heim_setting.dart';
import 'package:nami/screens/widgets/stufenwechsel_datum_setting.dart';
import 'package:nami/utilities/app.state.dart';
import 'package:nami/utilities/helper_functions.dart';
import 'package:nami/utilities/notifications.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../utilities/hive/settings.dart';

class Settings extends StatelessWidget {
  const Settings({Key? key}) : super(key: key);

  Widget _buildSync() {
    return ListTile(
      title: const Text('Aktualisiere die Mitgliedsdaten'),
      leading: const Icon(Icons.sync),
      onTap: () {
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
      onTap: () => showSendLogsDialog(),
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
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildSync(),
              _buildForceBSync(),
              const Divider(height: 1),
              const StufenwechelDatumSetting(),
              const StammHeimSetting(),
              _buildBiometricAuthentication(),
              _buildDataLoadingOverWifiOnly(),
              _buildShareLogs(),
              ElevatedButton(
                child: const Text("push Welcome page"),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const WelcomeScreen()),
                  );
                },
              ),
              Expanded(child: Container()),
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

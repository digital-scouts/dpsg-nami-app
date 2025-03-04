import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:nami/screens/settings/data_change_history_page.dart';
import 'package:nami/screens/utilities/new_version_info_screen.dart';
import 'package:nami/screens/widgets/nami_change_toggle.dart';
import 'package:nami/screens/widgets/stamm_heim_setting.dart';
import 'package:nami/screens/widgets/stufenwechsel_alter_setting.dart';
import 'package:nami/screens/widgets/stufenwechsel_datum_setting.dart';
import 'package:nami/utilities/app.state.dart';
import 'package:nami/utilities/helper_functions.dart';
import 'package:nami/utilities/notifications.dart';
import 'package:nami/utilities/stufe.dart';
import 'package:nami/utilities/theme.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
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
      title: const Text('Fehlerhafte Daten korrigieren'),
      subtitle: const Text('Alle Daten werden neu geladen'),
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

  _buildShowDataHistory() {
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

  _buildThemeToggle() {
    final themeModel = Provider.of<ThemeModel>(context);

    return ListTile(
      title: const Text('Erscheinungsbild'),
      leading: const Icon(Icons.color_lens),
      trailing: DropdownButton<ThemeMode>(
        value: themeModel.currentMode,
        onChanged: (ThemeMode? newValue) {
          if (newValue != null) {
            themeModel.setTheme(newValue);
            setThemeMode(newValue);
          }
        },
        items: const [
          DropdownMenuItem(
            value: ThemeMode.system,
            child: Text('Automatisch'),
          ),
          DropdownMenuItem(
            value: ThemeMode.light,
            child: Text('Hell'),
          ),
          DropdownMenuItem(
            value: ThemeMode.dark,
            child: Text('Dunkel'),
          ),
        ],
      ),
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
        title: const Center(child: Text('Settings')),
      ),
      body: ValueListenableBuilder(
        valueListenable: settingsBox.listenable(),
        builder: (context, _, __) {
          return ListView(
            children: [
              _buildSync(),
              _buildForceBSync(),
              _buildShowDataHistory(),
              const NamiChangeToggle(),
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
              _buildThemeToggle(),
              const Divider(height: 1),
              _buildShareLogs(),
              _buildChangelogButton(),
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

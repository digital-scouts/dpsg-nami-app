import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:nami/screens/settings/settings_app.dart';
import 'package:nami/screens/settings/settings_benachrichtigung.dart';
import 'package:nami/screens/settings/settings_stufenwechsel.dart';
import 'package:nami/screens/widgets/stamm_heim_setting.dart';
import 'package:nami/utilities/helper_functions.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../utilities/hive/settings.dart';
import 'settings_debug.dart';

class Settings extends StatefulWidget {
  const Settings({super.key});

  @override
  State<Settings> createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  bool isValidInput(String text) {
    RegExp regex = RegExp(r'^\d{0,2}-\d{0,2}$');
    return regex.hasMatch(text);
  }

  Widget _buildSubpageTile({
    required String title,
    required IconData icon,
    required Widget Function() pageBuilder,
  }) {
    return ListTile(
      title: Text(title),
      leading: Icon(icon),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => pageBuilder()),
        );
      },
    );
  }

  Widget _buildBenachrichtigungSettings() {
    return _buildSubpageTile(
      title: 'Benachrichtigungen',
      icon: Icons.notifications,
      pageBuilder: () => const SettingsBenachrichtigung(),
    );
  }

  Widget _buildDebugSettings() {
    return _buildSubpageTile(
      title: 'Debug & Tools',
      icon: Icons.bug_report,
      pageBuilder: () => const SettingsDebug(),
    );
  }

  Widget _buildStufenwechselSettings() {
    return _buildSubpageTile(
      title: 'Stufenwechsel',
      icon: Icons.swap_horiz,
      pageBuilder: () => const SettingsStufenwechsel(),
    );
  }

  Widget _buildAppSettings() {
    return _buildSubpageTile(
      title: 'App-Einstellungen',
      icon: Icons.settings,
      pageBuilder: () => const SettingsApp(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Center(child: Text('Settings'))),
      body: ValueListenableBuilder(
        valueListenable: settingsBox.listenable(),
        builder: (context, _, _) {
          return ListView(
            children: [
              _buildStufenwechselSettings(),
              _buildBenachrichtigungSettings(),
              _buildAppSettings(),
              const Divider(height: 1),
              const StammHeimSetting(),
              const Divider(height: 1),
              _buildDebugSettings(),
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: FutureBuilder<(PackageInfo, String?)>(
                  future:
                      Future.wait([
                        PackageInfo.fromPlatform(),
                        getGitCommitId(),
                      ]).then((results) {
                        return (
                          results[0] as PackageInfo,
                          results[1] as String?,
                        );
                      }),
                  builder:
                      (
                        BuildContext context,
                        AsyncSnapshot<(PackageInfo, String?)> snapshot,
                      ) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const CircularProgressIndicator();
                        } else {
                          final String version =
                              snapshot.data?.$1.version ?? 'Unknown';
                          final String commitId =
                              snapshot.data?.$2?.substring(0, 8) ?? 'Unknown';
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

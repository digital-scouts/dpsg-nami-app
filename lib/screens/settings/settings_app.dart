import 'package:flutter/material.dart';
import 'package:nami/screens/widgets/nami_change_toggle.dart';
import 'package:nami/utilities/theme.dart';
import 'package:provider/provider.dart';

import '../../utilities/hive/settings.dart';

class SettingsApp extends StatefulWidget {
  const SettingsApp({super.key});

  @override
  State<SettingsApp> createState() => _SettingsAppState();
}

class _SettingsAppState extends State<SettingsApp> {
  late bool _biometricEnabled;
  late bool _wifiOnly;

  @override
  void initState() {
    super.initState();
    _biometricEnabled = getBiometricAuthenticationEnabled();
    _wifiOnly = getDataLoadingOverWifiOnly();
  }

  void _updateBiometric(bool value) {
    setState(() {
      _biometricEnabled = value;
      setBiometricAuthenticationEnabled(value);
    });
  }

  void _updateWifiOnly(bool value) {
    setState(() {
      _wifiOnly = value;
      setDataLoadingOverWifiOnly(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeModel = Provider.of<ThemeModel>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('App-Einstellungen'),
      ),
      body: ListView(
        children: [
          const NamiChangeToggle(),
          ListTile(
            title: const Text('Biometrische Authentifizierung'),
            leading: const Icon(Icons.fingerprint),
            trailing: Switch(
              value: _biometricEnabled,
              onChanged: _updateBiometric,
            ),
          ),
          ListTile(
            title: const Text('Optionale Daten nur über WLAN laden'),
            leading: const Icon(Icons.wifi),
            trailing: Switch(
              value: _wifiOnly,
              onChanged: _updateWifiOnly,
            ),
          ),
          ListTile(
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
          ),
        ],
      ),
    );
  }
}

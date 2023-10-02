import 'package:flutter/material.dart';

class Settings extends StatefulWidget {
  const Settings({Key? key}) : super(key: key);

  @override
  State<Settings> createState() => _SettingsState();
}

// Provider.of<ThemeModel>(context, listen: false).setTheme(ThemeType.dark);

/*
 Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.sync),
                onPressed: () => {syncNamiData()},
              ),
              Text(getLastNamiSync() != null
                  ? "Vor ${DateTime.now().difference(getLastNamiSync()!).inDays.toString()} Tagen"
                  : "Noch nie Syncronisiert"),
            ],
          ),
*/

class _SettingsState extends State<Settings> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Center(child: Text('Settings')),
      ),
      body: const Center(
        child: Text('Settings'),
      ),
    );
  }
}

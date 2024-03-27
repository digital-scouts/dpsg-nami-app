import 'package:flutter/material.dart';
import 'package:nami/utilities/app.state.dart';

import '../../utilities/hive/settings.dart';

class Settings extends StatefulWidget {
  const Settings({Key? key}) : super(key: key);

  @override
  State<Settings> createState() => _SettingsState();
}

// Provider.of<ThemeModel>(context, listen: false).setTheme(ThemeType.dark);

class _SettingsState extends State<Settings> {
  bool stufenwechselDatumIsValid = true;

  final TextEditingController _stufenwechselTextController =
      TextEditingController();

  Future<void> _syncData({bool forceSync = false}) async {
    AppStateHandler().setLoadDataState(context, loadAll: forceSync);
  }

  Widget _buildSync() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('Sync: '),
        IconButton(
          icon: const Icon(Icons.sync),
          onPressed: () => {_syncData()},
        ),
        Text(
            "Vor ${DateTime.now().difference(getLastNamiSync()).inDays.toString()} Tagen"),
      ],
    );
  }

  Widget _buildForceBSync() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('Force Sync: '),
        IconButton(
          icon: const Icon(Icons.sync),
          onPressed: () => {_syncData(forceSync: true)},
        ),
      ],
    );
  }

  bool isValidInput(String text) {
    RegExp regex = RegExp(r'^\d{0,2}-\d{0,2}$');
    return regex.hasMatch(text);
  }

  Widget _buildStufenwechselDatumInput() {
    _stufenwechselTextController.text =
        '${getNextStufenwechselDatum().day.toString().padLeft(2, '0')}-${getNextStufenwechselDatum().month.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Stufenwechsel Datum: '),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 8, right: 8),
              child: TextField(
                controller: _stufenwechselTextController,
                decoration: InputDecoration(
                  hintText: 'DD-MM',
                  errorText: !stufenwechselDatumIsValid
                      ? 'Ungültiges Format'
                      : null, // Anzeige des Fehlers
                ),
              ),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              if (!isValidInput(_stufenwechselTextController.text)) {
                setState(() {
                  stufenwechselDatumIsValid = false;
                });
              } else {
                DateTime stufenwechselDatum = DateTime(
                    DateTime.now().year,
                    int.parse(_stufenwechselTextController.text.split('-')[1]),
                    int.parse(_stufenwechselTextController.text.split('-')[0]));
                setStufenwechselDatum(stufenwechselDatum);
                setState(() {
                  stufenwechselDatumIsValid = true;
                });
              }
            },
            icon: const Icon(Icons.save),
            label: const Text('Speichern'),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('Settings build');
    return Scaffold(
      appBar: AppBar(
        title: const Center(child: Text('Settings')),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildSync(),
          _buildForceBSync(),
          Divider(
            height: 1,
            color: Theme.of(context).dividerColor,
          ),
          _buildStufenwechselDatumInput()
        ],
      ),
    );
  }
}

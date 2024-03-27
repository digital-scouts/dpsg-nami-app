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

  Widget _buildSync() {
    return ListTile(
      title: const Text('Sync: '),
      leading: const Icon(Icons.sync),
      onTap: () {
        AppStateHandler().setLoadDataState(context, loadAll: false);
      },
      subtitle: Text(
          "Vor ${DateTime.now().difference(getLastNamiSync()).inDays.toString()} Tagen"),
    );
  }

  Widget _buildForceBSync() {
    return ListTile(
      title: const Text('Force Sync: '),
      leading: const Icon(Icons.sync),
      onTap: () {
        AppStateHandler().setLoadDataState(context, loadAll: true);
      },
    );
  }

  bool isValidInput(String text) {
    RegExp regex = RegExp(r'^\d{0,2}-\d{0,2}$');
    return regex.hasMatch(text);
  }

  Widget _buildStufenwechselDatumInput() {
    _stufenwechselTextController.text =
        '${getNextStufenwechselDatum().day.toString().padLeft(2, '0')}-${getNextStufenwechselDatum().month.toString().padLeft(2, '0')}';
    return ListTile(
      title: const Text('Stufenwechsel Datum: '),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 80,
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
          IconButton(
            color: Theme.of(context).colorScheme.primary,
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
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Center(child: Text('Settings')),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildSync(),
          _buildForceBSync(),
          const Divider(height: 1),
          _buildStufenwechselDatumInput()
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../utilities/hive/settings.dart';
import '../../utilities/nami/nami.service.dart';
import 'dart:math';

class Settings extends StatefulWidget {
  const Settings({Key? key}) : super(key: key);

  @override
  State<Settings> createState() => _SettingsState();
}

// Provider.of<ThemeModel>(context, listen: false).setTheme(ThemeType.dark);

class _SettingsState extends State<Settings>
    with SingleTickerProviderStateMixin {
  bool stufenwechselDatumIsValid = true;
  bool loading = false;
  late final AnimationController _controller;

  final TextEditingController _stufenwechselTextController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _syncData({bool forceSync = false}) async {
    setState(() => loading = true);
    // await syncNamiData(forceSync: forceSync);
    setState(() => loading = false);
  }

  Widget _buildSync() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('Sync: '),
        AnimatedBuilder(
          animation: _controller,
          builder: (_, child) {
            return Transform.rotate(
              angle: loading ? _controller.value * 2.0 * pi : 0,
              child: child,
            );
          },
          child: IconButton(
            icon: const Icon(Icons.sync),
            onPressed: loading ? null : () => {_syncData()},
          ),
        ),
        Text(getLastNamiSync() != null
            ? "Vor ${DateTime.now().difference(getLastNamiSync()!).inDays.toString()} Tagen"
            : "Noch nie Syncronisiert"),
      ],
    );
  }

  Widget _buildForceBSync() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('Force Sync: '),
        AnimatedBuilder(
          animation: _controller,
          builder: (_, child) {
            return Transform.rotate(
              angle: loading ? _controller.value * 2.0 * pi : 0,
              child: child,
            );
          },
          child: IconButton(
            icon: const Icon(Icons.sync),
            onPressed: loading ? null : () => {_syncData(forceSync: true)},
          ),
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

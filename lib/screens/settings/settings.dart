import 'package:flutter/material.dart';

import '../../utilities/hive/settings.dart';
import '../../utilities/nami/nami.service.dart';

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

class _SettingsState extends State<Settings>
    with SingleTickerProviderStateMixin {
  bool _isSyncing = false;
  double _rotationValue = 0.0;
  late AnimationController _controller;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();

    // Erstellen Sie einen AnimationController
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );

    // Erstellen Sie eine RotationTransition-Animation mit Tween
    _rotationAnimation = Tween<double>(begin: 360, end: 0).animate(_controller)
      ..addListener(() {
        setState(() {
          _rotationValue = _rotationAnimation.value;
        });
      });

    // Starten Sie die Animation
    _controller.repeat(); // Animation wiederholen
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _syncData() async {
    setState(() {
      _isSyncing = true;
    });

    await syncNamiData();

    setState(() {
      _isSyncing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Center(child: Text('Settings')),
      ),
      body: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: _isSyncing
                ? RotationTransition(
                    turns: AlwaysStoppedAnimation(_rotationValue /
                        360), // Teilen Sie durch 360, um eine vollständige Umdrehung zu erhalten
                    child: const Icon(Icons.sync))
                : const Icon(Icons.sync),
            onPressed: () => {_isSyncing ? null : _syncData()},
          ),
          Text(getLastNamiSync() != null
              ? "Vor ${DateTime.now().difference(getLastNamiSync()!).inDays.toString()} Tagen"
              : "Noch nie Syncronisiert"),
        ],
      ),
    );
  }
}

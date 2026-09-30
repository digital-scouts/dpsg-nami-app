import 'package:shared_preferences/shared_preferences.dart';

import 'app_startup_state_service.dart';

enum AppMode { live, demo }

/// Merkt sich, ob die App im Demo-Modus laeuft, damit ein Kaltstart dort
/// weitermacht, wo die Person aufgehoert hat.
class AppModeStore {
  AppModeStore({StartupPreferencesProvider? preferencesProvider})
    : _preferencesProvider =
          preferencesProvider ?? SharedPreferences.getInstance;

  static const String demoModeActiveKey = 'app_mode.demo_active';

  final StartupPreferencesProvider _preferencesProvider;

  Future<AppMode> load() async {
    final prefs = await _preferencesProvider();
    return (prefs.getBool(demoModeActiveKey) ?? false)
        ? AppMode.demo
        : AppMode.live;
  }

  Future<void> save(AppMode mode) async {
    final prefs = await _preferencesProvider();
    await prefs.setBool(demoModeActiveKey, mode == AppMode.demo);
  }
}

/// Wechselt zwischen echtem Zugang und Demo-Zugang. Der Wechsel baut die
/// App-Abhaengigkeiten neu auf, damit Demo- und Echtdaten nie gemeinsam in
/// denselben Models oder Speichern liegen.
class AppModeController {
  AppModeController({
    required this.mode,
    required Future<void> Function(AppMode mode) switchMode,
  }) : _switchMode = switchMode;

  final AppMode mode;
  final Future<void> Function(AppMode mode) _switchMode;

  bool get isDemo => mode == AppMode.demo;

  Future<void> enterDemo() => _switchMode(AppMode.demo);

  Future<void> exitDemo() => _switchMode(AppMode.live);
}

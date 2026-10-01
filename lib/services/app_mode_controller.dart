import 'package:shared_preferences/shared_preferences.dart';

import 'app_startup_state_service.dart';

enum AppMode { live, demo }

/// Rolle, mit der die Demo den erfundenen Bezirk zeigt. Jeder Zugang sieht
/// nur, was diese Rolle in Hitobito lesen duerfte.
enum DemoZugang { stammesvorstand, leitung, bezirksvorstand }

/// Merkt sich, ob die App im Demo-Modus laeuft und mit welchem Zugang, damit
/// ein Kaltstart dort weitermacht, wo die Person aufgehoert hat.
class AppModeStore {
  AppModeStore({StartupPreferencesProvider? preferencesProvider})
    : _preferencesProvider =
          preferencesProvider ?? SharedPreferences.getInstance;

  static const String demoModeActiveKey = 'app_mode.demo_active';
  static const String demoZugangKey = 'app_mode.demo_zugang';

  final StartupPreferencesProvider _preferencesProvider;

  Future<AppMode> load() async {
    final prefs = await _preferencesProvider();
    return (prefs.getBool(demoModeActiveKey) ?? false)
        ? AppMode.demo
        : AppMode.live;
  }

  /// Ohne gespeicherten Zugang, etwa aus einer Demo vor der Zugangsauswahl,
  /// startet der Stammesvorstand.
  Future<DemoZugang> loadDemoZugang() async {
    final prefs = await _preferencesProvider();
    final name = prefs.getString(demoZugangKey);
    return DemoZugang.values.firstWhere(
      (zugang) => zugang.name == name,
      orElse: () => DemoZugang.stammesvorstand,
    );
  }

  Future<void> save(AppMode mode, {DemoZugang? demoZugang}) async {
    final prefs = await _preferencesProvider();
    await prefs.setBool(demoModeActiveKey, mode == AppMode.demo);
    if (mode == AppMode.demo && demoZugang != null) {
      await prefs.setString(demoZugangKey, demoZugang.name);
    } else {
      await prefs.remove(demoZugangKey);
    }
  }
}

/// Wechselt zwischen echtem Zugang und Demo-Zugang. Der Wechsel baut die
/// App-Abhaengigkeiten neu auf, damit Demo- und Echtdaten nie gemeinsam in
/// denselben Models oder Speichern liegen.
class AppModeController {
  AppModeController({
    required this.mode,
    this.demoZugang,
    required Future<void> Function(AppMode mode, DemoZugang? demoZugang)
    switchMode,
  }) : _switchMode = switchMode;

  final AppMode mode;
  final DemoZugang? demoZugang;
  final Future<void> Function(AppMode mode, DemoZugang? demoZugang) _switchMode;

  bool get isDemo => mode == AppMode.demo;

  Future<void> enterDemo(DemoZugang zugang) =>
      _switchMode(AppMode.demo, zugang);

  Future<void> exitDemo() => _switchMode(AppMode.live, null);
}

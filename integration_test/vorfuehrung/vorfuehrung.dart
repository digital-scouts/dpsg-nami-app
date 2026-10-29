// Geführte Vorführung auf Simulator und Emulator (#278): Der Test bedient die
// echte App, ein Mensch schaut zu. Jeder Schritt wiederholt seine Bewegung,
// bis im Temp-Verzeichnis der App die Datei `vorfuehrung_weiter` liegt:
//
//   iOS:     touch "$(xcrun simctl get_app_container <udid> de.jlange.nami.app data)/Library/Caches/vorfuehrung_weiter"
//   Android: adb -s <id> shell run-as de.jlange.nami.app touch cache/vorfuehrung_weiter
//
// Start nur mit `--dart-define=VORFUEHRUNG=true`; `--dart-define=AB=<bereich>`
// beginnt bei einem Bereich, `--dart-define=NUR=<bereich>` zeigt nur diesen.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nami/main.dart' as app;
import 'package:nami/presentation/theme/app_haptik.dart';
import 'package:path_provider/path_provider.dart';

const bool vorfuehrungAktiv = bool.fromEnvironment('VORFUEHRUNG');
const String _ab = String.fromEnvironment('AB');
const String _nur = String.fromEnvironment('NUR');

/// Bindung mit Echtzeit-Frames; Berührungen am Gerät kommen in den Pausen an.
void vorfuehrungBinden() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  binding.shouldPropagateDevicePointerEvents = true;
}

class Vorfuehrung {
  Vorfuehrung._(this.tester, this._weiter);

  final WidgetTester tester;
  final File _weiter;
  bool _abErreicht = _ab.isEmpty || _nur.isNotEmpty;
  OverlayEntry? _schild;
  final _schildText = ValueNotifier<String>('');

  static Future<Vorfuehrung> starte(WidgetTester tester) async {
    final weiter = File(
      '${(await getTemporaryDirectory()).path}/vorfuehrung_weiter',
    );
    if (weiter.existsSync()) {
      weiter.deleteSync();
    }
    final vorfuehrung = Vorfuehrung._(tester, weiter);
    AppHaptik.beobachter = vorfuehrung._haptik;
    return vorfuehrung;
  }

  /// Wartet in Echtzeit, ohne dass der Test Frames verschluckt.
  Future<void> warte([int ms = 700]) => tester.pump(Duration(milliseconds: ms));

  /// Wartet, bis [finder] etwas findet.
  Future<void> bisSichtbar(
    Finder finder, {
    Duration timeout = const Duration(seconds: 40),
  }) async {
    final ende = DateTime.now().add(timeout);
    while (finder.evaluate().isEmpty && DateTime.now().isBefore(ende)) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(finder, findsWidgets);
  }

  /// Tippt [finder] an. Mit [mitte] wird das Ziel erst in die Mitte der
  /// Liste gescrollt, damit es nicht unter der Tab-Leiste liegt.
  Future<void> tippe(
    Finder finder, {
    int danach = 900,
    bool mitte = false,
  }) async {
    final ziel = finder.first;
    if (mitte) {
      await Scrollable.ensureVisible(
        tester.element(ziel),
        alignment: 0.5,
        duration: const Duration(milliseconds: 300),
      );
      await warte(500);
    } else {
      await tester.ensureVisible(ziel);
    }
    await tester.tap(ziel);
    await warte(danach);
  }

  /// Zeigt einen Bereich erst mit normaler, dann mit reduzierter Bewegung.
  /// [zeigen] muss im selben Zustand enden, in dem es beginnt.
  Future<void> bereich(
    String id,
    String titel, {
    Future<void> Function()? vorbereiten,
    required Future<void> Function() zeigen,
    Future<void> Function()? aufraeumen,
  }) async {
    if ((!_abErreicht && id != _ab) || (_nur.isNotEmpty && id != _nur)) {
      return;
    }
    _abErreicht = true;
    await _versuche('$id · vorbereiten', () async => vorbereiten?.call());
    for (final reduziert in [false, true]) {
      _bewegungReduziert(reduziert);
      final schritt =
          '$id · $titel · ${reduziert ? 'Bewegung reduziert' : 'normal'}';
      _zeigeSchild(schritt);
      // ignore: avoid_print
      print('VORFUEHRUNG ▶ $schritt – wartet auf weiter');
      var ok = true;
      while (true) {
        // Nach einem Fehler nicht wiederholen, nur noch auf weiter warten.
        if (ok) {
          ok = await _versuche(schritt, zeigen);
        }
        if (await _pause(const Duration(milliseconds: 1500))) {
          break;
        }
      }
      // ignore: avoid_print
      print('VORFUEHRUNG ✓ $schritt');
    }
    _bewegungReduziert(false);
    await _versuche('$id · aufräumen', () async => aufraeumen?.call());
  }

  /// Ein Fehler beendet nicht die ganze Vorführung, sondern nur den Schritt.
  Future<bool> _versuche(String was, Future<void> Function() aktion) async {
    try {
      await aktion();
      return true;
    } catch (fehler, stack) {
      // ignore: avoid_print
      print('VORFUEHRUNG ✗ $was: $fehler\n$stack');
      return false;
    }
  }

  Future<void> ende() async {
    _schild?.remove();
    _schild = null;
    AppHaptik.beobachter = null;
    tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
    // ignore: avoid_print
    print('VORFUEHRUNG ■ fertig');
  }

  void _bewegungReduziert(bool an) {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures(disableAnimations: an);
  }

  Future<bool> _pause(Duration dauer) async {
    final ende = DateTime.now().add(dauer);
    do {
      if (_weiter.existsSync()) {
        _weiter.deleteSync();
        return true;
      }
      await tester.pump(const Duration(milliseconds: 100));
    } while (DateTime.now().isBefore(ende));
    return false;
  }

  void _zeigeSchild(String text) {
    _schildText.value = text;
    if (_schild != null) {
      return;
    }
    final overlay = app.navigatorKey.currentState?.overlay;
    if (overlay == null) {
      return;
    }
    _schild = OverlayEntry(
      builder: (_) => IgnorePointer(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 64),
              child: ValueListenableBuilder<String>(
                valueListenable: _schildText,
                builder: (_, text, _) => _Pille(text: text),
              ),
            ),
          ),
        ),
      ),
    );
    overlay.insert(_schild!);
  }

  void _haptik(String bedeutung) {
    // ignore: avoid_print
    print('VORFUEHRUNG ♦ Haptik: $bedeutung');
    // Haptik darf auch während eines Builds ausgelöst werden; das Schild
    // kommt deshalb erst nach dem Frame ins Overlay.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _haptikSchild(bedeutung),
    );
  }

  void _haptikSchild(String bedeutung) {
    final overlay = app.navigatorKey.currentState?.overlay;
    if (overlay == null) {
      return;
    }
    final eintrag = OverlayEntry(
      builder: (_) => IgnorePointer(
        child: Align(
          alignment: Alignment.topCenter,
          child: SafeArea(
            child: _Pille(text: 'Haptik: $bedeutung', farbe: Colors.deepPurple),
          ),
        ),
      ),
    );
    overlay.insert(eintrag);
    Future<void>.delayed(const Duration(milliseconds: 1400), () {
      if (eintrag.mounted) {
        eintrag.remove();
      }
    });
  }
}

class _Pille extends StatelessWidget {
  const _Pille({required this.text, this.farbe = Colors.black});

  final String text;
  final Color farbe;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Container(
        margin: const EdgeInsets.all(8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: farbe.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          text,
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
      ),
    );
  }
}

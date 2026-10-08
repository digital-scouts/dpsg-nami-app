// Erzeugt Rohscreens der Store- oder Docs-Szenen aus Storybook in nativer
// Aufloesung. Ausfuehren ueber tool/store_screenshots/run_store_screenshots.sh.
// STORE_SCREENSHOT_SET waehlt die Szenen: `store` (Standard) oder `docs`
// (Store- und Handbuch-Szenen fuer GitHub Pages). Im
// iOS-Simulator schreibt die App direkt in STORE_SCREENSHOT_DIR auf dem Host,
// weil `flutter test` die App danach wieder deinstalliert.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:nami/stories/docs/docs_scenes_story.dart';
import 'package:nami/stories/store/store_scenes_story.dart';
import 'package:path_provider/path_provider.dart';

const String _outDirDefine = String.fromEnvironment('STORE_SCREENSHOT_DIR');
const String _setDefine = String.fromEnvironment(
  'STORE_SCREENSHOT_SET',
  defaultValue: 'store',
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Store-Szenen als PNG exportieren', (tester) async {
    await initializeDateFormatting('de');
    final outDir = _outDirDefine.isNotEmpty
        ? Directory(_outDirDefine)
        : Directory(
            '${(await getApplicationDocumentsDirectory()).path}/store_screenshots',
          );
    outDir.createSync(recursive: true);

    final stories = [
      ...storeSceneStories(),
      if (_setDefine == 'docs') ...docsSceneStories(),
    ];
    for (final story in stories) {
      final boundaryKey = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundaryKey,
          // Direkt der Story-Builder: die Storybook-Oberflaeche wuerde auf
          // dem iPad Seitenleisten einblenden. Store-Szenen nutzen keine Knobs.
          child: Builder(key: ValueKey(story.name), builder: story.builder),
        ),
      );
      await _settle(tester);

      final boundary =
          boundaryKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      final pixelRatio = tester.view.devicePixelRatio;
      final bytes = await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: pixelRatio);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        return data!.buffer.asUint8List();
      });
      // `Store/Erscheinungsbild/Dunkel` -> `erscheinungsbild_dunkel`,
      // `Docs/Statistik/Eigene Kachel` -> `statistik_eigene_kachel`.
      final fileName = story.name
          .substring(story.name.indexOf('/') + 1)
          .replaceAll(RegExp('[ /-]'), '_')
          .toLowerCase();
      File('${outDir.path}/$fileName.png').writeAsBytesSync(bytes!);
      debugPrint('store-screenshot: $fileName.png');
    }
  });
}

/// Laesst asynchrone Loader (Fake-Login, Karten-Assets, Kacheln) ablaufen,
/// ohne an Endlos-Animationen haengen zu bleiben.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
  try {
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 5),
    );
  } on FlutterError {
    // Laufende Animationen (z.B. Ladeindikatoren) sind fuer den Screenshot ok.
  }
}

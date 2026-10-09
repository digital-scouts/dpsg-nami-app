import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nami/presentation/widgets/app_falz.dart';

void main() {
  void setzeFenster(WidgetTester tester, Size groesse, {double dpr = 1}) {
    tester.view.physicalSize = groesse * dpr;
    tester.view.devicePixelRatio = dpr;
    tester.view.display.size = groesse * dpr;
    addTearDown(tester.view.reset);
    addTearDown(tester.view.display.reset);
  }

  /// Seitenleiste mit [versatz] Breite, daneben Liste und Detail.
  Future<Rect> listeRect(WidgetTester tester, {double versatz = 88}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Row(
            children: [
              SizedBox(width: versatz),
              Expanded(
                child: AppFalzBereich.fuer(
                  context,
                  versatz: versatz,
                  child: const AppListeDetail(
                    liste: ColoredBox(
                      key: ValueKey('liste'),
                      color: Colors.red,
                    ),
                    detail: SizedBox.expand(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return tester.getRect(find.byKey(const ValueKey('liste')));
  }

  test('teilt ohne Falz mit fester Listenbreite', () {
    expect(AppListeDetail.teilung(800, null), (liste: 320.0, spalt: 0.0));
    expect(AppListeDetail.teilung(1200, null), (liste: 360.0, spalt: 0.0));
  });

  test('nutzt den Falz nur mit genug Platz je Seite', () {
    const falz = (links: 387.5, rechts: 387.5);
    expect(AppListeDetail.teilung(863, falz), (liste: 387.5, spalt: 0.0));
    expect(AppListeDetail.teilung(863, (links: 200.0, rechts: 200.0)), (
      liste: 320.0,
      spalt: 0.0,
    ));
    expect(AppListeDetail.teilung(600, falz), (liste: 320.0, spalt: 0.0));
  });

  testWidgets(
    'legt auf dem Duo die Teilung auf den Falz',
    (tester) async {
      setzeFenster(tester, const Size(951, 669), dpr: 3);
      // Der Simulator meldet als Bildschirm den Aussenbildschirm.
      tester.view.display.size = const Size(1398, 2034);
      final rect = await listeRect(tester);
      expect(rect.left, 88);
      expect(rect.right, 951 / 2);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'kennt auf dem iPad keinen Falz',
    (tester) async {
      setzeFenster(tester, const Size(1133, 744), dpr: 2);
      final rect = await listeRect(tester);
      expect(rect.width, 360);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'kennt im Stage-Manager-Fenster keinen Falz',
    (tester) async {
      setzeFenster(tester, const Size(1366, 1024), dpr: 2);
      tester.view.physicalSize = const Size(951, 669) * 2;
      final rect = await listeRect(tester);
      expect(rect.width, 320);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets('nutzt auf Android das gemeldete Scharnier', (tester) async {
    setzeFenster(tester, const Size(1000, 800));
    tester.view.displayFeatures = [
      const DisplayFeature(
        bounds: Rect.fromLTRB(490, 0, 510, 800),
        type: DisplayFeatureType.hinge,
        state: DisplayFeatureState.postureHalfOpened,
      ),
    ];
    addTearDown(tester.view.resetDisplayFeatures);
    final rect = await listeRect(tester);
    expect(rect.right, 490);
    // Das Detail beginnt hinter dem Spalt.
    final detail = tester.getRect(find.byType(SizedBox).last);
    expect(detail.left, 510);
  });
}

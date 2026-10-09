import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nami/domain/member/mitglied.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/presentation/widgets/app_lesebreite.dart';
import 'package:nami/presentation/widgets/app_page_header.dart';
import 'package:nami/presentation/widgets/member_list_directory.dart';
import 'package:nami/presentation/widgets/member_list_tile.dart';

void main() {
  void setzeFenster(WidgetTester tester, Size groesse) {
    tester.view.physicalSize = groesse;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  test('Rand greift erst mit Mindestrand oberhalb der Lesebreite', () {
    expect(AppLesebreite.randFuer(402), 0);
    // iPad 11" hoch: knapp ueber der Lesebreite bleibt alles randlos.
    expect(AppLesebreite.randFuer(820), 0);
    // Duo aufgeklappt neben Seitenleiste und Systembereich rechts nutzt die
    // volle Breite.
    expect(AppLesebreite.randFuer(951 - 88 - 83), 0);
    expect(AppLesebreite.randFuer(848), 24);
    expect(AppLesebreite.randFuer(1376), 288);
    expect(AppLesebreite.randFuer(double.infinity), 0);
  });

  group('AppPageHeader', () {
    Future<Rect> headerRect(WidgetTester tester, {bool volleBreite = false}) {
      return tester
          .pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Column(
                  children: [
                    AppPageHeader(
                      key: const ValueKey('header'),
                      primary: const SizedBox.shrink(),
                      secondary: const SizedBox.shrink(),
                      volleBreite: volleBreite,
                    ),
                  ],
                ),
              ),
            ),
          )
          .then((_) => tester.getRect(find.byType(DecoratedBox).first));
    }

    testWidgets('bleibt auf dem Telefon randlos', (tester) async {
      setzeFenster(tester, const Size(402, 874));
      final rect = await headerRect(tester);
      expect(rect.left, 0);
      expect(rect.width, 402);
    });

    testWidgets('steht auf breiten Fenstern als mittiger Block', (
      tester,
    ) async {
      setzeFenster(tester, const Size(1376, 1032));
      final rect = await headerRect(tester);
      expect(rect.width, AppLesebreite.breite);
      expect(rect.left, 288);
    });

    testWidgets('volleBreite bleibt auch breit randlos', (tester) async {
      setzeFenster(tester, const Size(1376, 1032));
      final rect = await headerRect(tester, volleBreite: true);
      expect(rect.left, 0);
      expect(rect.width, 1376);
    });
  });

  testWidgets('Mitgliederliste ist auf breiten Fenstern buendig mit dem Kopf', (
    tester,
  ) async {
    setzeFenster(tester, const Size(1376, 1032));
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          AppLocalizations.delegate,
        ],
        supportedLocales: const [Locale('de'), Locale('en')],
        locale: const Locale('de'),
        home: Scaffold(
          body: MemberDirectory(
            mitglieder: [
              for (var i = 1; i <= 3; i++) MitgliedFactory.demo(index: i),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    final kachel = tester.getRect(find.byType(MemberListTile).first);
    // Lesebreite abzueglich 16 pt Innenabstand je Seite.
    expect(kachel.left, 288 + 16);
    expect(kachel.width, AppLesebreite.breite - 32);
  });
}

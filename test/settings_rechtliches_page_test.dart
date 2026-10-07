import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nami/domain/rechtliches/anbieter.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/presentation/screens/settings_rechtliches_page.dart';

Widget _app(Widget home, {Brightness brightness = Brightness.light}) =>
    MaterialApp(
      theme: ThemeData(brightness: brightness),
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('de'), Locale('en')],
      locale: const Locale('de'),
      home: home,
    );

void main() {
  testWidgets('zeigt Kernaussagen mit Anbieter und alle Empfänger', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const SettingsRechtlichesPage()));

    expect(find.text('Kurz gesagt'), findsOneWidget);
    expect(find.text(Anbieter.name), findsOneWidget);
    expect(find.text(Anbieter.email), findsOneWidget);
    expect(find.textContaining('Lorem'), findsNothing);
    for (final empfaenger in Datenempfaenger.alle) {
      await tester.scrollUntilVisible(
        find.byKey(Key('legal-recipient-${empfaenger.id}')),
        200,
      );
      expect(
        find.byKey(Key('legal-recipient-${empfaenger.id}')),
        findsOneWidget,
      );
    }
  });

  testWidgets('jeder Empfänger hat alle Texte in beiden Sprachen', (
    tester,
  ) async {
    for (final sprache in ['de', 'en']) {
      final t = AppLocalizations(Locale(sprache));
      for (final empfaenger in Datenempfaenger.alle) {
        for (final feld in [
          'name',
          'short',
          'purpose',
          'data',
          'basis',
          'retention',
        ]) {
          final key = 'legal_r_${empfaenger.id}_$feld';
          expect(t.t(key), isNot(key), reason: '$sprache: $key fehlt');
        }
      }
    }
  });

  testWidgets('Statistikserver-Sheet bietet ID kopieren und Mail', (
    tester,
  ) async {
    String? kopiert;
    final geoeffnet = <Uri>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          kopiert = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await tester.pumpWidget(
      _app(
        SettingsRechtlichesPage(
          installationsId: 'install-abc',
          onOpenUrl: (uri) async => geoeffnet.add(uri),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('legal-recipient-statistik')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('legal-sheet-statistik')), findsOneWidget);
    expect(find.textContaining('14 Monate'), findsOneWidget);

    await tester.tap(find.byKey(const Key('legal-copy-id')));
    await tester.pump();
    expect(kopiert, 'install-abc');

    await tester.tap(find.byKey(const Key('legal-write-mail')));
    await tester.pump();
    expect(geoeffnet.single.scheme, 'mailto');
    expect(geoeffnet.single.path, Anbieter.email);
  });

  testWidgets('ohne Installations-ID nur Mail im Statistikserver-Sheet', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const SettingsRechtlichesPage()));

    await tester.tap(find.byKey(const Key('legal-recipient-statistik')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('legal-copy-id')), findsNothing);
    expect(find.byKey(const Key('legal-write-mail')), findsOneWidget);
  });

  testWidgets('öffnet Rechte, Lizenzen und die ausführliche Erklärung', (
    tester,
  ) async {
    final geoeffnet = <Uri>[];
    await tester.pumpWidget(
      _app(
        SettingsRechtlichesPage(onOpenUrl: (uri) async => geoeffnet.add(uri)),
      ),
    );

    await tester.scrollUntilVisible(
      find.byKey(const Key('legal-full-policy')),
      200,
    );
    await tester.ensureVisible(find.byKey(const Key('legal-full-policy')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('legal-full-policy')));
    await tester.pump();
    expect(geoeffnet.single.toString(), Anbieter.datenschutzerklaerungUrl);

    await tester.ensureVisible(find.byKey(const Key('legal-rights')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('legal-rights')));
    await tester.pumpAndSettle();
    expect(find.text('Beschwerde bei einer Aufsichtsbehörde'), findsOneWidget);
    Navigator.of(
      tester.element(find.text('Beschwerde bei einer Aufsichtsbehörde')),
    ).pop();
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('legal-licenses')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('legal-licenses')));
    await tester.pumpAndSettle();
    expect(find.byType(LicensePage), findsOneWidget);
  });

  testWidgets('rendert im dunklen Modus ohne Fehler', (tester) async {
    await tester.pumpWidget(
      _app(const SettingsRechtlichesPage(), brightness: Brightness.dark),
    );
    expect(tester.takeException(), isNull);
  });
}

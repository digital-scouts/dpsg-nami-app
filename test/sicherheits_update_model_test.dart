import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nami/domain/app_update/sicherheits_update_regel.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/presentation/model/sicherheits_update_model.dart';
import 'package:nami/presentation/widgets/sicherheits_update_sperre.dart';
import 'package:nami/services/app_update_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late DateTime now;
  late String version;
  late Map<String, dynamic>? security;
  final timers = <Duration>[];

  AppUpdateService service() => AppUpdateService(
    platformOverride: 'android',
    currentVersionProvider: () async => version,
    manifestProvider: () async => {
      'android': {
        'latest': '1.0.1',
        'min_supported': '1.0.0',
        'store_url': 'https://example.com/android',
        'security': ?security,
      },
    },
  );

  SicherheitsUpdateModel model({Future<void> Function()? onDatenLoeschen}) =>
      SicherheitsUpdateModel(
        updateService: service(),
        now: () => now,
        timerFactory: (dauer, callback) {
          timers.add(dauer);
          return Timer(const Duration(days: 365), () {});
        },
        onDatenLoeschen: onDatenLoeschen,
      );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    now = DateTime(2026, 10, 10, 9);
    version = '1.0.0';
    security = {'min_version': '1.0.1'};
    timers.clear();
  });

  test('fuehrt ueber zwei Aufschuebe und Countdown zur Sperre', () async {
    final m = model();
    await m.pruefe();
    expect(m.lage.art, SicherheitsUpdateLageArt.nachfrage);

    await m.spaeter();
    expect(m.lage.art, SicherheitsUpdateLageArt.warten);
    expect(timers.last, const Duration(hours: 3));

    now = now.add(const Duration(hours: 3));
    await m.pruefe();
    expect(m.lage.art, SicherheitsUpdateLageArt.nachfrage);
    expect(m.lage.verbleibendeAufschuebe, 1);

    await m.spaeter();
    expect(m.lage.art, SicherheitsUpdateLageArt.countdown);

    now = now.add(const Duration(hours: 3));
    await m.pruefe();
    expect(m.istGesperrt, isTrue);
  });

  test('die Sperre ueberdauert einen Neustart', () async {
    final erstes = model();
    await erstes.pruefe();
    await erstes.spaeter();
    now = now.add(const Duration(hours: 3));
    await erstes.spaeter();
    now = now.add(const Duration(hours: 3));
    await erstes.pruefe();
    expect(erstes.istGesperrt, isTrue);

    final neu = model();
    await neu.pruefe();
    expect(neu.istGesperrt, isTrue);
  });

  test('hebt die Sperre nach dem Update auf', () async {
    final m = model();
    await m.pruefe();
    await m.spaeter();
    now = now.add(const Duration(hours: 3));
    await m.spaeter();
    now = now.add(const Duration(hours: 3));
    await m.pruefe();
    expect(m.istGesperrt, isTrue);

    version = '1.0.1';
    await m.pruefe(forceRefresh: true);

    expect(m.lage.art, SicherheitsUpdateLageArt.keine);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(SicherheitsUpdateModel.standKey), isNull);
  });

  test('loescht bei einem Datenleck beim Sperren einmal die Daten', () async {
    security = {'min_version': '1.0.1', 'daten_loeschen': true};
    var geloescht = 0;
    final m = model(onDatenLoeschen: () async => geloescht++);
    await m.pruefe();
    await m.spaeter();
    now = now.add(const Duration(hours: 3));
    await m.spaeter();
    now = now.add(const Duration(hours: 3));
    await m.pruefe();
    await m.pruefe();

    expect(m.istGesperrt, isTrue);
    expect(m.datenGeloescht, isTrue);
    expect(geloescht, 1);
  });

  group('Oberflaeche', () {
    Widget app(SicherheitsUpdateModel m, Widget child) =>
        ChangeNotifierProvider<SicherheitsUpdateModel?>.value(
          value: m,
          child: MaterialApp(
            locale: const Locale('de'),
            supportedLocales: const [Locale('de'), Locale('en')],
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: child,
          ),
        );

    testWidgets('zeigt den Countdown oben', (tester) async {
      final m = model();
      await tester.runAsync(() async {
        await m.pruefe();
        await m.spaeter();
        now = now.add(const Duration(hours: 3));
        await m.spaeter();
      });
      final jetzt = now.add(const Duration(minutes: 15));

      await tester.pumpWidget(
        app(
          m,
          SicherheitsUpdateRahmen(
            now: () => jetzt,
            child: const Scaffold(body: Text('Inhalt')),
          ),
        ),
      );

      expect(
        find.byKey(const Key('security-update-countdown')),
        findsOneWidget,
      );
      expect(
        find.text('Die App sperrt sich in 2 Std. 45 Min.'),
        findsOneWidget,
      );
      expect(find.text('Inhalt'), findsOneWidget);
    });

    testWidgets('Sperre bietet Notfallkontakte nur ohne Datenloeschung', (
      tester,
    ) async {
      final m = model();
      await tester.runAsync(() async {
        await m.pruefe();
        await m.spaeter();
        now = now.add(const Duration(hours: 3));
        await m.spaeter();
        now = now.add(const Duration(hours: 3));
        await m.pruefe();
      });

      await tester.pumpWidget(app(m, const SicherheitsUpdateSperre()));
      await tester.pump();

      expect(find.text('Update erforderlich'), findsOneWidget);
      await tester.tap(find.byKey(const Key('security-lock-notfall')));
      await tester.pump();
      expect(
        find.byKey(const Key('security-lock-notfall-liste')),
        findsOneWidget,
      );
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:nami/data/settings/in_memory_address_settings_repository.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/presentation/widgets/mobile_daten_hinweis.dart';
import 'package:nami/presentation/widgets/settings_stamm_address.dart';
import 'package:nami/services/network_access_policy.dart';
import 'package:provider/provider.dart';

import 'support/fake_connectivity.dart';

Widget _app(Widget child, {required NetworkAccessPolicy policy}) {
  return Provider<NetworkAccessPolicy>.value(
    value: policy,
    child: MaterialApp(
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('de'), Locale('en')],
      locale: const Locale('de'),
      home: Scaffold(body: child),
    ),
  );
}

Widget _map(Widget kacheln) => Stack(
  children: [
    FlutterMap(
      options: const MapOptions(initialCenter: LatLng(50.9, 6.9)),
      children: [kacheln],
    ),
    const Text('Karte'),
  ],
);

NetworkAccessPolicy _policy(FakeConnectivity verbindung) => NetworkAccessPolicy(
  connectivity: verbindung,
  noMobileDataEnabled: () => true,
);

void main() {
  group('KartenKacheln', () {
    Widget karte() => SizedBox(
      height: 600,
      child: KartenKacheln(
        trigger: 'test',
        builder: (context, kacheln) => _map(kacheln),
      ),
    );

    testWidgets('zeigt ohne WLAN den Hinweis und gibt nach Laden frei', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(karte(), policy: _policy(FakeConnectivity.mobile())),
      );
      await tester.pumpAndSettle();

      expect(find.text('Karte nur aus dem Speicher'), findsOneWidget);

      await tester.tap(find.text('Über mobile Daten laden'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('mobile-daten-karte-hinweis')), findsNothing);
      expect(find.text('Karte'), findsOneWidget);
    });

    testWidgets('zeigt im WLAN keinen Hinweis', (tester) async {
      await tester.pumpWidget(
        _app(karte(), policy: _policy(FakeConnectivity.wifi())),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('mobile-daten-karte-hinweis')), findsNothing);
    });

    testWidgets('nutzt auf kleinen Karten die kompakte Zeile', (tester) async {
      await tester.pumpWidget(
        _app(
          SizedBox(
            height: 180,
            child: KartenKacheln(
              trigger: 'test',
              builder: (context, kacheln) => _map(kacheln),
            ),
          ),
          policy: _policy(FakeConnectivity.mobile()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Laden'), findsOneWidget);
      expect(find.text('Über mobile Daten laden'), findsNothing);
    });
  });

  group('Adresssuche', () {
    testWidgets('fragt ohne WLAN erst nach Bestaetigung', (tester) async {
      final anfragen = <String>[];
      await tester.pumpWidget(
        _app(
          StammAddressSettings(
            repository: InMemoryAddressSettingsRepository(),
            autocompleteProvider: (query) async {
              anfragen.add(query);
              return ['Hauptstraße 1, Köln'];
            },
          ),
          policy: _policy(FakeConnectivity.mobile()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField), 'Hauptstr');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(anfragen, isEmpty);
      expect(find.text('Vorschläge im WLAN'), findsOneWidget);

      await tester.tap(find.text('Vorschläge über mobile Daten laden'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(anfragen, ['Hauptstr']);
      expect(find.text('Vorschläge im WLAN'), findsNothing);
      expect(find.text('Hauptstraße 1, Köln'), findsOneWidget);
    });
  });
}

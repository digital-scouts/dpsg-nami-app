import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:nami/data/appearance/in_memory_appearance_settings_repository.dart';
import 'package:nami/domain/appearance/support_access.dart';
import 'package:nami/domain/supporter/supporter_kauf_repository.dart';
import 'package:nami/domain/supporter/supporter_produkt.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/presentation/model/appearance_model.dart';
import 'package:nami/presentation/model/supporter_kauf_model.dart';
import 'package:nami/presentation/navigation/app_router.dart';
import 'package:nami/presentation/screens/supporter/supporter_page.dart';
import 'package:nami/services/app_icon_service.dart';
import 'package:provider/provider.dart';

import 'support/fake_supporter_store_client.dart';

void main() {
  setUpAll(() => initializeDateFormatting('de'));

  late FakeSupporterStoreClient client;
  late SupporterKaufModel model;

  final waehrendAktion = DateTime(2027, 2, 1);
  final nachAktion = DateTime(2027, 4, 1);

  Future<void> pumpSeite(
    WidgetTester tester, {
    DateTime? jetzt,
    GekaufterSupportAccess gespeichert = const GekaufterSupportAccess(),
    bool erreichbar = true,
    SupportAccess? testschalter,
    Map<String, double> preise = const {
      'supporter_paket_wald': 1.99,
      'supporter_paket_lagerfeuer': 1.99,
      'supporter_paket_nachthimmel': 1.99,
      'foerderer_jahr': 5.99,
    },
  }) async {
    tester.view.physicalSize = const Size(390 * 3, 2600 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    client = FakeSupporterStoreClient(preise: preise)
      ..erreichbar = erreichbar
      ..aktiv = {for (final p in gespeichert.produkte) p.id};
    model = SupporterKaufModel(
      client: client,
      repository: InMemorySupporterKaufRepository(gespeichert),
    );
    await model.start();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: model),
          if (testschalter != null)
            ChangeNotifierProvider.value(
              value: AppearanceModel(
                repository: InMemoryAppearanceSettingsRepository(),
                appIconService: FakeAppIconService(),
                access: testschalter,
              ),
            ),
        ],
        child: MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('de')],
          locale: const Locale('de'),
          // Paket-Hintergruende animieren sonst endlos.
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          onGenerateRoute: (settings) => MaterialPageRoute(
            settings: settings,
            builder: (_) => settings.name == AppRoutes.settingsAppearance
                ? const Scaffold(body: Text('Erscheinungsbild-Seite'))
                : SupporterPage(nowProvider: () => jetzt ?? waehrendAktion),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('zeigt Förderer und drei Pakete mit Einführungspreis', (
    tester,
  ) async {
    await pumpSeite(tester);

    expect(find.byKey(const Key('supporter-foerderer-karte')), findsOneWidget);
    expect(find.text('1 Woche kostenlos testen'), findsOneWidget);
    expect(find.textContaining('Danach 5,99 € pro Jahr'), findsOneWidget);
    for (final paket in ['waldsee', 'lagerfeuer', 'nachthimmel']) {
      expect(find.byKey(Key('supporter-paket-$paket')), findsOneWidget);
    }
    expect(find.textContaining('2,99', findRichText: true), findsNWidgets(3));
    expect(find.text('Einführungspreis bis 31.3.'), findsNWidgets(3));
    expect(find.text('Käufe wiederherstellen'), findsOneWidget);
    expect(find.text('Nutzungsbedingungen'), findsOneWidget);
  });

  testWidgets('nach dem Aktionsende ohne durchgestrichenen Preis', (
    tester,
  ) async {
    await pumpSeite(tester, jetzt: nachAktion);

    expect(find.text('Einführungspreis bis 31.3.'), findsNothing);
    expect(find.textContaining('2,99', findRichText: true), findsNothing);
  });

  testWidgets('Normalpreis im Store wird nicht durchgestrichen', (
    tester,
  ) async {
    await pumpSeite(tester, preise: const {});

    expect(find.text('Einführungspreis bis 31.3.'), findsNothing);
  });

  testWidgets('Kaufen startet den Store-Kauf', (tester) async {
    await pumpSeite(tester);

    await tester.tap(find.byKey(const Key('supporter-paket-waldsee-kaufen')));
    await tester.pump();
    expect(client.gekauft, ['supporter_paket_wald']);

    await tester.tap(find.byKey(const Key('supporter-foerderer-kaufen')));
    await tester.pump();
    expect(client.gekauft, ['supporter_paket_wald', 'foerderer_jahr']);
  });

  testWidgets('gekauftes Paket führt zum Erscheinungsbild', (tester) async {
    await pumpSeite(
      tester,
      gespeichert: GekaufterSupportAccess.ausProdukten({
        SupporterProdukt.paketWaldsee,
      }),
    );

    expect(find.text('Gekauft'), findsOneWidget);
    expect(
      find.byKey(const Key('supporter-paket-lagerfeuer-kaufen')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const Key('supporter-paket-waldsee-erscheinungsbild')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Erscheinungsbild-Seite'), findsOneWidget);
  });

  testWidgets('als Förderer sind alle Pakete enthalten', (tester) async {
    await pumpSeite(
      tester,
      gespeichert: const GekaufterSupportAccess(foerderer: true),
    );

    expect(find.byKey(const Key('supporter-foerderer-aktiv')), findsOneWidget);
    expect(find.text('Enthalten'), findsNWidgets(3));
    expect(find.text('Kaufen'), findsNothing);
  });

  testWidgets('Testschalter Förderer geht dem Store-Stand vor', (tester) async {
    await pumpSeite(
      tester,
      testschalter: const SchalterSupportAccess(SupporterTestZugang.foerderer),
    );

    expect(find.byKey(const Key('supporter-foerderer-aktiv')), findsOneWidget);
    expect(find.text('Enthalten'), findsNWidgets(3));
  });

  testWidgets('ohne Store: Hinweis und keine Kaufknöpfe', (tester) async {
    await pumpSeite(tester, erreichbar: false);

    expect(find.byKey(const Key('supporter-offline')), findsOneWidget);
    expect(find.text('Preis nicht verfügbar'), findsWidgets);
    final knopf = tester.widget<FilledButton>(
      find.byKey(const Key('supporter-foerderer-kaufen')),
    );
    expect(knopf.onPressed, isNull);
  });

  testWidgets('Kauffehler erscheint als Hinweis', (tester) async {
    await pumpSeite(tester);

    await tester.tap(find.byKey(const Key('supporter-paket-waldsee-kaufen')));
    await tester.pump();
    client.controller.add([
      PurchaseDetails(
        productID: 'supporter_paket_wald',
        verificationData: PurchaseVerificationData(
          localVerificationData: '',
          serverVerificationData: '',
          source: 'test',
        ),
        transactionDate: null,
        status: PurchaseStatus.error,
      ),
    ]);
    await tester.pump();
    await tester.pump();

    expect(
      find.text('Kauf nicht abgeschlossen. Versuch es noch einmal.'),
      findsOneWidget,
    );
    expect(model.fehler, isNull);
  });
}

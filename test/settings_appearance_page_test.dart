import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nami/data/appearance/in_memory_appearance_settings_repository.dart';
import 'package:nami/domain/appearance/appearance_catalog.dart';
import 'package:nami/domain/appearance/support_access.dart';
import 'package:nami/domain/supporter/supporter_kauf_repository.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/presentation/model/appearance_model.dart';
import 'package:nami/presentation/model/supporter_kauf_model.dart';
import 'package:nami/presentation/screens/settings_appearance_page.dart';
import 'package:nami/services/app_icon_service.dart';
import 'package:provider/provider.dart';

import 'support/fake_supporter_store_client.dart';

void main() {
  final t = AppLocalizations(const Locale('de'));

  Future<AppearanceModel> pumpPage(
    WidgetTester tester, {
    FakeAppIconService? iconService,
    SupportAccess access = const UnlockedSupportAccess(),
    ValueChanged<ThemeMode>? onThemeModeChanged,
    SupporterKaufModel? kauf,
  }) async {
    final model = AppearanceModel(
      repository: InMemoryAppearanceSettingsRepository(),
      appIconService: iconService ?? FakeAppIconService(),
      access: access,
    );
    await model.load();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AppearanceModel>.value(value: model),
          if (kauf != null) ChangeNotifierProvider.value(value: kauf),
        ],
        child: MaterialApp(
          localizationsDelegates: [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            AppLocalizations.delegate,
          ],
          supportedLocales: const [Locale('de'), Locale('en')],
          locale: const Locale('de'),
          // Hintergrund-Vorschauen animieren sonst endlos.
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: SettingsAppearancePage(onThemeModeChanged: onThemeModeChanged),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return model;
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    final finder = find.byKey(ValueKey(key));
    await tester.scrollUntilVisible(finder, 200);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('schaltet Hell/Dunkel', (tester) async {
    ThemeMode? changed;
    await pumpPage(tester, onThemeModeChanged: (mode) => changed = mode);

    await tester.tap(find.text(t.t('theme_dark')));
    await tester.pumpAndSettle();

    expect(changed, ThemeMode.dark);
  });

  testWidgets('waehlt Palette, Hintergrund, Badge und App-Icon', (
    tester,
  ) async {
    final iconService = FakeAppIconService();
    final model = await pumpPage(tester, iconService: iconService);

    await tapKey(tester, 'appearance-palette-wald');
    expect(model.palette, AppPaletteId.wald);

    await tapKey(tester, 'appearance-icon-LagerfeuerAbend');
    expect(iconService.applied?.key, 'LagerfeuerAbend');

    await tapKey(tester, 'appearance-background-himmel');
    expect(model.background, AppearanceBackgroundId.himmel);

    await tapKey(tester, 'appearance-badge-foerderer-polarstern');
    expect(model.badge, SupporterBadgeId.foerdererPolarstern);

    await tapKey(tester, 'appearance-badge-none');
    expect(model.badge, isNull);
  });

  testWidgets('zeigt Automatisch nur mit Systemunterstuetzung', (tester) async {
    await pumpPage(
      tester,
      iconService: FakeAppIconService(supportsAutomaticVariant: false),
    );

    expect(
      find.byKey(const ValueKey('appearance-icon-NachtlagerAutomatisch')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('appearance-icon-NachtlagerMorgen')),
      findsOneWidget,
    );
  });

  testWidgets('gesperrte Optionen lassen sich nicht waehlen', (tester) async {
    final model = await pumpPage(
      tester,
      access: const SchalterSupportAccess(SupporterTestZugang.keiner),
    );

    await tapKey(tester, 'appearance-palette-nachthimmel');
    expect(model.palette, AppPaletteId.standard);

    await tapKey(tester, 'appearance-palette-hochkontrast');
    expect(model.palette, AppPaletteId.hochkontrast);
    expect(find.byIcon(Icons.lock), findsWidgets);
    expect(find.byKey(const Key('supporter-sheet-nachthimmel')), findsNothing);
  });

  testWidgets('mit Store öffnet eine gesperrte Option das Paket-Sheet', (
    tester,
  ) async {
    final client = FakeSupporterStoreClient(
      preise: const {'supporter_paket_nachthimmel': 1.99},
    );
    final kauf = SupporterKaufModel(
      client: client,
      repository: InMemorySupporterKaufRepository(),
    );
    await kauf.start();
    await pumpPage(
      tester,
      access: const SchalterSupportAccess(SupporterTestZugang.keiner),
      kauf: kauf,
    );

    await tapKey(tester, 'appearance-palette-nachthimmel');

    expect(
      find.byKey(const Key('supporter-sheet-nachthimmel')),
      findsOneWidget,
    );
    expect(find.text('Teil von Paket Nachthimmel'), findsOneWidget);
    await tester.tap(find.byKey(const Key('supporter-sheet-kaufen')));
    await tester.pump();
    expect(client.gekauft, ['supporter_paket_nachthimmel']);
  });
}

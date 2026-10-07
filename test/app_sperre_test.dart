import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nami/data/appearance/in_memory_appearance_settings_repository.dart';
import 'package:nami/domain/appearance/appearance_catalog.dart';
import 'package:nami/domain/auth/auth_profile.dart';
import 'package:nami/domain/auth/auth_session.dart';
import 'package:nami/domain/auth/auth_state.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/presentation/model/appearance_model.dart';
import 'package:nami/presentation/model/auth_session_model.dart';
import 'package:nami/presentation/screens/auth_gate_screen.dart';
import 'package:nami/presentation/widgets/app_sperre_flaeche.dart';
import 'package:nami/presentation/widgets/supporter_background.dart';
import 'package:nami/services/app_icon_service.dart';
import 'package:nami/services/hitobito_data_retention_policy.dart';
import 'package:provider/provider.dart';

import 'support/auth_session_fakes.dart';
import 'support/fake_logger_service.dart';

final _start = DateTime(2026, 10, 7, 12);

/// Modell mit gespeicherter Sitzung: Der Kaltstart sperrt immer.
Future<AuthSessionModel> _gesperrtesModell() async {
  final session = AuthSession(
    accessToken: 'access-token',
    refreshToken: 'refresh-token',
    receivedAt: _start,
  );
  final model = AuthSessionModel(
    repository: InMemoryAuthSessionRepository(initialSession: session),
    profileRepository: InMemoryAuthProfileRepository(
      profile: const AuthProfile(namiId: 7),
      lastSyncAt: _start,
    ),
    oauthService: FakeOauthService(
      sessionToReturn: session,
      profileToReturn: const AuthProfile(namiId: 7),
    ),
    biometricLockService: FakeBiometricLockService(available: true),
    sensitiveStorageService: FakeSensitiveStorageService()
      ..principal = 'person-7'
      ..lastSensitiveSyncAt = _start
      ..lastSensitiveSyncAttemptAt = _start,
    retentionPolicy: HitobitoDataRetentionPolicy(
      maxDataAge: const Duration(days: 90),
      refreshInterval: const Duration(hours: 24),
      nowProvider: () => _start,
    ),
    logger: FakeLoggerService(),
    isAppLockEnabled: () => true,
  );
  await model.initialize();
  return model;
}

Widget _app({
  required AuthSessionModel authModel,
  AppearanceModel? appearance,
  bool sichtschutzAktiv = false,
  _FakePlattform? plattform,
  Future<void> Function()? onZurueck,
}) {
  Widget app = ChangeNotifierProvider<AuthSessionModel>.value(
    value: authModel,
    child: AppSperreZurueckTaste(
      gesperrt: () => authModel.state == AuthState.unlockRequired,
      onZurueck: onZurueck ?? () async {},
      child: MaterialApp(
        localizationsDelegates: [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          AppLocalizations.delegate,
        ],
        supportedLocales: const [Locale('de'), Locale('en')],
        locale: const Locale('de'),
        builder: (context, child) => Consumer<AuthSessionModel>(
          builder: (context, model, _) => Stack(
            fit: StackFit.expand,
            children: [
              AppGesperrterInhalt(
                gesperrt: model.state == AuthState.unlockRequired,
                child: child!,
              ),
              const AppLockOverlay(),
              AppSichtschutz(aktiv: sichtschutzAktiv, plattform: plattform),
            ],
          ),
        ),
        home: const Scaffold(body: Center(child: Text('Startseite'))),
        routes: {
          '/zweite': (_) => const Scaffold(
            body: Center(child: TextField(key: Key('feld'))),
          ),
        },
      ),
    ),
  );
  if (appearance != null) {
    app = ChangeNotifierProvider<AppearanceModel>.value(
      value: appearance,
      child: app,
    );
  }
  return app;
}

void main() {
  group('Sperre (A-16)', () {
    testWidgets('verdeckt den Inhalt und schirmt ihn ab', (tester) async {
      final semantics = tester.ensureSemantics();
      final model = await _gesperrtesModell();
      expect(model.state, AuthState.unlockRequired);

      await tester.pumpWidget(_app(authModel: model));
      await tester.pump();

      expect(find.byKey(const Key('app_lock_overlay')), findsOneWidget);
      // Liegt darunter, ist aber weder antippbar noch für den Screenreader.
      expect(find.text('Startseite'), findsOneWidget);
      expect(find.text('Startseite').hitTestable(), findsNothing);
      expect(find.bySemanticsLabel('Startseite'), findsNothing);
      // Ohne Paket der Verlauf in der Primärfarbe, kein Supporter-Hintergrund.
      expect(find.byType(SupporterBackground), findsNothing);
      expect(find.byKey(const Key('app-sperre-icon')), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('Tastaturfokus gelangt nicht unter die Sperre', (tester) async {
      final model = await _gesperrtesModell();
      await tester.pumpWidget(_app(authModel: model));
      await tester.pump();
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.pushNamed('/zweite');
      await tester.pumpAndSettle();

      final feld = tester.widget<TextField>(find.byKey(const Key('feld')));
      feld.focusNode?.requestFocus();
      await tester.tap(find.byKey(const Key('feld')), warnIfMissed: false);
      await tester.pump();

      final fokus = FocusManager.instance.primaryFocus;
      expect(
        fokus?.context?.findAncestorWidgetOfExactType<TextField>(),
        isNull,
      );
    });

    testWidgets('Zurück-Taste schließt keine Route unter der Sperre', (
      tester,
    ) async {
      final model = await _gesperrtesModell();
      var inDenHintergrund = 0;
      await tester.pumpWidget(
        _app(authModel: model, onZurueck: () async => inDenHintergrund++),
      );
      await tester.pump();
      tester.state<NavigatorState>(find.byType(Navigator)).pushNamed('/zweite');
      await tester.pumpAndSettle();

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('feld')), findsOneWidget);
      expect(inDenHintergrund, 1);
    });

    testWidgets('mit Supporter-Paket greifen Hintergrund und Icon', (
      tester,
    ) async {
      final appearance = AppearanceModel(
        repository: InMemoryAppearanceSettingsRepository(),
        appIconService: FakeAppIconService(),
      );
      await appearance.setBackground(AppearanceBackgroundId.lagerfeuer);
      await appearance.setAppIcon(
        const AppIconChoice(AppIconPackage.kohteSee, AppIconVariant.abend),
      );
      final model = await _gesperrtesModell();
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_app(authModel: model, appearance: appearance));
      await tester.pump();

      final hintergrund = tester.widget<SupporterBackground>(
        find.byType(SupporterBackground),
      );
      expect(hintergrund.background, AppearanceBackgroundId.lagerfeuer);
      expect(hintergrund.maxSceneHeight, 844 * AppSperreFlaeche.szenenAnteil);
      final bild = tester.widget<Image>(
        find.descendant(
          of: find.byKey(const Key('app-sperre-icon')),
          matching: find.byType(Image),
        ),
      );
      expect(
        (bild.image as AssetImage).assetName,
        'assets/supporter/icons/KohteSeeAbend.png',
      );
    });
  });

  group('Sichtschutz (A-17)', () {
    Future<AuthSessionModel> entsperrt() async {
      final model = await _gesperrtesModell();
      await model.unlock();
      expect(model.state, AuthState.signedIn);
      return model;
    }

    testWidgets('verdeckt bei aktiver Sperre, sobald die App nicht vorn ist', (
      tester,
    ) async {
      final plattform = _FakePlattform();
      await tester.pumpWidget(
        _app(
          authModel: await entsperrt(),
          sichtschutzAktiv: true,
          plattform: plattform,
        ),
      );
      expect(find.byKey(const Key('app_sichtschutz')), findsNothing);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(find.byKey(const Key('app_sichtschutz')), findsOneWidget);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(find.byKey(const Key('app_sichtschutz')), findsNothing);
      expect(plattform.aufrufe, [true]);
    });

    testWidgets('ohne App-Sperre bleibt die Vorschau sichtbar', (tester) async {
      final plattform = _FakePlattform();
      await tester.pumpWidget(
        _app(authModel: await entsperrt(), plattform: plattform),
      );

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();

      expect(find.byKey(const Key('app_sichtschutz')), findsNothing);
      expect(plattform.aufrufe, [false]);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    });

    testWidgets('überlagert die Sperre nicht', (tester) async {
      await tester.pumpWidget(
        _app(
          authModel: await _gesperrtesModell(),
          sichtschutzAktiv: true,
          plattform: _FakePlattform(),
        ),
      );

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();

      expect(find.byKey(const Key('app_lock_overlay')), findsOneWidget);
      expect(find.byKey(const Key('app_sichtschutz')), findsNothing);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    });
  });
}

class _FakePlattform extends AppSichtschutzPlattform {
  final List<bool> aufrufe = <bool>[];

  @override
  Future<void> setzen(bool aktiv) async => aufrufe.add(aktiv);
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nami/data/achievements/in_memory_achievement_repository.dart';
import 'package:nami/data/arbeitskontext/hitobito_group_resource.dart';
import 'package:nami/domain/achievements/achievement_definition.dart';
import 'package:nami/domain/arbeitskontext/arbeitskontext.dart';
import 'package:nami/domain/arbeitskontext/arbeitskontext_local_repository.dart';
import 'package:nami/domain/arbeitskontext/arbeitskontext_read_model.dart';
import 'package:nami/domain/arbeitskontext/arbeitskontext_read_model_repository.dart';
import 'package:nami/domain/arbeitskontext/usecases/bestimme_startkontext_usecase.dart';
import 'package:nami/domain/auth/auth_profile.dart';
import 'package:nami/domain/auth/auth_profile_repository.dart';
import 'package:nami/domain/auth/auth_session.dart';
import 'package:nami/domain/auth/auth_session_repository.dart';
import 'package:nami/domain/member/mitglied.dart';
import 'package:nami/domain/settings/app_settings.dart';
import 'package:nami/domain/settings/app_settings_repository.dart';
import 'package:nami/domain/taetigkeit/stufe.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/presentation/model/arbeitskontext_model.dart';
import 'package:nami/presentation/model/auth_session_model.dart';
import 'package:nami/presentation/model/urgent_notification_model.dart';
import 'package:nami/presentation/navigation/navigation_home.page.dart';
import 'package:nami/presentation/screens/statistics_page.dart';
import 'package:nami/services/app_startup_state_service.dart';
import 'package:nami/services/achievement_service.dart';
import 'package:nami/services/biometric_lock_service.dart';
import 'package:nami/services/hitobito_auth_env.dart';
import 'package:nami/services/hitobito_data_retention_policy.dart';
import 'package:nami/services/hitobito_groups_service.dart';
import 'package:nami/services/hitobito_oauth_service.dart';
import 'package:nami/services/logger_service.dart';
import 'package:nami/services/sensitive_storage_service.dart';
import 'package:provider/provider.dart';
import 'package:nami/demo/demo_services.dart';
import 'package:nami/presentation/model/qualifikations_einstellungen_model.dart';
import 'package:nami/presentation/screens/settings_qualifikationen_page.dart';
import 'package:nami/presentation/widgets/app_seitenleiste.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Seitenleiste', () {
    Future<void> pumpShell(
      WidgetTester tester,
      Size groesse, {
      List<SingleChildWidget> extraProviders = const [],
    }) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = groesse;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final authModel = await _createSignedInAuthModel();
      final arbeitskontextModel = await _createArbeitskontextModel(
        authModel: authModel,
      );
      await tester.pumpWidget(
        _buildTestApp(
          authModel: authModel,
          arbeitskontextModel: arbeitskontextModel,
          extraProviders: extraProviders,
          onGenerateRoute: (settings) => MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => Scaffold(body: Text('Route ${settings.name}')),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Finder inLeiste(String text) => find.descendant(
      of: find.byType(AppSeitenleiste),
      matching: find.text(text),
    );

    testWidgets('bleibt unter 840 pt bei der unteren Leiste', (tester) async {
      await pumpShell(tester, const Size(744, 1133));

      expect(find.byType(AppSeitenleiste), findsNothing);
      expect(find.byType(BottomNavigationBar), findsOneWidget);

      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();
      expect(find.text('SCHNELLZUGRIFF'), findsOneWidget);
    });

    testWidgets('ersetzt ab 840 pt die untere Leiste', (tester) async {
      await pumpShell(tester, const Size(1032, 1376));

      expect(find.byType(BottomNavigationBar), findsNothing);
      expect(find.byType(AppSeitenleiste), findsOneWidget);
      expect(
        tester.getSize(find.byType(AppSeitenleiste)).width,
        AppSeitenleiste.schmaleBreite,
      );

      await tester.tap(inLeiste('Statistiken'));
      await tester.pumpAndSettle();
      expect(find.byType(StatisticsPage), findsOneWidget);

      // Der Schnellzugriff steht in der Leiste, nicht in den Einstellungen.
      await tester.tap(inLeiste('Einstellungen'));
      await tester.pumpAndSettle();
      expect(find.text('SCHNELLZUGRIFF'), findsNothing);
      expect(inLeiste('Karte'), findsOneWidget);
      expect(inLeiste('Qualifikationen'), findsOneWidget);
    });

    for (final groesse in const [Size(1032, 1376), Size(402, 874)]) {
      testWidgets(
        'Unterseiten oeffnen im Inhaltsbereich, die Navigation bleibt '
        '(${groesse.width.toInt()} pt)',
        (tester) async {
          await pumpShell(tester, groesse);

          unawaited(
            NavigationHomeScreen.inhaltNavigator!.push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    Scaffold(appBar: AppBar(), body: const Text('Unterseite')),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('Unterseite'), findsOneWidget);
          final seitenleiste = groesse.width >= AppSeitenleiste.ab;
          expect(
            find.byType(AppSeitenleiste),
            seitenleiste ? findsOneWidget : findsNothing,
          );
          expect(
            find.byType(BottomNavigationBar),
            seitenleiste ? findsNothing : findsOneWidget,
          );

          // Ein Tipp auf den Bereich fuehrt zu dessen Startseite.
          await tester.tap(find.byIcon(Icons.groups));
          await tester.pumpAndSettle();
          expect(find.text('Unterseite'), findsNothing);
        },
      );
    }

    testWidgets('ist ab 1200 pt breit mit Ueberschrift', (tester) async {
      await pumpShell(tester, const Size(1376, 1032));

      expect(
        tester.getSize(find.byType(AppSeitenleiste)).width,
        AppSeitenleiste.breiteBreite,
      );
      expect(inLeiste('Schnellzugriff'), findsOneWidget);
    });

    testWidgets(
      'Schnellziel oeffnet neben der Leiste und bleibt beim Verkleinern offen',
      (tester) async {
        final quali = QualifikationsEinstellungenModel(
          InMemoryQualifikationsEinstellungenRepository(),
        );
        await quali.load();
        await pumpShell(
          tester,
          const Size(1032, 1376),
          extraProviders: [
            ChangeNotifierProvider<QualifikationsEinstellungenModel>.value(
              value: quali,
            ),
          ],
        );

        await tester.tap(inLeiste('Qualifikationen'));
        await tester.pumpAndSettle();
        expect(find.byType(SettingsQualifikationenPage), findsOneWidget);
        expect(find.byType(AppSeitenleiste), findsOneWidget);
        expect(find.byType(BackButton), findsNothing);

        // Duo zuklappen bzw. Split View: die Seite bleibt als Unterseite der
        // Einstellungen offen, die untere Leiste bleibt sichtbar.
        tester.view.physicalSize = const Size(402, 874);
        await tester.pumpAndSettle();
        expect(find.byType(AppSeitenleiste), findsNothing);
        expect(find.byType(BottomNavigationBar), findsOneWidget);
        expect(find.byType(SettingsQualifikationenPage), findsOneWidget);
        expect(find.byType(BackButton), findsOneWidget);

        // Wieder aufklappen: zurueck in die Seitenleiste, ohne Zurueck-Pfeil.
        tester.view.physicalSize = const Size(1032, 1376);
        await tester.pumpAndSettle();
        expect(find.byType(AppSeitenleiste), findsOneWidget);
        expect(find.byType(SettingsQualifikationenPage), findsOneWidget);
        expect(find.byType(BackButton), findsNothing);
      },
    );
  });

  testWidgets(
    'zeigt Mitglieder, Statistik und Stufenwechsel ohne AppBar, aber mit SafeArea',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final authModel = await _createSignedInAuthModel();
      final arbeitskontextModel = await _createArbeitskontextModel(
        authModel: authModel,
      );
      final achievementService = AchievementService(
        repository: InMemoryAchievementRepository(),
      );

      await tester.pumpWidget(
        _buildTestApp(
          authModel: authModel,
          arbeitskontextModel: arbeitskontextModel,
          achievementService: achievementService,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AppBar), findsNothing);
      expect(find.byType(SafeArea), findsWidgets);
      expect(find.text('Mitglieder'), findsWidgets);

      await tester.tap(find.byIcon(Icons.insert_chart));
      await tester.pumpAndSettle();

      expect(find.byType(AppBar), findsNothing);
      expect(find.byType(SafeArea), findsWidgets);
      expect(find.byType(StatisticsPage), findsOneWidget);
      final statistics = (await achievementService.loadAll()).firstWhere(
        (p) => p.id == AchievementIds.statisticsOpened,
      );
      expect(statistics.count, 1);

      await tester.tap(find.byIcon(Icons.swap_horiz));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(AppBar), findsNothing);
      expect(find.byType(SafeArea), findsWidgets);
      expect(find.text('Stufenwechsel'), findsWidgets);
      expect(find.byType(Checkbox), findsNothing);

      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();

      expect(find.text('Einstellungen'), findsWidgets);
    },
  );

  testWidgets(
    'bietet ohne geladene Daten bei abgelaufener Anmeldung Neu anmelden statt Dauer-Laden',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final authModel = await _createSignedInAuthModel(markDataSynced: false);
      final arbeitskontextModel = ArbeitskontextModel(
        localRepository: _FakeArbeitskontextLocalRepository(),
        readModelRepository: _FakeArbeitskontextReadModelRepository(),
        groupsService: _FakeHitobitoGroupsService(),
        bestimmeStartkontextUseCase: const BestimmeStartkontextUseCase(),
        logger: _FakeLoggerService(),
      );
      authModel.reportRemoteDataIssue(
        'Token-Anfrage fehlgeschlagen (400, invalid_grant).',
        requiresInteractiveLogin: true,
      );

      await tester.pumpWidget(
        _buildTestApp(
          authModel: authModel,
          arbeitskontextModel: arbeitskontextModel,
        ),
      );
      await tester.pump();

      expect(find.text('Erneute Anmeldung erforderlich'), findsOneWidget);
      expect(find.byKey(const Key('shell-neuanmeldung')), findsOneWidget);
      expect(
        find.byKey(const Key('shell-neuanmeldung-logout')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('shell-neuanmeldung')));
      await tester.pump();
      await tester.pump();

      expect(authModel.requiresInteractiveLogin, isFalse);
      expect(authModel.neuanmeldungen, 1);
      expect(find.text('Erneute Anmeldung erforderlich'), findsNothing);
    },
  );

  testWidgets('erklaert eine durch das System unterbrochene Anmeldung', (
    tester,
  ) async {
    final jetzt = DateTime(2026, 10, 8, 12);
    SharedPreferences.setMockInitialValues({
      AppStartupStateService.anmeldungBegonnenKey: jetzt
          .subtract(const Duration(minutes: 2))
          .toIso8601String(),
    });
    final authModel = AuthSessionModel(
      repository: _InMemoryAuthSessionRepository(),
      profileRepository: _InMemoryAuthProfileRepository(),
      oauthService: _FakeOauthService(),
      biometricLockService: _FakeBiometricLockService(),
      sensitiveStorageService: _FakeSensitiveStorageService(),
      retentionPolicy: HitobitoDataRetentionPolicy(
        maxDataAge: const Duration(days: 90),
        refreshInterval: const Duration(hours: 24),
        nowProvider: () => jetzt,
      ),
      logger: _FakeLoggerService(),
      startupStateService: AppStartupStateService(),
    );
    await authModel.initialize();
    final arbeitskontextModel = await _createArbeitskontextModel(
      authModel: authModel,
    );

    await tester.pumpWidget(
      _buildTestApp(
        authModel: authModel,
        arbeitskontextModel: arbeitskontextModel,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Anmeldung erforderlich'), findsOneWidget);
    expect(
      find.byKey(const Key('anmeldung-unterbrochen-hinweis')),
      findsOneWidget,
    );
    expect(find.text('Anmeldung unterbrochen'), findsOneWidget);
  });

  testWidgets('springt beim Abmelden auf die Mitgliederliste mit Anmeldung', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final authModel = await _createSignedInAuthModel();
    final arbeitskontextModel = await _createArbeitskontextModel(
      authModel: authModel,
    );
    await tester.pumpWidget(
      _buildTestApp(
        authModel: authModel,
        arbeitskontextModel: arbeitskontextModel,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();
    expect(find.text('Einstellungen'), findsWidgets);

    await authModel.logout();
    await arbeitskontextModel.syncForAuth(
      authState: authModel.state,
      session: authModel.session,
      profile: authModel.profile,
    );
    await tester.pumpAndSettle();

    expect(find.text('Anmeldung erforderlich'), findsOneWidget);
    expect(find.text('Mit Hitobito anmelden'), findsOneWidget);
  });

  for (final wegenRechten in <bool>[true, false]) {
    testWidgets(
      wegenRechten
          ? 'erklaert nach Abmeldung wegen geaenderter Rechte den Grund'
          : 'zeigt nach normalem Logout keinen Abmeldegrund',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final authModel = await _createSignedInAuthModel();
        final arbeitskontextModel = await _createArbeitskontextModel(
          authModel: authModel,
        );
        if (wegenRechten) {
          await authModel.logoutWegenFehlenderRechte();
        } else {
          await authModel.logout();
        }
        await arbeitskontextModel.syncForAuth(
          authState: authModel.state,
          session: authModel.session,
          profile: authModel.profile,
        );

        await tester.pumpWidget(
          _buildTestApp(
            authModel: authModel,
            arbeitskontextModel: arbeitskontextModel,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Anmeldung erforderlich'), findsOneWidget);
        expect(
          find.byKey(const Key('abmeldung-hinweis')),
          wegenRechten ? findsOneWidget : findsNothing,
        );
        expect(
          find.text('Rechte geändert'),
          wegenRechten ? findsOneWidget : findsNothing,
        );
      },
    );
  }

  testWidgets(
    'zeigt dezenten Sync-Hinweis statt Vollbild-Fehler, wenn trotz Fehler bereits Daten vorhanden sind',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final authModel = await _createSignedInAuthModel();
      final groupsService = _FakeHitobitoGroupsService(
        groups: const <HitobitoGroupResource>[
          HitobitoGroupResource(
            id: 11,
            name: 'Stamm Musterdorf',
            isLayer: true,
          ),
        ],
      );
      final arbeitskontextModel = ArbeitskontextModel(
        localRepository: _FakeArbeitskontextLocalRepository(),
        readModelRepository: _FakeArbeitskontextReadModelRepository(),
        groupsService: groupsService,
        bestimmeStartkontextUseCase: const BestimmeStartkontextUseCase(),
        logger: _FakeLoggerService(),
      );

      await arbeitskontextModel.syncForAuth(
        authState: authModel.state,
        session: authModel.session,
        profile: authModel.profile,
      );
      expect(arbeitskontextModel.isReady, isTrue);

      groupsService.fetchErrorOverride = Exception('Netzwerkfehler');
      await arbeitskontextModel.initializeForProfile(
        authModel.profile!,
        session: authModel.session,
        force: true,
      );
      expect(arbeitskontextModel.hasStaleDataWarning, isTrue);

      await tester.pumpWidget(
        _buildTestApp(
          authModel: authModel,
          arbeitskontextModel: arbeitskontextModel,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Arbeitskontext konnte nicht initialisiert werden'),
        findsNothing,
      );
      expect(find.text('Mitglieder'), findsWidgets);
      expect(find.byIcon(Icons.sync_problem), findsOneWidget);

      // Der Hinweis verschwindet nach 15 Sekunden von selbst ...
      await tester.pump(const Duration(seconds: 14));
      expect(find.byIcon(Icons.sync_problem), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      expect(find.byIcon(Icons.sync_problem), findsNothing);
      expect(arbeitskontextModel.hasStaleDataWarning, isTrue);

      // ... und erscheint beim naechsten Fehlschlag wieder.
      await arbeitskontextModel.initializeForProfile(
        authModel.profile!,
        session: authModel.session,
        force: true,
      );
      await tester.pump();
      expect(find.byIcon(Icons.sync_problem), findsOneWidget);
    },
  );

  testWidgets(
    'bietet im Fehlerzustand Abmelden und ein offenes Profil, ohne Serverantwort',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final authModel = await _createSignedInAuthModel();
      final groupsService =
          _FakeHitobitoGroupsService(groups: const <HitobitoGroupResource>[])
            ..fetchErrorOverride = const HitobitoGroupsException(
              'Groups-Anfrage fehlgeschlagen (400). Grund: Failed typecasting '
              ':zip_code! /app-src/vendor/bundle/ruby',
              statusCode: 400,
            );
      final arbeitskontextModel = ArbeitskontextModel(
        localRepository: _FakeArbeitskontextLocalRepository(),
        readModelRepository: _FakeArbeitskontextReadModelRepository(),
        groupsService: groupsService,
        bestimmeStartkontextUseCase: const BestimmeStartkontextUseCase(),
        logger: _FakeLoggerService(),
      );
      await arbeitskontextModel.syncForAuth(
        authState: authModel.state,
        session: authModel.session,
        profile: authModel.profile,
      );
      expect(arbeitskontextModel.hasError, isTrue);

      await tester.pumpWidget(
        _buildTestApp(
          authModel: authModel,
          arbeitskontextModel: arbeitskontextModel,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Arbeitskontext konnte nicht initialisiert werden'),
        findsOneWidget,
      );
      expect(find.textContaining('zip_code'), findsNothing);
      expect(find.textContaining('Fehlerhafte Gruppe suchen'), findsOneWidget);
      expect(find.byKey(const Key('shell-error-logout')), findsOneWidget);

      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();
      final kopf = find.byKey(const Key('settings-profile-header'));
      expect(
        find.descendant(of: kopf, matching: find.byIcon(Icons.chevron_right)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: kopf, matching: find.byIcon(Icons.lock_outline)),
        findsNothing,
      );
    },
  );

  testWidgets('zeigt den Ladefortschritt waehrend des initialen Ladens', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final authModel = await _createSignedInAuthModel();
    final groupsService = _FakeHitobitoGroupsService(
      groups: const <HitobitoGroupResource>[
        HitobitoGroupResource(id: 11, name: 'Stamm Musterdorf', isLayer: true),
      ],
    );
    final delayCompleter = Completer<void>();
    // Der Gruppen-Fetch wird absichtlich verzoegert: der Vollbild-Stepper
    // ist per Design nur sichtbar, solange arbeitskontext noch null ist -
    // das ist waehrend der Login-/Gruppen-Schritte der Fall, aber nicht
    // mehr sobald "Mitglieder laden" beginnt (dann ist die Shell schon
    // sichtbar, siehe Punkt 3 "Progressive Anzeige").
    groupsService.fetchDelay = delayCompleter.future;
    final arbeitskontextModel = ArbeitskontextModel(
      localRepository: _FakeArbeitskontextLocalRepository(),
      readModelRepository: _FakeArbeitskontextReadModelRepository(),
      groupsService: groupsService,
      bestimmeStartkontextUseCase: const BestimmeStartkontextUseCase(),
      logger: _FakeLoggerService(),
    );

    unawaited(
      arbeitskontextModel.syncForAuth(
        authState: authModel.state,
        session: authModel.session,
        profile: authModel.profile,
      ),
    );

    await tester.pumpWidget(
      _buildTestApp(
        authModel: authModel,
        arbeitskontextModel: arbeitskontextModel,
      ),
    );
    await tester.pump();

    expect(find.text('Gruppen'), findsOneWidget);
    // Kein Text mehr fuer den generischen Lade-/Wartezustand - nur noch
    // Icons: Login ist fertig (Haken), Gruppen laedt (Spinner). Rollen laden
    // erst ab der Mitglieder-Phase parallel mit und warten bis dahin genau
    // wie Mitglieder/Qualifikationen/Veranstaltungen (Kreis-Icon).
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byIcon(Icons.circle_outlined), findsNWidgets(4));

    delayCompleter.complete();
    await tester.pumpAndSettle();

    expect(arbeitskontextModel.isReady, isTrue);
  });

  testWidgets(
    'zeigt Qualifikationen/Veranstaltungen als Platzhalter-Zeilen, rueckt '
    'Rollen/Qualifikationen unter Mitglieder ein und faerbt wartende Zeilen '
    'lesbar statt mit dem kontrastarmen outline-Ton',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final authModel = await _createSignedInAuthModel();
      final groupsService = _FakeHitobitoGroupsService(
        groups: const <HitobitoGroupResource>[
          HitobitoGroupResource(
            id: 11,
            name: 'Stamm Musterdorf',
            isLayer: true,
          ),
        ],
      );
      final delayCompleter = Completer<void>();
      groupsService.fetchDelay = delayCompleter.future;
      final arbeitskontextModel = ArbeitskontextModel(
        localRepository: _FakeArbeitskontextLocalRepository(),
        readModelRepository: _FakeArbeitskontextReadModelRepository(),
        groupsService: groupsService,
        bestimmeStartkontextUseCase: const BestimmeStartkontextUseCase(),
        logger: _FakeLoggerService(),
      );

      unawaited(
        arbeitskontextModel.syncForAuth(
          authState: authModel.state,
          session: authModel.session,
          profile: authModel.profile,
        ),
      );

      await tester.pumpWidget(
        _buildTestApp(
          authModel: authModel,
          arbeitskontextModel: arbeitskontextModel,
        ),
      );
      await tester.pump();

      // Die beiden Platzhalter-Zeilen sind sichtbar, obwohl es dafuer noch
      // keine echte Lade-Logik gibt.
      expect(find.text('Qualifikationen'), findsOneWidget);
      expect(find.text('Veranstaltungen'), findsOneWidget);

      // "Mitglieder" erscheint zusaetzlich als Tab-Label in der unteren
      // Navigation - hier interessiert nur das oberste Vorkommen (die
      // Checkliste), daher wird ueber die y-Position gefiltert.
      Offset topmostTopLeft(String label) {
        final positions =
            tester
                .renderObjectList<RenderBox>(find.text(label))
                .map((box) => box.localToGlobal(Offset.zero))
                .toList()
              ..sort((a, b) => a.dy.compareTo(b.dy));
        return positions.first;
      }

      // Rollen und Qualifikationen sind als Unterpunkte von Mitgliedern
      // eingerueckt, Gruppen/Mitglieder/Veranstaltungen dagegen nicht.
      final gruppenLeft = topmostTopLeft('Gruppen').dx;
      final mitgliederLeft = topmostTopLeft('Mitglieder').dx;
      final rollenLeft = topmostTopLeft('Rollen').dx;
      final qualifikationenLeft = topmostTopLeft('Qualifikationen').dx;
      final veranstaltungenLeft = topmostTopLeft('Veranstaltungen').dx;

      expect(rollenLeft, greaterThan(gruppenLeft));
      expect(rollenLeft, greaterThan(mitgliederLeft));
      expect(qualifikationenLeft, rollenLeft);
      expect(veranstaltungenLeft, gruppenLeft);

      // Wartende Zeilen (hier: Qualifikationen) sind nicht mehr mit dem
      // kontrastarmen outline-Ton eingefaerbt, sondern mit onSurfaceVariant.
      final theme = Theme.of(tester.element(find.text('Qualifikationen')));
      final qualifikationenStyle = tester
          .widget<Text>(find.text('Qualifikationen'))
          .style;
      expect(qualifikationenStyle?.color, theme.colorScheme.onSurfaceVariant);
      expect(qualifikationenStyle?.color, isNot(theme.colorScheme.outline));
      final waitingIcon = tester.widget<Icon>(
        find.byIcon(Icons.circle_outlined).first,
      );
      expect(waitingIcon.color, theme.colorScheme.onSurfaceVariant);
      expect(waitingIcon.color, isNot(theme.colorScheme.outline));

      delayCompleter.complete();
      await tester.pumpAndSettle();

      expect(arbeitskontextModel.isReady, isTrue);
    },
  );

  testWidgets(
    'zeigt nach dem Setzen des Arbeitskontexts keine Lade-Checkliste mehr, '
    'auch wenn Mitglieder noch laden',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final authModel = await _createSignedInAuthModel();
      final groupsService = _FakeHitobitoGroupsService(
        groups: const <HitobitoGroupResource>[
          HitobitoGroupResource(
            id: 11,
            name: 'Stamm Musterdorf',
            isLayer: true,
          ),
        ],
      );
      final readModelRepository = _FakeArbeitskontextReadModelRepository();
      final refreshCompleter = Completer<void>();
      readModelRepository.refreshDelay = refreshCompleter.future;
      final arbeitskontextModel = ArbeitskontextModel(
        localRepository: _FakeArbeitskontextLocalRepository(),
        readModelRepository: readModelRepository,
        groupsService: groupsService,
        bestimmeStartkontextUseCase: const BestimmeStartkontextUseCase(),
        logger: _FakeLoggerService(),
      );

      unawaited(
        arbeitskontextModel.syncForAuth(
          authState: authModel.state,
          session: authModel.session,
          profile: authModel.profile,
        ),
      );

      await tester.pumpWidget(
        _buildTestApp(
          authModel: authModel,
          arbeitskontextModel: arbeitskontextModel,
        ),
      );
      await tester.pump();
      await tester.pump();

      // Gruppen sind fertig (arbeitskontext gesetzt), der Vollbild-Stepper
      // ist deshalb weg, obwohl die Mitglieder noch am blockierten refresh()
      // haengen. Den laufenden Sync zeigt nur noch der globale Ladebalken,
      // ueber der Mitgliederliste erscheint kein Banner.
      expect(arbeitskontextModel.arbeitskontext, isNotNull);
      expect(arbeitskontextModel.isSynchronizing, isTrue);
      expect(
        find.text('Arbeitskontext konnte nicht initialisiert werden'),
        findsNothing,
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);

      refreshCompleter.complete();
      await tester.pumpAndSettle();

      expect(arbeitskontextModel.isReady, isTrue);
    },
  );

  testWidgets(
    'zeigt bereits geladene Mitglieder progressiv an, waehrend weitere '
    'Seiten nachladen',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final authModel = await _createSignedInAuthModel();
      final groupsService = _FakeHitobitoGroupsService(
        groups: const <HitobitoGroupResource>[
          HitobitoGroupResource(
            id: 11,
            name: 'Stamm Musterdorf',
            isLayer: true,
          ),
        ],
      );
      final arbeitskontext = Arbeitskontext(
        aktiverLayer: const ArbeitskontextLayer(
          id: 11,
          name: 'Stamm Musterdorf',
        ),
      );
      final readModelRepository = _FakeArbeitskontextReadModelRepository();
      readModelRepository.progressReadModels = <ArbeitskontextReadModel>[
        ArbeitskontextReadModel(
          arbeitskontext: arbeitskontext,
          mitglieder: <Mitglied>[
            Mitglied.peopleListItem(
              mitgliedsnummer: '1',
              vorname: 'Julia',
              nachname: 'Keller',
            ),
          ],
        ),
        ArbeitskontextReadModel(
          arbeitskontext: arbeitskontext,
          mitglieder: <Mitglied>[
            Mitglied.peopleListItem(
              mitgliedsnummer: '1',
              vorname: 'Julia',
              nachname: 'Keller',
            ),
            Mitglied.peopleListItem(
              mitgliedsnummer: '2',
              vorname: 'Max',
              nachname: 'Mustermann',
            ),
          ],
        ),
      ];
      final refreshCompleter = Completer<void>();
      readModelRepository.refreshDelay = refreshCompleter.future;
      final arbeitskontextModel = ArbeitskontextModel(
        localRepository: _FakeArbeitskontextLocalRepository(),
        readModelRepository: readModelRepository,
        groupsService: groupsService,
        bestimmeStartkontextUseCase: const BestimmeStartkontextUseCase(),
        logger: _FakeLoggerService(),
      );

      unawaited(
        arbeitskontextModel.syncForAuth(
          authState: authModel.state,
          session: authModel.session,
          profile: authModel.profile,
        ),
      );

      await tester.pumpWidget(
        _buildTestApp(
          authModel: authModel,
          arbeitskontextModel: arbeitskontextModel,
        ),
      );
      await tester.pump();
      await tester.pump();

      // Beide Fortschritts-Seiten laufen synchron (ohne await dazwischen)
      // durch den onProgress-Callback, bevor refresh() am refreshDelay
      // haengen bleibt - beide Mitglieder muessen also schon in der Liste
      // sichtbar sein, obwohl der Sync insgesamt noch nicht fertig ist.
      expect(arbeitskontextModel.isSynchronizing, isTrue);
      expect(find.text('Julia Keller'), findsOneWidget);
      expect(find.text('Max Mustermann'), findsOneWidget);

      refreshCompleter.complete();
      await tester.pumpAndSettle();

      expect(arbeitskontextModel.isReady, isTrue);
    },
  );

  testWidgets(
    'zeigt bei einem spaeteren Sync (Pull-to-refresh/Debug-Tools) keine '
    'Lade-Checkliste',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final authModel = await _createSignedInAuthModel();
      final groupsService = _FakeHitobitoGroupsService(
        groups: const <HitobitoGroupResource>[
          HitobitoGroupResource(
            id: 11,
            name: 'Stamm Musterdorf',
            isLayer: true,
          ),
        ],
      );
      final readModelRepository = _FakeArbeitskontextReadModelRepository();
      final arbeitskontextModel = ArbeitskontextModel(
        localRepository: _FakeArbeitskontextLocalRepository(),
        readModelRepository: readModelRepository,
        groupsService: groupsService,
        bestimmeStartkontextUseCase: const BestimmeStartkontextUseCase(),
        logger: _FakeLoggerService(),
      );

      await arbeitskontextModel.syncForAuth(
        authState: authModel.state,
        session: authModel.session,
        profile: authModel.profile,
      );
      expect(arbeitskontextModel.isReady, isTrue);

      await tester.pumpWidget(
        _buildTestApp(
          authModel: authModel,
          arbeitskontextModel: arbeitskontextModel,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Lädt…'), findsNothing);

      // Simuliert einen spaeteren Sync ueber Pull-to-refresh oder die
      // Debug-Tools (beide rufen refreshFromRemote auf einem bereits
      // "ready" ArbeitskontextModel auf). Den Sync zeigt nur der globale
      // Ladebalken, die Liste bleibt ohne Banner sichtbar.
      final refreshCompleter = Completer<void>();
      readModelRepository.refreshDelay = refreshCompleter.future;
      unawaited(
        arbeitskontextModel.refreshFromRemote(
          session: authModel.session,
          profile: authModel.profile,
          scheduleRolesPreload: false,
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(arbeitskontextModel.isSynchronizing, isTrue);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Lädt…'), findsNothing);

      refreshCompleter.complete();
      await tester.pumpAndSettle();

      expect(arbeitskontextModel.isReady, isTrue);
    },
  );

  testWidgets(
    'blockiert die App nicht mit dem Fehlerbildschirm, wenn der Arbeitskontext '
    'frisch geladen wurde, der separate AuthSessionModel-Sync aber noch nie '
    'erfolgreich war',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      // Simuliert einen frischen Login/Neuinstall: Der unabhaengige
      // syncHitobitoData()-Pfad (Timer-/Connectivity-getrieben) ist noch
      // nie erfolgreich gelaufen, hasValidLocalData bleibt also false -
      // obwohl ArbeitskontextModel Gruppen und Mitglieder bereits
      // erfolgreich remote geladen hat.
      final authModel = await _createSignedInAuthModel(markDataSynced: false);
      expect(authModel.dataSyncStatus.hasValidLocalData, isFalse);

      final groupsService = _FakeHitobitoGroupsService(
        groups: const <HitobitoGroupResource>[
          HitobitoGroupResource(
            id: 11,
            name: 'Stamm Musterdorf',
            isLayer: true,
          ),
        ],
      );
      final arbeitskontextModel = ArbeitskontextModel(
        localRepository: _FakeArbeitskontextLocalRepository(),
        readModelRepository: _FakeArbeitskontextReadModelRepository(),
        groupsService: groupsService,
        bestimmeStartkontextUseCase: const BestimmeStartkontextUseCase(),
        logger: _FakeLoggerService(),
      );

      await arbeitskontextModel.syncForAuth(
        authState: authModel.state,
        session: authModel.session,
        profile: authModel.profile,
      );
      expect(arbeitskontextModel.isReady, isTrue);

      await tester.pumpWidget(
        _buildTestApp(
          authModel: authModel,
          arbeitskontextModel: arbeitskontextModel,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Arbeitskontext konnte nicht initialisiert werden'),
        findsNothing,
      );
      expect(find.text('Mitglieder'), findsWidgets);
    },
  );

  testWidgets(
    'ermoeglicht Retry ueber den Fehlerbildschirm, wenn der Profil-Abruf '
    'trotz gueltiger Session zunaechst fehlschlaegt',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final oauthService = _FakeOauthService()
        ..fetchProfileFailuresRemaining = 1;
      final authModel = AuthSessionModel(
        repository: _InMemoryAuthSessionRepository(),
        profileRepository: _InMemoryAuthProfileRepository(),
        oauthService: oauthService,
        biometricLockService: _FakeBiometricLockService(),
        sensitiveStorageService: _FakeSensitiveStorageService(),
        retentionPolicy: HitobitoDataRetentionPolicy(
          maxDataAge: const Duration(days: 90),
          refreshInterval: const Duration(hours: 24),
        ),
        logger: _FakeLoggerService(),
      );
      await authModel.signIn();
      await authModel.markSensitiveDataSynced();
      expect(authModel.profile, isNull);

      final groupsService = _FakeHitobitoGroupsService(
        groups: const <HitobitoGroupResource>[
          HitobitoGroupResource(
            id: 11,
            name: 'Stamm Musterdorf',
            isLayer: true,
          ),
        ],
      );
      final arbeitskontextModel = ArbeitskontextModel(
        localRepository: _FakeArbeitskontextLocalRepository(),
        readModelRepository: _FakeArbeitskontextReadModelRepository(),
        groupsService: groupsService,
        bestimmeStartkontextUseCase: const BestimmeStartkontextUseCase(),
        logger: _FakeLoggerService(),
      );

      // Entspricht dem reaktiven Ablauf in main.dart/_MyAppState: nach dem
      // (hier fehlgeschlagenen) Profil-Abruf wird syncForAuth() aufgerufen.
      await arbeitskontextModel.syncForAuth(
        authState: authModel.state,
        session: authModel.session,
        profile: authModel.profile,
      );
      expect(arbeitskontextModel.hasError, isTrue);

      await tester.pumpWidget(
        _buildTestApp(
          authModel: authModel,
          arbeitskontextModel: arbeitskontextModel,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Arbeitskontext konnte nicht initialisiert werden'),
        findsOneWidget,
      );
      final retryButtonFinder = find.widgetWithText(
        FilledButton,
        'Erneut versuchen',
      );
      expect(retryButtonFinder, findsOneWidget);
      // Der Button darf nicht deaktiviert sein, nur weil kein Profil
      // vorhanden ist - genau das war der Bug (Retry war sonst nie moeglich).
      expect(
        tester.widget<FilledButton>(retryButtonFinder).onPressed,
        isNotNull,
      );

      await tester.tap(retryButtonFinder);
      await tester.pumpAndSettle();

      expect(authModel.profile, isNotNull);
      expect(arbeitskontextModel.isReady, isTrue);
      expect(
        find.text('Arbeitskontext konnte nicht initialisiert werden'),
        findsNothing,
      );
    },
  );
}

Widget _buildTestApp({
  required AuthSessionModel authModel,
  required ArbeitskontextModel arbeitskontextModel,
  AchievementService? achievementService,
  List<SingleChildWidget> extraProviders = const [],
  RouteFactory? onGenerateRoute,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthSessionModel>.value(value: authModel),
      ChangeNotifierProvider<ArbeitskontextModel>.value(
        value: arbeitskontextModel,
      ),
      ChangeNotifierProvider<UrgentNotificationModel>(
        create: (_) => UrgentNotificationModel(),
      ),
      Provider<LoggerService>.value(value: _FakeLoggerService()),
      Provider<AchievementService>.value(
        value:
            achievementService ??
            AchievementService(repository: InMemoryAchievementRepository()),
      ),
      ...extraProviders,
    ],
    child: MaterialApp(
      onGenerateRoute: onGenerateRoute,
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('de'), Locale('en')],
      locale: const Locale('de'),
      home: const NavigationHomeScreen(),
    ),
  );
}

Future<AuthSessionModel> _createSignedInAuthModel({
  bool markDataSynced = true,
}) async {
  final authModel = AuthSessionModel(
    repository: _InMemoryAuthSessionRepository(),
    profileRepository: _InMemoryAuthProfileRepository(),
    oauthService: _FakeOauthService(),
    biometricLockService: _FakeBiometricLockService(),
    sensitiveStorageService: _FakeSensitiveStorageService(),
    retentionPolicy: HitobitoDataRetentionPolicy(
      maxDataAge: const Duration(days: 90),
      refreshInterval: const Duration(hours: 24),
    ),
    logger: _FakeLoggerService(),
  );
  await authModel.signIn();
  if (markDataSynced) {
    await authModel.markSensitiveDataSynced();
  }
  return authModel;
}

Future<ArbeitskontextModel> _createArbeitskontextModel({
  required AuthSessionModel authModel,
  HitobitoGroupsService? groupsService,
}) async {
  final model = ArbeitskontextModel(
    localRepository: _FakeArbeitskontextLocalRepository(
      cached: ArbeitskontextReadModel(
        arbeitskontext: Arbeitskontext(
          aktiverLayer: const ArbeitskontextLayer(
            id: 11,
            name: 'Stamm Musterdorf',
          ),
        ),
        mitglieder: <Mitglied>[
          Mitglied.peopleListItem(
            mitgliedsnummer: '1',
            vorname: 'Julia',
            nachname: 'Keller',
          ),
        ],
      ),
    ),
    readModelRepository: _FakeArbeitskontextReadModelRepository(),
    groupsService: groupsService ?? _FakeHitobitoGroupsService(),
    bestimmeStartkontextUseCase: const BestimmeStartkontextUseCase(),
    logger: _FakeLoggerService(),
  );

  await model.syncForAuth(
    authState: authModel.state,
    session: authModel.session,
    profile: authModel.profile,
  );

  return model;
}

class _FakeArbeitskontextLocalRepository
    implements ArbeitskontextLocalRepository {
  _FakeArbeitskontextLocalRepository({this.cached});

  final ArbeitskontextReadModel? cached;

  @override
  Future<void> clearCached() async {}

  @override
  Future<ArbeitskontextReadModel?> loadLastCached() async => cached;

  @override
  Future<void> saveCached(ArbeitskontextReadModel readModel) async {}
}

class _FakeArbeitskontextReadModelRepository
    implements ArbeitskontextReadModelRepository {
  Future<void>? refreshDelay;
  // Simuliert paginiertes Nachladen: jeder Eintrag wird nacheinander per
  // onProgress gemeldet, bevor refresh() mit dem finalen Ergebnis zurueckkehrt.
  List<ArbeitskontextReadModel> progressReadModels =
      const <ArbeitskontextReadModel>[];

  @override
  Future<ArbeitskontextReadModel> loadRoles({
    required String accessToken,
    required ArbeitskontextReadModel readModel,
  }) async {
    return readModel.copyWith(rolesSindGeladen: true);
  }

  @override
  Future<ArbeitskontextReadModel> loadCached(
    Arbeitskontext arbeitskontext,
  ) async {
    return ArbeitskontextReadModel(arbeitskontext: arbeitskontext);
  }

  @override
  Future<ArbeitskontextReadModel> refresh({
    required String accessToken,
    required Arbeitskontext arbeitskontext,
    List<HitobitoGroupResource>? accessibleGroups,
    void Function(ArbeitskontextReadModel partial)? onProgress,
  }) async {
    for (final partial in progressReadModels) {
      onProgress?.call(partial);
    }
    final delay = refreshDelay;
    if (delay != null) {
      await delay;
    }
    if (progressReadModels.isNotEmpty) {
      return progressReadModels.last;
    }
    return ArbeitskontextReadModel(arbeitskontext: arbeitskontext);
  }
}

class _FakeHitobitoGroupsService extends HitobitoGroupsService {
  _FakeHitobitoGroupsService({
    List<HitobitoGroupResource> groups = const <HitobitoGroupResource>[],
  }) : _groups = groups,
       super(
         config: const HitobitoAuthConfig(
           clientId: 'client',
           clientSecret: 'secret',
           authorizationUrl: 'https://demo.hitobito.com/oauth/authorize',
           tokenUrl: 'https://demo.hitobito.com/oauth/token',
           redirectUri: 'de.jlange.nami.app:/oauth/callback',
           scopeString: 'openid email api',
           discoveryUrl: '',
           profileUrl: 'https://demo.hitobito.com/oauth/profile',
         ),
       );

  final List<HitobitoGroupResource> _groups;
  Object? fetchErrorOverride;
  Future<void>? fetchDelay;

  @override
  Future<List<HitobitoGroupResource>> fetchAccessibleGroups(
    String accessToken,
  ) async {
    final delay = fetchDelay;
    if (delay != null) {
      await delay;
    }
    final error = fetchErrorOverride;
    if (error != null) {
      throw error;
    }
    return _groups;
  }
}

class _InMemoryAuthProfileRepository implements AuthProfileRepository {
  AuthProfile? _profile;
  DateTime? _lastSyncAt;

  @override
  Future<void> clear() async {
    _profile = null;
    _lastSyncAt = null;
  }

  @override
  Future<AuthProfile?> loadCached() async => _profile;

  @override
  Future<DateTime?> loadLastSyncAt() async => _lastSyncAt;

  @override
  Future<void> save(AuthProfile profile) async {
    _profile = profile;
    _lastSyncAt = DateTime(2026, 4, 7);
  }

  @override
  Future<void> saveLastSyncAt(DateTime? syncedAt) async {
    _lastSyncAt = syncedAt;
  }
}

class _InMemoryAuthSessionRepository implements AuthSessionRepository {
  AuthSession? _session;

  @override
  Future<void> clear() async {
    _session = null;
  }

  @override
  Future<AuthSession?> load() async => _session;

  @override
  Future<void> save(AuthSession session) async {
    _session = session;
  }
}

class _FakeOauthService extends HitobitoOauthService {
  _FakeOauthService()
    : super(
        config: const HitobitoAuthConfig(
          clientId: 'client',
          clientSecret: 'secret',
          authorizationUrl: 'https://demo.hitobito.com/oauth/authorize',
          tokenUrl: 'https://demo.hitobito.com/oauth/token',
          redirectUri: 'de.jlange.nami.app:/oauth/callback',
          scopeString: 'openid email api',
          discoveryUrl: '',
          profileUrl: 'https://demo.hitobito.com/oauth/profile',
        ),
      );

  @override
  Future<AuthSession> authenticateInteractive() async {
    return AuthSession(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      receivedAt: DateTime(2026, 4, 7),
    );
  }

  // Kein echter Widerruf ueber das Netz beim Abmelden.
  @override
  Future<bool> revoke(AuthSession session) async => true;

  // Laesst die ersten N Aufrufe von fetchProfile mit einem 404 fehlschlagen -
  // simuliert einen zunaechst fehlerhaften Profil-Endpoint, der sich per
  // Retry doch noch erfolgreich abrufen laesst.
  int fetchProfileFailuresRemaining = 0;

  @override
  Future<AuthProfile> fetchProfile(AuthSession session) async {
    if (fetchProfileFailuresRemaining > 0) {
      fetchProfileFailuresRemaining -= 1;
      throw const HitobitoAuthException(
        'Profil-Anfrage fehlgeschlagen (404).',
        statusCode: 404,
      );
    }
    return const AuthProfile(
      namiId: 7,
      firstName: 'Julia',
      lastName: 'Keller',
      language: 'de',
      primaryGroupId: 11,
      roles: <AuthProfileRole>[
        AuthProfileRole(
          groupId: 11,
          groupName: 'Stamm Musterdorf',
          roleName: 'Stammesfuehrung',
          roleClass: 'Group::Stamm::Leader',
          permissions: <String>['layer_read'],
        ),
      ],
    );
  }
}

class _FakeBiometricLockService implements BiometricLockService {
  @override
  Future<bool> authenticate() async => true;

  @override
  Future<bool> isAvailable() async => false;
}

class _FakeSensitiveStorageService extends SensitiveStorageService {
  String? _principal;
  DateTime? _lastSensitiveSyncAt;
  DateTime? _lastSensitiveSyncAttemptAt;
  DateTime? _lastBackgroundedAt;

  @override
  Future<String?> loadPrincipal() async => _principal;

  @override
  Future<DateTime?> loadLastBackgroundedAt() async => _lastBackgroundedAt;

  @override
  Future<DateTime?> loadLastSensitiveSyncAt() async => _lastSensitiveSyncAt;

  @override
  Future<DateTime?> loadLastSensitiveSyncAttemptAt() async =>
      _lastSensitiveSyncAttemptAt;

  @override
  Future<void> purgeSensitiveData() async {
    _principal = null;
    _lastSensitiveSyncAt = null;
    _lastSensitiveSyncAttemptAt = null;
    _lastBackgroundedAt = null;
  }

  @override
  Future<void> saveLastBackgroundedAt(DateTime? timestamp) async {
    _lastBackgroundedAt = timestamp;
  }

  @override
  Future<void> saveLastSensitiveSyncAt(DateTime? timestamp) async {
    _lastSensitiveSyncAt = timestamp;
  }

  @override
  Future<void> saveLastSensitiveSyncAttemptAt(DateTime? timestamp) async {
    _lastSensitiveSyncAttemptAt = timestamp;
  }

  @override
  Future<void> savePrincipal(String? principal) async {
    _principal = principal;
  }
}

class _FakeLoggerService extends LoggerService {
  _FakeLoggerService()
    : super(
        settingsRepository: _NoopAppSettingsRepository(),
        navigatorKey: GlobalKey<NavigatorState>(),
      );

  @override
  Future<void> log(String service, String message) async {}

  @override
  Future<void> logInfo(String service, String message) async {}

  @override
  Future<void> logWarn(String service, String message) async {}

  @override
  Future<void> logError(
    String service,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) async {}
}

class _NoopAppSettingsRepository extends AppSettingsRepository {
  _NoopAppSettingsRepository();

  @override
  Future<AppSettings> load() async => const AppSettings(
    themeMode: ThemeMode.system,
    languageCode: 'de',
    analyticsEnabled: false,
  );

  @override
  Future<void> saveAnalyticsEnabled(bool enabled) async {}

  @override
  Future<void> saveBiometricLockEnabled(bool enabled) async {}

  @override
  Future<void> saveGeburstagsbenachrichtigungStufen(Set<Stufe> stufen) async {}

  @override
  Future<void> saveLanguageCode(String code) async {}

  @override
  Future<void> saveMemberListSearchResultHighlightEnabled(bool enabled) async {}

  @override
  Future<void> saveNotificationsEnabled(bool enabled) async {}

  @override
  Future<void> saveThemeMode(ThemeMode mode) async {}
}

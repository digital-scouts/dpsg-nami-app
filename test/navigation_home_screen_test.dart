import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nami/data/arbeitskontext/hitobito_group_resource.dart';
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
import 'package:nami/services/biometric_lock_service.dart';
import 'package:nami/services/hitobito_auth_env.dart';
import 'package:nami/services/hitobito_data_retention_policy.dart';
import 'package:nami/services/hitobito_groups_service.dart';
import 'package:nami/services/hitobito_oauth_service.dart';
import 'package:nami/services/logger_service.dart';
import 'package:nami/services/sensitive_storage_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'zeigt Mitglieder, Statistik und Stufenwechsel ohne AppBar, aber mit SafeArea',
    (tester) async {
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

      expect(find.byType(AppBar), findsNothing);
      expect(find.byType(SafeArea), findsWidgets);
      expect(find.text('Mitglieder'), findsWidgets);

      await tester.tap(find.byIcon(Icons.insert_chart));
      await tester.pumpAndSettle();

      expect(find.byType(AppBar), findsNothing);
      expect(find.byType(SafeArea), findsWidgets);
      expect(find.byType(StatisticsPage), findsOneWidget);

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
    'zeigt die Ladeinfo luechenlos als Banner weiter an, waehrend Mitglieder '
    'nach dem Setzen des Arbeitskontexts noch laden',
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
      // ist deshalb weg - aber die Mitglieder haengen noch am blockierten
      // refresh(). Die Ladeinfo darf jetzt nicht verschwinden, sondern muss
      // als Banner ueber der Mitgliederliste sichtbar bleiben.
      expect(arbeitskontextModel.arbeitskontext, isNotNull);
      expect(arbeitskontextModel.isSynchronizing, isTrue);
      expect(
        find.text('Arbeitskontext konnte nicht initialisiert werden'),
        findsNothing,
      );
      // Mitglieder laden noch, und Rollen laden ab sofort parallel dazu mit -
      // beide Zeilen zeigen daher gleichzeitig den Lade-Spinner.
      expect(find.byType(CircularProgressIndicator), findsNWidgets(2));

      refreshCompleter.complete();
      await tester.pumpAndSettle();

      expect(arbeitskontextModel.isReady, isTrue);
    },
  );

  testWidgets(
    'zeigt bereits geladene Mitglieder progressiv an und aktualisiert den '
    'Live-Zaehler in der Ladeinfo, waehrend weitere Seiten nachladen',
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
      expect(find.textContaining('2 geladen'), findsOneWidget);

      refreshCompleter.complete();
      await tester.pumpAndSettle();

      expect(arbeitskontextModel.isReady, isTrue);
    },
  );

  testWidgets(
    'zeigt die Ladeinfo auch bei einem spaeteren Sync (Pull-to-refresh/'
    'Debug-Tools), nicht nur beim initialen Laden',
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
      // "ready" ArbeitskontextModel auf) - die Ladeinfo soll auch dabei
      // wieder sichtbar werden, nicht nur beim allerersten Login.
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
      // "Mitglieder" und "Rollen" zeigen hier beide einen Spinner: Rollen
      // laedt von Anfang an parallel mit, statt kurz den veralteten
      // "Fertig"-Stand vom letzten Sync zu zeigen (das war das urspruengliche
      // Flacker-Problem: Haken -> kurz weg -> Spinner).
      expect(find.byType(CircularProgressIndicator), findsNWidgets(2));

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
    ],
    child: MaterialApp(
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

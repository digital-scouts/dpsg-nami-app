import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:nami/data/achievements/in_memory_achievement_repository.dart';
import 'package:nami/data/achievements/shared_prefs_achievement_repository.dart';
import 'package:nami/data/arbeitskontext/secure_arbeitskontext_local_repository.dart';
import 'package:nami/data/auth/secure_auth_profile_repository.dart';
import 'package:nami/demo/demo_data.dart';
import 'package:nami/demo/demo_services.dart';
import 'package:nami/domain/achievements/achievement_definition.dart';
import 'package:nami/domain/arbeitskontext/usecases/bestimme_startkontext_usecase.dart';
import 'package:nami/domain/auth/auth_state.dart';
import 'package:nami/domain/bundesstatistik/ermittle_stammes_hierarchie_usecase.dart';
import 'package:nami/domain/member/member_write_repository.dart';
import 'package:nami/domain/member/mitglied.dart';
import 'package:nami/domain/settings/app_settings.dart';
import 'package:nami/domain/settings/app_settings_repository.dart';
import 'package:nami/domain/taetigkeit/stufe.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/presentation/model/arbeitskontext_model.dart';
import 'package:nami/presentation/model/auth_session_model.dart';
import 'package:nami/presentation/model/urgent_notification_model.dart';
import 'package:nami/presentation/navigation/navigation_home.page.dart';
import 'package:nami/presentation/widgets/logout_flow.dart';
import 'package:nami/services/achievement_service.dart';
import 'package:nami/services/app_mode_controller.dart';
import 'package:nami/services/biometric_lock_service.dart';
import 'package:nami/services/hitobito_data_retention_policy.dart';
import 'package:nami/services/logger_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Directory hiveDir;

  setUpAll(() async {
    hiveDir = await Directory.systemTemp.createTemp('nami_demo_mode_test');
    Hive.init(hiveDir.path);
  });

  tearDownAll(() async {
    await Hive.close();
    await hiveDir.delete(recursive: true);
  });

  group('Demo-Zugang', () {
    test('meldet an und laedt den Demo-Stamm nur lesend', () async {
      final demo = await _DemoModels.create();

      await demo.authModel.initialize();
      expect(demo.authModel.state, AuthState.signedOut);

      await demo.authModel.signInWithAuthenticatedSession(DemoData.session());
      await demo.arbeitskontextModel.syncForAuth(
        authState: demo.authModel.state,
        session: demo.authModel.session,
        profile: demo.authModel.profile,
      );

      expect(demo.authModel.state, AuthState.signedIn);
      expect(demo.authModel.profile?.firstName, 'David');
      expect(demo.arbeitskontextModel.isUnauthorized, isFalse);
      final readModel = demo.arbeitskontextModel.readModel!;
      expect(readModel.arbeitskontext.aktiverLayer.name, DemoData.stammName);
      expect(readModel.mitglieder.length, DemoData.mitglieder().length);
      for (final Mitglied mitglied in readModel.mitglieder) {
        expect(
          demo.arbeitskontextModel.istMitgliedSchreibbar(mitglied),
          isFalse,
          reason: mitglied.mitgliedsnummer,
        );
      }
      // Die Bundesstatistik erkennt den Demo-Stamm als Stamm.
      expect(
        const ErmittleStammesHierarchieUseCase()(readModel)?.stammId,
        DemoData.layerId.toString(),
      );

      await demo.authModel.logout();
    });

    test('schreibt keine echten sensiblen Boxen', () async {
      final demo = await _DemoModels.create();
      await demo.authModel.signInWithAuthenticatedSession(DemoData.session());
      await demo.authModel.markSensitiveDataSynced();

      for (final boxName in SensitiveStorageBoxNames.all) {
        expect(Hive.isBoxOpen(boxName), isFalse, reason: boxName);
        expect(
          File('${hiveDir.path}/$boxName.hive').existsSync(),
          isFalse,
          reason: boxName,
        );
      }

      await demo.authModel.logout();
      // Nach dem Beenden startet ein neuer Demo-Zugang ohne Altdaten.
      final next = await _DemoModels.create();
      await next.authModel.initialize();
      expect(next.authModel.state, AuthState.signedOut);
      expect(next.authModel.lastSensitiveSyncAt, isNull);
    });

    test('lehnt Schreibzugriffe ab', () async {
      final repository = ReadOnlyMemberWriteRepository();

      await expectLater(
        repository.fetchRemoteMember(accessToken: 'demo', personId: 1),
        throwsA(isA<MemberWriteRejectedException>()),
      );
    });

    test('zeigt Erfolge des Geraets und speichert eigene nicht', () async {
      SharedPreferences.setMockInitialValues({});
      final now = DateTime(2026, 10, 1, 12);
      final device = SharedPrefsAchievementRepository();
      await AchievementService(
        repository: device,
        nowProvider: () => now,
      ).record(AchievementIds.memberEdited);
      final deviceIds = (await device.load()).keys.toSet();

      Future<AchievementService> startDemo() async => AchievementService(
        repository: InMemoryAchievementRepository(
          initialRecords: await device.load(),
        ),
        nowProvider: () => now,
      );

      final demo = await startDemo();
      final memberEdited = (await demo.loadAll()).firstWhere(
        (p) => p.id == AchievementIds.memberEdited,
      );
      expect(memberEdited.count, 1);

      final unlocks = await demo.recordDaily(AchievementIds.statisticsOpened);
      expect(unlocks.single.tier, AchievementTier.bronze);
      expect(
        (await device.load()).keys.toSet(),
        deviceIds,
        reason: 'Demo-Fortschritt landet nicht auf dem Geraet',
      );

      // Nach einem Neustart im Demo kann derselbe Erfolg erneut kommen.
      final restarted = await startDemo();
      final again = await restarted.recordDaily(
        AchievementIds.statisticsOpened,
      );
      expect(again.single.tier, AchievementTier.bronze);
    });

    test('sendet nur das Ereignis "Demo genutzt"', () async {
      final sent = <String>[];
      final hook = demoEventHook((name, _) async => sent.add(name));

      await hook('auth_flow', const {});
      await hook('settings_changed', const {});
      await hook(demoUsedEvent, const {});

      expect(sent, [demoUsedEvent]);
    });

    test('liefert Fuehrungszeugnisse nur fuer Demo-Personen', () async {
      final efz = await DemoHitobitoEfzService().fetchAlleEfzEinsichtnahmen(
        'demo',
      );
      final personIds = DemoData.mitglieder()
          .map((mitglied) => mitglied.personId)
          .toSet();

      expect(efz, isNotEmpty);
      expect(efz.every((e) => personIds.contains(e.personId)), isTrue);
    });

    test('merkt sich den Modus fuer den naechsten Start', () async {
      SharedPreferences.setMockInitialValues({});
      final store = AppModeStore();

      expect(await store.load(), AppMode.live);
      await store.save(AppMode.demo);
      expect(await store.load(), AppMode.demo);
      await store.save(AppMode.live);
      expect(await store.load(), AppMode.live);
    });
  });

  group('Demo-Einstieg in der Oberflaeche', () {
    testWidgets('bietet im abgemeldeten Zustand den Demo-Zugang an', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final switches = <AppMode>[];
      final demo = await tester.runAsync(_DemoModels.create);
      await tester.runAsync(demo!.authModel.initialize);

      await tester.pumpWidget(
        _buildApp(
          demo,
          AppModeController(mode: AppMode.live, switchMode: _record(switches)),
          home: const NavigationHomeScreen(),
        ),
      );
      await tester.pump();

      expect(find.text('Mit Hitobito anmelden'), findsOneWidget);
      await tester.tap(find.byKey(const Key('demo-start')));
      await tester.pump();

      expect(switches, <AppMode>[AppMode.demo]);
    });

    testWidgets('Abmelden beendet im Demo den Demo-Zugang', (tester) async {
      final switches = <AppMode>[];
      final demo = await tester.runAsync(_DemoModels.create);

      await tester.pumpWidget(
        _buildApp(
          demo!,
          AppModeController(mode: AppMode.demo, switchMode: _record(switches)),
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => runLogoutFlow(context),
              child: const Text('Abmelden'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Abmelden'));
      await tester.pump();

      expect(switches, <AppMode>[AppMode.live]);
    });
  });
}

Future<void> Function(AppMode) _record(List<AppMode> switches) {
  return (mode) async => switches.add(mode);
}

Widget _buildApp(
  _DemoModels demo,
  AppModeController appModeController, {
  required Widget home,
}) {
  return MultiProvider(
    providers: [
      Provider<AppModeController>.value(value: appModeController),
      ChangeNotifierProvider<AuthSessionModel>.value(value: demo.authModel),
      ChangeNotifierProvider<ArbeitskontextModel>.value(
        value: demo.arbeitskontextModel,
      ),
      ChangeNotifierProvider<UrgentNotificationModel>(
        create: (_) => UrgentNotificationModel(),
      ),
      Provider<LoggerService>.value(value: _SilentLoggerService()),
      Provider<AchievementService>.value(
        value: AchievementService(repository: InMemoryAchievementRepository()),
      ),
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
      home: home,
    ),
  );
}

/// Baut die sensiblen Models so zusammen wie `main.dart` im Demo-Modus.
class _DemoModels {
  _DemoModels(this.authModel, this.arbeitskontextModel);

  final AuthSessionModel authModel;
  final ArbeitskontextModel arbeitskontextModel;

  static Future<_DemoModels> create() async {
    final storage = DemoSensitiveStorageService();
    await storage.purgeSensitiveData();
    final logger = _SilentLoggerService();
    final authModel = AuthSessionModel(
      repository: InMemoryAuthSessionRepository(),
      profileRepository: SecureAuthProfileRepository(
        sensitiveStorageService: storage,
      ),
      oauthService: DemoOauthService(),
      biometricLockService: _NoBiometricLockService(),
      sensitiveStorageService: storage,
      retentionPolicy: HitobitoDataRetentionPolicy(
        maxDataAge: const Duration(days: 90),
        refreshInterval: const Duration(hours: 24),
      ),
      logger: logger,
    );
    final arbeitskontextModel = ArbeitskontextModel(
      localRepository: SecureArbeitskontextLocalRepository(
        sensitiveStorageService: storage,
      ),
      readModelRepository: DemoArbeitskontextReadModelRepository(
        ladedauer: Duration.zero,
      ),
      groupsService: DemoHitobitoGroupsService(),
      bestimmeStartkontextUseCase: const BestimmeStartkontextUseCase(),
      remoteAccessExecutor: authModel.executeRemoteAccess,
      logger: logger,
    );
    return _DemoModels(authModel, arbeitskontextModel);
  }
}

abstract final class SensitiveStorageBoxNames {
  static const List<String> all = <String>[
    'hitobito_secure_meta_box',
    'hitobito_arbeitskontext_box',
    'hitobito_profile_box',
  ];
}

class _NoBiometricLockService implements BiometricLockService {
  @override
  Future<bool> authenticate() async => true;

  @override
  Future<bool> isAvailable() async => false;
}

class _SilentLoggerService extends LoggerService {
  _SilentLoggerService()
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

  @override
  Future<void> trackAuthFlow(
    String action,
    String outcome, {
    Map<String, Object?> properties = const <String, Object?>{},
  }) async {}
}

class _NoopAppSettingsRepository extends AppSettingsRepository {
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

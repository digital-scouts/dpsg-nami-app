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
import 'package:nami/demo/demo_staemme.dart';
import 'package:nami/domain/achievements/achievement_definition.dart';
import 'package:nami/domain/arbeitskontext/arbeitskontext.dart';
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
import 'package:nami/presentation/widgets/demo_zugang_sheet.dart';
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
    test(
      'Stammesvorstand sieht den ganzen Stamm Silberfels nur lesend',
      () async {
        final demo = await _DemoModels.create(DemoZugang.stammesvorstand);

        await demo.authModel.initialize();
        expect(demo.authModel.state, AuthState.signedOut);
        await demo.anmelden();

        expect(demo.authModel.state, AuthState.signedIn);
        expect(demo.authModel.profile?.firstName, 'Johanna');
        expect(demo.arbeitskontextModel.isUnauthorized, isFalse);
        final readModel = demo.arbeitskontextModel.readModel!;
        expect(
          readModel.arbeitskontext.aktiverLayer.id,
          DemoBezirk.silberfelsId,
        );
        expect(readModel.arbeitskontext.verfuegbareLayer, isEmpty);
        expect(
          _nummern(readModel.mitglieder),
          _personen(DemoBezirk.silberfels).toSet(),
        );
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
          DemoBezirk.silberfelsId.toString(),
        );

        await demo.authModel.logout();
      },
    );

    test('Leitung sieht mit group_read nur die eigene Gruppe', () async {
      final demo = await _DemoModels.create(DemoZugang.leitung);
      await demo.anmelden();

      expect(demo.authModel.profile?.firstName, 'David');
      final readModel = demo.arbeitskontextModel.readModel!;
      expect(readModel.arbeitskontext.aktiverLayer.id, DemoBezirk.silberfelsId);
      expect(readModel.arbeitskontext.verfuegbareLayer, isEmpty);
      expect(
        _nummern(readModel.mitglieder),
        _personen(
          DemoBezirk.silberfels,
          gruppenId: DemoBezirk.truppKompassId,
        ).toSet(),
      );
      expect(_nummern(readModel.mitglieder), contains('1052'));
      // Die Gruppen des Stamms liefert Hitobito trotzdem vollstaendig.
      expect(
        readModel.gruppen,
        hasLength(DemoBezirk.silberfels.gruppen.length),
      );
      // Rollen, Qualifikationen und EFZ liefert Hitobito mit group_read nur
      // fuer die eigene Person.
      expect(
        readModel.mitgliedsZuordnungen.map((z) => z.mitgliedsnummer).toSet(),
        {'1052'},
      );
      expect(
        readModel.mitglieder
            .where((m) => m.roles.isNotEmpty)
            .map((m) => m.mitgliedsnummer),
        ['1052'],
      );
      expect(
        readModel.efzEinsichtnahmen.every((e) => e.personId == 1052),
        isTrue,
      );
      expect(
        readModel.qualifikationen.every((q) => q.personId == 1052),
        isTrue,
      );
      final abdeckung = demo.arbeitskontextModel.statistikAbdeckung!;
      expect(abdeckung.gruppenOhneRollen, {DemoBezirk.truppKompassId});
      final andere = readModel.mitglieder.firstWhere(
        (m) => m.mitgliedsnummer != '1052',
      );
      expect(demo.arbeitskontextModel.istVollLesbar(andere), isFalse);

      await demo.authModel.logout();
    });

    test(
      'Bezirksvorstand startet im Bezirk und wechselt in beide Staemme',
      () async {
        final demo = await _DemoModels.create(DemoZugang.bezirksvorstand);
        await demo.anmelden();

        expect(demo.authModel.profile?.firstName, 'Martin');
        var readModel = demo.arbeitskontextModel.readModel!;
        expect(readModel.arbeitskontext.aktiverLayer.id, DemoBezirk.bezirkId);
        expect(
          readModel.arbeitskontext.verfuegbareLayer.map((layer) => layer.id),
          unorderedEquals(<int>[
            DemoBezirk.silberfelsId,
            DemoBezirk.birkenhainId,
          ]),
        );
        expect(
          _nummern(readModel.mitglieder),
          _personen(DemoBezirk.bezirk).toSet(),
        );
        expect(const ErmittleStammesHierarchieUseCase()(readModel), isNull);

        final birkenhain = readModel.arbeitskontext.verfuegbareLayer.firstWhere(
          (layer) => layer.id == DemoBezirk.birkenhainId,
        );
        final gewechselt = await demo.arbeitskontextModel.switchToLayer(
          targetLayer: birkenhain,
          session: demo.authModel.session,
          profile: demo.authModel.profile,
        );

        expect(gewechselt, isTrue);
        readModel = demo.arbeitskontextModel.readModel!;
        expect(
          readModel.arbeitskontext.aktiverLayer.id,
          DemoBezirk.birkenhainId,
        );
        expect(
          _nummern(readModel.mitglieder),
          _personen(DemoBezirk.birkenhain).toSet(),
        );
        final hierarchie = const ErmittleStammesHierarchieUseCase()(readModel);
        expect(hierarchie?.stammId, DemoBezirk.birkenhainId.toString());
        expect(hierarchie?.bezirkId, DemoBezirk.bezirkId.toString());

        await demo.authModel.logout();
      },
    );

    test('Supporter-Extras zeigt die Daten des Stammesvorstands', () {
      final supporter = DemoData(DemoZugang.supporter, now: () => _heute);
      final vorstand = DemoData(DemoZugang.stammesvorstand, now: () => _heute);

      expect(supporter.profile.namiId, vorstand.profile.namiId);
      expect(supporter.profile.primaryGroupId, vorstand.profile.primaryGroupId);
      expect(
        supporter.profile.roles.single.permissions,
        vorstand.profile.roles.single.permissions,
      );
      expect(supporter.session().principal, 'demo-supporter');
    });

    test(
      'schaltet Supporter-Extras nur im Pruef-Zugang mit Store nicht frei',
      () {
        for (final zugang in DemoZugang.values) {
          for (final storeEnabled in [false, true]) {
            expect(
              demoAllesFrei(
                isDemo: false,
                zugang: zugang,
                storeEnabled: storeEnabled,
              ),
              isFalse,
            );
            expect(
              demoAllesFrei(
                isDemo: true,
                zugang: zugang,
                storeEnabled: storeEnabled,
              ),
              !(zugang == DemoZugang.supporter && storeEnabled),
            );
          }
        }
      },
    );

    test('baut jeden Layer fuer jeden Zugang', () {
      for (final zugang in DemoZugang.values) {
        final data = DemoData(zugang, now: () => _heute);
        for (final layer in DemoBezirk.layer) {
          final readModel = data.readModel(
            arbeitskontext: Arbeitskontext(
              aktiverLayer: ArbeitskontextLayer(id: layer.id, name: layer.name),
            ),
          );
          expect(
            readModel.gruppen.every((gruppe) => gruppe.layerId == layer.id),
            isTrue,
            reason: '${zugang.name}/${layer.name}',
          );
          expect(
            readModel.mitglieder.length,
            data.mitglieder(layer.id).length,
            reason: '${zugang.name}/${layer.name}',
          );
        }
      }
    });

    test('schreibt keine echten sensiblen Boxen', () async {
      final demo = await _DemoModels.create(DemoZugang.stammesvorstand);
      await demo.authModel.signInWithAuthenticatedSession(
        demo.demoData.session(),
      );
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
      final next = await _DemoModels.create(DemoZugang.leitung);
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

    test('liefert Fuehrungszeugnisse nur fuer sichtbare Personen', () async {
      Future<Set<int>> efzPersonen(DemoZugang zugang) async {
        final service = DemoHitobitoEfzService(
          DemoData(zugang, now: () => _heute),
        );
        final efz = await service.fetchEfzEinsichtnahmen('demo');
        return efz.map((einsichtnahme) => einsichtnahme.personId).toSet();
      }

      expect(await efzPersonen(DemoZugang.leitung), <int>{1052});
      expect(await efzPersonen(DemoZugang.stammesvorstand), <int>{
        1051,
        1052,
        1053,
        1054,
        1061,
      });
      expect(
        await efzPersonen(DemoZugang.bezirksvorstand),
        containsAll(<int>{3001, 1061, 2061}),
      );
    });

    test(
      'liefert kommende Veranstaltungen ohne Netz und nach Gruppe',
      () async {
        final service = DemoHitobitoEventsService(
          DemoData(DemoZugang.stammesvorstand, now: () => _heute),
        );

        final alle = await service.fetchVeranstaltungen('demo', abTag: _heute);
        expect(alle, isNotEmpty);
        expect(
          alle.every((v) => !v.ende!.isBefore(DateUtils.dateOnly(_heute))),
          isTrue,
        );
        // Nur Core-Felder: kein externer Link, der das Netz oeffnen wuerde.
        expect(alle.every((v) => v.anmeldeLinkExtern == null), isTrue);

        final stamm = await service.fetchVeranstaltungen(
          'demo',
          abTag: _heute,
          gruppenIds: {DemoBezirk.silberfelsId},
        );
        expect(
          stamm.every((v) => v.gruppenIds.contains(DemoBezirk.silberfelsId)),
          isTrue,
        );
        expect(stamm.length, lessThan(alle.length));
        expect(await service.fetchGruppenNamen('demo', {DemoBezirk.bezirkId}), {
          DemoBezirk.bezirkId: 'Bezirk Silbertal',
        });
      },
    );

    test('merkt sich Modus und Zugang fuer den naechsten Start', () async {
      SharedPreferences.setMockInitialValues({});
      final store = AppModeStore();

      expect(await store.load(), AppMode.live);
      await store.save(AppMode.demo, demoZugang: DemoZugang.bezirksvorstand);
      expect(await store.load(), AppMode.demo);
      expect(await store.loadDemoZugang(), DemoZugang.bezirksvorstand);
      await store.save(AppMode.live);
      expect(await store.load(), AppMode.live);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey(AppModeStore.demoZugangKey), isFalse);
    });

    test('merkt sich den Zugang Supporter-Extras', () async {
      SharedPreferences.setMockInitialValues({});
      final store = AppModeStore();

      await store.save(AppMode.demo, demoZugang: DemoZugang.supporter);
      expect(await store.loadDemoZugang(), DemoZugang.supporter);
    });

    test(
      'startet eine Demo ohne gespeicherten Zugang als Stammesvorstand',
      () async {
        SharedPreferences.setMockInitialValues({
          AppModeStore.demoModeActiveKey: true,
        });
        final store = AppModeStore();

        expect(await store.load(), AppMode.demo);
        expect(await store.loadDemoZugang(), DemoZugang.stammesvorstand);
      },
    );
  });

  group('Demo-Einstieg in der Oberflaeche', () {
    testWidgets('Demo ansehen fragt nach dem Zugang', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final switches = <_Wechsel>[];
      final demo = await tester.runAsync(
        () => _DemoModels.create(DemoZugang.stammesvorstand),
      );
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
      await tester.pumpAndSettle();

      expect(switches, isEmpty);
      for (final zugang in DemoZugang.values) {
        expect(
          find.byKey(Key('demo-zugang-${zugang.name}')),
          zugang == DemoZugang.supporter ? findsNothing : findsOneWidget,
        );
      }
      await tester.tap(find.byKey(const Key('demo-zugang-leitung')));
      await tester.pumpAndSettle();

      expect(switches, <_Wechsel>[(AppMode.demo, DemoZugang.leitung)]);
    });

    testWidgets('zeigt Supporter-Extras nur mit Store-Anbindung', (
      tester,
    ) async {
      Future<void> zeige({required bool zeigeSupporter}) async {
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('de'),
            supportedLocales: const [Locale('de'), Locale('en')],
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: Scaffold(
              body: SingleChildScrollView(
                child: DemoZugangSheet(zeigeSupporter: zeigeSupporter),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await zeige(zeigeSupporter: false);
      expect(find.byKey(const Key('demo-zugang-supporter')), findsNothing);
      expect(find.byKey(const Key('demo-zugang-leitung')), findsOneWidget);

      await zeige(zeigeSupporter: true);
      expect(find.byKey(const Key('demo-zugang-supporter')), findsOneWidget);
      expect(find.text('Supporter-Extras'), findsOneWidget);
    });

    testWidgets('Schliessen der Auswahl startet keine Demo', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final switches = <_Wechsel>[];
      final demo = await tester.runAsync(
        () => _DemoModels.create(DemoZugang.stammesvorstand),
      );
      await tester.runAsync(demo!.authModel.initialize);

      await tester.pumpWidget(
        _buildApp(
          demo,
          AppModeController(mode: AppMode.live, switchMode: _record(switches)),
          home: const NavigationHomeScreen(),
        ),
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('demo-start')));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('demo-zugang-leitung')), findsNothing);
      expect(switches, isEmpty);
    });

    testWidgets('Abmelden beendet im Demo den Demo-Zugang', (tester) async {
      final switches = <_Wechsel>[];
      final demo = await tester.runAsync(
        () => _DemoModels.create(DemoZugang.leitung),
      );

      await tester.pumpWidget(
        _buildApp(
          demo!,
          AppModeController(
            mode: AppMode.demo,
            demoZugang: DemoZugang.leitung,
            switchMode: _record(switches),
          ),
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

      expect(switches, <_Wechsel>[(AppMode.live, null)]);
    });
  });
}

final DateTime _heute = DateTime(2026, 3, 15, 10);

typedef _Wechsel = (AppMode, DemoZugang?);

Future<void> Function(AppMode, DemoZugang?) _record(List<_Wechsel> switches) {
  return (mode, zugang) async => switches.add((mode, zugang));
}

Set<String> _nummern(Iterable<Mitglied> mitglieder) =>
    mitglieder.map((mitglied) => mitglied.mitgliedsnummer).toSet();

Iterable<String> _personen(DemoLayer layer, {int? gruppenId}) => layer.personen
    .where((person) => gruppenId == null || person.gruppenId == gruppenId)
    .map((person) => person.mitgliedsnummer);

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
  _DemoModels(this.demoData, this.authModel, this.arbeitskontextModel);

  final DemoData demoData;
  final AuthSessionModel authModel;
  final ArbeitskontextModel arbeitskontextModel;

  static Future<_DemoModels> create(DemoZugang zugang) async {
    final demoData = DemoData(zugang, now: () => _heute);
    final storage = DemoSensitiveStorageService();
    await storage.purgeSensitiveData();
    final logger = _SilentLoggerService();
    final authModel = AuthSessionModel(
      repository: InMemoryAuthSessionRepository(),
      profileRepository: SecureAuthProfileRepository(
        sensitiveStorageService: storage,
      ),
      oauthService: DemoOauthService(demoData),
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
        demoData,
        ladedauer: Duration.zero,
      ),
      groupsService: DemoHitobitoGroupsService(demoData),
      bestimmeStartkontextUseCase: const BestimmeStartkontextUseCase(),
      remoteAccessExecutor: authModel.executeRemoteAccess,
      logger: logger,
    );
    return _DemoModels(demoData, authModel, arbeitskontextModel);
  }

  /// Meldet an wie `main.dart` und laedt danach den Startkontext.
  Future<void> anmelden() async {
    await authModel.signInWithAuthenticatedSession(demoData.session());
    await arbeitskontextModel.syncForAuth(
      authState: authModel.state,
      session: authModel.session,
      profile: authModel.profile,
    );
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

  @override
  Future<AppSperreBestaetigung> bestaetigen() async =>
      AppSperreBestaetigung.nichtVerfuegbar;
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

import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hive_ce/hive.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:nami/core/notifications/pull_notification.dart';
import 'package:nami/core/notifications/pull_notifications_cubit.dart';
import 'package:nami/core/notifications/pull_notifications_repository_factory.dart';
import 'package:nami/data/achievements/in_memory_achievement_repository.dart';
import 'package:nami/data/arbeitskontext/hitobito_arbeitskontext_read_model_repository.dart';
import 'package:nami/data/arbeitskontext/secure_arbeitskontext_local_repository.dart';
import 'package:nami/data/auth/secure_auth_profile_repository.dart';
import 'package:nami/data/auth/secure_auth_session_repository.dart';
import 'package:nami/data/member/hitobito_member_write_repository.dart';
import 'package:nami/data/member/secure_pending_person_update_repository.dart';
import 'package:nami/data/nami_ai/nami_ai_chat_history_local_repository.dart';
import 'package:nami/demo/demo_data.dart';
import 'package:nami/demo/demo_staemme.dart';
import 'package:nami/demo/demo_services.dart';
import 'package:nami/domain/arbeitskontext/arbeitskontext_read_model_repository.dart';
import 'package:nami/domain/auth/auth_session_repository.dart';
import 'package:nami/domain/bundesstatistik/bundesstatistik_teilnahme.dart';
import 'package:nami/domain/bundesstatistik/installation_credentials.dart';
import 'package:nami/domain/member/member_write_repository.dart';
import 'package:nami/domain/member_filters/member_filter_repository.dart';
import 'package:nami/domain/nami_ai/nami_ai_chat_history_repository.dart';
import 'package:nami/domain/arbeitskontext/usecases/bestimme_startkontext_usecase.dart';
import 'package:nami/presentation/model/arbeitskontext_model.dart';
import 'package:nami/presentation/model/auth_session_model.dart';
import 'package:nami/presentation/model/achievements_model.dart';
import 'package:nami/presentation/model/member_edit_model.dart';
import 'package:nami/presentation/model/pending_sync_coordinator.dart';
import 'package:nami/presentation/notifications/app_update_dialog.dart';
import 'package:nami/presentation/notifications/achievement_unlocked.dart';
import 'package:nami/presentation/notifications/feedback_prompt_dialog.dart';
import 'package:nami/presentation/notifications/notifications_hub.dart';
import 'package:nami/presentation/notifications/welcome_dialog.dart';
import 'package:nami/presentation/notifications/wiredash_texte.dart';
import 'package:nami/presentation/screens/auth_gate_screen.dart';
import 'package:nami/presentation/theme/schrift_lizenzen.dart';
import 'package:nami/presentation/theme/theme.dart';
import 'package:nami/presentation/widgets/global_loading_top_bar.dart';
import 'package:nami/services/hitobito_efz_service.dart';
import 'package:nami/services/hitobito_qualifications_service.dart';
import 'package:nami/services/hitobito_roles_service.dart';
import 'package:nami/services/nami_ai/nami_ai_corpus_lookup_service.dart';
import 'package:nami/services/nami_ai/nami_ai_debug_log_service.dart';
import 'package:nami/services/nami_ai/nami_ai_service.dart';
import 'package:nami/services/nami_ai/nami_ai_stream_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:wiredash/wiredash.dart';
import 'package:url_launcher/url_launcher.dart';

import 'data/member_filters/shared_prefs_member_filter_repository.dart';
import 'data/statistiks/shared_prefs_statistik_kachel_repository.dart';
import 'data/statistiks/shared_prefs_statistik_verlauf_repository.dart';
import 'data/bundesstatistik/http_bundesstatistik_repository.dart';
import 'data/bundesstatistik/secure_installation_credentials_repository.dart';
import 'data/bundesstatistik/shared_prefs_bundesstatistik_teilnahme_repository.dart';
import 'data/maps/shared_prefs_address_map_location_repository.dart';
import 'data/appearance/shared_prefs_appearance_settings_repository.dart';
import 'data/supporter/shared_prefs_supporter_kauf_repository.dart';
import 'data/achievements/shared_prefs_achievement_repository.dart';
import 'domain/achievements/achievement_definition.dart';
import 'data/settings/shared_prefs_app_settings_repository.dart';
import 'data/settings/shared_prefs_qualifikations_einstellungen_repository.dart';
import 'domain/appearance/support_access.dart';
import 'domain/auth/auth_profile.dart';
import 'domain/auth/auth_state.dart';
import 'domain/settings/app_settings.dart';
import 'domain/settings/app_settings_repository.dart';
import 'domain/statistiks/statistik_kachel_einstellungen.dart';
import 'domain/statistiks/statistik_verlauf.dart';
import 'l10n/app_localizations.dart';
import 'presentation/model/app_settings_model.dart';
import 'presentation/model/appearance_model.dart';
import 'presentation/model/supporter_kauf_model.dart';
import 'presentation/model/bundesstatistik_model.dart';
import 'presentation/model/locale_model.dart';
import 'presentation/model/member_filters_model.dart';
import 'presentation/model/qualifikations_einstellungen_model.dart';
import 'presentation/model/statistik_kacheln_model.dart';
import 'presentation/model/urgent_notification_model.dart';
import 'presentation/navigation/app_router.dart';
import 'presentation/navigation/navigation_home.page.dart';
import 'presentation/notifications/app_snackbar.dart';
import 'services/app_icon_service.dart';
import 'services/achievement_service.dart';
import 'services/app_mode_controller.dart';
import 'services/teilen_ordner.dart';
import 'services/app_reset_service.dart';
import 'services/app_runtime_controller.dart';
import 'services/app_startup_state_service.dart';
import 'services/app_update_service.dart';
import 'services/statistik_verlauf_service.dart';
import 'services/benachrichtigungs_berechtigung.dart';
import 'services/biometric_lock_service.dart';
import 'services/bundesstatistik_env.dart';
import 'services/data_expiry_notification_service.dart';
import 'services/feedback_prompt_service.dart';
import 'services/geburtstags_erinnerung_service.dart';
import 'services/sitzungs_erinnerung_service.dart';
import 'services/store_review_prompt_service.dart';
import 'services/hitobito_auth_config_controller.dart';
import 'services/hitobito_auth_env.dart';
import 'services/hitobito_data_retention_policy.dart';
import 'services/hitobito_groups_service.dart';
import 'services/hitobito_oauth_service.dart';
import 'services/hitobito_people_service.dart';
import 'services/hitobito_traffic_log_service.dart';
import 'services/legacy_app_data_cleanup_service.dart';
import 'services/logger_service.dart';
import 'services/supporter/supporter_env.dart';
import 'services/supporter/supporter_store_client.dart';
import 'services/qualifikations_erinnerung_service.dart';
import 'services/map_tile_cache_service.dart';
import 'services/network_access_policy.dart';
import 'services/sensitive_storage_service.dart';
import 'services/usage_tracking_service.dart';

final navigatorKey = GlobalKey<NavigatorState>();
final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// Logger der aktuell laufenden App-Composition, fuer die globale
/// Fehlerbehandlung.
LoggerService? _activeLogger;
int _appGeneration = 0;

void main() {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      registriereSchriftlizenzen();
      final appDocDir = await getApplicationDocumentsDirectory();
      Hive.init(appDocDir.path);
      await dotenv.load(fileName: ".env");
      await initializeDateFormatting("de_DE", null);
      Intl.defaultLocale = "de_DE";
      _installGlobalErrorHandlers();

      final appModeStore = AppModeStore();
      await _startApp(
        appDocDir: appDocDir,
        mode: await appModeStore.load(),
        demoZugang: await appModeStore.loadDemoZugang(),
      );
    },
    (error, stack) {
      final logger = _activeLogger;
      // Letzte Schutzschicht für unvorhergesehene Fehler
      if (logger != null) {
        // ignore: discarded_futures
        logger.log('error', 'Zoned: $error\n$stack');
        // ignore: discarded_futures
        logger.trackRuntimeError(
          source: 'zoned',
          error: error,
          stackTrace: stack,
        );
      } else {
        // Fallback: zur Not in stdout schreiben, falls Logger noch nicht bereit ist
        // ignore: avoid_print
        print('Zoned error before logger init: $error\n$stack');
      }
    },
  );
}

bool _loggedMissingOfflineTile = false;

void _installGlobalErrorHandlers() {
  // Globale Fehlerbehandlung: Framework- und ungefangene Fehler loggen/tracken
  FlutterError.onError = (FlutterErrorDetails details) async {
    if (MapTileCacheService.isMissingOfflineTile(details.exception)) {
      // Offline fehlende Kartenkacheln kommen je Kachel; ein Hinweis pro
      // Sitzung reicht, Telemetrie braucht es dafuer nicht.
      if (!_loggedMissingOfflineTile) {
        _loggedMissingOfflineTile = true;
        await _activeLogger?.logInfo(
          'maps',
          'Kartenkacheln fehlen im Offline-Cache',
        );
      }
      return;
    }
    FlutterError.presentError(details);
    await _activeLogger?.logError(
      'error',
      'FlutterError',
      error: details.exception,
      stackTrace: details.stack,
    );
    await _activeLogger?.trackRuntimeError(
      source: 'flutter',
      error: details.exception,
      stackTrace: details.stack,
    );
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    // Ungefangene, asynchrone Fehler
    // ignore: discarded_futures
    _activeLogger?.logError(
      'error',
      'Uncaught runtime error',
      error: error,
      stackTrace: stack,
    );
    // ignore: discarded_futures
    _activeLogger?.trackRuntimeError(
      source: 'uncaught',
      error: error,
      stackTrace: stack,
    );
    return true; // Fehler als behandelt markieren
  };
}

/// Baut alle App-Abhaengigkeiten fuer [mode] auf und startet die App. Im
/// Demo-Modus liegen alle sensiblen Daten nur im Speicher, Hitobito wird nicht
/// angesprochen und die Bundesstatistik laeuft gegen den Mock-Statistikserver.
/// [demoZugang] bestimmt, mit welcher Rolle die Demo den Bezirk zeigt.
Future<void> _startApp({
  required Directory appDocDir,
  required AppMode mode,
  required DemoZugang demoZugang,
}) async {
  final isDemo = mode == AppMode.demo;
  final demoData = DemoData(demoZugang);
  // Settings laden und Provider initialisieren
  final AppSettingsRepository settingsRepo = SharedPrefsAppSettingsRepository();
  final MemberFilterRepository memberFilterRepository = isDemo
      ? InMemoryMemberFilterRepository()
      : SharedPrefsMemberFilterRepository();
  final StatistikKachelRepository statistikKachelRepository = isDemo
      ? InMemoryStatistikKachelRepository()
      : SharedPrefsStatistikKachelRepository();
  final StatistikVerlaufRepository statistikVerlaufRepository = isDemo
      ? InMemoryStatistikVerlaufRepository()
      : SharedPrefsStatistikVerlaufRepository();
  final appStartupStateService = AppStartupStateService();
  final AppSettings initial = await settingsRepo.load();
  final urgentNotificationModel = UrgentNotificationModel();
  final localeModel = LocaleModel(
    persist: (code) => settingsRepo.saveLanguageCode(code),
  )..setLocale(Locale(initial.languageCode), persist: false);
  final appSettingsModel = AppSettingsModel(initial, settingsRepo);
  // Supporter-Zugang: Die Demo zeigt alles, ausser im Zugang „Supporter-Extras“
  // fuer die Kaufpruefung. Sonst liefert der Store den Kaufstand, sofern
  // SUPPORTER_STORE_ENABLED gesetzt ist. Der Testschalter wirkt nur in Debug-
  // und Profile-Builds (A-94) und geht dort dem Store vor.
  final allesFrei = demoAllesFrei(
    isDemo: isDemo,
    zugang: demoZugang,
    storeEnabled: SupporterEnv.storeEnabled,
  );
  final supporterKaufModel = !allesFrei && SupporterEnv.storeEnabled
      ? SupporterKaufModel(
          client: InAppPurchaseStoreClient(),
          repository: SharedPrefsSupporterKaufRepository(),
          log: (message) => _activeLogger?.logWarn('supporter', message),
        )
      : null;
  SupportAccess aktuellerSupportAccess() {
    if (allesFrei) {
      return const UnlockedSupportAccess();
    }
    final zugang = kReleaseMode
        ? SupporterTestZugang.keiner
        : appSettingsModel.supporterTestZugang;
    if (supporterKaufModel == null || zugang != SupporterTestZugang.keiner) {
      return SchalterSupportAccess(zugang);
    }
    return supporterKaufModel.access;
  }

  final appearanceModel = AppearanceModel(
    repository: SharedPrefsAppearanceSettingsRepository(),
    appIconService: MethodChannelAppIconService(),
    access: aktuellerSupportAccess(),
  );
  await appearanceModel.load();
  void aktualisiereSupportAccess() {
    final neu = aktuellerSupportAccess();
    final alt = appearanceModel.access;
    if (neu.foerderer != alt.foerderer || !setEquals(neu.pakete, alt.pakete)) {
      appearanceModel.updateAccess(neu);
    }
  }

  appSettingsModel.addListener(aktualisiereSupportAccess);
  if (supporterKaufModel != null) {
    supporterKaufModel.addListener(aktualisiereSupportAccess);
    unawaited(supporterKaufModel.start());
  }
  final qualifikationsEinstellungenModel = QualifikationsEinstellungenModel(
    isDemo
        ? InMemoryQualifikationsEinstellungenRepository()
        : SharedPrefsQualifikationsEinstellungenRepository(),
  );
  await qualifikationsEinstellungenModel.load();
  final memberFiltersModel = MemberFiltersModel(memberFilterRepository);
  final statistikKachelnModel = StatistikKachelnModel(
    statistikKachelRepository,
  );

  Future<void> sendToWiredash(String name, Map<String, Object?> props) async {
    final ctx = navigatorKey.currentContext;
    if (ctx == null) return;
    try {
      await Wiredash.of(ctx).trackEvent(name, data: props);
    } catch (_) {}
  }

  final logger = LoggerService(
    settingsRepository: settingsRepo,
    navigatorKey: navigatorKey,
    // Im Demo geht nur "Demo genutzt" raus, keine Ereignisse aus Demo-Aktionen.
    wiredashEventHook: isDemo ? demoEventHook(sendToWiredash) : sendToWiredash,
  );
  final networkAccessPolicy = NetworkAccessPolicy(
    logger: logger,
    noMobileDataEnabled: () => appSettingsModel.noMobileDataEnabled,
  );
  final appUpdateService = AppUpdateService(
    networkAccessPolicy: networkAccessPolicy,
    logger: logger,
  );
  _activeLogger = logger;
  final benachrichtigungsBerechtigung = BenachrichtigungsBerechtigung();
  final dataExpiryNotificationService = DataExpiryNotificationService(
    logger: logger,
  );
  final mapTileCacheService = MapTileCacheService(
    logger: logger,
    networkAccessPolicy: networkAccessPolicy,
  );
  // Update von 0.2.x: alte Daten entfernen, bevor eigene Boxen geoeffnet
  // werden und die Session geladen wird. Danach ist ein Login noetig.
  final legacyAppDataCleanupService = LegacyAppDataCleanupService(
    documentsDirectoryProvider: () async => appDocDir,
    cancelScheduledNotifications: dataExpiryNotificationService.cancelAll,
    deleteLegacyMapStore: () => mapTileCacheService.deleteStore(
      LegacyAppDataCleanupService.legacyMapStoreName,
    ),
    logger: logger,
  );
  if (!isDemo) {
    await legacyAppDataCleanupService.runIfNeeded();
  }
  final hitobitoTrafficLogService = HitobitoTrafficLogService();
  // Fruehere Versionen haben vollstaendige Antworten mit Mitgliederdaten
  // protokolliert; diese Dateien duerfen nicht liegen bleiben.
  await hitobitoTrafficLogService.deleteLegacyFiles();
  final namiAiDebugLogService = NamiAiDebugLogService();
  final namiAiCorpusLookupService = NamiAiCorpusLookupService();

  final sensitiveStorageService = isDemo
      ? DemoSensitiveStorageService()
      : SensitiveStorageService();
  if (isDemo) {
    // Jeder Demo-Start beginnt mit frischen Demo-Daten.
    await sensitiveStorageService.purgeSensitiveData();
  }
  final AuthSessionRepository authSessionRepository = isDemo
      ? InMemoryAuthSessionRepository()
      : SecureAuthSessionRepository();
  final authProfileRepository = SecureAuthProfileRepository(
    sensitiveStorageService: sensitiveStorageService,
  );
  final arbeitskontextLocalRepository = SecureArbeitskontextLocalRepository(
    sensitiveStorageService: sensitiveStorageService,
  );
  final namiAiChatHistoryRepository = NamiAiChatHistoryLocalRepository(
    sensitiveStorageService: sensitiveStorageService,
  );
  final envAuthConfig = isDemo ? demoAuthConfig : HitobitoAuthEnv.authConfig;
  final oauthService = isDemo
      ? DemoOauthService(demoData)
      : HitobitoOauthService(config: envAuthConfig, logger: logger);
  final hitobitoGroupsService = isDemo
      ? DemoHitobitoGroupsService(demoData)
      : HitobitoGroupsService(
          config: envAuthConfig,
          trafficLogService: hitobitoTrafficLogService,
          logger: logger,
        );
  final hitobitoPeopleService = HitobitoPeopleService(
    config: envAuthConfig,
    trafficLogService: hitobitoTrafficLogService,
    logger: logger,
  );
  final hitobitoRolesService = HitobitoRolesService(
    config: envAuthConfig,
    trafficLogService: hitobitoTrafficLogService,
    logger: logger,
  );
  final hitobitoEfzService = isDemo
      ? DemoHitobitoEfzService(demoData)
      : HitobitoEfzService(
          config: envAuthConfig,
          trafficLogService: hitobitoTrafficLogService,
          logger: logger,
        );
  final hitobitoQualificationsService = HitobitoQualificationsService(
    config: envAuthConfig,
    trafficLogService: hitobitoTrafficLogService,
    logger: logger,
  );
  final hitobitoAuthConfigController = HitobitoAuthConfigController(
    sensitiveStorageService: sensitiveStorageService,
    oauthService: oauthService,
    groupsService: hitobitoGroupsService,
    peopleService: hitobitoPeopleService,
    rolesService: hitobitoRolesService,
    efzService: hitobitoEfzService,
    qualificationsService: hitobitoQualificationsService,
    logger: logger,
    envConfig: envAuthConfig,
  );
  final ArbeitskontextReadModelRepository arbeitskontextReadModelRepository =
      isDemo
      ? DemoArbeitskontextReadModelRepository(demoData)
      : HitobitoArbeitskontextReadModelRepository(
          groupsService: hitobitoGroupsService,
          peopleService: hitobitoPeopleService,
          rolesService: hitobitoRolesService,
          efzService: hitobitoEfzService,
          qualificationsService: hitobitoQualificationsService,
          localRepository: arbeitskontextLocalRepository,
          logger: logger,
        );
  final InstallationCredentialsRepository installationCredentialsRepository =
      isDemo
      ? InMemoryInstallationCredentialsRepository()
      : SecureInstallationCredentialsRepository();
  final appResetService = AppResetService(
    clearInstallationCredentials: installationCredentialsRepository.clear,
    authSessionRepository: authSessionRepository,
    sensitiveStorageService: sensitiveStorageService,
    logFileProvider: logger.getLogFile,
    clearLogs: logger.clearAllLogs,
    clearHitobitoTrafficLogs: hitobitoTrafficLogService.clearAllLogs,
    clearMapCache: mapTileCacheService.deleteRoot,
    clearLegacyData: legacyAppDataCleanupService.deleteLegacyData,
    cancelScheduledNotifications: dataExpiryNotificationService.cancelAll,
  );

  final authModel = AuthSessionModel(
    repository: authSessionRepository,
    profileRepository: authProfileRepository,
    oauthService: oauthService,
    biometricLockService: BiometricLockService(logger: logger),
    sensitiveStorageService: sensitiveStorageService,
    retentionPolicy: HitobitoDataRetentionPolicy(
      maxDataAge: HitobitoAuthEnv.maxDataAge,
      refreshInterval: HitobitoAuthEnv.refreshInterval,
    ),
    logger: logger,
    networkAccessPolicy: networkAccessPolicy,
    isAppLockEnabled: () => !isDemo && appSettingsModel.biometricLockEnabled,
    lockTimeout: HitobitoAuthEnv.appLockTimeout,
    startupStateService: appStartupStateService,
    // Geokodierte Wohnorte und Kacheln um Mitgliedsadressen gehoeren zu den
    // Daten, die Logout und Datenablauf entfernen muessen.
    purgeLocalPersonalData: () async {
      await SharedPrefsAddressMapLocationRepository().clearAll();
      await mapTileCacheService.deleteRoot();
      await TeilenOrdner.leeren();
    },
    onPreferredLanguageChanged: (languageCode) async {
      final normalized = AuthProfile.normalizeLanguageCode(languageCode);
      localeModel.setLocale(Locale(normalized), persist: false);
      await appSettingsModel.setLanguageCode(normalized);
    },
  );

  final arbeitskontextModel = ArbeitskontextModel(
    localRepository: arbeitskontextLocalRepository,
    readModelRepository: arbeitskontextReadModelRepository,
    groupsService: hitobitoGroupsService,
    bestimmeStartkontextUseCase: const BestimmeStartkontextUseCase(),
    remoteAccessExecutor: authModel.executeRemoteAccess,
    sessionGeneration: () => authModel.sessionGeneration,
    onKeineBerechtigung: authModel.logoutWegenFehlenderRechte,
    logger: logger,
  );
  // Im Demo sendet der erfundene Stamm an den Mock-Statistikserver und
  // erhaelt von dort synthetische Bundeswerte.
  final bundesstatistikServerUrl = isDemo
      ? BundesstatistikEnv.demoServerUrl
      : BundesstatistikEnv.serverUrl;
  final bundesstatistikEnabled = isDemo || BundesstatistikEnv.isEnabled;
  final bundesstatistikModel = BundesstatistikModel(
    featureEnabled: bundesstatistikEnabled,
    repository: HttpBundesstatistikRepository(
      baseUrl: bundesstatistikEnabled
          ? bundesstatistikServerUrl
          : 'http://localhost',
      timeout: BundesstatistikEnv.fetchTimeout,
    ),
    credentialsRepository: installationCredentialsRepository,
    teilnahmeRepository: isDemo
        ? InMemoryBundesstatistikTeilnahmeRepository(
            // Im Demo sind alle erfundenen Staemme bereits freigegeben.
            initial: [DemoBezirk.silberfelsId, DemoBezirk.birkenhainId].fold(
              BundesstatistikTeilnahme.leer,
              (teilnahme, stammId) => teilnahme.mitEinwilligung(
                demoData.profile.namiId.toString(),
                stammId.toString(),
                DateTime.now(),
              ),
            ),
          )
        : SharedPrefsBundesstatistikTeilnahmeRepository(),
    networkAccessPolicy: networkAccessPolicy,
    logger: logger,
    sendInterval: BundesstatistikEnv.sendInterval,
  );
  await bundesstatistikModel.initialize();
  // Anmeldung und Arbeitskontext bestimmen, ob und was geteilt wird.
  void syncBundesstatistik() {
    unawaited(
      bundesstatistikModel.aktualisiereKontext(
        personId: authModel.profile?.namiId.toString(),
        readModel: arbeitskontextModel.readModel,
        datenstand: authModel.lastSensitiveSyncAt,
        abdeckung: arbeitskontextModel.statistikAbdeckung,
      ),
    );
  }

  authModel.addListener(syncBundesstatistik);
  arbeitskontextModel.addListener(syncBundesstatistik);

  // Erinnerungen an ablaufende Qualifikationen; die Demo plant nichts.
  final qualifikationsErinnerungService = QualifikationsErinnerungService(
    logger: logger,
  );
  void syncQualifikationsErinnerungen() {
    if (isDemo) {
      return;
    }
    // Nur beim Abmelden raeumen; solange beim Start noch nichts geladen ist,
    // bleibt die Merkliste gemeldeter Ablaeufe erhalten.
    if (authModel.state == AuthState.signedOut) {
      unawaited(qualifikationsErinnerungService.raeumen());
      return;
    }
    final readModel = arbeitskontextModel.readModel;
    final personId = authModel.profile?.namiId;
    if (readModel == null ||
        personId == null ||
        arbeitskontextModel.isLoading ||
        arbeitskontextModel.isLoadingRoles) {
      return;
    }
    unawaited(
      qualifikationsErinnerungService.aktualisiere(
        readModel: readModel,
        einstellungen: qualifikationsEinstellungenModel.einstellungen,
        eigenePersonId: personId,
        supporter: appearanceModel.access.qualifikationenFrei,
        pushErlaubt: appSettingsModel.notificationsEnabled,
        sprache: appSettingsModel.languageCode,
      ),
    );
  }

  authModel.addListener(syncQualifikationsErinnerungen);
  arbeitskontextModel.addListener(syncQualifikationsErinnerungen);
  qualifikationsEinstellungenModel.addListener(syncQualifikationsErinnerungen);
  appSettingsModel.addListener(syncQualifikationsErinnerungen);
  appearanceModel.addListener(syncQualifikationsErinnerungen);

  // Geburtstags-Erinnerungen fuer die gewaehlten Stufen; die Demo plant
  // nichts.
  final geburtstagsErinnerungService = GeburtstagsErinnerungService(
    logger: logger,
  );
  void syncGeburtstagsErinnerungen() {
    if (isDemo) {
      return;
    }
    if (authModel.state == AuthState.signedOut) {
      unawaited(geburtstagsErinnerungService.raeumen());
      return;
    }
    final readModel = arbeitskontextModel.readModel;
    if (readModel == null ||
        arbeitskontextModel.isLoading ||
        arbeitskontextModel.isLoadingRoles) {
      return;
    }
    unawaited(
      geburtstagsErinnerungService.aktualisiere(
        readModel: readModel,
        stufen: appSettingsModel.geburstagsbenachrichtigungStufen,
        pushErlaubt: appSettingsModel.notificationsEnabled,
        sprache: appSettingsModel.languageCode,
      ),
    );
  }

  authModel.addListener(syncGeburtstagsErinnerungen);
  arbeitskontextModel.addListener(syncGeburtstagsErinnerungen);
  appSettingsModel.addListener(syncGeburtstagsErinnerungen);

  // Erinnerung, bevor Hitobito die Anmeldung nach einer Woche ohne
  // Erneuerung beendet; die Demo plant nichts.
  final sitzungsErinnerungService = SitzungsErinnerungService(logger: logger);
  void syncSitzungsErinnerung() {
    if (isDemo) {
      return;
    }
    final session = authModel.session;
    final aktiv =
        session != null &&
        session.canRefresh &&
        authModel.state != AuthState.signedOut &&
        !authModel.requiresInteractiveLogin;
    unawaited(
      sitzungsErinnerungService.aktualisiere(
        erneuertAm: aktiv ? session.receivedAt : null,
        pushErlaubt: appSettingsModel.notificationsEnabled,
        sprache: appSettingsModel.languageCode,
      ),
    );
  }

  authModel.addListener(syncSitzungsErinnerung);
  appSettingsModel.addListener(syncSitzungsErinnerung);

  // Beim Zurueckkehren in die App erneut abgleichen: wiederholt eine
  // fehlgeschlagene Planung und beruecksichtigt Zeitzonenwechsel. Ohne
  // Aenderung des Stands passiert nichts.
  AppLifecycleListener(
    onResume: () {
      syncQualifikationsErinnerungen();
      syncGeburtstagsErinnerungen();
      syncSitzungsErinnerung();
    },
  );

  // Monatliche Summen für die Statistik-Kachel „Verlauf“ (nur auf dem Gerät).
  final statistikVerlaufService = StatistikVerlaufService(
    repository: statistikVerlaufRepository,
  );
  arbeitskontextModel.addListener(
    () => unawaited(
      statistikVerlaufService.aktualisiere(
        arbeitskontextModel.readModel,
        ladeLaeuft:
            arbeitskontextModel.isLoading || arbeitskontextModel.isLoadingRoles,
        abdeckung: arbeitskontextModel.statistikAbdeckung,
      ),
    ),
  );

  final pendingPersonUpdateRepository = SecurePendingPersonUpdateRepository(
    sensitiveStorageService: sensitiveStorageService,
  );
  final MemberWriteRepository memberWriteRepository = isDemo
      ? ReadOnlyMemberWriteRepository()
      : HitobitoMemberWriteRepository(
          peopleService: hitobitoPeopleService,
          remoteAccessExecutor: authModel.executeRemoteAccess,
          logger: logger,
        );
  final achievementService = AchievementService(
    // Erfolge gelten pro Geraet. Das Demo zeigt diesen Stand, haelt eigene
    // Fortschritte aber nur im Speicher.
    repository: isDemo
        ? InMemoryAchievementRepository(
            initialRecords: await SharedPrefsAchievementRepository().load(),
          )
        : SharedPrefsAchievementRepository(),
  );
  final achievementsModel = AchievementsModel(service: achievementService);
  final storeReviewPromptService = StoreReviewPromptService(
    logger: logger,
    isDemo: isDemo,
  );
  unawaited(achievementsModel.load());
  final memberEditModel = MemberEditModel(
    memberWriteRepository: memberWriteRepository,
    pendingRepository: pendingPersonUpdateRepository,
    logger: logger,
    onMemberUpdated: arbeitskontextModel.ersetzeMitglied,
    onMemberSaved: () => achievementService.record(AchievementIds.memberEdited),
    sessionGeneration: () => authModel.sessionGeneration,
  );

  // Session-/Arbeitskontext-Initialisierung (inkl. moeglicher voller
  // Netzwerk-Reloads von Gruppen/Mitgliedern) laeuft bewusst NACH
  // runApp() statt davor: vorher blockierte diese Kette den allerersten
  // Flutter-Frame - beim Kaltstart mit unterbrochenem/unvollstaendigem
  // lokalem Cache blieb der Screen dadurch komplett weiss, bis alles
  // fertig geladen war. AuthSessionModel/ArbeitskontextModel starten in
  // einem definierten "initial/initializing"-Zustand und aktualisieren
  // sich reaktiv per notifyListeners() - die bereits vorhandene Lade-UI
  // (_buildPlaceholder in navigation_home.page.dart) zeichnet damit auch
  // hier ihren Spinner/ihre Checkliste, sobald die App-Shell einmal
  // gemountet ist.
  Future<void> runStartupInitialization() async {
    try {
      if (!isDemo) {
        await hitobitoAuthConfigController.initialize();
      }
      await authModel.initialize();
      if (!isDemo) {
        unawaited(authModel.sitzungFrischHalten(trigger: 'startup'));
      }
      if (isDemo && authModel.state == AuthState.signedOut) {
        // Der Demo-Zugang meldet sich wie ein echter Login an und laedt
        // danach seinen Startkontext.
        await authModel.signInWithAuthenticatedSession(demoData.session());
      }
      await arbeitskontextModel.syncForAuth(
        authState: authModel.state,
        session: authModel.session,
        profile: authModel.profile,
      );
      if (isDemo && arbeitskontextModel.readModel != null) {
        await authModel.markSensitiveDataSynced();
      }
      if (authModel.session != null) {
        await memberEditModel.loadPending();
      }
    } catch (error, stack) {
      await logger.log(
        'startup',
        'Kaltstart-Initialisierung fehlgeschlagen: $error\n$stack',
      );
    }
  }

  late final AppModeController appModeController;
  appModeController = AppModeController(
    mode: mode,
    demoZugang: isDemo ? demoZugang : null,
    switchMode: (nextMode, nextDemoZugang) async {
      if (nextMode == mode &&
          (nextMode == AppMode.live || nextDemoZugang == demoZugang)) {
        return;
      }
      final zielZugang = nextDemoZugang ?? demoZugang;
      await logger.log(
        'app_mode',
        'Wechsel von ${mode.name} zu ${nextMode.name}'
            '${nextMode == AppMode.demo ? ' (${zielZugang.name})' : ''}',
      );
      scaffoldMessengerKey.currentState
        ?..hideCurrentSnackBar()
        ..hideCurrentMaterialBanner();
      navigatorKey.currentState?.popUntil((route) => route.isFirst);
      NavigationHomeScreen.zurueckZumHauptbereich();
      if (isDemo) {
        await authModel.logout();
      }
      await AppModeStore().save(nextMode, demoZugang: nextDemoZugang);
      // Alten Baum vollstaendig abbauen, bevor der neue die globalen Keys
      // (Navigator, ScaffoldMessenger) uebernimmt. Sonst wuerde Flutter
      // deren State samt Referenzen auf die alten Models weiterverwenden.
      runApp(const ColoredBox(color: Color(0xFFFFFFFF)));
      await WidgetsBinding.instance.endOfFrame;
      await _startApp(
        appDocDir: appDocDir,
        mode: nextMode,
        demoZugang: zielZugang,
      );
    },
  );

  runApp(
    MultiProvider(
      key: ValueKey<int>(++_appGeneration),
      providers: [
        Provider<AppModeController>.value(value: appModeController),
        ChangeNotifierProvider(
          create: (_) =>
              ThemeModel(persist: (mode) => settingsRepo.saveThemeMode(mode))
                ..currentMode = initial.themeMode,
        ),
        ChangeNotifierProvider<LocaleModel>.value(value: localeModel),
        ChangeNotifierProvider<AppearanceModel>.value(value: appearanceModel),
        if (supporterKaufModel != null)
          ChangeNotifierProvider<SupporterKaufModel>.value(
            value: supporterKaufModel,
          ),
        Provider<AppSettingsRepository>.value(value: settingsRepo),
        Provider<NetworkAccessPolicy>.value(value: networkAccessPolicy),
        Provider<AppUpdateService>.value(value: appUpdateService),
        Provider<DataExpiryNotificationService>.value(
          value: dataExpiryNotificationService,
        ),
        Provider<BenachrichtigungsBerechtigung>.value(
          value: benachrichtigungsBerechtigung,
        ),
        Provider<AppStartupStateService>.value(value: appStartupStateService),
        Provider<AppResetService>.value(value: appResetService),
        ChangeNotifierProvider<AppSettingsModel>.value(value: appSettingsModel),
        ChangeNotifierProvider<MemberFiltersModel>.value(
          value: memberFiltersModel,
        ),
        ChangeNotifierProvider<QualifikationsEinstellungenModel>.value(
          value: qualifikationsEinstellungenModel,
        ),
        ChangeNotifierProvider<StatistikKachelnModel>.value(
          value: statistikKachelnModel,
        ),
        Provider<StatistikVerlaufRepository>.value(
          value: statistikVerlaufRepository,
        ),
        ChangeNotifierProvider<UrgentNotificationModel>.value(
          value: urgentNotificationModel,
        ),
        ChangeNotifierProvider<AuthSessionModel>.value(value: authModel),
        ChangeNotifierProvider<ArbeitskontextModel>.value(
          value: arbeitskontextModel,
        ),
        ChangeNotifierProvider<BundesstatistikModel>.value(
          value: bundesstatistikModel,
        ),
        ChangeNotifierProvider<MemberEditModel>.value(value: memberEditModel),
        Provider<AchievementService>.value(value: achievementService),
        Provider<StoreReviewPromptService>.value(
          value: storeReviewPromptService,
        ),
        ChangeNotifierProvider<AchievementsModel>.value(
          value: achievementsModel,
        ),
        ChangeNotifierProvider<HitobitoAuthConfigController>.value(
          value: hitobitoAuthConfigController,
        ),
        Provider<LoggerService>.value(value: logger),
        Provider<HitobitoTrafficLogService>.value(
          value: hitobitoTrafficLogService,
        ),
        Provider<MapTileCacheService>.value(value: mapTileCacheService),
        Provider<HitobitoEfzService>.value(value: hitobitoEfzService),
        Provider<NamiAiService>.value(value: NamiAiService()),
        Provider<NamiAiStreamService>.value(value: NamiAiStreamService()),
        Provider<NamiAiDebugLogService>.value(value: namiAiDebugLogService),
        Provider<NamiAiCorpusLookupService>.value(
          value: namiAiCorpusLookupService,
        ),
        Provider<NamiAiChatHistoryRepository>.value(
          value: namiAiChatHistoryRepository,
        ),
      ],
      // Ueber MyApp, damit dieser Observer vor dem des Navigators kommt.
      child: AppSperreZurueckTaste(
        gesperrt: () => authModel.state == AuthState.unlockRequired,
        child: const MyApp(),
      ),
    ),
  );
  unawaited(runStartupInitialization());
  unawaited(TeilenOrdner.leeren());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  static const Duration _engagementPromptDelay = Duration(seconds: 5);

  late UsageTrackingService _usage;
  late final LoggerService logger;
  late final AuthSessionModel _authModel;
  late final ArbeitskontextModel _arbeitskontextModel;
  late final AppSettingsModel _appSettingsModel;
  late final MemberEditModel _memberEditModel;
  late final AppResetService _appResetService;
  late final AppStartupStateService _appStartupStateService;
  late final DataExpiryNotificationService _dataExpiryNotificationService;
  late final UrgentNotificationModel _urgentNotificationModel;
  late final AppRuntimeController _appRuntimeController;
  late final bool _isDemo;
  late final PendingSyncCoordinator _pendingSync;
  late bool _lastNoMobileDataEnabled;
  bool _pendingSessionActive = false;
  bool _startupSyncAwaitsAuth = false;
  String? _pendingSessionPrincipal;
  Timer? _authMaintenanceTimer;
  PullNotificationsCubit? _notificationsCubit;
  StreamSubscription<PullNotificationsState>? _notificationsSubscription;
  PullNotificationsLoaded? _pendingNotificationsState;
  bool _didCheckForAppUpdate = false;
  bool _startupFlowCompleted = false;
  bool _startupFlowRunning = false;
  bool _didRunEngagementPrompt = false;
  final FeedbackPromptService _feedbackPromptService = FeedbackPromptService();
  late final AchievementService _achievementService;
  late final StoreReviewPromptService _storeReviewPromptService;
  StreamSubscription<AchievementUnlock>? _achievementSubscription;
  final List<AchievementUnlock> _pendingAchievementUnlocks = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Start Nutzungs-Session beim App-Start
    logger = context.read<LoggerService>();
    _isDemo = context.read<AppModeController>().isDemo;
    _authModel = context.read<AuthSessionModel>();
    _arbeitskontextModel = context.read<ArbeitskontextModel>();
    _appSettingsModel = context.read<AppSettingsModel>();
    _memberEditModel = context.read<MemberEditModel>();
    _appResetService = context.read<AppResetService>();
    _appStartupStateService = context.read<AppStartupStateService>();
    _dataExpiryNotificationService = context
        .read<DataExpiryNotificationService>();
    _urgentNotificationModel = context.read<UrgentNotificationModel>();
    _achievementService = context.read<AchievementService>();
    _storeReviewPromptService = context.read<StoreReviewPromptService>();
    _achievementSubscription = _achievementService.unlocks.listen(
      _handleAchievementUnlock,
    );
    _appRuntimeController = AppRuntimeController(resetApp: _performFullReset);
    _pendingSync = PendingSyncCoordinator(
      connectivity: Connectivity(),
      authModel: _authModel,
      memberEditModel: _memberEditModel,
      noMobileDataEnabled: () => _appSettingsModel.noMobileDataEnabled,
      syncMembers: _syncArbeitskontextComplete,
      // Der Demo-Zugang ist nur lesend, es gibt nichts nachzusenden.
      pendingRetryEnabled: !_isDemo,
    );
    _lastNoMobileDataEnabled = _appSettingsModel.noMobileDataEnabled;
    _pendingSessionActive = _authModel.session != null;
    _pendingSessionPrincipal = _authModel.session?.principal;
    _authModel.addListener(_handleAuthModelChanged);
    _appSettingsModel.addListener(_handleAppSettingsChanged);
    _urgentNotificationModel.setAcknowledgeHandler((id) async {
      await _notificationsCubit?.acknowledge(id);
    });
    _usage = UsageTrackingService(logger: logger);
    // Ausstehende Pause/Sessions vom letzten Lauf auswerten
    _usage.flushPendingSession();
    _usage.startSession();
    unawaited(_achievementService.recordDaily(AchievementIds.appDays));
    _initGlobalNotifications();
    _startAuthMaintenanceTimer();
    _pendingSync.start();
    unawaited(_pendingSync.checkCurrentConnectivity(trigger: 'startup'));
    _syncDataExpiryReminder();
    _scheduleStartupFlow();
    if (_isDemo) {
      // Erst nach dem ersten Frame gibt es den Wiredash-Kontext.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(logger.trackEvent(demoUsedEvent, const {}));
      });
    }
  }

  void _handleAppSettingsChanged() {
    _syncDataExpiryReminder();
    final noMobileDataEnabled = _appSettingsModel.noMobileDataEnabled;
    if (_lastNoMobileDataEnabled == noMobileDataEnabled) {
      return;
    }
    _lastNoMobileDataEnabled = noMobileDataEnabled;
    unawaited(
      _pendingSync.checkCurrentConnectivity(
        trigger: noMobileDataEnabled
            ? 'mobile_data_disabled'
            : 'mobile_data_enabled',
      ),
    );
  }

  void _handleAuthModelChanged() {
    _syncArbeitskontextWithAuth();
    _syncDataExpiryReminder();
    _reloadPendingUpdatesOnSessionChange();
    if (_startupSyncAwaitsAuth && !_isAuthPendingForStartupSync()) {
      _startupSyncAwaitsAuth = false;
      _runStartupSyncIfDue();
    }

    final authState = _authModel.state;
    if (authState == AuthState.signedIn) {
      _scheduleStartupFlow();
      _flushPendingNotificationBanner();
      return;
    }

    if (authState == AuthState.unlockRequired) {
      _urgentNotificationModel.setNotification(null);
      return;
    }

    _resetStartupFlowState();
  }

  /// Logout, Datenablauf und Nutzerwechsel leeren die Pending-Box; die Liste
  /// im Speicher muss danach neu geladen werden. Ohne Session bleibt die Box
  /// zu, dann wird nur die Liste im Speicher geleert.
  void _reloadPendingUpdatesOnSessionChange() {
    final session = _authModel.session;
    final hasSession = session != null;
    if (hasSession == _pendingSessionActive &&
        session?.principal == _pendingSessionPrincipal) {
      return;
    }
    _pendingSessionActive = hasSession;
    _pendingSessionPrincipal = session?.principal;
    if (!hasSession) {
      _memberEditModel.clearPendingInMemory();
      return;
    }
    unawaited(_memberEditModel.loadPending());
  }

  void _syncDataExpiryReminder() {
    if (_isDemo) {
      // Demo-Daten laufen nicht ab.
      return;
    }
    final remaining = _authModel.remainingUntilRelogin;
    final isActive =
        _authModel.hasRemoteAccessIssue &&
        remaining != null &&
        remaining > Duration.zero &&
        remaining <= const Duration(days: 3);

    unawaited(
      _dataExpiryNotificationService.updateExpiryReminder(
        ablauf: isActive ? DateTime.now().add(remaining) : null,
        pushErlaubt: _appSettingsModel.notificationsEnabled,
        sprache: _appSettingsModel.languageCode,
      ),
    );
  }

  void _syncArbeitskontextWithAuth() {
    unawaited(
      _arbeitskontextModel.syncForAuth(
        authState: _authModel.state,
        session: _authModel.session,
        profile: _authModel.profile,
      ),
    );
  }

  void _resetStartupFlowState() {
    _startupFlowCompleted = false;
    _startupFlowRunning = false;
    _didCheckForAppUpdate = false;
    _pendingNotificationsState = null;
    _urgentNotificationModel.setNotification(null);
  }

  bool _canShowStartupUi() => _authModel.state == AuthState.signedIn;

  void _scheduleStartupFlow() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_runStartupFlowIfNeeded());
    });
  }

  Future<void> _runStartupFlowIfNeeded() async {
    if (!mounted ||
        !_canShowStartupUi() ||
        _startupFlowCompleted ||
        _startupFlowRunning) {
      return;
    }

    final dialogContext = navigatorKey.currentContext;
    if (dialogContext == null) {
      return;
    }

    _startupFlowRunning = true;
    scaffoldMessengerKey.currentState?.hideCurrentMaterialBanner();

    try {
      if (_isDemo) {
        // Willkommen, Update- und Feedback-Hinweise gehoeren zur echten
        // Installation und sollen deren Zustand nicht veraendern.
        _startupFlowCompleted = true;
        return;
      }
      final hasSeenWelcome = await _appStartupStateService.hasSeenWelcome();
      if (!hasSeenWelcome) {
        await _zeigeWillkommen(dialogContext);
        await _appStartupStateService.markWelcomeSeen();
        await _feedbackPromptService.recordFirstUse();
        _startupFlowCompleted = true;
        return;
      }

      final didShowUpdateDialog = await _checkForAppUpdate();
      _startupFlowCompleted = true;
      if (!didShowUpdateDialog) {
        unawaited(_runEngagementPromptIfNeeded());
      }
    } finally {
      _startupFlowRunning = false;
      if (_startupFlowCompleted) {
        _flushPendingNotificationBanner();
        _flushAchievementUnlocks();
      }
    }
  }

  /// Willkommen-Stepper nach dem ersten Login. Die Daten laden derweil im
  /// Hintergrund weiter (siehe [_syncArbeitskontextWithAuth]).
  Future<void> _zeigeWillkommen(BuildContext dialogContext) async {
    final appSettings = dialogContext.read<AppSettingsModel>();
    final berechtigung = dialogContext.read<BenachrichtigungsBerechtigung>();
    final themeModel = dialogContext.read<ThemeModel>();
    final biometrie = BiometricLockService(
      logger: dialogContext.read<LoggerService>(),
    );
    final biometrieVerfuegbar = await biometrie.isAvailable();
    // iOS meldet auch ein nie gefragtes „nicht erlaubt“; deshalb gilt nur
    // ein Ja als Stand, sonst zeigt der Stepper „Aktivieren“. Eine fruehere
    // Ablehnung erkennt er erst an der sofortigen Antwort darauf.
    final benachrichtigungenErlaubt = await berechtigung.istErlaubt() == true
        ? true
        : null;
    if (!dialogContext.mounted) {
      return;
    }
    await showWelcomeDialog(
      dialogContext,
      optionen: WillkommenOptionen(
        biometrieVerfuegbar: biometrieVerfuegbar,
        biometrieAktiv: appSettings.biometricLockEnabled,
        benachrichtigungenErlaubt: benachrichtigungenErlaubt,
        analyseAktiv: appSettings.analyticsEnabled,
        keineMobilenDaten: appSettings.noMobileDataEnabled,
        themeMode: themeModel.currentMode,
        // Einmal bestaetigen laesst die Systemabfrage fuer Face ID gleich
        // hier erscheinen; die Sperre greift erst nach 60 s im Hintergrund.
        onBiometrieAktivieren: () async {
          if (!await biometrie.authenticate()) {
            return false;
          }
          await appSettings.setBiometricLockEnabled(true);
          return true;
        },
        onBenachrichtigungenAktivieren: () async {
          final erlaubt = await berechtigung.anfragen();
          if (erlaubt) {
            await appSettings.setNotificationsEnabled(true);
          }
          return erlaubt;
        },
        onAnalyseAendern: appSettings.setAnalyticsEnabled,
        onKeineMobilenDatenAendern: appSettings.setNoMobileDataEnabled,
        // Wie die Einstellungsseite: ThemeModel wirkt sofort, AppSettings
        // speichert.
        onThemeAendern: (mode) async {
          themeModel.setTheme(mode);
          await appSettings.setThemeMode(mode);
        },
        onRechtliches: () =>
            (NavigationHomeScreen.inhaltNavigator ?? navigatorKey.currentState)
                ?.pushNamed(AppRoutes.settingsRechtliches),
        // Android kennt keinen einheitlichen Link in die App-Einstellungen.
        onSystemEinstellungen: defaultTargetPlatform == TargetPlatform.iOS
            ? () => launchUrl(Uri.parse('app-settings:'))
            : null,
      ),
    );
  }

  void _startAuthMaintenanceTimer() {
    _authMaintenanceTimer?.cancel();
    final authModel = context.read<AuthSessionModel>();
    if (_isAuthPendingForStartupSync()) {
      // Vor dem Laden der Session ist jeder Sync-Zeitpunkt unbekannt, und
      // hinter der App-Sperre wird nicht synchronisiert; der Start-Sync
      // folgt, sobald beides vorbei ist.
      _startupSyncAwaitsAuth = true;
    } else {
      _runStartupSyncIfDue();
    }
    _authMaintenanceTimer = Timer.periodic(
      HitobitoAuthEnv.refreshInterval,
      (_) => authModel.syncHitobitoData(
        syncMembers: (accessToken) => _syncArbeitskontextComplete(),
        trigger: 'interval',
        userInitiated: false,
      ),
    );
  }

  bool _isAuthPendingForStartupSync() {
    final state = _authModel.state;
    return state == AuthState.initializing || state == AuthState.unlockRequired;
  }

  void _runStartupSyncIfDue() {
    if (!_authModel.isRefreshAttemptDue) {
      return;
    }
    final allowMobileDataOverride =
        !_authModel.dataSyncStatus.hasValidLocalData;
    unawaited(
      _authModel.syncHitobitoData(
        syncMembers: (accessToken) => _syncArbeitskontextComplete(
          allowMobileDataOverride: allowMobileDataOverride,
        ),
        trigger: 'startup',
        userInitiated: false,
        allowMobileDataOverride: allowMobileDataOverride,
      ),
    );
  }

  Future<void> _syncArbeitskontextComplete({
    bool allowMobileDataOverride = false,
  }) async {
    await _arbeitskontextModel.syncVollstaendig(
      session: _authModel.session,
      profile: _authModel.profile,
      allowMobileDataOverride: allowMobileDataOverride,
    );
  }

  Future<bool> _checkForAppUpdate() async {
    if (_didCheckForAppUpdate) {
      return false;
    }
    _didCheckForAppUpdate = true;

    try {
      final info = await context.read<AppUpdateService>().checkForUpdate();
      final dialogContext = navigatorKey.currentContext;
      if (!mounted || dialogContext == null || info == null) {
        return false;
      }
      await showAppUpdateDialog(dialogContext, info);
      return true;
    } catch (error, stack) {
      await logger.log(
        'update',
        'App-Update-Check fehlgeschlagen: $error\n$stack',
      );
      return false;
    }
  }

  /// Zeigt pro App-Session hoechstens einen Engagement-Dialog: zuerst den
  /// einmaligen Feedback-Dialog, sonst ggf. den Wiredash Promoter Score.
  Future<void> _runEngagementPromptIfNeeded() async {
    if (_didRunEngagementPrompt) {
      return;
    }
    _didRunEngagementPrompt = true;

    try {
      await Future<void>.delayed(_engagementPromptDelay);
      if (!mounted || !_canShowStartupUi()) {
        return;
      }

      if (await _feedbackPromptService.shouldShow()) {
        final ctx = navigatorKey.currentContext;
        if (ctx == null || !ctx.mounted) {
          return;
        }
        // Kein System-Bewertungsdialog im selben App-Start.
        _storeReviewPromptService.markFeedbackPromptShown();
        await runFeedbackPromptFlow(
          ctx,
          logger: logger,
          trigger: 'startup',
          service: _feedbackPromptService,
          achievements: _achievementService,
        );
        return;
      }

      final ctx = navigatorKey.currentContext;
      if (!mounted || ctx == null || !ctx.mounted) {
        return;
      }
      final didShowSurvey = await Wiredash.of(
        ctx,
      ).showPromoterSurvey(inheritMaterialTheme: true);
      if (didShowSurvey) {
        await logger.trackAndLog('feedback', 'promoter_survey', {
          'action': 'shown',
          'trigger': 'startup',
        });
      }
    } catch (error, stack) {
      await logger.log(
        'feedback',
        'Engagement-Dialog fehlgeschlagen: $error\n$stack',
      );
    }
  }

  Future<void> _initGlobalNotifications() async {
    await _notificationsSubscription?.cancel();
    await _notificationsCubit?.close();

    final repo = await createPullNotificationsRepository(
      logger: logger,
      networkAccessPolicy: context.read<NetworkAccessPolicy>(),
    );
    final cubit = PullNotificationsCubit(repo);
    _notificationsSubscription = cubit.stream.listen(_handleNotificationsState);
    _notificationsCubit = cubit;
    await cubit.load();
  }

  void _handleNotificationsState(PullNotificationsState state) {
    if (state is PullNotificationsLoaded) {
      _pendingNotificationsState = state;
    }

    if (!_startupFlowCompleted || !_canShowStartupUi()) {
      _urgentNotificationModel.setNotification(null);
      return;
    }

    if (state is! PullNotificationsLoaded) return;

    _syncUrgentNotification(state);
  }

  void _flushPendingNotificationBanner() {
    final state = _pendingNotificationsState;
    if (state == null || !_startupFlowCompleted || !_canShowStartupUi()) {
      return;
    }

    _syncUrgentNotification(state);
  }

  void _syncUrgentNotification(PullNotificationsLoaded state) {
    if (!_canShowStartupUi()) {
      _urgentNotificationModel.setNotification(null);
      return;
    }

    AppHubNotification? urgent;
    final visibleExternal = NotificationsHub.mapVisibleExternal(
      notifications: state.notifications,
      acknowledged: state.acknowledged,
    );
    try {
      urgent = visibleExternal.firstWhere(
        (notification) =>
            notification.severity == AppNotificationSeverity.urgent,
      );
    } catch (_) {
      urgent = null;
    }

    if (urgent == null) {
      _urgentNotificationModel.setNotification(null);
      return;
    }

    _urgentNotificationModel.setNotification(_toPullNotification(urgent));
  }

  PullNotification _toPullNotification(AppHubNotification message) {
    return PullNotification(
      id: message.id,
      title: message.title,
      body: message.body,
      type: switch (message.severity) {
        AppNotificationSeverity.urgent => 'urgent',
        AppNotificationSeverity.warn => 'warn',
        AppNotificationSeverity.info => 'info',
      },
      createdAt: message.createdAt,
      updatedAt: message.updatedAt,
      deepLink: message.deepLink,
      externalLink: message.externalLink,
    );
  }

  void _handleAchievementUnlock(AchievementUnlock unlock) {
    _pendingAchievementUnlocks.add(unlock);
    _flushAchievementUnlocks();
  }

  /// Zeigt gesammelte Freischaltungen erst, wenn der Startup-Flow (Willkommen,
  /// Update-Hinweis) durch ist. Von mehreren wird nur die höchste gezeigt.
  void _flushAchievementUnlocks() {
    if (_pendingAchievementUnlocks.isEmpty ||
        !_startupFlowCompleted ||
        !_canShowStartupUi()) {
      return;
    }
    final ctx = navigatorKey.currentContext;
    if (ctx == null || !ctx.mounted) {
      return;
    }
    final unlock = _pendingAchievementUnlocks.reduce(
      (a, b) => b.rank >= a.rank ? b : a,
    );
    _pendingAchievementUnlocks.clear();
    unawaited(
      showAchievementUnlocked(
        ctx,
        definition: unlock.definition,
        tier: unlock.tier,
        onShowAll: () =>
            (NavigationHomeScreen.inhaltNavigator ?? navigatorKey.currentState)
                ?.pushNamed(AppRoutes.achievements),
      ),
    );
  }

  Future<void> _performFullReset() async {
    await logger.log('debug_tools', 'Vollstaendiger App-Reset gestartet');
    scaffoldMessengerKey.currentState
      ?..hideCurrentSnackBar()
      ..hideCurrentMaterialBanner();
    navigatorKey.currentState?.popUntil((route) => route.isFirst);
    NavigationHomeScreen.zurueckZumHauptbereich();

    _authMaintenanceTimer?.cancel();
    await _notificationsSubscription?.cancel();
    _notificationsSubscription = null;
    await _notificationsCubit?.close();
    _notificationsCubit = null;
    _pendingNotificationsState = null;
    _urgentNotificationModel.setNotification(null);

    await _authModel.logout();
    await _appResetService.resetAllData();
    _pendingAchievementUnlocks.clear();
    await context.read<AchievementsModel>().load();

    final settingsRepo = context.read<AppSettingsRepository>();
    final defaults = await settingsRepo.load();
    context.read<AppSettingsModel>().replaceWith(defaults);
    context.read<ThemeModel>().setTheme(defaults.themeMode);
    await context.read<AppearanceModel>().reset();
    context.read<LocaleModel>().setLocale(
      Locale(defaults.languageCode),
      persist: false,
    );

    _resetStartupFlowState();
    _usage.startSession();
    _startAuthMaintenanceTimer();
    _pendingSync.start();
    await _initGlobalNotifications();
    unawaited(_pendingSync.checkCurrentConnectivity(trigger: 'app_reset'));
    _scheduleStartupFlow();

    final snackbarContext = navigatorKey.currentContext;
    if (snackbarContext != null) {
      AppSnackbar.showOnMessenger(
        messenger: scaffoldMessengerKey.currentState,
        context: snackbarContext,
        message: AppLocalizations.of(snackbarContext).t('debug_reset_done'),
        type: AppSnackbarType.success,
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authModel.removeListener(_handleAuthModelChanged);
    _appSettingsModel.removeListener(_handleAppSettingsChanged);
    _urgentNotificationModel.setAcknowledgeHandler(null);
    _achievementSubscription?.cancel();
    _authMaintenanceTimer?.cancel();
    _pendingSync.dispose();
    _notificationsSubscription?.cancel();
    _notificationsCubit?.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final authModel = context.read<AuthSessionModel>();
    if (state == AppLifecycleState.resumed) {
      logger.log('lifecycle', 'App resumed');
      // App kommt in den Vordergrund: einmaliges Resume
      _usage.resume();
      unawaited(_achievementService.recordDaily(AchievementIds.appDays));
      authModel.onAppResumed();
      _notificationsCubit?.load();
      _pendingSync.resume();
    } else if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      if (!_pendingSync.isPaused) {
        _usage.pause();
        _pendingSync.pause();
        authModel.onAppBackgrounded();
      }
      logger.log('lifecycle', 'App $state');
    }
    super.didChangeAppLifecycleState(state);
  }

  @override
  Widget build(BuildContext context) {
    final authModel = context.watch<AuthSessionModel>();
    final arbeitskontextModel = context.watch<ArbeitskontextModel>();
    final memberFiltersModel = context.watch<MemberFiltersModel>();
    final isGlobalLoading =
        authModel.isLoadingProfile ||
        authModel.isSyncingHitobitoData ||
        arbeitskontextModel.isLoading ||
        arbeitskontextModel.isLoadingRoles ||
        arbeitskontextModel.isSwitchingLayer ||
        memberFiltersModel.isLoading;
    final useImmediateFeedback =
        authModel.state == AuthState.authenticating ||
        authModel.isUserInitiatedSyncInProgress ||
        arbeitskontextModel.isSwitchingLayer;

    final projectId = dotenv.env['WIREDASH_PROJECT_ID'];
    final secret = dotenv.env['WIREDASH_SECRET'];

    if (projectId == null ||
        secret == null ||
        projectId.isEmpty ||
        secret.isEmpty) {
      throw Exception('Wiredash-Konfiguration fehlt in .env');
    }

    return Consumer<ThemeModel>(
      builder: (context, themeModel, _) {
        final palette = context.watch<AppearanceModel>().palette;
        return Provider<AppRuntimeController>.value(
          value: _appRuntimeController,
          child: Wiredash(
            projectId: projectId,
            secret: secret,
            psOptions: const PsOptions(
              initialDelay: Duration(days: 21),
              frequency: Duration(days: 90),
              minimumAppStarts: 3,
            ),
            feedbackOptions: const WiredashFeedbackOptions(
              labels: [
                Label(id: 'label-u26353u60f', title: 'Fehler'),
                Label(id: 'label-mtl2xk4esi', title: 'Verbesserung'),
                Label(id: 'label-p792odog4e', title: 'Lob'),
              ],
            ),
            options: WiredashOptionsData(
              locale: context.watch<LocaleModel>().currentLocale,
              localizationDelegate: const WiredashTexteDelegate(),
            ),
            collectMetaData: (metaData) => metaData,
            child: MaterialApp(
              theme: buildTheme(palette, Brightness.light),
              darkTheme: buildTheme(palette, Brightness.dark),
              themeMode: themeModel.currentMode,
              navigatorKey: navigatorKey,
              navigatorObservers: [
                AppNavigationLoggingObserver(logger: logger),
              ],
              scaffoldMessengerKey: scaffoldMessengerKey,
              onGenerateRoute: onGenerateRoute,
              localizationsDelegates: [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
                AppLocalizations.delegate,
              ],
              builder: (context, child) {
                final content = Stack(
                  fit: StackFit.expand,
                  children: [
                    if (child != null)
                      AppGesperrterInhalt(
                        gesperrt: authModel.state == AuthState.unlockRequired,
                        child: child,
                      ),
                    const AppLockOverlay(),
                    AppSichtschutz(
                      aktiv:
                          !_isDemo &&
                          context.select<AppSettingsModel, bool>(
                            (settings) => settings.biometricLockEnabled,
                          ),
                    ),
                    GlobalLoadingTopBar(
                      active: isGlobalLoading,
                      immediate: useImmediateFeedback,
                    ),
                  ],
                );
                if (!_isDemo) {
                  return content;
                }
                return Banner(
                  message: AppLocalizations.of(context).t('demo_ribbon'),
                  location: BannerLocation.topStart,
                  color: Theme.of(context).colorScheme.tertiary,
                  child: content,
                );
              },
              supportedLocales: const [Locale('de'), Locale('en')],
              locale: context.watch<LocaleModel>().currentLocale,
              home: const AuthGateScreen(),
            ),
          ),
        );
      },
    );
  }
}

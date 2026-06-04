import 'dart:async';
import 'dart:ui';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hive_ce/hive.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:nami/core/notifications/pull_notification.dart';
import 'package:nami/core/notifications/pull_notifications_cubit.dart';
import 'package:nami/core/notifications/pull_notifications_repository_factory.dart';
import 'package:nami/data/arbeitskontext/hitobito_arbeitskontext_read_model_repository.dart';
import 'package:nami/data/arbeitskontext/secure_arbeitskontext_local_repository.dart';
import 'package:nami/data/auth/secure_auth_profile_repository.dart';
import 'package:nami/data/auth/secure_auth_session_repository.dart';
import 'package:nami/data/member/hitobito_member_write_repository.dart';
import 'package:nami/data/member/secure_pending_person_update_repository.dart';
import 'package:nami/domain/arbeitskontext/usecases/bestimme_startkontext_usecase.dart';
import 'package:nami/presentation/model/arbeitskontext_model.dart';
import 'package:nami/presentation/model/auth_session_model.dart';
import 'package:nami/presentation/model/member_edit_model.dart';
import 'package:nami/presentation/notifications/app_update_dialog.dart';
import 'package:nami/presentation/notifications/notifications_hub.dart';
import 'package:nami/presentation/notifications/welcome_dialog.dart';
import 'package:nami/presentation/screens/auth_gate_screen.dart';
import 'package:nami/presentation/theme/theme.dart';
import 'package:nami/presentation/widgets/global_loading_top_bar.dart';
import 'package:nami/services/hitobito_roles_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:wiredash/wiredash.dart';

import 'data/member_filters/shared_prefs_member_filter_repository.dart';
import 'data/settings/shared_prefs_app_settings_repository.dart';
import 'domain/auth/auth_profile.dart';
import 'domain/auth/auth_state.dart';
import 'domain/settings/app_settings.dart';
import 'domain/settings/app_settings_repository.dart';
import 'l10n/app_localizations.dart';
import 'presentation/model/app_settings_model.dart';
import 'presentation/model/locale_model.dart';
import 'presentation/model/member_filters_model.dart';
import 'presentation/model/urgent_notification_model.dart';
import 'presentation/navigation/app_router.dart';
import 'presentation/notifications/app_snackbar.dart';
import 'services/app_reset_service.dart';
import 'services/app_runtime_controller.dart';
import 'services/app_startup_state_service.dart';
import 'services/app_update_service.dart';
import 'services/biometric_lock_service.dart';
import 'services/data_expiry_notification_service.dart';
import 'services/hitobito_auth_config_controller.dart';
import 'services/hitobito_auth_env.dart';
import 'services/hitobito_data_retention_policy.dart';
import 'services/hitobito_groups_service.dart';
import 'services/hitobito_oauth_service.dart';
import 'services/hitobito_people_service.dart';
import 'services/hitobito_traffic_log_service.dart';
import 'services/logger_service.dart';
import 'services/map_tile_cache_service.dart';
import 'services/network_access_policy.dart';
import 'services/sensitive_storage_service.dart';
import 'services/usage_tracking_service.dart';
import 'services/wifi_sync_trigger.dart';

final navigatorKey = GlobalKey<NavigatorState>();
final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

void main() {
  LoggerService? logger;
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      final appDocDir = await getApplicationDocumentsDirectory();
      Hive.init(appDocDir.path);
      await dotenv.load(fileName: ".env");
      await initializeDateFormatting("de_DE", null);
      Intl.defaultLocale = "de_DE";

      // Settings laden und Provider initialisieren
      final AppSettingsRepository settingsRepo =
          SharedPrefsAppSettingsRepository();
      final memberFilterRepository = SharedPrefsMemberFilterRepository();
      final appStartupStateService = AppStartupStateService();
      final AppSettings initial = await settingsRepo.load();
      final urgentNotificationModel = UrgentNotificationModel();
      final localeModel = LocaleModel(
        persist: (code) => settingsRepo.saveLanguageCode(code),
      )..setLocale(Locale(initial.languageCode), persist: false);
      final appSettingsModel = AppSettingsModel(initial, settingsRepo);
      final memberFiltersModel = MemberFiltersModel(memberFilterRepository);

      logger = LoggerService(
        settingsRepository: settingsRepo,
        navigatorKey: navigatorKey,
        wiredashEventHook: (name, props) async {
          final ctx = navigatorKey.currentContext;
          if (ctx == null) return;
          try {
            await Wiredash.of(ctx).trackEvent(name, data: props);
          } catch (_) {}
        },
      );
      final networkAccessPolicy = NetworkAccessPolicy(
        logger: logger,
        noMobileDataEnabled: () => appSettingsModel.noMobileDataEnabled,
      );
      final appUpdateService = AppUpdateService(
        networkAccessPolicy: networkAccessPolicy,
      );
      final dataExpiryNotificationService = DataExpiryNotificationService(
        logger: logger!,
      );
      final mapTileCacheService = MapTileCacheService(
        logger: logger,
        networkAccessPolicy: networkAccessPolicy,
      );
      final hitobitoTrafficLogService = HitobitoTrafficLogService();

      final sensitiveStorageService = SensitiveStorageService();
      final authSessionRepository = SecureAuthSessionRepository();
      final authProfileRepository = SecureAuthProfileRepository(
        sensitiveStorageService: sensitiveStorageService,
      );
      final arbeitskontextLocalRepository = SecureArbeitskontextLocalRepository(
        sensitiveStorageService: sensitiveStorageService,
      );
      final envAuthConfig = HitobitoAuthEnv.authConfig;
      final oauthService = HitobitoOauthService(
        config: envAuthConfig,
        logger: logger,
      );
      final hitobitoGroupsService = HitobitoGroupsService(
        config: envAuthConfig,
        trafficLogService: hitobitoTrafficLogService,
      );
      final hitobitoPeopleService = HitobitoPeopleService(
        config: envAuthConfig,
        trafficLogService: hitobitoTrafficLogService,
      );
      final hitobitoRolesService = HitobitoRolesService(
        config: envAuthConfig,
        trafficLogService: hitobitoTrafficLogService,
      );
      final hitobitoAuthConfigController = HitobitoAuthConfigController(
        sensitiveStorageService: sensitiveStorageService,
        oauthService: oauthService,
        groupsService: hitobitoGroupsService,
        peopleService: hitobitoPeopleService,
        rolesService: hitobitoRolesService,
        logger: logger,
        envConfig: envAuthConfig,
      );
      await hitobitoAuthConfigController.initialize();
      final arbeitskontextReadModelRepository =
          HitobitoArbeitskontextReadModelRepository(
            groupsService: hitobitoGroupsService,
            peopleService: hitobitoPeopleService,
            rolesService: hitobitoRolesService,
            localRepository: arbeitskontextLocalRepository,
          );
      final appResetService = AppResetService(
        authSessionRepository: authSessionRepository,
        sensitiveStorageService: sensitiveStorageService,
        logFileProvider: logger!.getLogFile,
        clearLogs: logger!.clearAllLogs,
        clearHitobitoTrafficLogs: hitobitoTrafficLogService.clearAllLogs,
        clearMapCache: mapTileCacheService.deleteRoot,
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
        logger: logger!,
        networkAccessPolicy: networkAccessPolicy,
        isAppLockEnabled: () => appSettingsModel.biometricLockEnabled,
        lockTimeout: HitobitoAuthEnv.appLockTimeout,
        onPreferredLanguageChanged: (languageCode) async {
          final normalized = AuthProfile.normalizeLanguageCode(languageCode);
          localeModel.setLocale(Locale(normalized), persist: false);
          await appSettingsModel.setLanguageCode(normalized);
        },
      );
      await authModel.initialize();

      final arbeitskontextModel = ArbeitskontextModel(
        localRepository: arbeitskontextLocalRepository,
        readModelRepository: arbeitskontextReadModelRepository,
        groupsService: hitobitoGroupsService,
        bestimmeStartkontextUseCase: const BestimmeStartkontextUseCase(),
        remoteAccessExecutor: authModel.executeRemoteAccess,
        logger: logger!,
      );
      await arbeitskontextModel.syncForAuth(
        authState: authModel.state,
        session: authModel.session,
        profile: authModel.profile,
      );
      final pendingPersonUpdateRepository = SecurePendingPersonUpdateRepository(
        sensitiveStorageService: sensitiveStorageService,
      );
      final memberWriteRepository = HitobitoMemberWriteRepository(
        peopleService: hitobitoPeopleService,
        remoteAccessExecutor: authModel.executeRemoteAccess,
        logger: logger!,
      );
      final memberEditModel = MemberEditModel(
        memberWriteRepository: memberWriteRepository,
        pendingRepository: pendingPersonUpdateRepository,
        logger: logger!,
        onMemberUpdated: arbeitskontextModel.ersetzeMitglied,
      );
      await memberEditModel.loadPending();

      // Globale Fehlerbehandlung: Framework- und ungefangene Fehler loggen/tracken
      FlutterError.onError = (FlutterErrorDetails details) async {
        FlutterError.presentError(details);
        await logger?.logError(
          'error',
          'FlutterError',
          error: details.exception,
          stackTrace: details.stack,
        );
        await logger?.trackRuntimeError(
          source: 'flutter',
          error: details.exception,
          stackTrace: details.stack,
        );
      };

      PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
        // Ungefangene, asynchrone Fehler
        // ignore: discarded_futures
        logger?.logError(
          'error',
          'Uncaught runtime error',
          error: error,
          stackTrace: stack,
        );
        // ignore: discarded_futures
        logger?.trackRuntimeError(
          source: 'uncaught',
          error: error,
          stackTrace: stack,
        );
        return true; // Fehler als behandelt markieren
      };

      runApp(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(
              create: (_) => ThemeModel(
                persist: (mode) => settingsRepo.saveThemeMode(mode),
              )..currentMode = initial.themeMode,
            ),
            ChangeNotifierProvider<LocaleModel>.value(value: localeModel),
            Provider<AppSettingsRepository>.value(value: settingsRepo),
            Provider<NetworkAccessPolicy>.value(value: networkAccessPolicy),
            Provider<AppUpdateService>.value(value: appUpdateService),
            Provider<DataExpiryNotificationService>.value(
              value: dataExpiryNotificationService,
            ),
            Provider<AppStartupStateService>.value(
              value: appStartupStateService,
            ),
            Provider<AppResetService>.value(value: appResetService),
            ChangeNotifierProvider<AppSettingsModel>.value(
              value: appSettingsModel,
            ),
            ChangeNotifierProvider<MemberFiltersModel>.value(
              value: memberFiltersModel,
            ),
            ChangeNotifierProvider<UrgentNotificationModel>.value(
              value: urgentNotificationModel,
            ),
            ChangeNotifierProvider<AuthSessionModel>.value(value: authModel),
            ChangeNotifierProvider<ArbeitskontextModel>.value(
              value: arbeitskontextModel,
            ),
            ChangeNotifierProvider<MemberEditModel>.value(
              value: memberEditModel,
            ),
            ChangeNotifierProvider<HitobitoAuthConfigController>.value(
              value: hitobitoAuthConfigController,
            ),
            Provider<LoggerService>.value(value: logger!),
            Provider<HitobitoTrafficLogService>.value(
              value: hitobitoTrafficLogService,
            ),
            Provider<MapTileCacheService>.value(value: mapTileCacheService),
          ],
          child: const MyApp(),
        ),
      );
    },
    (error, stack) {
      // Letzte Schutzschicht für unvorhergesehene Fehler
      if (logger != null) {
        // ignore: discarded_futures
        logger!.log('error', 'Zoned: $error\n$stack');
        // ignore: discarded_futures
        logger!.trackRuntimeError(
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

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  static const Duration _pendingRetryInterval = Duration(minutes: 1);

  late UsageTrackingService _usage;
  bool _isPaused = false;
  bool _isForegroundSyncRunning = false;
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
  late final Connectivity _connectivity;
  late final WifiSyncTrigger _wifiSyncTrigger;
  late bool _lastNoMobileDataEnabled;
  Timer? _authMaintenanceTimer;
  Timer? _pendingRetryTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  PullNotificationsCubit? _notificationsCubit;
  StreamSubscription<PullNotificationsState>? _notificationsSubscription;
  PullNotificationsLoaded? _pendingNotificationsState;
  bool _didCheckForAppUpdate = false;
  bool _startupFlowCompleted = false;
  bool _startupFlowRunning = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Start Nutzungs-Session beim App-Start
    logger = context.read<LoggerService>();
    _authModel = context.read<AuthSessionModel>();
    _arbeitskontextModel = context.read<ArbeitskontextModel>();
    _appSettingsModel = context.read<AppSettingsModel>();
    _memberEditModel = context.read<MemberEditModel>();
    _appResetService = context.read<AppResetService>();
    _appStartupStateService = context.read<AppStartupStateService>();
    _dataExpiryNotificationService = context
        .read<DataExpiryNotificationService>();
    _urgentNotificationModel = context.read<UrgentNotificationModel>();
    _appRuntimeController = AppRuntimeController(resetApp: _performFullReset);
    _connectivity = Connectivity();
    _wifiSyncTrigger = WifiSyncTrigger();
    _lastNoMobileDataEnabled = _appSettingsModel.noMobileDataEnabled;
    _authModel.addListener(_handleAuthModelChanged);
    _appSettingsModel.addListener(_handleAppSettingsChanged);
    _urgentNotificationModel.setAcknowledgeHandler((id) async {
      await _notificationsCubit?.acknowledge(id);
    });
    _usage = UsageTrackingService(logger: logger);
    // Ausstehende Pause/Sessions vom letzten Lauf auswerten
    _usage.flushPendingSession();
    _usage.startSession();
    _initGlobalNotifications();
    _startAuthMaintenanceTimer();
    _startPendingRetryTimer();
    _startConnectivityListener();
    unawaited(_checkCurrentConnectivityForForegroundSync(trigger: 'startup'));
    _syncDataExpiryReminder();
    _scheduleStartupFlow();
  }

  void _handleAppSettingsChanged() {
    final noMobileDataEnabled = _appSettingsModel.noMobileDataEnabled;
    if (_lastNoMobileDataEnabled == noMobileDataEnabled) {
      return;
    }
    _lastNoMobileDataEnabled = noMobileDataEnabled;
    unawaited(
      _checkCurrentConnectivityForForegroundSync(
        trigger: noMobileDataEnabled
            ? 'mobile_data_disabled'
            : 'mobile_data_enabled',
      ),
    );
  }

  void _handleAuthModelChanged() {
    _syncArbeitskontextWithAuth();
    _syncDataExpiryReminder();

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

  void _syncDataExpiryReminder() {
    final remaining = _authModel.remainingUntilRelogin;
    final isActive =
        _authModel.hasRemoteAccessIssue &&
        remaining != null &&
        remaining > Duration.zero &&
        remaining <= const Duration(days: 3);

    final daysRemaining = remaining == null
        ? 0
        : (remaining.inHours <= 24 ? 1 : (remaining.inHours / 24).ceil());

    unawaited(
      _dataExpiryNotificationService.updateExpiryReminder(
        active: isActive,
        daysRemaining: daysRemaining,
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
      final hasSeenWelcome = await _appStartupStateService.hasSeenWelcome();
      if (!hasSeenWelcome) {
        await showWelcomeDialog(dialogContext);
        await _appStartupStateService.markWelcomeSeen();
        _startupFlowCompleted = true;
        return;
      }

      await _checkForAppUpdate();
      _startupFlowCompleted = true;
    } finally {
      _startupFlowRunning = false;
      if (_startupFlowCompleted) {
        _flushPendingNotificationBanner();
      }
    }
  }

  void _startAuthMaintenanceTimer() {
    _authMaintenanceTimer?.cancel();
    final authModel = context.read<AuthSessionModel>();
    if (authModel.isRefreshAttemptDue) {
      unawaited(
        authModel.syncHitobitoData(
          syncMembers: (accessToken) async {
            await _arbeitskontextModel.refreshFromRemote(
              session: _authModel.session,
              profile: _authModel.profile,
            );
          },
          trigger: 'startup',
          userInitiated: false,
        ),
      );
    }
    _authMaintenanceTimer = Timer.periodic(
      HitobitoAuthEnv.refreshInterval,
      (_) => authModel.syncHitobitoData(
        syncMembers: (accessToken) async {
          await _arbeitskontextModel.refreshFromRemote(
            session: _authModel.session,
            profile: _authModel.profile,
          );
        },
        trigger: 'interval',
        userInitiated: false,
      ),
    );
  }

  void _startConnectivityListener() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((
      results,
    ) {
      unawaited(
        _handleForegroundSyncOpportunity(
          NetworkAccessPolicy.classifyConnectivityResults(results),
          trigger: 'connectivity_changed',
        ),
      );
    });
  }

  void _startPendingRetryTimer() {
    _pendingRetryTimer?.cancel();
    _pendingRetryTimer = Timer.periodic(_pendingRetryInterval, (_) {
      unawaited(
        _retryPendingPersonUpdatesIfPossible(trigger: 'pending_retry_timer'),
      );
    });
  }

  Future<NetworkConnectionType> _resolveCurrentConnectionType() async {
    final results = await _connectivity.checkConnectivity();
    return NetworkAccessPolicy.classifyConnectivityResults(results);
  }

  Future<void> _checkCurrentConnectivityForForegroundSync({
    required String trigger,
  }) async {
    final connectionType = await _resolveCurrentConnectionType();
    await _handleForegroundSyncOpportunity(connectionType, trigger: trigger);
  }

  Future<void> _handleForegroundSyncOpportunity(
    NetworkConnectionType connectionType, {
    required String trigger,
  }) async {
    if (_isPaused ||
        !_wifiSyncTrigger.shouldTrigger(
          connectionType,
          noMobileDataEnabled: _appSettingsModel.noMobileDataEnabled,
        )) {
      return;
    }

    await _runForegroundSync(trigger: trigger);
  }

  Future<void> _runForegroundSync({required String trigger}) async {
    if (_isForegroundSyncRunning) {
      return;
    }

    _isForegroundSyncRunning = true;
    try {
      await _authModel.syncHitobitoData(
        syncMembers: (accessToken) async {
          await _arbeitskontextModel.refreshFromRemote(
            session: _authModel.session,
            profile: _authModel.profile,
          );
        },
        trigger: trigger,
        userInitiated: false,
      );
      await _retryPendingPersonUpdatesIfPossible(trigger: '${trigger}_pending');
    } finally {
      _isForegroundSyncRunning = false;
    }
  }

  Future<void> _retryPendingPersonUpdatesIfPossible({
    required String trigger,
  }) async {
    if (_isPaused || _memberEditModel.isBusy) {
      return;
    }

    final hasRetryablePending = _memberEditModel.pendingUpdates.any(
      (entry) => !entry.needsResolution,
    );
    if (!hasRetryablePending) {
      return;
    }

    final accessToken = _authModel.session?.accessToken;
    if (accessToken == null ||
        accessToken.isEmpty ||
        _authModel.requiresInteractiveLogin) {
      return;
    }

    final connectionType = await _resolveCurrentConnectionType();
    if (!_wifiSyncTrigger.isSyncAllowed(
      connectionType,
      noMobileDataEnabled: _appSettingsModel.noMobileDataEnabled,
    )) {
      return;
    }

    await _memberEditModel.retryPending(
      accessToken: accessToken,
      trigger: trigger,
    );
  }

  Future<void> _checkForAppUpdate() async {
    if (_didCheckForAppUpdate) {
      return;
    }
    _didCheckForAppUpdate = true;

    try {
      final info = await context.read<AppUpdateService>().checkForUpdate();
      final dialogContext = navigatorKey.currentContext;
      if (!mounted || dialogContext == null || info == null) {
        return;
      }
      await showAppUpdateDialog(dialogContext, info);
    } catch (error, stack) {
      await logger.log(
        'update',
        'App-Update-Check fehlgeschlagen: $error\n$stack',
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

  Future<void> _performFullReset() async {
    await logger.log('debug_tools', 'Vollstaendiger App-Reset gestartet');
    scaffoldMessengerKey.currentState
      ?..hideCurrentSnackBar()
      ..hideCurrentMaterialBanner();
    navigatorKey.currentState?.popUntil((route) => route.isFirst);

    _authMaintenanceTimer?.cancel();
    await _notificationsSubscription?.cancel();
    _notificationsSubscription = null;
    await _notificationsCubit?.close();
    _notificationsCubit = null;
    _pendingNotificationsState = null;
    _urgentNotificationModel.setNotification(null);

    await _authModel.logout();
    await _appResetService.resetAllData();

    final settingsRepo = context.read<AppSettingsRepository>();
    final defaults = await settingsRepo.load();
    context.read<AppSettingsModel>().replaceWith(defaults);
    context.read<ThemeModel>().setTheme(defaults.themeMode);
    context.read<LocaleModel>().setLocale(
      Locale(defaults.languageCode),
      persist: false,
    );

    _resetStartupFlowState();
    _usage.startSession();
    _startAuthMaintenanceTimer();
    _startPendingRetryTimer();
    await _initGlobalNotifications();
    unawaited(_checkCurrentConnectivityForForegroundSync(trigger: 'app_reset'));
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
    _authMaintenanceTimer?.cancel();
    _pendingRetryTimer?.cancel();
    _connectivitySubscription?.cancel();
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
      _isPaused = false;
      _wifiSyncTrigger.reset();
      authModel.onAppResumed();
      _notificationsCubit?.load();
      unawaited(_checkCurrentConnectivityForForegroundSync(trigger: 'resume'));
    } else if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      if (!_isPaused) {
        _usage.pause();
        _isPaused = true;
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
        return Provider<AppRuntimeController>.value(
          value: _appRuntimeController,
          child: Wiredash(
            projectId: projectId,
            secret: secret,
            feedbackOptions: const WiredashFeedbackOptions(
              labels: [
                Label(id: 'label-u26353u60f', title: 'Fehler'),
                Label(id: 'label-mtl2xk4esi', title: 'Verbesserung'),
                Label(id: 'label-p792odog4e', title: 'Lob'),
              ],
            ),
            options: WiredashOptionsData(
              locale: context.watch<LocaleModel>().currentLocale,
            ),
            collectMetaData: (metaData) => metaData,
            child: MaterialApp(
              theme: lightTheme,
              darkTheme: darkTheme,
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
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    if (child != null) child,
                    const AppLockOverlay(),
                    GlobalLoadingTopBar(
                      active: isGlobalLoading,
                      immediate: useImmediateFeedback,
                    ),
                  ],
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

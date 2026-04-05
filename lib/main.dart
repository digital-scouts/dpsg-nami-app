import 'dart:async';
import 'dart:ui';

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
import 'package:nami/domain/arbeitskontext/usecases/bestimme_startkontext_usecase.dart';
import 'package:nami/presentation/model/arbeitskontext_model.dart';
import 'package:nami/presentation/model/auth_session_model.dart';
import 'package:nami/presentation/notifications/app_update_dialog.dart';
import 'package:nami/presentation/notifications/welcome_dialog.dart';
import 'package:nami/presentation/screens/auth_gate_screen.dart';
import 'package:nami/presentation/theme/theme.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:wiredash/wiredash.dart';

import 'data/settings/shared_prefs_app_settings_repository.dart';
import 'domain/auth/auth_profile.dart';
import 'domain/auth/auth_state.dart';
import 'domain/settings/app_settings.dart';
import 'domain/settings/app_settings_repository.dart';
import 'l10n/app_localizations.dart';
import 'presentation/model/app_settings_model.dart';
import 'presentation/model/locale_model.dart';
import 'presentation/navigation/app_router.dart';
import 'services/app_reset_service.dart';
import 'services/app_runtime_controller.dart';
import 'services/app_startup_state_service.dart';
import 'services/app_update_service.dart';
import 'services/biometric_lock_service.dart';
import 'services/hitobito_auth_config_controller.dart';
import 'services/hitobito_auth_env.dart';
import 'services/hitobito_data_retention_policy.dart';
import 'services/hitobito_groups_service.dart';
import 'services/hitobito_oauth_service.dart';
import 'services/hitobito_people_service.dart';
import 'services/logger_service.dart';
import 'services/sensitive_storage_service.dart';
import 'services/usage_tracking_service.dart';

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
      final appStartupStateService = AppStartupStateService();
      final AppSettings initial = await settingsRepo.load();
      final localeModel = LocaleModel(
        persist: (code) => settingsRepo.saveLanguageCode(code),
      )..setLocale(Locale(initial.languageCode), persist: false);
      final appSettingsModel = AppSettingsModel(initial, settingsRepo);

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
      );
      final hitobitoPeopleService = HitobitoPeopleService(
        config: envAuthConfig,
      );
      final hitobitoAuthConfigController = HitobitoAuthConfigController(
        sensitiveStorageService: sensitiveStorageService,
        oauthService: oauthService,
        groupsService: hitobitoGroupsService,
        peopleService: hitobitoPeopleService,
        logger: logger,
        envConfig: envAuthConfig,
      );
      await hitobitoAuthConfigController.initialize();
      final arbeitskontextReadModelRepository =
          HitobitoArbeitskontextReadModelRepository(
            groupsService: hitobitoGroupsService,
            peopleService: hitobitoPeopleService,
            localRepository: arbeitskontextLocalRepository,
          );
      final appResetService = AppResetService(
        authSessionRepository: authSessionRepository,
        sensitiveStorageService: sensitiveStorageService,
        logFileProvider: logger!.getLogFile,
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
        logger: logger!,
      );
      await arbeitskontextModel.syncForAuth(
        authState: authModel.state,
        session: authModel.session,
        profile: authModel.profile,
      );

      // Globale Fehlerbehandlung: Framework- und ungefangene Fehler loggen/tracken
      FlutterError.onError = (FlutterErrorDetails details) async {
        FlutterError.presentError(details);
        await logger?.log(
          'error',
          'FlutterError: ${details.exceptionAsString()}',
        );
        await logger?.trackEvent('runtime_error', {
          'type': 'flutter',
          'exception': details.exceptionAsString(),
          'stack': details.stack?.toString(),
        });
      };

      PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
        // Ungefangene, asynchrone Fehler
        // ignore: discarded_futures
        logger?.log('error', 'Uncaught: $error\n$stack');
        // ignore: discarded_futures
        logger?.trackEvent('runtime_error', {
          'type': 'uncaught',
          'exception': error.toString(),
          'stack': stack.toString(),
        });
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
            Provider<AppStartupStateService>.value(
              value: appStartupStateService,
            ),
            Provider<AppResetService>.value(value: appResetService),
            ChangeNotifierProvider<AppSettingsModel>.value(
              value: appSettingsModel,
            ),
            ChangeNotifierProvider<AuthSessionModel>.value(value: authModel),
            ChangeNotifierProvider<ArbeitskontextModel>.value(
              value: arbeitskontextModel,
            ),
            ChangeNotifierProvider<HitobitoAuthConfigController>.value(
              value: hitobitoAuthConfigController,
            ),
            Provider<LoggerService>.value(value: logger!),
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
        logger!.trackEvent('runtime_error', {
          'type': 'zoned',
          'exception': error.toString(),
          'stack': stack.toString(),
        });
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
  late UsageTrackingService _usage;
  bool _isPaused = false;
  late final LoggerService logger;
  late final AuthSessionModel _authModel;
  late final ArbeitskontextModel _arbeitskontextModel;
  late final AppResetService _appResetService;
  late final AppStartupStateService _appStartupStateService;
  late final AppRuntimeController _appRuntimeController;
  Timer? _authMaintenanceTimer;
  PullNotificationsCubit? _notificationsCubit;
  StreamSubscription<PullNotificationsState>? _notificationsSubscription;
  String? _currentUrgentId;
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
    _appResetService = context.read<AppResetService>();
    _appStartupStateService = context.read<AppStartupStateService>();
    _appRuntimeController = AppRuntimeController(resetApp: _performFullReset);
    _authModel.addListener(_handleAuthModelChanged);
    _usage = UsageTrackingService(logger: logger);
    // Ausstehende Pause/Sessions vom letzten Lauf auswerten
    _usage.flushPendingSession();
    _usage.startSession();
    _initGlobalNotifications();
    _startAuthMaintenanceTimer();
    _scheduleStartupFlow();
  }

  void _handleAuthModelChanged() {
    _syncArbeitskontextWithAuth();

    final authState = _authModel.state;
    if (authState == AuthState.signedIn) {
      _scheduleStartupFlow();
      _flushPendingNotificationBanner();
      return;
    }

    if (authState == AuthState.unlockRequired) {
      scaffoldMessengerKey.currentState?.hideCurrentMaterialBanner();
      return;
    }

    _resetStartupFlowState();
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
    _currentUrgentId = null;
    scaffoldMessengerKey.currentState?.hideCurrentMaterialBanner();
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
      ),
    );
  }

  Future<void> _checkForAppUpdate() async {
    if (_didCheckForAppUpdate) {
      return;
    }
    _didCheckForAppUpdate = true;

    try {
      final info = await AppUpdateService().checkForUpdate();
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

    final repo = await createPullNotificationsRepository(logger: logger);
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
      scaffoldMessengerKey.currentState?.hideCurrentMaterialBanner();
      return;
    }

    if (state is! PullNotificationsLoaded) return;

    _showNotificationBanner(state);
  }

  void _flushPendingNotificationBanner() {
    final state = _pendingNotificationsState;
    if (state == null || !_startupFlowCompleted || !_canShowStartupUi()) {
      return;
    }

    _showNotificationBanner(state);
  }

  void _showNotificationBanner(PullNotificationsLoaded state) {
    if (!_canShowStartupUi()) {
      return;
    }

    PullNotification? urgent;
    try {
      urgent = state.notifications.firstWhere(
        (notification) =>
            notification.type == 'urgent' &&
            !state.acknowledged.contains(notification.id),
      );
    } catch (_) {
      urgent = null;
    }

    final messenger = scaffoldMessengerKey.currentState;
    if (urgent == null) {
      _currentUrgentId = null;
      messenger?.hideCurrentMaterialBanner();
      return;
    }

    if (_currentUrgentId == urgent.id) {
      return;
    }

    _currentUrgentId = urgent.id;
    final locale = context.read<LocaleModel>().currentLocale;
    final localizations =
        AppLocalizations.maybeOf(context) ?? AppLocalizations(locale);
    messenger
      ?..hideCurrentMaterialBanner()
      ..showMaterialBanner(
        MaterialBanner(
          backgroundColor: Theme.of(context).colorScheme.errorContainer,
          leading: Icon(
            Icons.notification_important_outlined,
            color: Theme.of(context).colorScheme.onErrorContainer,
          ),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                urgent.title.resolve(locale),
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              Text(urgent.body.resolve(locale)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await _notificationsCubit?.acknowledge(urgent!.id);
              },
              child: Text(localizations.t('acknowledge')),
            ),
          ],
        ),
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
    _currentUrgentId = null;

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
    await _initGlobalNotifications();
    _scheduleStartupFlow();

    final snackbarContext = navigatorKey.currentContext;
    if (snackbarContext != null) {
      scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(snackbarContext).t('debug_reset_done'),
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authModel.removeListener(_handleAuthModelChanged);
    _authMaintenanceTimer?.cancel();
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
      authModel.onAppResumed();
      _notificationsCubit?.load(force: true);
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
                  children: [if (child != null) child, const AppLockOverlay()],
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

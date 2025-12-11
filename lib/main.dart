import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:nami/presentation/navigation/navigation_home.page.dart';
import 'package:nami/presentation/theme/theme.dart';
import 'package:provider/provider.dart';
import 'package:wiredash/wiredash.dart';

import 'data/settings/shared_prefs_app_settings_repository.dart';
import 'domain/settings/app_settings.dart';
import 'domain/settings/app_settings_repository.dart';
import 'l10n/app_localizations.dart';
import 'presentation/model/app_settings_model.dart';
import 'presentation/model/locale_model.dart';
import 'presentation/navigation/app_router.dart';
import 'services/logger_service.dart';
import 'services/usage_tracking_service.dart';

final navigatorKey = GlobalKey<NavigatorState>();

void main() {
  LoggerService? logger;
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      await dotenv.load(fileName: ".env");
      await initializeDateFormatting("de_DE", null);
      Intl.defaultLocale = "de_DE";

      // Settings laden und Provider initialisieren
      final AppSettingsRepository settingsRepo =
          SharedPrefsAppSettingsRepository();
      final AppSettings initial = await settingsRepo.load();

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
            ChangeNotifierProvider(
              create: (_) => LocaleModel(
                persist: (code) => settingsRepo.saveLanguageCode(code),
              )..setLocale(Locale(initial.languageCode)),
            ),
            ChangeNotifierProvider(
              create: (_) => AppSettingsModel(initial, settingsRepo),
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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Start Nutzungs-Session beim App-Start
    logger = context.read<LoggerService>();
    _usage = UsageTrackingService(logger: logger);
    // Ausstehende Pause/Sessions vom letzten Lauf auswerten
    _usage.flushPendingSession();
    _usage.startSession();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      logger.log('lifecycle', 'App resumed');
      // App kommt in den Vordergrund: einmaliges Resume
      _usage.resume();
      _isPaused = false;
    } else if (state == AppLifecycleState.inactive) {
      // App geht in den Hintergrund: nur einmal pausieren
      if (!_isPaused) {
        _usage.pause();
        _isPaused = true;
      }
    } else if (state == AppLifecycleState.paused) {
      logger.log('lifecycle', 'App paused');
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
        return Wiredash(
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
            onGenerateRoute: onGenerateRoute,
            initialRoute: '/',
            localizationsDelegates: [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
              AppLocalizations.delegate,
            ],
            supportedLocales: const [Locale('de'), Locale('en')],
            locale: context.watch<LocaleModel>().currentLocale,
            home: const NavigationHomeScreen(),
          ),
        );
      },
    );
  }
}

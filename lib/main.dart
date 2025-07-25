import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:nami/screens/login_screen.dart';
import 'package:nami/screens/navigation_home_screen.dart';
import 'package:nami/screens/utilities/authenticate_screen.dart';
import 'package:nami/utilities/app.state.dart';
import 'package:nami/utilities/custom_wiredash_translations_delegate.dart';
import 'package:nami/utilities/helper_functions.dart';
import 'package:nami/utilities/hive/hive.handler.dart';
import 'package:nami/utilities/hive/hive_service.dart';
import 'package:nami/utilities/hive/settings_service.dart';
import 'package:nami/utilities/logger.dart';
import 'package:nami/utilities/notifications/birthday_notifications.dart';
import 'package:nami/utilities/theme.dart';
import 'package:provider/provider.dart';
import 'package:wiredash/wiredash.dart';

final navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  initializeDateFormatting("de_DE", null);
  Intl.defaultLocale = "de_DE";
  await Hive.initFlutter();
  await registerAdapter();
  try {
    await openHive();
  } on TypeError catch (_) {
    deleteHiveMemberDataOnFail();
    await openHive();
  }

  // Initialisiere die Services
  initializeSettingsService();
  initializeHiveService();

  await dotenv.load(fileName: ".env");
  await initLogger();
  try {
    WidgetsFlutterBinding.ensureInitialized();
    await FMTCObjectBoxBackend().initialise();
    const FMTCStore('mapStore').manage.create();
    enableMapTileCaching();
  } catch (e) {
    sensLog.e(
      'Error while initalice objectbox for flutter_map_tile_caching: $e',
    );
  }
  await BirthdayNotificationService.init();
  runApp(
    ChangeNotifierProvider<ThemeModel>(
      create: (_) => ThemeModel(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    if (dotenv.env['WIREDASH_PROJECT_ID'] == null ||
        dotenv.env['WIREDASH_SECRET'] == null ||
        dotenv.env['WIREDASH_PROJECT_ID']!.isEmpty ||
        dotenv.env['WIREDASH_SECRET']!.isEmpty) {
      throw Exception(
        'Please provide WIREDASH_PROJECT_ID and WIREDASH_SECRET in your .env file',
      );
    }

    return Wiredash(
      projectId: dotenv.env['WIREDASH_PROJECT_ID']!,
      secret: dotenv.env['WIREDASH_SECRET']!,
      feedbackOptions: const WiredashFeedbackOptions(
        labels: [
          Label(id: 'label-u26353u60f', title: 'Fehler'),
          Label(id: 'label-mtl2xk4esi', title: 'Verbesserung'),
          Label(id: 'label-p792odog4e', title: 'Lob'),
        ],
      ),
      options: const WiredashOptionsData(
        localizationDelegate: CustomWiredashTranslationsDelegate(),
        locale: Locale('de', 'DE'),
      ),
      collectMetaData: (metaData) => metaData,
      child: ChangeNotifierProvider(
        create: (context) => AppStateHandler(),
        child: const MaterialAppWrapper(),
      ),
    );
  }
}

class MaterialAppWrapper extends StatefulWidget {
  const MaterialAppWrapper({super.key});

  @override
  State<MaterialAppWrapper> createState() => _MaterialAppWrapperState();
}

class _MaterialAppWrapperState extends State<MaterialAppWrapper>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppStateHandler>().onResume(context);
    });

    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
      case AppLifecycleState.inactive:
        context.read<AppStateHandler>().onPause();
      case AppLifecycleState.resumed:
        WidgetsBinding.instance.addPostFrameCallback((_) {
          context.read<AppStateHandler>().onResume(context);
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: Provider.of<ThemeModel>(context).currentMode,
      home: const RootHome(),
      navigatorKey: navigatorKey,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('de', 'DE')],
      builder: (context, child) {
        return Scaffold(
          floatingActionButton: FloatingActionButton(
            onPressed: () => openWiredash(context, 'Feedback Button Main'),
            child: const Icon(Icons.feedback),
          ),
          body: Consumer<AppStateHandler>(
            builder: (context, appStateHandler, _) {
              final currentState = appStateHandler.currentState;
              return IndexedStack(
                index: (currentState == AppState.retryAuthentication) ? 0 : 1,
                children: [
                  switch (currentState) {
                    AppState.retryAuthentication => const AuthenticateScreen(),
                    _ => const SizedBox(),
                  },
                  child!,
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class RootHome extends StatelessWidget {
  const RootHome({super.key});

  @override
  Widget build(BuildContext context) {
    final appStateHandler = context.watch<AppStateHandler>();

    switch (appStateHandler.currentState) {
      case AppState.closed:
        return const Center(child: CircularProgressIndicator());
      case AppState.loggedOut:
        return const LoginScreen();
      case AppState.relogin:
      case AppState.ready:
      case AppState.retryAuthentication:
        return const NavigationHomeScreen();
    }
  }
}

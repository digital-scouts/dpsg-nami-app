import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:nami/screens/login_screen.dart';
import 'package:nami/screens/navigation_home_screen.dart';
import 'package:nami/screens/statistiken/authenticate_screen.dart';
import 'package:nami/utilities/app.state.dart';
import 'package:nami/utilities/custom_wiredash_translations_delegate.dart';
import 'package:nami/utilities/hive/hive.handler.dart';
import 'package:nami/utilities/logger.dart';
import 'package:nami/utilities/theme.dart';
import 'package:privacy_screen/privacy_screen.dart';
import 'package:provider/provider.dart';
import 'package:wiredash/wiredash.dart';

final navigatorKey = GlobalKey<NavigatorState>();
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FlutterMapTileCaching.initialise();
  initializeDateFormatting("de_DE", null);
  FMTC.instance('mapStore').manage.createAsync();
  Intl.defaultLocale = "de_DE";
  await Hive.initFlutter();
  await registerAdapter();
  await openHive();
  await dotenv.load(fileName: ".env");
  await initLogger();
  await PrivacyScreen.instance.enable(
    iosOptions: const PrivacyIosOptions(
      enablePrivacy: true,
      lockTrigger: IosLockTrigger.didEnterBackground,
    ),
    androidOptions: const PrivacyAndroidOptions(
      enableSecure: true,
    ),
  );
  runApp(
    ChangeNotifierProvider<ThemeModel>(
      create: (_) => ThemeModel(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (dotenv.env['WIREDASH_PROJECT_ID'] == null ||
        dotenv.env['WIREDASH_SECRET'] == null ||
        dotenv.env['WIREDASH_PROJECT_ID']!.isEmpty ||
        dotenv.env['WIREDASH_SECRET']!.isEmpty) {
      throw Exception(
          'Please provide WIREDASH_PROJECT_ID and WIREDASH_SECRET in your .env file');
    }
    return Wiredash(
      projectId: dotenv.env['WIREDASH_PROJECT_ID']!,
      secret: dotenv.env['WIREDASH_SECRET']!,
      feedbackOptions: const WiredashFeedbackOptions(
        labels: [
          Label(id: 'label-u26353u60f', title: 'Fehler'),
          Label(id: 'label-mtl2xk4esi', title: 'Verbesserung'),
          Label(id: 'label-p792odog4e', title: 'Lob')
        ],
      ),
      options: const WiredashOptionsData(
        localizationDelegate: CustomWiredashTranslationsDelegate(),
        locale: Locale('de', 'DE'),
      ),
      child: ChangeNotifierProvider(
        create: (context) => AppStateHandler(),
        child: const MaterialAppWrapper(),
      ),
    );
  }
}

class MaterialAppWrapper extends StatefulWidget {
  const MaterialAppWrapper({Key? key}) : super(key: key);

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
    if (state == AppLifecycleState.resumed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<AppStateHandler>().onResume(context);
      });
    } else if (state == AppLifecycleState.paused) {
      context.read<AppStateHandler>().onPause();
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
      builder: (context, child) {
        return Scaffold(
          floatingActionButton: FloatingActionButton(
            onPressed: () {
              Wiredash.of(context).show(inheritMaterialTheme: true);
            },
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

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:nami/screens/login_screen.dart';
import 'package:nami/screens/navigation_home_screen.dart';
import 'package:nami/utilities/app.state.dart';
import 'package:nami/utilities/custom_wiredash_translations_delegate.dart';
import 'package:nami/utilities/theme.dart';
import 'package:provider/provider.dart';
import 'package:wiredash/wiredash.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  initializeDateFormatting("de_DE", null);
  Intl.defaultLocale = "de_DE";
  await Hive.initFlutter();
  await dotenv.load(fileName: ".env");
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
          child: MaterialApp(
            theme: lightTheme,
            darkTheme: darkTheme,
            themeMode: Provider.of<ThemeModel>(context).currentMode,
            home: const MyHome(),
          ),
        ));
  }
}

class MyHome extends StatefulWidget {
  const MyHome({Key? key}) : super(key: key);

  @override
  State<MyHome> createState() => _MyHomeState();
}

class _MyHomeState extends State<MyHome> with WidgetsBindingObserver {
  AppStateHandler appState = AppStateHandler();

  @override
  void initState() {
    super.initState();
    appState.setResumeState(context);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint('AppLifecycle: $state');
    if (state == AppLifecycleState.inactive) {
      appState.setInactiveState(context);
    } else if (state == AppLifecycleState.resumed) {
      appState.setResumeState(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    const navigationHomeScreen = NavigationHomeScreen();

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Wiredash.of(context).show(inheritMaterialTheme: true);
        },
        child: const Icon(Icons.feedback),
      ),
      body: Consumer<AppStateHandler>(
        child: navigationHomeScreen,
        builder: (context, stateHandler, child) {
          debugPrint('AppState: ${appState.currentState}');
          Fluttertoast.showToast(
            msg: 'AppState: ${appState.currentState.name}',
            toastLength: Toast.LENGTH_LONG,
            gravity: ToastGravity.BOTTOM,
          );
          if (appState.currentState == AppState.loggedOut) {
            return const LoginScreen();
          } else if (appState.currentState == AppState.loadData ||
              appState.currentState == AppState.resume) {
            return const Center(child: CircularProgressIndicator());
          } else if (appState.currentState == AppState.authenticated) {
            return const NavigationHomeScreen();
          }
          return child!;
        },
      ),
    );
  }
}

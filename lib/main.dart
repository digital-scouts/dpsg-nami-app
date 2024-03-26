import 'package:fluttertoast/fluttertoast.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:flutter/material.dart';
import 'package:nami/screens/login_screen.dart';
import 'package:nami/screens/navigation_home_screen.dart';
import 'package:nami/utilities/app.state.dart';
import 'package:nami/utilities/theme.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

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
    return ChangeNotifierProvider(
      create: (context) => AppStateHandler(),
      child: MaterialApp(
        theme: lightTheme,
        darkTheme: darkTheme,
        themeMode: Provider.of<ThemeModel>(context).currentMode,
        home: const MyHome(),
      ),
    );
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

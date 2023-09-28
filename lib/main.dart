import 'package:hive_flutter/hive_flutter.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:nami/screens/login.dart';
import 'package:nami/screens/navigation_home_screen.dart';
import 'package:nami/utilities/hive/mitglied.dart';
import 'package:nami/utilities/hive/settings.dart';
import 'package:nami/utilities/hive/taetigkeit.dart';
import 'package:nami/utilities/nami/nami-login.service.dart';
import 'package:nami/utilities/theme.dart';
import 'package:provider/provider.dart';
import 'utilities/nami/nami.service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:connectivity/connectivity.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  runApp(ChangeNotifierProvider<ThemeModel>(
      create: (_) => ThemeModel(), child: const MyApp()));
}

Future openHive() async {
  const secureStorage = FlutterSecureStorage();
  // if key not exists return null
  var encryprionKey = await secureStorage.read(key: 'key');
  if (encryprionKey == null) {
    final key = Hive.generateSecureKey();
    await secureStorage.write(
      key: 'key',
      value: base64UrlEncode(key),
    );
  }
  final encryptionKey =
      base64Url.decode((await secureStorage.read(key: 'key'))!);

  Hive.registerAdapter(TaetigkeitAdapter());
  await Hive.openBox<Taetigkeit>('taetigkeit',
      encryptionCipher: HiveAesCipher(encryptionKey));
  Hive.registerAdapter(MitgliedAdapter());
  await Hive.openBox<Mitglied>('members',
      encryptionCipher: HiveAesCipher(encryptionKey));
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  MyAppState createState() => MyAppState();
}

class MyAppState extends State<MyApp> {
  Key key = UniqueKey();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: MyHome());
  }
}

class MyHome extends StatefulWidget {
  const MyHome({Key? key}) : super(key: key);

  @override
  State<MyHome> createState() => _MyHomeState();
}

class _MyHomeState extends State<MyHome> {
  bool authenticated = false;
  final LocalAuthentication auth = LocalAuthentication();

  void openLoginPage() {
    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (context) => const LoginScreen(),
      ),
    )
        .then((value) {
      postLoginSteps();
    });
  }

  Future<bool> init() async {
    await Hive.openBox('settingsBox');

    bool canCheckBiometrics = false;
    try {
      if (await auth.isDeviceSupported() &&
          await auth.canCheckBiometrics &&
          (await auth.getAvailableBiometrics()).isNotEmpty) {
        canCheckBiometrics = true;
      } else {
        canCheckBiometrics = false;
      }
    } on PlatformException catch (_) {
      canCheckBiometrics = false;
    }

    //online check
    if (!await isDeviceConnected()) {
      throw Exception('No Internet connection');
    }
    if (!await isNamiOnline()) {
      throw Exception('Nami is not online');
    }

    try {
      await openHive();
    } catch (_) {}

    //nami login
    var needLogin = await doesNeedLogin();
    if (needLogin) {
      openLoginPage();
      return false;
    }

    //app login
    if (canCheckBiometrics && !authenticated) {
      bool authenticated = await authenticate();
      setState(() {
        this.authenticated = authenticated;
      });
    }

    await postLoginSteps();

    return !needLogin && authenticated;
  }

  Future<void> postLoginSteps() async {
    if (DateTime.now().difference(getLastNamiSync()!).inDays > 30) {
      debugPrint(
          "Letzter NaMi Sync länger als 30 Tage her. NaMi Sync wird durchgeführt.");
      // automatisch alle 30 Tage Syncronisieren

      syncNamiData();
    }
  }

  Future<bool> isDeviceConnected() async {
    var connectivityResult = await (Connectivity().checkConnectivity());
    if (connectivityResult == ConnectivityResult.none) {
      return false; // Keine Verbindung
    } else if (connectivityResult == ConnectivityResult.mobile ||
        connectivityResult == ConnectivityResult.wifi) {
      return true; // Verbunden mit Mobilem Netzwerk oder WLAN
    } else {
      return false; // Anderer Fall (z. B. Bluetooth)
    }
  }

  Future<bool> isNamiOnline() async {
    try {
      final response = await http.head(Uri.parse('https://nami.dpsg.de/'));
      if (response.statusCode == 200) {
        return true;
      }
    } catch (e) {
      return false;
    }
    return false;
  }

  Future<bool> doesNeedLogin() async {
    int lastLoginCheck =
        DateTime.now().difference(getLastLoginCheck()).inMinutes;

    // Überpüfe den Nami Login maximal alle 15 Minuten
    if (lastLoginCheck > 15) {
      if (await isLoggedIn()) {
        return false;
      }
      debugPrint(
          'Letzter Login Check länger als 15 Minuten her. Login nicht erfolgreich.');
      return true;
    }
    return false;
  }

  Future<bool> authenticate() async {
    authenticated = false;
    try {
      return await auth.authenticate(
          localizedReason: 'Let OS determine authentication method');
    } on PlatformException catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: Provider.of<ThemeModel>(context).currentTheme,
      home: Scaffold(
        body: FutureBuilder(
          future: init(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done) {
              if (snapshot.error != null) {
                return Scaffold(
                  body: Center(
                    child: Text('${snapshot.error}'),
                  ),
                );
              } else {
                return const NavigationHomeScreen();
              }
            } else {
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(),
                ),
              );
            }
          },
        ),
      ),
    );
  }
}

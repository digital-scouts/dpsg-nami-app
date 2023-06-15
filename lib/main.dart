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
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;

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

  static void restartApp(BuildContext context) {
    context.findAncestorStateOfType<MyAppState>()!.restartApp();
  }

  @override
  MyAppState createState() => MyAppState();
}

class MyAppState extends State<MyApp> {
  Key key = UniqueKey();

  void restartApp() {
    setState(() {
      key = UniqueKey();
    });
  }

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
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const LoginScreen(),
      ),
    );
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
    if (!await isOnline('example.com')) {
      throw Exception('No Internet connection');
    }
    if (!await isOnline('nami.dpsg.de')) {
      throw Exception('Nami is not online');
    }

    //nami login
    var _needLogin = await needLogin();
    if (_needLogin) {
      openLoginPage();
      _needLogin = await needLogin();
    }

    //app login
    if (canCheckBiometrics && !authenticated) {
      bool authenticated = await authenticate();
      setState(() {
        this.authenticated = authenticated;
      });
    }

    try {
      await openHive();
    } catch (_) {}

    if (DateTime.now().difference(getLastNamiSync()!).inDays > 30) {
      debugPrint(
          "Letzter NaMi Sync länger als 30 Tage her. NaMi Sync wird durchgeführt.");
      // automatisch alle 30 Tage Syncronisieren

      syncNamiData();
    }

    return !_needLogin && authenticated;
  }

  Future<bool> isOnline(url) async {
    try {
      final result = await InternetAddress.lookup(url);
      final response = await http.head(Uri.parse('https://$url'));
      if (result.isNotEmpty &&
          result[0].rawAddress.isNotEmpty &&
          response.statusCode == 200) {
        return true;
      }
    } on SocketException catch (_) {
      return false;
    }
    return false;
  }

  Future<bool> needLogin() async {
    int lastLoginCheck =
        DateTime.now().difference(getLastLoginCheck()).inMinutes;

    // Überpüfe den Nami Login maximal alle 15 Minuten
    if (lastLoginCheck > 15) {
      bool _isLoggedIn = await isLoggedIn();
      if (_isLoggedIn) {
        return needLogin();
      }
      debugPrint(
          'Letzter Login Check länger als 15 Minuten her. Login nicht erfolgreich.');
      return true;
    }
    if (lastLoginCheck <= 15) {
      return false;
    }
    return true;
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

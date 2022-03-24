import 'package:hive/hive.dart';
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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

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
  var taetigkeitBox = await Hive.openBox<Taetigkeit>('taetigkeit',
      encryptionCipher: HiveAesCipher(encryptionKey));
  Hive.registerAdapter(MitgliedAdapter());
  var memberBox = await Hive.openBox<Mitglied>('members',
      encryptionCipher: HiveAesCipher(encryptionKey));

  runApp(ChangeNotifierProvider<ThemeModel>(
      create: (_) => ThemeModel(), child: const MyApp()));
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: MyHome());
  }
}

class MyHome extends StatefulWidget {
  MyHome({Key? key}) : super(key: key);

  @override
  State<MyHome> createState() => _MyHomeState();
}

class _MyHomeState extends State<MyHome> {
  bool authenticated = false;
  final LocalAuthentication auth = LocalAuthentication();

  Future<bool> init() async {
    await Hive.openBox('settingsBox');

    bool _canCheckBiometrics = false;
    try {
      if (await auth.isDeviceSupported() &&
          await auth.canCheckBiometrics &&
          (await auth.getAvailableBiometrics()).isNotEmpty) {
        _canCheckBiometrics = true;
      } else {
        _canCheckBiometrics = false;
      }
    } on PlatformException catch (_) {
      _canCheckBiometrics = false;
    }

    //nami login
    var _isOnline = await isOnline();
    var _needLogin = await needLogin();
    if (_isOnline && _needLogin) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const LoginScreen(),
        ),
      );
      _needLogin = await needLogin();
    }

    //app login
    if (_canCheckBiometrics && !authenticated) {
      authenticated = await authenticate();
      setState(() {
        authenticated = authenticated;
      });
    }

    return _isOnline && !_needLogin && authenticated;
  }

  Future<bool> isOnline() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
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
    int lastNamiSync = DateTime.now().difference(getLastNamiSync()!).inDays;
    debugPrint(
        'Letzter Login Check: $lastLoginCheck Min | Letzter Nami Sync: $lastNamiSync Days');
    // Überpüfe den Nami Login maximal alle 15 Minuten
    if (lastLoginCheck > 15) {
      bool _isLoggedIn = await isLoggedIn();
      if (_isLoggedIn) {
        return needLogin();
      }
      debugPrint(
          'Letzter Login Check länger als 15 Minuten her. Login nicht erfolgreich.');
      return false;
    } else if (lastNamiSync > 30) {
      debugPrint(
          "Letzter NaMi Sync länger als 30 Tage her. NaMi Sync wird durchgeführt.");
      // automatisch alle 30 Tage Syncronisieren
      syncNamiData(context);
    }
    if (lastLoginCheck <= 15) {
      return false;
    }
    return true;
  }

  Future<bool> authenticate() async {
    authenticated = false;
    try {
      print('Authenticating');
      return await auth.authenticate(
          localizedReason: 'Let OS determine authentication method',
          useErrorDialogs: true,
          stickyAuth: false);
    } on PlatformException catch (e) {
      print(e);
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
                return const Scaffold(
                  body: Center(
                    child: Text('Something went wrong :/'),
                  ),
                );
              } else {
                return const NavigationHomeScreen();
              }
            } else {
              return const Scaffold(
                body: Center(
                  child: Text('Opening Hive...'),
                ),
              );
            }
          },
        ),
      ),
    );
  }
}

import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:flutter/material.dart';
import 'package:nami/screens/login.dart';
import 'package:nami/screens/navigation_home_screen.dart';
import 'package:nami/utilities/hive/mitglied.dart';
import 'package:nami/utilities/hive/settings.dart';
import 'package:nami/utilities/hive/taetigkeit.dart';
import 'package:nami/utilities/nami/nami-login.service.dart';
import 'package:nami/utilities/theme.dart';
import 'package:provider/provider.dart';
import 'utilities/nami/nami.service.dart';

import 'dart:io';

void main() async {
  await Hive.initFlutter();

  Hive.registerAdapter(TaetigkeitAdapter());
  await Hive.openBox<Taetigkeit>('taetigkeit');
  Hive.registerAdapter(MitgliedAdapter());
  await Hive.openBox<Mitglied>('members');

  runApp(ChangeNotifierProvider<ThemeModel>(
      create: (_) => ThemeModel(), child: const MyApp()));
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Future<bool> init() async {
    await Hive.openBox('settingsBox');
    return await isOnline() && await needLogin();
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
    // Überpüfe den Login maximal alle 15 Minuten
    if (lastLoginCheck > 15 && !await isLoggedIn()) {
      debugPrint(
          'Letzter Login Check länger als 15 Minuten her. Login nicht erfolgreich.');
      return true;
    } else if (lastNamiSync > 30) {
      debugPrint(
          "Letzter NaMi Sync länger als 30 Tage her. NaMi Sync wird durchgeführt.");
      // automatisch alle 30 Tage Syncronisieren
      syncNamiData(context);
    }

    return true;
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
              } else if (snapshot.data == true) {
                return const LoginScreen();
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

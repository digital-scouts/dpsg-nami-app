import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:flutter/material.dart';
import 'package:nami/hive/mitglied.dart';
import 'package:nami/hive/settings.dart';
import 'package:nami/model/nami_member_details_model.dart';
import 'package:nami/screens/login.dart';
import 'package:flutter/services.dart';
import 'package:nami/screens/navigation_home_screen.dart';

import 'utilities/app_theme.dart';
import 'utilities/nami.service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'dart:io';

void main() async {
  await Hive.initFlutter();

  Hive.registerAdapter(MitgliedAdapter());

  runApp(
    const MaterialApp(
      home: MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  double syncProgress = 0;
  @override
  void initState() {
    super.initState();
    // initNami();
  }

  void init() async {
    setNamiUrl("https://2cb269f6-99dd-4fa8-9aea-fafe6fdb231b.mock.pstmn.io");
    setNamiPath("/ica/rest/api/1/1/service/nami");
    if (!await isLoggedIn()) {
      navPushLogin();
      return;
    }
    int gruppierung = await loadGruppierung();
    if (gruppierung == 0) {
      throw Exception("Keine eindeutige Gruppierung gefunden");
    }
    setGruppierung(gruppierung);
    syncNamiData();
  }

  void syncNamiData() async {
    syncProgress = 0;
    List<int> members = await loadMemberIds();

    double syncProgressSteps = 1 / members.length;
    List<NamiMemberDetailsModel> memberDetails = [];
    for (var member in members) {
      memberDetails.add(await loadMemberDetails(member));
      syncProgress += syncProgressSteps;
      print('Member $member loaded: ${(syncProgress * 100).round()}%');
    }
  }

  void navPushLogin() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness:
          !kIsWeb && Platform.isAndroid ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ));
    return MaterialApp(
      title: 'Nami',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        textTheme: AppTheme.textTheme,
        platform: TargetPlatform.iOS,
      ),
      home: Scaffold(
        body: FutureBuilder(
          future: Hive.openBox('settingsBox'),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done) {
              if (snapshot.error != null) {
                print(snapshot.error);
                return const Scaffold(
                  body: Center(
                    child: Text('Something went wrong :/'),
                  ),
                );
              } else {
                init();
                return NavigationHomeScreen();
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

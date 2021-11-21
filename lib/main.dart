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

late Box<Mitglied> memberBox;

void main() async {
  await Hive.initFlutter();

  Hive.registerAdapter(MitgliedAdapter());
  memberBox = await Hive.openBox<Mitglied>('members');
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
    //setNamiUrl("https://2cb269f6-99dd-4fa8-9aea-fafe6fdb231b.mock.pstmn.io");
    setNamiUrl("https://nami.dpsg.de");
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
    List<int> mitgliedIds = await loadMemberIds();

    double syncProgressSteps = 1 / mitgliedIds.length;
    for (var mitgliedId in mitgliedIds) {
      storeMitgliedToHive(mitgliedId)
          .then((value) => syncProgress += syncProgressSteps)
          .then((value) => print(
              'Member $mitgliedId loaded: ${(syncProgress * 100).round()}%'));
    }
  }

  Future<bool> storeMitgliedToHive(int mitgliedId) async {
    NamiMemberDetailsModel rawMember = await loadMemberDetails(mitgliedId);
    Mitglied mitglied = Mitglied()
      ..vorname = rawMember.vorname
      ..nachname = rawMember.nachname
      ..geschlecht = rawMember.geschlecht
      ..geburtsDatum = rawMember.geburtsDatum
      ..stufe = rawMember.stufe
      ..id = rawMember.id
      ..mitgliedsNummer = rawMember.mitgliedsNummer
      ..eintrittsdatum = rawMember.eintrittsdatum
      ..austrittsDatum = rawMember.austrittsDatum
      ..ort = rawMember.ort
      ..plz = rawMember.plz
      ..strasse = rawMember.strasse
      ..landId = rawMember.landId ?? 1
      ..email = rawMember.email
      ..emailVertretungsberechtigter = rawMember.emailVertretungsberechtigter
      ..telefon1 = rawMember.telefon1
      ..telefon2 = rawMember.telefon2
      ..telefon3 = rawMember.telefon3
      ..lastUpdated = rawMember.lastUpdated
      ..version = rawMember.version
      ..mglTypeId = rawMember.mglTypeId
      ..beitragsartId = rawMember.beitragsartId ?? 0
      ..status = rawMember.status;
    memberBox.put(mitgliedId, mitglied);
    return true;
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

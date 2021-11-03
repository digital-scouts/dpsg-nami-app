import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:flutter/material.dart';
import 'package:nami/hive/mitglied.dart';
import 'package:nami/hive/settings.dart';
import 'package:nami/screens/dashboard.dart';
import 'package:nami/screens/login.dart';

import 'utilities/nami.service.dart';

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
    return MaterialApp(
      title: 'Fetch Data Example',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Home'),
        ),
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
                return const DashboardScreen();
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

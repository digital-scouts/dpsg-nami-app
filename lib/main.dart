import 'dart:async';
import 'dart:convert';

import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:nami/hive/mitglied.dart';
import 'package:nami/nami_stats_model.dart';
import 'package:nami/hive/settings.dart';
import 'package:nami/screens/login.dart';

const String namiUrl =
    "https://2cb269f6-99dd-4fa8-9aea-fafe6fdb231b.mock.pstmn.io";
const String namiPath = "/ica/rest/api/1/1/service/nami";

Future<String> namiLogin() async {
  final response = await http.post(
      Uri.parse(namiUrl + namiPath + "/auth/manual/sessionStartup"),
      headers: {"Content-Type": "application/json"},
      body: json.encode({
        'username': '203636',
        'password': 'A7GXbTdKgEKt2s',
        'Login': 'API'
      }));

  if (response.statusCode == 200 &&
      response.headers.containsKey('set-cookie')) {
    return response.headers["set-cookie"]!.split(';')[0];
  } else {
    throw Exception('Failed to load album');
  }
}

Future<NamiStatsModel> loadNamiStats(Future<String> cookie) async {
  String c = await cookie;
  final response = await http.get(
      Uri.parse(namiUrl + "/ica/rest/dashboard/stats/stats"),
      headers: {'Cookie': c});

  if (response.statusCode == 200) {
    return NamiStatsModel.fromJson(jsonDecode(response.body));
  } else {
    throw Exception('Failed to load album');
  }
}

void main() async {
  await Hive.initFlutter();
  Hive.registerAdapter(MitgliedAdapter());
  Hive.registerAdapter(SettingsAdapter());

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
    checkLoginState();
    super.initState();
  }

  void checkLoginState() async {
    var box = await Hive.openBox<Settings>('settingsBox');
    String? token = box.get('s')?.namiApiToken;
    if (token == null) {
      print('token: $token');
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    } else {
      // todo load Api Data
    }
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
        body: FutureBuilder<NamiStatsModel>(
          future: loadNamiStats(namiLogin()),
          builder:
              (BuildContext context, AsyncSnapshot<NamiStatsModel> snapshot) {
            if (snapshot.hasData) {
              return ListView.builder(
                  itemCount: snapshot.data?.statsCategories.length,
                  itemBuilder: (context, i) {
                    return ListTile(
                      title: Text('${snapshot.data?.statsCategories[i].name}'),
                      subtitle:
                          Text('${snapshot.data?.statsCategories[i].count}'),
                    );
                  });
            } else if (snapshot.hasError) {
              return const Text("Error...");
            }
            return const CircularProgressIndicator();
          },
        ),
      ),
    );
  }
}

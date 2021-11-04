import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:nami/hive/settings.dart';
import 'package:nami/model/nami_stats_model.dart';

/// Versucht ein Login mit ID und Passwort. True wenn erfolgreich.
Future<bool> namiLoginWithPassword(int userId, String password) async {
  String url = getNamiLUrl();
  String path = getNamiPath();
  final response = await http.post(
      Uri.parse('$url$path/auth/manual/sessionStartup'),
      headers: {"Content-Type": "application/json"},
      body: json
          .encode({'username': userId, 'password': password, 'Login': 'API'}));

  if (response.statusCode == 200 &&
      response.headers.containsKey('set-cookie')) {
    String cookie = response.headers["set-cookie"]!.split(';')[0];
    setNamiApiCookie(cookie);
    return true;
  }
  return false;
}

/// läd Nami Dashboard Statistiken
Future<NamiStatsModel> loadNamiStats() async {
  String url = getNamiLUrl();
  final response = await http.get(
      Uri.parse('$url/ica/rest/dashboard/stats/stats'),
      headers: {'Cookie': '$getNamiApiCookie()'});

  if (response.statusCode == 200) {
    return NamiStatsModel.fromJson(jsonDecode(response.body));
  } else {
    throw Exception('Failed to load album');
  }
}

/// prüft anhand eines Test-Requests, ob der Nutzer eingeloggt ist.
Future<bool> isLoggedIn() async {
  //check if token exists
  String? token = getNamiApiCookie();
  if (token == null || token.isEmpty) {
    print('token: $token');
    return false;
  }

  //check if token is valid
  try {
    await loadNamiStats();
  } catch (ex) {
    print('token is not null but not valid');
    return false;
  }
  return true;
}

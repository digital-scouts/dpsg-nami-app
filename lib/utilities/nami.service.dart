import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:nami/hive/settings.dart';
import 'package:nami/model/nami_stats_model.dart';
import 'package:nami/model/nami_member_details_model.dart';

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

Future<List<int>> loadMemberIds() async {
  String url = getNamiLUrl();
  String path = getNamiPath();
  int? gruppierung = getGruppierung();
  String fullUrl =
      '$url$path/mitglied/filtered-for-navigation/gruppierung/gruppierung/$gruppierung/flist?_dc=1635173028278&page=1&start=0&limit=5000';
  final response = await http
      .get(Uri.parse(fullUrl), headers: {'Cookie': '$getNamiApiCookie()'});

  if (response.statusCode == 200) {
    List<int> memberIds = [];
    jsonDecode(response.body)['data']
        .forEach((item) => memberIds.add(item['id']));
    return memberIds;
  } else {
    throw Exception('Failed to load member List');
  }
}

/// returns the id of the current gruppierung | return 0 when there are multiple or 0 gruppierungen
Future<int> loadGruppierung({node = 'root'}) async {
  String url = getNamiLUrl();
  String path = getNamiPath();
  String fullUrl =
      '$url$path/gruppierungen/filtered-for-navigation/gruppierung/node/$node';
  final response = await http
      .get(Uri.parse(fullUrl), headers: {'Cookie': '$getNamiApiCookie()'});

  if (response.statusCode != 200) {
    return 0;
  }

  if (jsonDecode(response.body)['data'].length == 1) {
    int currentGruppierungId = jsonDecode(response.body)['data'][0]['id'];
    if (currentGruppierungId > 0) {
      int nextGruppierungId = await loadGruppierung(node: currentGruppierungId);
      return nextGruppierungId == 0 ? currentGruppierungId : nextGruppierungId;
    }
  }

  return 0;
}

Future<NamiMemberDetailsModel> loadMemberDetails(int id) async {
  String url = getNamiLUrl();
  String path = getNamiPath();
  int? gruppierung = getGruppierung();
  String fullUrl =
      '$url$path/mitglied/filtered-for-navigation/gruppierung/gruppierung/$gruppierung/$id';
  final response = await http
      .get(Uri.parse(fullUrl), headers: {'Cookie': '$getNamiApiCookie()'});

  if (response.statusCode == 200) {
    return NamiMemberDetailsModel.fromJson(jsonDecode(response.body)['data']);
  } else {
    throw Exception('Failed to load album');
  }
}

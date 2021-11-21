import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:nami/hive/settings.dart';
import 'package:nami/model/nami_stats_model.dart';
import 'package:nami/model/nami_member_details_model.dart';

/// Versucht ein Login mit ID und Passwort. True wenn erfolgreich.
Future<bool> namiLoginWithPassword(int userId, String password) async {
  String url = getNamiLUrl();
  String path = getNamiPath();
  Uri uri = Uri.parse('$url$path/auth/manual/sessionStartup');
  Map<String, String> body = {
    'username': userId.toString(),
    'password': 'Janneckl-95',
    'Login': 'API'
  };
  Map<String, String> headers = {
    "Host": 'nami.dpsg.de',
    "Origin": 'https://nami.dpsg.de',
    'Content-Type': 'application/x-www-form-urlencoded',
    //'Content-Length': bodyBytes.length.toString(),
  };

  http.Response authRedirect =
      await http.post(uri, body: body, headers: headers);

  if (authRedirect.statusCode != 302 ||
      authRedirect.headers['location']!.isEmpty) {
    return false;
  }

  Uri redirectUri = Uri.parse(authRedirect.headers['location']!);
  http.Response response = await http.get(redirectUri);

  /*final response2 = await http.post(
      Uri.parse('$url$path/auth/manual/sessionStartup'),
      headers: headers,
      body: json.encode(body));*/

  if (response.statusCode != 200 ||
      !response.headers.containsKey('set-cookie')) {
    return false;
  }
  var resBody = json.decode(response.body);
  if (resBody['statusCode'] != 0 || resBody['statusMessage'].length > 0) {
    return false;
  }
  String cookie = response.headers["set-cookie"]!.split(';')[0];
  setNamiApiCookie(cookie);
  return true;
}

/// läd Nami Dashboard Statistiken
Future<NamiStatsModel> loadNamiStats() async {
  String url = getNamiLUrl();
  String? cookie = getNamiApiCookie();
  final response = await http.get(
      Uri.parse('$url/ica/rest/dashboard/stats/stats'),
      headers: {'Cookie': '$cookie'});
  Map<String, dynamic> json = jsonDecode(response.body);
  if (response.statusCode == 200 && json['success']) {
    Map<String, dynamic> json = jsonDecode(response.body);
    NamiStatsModel stats = NamiStatsModel.fromJson(json);
    return stats;
  } else {
    throw Exception('Failed to load album');
  }
}

/// prüft anhand eines Test-Requests, ob der Nutzer eingeloggt ist.
Future<bool> isLoggedIn() async {
  //check if token exists
  String? token = getNamiApiCookie();
  print('token: $token');
  if (token == null || token.isEmpty) {
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
  String cookie = getNamiApiCookie() ?? '';
  String fullUrl =
      '$url$path/mitglied/filtered-for-navigation/gruppierung/gruppierung/$gruppierung/flist?_dc=1635173028278&page=1&start=0&limit=5000';
  final response =
      await http.get(Uri.parse(fullUrl), headers: {'Cookie': cookie});

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
  String cookie = getNamiApiCookie() ?? '';
  String fullUrl =
      '$url$path/gruppierungen/filtered-for-navigation/gruppierung/node/$node';
  final response =
      await http.get(Uri.parse(fullUrl), headers: {'Cookie': cookie});

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
  String cookie = getNamiApiCookie() ?? '';
  String fullUrl =
      '$url$path/mitglied/filtered-for-navigation/gruppierung/gruppierung/$gruppierung/$id';
  final response =
      await http.get(Uri.parse(fullUrl), headers: {'Cookie': cookie});
  var source = json.decode(Utf8Decoder().convert(response.bodyBytes));

  if (response.statusCode == 200) {
    return NamiMemberDetailsModel.fromJson(source['data']);
  } else {
    throw Exception('Failed to load album');
  }
}

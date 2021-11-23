import 'dart:convert';

import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:nami/model/nami_stats_model.dart';
import 'package:nami/model/nami_member_details_model.dart';
import 'package:nami/utilities/hive/mitglied.dart';
import 'package:nami/utilities/hive/settings.dart';

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
      headers: {'Cookie': cookie});
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
  if (token.isEmpty) {
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
  String cookie = getNamiApiCookie();
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
  String cookie = getNamiApiCookie();
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
  String cookie = getNamiApiCookie();
  String fullUrl =
      '$url$path/mitglied/filtered-for-navigation/gruppierung/gruppierung/$gruppierung/$id';
  final response =
      await http.get(Uri.parse(fullUrl), headers: {'Cookie': cookie});
  var source = json.decode(const Utf8Decoder().convert(response.bodyBytes));

  if (response.statusCode == 200) {
    return NamiMemberDetailsModel.fromJson(source['data']);
  } else {
    throw Exception('Failed to load album');
  }
}

void syncNamiData() async {
  await syncGruppierung();
  syncMember();
  //syncStats
  //syncProfile
}

syncGruppierung() async {
  int gruppierung = getGruppierung() ?? await loadGruppierung();
  if (gruppierung == 0) {
    throw Exception("Keine eindeutige Gruppierung gefunden");
  }
  setGruppierung(gruppierung);
}

syncMember() async {
  double memberSyncProgress = 0;
  Box<Mitglied> memberBox = Hive.box('members');
  List<int> mitgliedIds = await loadMemberIds();

  double syncProgressSteps = 1 / mitgliedIds.length;
  for (var mitgliedId in mitgliedIds) {
    storeMitgliedToHive(mitgliedId, memberBox)
        .then((value) => memberSyncProgress += syncProgressSteps)
        .then((value) => print(
            'Member $mitgliedId loaded: ${(memberSyncProgress * 100).round()}%'));
  }
}

Future<void> storeMitgliedToHive(
    int mitgliedId, Box<Mitglied> memberBox) async {
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
}

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:nami/utilities/hive/settings.dart';
import 'model/nami_stats.model.dart';
import 'package:nami/utilities/nami/nami_member_add_meta.dart';

/// läd Nami Dashboard Statistiken
Future<NamiStatsModel> loadNamiStats() async {
  String url = getNamiLUrl();
  String? cookie = getNamiApiCookie();
  debugPrint('Request: Lade Stats');
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

Future<String> loadGruppierung() async {
  String url = getNamiLUrl();
  String path = getNamiPath();
  String cookie = getNamiApiCookie();
  String fullUrl = '$url$path/gf/gruppierung';

  if (cookie == 'testLoginCookie') {
    setGruppierungId(1234);
    setGruppierungName("1234 Test Gruppierung");
    return '1234 Test Gruppierung';
  }

  debugPrint('Request: Lade Gruppierung');
  final response =
      await http.get(Uri.parse(fullUrl), headers: {'Cookie': cookie});

  if (response.statusCode != 200 ||
      !jsonDecode(response.body)['success'] ||
      jsonDecode(response.body)['data'].length != 1) {
    debugPrint(
        'Failed to load gruppierung. Multiple or no gruppierungen found');
    throw Exception('Failed to load gruppierung');
  }

  int gruppierungId = jsonDecode(response.body)['data'][0]['id'];
  String gruppierungName = jsonDecode(response.body)['data'][0]['descriptor'];
  setGruppierungId(gruppierungId);
  setGruppierungName(gruppierungName);
  debugPrint('Gruppierung: $gruppierungName ($gruppierungId)');
  return gruppierungName;
}

Future<void> reloadMetadataFromServer() async {
  debugPrint('Reloading metadata from server');
  var results = await Future.wait([
    getGeschlechtMeta(),
    getLandMeta(),
    getRegionMeta(),
    getBeitragsartenMeta(),
    getStaatsangehoerigkeitMeta(),
    getMitgliedstypMeta(),
  ]);
  setMetaData(
      results[0], results[1], results[2], results[3], results[4], results[5]);
}

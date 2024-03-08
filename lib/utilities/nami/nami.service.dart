import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:nami/utilities/hive/settings.dart';
import 'package:nami/utilities/nami/nami_rechte.dart';
import 'model/nami_stats.model.dart';
import 'nami-member.service.dart';
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

Future<void> loadGruppierung() async {
  String url = getNamiLUrl();
  String path = getNamiPath();
  String cookie = getNamiApiCookie();
  String fullUrl = '$url$path/gf/gruppierung';
  debugPrint('Request: Lade Gruppierung');
  final response =
      await http.get(Uri.parse(fullUrl), headers: {'Cookie': cookie});

  if (response.statusCode == 200 &&
      jsonDecode(response.body)['success'] &&
      jsonDecode(response.body)['data'].length == 1) {
    int gruppierungId = jsonDecode(response.body)['data'][0]['id'];
    String gruppierungName = jsonDecode(response.body)['data'][0]['descriptor'];
    setGruppierungId(gruppierungId);
    setGruppierungName(gruppierungName);
    debugPrint('Gruppierung: $gruppierungName ($gruppierungId)');
    return;
  }
  debugPrint('Failed to load gruppierung. Multiple or no gruppierungen found');
}

Future<void> syncNamiData({bool forceSync = false}) async {
  // login / update token
  setLastNamiSync(DateTime.now());
  await loadGruppierung();
  await syncMember(forceSync);
  //load user data

  await reloadMetadataFromServer();
  var rechte = await getRechte();
  debugPrint('Rechte: $rechte');

  //syncStats
  //syncProfile
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

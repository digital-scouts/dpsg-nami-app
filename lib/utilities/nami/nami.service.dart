import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:nami/utilities/hive/settings.dart';
import 'model/nami_stats.model.dart';
import 'nami-member.service.dart';

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

/// returns the id of the current gruppierung | return 0 when there are multiple or 0 gruppierungen
Future<int> loadGruppierung({node = 'root'}) async {
  String url = getNamiLUrl();
  String path = getNamiPath();
  String cookie = getNamiApiCookie();
  String fullUrl =
      '$url$path/gruppierungen/filtered-for-navigation/gruppierung/node/$node';
  debugPrint('Request: Lade Gruppierung');
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

Future<void> syncNamiData(BuildContext context) async {
  setLastNamiSync(DateTime.now());
  await syncGruppierung();
  await syncMember(context);

  //syncStats
  //syncProfile
}

syncGruppierung() async {
  int gruppierung = getGruppierung() ?? await loadGruppierung();
  if (gruppierung == 0) {
    throw Exception("Keine eindeutige Gruppierung gefunden");
  }
  print('gruppierung: $gruppierung');
  setGruppierung(gruppierung);
}

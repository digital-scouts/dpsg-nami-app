import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:nami/utilities/hive/settings.dart';
import 'package:intl/intl.dart';
import 'package:nami/utilities/hive/taetigkeit.dart';
import 'package:nami/utilities/stufe.dart';

String url = getNamiLUrl();
String path = getNamiPath();
int? gruppierungId = getGruppierungId();
String? gruppierungName = getGruppierungName();
String cookie = getNamiApiCookie();

Future<void> stufenwechsel(int memberId, Taetigkeit currentTaetigkeit,
    Stufe nextStufe, DateTime stufenwechselDatum) async {
  debugPrint('Stufenwechsel für ${currentTaetigkeit.id}');
  await createTaetigkeitForStufe(memberId, stufenwechselDatum, nextStufe);
  await completeTaetigkeit(memberId, currentTaetigkeit, stufenwechselDatum);
  // TODO: Update member in Hive
}

Future<void> createTaetigkeit(int memberId, DateTime startDate,
    int taetigkeitId, int untergliederungId) async {
  String fullUrl =
      '$url$path/zugeordnete-taetigkeiten/filtered-for-navigation/gruppierung-mitglied/mitglied/$memberId';
  debugPrint('Request: Erstelle Tätigkeit für $memberId');

  if (gruppierungName == null || gruppierungId == null) {
    throw Exception('Parameter missing');
  }
  String formattedStartDate =
      DateFormat('yyyy-MM-ddTHH:mm:ss').format(startDate);
  final headers = {'Cookie': cookie, 'Content-Type': 'application/json'};
  final body = jsonEncode({
    'gruppierung': gruppierungName,
    'gruppierungId': gruppierungId,
    'aktivVon': formattedStartDate,
    'aktivBis': null,
    'taetigkeitId': taetigkeitId,
    'untergliederungId': untergliederungId
  });

  http.Response response;
  try {
    response = await http
        .post(Uri.parse(fullUrl), headers: headers, body: body)
        .whenComplete(
            () => debugPrint('Complete: Erstelle Tätigkeit für $memberId'));
  } catch (e) {
    throw Exception('Failed to create taetigkeit for $memberId');
  }

  if (response.statusCode != 200 || !jsonDecode(response.body)['success']) {
    throw Exception('Failed to create taetigkeit for $memberId');
  }
}

Future<void> completeTaetigkeit(
    int memberId, Taetigkeit taetigkeit, DateTime endDate) async {
  String fullUrl =
      '$url$path/zugeordnete-taetigkeiten/filtered-for-navigation/gruppierung-mitglied/mitglied/$memberId/${taetigkeit.id}';
  debugPrint('Request: Erstelle Tätigkeit für $memberId');

  final headers = {'Cookie': cookie, 'Content-Type': 'application/json'};
  final body = jsonEncode({
    'aktivVon': DateFormat('yyyy-MM-ddTHH:mm:ss').format(taetigkeit.aktivVon),
    'aktivBis': DateFormat('yyyy-MM-ddTHH:mm:ss').format(endDate),
  });

  http.Response response;
  try {
    response = await http
        .put(Uri.parse(fullUrl), headers: headers, body: body)
        .whenComplete(
            () => debugPrint('Complete: Erstelle Tätigkeit für $memberId'));
  } catch (e) {
    throw Exception('Failed to update taetigkeit for $memberId');
  }

  if (response.statusCode != 200 || !jsonDecode(response.body)['success']) {
    throw Exception('Failed to update taetigkeit for $memberId');
  }
}

Future<void> createTaetigkeitForStufe(
    int memberId, DateTime startDate, Stufe stufe) async {
  int taetigkeitId = 1;

  List<NamedId> untergliederungen =
      await loadUntergliederungAufTaetigkeit(taetigkeitId);
  NamedId untergliederung = untergliederungen.firstWhere(
      (element) => element.descriptor == stufe.name.value.toString());

  if (untergliederung.id == -1) {
    throw Exception(
        'Failed to create taetigkeit for $memberId. Untergruppe not found');
  }

  return createTaetigkeit(
      memberId, startDate, taetigkeitId, untergliederung.id);
}

Future<List<NamedId>> loadTaetigkeitAufGruppierung() async {
  String fullUrl =
      '$url$path/taetigkeitaufgruppierung/filtered/gruppierung/gruppierung/$gruppierungId';
  final response =
      await http.get(Uri.parse(fullUrl), headers: {'Cookie': cookie});

  if (response.statusCode != 200 || !jsonDecode(response.body)['success']) {
    debugPrint('Failed to load taetigkeiten.');
    return List.empty();
  }
  final data = jsonDecode(response.body)['data'];
  final taetigkeiten = List<NamedId>.from(
      data.map((item) => NamedId(item['id'], item['descriptor'])));
  return taetigkeiten;
}

Future<List<NamedId>> loadUntergliederungAufTaetigkeit(int taetigkeit) async {
  String fullUrl =
      '$url$path/untergliederungauftaetigkeit/filtered/untergliederung/taetigkeit/$taetigkeit';
  final response =
      await http.get(Uri.parse(fullUrl), headers: {'Cookie': cookie});

  if (response.statusCode != 200 || !jsonDecode(response.body)['success']) {
    debugPrint('Failed to load untergliederungen.');
    return List.empty();
  }
  final data = jsonDecode(response.body)['data'];
  final taetigkeiten = List<NamedId>.from(
      data.map((item) => NamedId(item['id'], item['descriptor'])));
  return taetigkeiten;
}

class NamedId {
  int id;
  String descriptor;
  NamedId(this.id, this.descriptor);
}

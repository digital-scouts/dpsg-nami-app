import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:nami/utilities/hive/mitglied.dart';
import 'package:nami/utilities/hive/settings.dart';
import 'package:nami/utilities/hive/taetigkeit.dart';
import 'package:nami/utilities/logger.dart';
import 'package:nami/utilities/nami/nami_member.service.dart';
import 'package:nami/utilities/stufe.dart';
import 'package:wiredash/wiredash.dart';

String url = getNamiLUrl();
String path = getNamiPath();
int? gruppierungId = getGruppierungId();
String? gruppierungName = getGruppierungName();
String cookie = getNamiApiCookie();

Future<Mitglied> stufenwechsel(
  int memberId,
  Taetigkeit currentTaetigkeit,
  Stufe nextStufe,
  DateTime stufenwechselDatum,
) async {
  Wiredash.trackEvent('Stufenwechsel wird durchgefuehrt');
  sensLog.i('Stufenwechsel für ${sensId(memberId)}');
  // erst die neue Tätigkeit anlegen und dann die alte Tätigkeit beenden
  await createTaetigkeitForStufe(memberId, stufenwechselDatum, nextStufe);
  await completeTaetigkeit(memberId, currentTaetigkeit, stufenwechselDatum);
  return await updateOneMember(memberId);
}

Future<void> createTaetigkeit(
  int memberId,
  DateTime startDate,
  String taetigkeitId,
  String untergliederungId, {
  String? caeaGroup,
}) async {
  String fullUrl =
      '$url$path/zugeordnete-taetigkeiten/filtered-for-navigation/gruppierung-mitglied/mitglied/$memberId';
  sensLog.i('Request: Erstelle Tätigkeit für ${sensId(memberId)}');

  if (gruppierungName == null || gruppierungId == null) {
    throw Exception('Parameter missing');
  }
  String formattedStartDate = DateFormat(
    'yyyy-MM-ddTHH:mm:ss',
  ).format(startDate);
  final headers = {'Cookie': cookie, 'Content-Type': 'application/json'};
  final body = jsonEncode({
    'gruppierung': gruppierungName,
    'gruppierungId': gruppierungId,
    'aktivVon': formattedStartDate,
    'aktivBis': null,
    'taetigkeitId': taetigkeitId,
    'untergliederungId': untergliederungId,
    'caeaGroupId': caeaGroup,
    'caeaGroupForGfId': caeaGroup,
  });

  http.Response response;
  try {
    response = await http.post(
      Uri.parse(fullUrl),
      headers: headers,
      body: body,
    );
    sensLog.i('Complete: Erstelle Tätigkeit für ${sensId(memberId)}');
  } catch (e) {
    throw Exception('Failed to create taetigkeit for ${sensId(memberId)}');
  }

  if (response.statusCode != 200 || !jsonDecode(response.body)['success']) {
    throw Exception('Failed to create taetigkeit for ${sensId(memberId)}');
  }
  sensLog.i('Success: Tätigkeit erstellt für ${sensId(memberId)}');
}

Future<void> completeTaetigkeit(
  int memberId,
  Taetigkeit taetigkeit,
  DateTime endDate,
) async {
  String fullUrl =
      '$url$path/zugeordnete-taetigkeiten/filtered-for-navigation/gruppierung-mitglied/mitglied/$memberId/${taetigkeit.id}';
  sensLog.i('Request: Complete Tätigkeit for ${sensId(memberId)}');

  final headers = {'Cookie': cookie, 'Content-Type': 'application/json'};
  final body = jsonEncode({
    'aktivVon': DateFormat('yyyy-MM-ddTHH:mm:ss').format(taetigkeit.aktivVon),
    'aktivBis': DateFormat('yyyy-MM-ddTHH:mm:ss').format(endDate),
  });

  http.Response response;
  try {
    response = await http.put(Uri.parse(fullUrl), headers: headers, body: body);
    sensLog.i('Complete: Erstelle Tätigkeit für ${sensId(memberId)}');
  } catch (e) {
    throw Exception('Failed to update taetigkeit for ${sensId(memberId)}');
  }

  if (response.statusCode != 200 || !jsonDecode(response.body)['success']) {
    throw Exception('Failed to update taetigkeit for ${sensId(memberId)}');
  }
  sensLog.i('Success: Tätigkeit erstellt für ${sensId(memberId)}');
}

Future<void> deleteTaetigkeit(int memberId, Taetigkeit taetigkeit) async {
  String fullUrl =
      '$url$path/zugeordnete-taetigkeiten/filtered-for-navigation/gruppierung-mitglied/mitglied/$memberId/${taetigkeit.id}';
  sensLog.i(
    'Request: Delete Tätigkeit ${taetigkeit.id} für ${sensId(memberId)}',
  );

  try {
    await http.delete(Uri.parse(fullUrl), headers: {'Cookie': cookie});
    sensLog.i(
      'Complete: Delete Tätigkeit ${taetigkeit.id} für ${sensId(memberId)}',
    );
  } catch (e) {
    throw Exception(
      'Failed to delete taetigkeit ${taetigkeit.id} for ${sensId(memberId)}',
    );
  }

  /*
  Ignore Errors and Statuscodes for now - Server is not working properly
  if (response.statusCode != 200 || !jsonDecode(response.body)['success']) {
    throw Exception(
        'Failed to delete taetigkeit ${taetigkeit.id} for ${sensId(memberId)}');
  }
  */
  sensLog.i('Success: Tätigkeit gelöscht für ${sensId(memberId)}');
}

Future<void> createTaetigkeitForStufe(
  int memberId,
  DateTime startDate,
  Stufe stufe,
) async {
  int taetigkeitId = 1;

  Map<int, String> untergliederungen = await loadUntergliederungAufTaetigkeit(
    taetigkeitId,
  );
  int untergliederungId = untergliederungen.entries
      .firstWhere((element) => element.value == stufe.display)
      .key;

  return createTaetigkeit(
    memberId,
    startDate,
    taetigkeitId.toString(),
    untergliederungId.toString(),
  );
}

Future<Map<int, String>> loadTaetigkeitAufGruppierung() async {
  String fullUrl =
      '$url$path/taetigkeitaufgruppierung/filtered/gruppierung/gruppierung/$gruppierungId';
  final response = await http.get(
    Uri.parse(fullUrl),
    headers: {'Cookie': cookie},
  );

  if (response.statusCode != 200 || !jsonDecode(response.body)['success']) {
    sensLog.e('Failed to load taetigkeiten.');
    return {};
  }
  final data = jsonDecode(response.body)['data'];
  return Map<int, String>.fromEntries(
    data.map<MapEntry<int, String>>(
      (item) => MapEntry<int, String>(item['id'], item['descriptor']),
    ),
  );
}

Future<Map<int, String>> loadUntergliederungAufTaetigkeit(
  int taetigkeit,
) async {
  String fullUrl =
      '$url$path/untergliederungauftaetigkeit/filtered/untergliederung/taetigkeit/$taetigkeit';
  final response = await http.get(
    Uri.parse(fullUrl),
    headers: {'Cookie': cookie},
  );

  if (response.statusCode != 200 || !jsonDecode(response.body)['success']) {
    sensLog.e('Failed to load untergliederungen.');
    return {};
  }
  final data = jsonDecode(response.body)['data'];

  return Map<int, String>.fromEntries(
    data.map<MapEntry<int, String>>(
      (item) => MapEntry<int, String>(item['id'], item['descriptor']),
    ),
  );
}

/// Rechte die eine Tätigkeit haben kann (Lesen oder Schreiben/Lesen)
Future<Map<int, String>> loadCaeaGroupAufTaetigkeit(String taetigkeit) async {
  String fullUrl =
      '$url$path/caea-group/filtered-for-navigation/taetigkeit/taetigkeit/$taetigkeit';
  final response = await http.get(
    Uri.parse(fullUrl),
    headers: {'Cookie': cookie},
  );

  if (response.statusCode != 200 || !jsonDecode(response.body)['success']) {
    sensLog.e('Failed to load untergliederungen.');
    return {};
  }
  final data = jsonDecode(response.body)['data'];
  return Map<int, String>.fromEntries(
    data.map<MapEntry<int, String>>(
      (item) => MapEntry<int, String>(item['id'], item['descriptor']),
    ),
  );
}

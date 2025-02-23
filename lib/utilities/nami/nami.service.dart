import 'dart:convert';

import 'package:html/dom.dart';
import 'package:html/parser.dart';
import 'package:http/http.dart' as http;
import 'package:nami/utilities/hive/settings.dart';
import 'package:nami/utilities/logger.dart';
import 'package:nami/utilities/nami/model/nami_gruppierung.model.dart';
import 'package:nami/utilities/nami/nami_login.service.dart';
import 'package:nami/utilities/nami/nami_member_add_meta.dart';
import 'package:nami/utilities/types.dart';

import 'model/nami_stats.model.dart';

/// Calls [func] and returns the json decoded body if reuqest ws succsessful
///
/// If the request failes with an expired session, it tries to get a new cookie
/// with saved password and retries [func].
/// Throws [SessionExpiredException] if that's not possible
///
/// Remeber to obtain the cookie in [func] to always use the latest one.
dynamic withMaybeRetry(Future<http.Response> Function() func,
    [String? errorMessage]) async {
  final response = await func();

  if (response.statusCode == 200 && jsonDecode(response.body)['success']) {
    return jsonDecode(response.body);
  } else if (response.statusCode == 500 ||
      (response.statusCode == 200 &&
          jsonDecode(response.body)["message"] == "Session expired")) {
    final success = await updateLoginData();
    if (success) {
      final response = await func();
      late final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success']) {
        return body;
      } else {
        throw SessionExpiredException();
      }
    } else {
      throw SessionExpiredException();
    }
  } else {
    sensLog.e(
        'withMaybeRetry: ${jsonDecode(response.body)["message"]} Failed to load with status code ${response.statusCode}. Custom Message: $errorMessage');
    throw Exception(
        'Failed to load with status code ${response.statusCode}. Custom Message: $errorMessage');
  }
}

/// Calls [func] and returns the html body if reuqest ws succsessful
///
/// If the request failes with an expired session, it tries to get a new cookie
/// with saved password and retries [func].
/// Throws [SessionExpiredException] if that's not possible
///
/// Remeber to obtain the cookie in [func] to always use the latest one.
Future<Document> withMaybeRetryHTML(Future<http.Response> Function() func,
    [String? errorMessage]) async {
  final response = await func();
  late final html = parse(response.body);
  if (response.statusCode == 200) {
    return html;
  } else if (response.statusCode == 500 &&
      response.body.toLowerCase().contains("session expired")) {
    final success = await updateLoginData();
    if (success) {
      final response = await func();
      late final html = parse(response.body);
      if (response.statusCode == 200) {
        return html;
      } else {
        throw SessionExpiredException();
      }
    } else {
      throw SessionExpiredException();
    }
  } else {
    throw Exception(
        'Failed to load with status code ${response.statusCode}. Custom Message: $errorMessage');
  }
}

/// läd Nami Dashboard Statistiken
Future<NamiStatsModel> loadNamiStats() async {
  String url = getNamiLUrl();
  String? cookie = getNamiApiCookie();
  sensLog.i('Request: Lade Stats');
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

Future<List<NamiGruppierungModel>> loadGruppierungen(
    {bool onlyStaemme = true}) async {
  String cookie = getNamiApiCookie();

  if (cookie == 'testLoginCookie') {
    return [NamiGruppierungModel(id: 1234, name: '1234 Test Gruppierung')];
  }

  sensLog.i('Request: Lade Gruppierung');

  late List<NamiGruppierungModel> gruppierungen;
  if (onlyStaemme) {
    gruppierungen = await loadOnlyStaemme();
  } else {
    gruppierungen = await loadAllGruppierung();
  }

  if (gruppierungen.isEmpty) {
    throw NoGruppierungException();
  }
  return gruppierungen;
}

Future<List<NamiGruppierungModel>> loadAllGruppierung() async {
  String url = getNamiLUrl();
  String path = getNamiPath();
  String fullUrl = '$url$path/gf/gruppierung';

  sensLog.i('Request: Lade Gruppierung');

  final body = await withMaybeRetry(() async {
    final cookie = getNamiApiCookie();
    return await http.get(Uri.parse(fullUrl), headers: {'Cookie': cookie});
  });

  List<NamiGruppierungModel> gruppierungen = (body['data'] as List<dynamic>)
      .map((e) => NamiGruppierungModel.fromJson(e as Map<String, dynamic>))
      .cast<NamiGruppierungModel>()
      .toList();

  return gruppierungen;
}

Future<List<NamiGruppierungModel>> loadOnlyStaemme(
    {int node = 1, String name = ''}) async {
  String url = getNamiLUrl();
  String path = getNamiPath();
  String fullUrl =
      '$url$path/gruppierungen/filtered-for-navigation/gruppierung/node/$node';

  sensLog.i('Request: Lade Gruppierung for node $node');
  final body = await withMaybeRetry(() async {
    final cookie = getNamiApiCookie();
    return await http.get(Uri.parse(fullUrl), headers: {'Cookie': cookie});
  });

  List<NamiGruppierungModel> gruppierungen = [];
  if (body['data'].isNotEmpty) {
    for (var item in body['data']) {
      gruppierungen.addAll(
          await loadOnlyStaemme(node: item['id'], name: item['descriptor']));
    }
  } else {
    gruppierungen.add(NamiGruppierungModel(id: node, name: name));
  }

  return gruppierungen;
}

Future<void> reloadMetadataFromServer() async {
  sensLog.i('Reloading metadata from server');
  var results = await Future.wait([
    getGeschlechtMeta(),
    getLandMeta(),
    getRegionMeta(),
    getBeitragsartenMeta(),
    getStaatsangehoerigkeitMeta(),
    getMitgliedstypMeta(),
    getKonfessionMeta(),
    getErsteTaetigkeitMeta(),
  ]);
  setMetaData(results[0], results[1], results[2], results[3], results[4],
      results[5], results[6], results[7]);
}

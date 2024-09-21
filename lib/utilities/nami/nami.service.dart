import 'dart:convert';
import 'package:html/dom.dart';
import 'package:html/parser.dart';
import 'package:http/http.dart' as http;
import 'package:nami/utilities/hive/settings.dart';
import 'package:nami/utilities/logger.dart';
import 'package:nami/utilities/nami/nami_login.service.dart';
import 'package:nami/utilities/types.dart';
import 'model/nami_stats.model.dart';
import 'package:nami/utilities/nami/nami_member_add_meta.dart';

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
  late final body = jsonDecode(response.body);
  if (response.statusCode == 200 && body['success']) {
    return body;
  } else if (response.statusCode == 200 &&
      body["message"] == "Session expired") {
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
        'withMaybeRetry: ${body["message"]} Failed to load with status code ${response.statusCode}. Custom Message: $errorMessage');
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

  sensLog.i('Request: Lade Gruppierung');
  final body = await withMaybeRetry(() async {
    final cookie = getNamiApiCookie();
    return await http.get(Uri.parse(fullUrl), headers: {'Cookie': cookie});
  });

// if body['data'].length is 0, user has no rights to see any gruppierung
  if (body['data'].length != 1) {
    sensLog.e('Failed to load gruppierung. Multiple or no gruppierungen found');
    throw Exception('Failed to load gruppierung');
  }

  int gruppierungId = body['data'][0]['id'];
  String gruppierungName = body['data'][0]['descriptor'];
  setGruppierungId(gruppierungId);
  setGruppierungName(gruppierungName);
  consLog.i('Gruppierung: $gruppierungName ($gruppierungId)');
  return gruppierungName;
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

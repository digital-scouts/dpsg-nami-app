import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:nami/utilities/hive/settings.dart';
import 'package:http/http.dart' as http;

String url = getNamiLUrl();
String path = getNamiPath();
int? gruppierungId = getGruppierungId();
String cookie = getNamiApiCookie();

Future<List<String>> getMetadata(String url) async {
  final headers = {'Cookie': cookie, 'Content-Type': 'application/json'};

  http.Response response;
  dynamic result;
  try {
    response = await http.get(Uri.parse(url), headers: headers);
    result = jsonDecode(response.body);
  } catch (e) {
    debugPrint(e.toString());
    throw Exception('Failed to load metadata: $url');
  }

  if (response.statusCode != 200 || !result['success']) {
    debugPrint(result.toString());
    throw Exception('Metadata result not valid: $url');
  }

  List<String> list = result['data'].map<String>((m) {
    return utf8.decode(m['descriptor'].codeUnits);
  }).toList();
  list.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return list;
}

Future<List<String>> getBeitragsartenMeta() async {
  String fullUrl =
      '$url/ica/rest/namiBeitrag/beitragsartmgl/gruppierung/$gruppierungId';
  List<String> meta = await getMetadata(fullUrl);

  RegExpMatch? match;
  List<String> newMeta = [];
  for (String e in meta) {
    match = RegExp(r'\((.*?)\)').firstMatch(e);
    newMeta.add(match!.group(1)!.replaceAll('VERBANDSBEITRAG', '').trim());
  }

  debugPrint(newMeta.toString());
  return newMeta;
}

Future<List<String>> getGeschlechtMeta() async {
  String fullUrl = '$url/ica/rest/baseadmin/geschlecht/';
  return await getMetadata(fullUrl);
}

Future<List<String>> getStaatsangehoerigkeitMeta() async {
  String fullUrl = '$url/ica/rest/baseadmin/staatsangehoerigkeit/';
  return await getMetadata(fullUrl);
}

Future<List<String>> getRegionMeta() async {
  String fullUrl = '$url/ica/rest/baseadmin/region/';
  return await getMetadata(fullUrl);
}

Future<List<String>> getMitgliedstypMeta() async {
  String fullUrl = '$url/ica/rest/nami/enum/mgltype/';
  return await getMetadata(fullUrl);
}

Future<List<String>> getLandMeta() async {
  String fullUrl = '$url/ica/rest/baseadmin/land/';
  return await getMetadata(fullUrl);
}

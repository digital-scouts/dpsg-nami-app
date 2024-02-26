import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:nami/utilities/hive/settings.dart';
import 'package:http/http.dart' as http;

String url = getNamiLUrl();
String path = getNamiPath();
int? gruppierungId = getGruppierungId();
String cookie = getNamiApiCookie();

Future<List<NamiMetaData>> getMetadata(String url) async {
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
  return result['data'].map<NamiMetaData>((m) {
    return NamiMetaData(m['descriptor'], m['id'].toString());
  }).toList();
}

Future<List<NamiMetaData>> getBeitragsartenMeta() async {
  String fullUrl =
      '$url/ica/rest/namiBeitrag/beitragsartmgl/gruppierung/$gruppierungId';
  List<NamiMetaData> meta = await getMetadata(fullUrl);

  RegExpMatch? match;
  List<NamiMetaData> newMeta = [];
  for (NamiMetaData e in meta) {
    match = RegExp(r'\((.*?)\)').firstMatch(e.descriptor);
    newMeta.add(NamiMetaData(
        match!.group(1)!.replaceAll('VERBANDSBEITRAG', '').trim(), e.id));
  }

  debugPrint(newMeta.toString());
  return newMeta;
}

Future<List<NamiMetaData>> getGeschlechtMeta() async {
  String fullUrl = '$url/ica/rest/baseadmin/geschlecht/';
  return await getMetadata(fullUrl);
}

Future<List<NamiMetaData>> getStaatsangehoerigkeitMeta() async {
  String fullUrl = '$url/ica/rest/baseadmin/staatsangehoerigkeit/';
  return await getMetadata(fullUrl);
}

Future<List<NamiMetaData>> getRegionMeta() async {
  String fullUrl = '$url/ica/rest/baseadmin/region/';
  return await getMetadata(fullUrl);
}

Future<List<NamiMetaData>> getMitgliedstypMeta() async {
  String fullUrl = '$url/ica/rest/nami/enum/mgltype/';
  return await getMetadata(fullUrl);
}

Future<List<NamiMetaData>> getLandMeta() async {
  String fullUrl = '$url/ica/rest/baseadmin/land/';
  return await getMetadata(fullUrl);
}

class NamiMetaData {
  String descriptor;
  String id;

  NamiMetaData(this.descriptor, this.id);

  @override
  String toString() {
    return '{descriptor: $descriptor, id: $id}';
  }
}

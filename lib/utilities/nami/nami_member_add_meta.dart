import 'dart:convert';

import 'package:nami/utilities/hive/settings.dart';
import 'package:http/http.dart' as http;
import 'package:nami/utilities/nami/nami.service.dart';

const String testCoockieName = 'testLoginCookie';

Future<List<String>> getMetadata(String url) async {
  final body = await withMaybeRetry(
    () async => await http.get(Uri.parse(url), headers: {
      'Cookie': getNamiApiCookie(),
      'Content-Type': 'application/json'
    }),
    'Failed to load metadata: $url',
  );

  List<String> list = body['data'].map<String>((m) {
    return utf8.decode(m['descriptor'].codeUnits);
  }).toList();
  list.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return list;
}

Future<List<String>> getBeitragsartenMeta() async {
  if (getNamiApiCookie() == testCoockieName) {
    return [
      'Familienermäßigt - Stiftungseuro',
      'Familienermäßigt',
      'Sozialermäßigt - Stiftungseuro',
      'Sozialermäßigt',
      'Voller Beitrag - Stiftungseuro',
      'Voller Beitrag'
    ];
  }
  String fullUrl =
      '${getNamiLUrl()}/ica/rest/namiBeitrag/beitragsartmgl/gruppierung/${getGruppierungId()}';
  List<String> meta = await getMetadata(fullUrl);

  RegExpMatch? match;
  List<String> newMeta = [];
  for (String e in meta) {
    match = RegExp(r'\((.*?)\)').firstMatch(e);
    newMeta.add(match!.group(1)!.replaceAll(' - VERBANDSBEITRAG', '').trim());
  }
  return newMeta;
}

Future<List<String>> getGeschlechtMeta() async {
  if (getNamiApiCookie() == testCoockieName) {
    return ['männlich', 'weiblich', 'divers', 'keine Angabe'];
  }
  String fullUrl = '${getNamiLUrl()}/ica/rest/baseadmin/geschlecht/';
  return await getMetadata(fullUrl);
}

Future<List<String>> getStaatsangehoerigkeitMeta() async {
  if (getNamiApiCookie() == testCoockieName) {
    return ['deutsch', 'Teststaatsangehörigkeit2', 'Teststaatsangehörigkeit3'];
  }
  String fullUrl = '${getNamiLUrl()}/ica/rest/baseadmin/staatsangehoerigkeit/';
  return await getMetadata(fullUrl);
}

Future<List<String>> getRegionMeta() async {
  if (getNamiApiCookie() == testCoockieName) {
    return ['Testregion1', 'Testregion2', 'Testregion3'];
  }
  String fullUrl = '${getNamiLUrl()}/ica/rest/baseadmin/region/';
  return await getMetadata(fullUrl);
}

Future<List<String>> getMitgliedstypMeta() async {
  if (getNamiApiCookie() == testCoockieName) {
    return ['Schnuppermitglied', 'Mitglied'];
  }
  String fullUrl = '${getNamiLUrl()}/ica/rest/nami/enum/mgltype/';
  return await getMetadata(fullUrl);
}

Future<List<String>> getErsteTaetigkeitMeta() async {
  if (getNamiApiCookie() == testCoockieName) {
    return ['LeiterIn', 'sonst. Mitglied', 'Mitglied'];
  }
  String fullUrl =
      '${getNamiLUrl()}/ica/rest//nami/taetigkeitaufgruppierung/filtered/gruppierung/erste-taetigkeit/gruppierung/${getGruppierungId()}';
  return await getMetadata(fullUrl);
}

Future<List<String>> getErsteUntergliederungMeta(String taetigkeit) async {
  if (getNamiApiCookie() == testCoockieName) {
    return ['LeiterIn', 'sonst. Mitglied', 'Mitglied'];
  }

  //find taetigkeitId
  // todo extra call einsparen
  String taetigkeitUrl =
      '${getNamiLUrl()}/ica/rest//nami/taetigkeitaufgruppierung/filtered/gruppierung/erste-taetigkeit/gruppierung/${getGruppierungId()}';
  final body = await withMaybeRetry(
    () async => await http.get(Uri.parse(taetigkeitUrl), headers: {
      'Cookie': getNamiApiCookie(),
      'Content-Type': 'application/json'
    }),
    'Failed to load metadata: $taetigkeitUrl',
  );

  String? taetigkeitId = body['data']
      .firstWhere(
        (item) => utf8.decode(item['descriptor'].codeUnits) == taetigkeit,
        orElse: () => null,
      )?['id']
      .toString();

  if (taetigkeitId == null) {
    throw Exception('TaetigkeitId not found for taetigkeit: $taetigkeit');
  }

  // load untergliederung
  String fullUrl =
      '${getNamiLUrl()}/ica/rest//nami/untergliederungauftaetigkeit/filtered/untergliederung/ersteTaetigkeit/$taetigkeitId';
  return await getMetadata(fullUrl);
}

Future<List<String>> getLandMeta() async {
  if (getNamiApiCookie() == testCoockieName) {
    return ['Deutschland', 'Testland2', 'Testland3'];
  }
  String fullUrl = '${getNamiLUrl()}/ica/rest/baseadmin/land/';
  return await getMetadata(fullUrl);
}

Future<List<String>> getKonfessionMeta() async {
  if (getNamiApiCookie() == testCoockieName) {
    return [
      'römisch-katholisch',
      'evangelisch / protestantisch',
      'sonstige' 'ohne Konfession'
    ];
  }
  String fullUrl = '${getNamiLUrl()}/ica/rest/baseadmin/konfession/';
  return await getMetadata(fullUrl);
}

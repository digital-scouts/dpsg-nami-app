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

Future<List<String>> getLandMeta() async {
  if (getNamiApiCookie() == testCoockieName) {
    return ['Deutschland', 'Testland2', 'Testland3'];
  }
  String fullUrl = '${getNamiLUrl()}/ica/rest/baseadmin/land/';
  return await getMetadata(fullUrl);
}

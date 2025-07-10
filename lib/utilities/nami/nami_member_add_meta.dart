import 'package:http/http.dart' as http;
import 'package:nami/utilities/app.state.dart';
import 'package:nami/utilities/hive/settings.dart';
import 'package:nami/utilities/nami/nami.service.dart';
import 'package:nami/utilities/types.dart';

const String testCoockieName = 'testLoginCookie';

Future<Map<String, String>> getMetadata(String url) async {
  return withMaybeRetry(
        () async => await http.get(
          Uri.parse(url),
          headers: {
            'Cookie': getNamiApiCookie(),
            'Content-Type': 'application/json',
          },
        ),
        'Failed to load metadata: $url',
      )
      .then<Map<String, String>>((body) {
        Map<String, String> map = {
          for (var m in body['data']) m['id'].toString(): m['descriptor'],
        };

        // Sortieren der Map nach den Schlüsseln (descriptor)
        var sortedMap = Map.fromEntries(
          map.entries.toList()..sort(
            (e1, e2) =>
                e1.value.toLowerCase().compareTo(e2.value.toLowerCase()),
          ),
        );

        return sortedMap;
      })
      .catchError((error) async {
        if (error is SessionExpiredException) {
          if (!await AppStateHandler().setReloginState()) {
            throw error;
          } else {
            return await getMetadata(url);
          }
        } else {
          throw error;
        }
      }, test: (error) => error is SessionExpiredException);
}

Future<Map<String, String>> getBeitragsartenMeta() async {
  if (getNamiApiCookie() == testCoockieName) {
    return {
      '1': 'Familienermäßigt - Stiftungseuro',
      '2': 'Familienermäßigt',
      '3': 'Sozialermäßigt - Stiftungseuro',
      '4': 'Sozialermäßigt',
      '5': 'Voller Beitrag - Stiftungseuro',
      '6': 'Voller Beitrag',
    };
  }
  String fullUrl =
      '${getNamiLUrl()}/ica/rest/namiBeitrag/beitragsartmgl/gruppierung/${getGruppierungId()}';
  Map<String, String> meta = await getMetadata(fullUrl);

  RegExpMatch? match;
  Map<String, String> newMeta = {};
  meta.forEach((key, value) {
    match = RegExp(r'\((.*?)\)').firstMatch(value);
    if (match != null) {
      newMeta[key] = match!
          .group(1)!
          .replaceAll(' - VERBANDSBEITRAG', '')
          .trim();
    }
  });
  return newMeta;
}

Future<Map<String, String>> getGeschlechtMeta() async {
  if (getNamiApiCookie() == testCoockieName) {
    return {
      '1': 'männlich',
      '2': 'weiblich',
      '3': 'divers',
      '4': 'keine Angabe',
    };
  }
  String fullUrl = '${getNamiLUrl()}/ica/rest/baseadmin/geschlecht/';
  return await getMetadata(fullUrl);
}

Future<Map<String, String>> getStaatsangehoerigkeitMeta() async {
  if (getNamiApiCookie() == testCoockieName) {
    return {
      '1054': 'deutsch',
      '2': 'Teststaatsangehörigkeit2',
      '3': 'Teststaatsangehörigkeit3',
    };
  }
  String fullUrl = '${getNamiLUrl()}/ica/rest/baseadmin/staatsangehoerigkeit/';
  return await getMetadata(fullUrl);
}

Future<Map<String, String>> getRegionMeta() async {
  if (getNamiApiCookie() == testCoockieName) {
    return {'1': 'Testregion1', '2': 'Testregion2', '3': 'Testregion3'};
  }
  String fullUrl = '${getNamiLUrl()}/ica/rest/baseadmin/region/';
  return await getMetadata(fullUrl);
}

Future<Map<String, String>> getMitgliedstypMeta() async {
  if (getNamiApiCookie() == testCoockieName) {
    return {'1': 'Schnuppermitglied', '2': 'Mitglied'};
  }
  String fullUrl = '${getNamiLUrl()}/ica/rest/nami/enum/mgltype/';
  return await getMetadata(fullUrl);
}

Future<Map<String, String>> getErsteTaetigkeitMeta() async {
  if (getNamiApiCookie() == testCoockieName) {
    return {'1': 'LeiterIn', '2': 'sonst. Mitglied', '3': 'Mitglied'};
  }

  String fullUrl =
      '${getNamiLUrl()}/ica/rest//nami/taetigkeitaufgruppierung/filtered/gruppierung/erste-taetigkeit/gruppierung/${getGruppierungId()}';
  return await getMetadata(fullUrl);
}

Future<Map<String, String>> getErsteUntergliederungMeta(
  String taetigkeitId,
) async {
  if (getNamiApiCookie() == testCoockieName) {
    return {'1': 'LeiterIn', '2': 'sonst. Mitglied', '3': 'Mitglied'};
  }

  // load untergliederung
  String fullUrl =
      '${getNamiLUrl()}/ica/rest//nami/untergliederungauftaetigkeit/filtered/untergliederung/ersteTaetigkeit/$taetigkeitId';
  return await getMetadata(fullUrl);
}

Future<Map<String, String>> getLandMeta() async {
  if (getNamiApiCookie() == testCoockieName) {
    return {'1': 'Deutschland', '2': 'Testland2', '3': 'Testland3'};
  }
  String fullUrl = '${getNamiLUrl()}/ica/rest/baseadmin/land/';
  return await getMetadata(fullUrl);
}

Future<Map<String, String>> getKonfessionMeta() async {
  if (getNamiApiCookie() == testCoockieName) {
    return {
      '1': 'römisch-katholisch',
      '2': 'evangelisch / protestantisch',
      '3': 'sonstige',
      '4': 'ohne Konfession',
    };
  }
  String fullUrl = '${getNamiLUrl()}/ica/rest/baseadmin/konfession/';
  return await getMetadata(fullUrl);
}

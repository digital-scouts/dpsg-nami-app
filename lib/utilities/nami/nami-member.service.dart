import 'package:nami/model/nami_member_details_model.dart';
import 'package:nami/utilities/constants.dart';
import 'package:nami/utilities/hive/mitglied.dart';
import 'package:hive/hive.dart';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:nami/utilities/hive/settings.dart';

Future<List<int>> loadMemberIds() async {
  String url = getNamiLUrl();
  String path = getNamiPath();
  int? gruppierung = getGruppierung();
  String cookie = getNamiApiCookie();
  String fullUrl =
      '$url$path/mitglied/filtered-for-navigation/gruppierung/gruppierung/$gruppierung/flist?_dc=1635173028278&page=1&start=0&limit=5000';
  final response =
      await http.get(Uri.parse(fullUrl), headers: {'Cookie': cookie});

  if (response.statusCode == 200) {
    List<int> memberIds = [];
    jsonDecode(response.body)['data']
        .forEach((item) => memberIds.add(item['id']));
    return memberIds;
  } else {
    throw Exception('Failed to load member List');
  }
}

Future<NamiMemberDetailsModel> loadMemberDetails(int id) async {
  String url = getNamiLUrl();
  String path = getNamiPath();
  int? gruppierung = getGruppierung();
  String cookie = getNamiApiCookie();
  String fullUrl =
      '$url$path/mitglied/filtered-for-navigation/gruppierung/gruppierung/$gruppierung/$id';
  final response =
      await http.get(Uri.parse(fullUrl), headers: {'Cookie': cookie});
  var source = json.decode(const Utf8Decoder().convert(response.bodyBytes));

  if (response.statusCode == 200) {
    return NamiMemberDetailsModel.fromJson(source['data']);
  } else {
    throw Exception('Failed to load album');
  }
}

syncMember() async {
  double memberSyncProgress = 0;
  Box<Mitglied> memberBox = Hive.box('members');
  List<int> mitgliedIds = await loadMemberIds();

  double syncProgressSteps = 1 / mitgliedIds.length;
  for (var mitgliedId in mitgliedIds) {
    storeMitgliedToHive(mitgliedId, memberBox)
        .then((value) => memberSyncProgress += syncProgressSteps)
        .then((value) => print(
            'Member $mitgliedId loaded: ${(memberSyncProgress * 100).round()}%'));
  }
}

Future<void> storeMitgliedToHive(
    int mitgliedId, Box<Mitglied> memberBox) async {
  NamiMemberDetailsModel rawMember = await loadMemberDetails(mitgliedId);
  Mitglied mitglied = Mitglied()
    ..vorname = rawMember.vorname
    ..nachname = rawMember.nachname
    ..geschlecht = rawMember.geschlecht
    ..geburtsDatum = rawMember.geburtsDatum
    ..stufe = StufenExtension.getValueFromString(rawMember.stufe ?? '').string()
    ..id = rawMember.id
    ..mitgliedsNummer = rawMember.mitgliedsNummer
    ..eintrittsdatum = rawMember.eintrittsdatum
    ..austrittsDatum = rawMember.austrittsDatum
    ..ort = rawMember.ort
    ..plz = rawMember.plz
    ..strasse = rawMember.strasse
    ..landId = rawMember.landId ?? 1
    ..email = rawMember.email
    ..emailVertretungsberechtigter = rawMember.emailVertretungsberechtigter
    ..telefon1 = rawMember.telefon1
    ..telefon2 = rawMember.telefon2
    ..telefon3 = rawMember.telefon3
    ..lastUpdated = rawMember.lastUpdated
    ..version = rawMember.version
    ..mglTypeId = rawMember.mglTypeId
    ..beitragsartId = rawMember.beitragsartId ?? 0
    ..status = rawMember.status;
  memberBox.put(mitgliedId, mitglied);
}

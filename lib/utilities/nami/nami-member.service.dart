import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nami/utilities/stufe.dart';
import 'package:nami/utilities/hive/mitglied.dart';
import 'package:hive/hive.dart';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:nami/utilities/hive/settings.dart';
import 'package:nami/utilities/hive/taetigkeit.dart';

import 'model/nami_member_details.model.dart';
import 'model/nami_taetigkeiten.model.dart';

ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? snackbar;

int getVersionOfMember(int id, List<Mitglied> mitglieder) {
  try {
    Mitglied mitglied = mitglieder.firstWhere((m) => m.id == id);
    return mitglied.version;
  } catch (e) {
    return 0;
  }
}

Future<List<int>> loadMemberIdsToUpdate(String url, String path,
    int gruppierung, String cookie, bool forceUpdate) async {
  String fullUrl =
      '$url$path/mitglied/filtered-for-navigation/gruppierung/gruppierung/$gruppierung/flist?_dc=1635173028278&page=1&start=0&limit=5000';
  debugPrint('Request: Lade Mitgliedsliste');
  final response =
      await http.get(Uri.parse(fullUrl), headers: {'Cookie': cookie});

  List<Mitglied> mitglieder =
      Hive.box<Mitglied>('members').values.toList().cast<Mitglied>();

  if (response.statusCode == 200 &&
      jsonDecode(response.body)['success'] == true) {
    List<int> memberIds = [];
    jsonDecode(response.body)['data'].forEach((item) => {
          if (forceUpdate ||
              getVersionOfMember(item['id'], mitglieder) !=
                  item['entries_version'])
            {
              debugPrint(
                  'Member ${item['vorname']} ${item['id']} needs to be updated. Old Version: ${getVersionOfMember(item['id'], mitglieder)} New Version: ${item['entries_version']}'),
              memberIds.add(item['id'])
            }
        });
    return memberIds;
  } else {
    debugPrint('Failed to load member List');
    debugPrintStack();
    return List.empty();
  }
}

Future<NamiMemberDetailsModel> loadMemberDetails(
    int id, String url, String path, int gruppierung, String cookie) async {
  String fullUrl =
      '$url$path/mitglied/filtered-for-navigation/gruppierung/gruppierung/$gruppierung/$id';
  debugPrint('Request: Lade Details eines Mitglieds');
  http.Response response;
  try {
    response = await http.get(Uri.parse(fullUrl), headers: {'Cookie': cookie});
  } catch (e) {
    debugPrint('Failed to load MemberDetails for $id');
    debugPrint(e.toString());
    throw Exception('Failed to load MemberDetails');
  }
  var source = json.decode(const Utf8Decoder().convert(response.bodyBytes));

  if (response.statusCode == 200) {
    NamiMemberDetailsModel member =
        NamiMemberDetailsModel.fromJson(source['data']);
    if (DateTime.now().difference(member.geburtsDatum).inDays > 36525) {
      debugPrint(
          'Geburtsdatum von $id (${member.vorname}) ist fehlerhaft: ${member.geburtsDatum}');
    }
    return member;
  } else {
    throw Exception('Failed to load MemberDetails');
  }
}

Future<List<NamiMemberTaetigkeitenModel>> loadMemberTaetigkeiten(
    int id, String url, String path, String cookie) async {
  String fullUrl =
      '$url$path/zugeordnete-taetigkeiten/filtered-for-navigation/gruppierung-mitglied/mitglied/$id/flist';
  debugPrint('Request: Lade Details eines Mitglieds');
  final response =
      await http.get(Uri.parse(fullUrl), headers: {'Cookie': cookie});
  var source = json.decode(const Utf8Decoder().convert(response.bodyBytes));

  if (response.statusCode == 200 && source['success']) {
    List<NamiMemberTaetigkeitenModel> taetigkeiten = [];
    for (Map<String, dynamic> item in source['data']) {
      taetigkeiten.add(NamiMemberTaetigkeitenModel.fromJson(item, true));
    }
    return taetigkeiten;
  } else {
    debugPrint('Failed to load Tätigkeiten');
    return [];
  }
}

Future<NamiMemberTaetigkeitenModel?> loadMemberTaetigkeit(int memberId,
    int taetigkeitId, String url, String path, String cookie) async {
  String fullUrl =
      '$url$path/zugeordnete-taetigkeiten/filtered-for-navigation/gruppierung-mitglied/mitglied/$memberId/$taetigkeitId';
  debugPrint('Request: Lade Taetigkeit $taetigkeitId von Mitglied $memberId');
  final response =
      await http.get(Uri.parse(fullUrl), headers: {'Cookie': cookie});
  var source = json.decode(const Utf8Decoder().convert(response.bodyBytes));

  if (response.statusCode == 200 && source['success']) {
    return NamiMemberTaetigkeitenModel.fromJson(source['data'], false);
  } else {
    debugPrint('Failed to load Tätigkeit');
    return null;
  }
}

Future<void> syncMember(ValueNotifier<double> memberAllProgressNotifier,
    ValueNotifier<bool?> memberOverviewProgressNotifier,
    {bool forceUpdate = false}) async {
  int gruppierung = getGruppierungId()!;
  String cookie = getNamiApiCookie();
  String url = getNamiLUrl();
  String path = getNamiPath();

  Box<Mitglied> memberBox = Hive.box('members');
  List<int> mitgliedIds;

  mitgliedIds =
      await loadMemberIdsToUpdate(url, path, gruppierung, cookie, forceUpdate);

  memberOverviewProgressNotifier.value = true;

  debugPrint('Starte Syncronisation der Mitgliedsdetails');

  var futures = <Future>[];

  for (var mitgliedId in mitgliedIds) {
    futures.add(storeMitgliedToHive(
        mitgliedId,
        memberBox,
        url,
        path,
        gruppierung,
        cookie,
        memberAllProgressNotifier,
        1 / mitgliedIds.length));
  }
  await Future.wait(futures);
  memberAllProgressNotifier.value = 1.0;
  setLastNamiSync(DateTime.now());
  debugPrint('Syncronisation der Mitgliedsdetails abgeschlossen');
}

Future<void> storeMitgliedToHive(
    int mitgliedId,
    Box<Mitglied> memberBox,
    String url,
    String path,
    int gruppierung,
    String cookie,
    ValueNotifier<double> memberAllProgressNotifier,
    double progressStep) async {
  NamiMemberDetailsModel rawMember;
  List<NamiMemberTaetigkeitenModel> rawTaetigkeiten;
  try {
    rawMember =
        await loadMemberDetails(mitgliedId, url, path, gruppierung, cookie);
  } catch (e) {
    debugPrint('Failed to load member $mitgliedId');
    debugPrint(e.toString());
    return;
  }
  try {
    rawTaetigkeiten =
        await loadMemberTaetigkeiten(mitgliedId, url, path, cookie);
  } catch (e) {
    debugPrint('Failed to load member tätigkeiten $mitgliedId');
    debugPrint(e.toString());
    rawTaetigkeiten = [];
  }

  List<Taetigkeit> taetigkeiten = [];
  for (NamiMemberTaetigkeitenModel item in rawTaetigkeiten) {
    taetigkeiten.add(Taetigkeit()
      ..id = item.id
      ..taetigkeit = item.taetigkeit
      ..aktivBis = item.aktivBis
      ..aktivVon = item.aktivVon
      ..anlagedatum = item.anlagedatum
      ..untergliederung = item.untergliederung
      ..gruppierung = item.gruppierung
      ..berechtigteGruppe = item.berechtigteGruppe
      ..berechtigteUntergruppen = item.berechtigteUntergruppen);
  }

  Mitglied mitglied = Mitglied()
    ..vorname = rawMember.vorname
    ..nachname = rawMember.nachname
    ..geschlecht = rawMember.geschlecht
    ..geburtsDatum = rawMember.geburtsDatum
    ..stufe =
        Stufe.getStufeByString(rawMember.stufe ?? StufeEnum.KEINE_STUFE.value)
            .name
            .value
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
    ..version = rawTaetigkeiten.isNotEmpty ? rawMember.version : 0
    ..mglTypeId = rawMember.mglTypeId
    ..beitragsartId = rawMember.beitragsartId ?? 0
    ..status = rawMember.status
    ..taetigkeiten = taetigkeiten;

  memberBox.put(mitgliedId, mitglied);
  memberAllProgressNotifier.value += progressStep;
}

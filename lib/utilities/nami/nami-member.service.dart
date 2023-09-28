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

Future<List<int>> loadMemberIdsToUpdate(
    String url, String path, int gruppierung, String cookie) async {
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
          if (getVersionOfMember(item['id'], mitglieder) !=
              item['entries_version'])
            {memberIds.add(item['id'])}
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
  final response =
      await http.get(Uri.parse(fullUrl), headers: {'Cookie': cookie});
  var source = json.decode(const Utf8Decoder().convert(response.bodyBytes));

  if (response.statusCode == 200) {
    return NamiMemberDetailsModel.fromJson(source['data']);
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
      taetigkeiten.add(NamiMemberTaetigkeitenModel.fromJson(item));
    }
    return taetigkeiten;
  } else {
    debugPrint('Failed to load Tätigkeiten');
    return [];
  }
}

showSyncStatus(String text, BuildContext context, {bool lastUpdate = false}) {
  Duration duration = const Duration(seconds: 10);
  if (snackbar != null) {
    snackbar!.close();
  }

  Timer(duration, () => snackbar = null);
  try {
    snackbar = ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(text),
      duration: duration,
      action: lastUpdate
          ? SnackBarAction(
              label: 'Ok',
              onPressed: () => {},
            )
          : null,
    ));
  } catch (e) {
    debugPrint('Cant show snackbar');
  }
}

Future<void> syncMember() async {
  int gruppierung = getGruppierung()!;
  String cookie = getNamiApiCookie();
  String url = getNamiLUrl();
  String path = getNamiPath();

  Box<Mitglied> memberBox = Hive.box('members');
  List<int> mitgliedIds =
      await loadMemberIdsToUpdate(url, path, gruppierung, cookie);
  debugPrint('Starte Syncronisation der Mitgliedsdetails');

  var futures = <Future>[];

  for (var mitgliedId in mitgliedIds) {
    futures.add(storeMitgliedToHive(
        mitgliedId, memberBox, url, path, gruppierung, cookie));
  }
  await Future.wait(futures);
  debugPrint('Syncronisation der Mitgliedsdetails abgeschlossen');
}

Future<void> storeMitgliedToHive(int mitgliedId, Box<Mitglied> memberBox,
    String url, String path, int gruppierung, String cookie) async {
  NamiMemberDetailsModel rawMember =
      await loadMemberDetails(mitgliedId, url, path, gruppierung, cookie);
  List<NamiMemberTaetigkeitenModel> rawTaetigkeiten =
      await loadMemberTaetigkeiten(mitgliedId, url, path, cookie);

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
    ..stufe = Stufe.getStufeByString(rawMember.stufe ?? 'keine Stufe').name
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
    ..status = rawMember.status
    ..taetigkeiten = taetigkeiten;
  memberBox.put(mitgliedId, mitglied);
}

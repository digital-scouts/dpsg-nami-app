import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nami/utilities/constants.dart';
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

Future<List<int>> loadMemberIdsToUpdate() async {
  String url = getNamiLUrl();
  String path = getNamiPath();
  int? gruppierung = getGruppierung();
  String cookie = getNamiApiCookie();
  String fullUrl =
      '$url$path/mitglied/filtered-for-navigation/gruppierung/gruppierung/$gruppierung/flist?_dc=1635173028278&page=1&start=0&limit=5000';
  debugPrint('Request: Lade Mitgliedsliste');
  final response =
      await http.get(Uri.parse(fullUrl), headers: {'Cookie': cookie});

  List<Mitglied> mitglieder =
      Hive.box<Mitglied>('members').values.toList().cast<Mitglied>();

  if (response.statusCode == 200) {
    List<int> memberIds = [];
    jsonDecode(response.body)['data'].forEach((item) => {
          if (getVersionOfMember(item['id'], mitglieder) !=
              item['entries_version'])
            {memberIds.add(item['id'])}
        });
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

Future<List<NamiMemberTaetigkeitenModel>> loadMemberTaetigkeiten(int id) async {
  String url = getNamiLUrl();
  String path = getNamiPath();
  String cookie = getNamiApiCookie();

  String fullUrl =
      '$url$path/zugeordnete-taetigkeiten/filtered-for-navigation/gruppierung-mitglied/mitglied/$id/flist';
  debugPrint('Request: Lade Details eines Mitglieds');
  final response =
      await http.get(Uri.parse(fullUrl), headers: {'Cookie': cookie});
  var source = json.decode(const Utf8Decoder().convert(response.bodyBytes));

  if (response.statusCode == 200) {
    List<NamiMemberTaetigkeitenModel> taetigkeiten = [];
    for (Map<String, dynamic> item in source['data']) {
      taetigkeiten.add(NamiMemberTaetigkeitenModel.fromJson(item));
    }
    return taetigkeiten;
  } else {
    throw Exception('Failed to load Tätigkeiten');
  }
}

showSyncStatus(String text, BuildContext context, {bool lastUpdate = false}) {
  Duration duration = const Duration(seconds: 10);
  if (snackbar != null) {
    snackbar!.close();
  }

  Timer(duration, () => snackbar = null);
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
}

syncMember(BuildContext context) async {
  double memberSyncProgress = 0;
  Box<Mitglied> memberBox = Hive.box('members');
  List<int> mitgliedIds = await loadMemberIdsToUpdate();
  showSyncStatus("Sycronisation 0/2", context);
  debugPrint('Starte Syncronisation der Mitgliedsdetails');

  double syncProgressSteps = 1 / mitgliedIds.length;
  for (var mitgliedId in mitgliedIds) {
    storeMitgliedToHive(mitgliedId, memberBox)
        .then((value) => {memberSyncProgress += syncProgressSteps})
        .then((value) => {
              debugPrint('Sync: ' + memberSyncProgress.toString()),
              if (memberSyncProgress >= 1.0)
                {showSyncStatus("Sycronisation 1/2", context, lastUpdate: true)}
            });
  }
  if (mitgliedIds.isEmpty) {
    showSyncStatus("Alle Daten sind aktuell", context, lastUpdate: true);
  }
  debugPrint('Syncronisation der Mitgliedsdetails abgeschlossen');
}

Future<void> storeMitgliedToHive(
    int mitgliedId, Box<Mitglied> memberBox) async {
  NamiMemberDetailsModel rawMember = await loadMemberDetails(mitgliedId);
  List<NamiMemberTaetigkeitenModel> rawTaetigkeiten =
      await loadMemberTaetigkeiten(mitgliedId);

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
    ..status = rawMember.status
    ..taetigkeit = taetigkeiten;
  memberBox.put(mitgliedId, mitglied);
}

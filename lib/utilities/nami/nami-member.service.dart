import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nami/utilities/logger.dart';
import 'package:nami/utilities/nami/nami-member-fake.service.dart';
import 'package:nami/utilities/nami/nami.service.dart';
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

int _getVersionOfMember(int id, List<Mitglied> mitglieder) {
  try {
    Mitglied mitglied = mitglieder.firstWhere((m) => m.id == id);
    return mitglied.version;
  } catch (e) {
    return 0;
  }
}

Future<List<int>> _loadMemberIdsToUpdate(
    String url, String path, int gruppierung, bool forceUpdate) async {
  String fullUrl =
      '$url$path/mitglied/filtered-for-navigation/gruppierung/gruppierung/$gruppierung/flist?_dc=1635173028278&page=1&start=0&limit=5000';
  sensLog.i('Request: Lade Mitgliedsliste');
  final body = await withMaybeRetry(() async {
    final cookie = getNamiApiCookie();
    return await http.get(Uri.parse(fullUrl), headers: {'Cookie': cookie});
  });

  List<Mitglied> mitglieder =
      Hive.box<Mitglied>('members').values.toList().cast<Mitglied>();
  List<int> memberIds = [];
  body['data'].forEach((item) {
    if (forceUpdate ||
        _getVersionOfMember(item['id'], mitglieder) !=
            item['entries_version']) {
      consLog.i(
          'Member ${item['entries_vorname']} ${item['id']} needs to be updated. Old Version: ${_getVersionOfMember(item['id'], mitglieder)} New Version: ${item['entries_version']}');
      fileLog.i(
          'Member ${sensId(item['id'])} needs to be updated. Old Version: ${_getVersionOfMember(item['id'], mitglieder)} New Version: ${item['entries_version']}');
      memberIds.add(item['id']);
    } else {
      consLog.i(
          'Member ${item['entries_vorname']} ${item['id']} is up to date. Version: ${item['entries_version']}');
      fileLog.i(
          'Member ${sensId(item['id'])} is up to date. Version: ${item['entries_version']}');
    }
  });
  return memberIds;
}

Future<NamiMemberDetailsModel> _loadMemberDetails(
    int id, String url, String path, int gruppierung, String cookie) async {
  String fullUrl =
      '$url$path/mitglied/filtered-for-navigation/gruppierung/gruppierung/$gruppierung/$id';
  sensLog.i('Request: Load MemberDetails for ${sensId(id)}');
  final http.Response response;
  try {
    response = await http.get(Uri.parse(fullUrl), headers: {'Cookie': cookie});
  } catch (e, st) {
    sensLog.e('Failed to load MemberDetails for ${sensId(id)}',
        error: e, stackTrace: st);
    throw Exception('Failed to load MemberDetails');
  }
  final source = json.decode(const Utf8Decoder().convert(response.bodyBytes));

  if (response.statusCode == 200) {
    NamiMemberDetailsModel member =
        NamiMemberDetailsModel.fromJson(source['data']);
    if (DateTime.now().difference(member.geburtsDatum).inDays > 36525) {
      sensLog.w(
          'Geburtsdatum von ${sensId(id)} ist fehlerhaft: ${member.geburtsDatum}. Versuche es erneut.');
      return await _loadMemberDetails(id, url, path, gruppierung, cookie);
    }
    sensLog.t('Response: Loaded MemberDetails for ${sensMember(member)}');
    return member;
  } else {
    sensLog.e(
        'Failed to load MemberDetails for ${sensId(id)}: wrong status code: ${response.statusCode}');
    throw Exception('Failed to load MemberDetails');
  }
}

Future<List<NamiMemberTaetigkeitenModel>> _loadMemberTaetigkeiten(
    int id, String url, String path, String cookie) async {
  String fullUrl =
      '$url$path/zugeordnete-taetigkeiten/filtered-for-navigation/gruppierung-mitglied/mitglied/$id/flist';
  sensLog.i('Request: Lade Details eines Mitglieds');
  final response =
      await http.get(Uri.parse(fullUrl), headers: {'Cookie': cookie});
  final source = json.decode(const Utf8Decoder().convert(response.bodyBytes));

  if (response.statusCode == 200 && source['success']) {
    List<NamiMemberTaetigkeitenModel> taetigkeiten = [];
    for (Map<String, dynamic> item in source['data']) {
      final taetigkeit = NamiMemberTaetigkeitenModel.fromJson(item, true);
      sensLog.t(
          'Taetigkeit = ${taetigkeit.taetigkeit}, untergliederung = ${taetigkeit.untergliederung}, isActive = ${taetigkeit.aktivBis?.isAfter(DateTime.now()) ?? false} von ${sensId(id)}');
      taetigkeiten.add(taetigkeit);
    }
    sensLog.i('Response: Loaded Tätigkeiten for ${sensId(id)}');
    return taetigkeiten;
  } else {
    sensLog.e('Failed to load Tätigkeiten for ${sensId(id)}');
    return [];
  }
}

// ignore: unused_element
Future<NamiMemberTaetigkeitenModel?> _loadMemberTaetigkeit(int memberId,
    int taetigkeitId, String url, String path, String cookie) async {
  String fullUrl =
      '$url$path/zugeordnete-taetigkeiten/filtered-for-navigation/gruppierung-mitglied/mitglied/$memberId/$taetigkeitId';
  sensLog.i(
      'Request: Lade Taetigkeit ${sensId(taetigkeitId)} von Mitglied ${sensId(memberId)}');
  final response =
      await http.get(Uri.parse(fullUrl), headers: {'Cookie': cookie});
  var source = json.decode(const Utf8Decoder().convert(response.bodyBytes));

  if (response.statusCode == 200 && source['success']) {
    return NamiMemberTaetigkeitenModel.fromJson(source['data'], false);
  } else {
    sensLog.e(
        'Failed to load Tätigkeit ${sensId(taetigkeitId)}: wrong status code: ${response.statusCode}');
    return null;
  }
}

Future<void> syncMember(
  ValueNotifier<double> memberAllProgressNotifier,
  ValueNotifier<bool?> memberOverviewProgressNotifier, {
  bool forceUpdate = false,
}) async {
  setLastNamiSyncTry(DateTime.now());
  int gruppierung = getGruppierungId()!;
  String cookie = getNamiApiCookie();
  String url = getNamiLUrl();
  String path = getNamiPath();

  Box<Mitglied> memberBox = Hive.box('members');

  if (cookie == 'testLoginCookie') {
    await storeFakeSetOfMemberInHive(
        memberBox, memberOverviewProgressNotifier, memberAllProgressNotifier);
    setLastNamiSync(DateTime.now());
    return;
  }

  List<int> mitgliedIds;
  try {
    mitgliedIds =
        await _loadMemberIdsToUpdate(url, path, gruppierung, forceUpdate);
  } catch (e) {
    memberOverviewProgressNotifier.value = false;
    rethrow;
  }

  /// Update cookie because it could be new after relogin
  cookie = getNamiApiCookie();

  memberOverviewProgressNotifier.value = true;
  sensLog.i('Starte Syncronisation der Mitgliedsdetails');
  var futures = <Future>[];

  for (var mitgliedId in mitgliedIds) {
    futures.add(_storeMitgliedToHive(
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
  sensLog.i('Syncronisation der Mitgliedsdetails abgeschlossen');
}

Future<void> _storeMitgliedToHive(
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
        await _loadMemberDetails(mitgliedId, url, path, gruppierung, cookie);
  } catch (e, st) {
    sensLog.e('Failed to load member ${sensId(mitgliedId)}',
        error: e, stackTrace: st);
    return;
  }
  try {
    rawTaetigkeiten =
        await _loadMemberTaetigkeiten(mitgliedId, url, path, cookie);
  } catch (e, st) {
    sensLog.e('Failed to load member tätigkeiten ${sensId(mitgliedId)}',
        error: e, stackTrace: st);
    rawTaetigkeiten = [];
  }

  List<Taetigkeit> taetigkeiten = [];
  for (NamiMemberTaetigkeitenModel item in rawTaetigkeiten) {
    taetigkeiten.add(Taetigkeit()
      ..id = item.id
      ..taetigkeit =
          item.taetigkeit.replaceAll(RegExp(r'^[€\-x ]* '), '').split(' (')[0]
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
        Stufe.getStufeByString(rawMember.stufe ?? Stufe.KEINE_STUFE.display)
            .display
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

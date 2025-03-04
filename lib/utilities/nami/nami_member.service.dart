import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:hive_ce/hive.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:nami/utilities/dataChanges.service.dart';
import 'package:nami/utilities/hive/ausbildung.dart';
import 'package:nami/utilities/hive/dataChanges.dart';
import 'package:nami/utilities/hive/mitglied.dart';
import 'package:nami/utilities/hive/settings.dart';
import 'package:nami/utilities/hive/taetigkeit.dart';
import 'package:nami/utilities/logger.dart';
import 'package:nami/utilities/nami/model/nami_gruppierung.model.dart';
import 'package:nami/utilities/nami/model/nami_member_ausbildung_model.dart';
import 'package:nami/utilities/nami/nami.service.dart';
import 'package:nami/utilities/nami/nami_member_fake.service.dart';
import 'package:nami/utilities/nami/nami_rechte.dart';

import 'model/nami_member_details.model.dart';
import 'model/nami_taetigkeiten.model.dart';

int _getVersionOfMember(int id, List<Mitglied> mitglieder) {
  try {
    Mitglied mitglied = mitglieder.firstWhere((m) => m.id == id);
    return mitglied.version;
  } catch (e) {
    return 0;
  }
}

Future<Map<int, int>> _loadMemberIdsToUpdate(
    String url,
    String path,
    int gruppierung,
    bool forceUpdate,
    DataChangesService dataChangesService) async {
  String fullUrl =
      '$url$path/mitglied/filtered-for-navigation/gruppierung/gruppierung/$gruppierung/flist?_dc=1635173028278&page=1&start=0&limit=5000';
  sensLog.i('Request: Lade Mitgliedsliste');
  final body = await withMaybeRetry(() async {
    final cookie = getNamiApiCookie();
    return await http.get(Uri.parse(fullUrl), headers: {'Cookie': cookie});
  });

  final box = Hive.box<Mitglied>('members');
  List<Mitglied> mitglieder = box.values.toList().cast<Mitglied>();
  Map<int, int> memberIds = {};
  Set<int> loadedMemberIds = {};

  body['data'].forEach((item) {
    loadedMemberIds.add(item['id']);
    if (forceUpdate ||
        _getVersionOfMember(item['id'], mitglieder) !=
            item['entries_version']) {
      consLog.i(
          'Member ${item['entries_vorname']} ${item['id']} needs to be updated. Old Version: ${_getVersionOfMember(item['id'], mitglieder)} New Version: ${item['entries_version']}');
      fileLog.i(
          'Member ${sensId(item['id'])} needs to be updated. Old Version: ${_getVersionOfMember(item['id'], mitglieder)} New Version: ${item['entries_version']}');
      memberIds[item['id']] = item['entries_mitgliedsNummer'];
    } else {
      consLog.i(
          'Member ${item['entries_vorname']} ${item['id']} is up to date. Version: ${item['entries_version']}');
      fileLog.i(
          'Member ${sensId(item['id'])} is up to date. Version: ${item['entries_version']}');
    }
  });

  // Entferne gelöschte Mitglieder
  for (var mitglied in mitglieder) {
    if (!loadedMemberIds.contains(mitglied.id)) {
      consLog.i(
          'Member ${mitglied.vorname} ${mitglied.id} wird aus Hive entfernt.');
      fileLog.i('Member ${sensId(mitglied.id!)} wird aus Hive entfernt.');
      dataChangesService.addDataChangeEntry(mitglied.id!,
          action: DataChangeAction.delete);
      await box.delete(mitglied.id);
    }
  }
  return memberIds;
}

Future<NamiMemberDetailsModel> _loadMemberDetails(
    int id, String url, String path, int gruppierung, String cookie,
    {int retry = 0}) async {
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

  if (response.statusCode == 200 && source['success']) {
    NamiMemberDetailsModel member =
        NamiMemberDetailsModel.fromJson(source['data']);
    if (DateTime.now().difference(member.geburtsDatum).inDays > 36525) {
      sensLog.w(
          'Geburtsdatum von ${sensId(id)} ist fehlerhaft: ${member.geburtsDatum}. Versuche es erneut. Retry: $retry');
      if (retry <= 3) {
        return await _loadMemberDetails(id, url, path, gruppierung, cookie,
            retry: retry + 1);
      }
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
  sensLog.i('Request: Taetigkeiten for ${sensId(id)}');
  final response =
      await http.get(Uri.parse(fullUrl), headers: {'Cookie': cookie});
  final source = json.decode(const Utf8Decoder().convert(response.bodyBytes));

  sensLog.t('Response: Taetigkeiten for ${sensId(id)}');

  if (response.statusCode == 200 && source['success']) {
    List<NamiMemberTaetigkeitenModel> taetigkeiten = [];
    for (Map<String, dynamic> item in source['data']) {
      final taetigkeit = NamiMemberTaetigkeitenModel.fromJson(item, true);
      sensLog.t(
          'Taetigkeit = ${taetigkeit.taetigkeit}, untergliederung = ${taetigkeit.untergliederung}, isActive = ${taetigkeit.aktivBis?.isAfter(DateTime.now()) ?? false} von ${sensId(id)}');
      taetigkeiten.add(taetigkeit);
    }
    sensLog.t('Finalized Taetigkeiten for ${sensId(id)}');
    return taetigkeiten;
  } else {
    sensLog.e('Failed to load Taetigkeiten for ${sensId(id)}');
    return [];
  }
}

Future<List<NamiMemberAusbildungModel>> _loadMemberAusbildungen(
    int id, String url, String path, String cookie) async {
  String fullUrl =
      '$url$path/mitglied-ausbildung/filtered-for-navigation/mitglied/mitglied/$id/flist';
  sensLog.i('Request: Ausbildungen for ${sensId(id)}');
  final response =
      await http.get(Uri.parse(fullUrl), headers: {'Cookie': cookie});
  final source = json.decode(const Utf8Decoder()
      .convert(response.bodyBytes)
      .replaceAll("&#34;", '\\"'));

  if (response.statusCode == 200 && source['success']) {
    List<NamiMemberAusbildungModel> ausbildungen = [];
    for (Map<String, dynamic> item in source['data']) {
      final ausbildung = NamiMemberAusbildungModel.fromJson(item);
      ausbildungen.add(ausbildung);
    }
    sensLog.i('Response: Loaded Ausbildungen for ${sensId(id)}');
    return ausbildungen;
  } else {
    sensLog.e('Failed to load Ausbildungen for ${sensId(id)}');
    return [];
  }
}

Future<Mitglied> updateOneMember(int memberId) async {
  String cookie = getNamiApiCookie();
  String url = getNamiLUrl();
  String path = getNamiPath();

  int gruppierung = getGruppierungId()!;

  if (cookie == 'testLoginCookie') {
    return createMemberDefaultPfadfinder(13, memberId);
  }

  Box<Mitglied> memberBox = Hive.box('members');

  final member = await _storeMitgliedToHive(memberId, memberBox, url, path,
      gruppierung, cookie, DataChangesService(), ValueNotifier<double>(0), 1);
  if (member == null) {
    throw Exception('Failed to load details of current user');
  }
  return member;
}

Future<int?> findUserId(int memberId, Map<int, int> mitgliedIds,
    DataChangesService dataChangesService) async {
  String url = getNamiLUrl();
  String path = getNamiPath();

  int? loggedInUserId = getLoggedInUserId();
  if (loggedInUserId == null) {
    if (mitgliedIds.containsKey(memberId)) {
      loggedInUserId = memberId;
      setLoggedInUserId(loggedInUserId);
    } else if (mitgliedIds.containsValue(memberId)) {
      loggedInUserId =
          mitgliedIds.keys.firstWhere((key) => mitgliedIds[key] == memberId);
      setLoggedInUserId(loggedInUserId);
    }
    if (loggedInUserId == null) {
      List<NamiGruppierungModel> gruppierungen =
          await loadGruppierungen(onlyStaemme: false);
      for (NamiGruppierungModel gruppierung in gruppierungen) {
        mitgliedIds = await _loadMemberIdsToUpdate(
            url, path, gruppierung.id, true, dataChangesService);
        if (mitgliedIds.containsKey(memberId)) {
          loggedInUserId = memberId;
          setLoggedInUserId(loggedInUserId);
          break;
        } else if (mitgliedIds.containsValue(memberId)) {
          loggedInUserId = mitgliedIds.keys
              .firstWhere((key) => mitgliedIds[key] == memberId);
          setLoggedInUserId(loggedInUserId);
          break;
        }
      }
    }
  }
  return loggedInUserId;
}

/// Syncronizes all members from Nami with the local Hive database.
/// If [forceUpdate] is set to true, all members will be updated.
/// Otherwise only members with a newer version will be updated.
/// The progress is reported via the [rechteProgressNotifier], [memberAllProgressNotifier] and [memberOverviewProgressNotifier].
/// A List of updated Member (id) is returned.
Future<void> syncMembers(
  ValueNotifier<double> memberAllProgressNotifier,
  ValueNotifier<bool?> memberOverviewProgressNotifier,
  ValueNotifier<List<AllowedFeatures>> rechteProgressNotifier,
  DataChangesService dataChangesService, {
  bool forceUpdate = false,
}) async {
  setLastNamiSyncTry(DateTime.now());

  int gruppierung = getGruppierungId()!;
  String cookie = getNamiApiCookie();
  String url = getNamiLUrl();
  String path = getNamiPath();
  int memberId = getNamiLoginId()!;

  Box<Mitglied> memberBox = Hive.box('members');

  if (cookie == 'testLoginCookie') {
    await storeFakeSetOfMemberInHive(
        memberBox, memberOverviewProgressNotifier, memberAllProgressNotifier);
    setRechte(await loadRechte(0));
    rechteProgressNotifier.value = getAllowedFeatures();

    setLastNamiSync(DateTime.now());
    return;
  }

  Map<int, int> mitgliedIds = {};
  try {
    mitgliedIds.addAll(await _loadMemberIdsToUpdate(
        url, path, gruppierung, forceUpdate, dataChangesService));
  } catch (e) {
    memberOverviewProgressNotifier.value = false;
    rethrow;
  }

  /// Update cookie because it could be new after relogin
  cookie = getNamiApiCookie();

  int? loggedInUserId =
      await findUserId(memberId, mitgliedIds, dataChangesService);
  if (loggedInUserId == null) {
    memberOverviewProgressNotifier.value = false;
    return;
  }
  final rechte = await loadRechte(loggedInUserId);
  setRechte(rechte);
  rechteProgressNotifier.value = getAllowedFeatures();

  memberOverviewProgressNotifier.value = true;
  sensLog.i('Starte Syncronisation der Mitgliedsdetails');
  final futures = <Future>[];

  for (var mitgliedId in mitgliedIds.keys) {
    futures.add(_storeMitgliedToHive(
      mitgliedId,
      memberBox,
      url,
      path,
      gruppierung,
      cookie,
      dataChangesService,
      memberAllProgressNotifier,
      1 / mitgliedIds.length,
    ));
  }
  await Future.wait(futures);
  memberAllProgressNotifier.value = 1.0;

  setLastNamiSync(DateTime.now());
  sensLog.i('Syncronisation der Mitgliedsdetails abgeschlossen');
}

Future<void> endMembership(int memberId, DateTime endDate) async {
  String cookie = getNamiApiCookie();
  String url = getNamiLUrl();
  String path = getNamiPath();
  Box<Mitglied> memberBox = Hive.box('members');

  if (cookie == 'testLoginCookie') {
    return Future.value();
  }

  final headers = {
    'Cookie': cookie,
    'Content-Type': 'application/x-www-form-urlencoded'
  };

  // body is x-www-form-urlencoded
  final body = {
    'id': memberId.toString(),
    'isConfirmed': 'true',
    'beendenZumDatum': '${DateFormat('yyyy-MM-dd').format(endDate)} 00:00:00'
  };

  String fullUrl =
      '$url$path/mitglied/filtered-for-navigation/mglschaft-beenden';
  sensLog.i('Request: Mitgliedschaft beenden für ${sensId(memberId)}');

  final response = await withMaybeRetry(() async {
    return await http.post(Uri.parse(fullUrl), headers: headers, body: body);
  });

  if (!response.containsKey('success') || response['success'] != true) {
    sensLog.e('Failed to end membership for ${sensId(memberId)}');
    throw Exception('Failed to end membership');
  }
  memberBox.delete(memberId);
  sensLog.i('Success: Mitgliedschaft beendet für ${sensId(memberId)}');
}

Future<Mitglied?> _storeMitgliedToHive(
    int mitgliedId,
    Box<Mitglied> memberBox,
    String url,
    String path,
    int gruppierung,
    String cookie,
    DataChangesService dataChangesService,
    ValueNotifier<double> memberAllProgressNotifier,
    double progressStep) async {
  NamiMemberDetailsModel rawMember;
  List<NamiMemberTaetigkeitenModel> rawTaetigkeiten;
  List<NamiMemberAusbildungModel> rawAusbildungen = [];
  try {
    rawMember =
        await _loadMemberDetails(mitgliedId, url, path, gruppierung, cookie);
  } catch (e, st) {
    sensLog.e('Failed to load member ${sensId(mitgliedId)}',
        error: e, stackTrace: st);
    return null;
  }
  try {
    rawTaetigkeiten =
        await _loadMemberTaetigkeiten(mitgliedId, url, path, cookie);
  } catch (e, st) {
    sensLog.e('Failed to load member tätigkeiten ${sensId(mitgliedId)}',
        error: e, stackTrace: st);
    rawTaetigkeiten = [];
  }

  if (getAllowedFeatures().contains(AllowedFeatures.ausbildungRead) ||
      mitgliedId == getNamiLoginId()) {
    try {
      rawAusbildungen =
          await _loadMemberAusbildungen(mitgliedId, url, path, cookie);
    } catch (e, st) {
      sensLog.e('Failed to load member ausbildungen ${sensId(mitgliedId)}',
          error: e, stackTrace: st);
    }
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

  List<Ausbildung> ausbildungen = [];
  for (final item in rawAusbildungen) {
    ausbildungen.add(
      Ausbildung()
        ..id = item.id
        ..name = item.name
        ..veranstalter = item.veranstalter
        ..datum = item.datum
        ..baustein = item.baustein,
    );
  }

  Mitglied mitglied = Mitglied()
    ..vorname = rawMember.vorname
    ..nachname = rawMember.nachname
    ..spitzname = rawMember.spitzname
    ..geschlechtId = rawMember.geschlechtId
    ..geburtsDatum = rawMember.geburtsDatum
    ..id = rawMember.id
    ..mitgliedsNummer = rawMember.mitgliedsNummer ?? 0
    ..eintrittsdatum = rawMember.eintrittsdatum.isBefore(DateTime(1950))
        ? getEarliestStartDate(taetigkeiten)
        : rawMember.eintrittsdatum
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
    ..lastUpdated = rawMember.lastUpdated ?? DateTime.now()
    ..version = rawTaetigkeiten.isNotEmpty ? rawMember.version : 0
    ..mglTypeId = rawMember.mglTypeId ?? 'NICHT_MITGLIED'
    ..beitragsartId = rawMember.beitragsartId ?? 0
    ..status = rawMember.status ?? ''
    ..taetigkeiten = taetigkeiten
    ..ausbildungen = ausbildungen
    ..staatssangehaerigkeitId = rawMember.staatsangehoerigkeitId
    ..konfessionId = rawMember.konfessionId.toString()
    ..mitgliedszeitschrift = rawMember.zeitschriftenversand
    ..datenweiterverwendung = rawMember.wiederverwendenFlag;

  // Compare previous member data with new data, List of changed fields
  final previousMemberData = memberBox.get(mitgliedId);
  if (previousMemberData == null) {
    sensLog.i('No previous data found for ${sensId(mitgliedId)}');
    await dataChangesService.addDataChangeEntry(mitgliedId,
        action: DataChangeAction.create);
  } else {
    List<String> changedFields =
        _getChangedFields(previousMemberData, mitglied);
    sensLog.i('Changed fields for ${sensId(mitgliedId)}: $changedFields');
    await dataChangesService.addDataChangeEntry(mitgliedId,
        changedFields: changedFields, action: DataChangeAction.update);
  }

  memberBox.put(mitgliedId, mitglied);
  memberAllProgressNotifier.value += progressStep;
  return mitglied;
}

List<String> _getChangedFields(
    Mitglied? previousMemberData, Mitglied mitglied) {
  final List<String> ignoreFields = ['lastUpdated', 'version'];
  List<String> changedFields = [];
  if (previousMemberData != null) {
    final previousMap = previousMemberData.toJson();
    final currentMap = mitglied.toJson();

    previousMap.forEach((key, previousValue) {
      if (ignoreFields.contains(key)) {
        return;
      }
      final currentValue = currentMap[key];
      if (previousValue != currentValue) {
        changedFields.add(key);
      }
    });
  }
  return changedFields;
}

DateTime getEarliestStartDate(List<Taetigkeit> taetigkeiten) {
  if (taetigkeiten.isEmpty) {
    return DateTime.now(); // Fallback, falls keine Tätigkeiten vorhanden sind
  }
  taetigkeiten.sort((a, b) => a.aktivVon.compareTo(b.aktivVon));
  return taetigkeiten.first.aktivVon;
}

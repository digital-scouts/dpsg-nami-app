import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:nami/utilities/hive/mitglied.dart';
import 'package:nami/utilities/hive/taetigkeit.dart';
import 'package:nami/utilities/stufe.dart';

Future<void> storeFakeSetOfMemberInHive(
    Box<Mitglied> box,
    ValueNotifier<bool?> memberOverviewProgressNotifier,
    ValueNotifier<double> memberAllProgressNotifier) async {
  await fakeLoading(memberOverviewProgressNotifier, memberAllProgressNotifier);

  for (var element in members) {
    Mitglied member =
        createFakeMember(element['member'], element['taetigkeiten']);
    box.put(member.id, member);
  }
}

Mitglied createFakeMember(dynamic rawMember, dynamic rawTaetigkeiten) {
  List<Taetigkeit> taetigkeiten = [];
  for (dynamic item in rawTaetigkeiten) {
    taetigkeiten.add(Taetigkeit()
      ..id = item['id']
      ..taetigkeit = item['taetigkeit']
      ..aktivBis = DateTime.tryParse(item['aktivBis'])
      ..aktivVon = DateTime.parse(item['aktivVon'])
      ..anlagedatum = DateTime.parse(item['anlagedatum'])
      ..untergliederung = item['untergliederung']
      ..gruppierung = item['gruppierung']
      ..berechtigteGruppe = item['berechtigteGruppe']
      ..berechtigteUntergruppen = item['berechtigteUntergruppen']);
  }

  Mitglied mitglied = Mitglied()
    ..vorname = rawMember['vorname']
    ..nachname = rawMember['nachname']
    ..geschlecht = rawMember['geschlecht']
    ..geburtsDatum = DateTime.parse(rawMember['geburtsDatum'])
    ..stufe = Stufe.getStufeByString(
            rawMember['stufe'] ?? StufeEnum.KEINE_STUFE.value)
        .name
        .value
    ..id = rawMember['id']
    ..mitgliedsNummer = rawMember['mitgliedsNummer']
    ..eintrittsdatum = DateTime.parse(rawMember['eintrittsdatum'])
    ..austrittsDatum = DateTime.tryParse(rawMember['austrittsDatum'])
    ..ort = rawMember['ort']
    ..plz = rawMember['plz']
    ..strasse = rawMember['strasse']
    ..landId = rawMember['landId'] ?? 1
    ..email = rawMember['email']
    ..emailVertretungsberechtigter = rawMember['emailVertretungsberechtigter']
    ..telefon1 = rawMember['telefon1']
    ..telefon2 = rawMember['telefon2']
    ..telefon3 = rawMember['telefon3']
    ..lastUpdated = DateTime.parse(rawMember['lastUpdated'])
    ..version = rawMember['version']
    ..mglTypeId = rawMember['mglTypeId']
    ..beitragsartId = rawMember['beitragsartId'] ?? 0
    ..status = rawMember['status']
    ..taetigkeiten = taetigkeiten;

  return mitglied;
}

Future<void> fakeLoading(ValueNotifier<bool?> memberOverviewProgressNotifier,
    ValueNotifier<double> memberAllProgressNotifier) async {
  await Future.delayed(const Duration(seconds: 1));
  memberOverviewProgressNotifier.value = true;
  Random random = Random();
  while (memberAllProgressNotifier.value < 1) {
    await Future.delayed(const Duration(milliseconds: 200));
    memberAllProgressNotifier.value += (0.05 + random.nextDouble() * 0.1);
    if (memberAllProgressNotifier.value > 1) {
      memberAllProgressNotifier.value = 1;
    }
  }
}

const List<dynamic> members = [
  {
    "member": {
      "id": 1,
      "mitgliedsNummer": 1,
      "geschlecht": "männlich",
      "emailVertretungsberechtigter": "liam.papa@smith.de",
      "lastUpdated": "2022-11-14 10:02:39",
      "version": 34,
      "mglTypeId": "MITGLIED",
      "nachname": "Smith",
      "eintrittsdatum": "2016-11-18 00:00:00",
      "status": "Aktiv",
      "telefon3": "",
      "email": "liam@smith.de",
      "telefon1": "040 123 456",
      "telefon2": "Papa: 0171 321 321 / Mama: 01578 123 123",
      "strasse": "Musterweg 1",
      "vorname": "Liam",
      "austrittsDatum": "",
      "ort": "Hamburg",
      "landId": 1,
      "geburtsDatum": "2009-02-16 00:00:00",
      "stufe": "Pfadfinder",
      "beitragsartId": 4,
      "plz": "22523"
    },
    "taetigkeiten": [
      {
        "id": 11,
        "aktivBis": "",
        "aktivVon": "2022-10-07 00:00:00",
        "anlagedatum": "2022-11-14 10:02:39",
        "aeaGroupForGf": "",
        "caeaGroup": "",
        "untergliederung": "Pfadfinder",
        "gruppierung": "1234 Test Gruppierung",
        "taetigkeit": "€ Mitglied (1)"
      },
      {
        "id": 12,
        "aktivBis": "2022-10-06 00:00:00",
        "aktivVon": "2020-10-02 00:00:00",
        "anlagedatum": "2020-10-30 10:39:46",
        "caeaGroupForGf": "",
        "caeaGroup": "",
        "untergliederung": "Jungpfadfinder",
        "gruppierung": "1234 Test Gruppierung",
        "taetigkeit": "€ Mitglied (1)"
      },
      {
        "id": 13,
        "aktivBis": "2020-10-01 00:00:00",
        "aktivVon": "2016-11-18 00:00:00",
        "anlagedatum": "2016-12-04 16:42:58",
        "caeaGroupForGf": "",
        "caeaGroup": "",
        "untergliederung": "Wölfling",
        "gruppierung": "1234 Test Gruppierung",
        "taetigkeit": "€ Mitglied (1)"
      }
    ]
  },
  {
    "member": {
      "id": 2,
      "mitgliedsNummer": 2,
      "geschlecht": "weiblich",
      "emailVertretungsberechtigter": "emma.mama@johnson.de",
      "lastUpdated": "2022-10-25 09:45:21",
      "version": 29,
      "mglTypeId": "MITGLIED",
      "nachname": "Johnson",
      "eintrittsdatum": "2018-07-22 00:00:00",
      "status": "Aktiv",
      "telefon3": "",
      "email": "emma@johnson.de",
      "telefon1": "030 987 654",
      "telefon2": "Mama: 0162 987 987 / Papa: 0176 543 543",
      "strasse": "Musterstraße 2",
      "vorname": "Emma",
      "austrittsDatum": "",
      "ort": "Berlin",
      "landId": 1,
      "geburtsDatum": "2010-05-03 00:00:00",
      "stufe": "Jungpfadfinder",
      "beitragsartId": 4,
      "plz": "10115"
    },
    "taetigkeiten": [
      {
        "id": 21,
        "aktivBis": "",
        "caeaGroup": "",
        "aktivVon": "2022-10-07 00:00:00",
        "anlagedatum": "2022-11-14 10:02:39",
        "caeaGroupForGf": "",
        "untergliederung": "Jungpfadfinder",
        "gruppierung": "1234 Test Gruppierung",
        "taetigkeit": "€ Mitglied (1)"
      },
      {
        "id": 22,
        "aktivBis": "2022-10-06 00:00:00",
        "caeaGroup": "",
        "aktivVon": "2020-10-02 00:00:00",
        "anlagedatum": "2020-10-30 10:39:46",
        "caeaGroupForGf": "",
        "untergliederung": "Wölfling",
        "gruppierung": "1234 Test Gruppierung",
        "taetigkeit": "€ Mitglied (1)"
      }
    ]
  },
  {
    "member": {
      "id": 3,
      "mitgliedsNummer": 3,
      "geschlecht": "männlich",
      "emailVertretungsberechtigter": "noah.papa@davis.de",
      "lastUpdated": "2022-09-30 14:20:17",
      "version": 31,
      "mglTypeId": "MITGLIED",
      "nachname": "Davis",
      "eintrittsdatum": "2017-03-10 00:00:00",
      "status": "Aktiv",
      "telefon3": "",
      "email": "noah@davis.de",
      "telefon1": "0170 789 123",
      "telefon2": "0159 987 789",
      "strasse": "Musterweg 3",
      "vorname": "Noah",
      "austrittsDatum": "",
      "ort": "München",
      "landId": 1,
      "geburtsDatum": "2011-08-27 00:00:00",
      "stufe": "Wölfling",
      "beitragsartId": 4,
      "plz": "80331"
    },
    "taetigkeiten": [
      {
        "id": 31,
        "aktivBis": "2022-10-06 00:00:00",
        "caeaGroup": "",
        "aktivVon": "2020-10-02 00:00:00",
        "anlagedatum": "2020-10-30 10:39:46",
        "caeaGroupForGf": "",
        "untergliederung": "Wölfling",
        "gruppierung": "1234 Test Gruppierung",
        "taetigkeit": "€ Mitglied (1)"
      }
    ]
  },
  {
    "member": {
      "id": 1234,
      "mitgliedsNummer": 1234,
      "geschlecht": "männlich",
      "emailVertretungsberechtigter": "",
      "lastUpdated": "2022-09-30 14:20:17",
      "version": 5,
      "mglTypeId": "MITGLIED",
      "nachname": "Mustermann",
      "eintrittsdatum": "2017-03-10 00:00:00",
      "status": "Aktiv",
      "telefon3": "",
      "email": "leiter@stamm.de",
      "telefon1": "0170 789 123",
      "telefon2": "",
      "strasse": "Musterweg 3",
      "vorname": "Test",
      "austrittsDatum": "",
      "ort": "Hamburg",
      "landId": 1,
      "geburtsDatum": "2011-08-27 00:00:00",
      "stufe": "Pfadfinder",
      "beitragsartId": 4,
      "plz": "80331",
    },
    "taetigkeiten": [
      {
        "id": 41,
        "aktivBis": "",
        "caeaGroup": "Schreiben/Lesen",
        "aktivVon": "2020-10-02 00:00:00",
        "anlagedatum": "2020-10-30 10:39:46",
        "caeaGroupForGf": "Schreiben/Lesen",
        "untergliederung": "Pfadfinder",
        "gruppierung": "1234 Test Gruppierung",
        "taetigkeit": "€ LeiterIn (6)"
      }
    ]
  }
];

import 'dart:math';

import 'package:faker/faker.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:nami/utilities/hive/mitglied.dart';
import 'package:nami/utilities/hive/taetigkeit.dart';

Future<void> storeFakeSetOfMemberInHive(
    Box<Mitglied> box,
    ValueNotifier<bool?> memberOverviewProgressNotifier,
    ValueNotifier<double> memberAllProgressNotifier) async {
  await fakeLoading(memberOverviewProgressNotifier, memberAllProgressNotifier);

  for (Mitglied member in createMembersList()) {
    box.put(member.id, member);
  }
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

Taetigkeit createTaetigkeit(
    int id, DateTime start, DateTime? end, String untergliederung,
    {bool isLeader = false, String gruppierung = "1234 Test Gruppierung"}) {
  Taetigkeit t = Taetigkeit()
    ..id = id
    ..aktivVon = start
    ..aktivBis = end
    ..anlagedatum = start
    ..untergliederung = untergliederung
    ..gruppierung = gruppierung
    ..berechtigteGruppe = ""
    ..berechtigteUntergruppen = "";

  if (isLeader) {
    t.taetigkeit = "€ LeiterIn (6)";
  } else {
    t.taetigkeit = "€ Mitglied (1)";
  }
  return t;
}

Mitglied createMitgleid(
    int id, DateTime start, DateTime birth, List<Taetigkeit> taetigkeiten) {
  var faker = Faker();
  var random = Random();
  return Mitglied()
    ..id = id
    ..mitgliedsNummer = id
    ..vorname = faker.person.firstName()
    ..nachname = faker.person.lastName()
    ..geschlecht = faker.randomGenerator.boolean() ? "männlich" : "weiblich"
    ..mglTypeId = "MITGLIED"
    ..stufe = taetigkeiten.first.untergliederung!
    ..status = "Aktiv"
    ..beitragsartId = 4
    ..eintrittsdatum = start
    ..austrittsDatum = null
    ..email = faker.internet.email()
    ..emailVertretungsberechtigter = faker.internet.freeEmail()
    ..telefon1 = faker.phoneNumber.de()
    ..telefon2 = faker.phoneNumber.de()
    ..telefon3 = ""
    ..geburtsDatum = birth
    ..strasse = faker.address.streetAddress()
    ..ort = faker.address.city()
    ..plz = faker.address.zipCode()
    ..landId = 1
    ..version = random.nextInt(60)
    ..lastUpdated = generateRandomDateDaysAgo(random.nextInt(30))
    ..taetigkeiten = taetigkeiten;
}

Mitglied createMemberPfadfinder(int age, int id) {
  DateTime birthDate = generateRandomDateYearsAgo(age - 0);
  DateTime woeStart = generateRandomDateYearsAgo(age - 6);
  DateTime jufiStart = generateRandomDateYearsAgo(age - 9);
  DateTime pfadiStart = generateRandomDateYearsAgo(age - 12);

  Taetigkeit taetigkeit = createTaetigkeit(
      int.parse('${id}3'), pfadiStart, null, "Pfadfinder", false);
  Taetigkeit taetigkeit2 = createTaetigkeit(
      int.parse('${id}2'), jufiStart, pfadiStart, "Jungpfadfinder", false);
  Taetigkeit taetigkeit3 = createTaetigkeit(
      int.parse('${id}1'), woeStart, jufiStart, "Wölfling", false);

  return createMitgleid(
      id, woeStart, birthDate, [taetigkeit, taetigkeit2, taetigkeit3]);
}

Mitglied createMemberJungpfadfinder(int age, int id) {
  DateTime birthDate = generateRandomDateYearsAgo(age - 0);
  DateTime woeStart = generateRandomDateYearsAgo(age - 8);
  DateTime jufiStart = generateRandomDateYearsAgo(age - 9);

  Taetigkeit taetigkeit = createTaetigkeit(
      int.parse('${id}1'), jufiStart, null, "Jungpfadfinder", false);
  Taetigkeit taetigkeit2 = createTaetigkeit(
      int.parse('${id}2'), woeStart, jufiStart, "Wölfling", false);

  return createMitgleid(id, woeStart, birthDate, [taetigkeit, taetigkeit2]);
}

Mitglied createMemberWoelfling(int age, int id) {
  DateTime birthDate = generateRandomDateYearsAgo(age - 0);
  DateTime woeStart = generateRandomDateYearsAgo(age - 7);

  Taetigkeit taetigkeit =
      createTaetigkeit(int.parse('${id}1'), woeStart, null, "Wölfling", false);

  return createMitgleid(id, woeStart, birthDate, [taetigkeit]);
}

Mitglied createMemberLeiter(int age, String stufe, int id) {
  DateTime birthDate = generateRandomDateYearsAgo(age - 0);
  DateTime leiterStart = generateRandomDateYearsAgo(age - 18);

  Taetigkeit taetigkeit =
      createTaetigkeit(int.parse('${id}1'), leiterStart, null, stufe, true);
  return createMitgleid(id, leiterStart, birthDate, [taetigkeit]);
}

List<Mitglied> createMembersList() {
  int i = 1;
  return [
    createMemberPfadfinder(13, i++),
    createMemberPfadfinder(12, i++),
    createMemberPfadfinder(14, i++),
    createMemberPfadfinder(13, i++),
    createMemberPfadfinder(15, i++),
    createMemberPfadfinder(16, i++),
    createMemberPfadfinder(14, i++),
    createMemberPfadfinder(13, i++),
    createMemberJungpfadfinder(13, i++),
    createMemberJungpfadfinder(12, i++),
    createMemberJungpfadfinder(11, i++),
    createMemberJungpfadfinder(10, i++),
    createMemberJungpfadfinder(9, i++),
    createMemberJungpfadfinder(10, i++),
    createMemberJungpfadfinder(11, i++),
    createMemberWoelfling(6, i++),
    createMemberWoelfling(7, i++),
    createMemberWoelfling(8, i++),
    createMemberWoelfling(9, i++),
    createMemberWoelfling(10, i++),
    createMemberWoelfling(9, i++),
    createMemberWoelfling(7, i++),
    createMemberWoelfling(8, i++),
    createMemberWoelfling(8, i++),
    createMemberLeiter(27, 'Pfadfinder', i++),
    createMemberLeiter(35, 'Rover', i++),
    createMemberLeiter(18, 'Wölfling', i++),
    createMemberLeiter(20, 'Pfadfinder', i++),
    createMemberLeiter(19, 'Jungpfadfinder', i++),
  ];
}

DateTime generateRandomDateYearsAgo(int age) {
  final random = Random();
  final currentYear = DateTime.now().year;
  final birthYear = currentYear - age;

  // Generiere einen zufälligen Monat zwischen 1 und 12
  final month = random.nextInt(12) + 1;

  // Generiere einen zufälligen Tag zwischen 1 und 28
  // Wir wählen 28, um sicherzustellen, dass das Datum in jedem Monat gültig ist
  final day = random.nextInt(28) + 1;

  return DateTime(birthYear, month, day);
}

DateTime generateRandomDateDaysAgo(int days) {
  return DateTime.now().subtract(Duration(days: days));
}

class FakeMember {
  final int id;
  final int mitgliedsNummer;
  final String geschlecht;
  final String emailVertretungsberechtigter;
  final String lastUpdated;
  final int version;
  final String mglTypeId;
  final String nachname;
  final String eintrittsdatum;
  final String status;
  final String telefon3;
  final String email;
  final String telefon1;
  final String telefon2;
  final String strasse;
  final String vorname;
  final String austrittsDatum;
  final String ort;
  final int landId;
  final String geburtsDatum;
  final String stufe;
  final int beitragsartId;
  final String plz;
  final List<FakeTaetigkeit> taetigkeiten;

  FakeMember({
    required this.id,
    required this.mitgliedsNummer,
    required this.geschlecht,
    required this.emailVertretungsberechtigter,
    required this.lastUpdated,
    required this.version,
    required this.mglTypeId,
    required this.nachname,
    required this.eintrittsdatum,
    required this.status,
    required this.telefon3,
    required this.email,
    required this.telefon1,
    required this.telefon2,
    required this.strasse,
    required this.vorname,
    required this.austrittsDatum,
    required this.ort,
    required this.landId,
    required this.geburtsDatum,
    required this.stufe,
    required this.beitragsartId,
    required this.plz,
    required this.taetigkeiten,
  });
}

class FakeTaetigkeit {
  final int id;
  final String aktivBis;
  final String aktivVon;
  final String anlagedatum;
  final String aeaGroupForGf;
  final String caeaGroup;
  final String untergliederung;
  final String gruppierung;
  final String taetigkeit;

  FakeTaetigkeit({
    required this.id,
    required this.aktivBis,
    required this.aktivVon,
    required this.anlagedatum,
    required this.aeaGroupForGf,
    required this.caeaGroup,
    required this.untergliederung,
    required this.gruppierung,
    required this.taetigkeit,
  });
}

import 'dart:math';

import 'package:faker/faker.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_ce/hive.dart';
import 'package:nami/utilities/hive/ausbildung.dart';
import 'package:nami/utilities/hive/mitglied.dart';
import 'package:nami/utilities/hive/taetigkeit.dart';

var random = Random();

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
    t.taetigkeit = "Mitglied";
  }
  return t;
}

Ausbildung createAusbildung({
  required int id,
  required DateTime datum,
  required String name,
  required String veranstalter,
  required String baustein,
}) {
  final a = Ausbildung()
    ..id = id
    ..name = name
    ..datum = datum
    ..veranstalter = veranstalter
    ..baustein = baustein;
  return a;
}

/// first in taetigkeiten is the newest/current untergliederung
Mitglied createMitgleid(
  int id,
  DateTime start,
  DateTime birth,
  List<Taetigkeit> taetigkeiten, {
  String? vorname,
  String? nachname,
  String? strasse,
  String? ort,
  String? plz,
  List<Ausbildung> ausbildungen = const [],
}) {
  var faker = Faker();
  var random = Random();
  return Mitglied()
    ..id = id
    ..mitgliedsNummer = id
    ..vorname = vorname ?? faker.person.firstName()
    ..nachname = nachname ?? faker.person.lastName()
    ..geschlechtId = random.nextBool() ? 19 : 20
    ..mglTypeId = "MITGLIED"
    ..status = "Aktiv"
    ..beitragsartId = 4
    ..staatssangehaerigkeitId = 1054
    ..konfessionId = null
    ..eintrittsdatum = start
    ..austrittsDatum = null
    ..email = faker.internet.email()
    ..emailVertretungsberechtigter = faker.internet.freeEmail()
    ..telefon1 = faker.phoneNumber.de()
    ..telefon2 = faker.phoneNumber.de()
    ..telefon3 = ""
    ..geburtsDatum = birth
    ..strasse = strasse ?? faker.address.streetAddress()
    ..ort = ort ?? faker.address.city()
    ..plz = plz ?? faker.address.zipCode()
    ..landId = 1
    ..version = random.nextInt(60)
    ..lastUpdated = generateRandomDateDaysAgo(random.nextInt(30))
    ..taetigkeiten = taetigkeiten
    ..mitgliedszeitschrift = random.nextBool()
    ..datenweiterverwendung = random.nextBool()
    ..ausbildungen = ausbildungen;
}

Mitglied createMemberDefaultPfadfinder(int age, int id) {
  DateTime birthDate = generateRandomDateYearsAgo(age - 0);
  DateTime woeStart = generateRandomDateYearsAgo(age - 6);
  DateTime jufiStart = generateRandomDateYearsAgo(age - 9);
  DateTime pfadiStart = generateRandomDateYearsAgo(age - 12);

  Taetigkeit taetigkeit =
      createTaetigkeit(int.parse('${id}3'), pfadiStart, null, "Pfadfinder");
  Taetigkeit taetigkeit2 = createTaetigkeit(
      int.parse('${id}2'), jufiStart, pfadiStart, "Jungpfadfinder");
  Taetigkeit taetigkeit3 =
      createTaetigkeit(int.parse('${id}1'), woeStart, jufiStart, "Wölfling");

  return createMitgleid(
      id, woeStart, birthDate, [taetigkeit, taetigkeit2, taetigkeit3]);
}

Mitglied createMemberDefaultJungpfadfinder(int age, int id) {
  DateTime birthDate = generateRandomDateYearsAgo(age - 0);
  DateTime woeStart = generateRandomDateYearsAgo(age - 8);
  DateTime jufiStart = generateRandomDateYearsAgo(age - 9);

  Taetigkeit taetigkeit =
      createTaetigkeit(int.parse('${id}1'), jufiStart, null, "Jungpfadfinder");
  Taetigkeit taetigkeit2 =
      createTaetigkeit(int.parse('${id}2'), woeStart, jufiStart, "Wölfling");

  return createMitgleid(id, woeStart, birthDate, [taetigkeit, taetigkeit2]);
}

Mitglied createMemberDefaultWoelfling(int age, int id) {
  DateTime birthDate = generateRandomDateYearsAgo(age - 0);
  DateTime biberStart = generateRandomDateYearsAgo(age - 5);
  DateTime woeStart = generateRandomDateYearsAgo(age - 7);

  List<Taetigkeit> taetigkeiten = [];
  int i = 1;
  taetigkeiten.add(
      createTaetigkeit(int.parse('$id${i++}'), woeStart, null, "Wölfling"));
  if (random.nextBool()) {
    taetigkeiten.add(createTaetigkeit(
        int.parse('$id${i++}'), biberStart, woeStart, "Biber"));
  }

  return createMitgleid(id, taetigkeiten.length == 2 ? biberStart : woeStart,
      birthDate, taetigkeiten);
}

Mitglied createMemberDefaultBiber(int age, int id) {
  DateTime birthDate = generateRandomDateYearsAgo(age - 0);
  DateTime biberStart = generateRandomDateYearsAgo(age - 5);

  List<Taetigkeit> taetigkeiten = [];
  int i = 1;
  taetigkeiten
      .add(createTaetigkeit(int.parse('$id${i++}'), biberStart, null, "Biber"));

  return createMitgleid(id, biberStart, birthDate, taetigkeiten);
}

Mitglied createMemberDefaultLeiter(int age, String stufe, int id) {
  DateTime birthDate = generateRandomDateYearsAgo(age - 0);
  DateTime leiterStart = generateRandomDateYearsAgo(age - 18);

  Taetigkeit taetigkeit = createTaetigkeit(
      int.parse('${id}1'), leiterStart, null, stufe,
      isLeader: true);
  final ausbildung1 = createAusbildung(
    id: int.parse('${id}01'),
    name: "Bausteinwochenende 19.04.24-21.04.24",
    datum: DateTime.parse("2024-04-19"),
    baustein: "Baustein 2a",
    veranstalter: "DPSG DV Köln",
  );
  final ausbildung2 = createAusbildung(
    id: int.parse('${id}02'),
    name: "Bausteinwochenende 19.04.24-21.04.24",
    datum: DateTime.parse("2024-04-19"),
    baustein: "Baustein 2b",
    veranstalter: "DPSG DV Köln",
  );

  return createMitgleid(
    id,
    leiterStart,
    birthDate,
    [taetigkeit],
    ausbildungen: [ausbildung1, ausbildung2],
  );
}

/// Leiter ist in allen Stufen Mitglied und Leiter gewesen
/// und leitet länger als er Mitglied war
Mitglied createMemberLeiter1(int id) {
  int age = 35;
  DateTime birthDate = generateRandomDateYearsAgo(age - 0);
  DateTime woeStart = generateRandomDateYearsAgo(age - 6);
  DateTime biberStart = woeStart.subtract(const Duration(days: 15));
  DateTime jufiStart = generateRandomDateYearsAgo(age - 9);
  DateTime pfadiStart = generateRandomDateYearsAgo(age - 12);
  DateTime roverStart = generateRandomDateYearsAgo(age - 15);
  DateTime leiterBiberStart = generateRandomDateYearsAgo(age - 18);
  DateTime leiterWoeStart = generateRandomDateYearsAgo(age - 20);
  DateTime leiterJufiStart = generateRandomDateYearsAgo(age - 22);
  DateTime leiterPfadiStart = generateRandomDateYearsAgo(age - 25);
  DateTime leiterRoverStart = generateRandomDateYearsAgo(age - 30);
  DateTime leiterJufi2Start = generateRandomDateYearsAgo(age - 31);

  int i = 1;
  Taetigkeit taetigkeit0 = createTaetigkeit(
      int.parse('$id${i++}'), biberStart, woeStart, 'Biber',
      gruppierung: '6789 Andere Gruppierung');
  Taetigkeit taetigkeit1 = createTaetigkeit(
      int.parse('$id${i++}'), woeStart, jufiStart, 'Wölfling',
      gruppierung: '6789 Andere Gruppierung');
  Taetigkeit taetigkeit2 = createTaetigkeit(
      int.parse('$id${i++}'), jufiStart, pfadiStart, 'Jungpfadfinder',
      gruppierung: '6789 Andere Gruppierung');
  Taetigkeit taetigkeit3 = createTaetigkeit(
      int.parse('$id${i++}'), pfadiStart, roverStart, 'Pfadfinder');
  Taetigkeit taetigkeit4 = createTaetigkeit(
      int.parse('$id${i++}'), roverStart, leiterBiberStart, 'Rover');
  Taetigkeit taetigkeit5 = createTaetigkeit(
      int.parse('$id${i++}'), leiterBiberStart, leiterWoeStart, 'Biber',
      isLeader: true);
  Taetigkeit taetigkeit6 = createTaetigkeit(
      int.parse('$id${i++}'), leiterWoeStart, leiterJufiStart, 'Wölfling',
      isLeader: true);
  Taetigkeit taetigkeit7 = createTaetigkeit(int.parse('$id${i++}'),
      leiterJufiStart, leiterPfadiStart, 'Jungpfadfinder',
      isLeader: true);
  Taetigkeit taetigkeit8 = createTaetigkeit(
      int.parse('$id${i++}'), leiterPfadiStart, leiterRoverStart, 'Pfadfinder',
      isLeader: true);
  Taetigkeit taetigkeit9 = createTaetigkeit(
      int.parse('$id${i++}'), leiterRoverStart, leiterJufi2Start, 'Rover',
      isLeader: true);
  Taetigkeit taetigkeit10 = createTaetigkeit(
      int.parse('$id${i++}'), leiterJufi2Start, null, 'Jungpfadfinder',
      isLeader: true);

  return createMitgleid(
      id,
      biberStart,
      birthDate,
      [
        taetigkeit10,
        taetigkeit9,
        taetigkeit8,
        taetigkeit7,
        taetigkeit6,
        taetigkeit5,
        taetigkeit4,
        taetigkeit3,
        taetigkeit2,
        taetigkeit1,
        taetigkeit0
      ],
      vorname: 'A1_Leiter',
      nachname: 'Alle Stufen',
      strasse: 'Lange Reihe 2',
      ort: 'Hamburg',
      plz: '20099');
}

/// Leiter ist in allen Stufen und leitet kürzer als er Mitglied war
Mitglied createMemberLeiter2(int id) {
  int age = 25;
  DateTime birthDate = generateRandomDateYearsAgo(age - 0);
  DateTime woeStart = generateRandomDateYearsAgo(age - 6);
  DateTime biberStart = woeStart.subtract(const Duration(days: 15));
  DateTime jufiStart = generateRandomDateYearsAgo(age - 9);
  DateTime pfadiStart = generateRandomDateYearsAgo(age - 12);
  DateTime roverStart = generateRandomDateYearsAgo(age - 15);
  DateTime leiterPfadi1Start = generateRandomDateYearsAgo(age - 18);
  DateTime leiterWoeStart = generateRandomDateYearsAgo(age - 20);
  DateTime leiterPfadi2Start = generateRandomDateYearsAgo(age - 23);

  int i = 1;
  Taetigkeit taetigkeit0 = createTaetigkeit(
      int.parse('$id${i++}'), biberStart, woeStart, 'Biber',
      gruppierung: '6789 Andere Gruppierung');
  Taetigkeit taetigkeit1 = createTaetigkeit(
      int.parse('$id${i++}'), woeStart, jufiStart, 'Wölfling',
      gruppierung: '6789 Andere Gruppierung');
  Taetigkeit taetigkeit2 = createTaetigkeit(
      int.parse('$id${i++}'), jufiStart, pfadiStart, 'Jungpfadfinder',
      gruppierung: '6789 Andere Gruppierung');
  Taetigkeit taetigkeit3 = createTaetigkeit(
      int.parse('$id${i++}'), pfadiStart, roverStart, 'Pfadfinder');
  Taetigkeit taetigkeit4 = createTaetigkeit(
      int.parse('$id${i++}'), roverStart, leiterPfadi1Start, 'Rover');
  Taetigkeit taetigkeit5 = createTaetigkeit(
      int.parse('$id${i++}'), leiterPfadi1Start, leiterWoeStart, 'Pfadfinder',
      isLeader: true);
  Taetigkeit taetigkeit6 = createTaetigkeit(
      int.parse('$id${i++}'), leiterWoeStart, leiterPfadi2Start, 'Wölfling',
      isLeader: true);
  Taetigkeit taetigkeit7 = createTaetigkeit(
      int.parse('$id${i++}'), leiterPfadi2Start, null, 'Pfadfinder',
      isLeader: true);

  return createMitgleid(
      id,
      biberStart,
      birthDate,
      [
        taetigkeit7,
        taetigkeit6,
        taetigkeit5,
        taetigkeit4,
        taetigkeit3,
        taetigkeit2,
        taetigkeit1,
        taetigkeit0
      ],
      vorname: 'A2_Leiter',
      nachname: 'Pfadi',
      strasse: 'Lange Reihe 2',
      ort: 'Hamburg',
      plz: '20099');
}

List<Mitglied> createMembersList() {
  int i = 1;
  return [
    createMemberDefaultPfadfinder(13, i++),
    createMemberDefaultPfadfinder(12, i++),
    createMemberDefaultPfadfinder(14, i++),
    createMemberDefaultPfadfinder(13, i++),
    createMemberDefaultPfadfinder(15, i++),
    createMemberDefaultPfadfinder(16, i++),
    createMemberDefaultPfadfinder(14, i++),
    createMemberDefaultPfadfinder(13, i++),
    createMemberDefaultJungpfadfinder(13, i++),
    createMemberDefaultJungpfadfinder(12, i++),
    createMemberDefaultJungpfadfinder(11, i++),
    createMemberDefaultJungpfadfinder(10, i++),
    createMemberDefaultJungpfadfinder(9, i++),
    createMemberDefaultJungpfadfinder(10, i++),
    createMemberDefaultJungpfadfinder(11, i++),
    createMemberDefaultWoelfling(6, i++),
    createMemberDefaultWoelfling(7, i++),
    createMemberDefaultWoelfling(8, i++),
    createMemberDefaultWoelfling(9, i++),
    createMemberDefaultWoelfling(10, i++),
    createMemberDefaultWoelfling(9, i++),
    createMemberDefaultWoelfling(7, i++),
    createMemberDefaultWoelfling(8, i++),
    createMemberDefaultWoelfling(8, i++),
    createMemberDefaultBiber(6, i++),
    createMemberDefaultBiber(5, i++),
    createMemberDefaultBiber(6, i++),
    createMemberDefaultLeiter(27, 'Pfadfinder', i++),
    createMemberDefaultLeiter(35, 'Rover', i++),
    createMemberDefaultLeiter(18, 'Wölfling', i++),
    createMemberDefaultLeiter(20, 'Pfadfinder', i++),
    createMemberDefaultLeiter(19, 'Jungpfadfinder', i++),
    createMemberLeiter1(i++),
    createMemberLeiter2(i++),
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

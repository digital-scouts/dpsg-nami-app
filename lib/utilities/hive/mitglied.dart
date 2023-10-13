import 'package:hive/hive.dart';
import 'package:nami/utilities/hive/settings.dart';
import 'package:nami/utilities/hive/taetigkeit.dart';

import '../stufe.dart';

// flutter packages pub run build_runner build

part 'mitglied.g.dart';

@HiveType(typeId: 1)
class Mitglied {
  @HiveField(0)
  late String vorname;

  @HiveField(1)
  late String nachname;

  @HiveField(3)
  late String geschlecht;

  @HiveField(4)
  late DateTime geburtsDatum;

  @HiveField(5)
  late String stufe;

  @HiveField(6)
  late int id;

  @HiveField(7)
  late int mitgliedsNummer;

  @HiveField(8)
  late DateTime eintrittsdatum;

  @HiveField(9)
  late DateTime? austrittsDatum;

  @HiveField(10)
  late String ort;

  @HiveField(11)
  late String plz;

  @HiveField(12)
  late String strasse;

  @HiveField(13)
  late int landId;

  @HiveField(14)
  late String? email;

  @HiveField(15)
  late String? emailVertretungsberechtigter;

  @HiveField(16)
  late String? telefon1;

  @HiveField(17)
  late String? telefon2;

  @HiveField(18)
  late String? telefon3;

  @HiveField(19)
  late DateTime lastUpdated;

  @HiveField(20)
  late int version;

  @HiveField(21)
  late String mglTypeId;

  @HiveField(22)
  late int beitragsartId;

  @HiveField(23)
  late String status;

  @HiveField(24)
  late List<Taetigkeit> taetigkeiten;

  bool isMitgliedLeiter() {
    for (Taetigkeit t in taetigkeiten) {
      if (t.isLeitung()) {
        return true;
      }
    }
    return false;
  }

  List<Taetigkeit> getActiveTaetigkeiten() {
    List<Taetigkeit> aktiveTaetigkeiten = [];
    for (Taetigkeit taetigkeit in taetigkeiten) {
      taetigkeit.taetigkeit =
          taetigkeit.taetigkeit.replaceFirst('€ ', '').split('(')[0];
      if (taetigkeit.isActive() || taetigkeit.isFutureTaetigkeit()) {
        aktiveTaetigkeiten.add(taetigkeit);
      }
    }
    return aktiveTaetigkeiten;
  }

  List<Taetigkeit> getAlteTaetigkeiten() {
    List<Taetigkeit> alteTaetigkeiten = [];
    for (Taetigkeit taetigkeit in taetigkeiten) {
      taetigkeit.taetigkeit =
          taetigkeit.taetigkeit.replaceFirst('€ ', '').split('(')[0];
      if (!taetigkeit.isActive() && !taetigkeit.isFutureTaetigkeit()) {
        alteTaetigkeiten.add(taetigkeit);
      }
    }
    return alteTaetigkeiten;
  }

  Stufe get currentStufe {
    return Stufe.getStufeByString(stufe);
  }

  Stufe? get nextStufe {
    return Stufe.getStufeByOrder(Stufe.getStufeByString(stufe).order + 1);
  }

  int? getMinStufenWechselJahr() {
    int alterNextStufenwechsel =
        getAlterAm(referenceDate: getNextStufenwechselDatum());

    if (nextStufe != null &&
        nextStufe!.isStufeYouCanChangeTo &&
        !isMitgliedLeiter()) {
      return DateTime.now().year -
          alterNextStufenwechsel +
          nextStufe!.alterMin!;
    } else {
      return null;
    }
  }

  int? getMaxStufenWechselJahr() {
    int alterNextStufenwechsel =
        getAlterAm(referenceDate: getNextStufenwechselDatum());
    if (nextStufe != null &&
        nextStufe!.isStufeYouCanChangeTo &&
        !isMitgliedLeiter()) {
      return DateTime.now().year -
          alterNextStufenwechsel +
          currentStufe.alterMax! +
          1;
    } else if (currentStufe.name == "Rover" && !isMitgliedLeiter()) {
      return DateTime.now().year -
          alterNextStufenwechsel +
          currentStufe.alterMax! +
          1;
    } else {
      return null;
    }
  }

  int getAlterAm({DateTime? referenceDate}) {
    referenceDate ??= DateTime.now();

    int age = referenceDate.year - geburtsDatum.year;

    // Überprüfen, ob der Geburtstag bereits in diesem Jahr stattgefunden hat
    if (referenceDate.month < geburtsDatum.month ||
        (referenceDate.month == geburtsDatum.month &&
            referenceDate.day < geburtsDatum.day)) {
      age--;
    }
    return age;
  }

  /// 0 gleich | <0 this ist alpabetisch früher | >0 this ist alpabetisch später
  int compareByName(Mitglied mitglied) {
    String m1Name = '$vorname $nachname';
    String m2Name = '${mitglied.vorname} ${mitglied.nachname}';
    return m1Name.compareTo(m2Name);
  }

  /// 0 gleich | <0 this ist jüngere Stufe | >0 this ist ältere Stufe
  int compareByStufe(Mitglied mitglied) {
    return Stufe.getStufeByString(stufe)
        .compareTo(Stufe.getStufeByString(mitglied.stufe));
  }

  /// 0 gleich | <0 this ist jünger | >0 this ist älter
  int compareByAge(Mitglied mitglied) {
    return geburtsDatum.compareTo(mitglied.geburtsDatum);
  }

  /// 0 gleich | <0 this ist länger dabei | >0 this ist kürzer dabei
  int compareByMitgliedsalter(Mitglied mitglied) {
    return eintrittsdatum.compareTo(mitglied.eintrittsdatum);
  }
}

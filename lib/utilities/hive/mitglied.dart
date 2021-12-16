import 'package:hive/hive.dart';
import 'package:nami/utilities/hive/taetigkeit.dart';

import '../constants.dart';

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

  /// 0 gleich | <0 this ist alpabetisch früher | >0 this ist alpabetisch später
  int compareByName(Mitglied mitglied) {
    String m1Name = '$vorname $nachname';
    String m2Name = '${mitglied.vorname} ${mitglied.nachname}';
    return m1Name.compareTo(m2Name);
  }

  /// 0 gleich | <0 this ist jüngere Stufe | >0 this ist ältere Stufe
  int compareByStufe(Mitglied mitglied) {
    int m1Stufe = getStufeValue(StufenExtension.getValueFromString(stufe));
    int m2Stufe =
        getStufeValue(StufenExtension.getValueFromString(mitglied.stufe));
    return m1Stufe - m2Stufe;
  }

  /// 0 gleich | <0 this ist jünger | >0 this ist älter
  int compareByAge(Mitglied mitglied) {
    return geburtsDatum.compareTo(mitglied.geburtsDatum);
  }

  /// 0 gleich | <0 this ist länger dabei | >0 this ist kürzer dabei
  int compareByMitgliedsalter(Mitglied mitglied) {
    return eintrittsdatum.compareTo(mitglied.eintrittsdatum);
  }

  int getStufeValue(Stufe stufe) {
    switch (stufe) {
      case Stufe.woe:
        return 1;
      case Stufe.jufi:
        return 2;
      case Stufe.pfadi:
        return 3;
      case Stufe.rover:
        return 4;
      case Stufe.leiter:
        return 5;
      default:
        return 6;
    }
  }
}

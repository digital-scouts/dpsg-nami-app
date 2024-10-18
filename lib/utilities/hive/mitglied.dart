import 'package:geocoding/geocoding.dart';
import 'package:hive_ce/hive.dart';
import 'package:latlong2/latlong.dart';
import 'package:nami/utilities/hive/ausbildung.dart';
import 'package:nami/utilities/hive/settings_stufenwechsel.dart';
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
  late int geschlechtId;

  @HiveField(4)
  late DateTime geburtsDatum;

  @HiveField(6)
  late int? id;

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

  @HiveField(25, defaultValue: [])
  late List<Ausbildung> ausbildungen;

  @HiveField(26)
  late int staatssangehaerigkeitId;

  @HiveField(27)
  late String? konfessionId;

  @HiveField(28)
  late bool mitgliedszeitschrift;

  @HiveField(29)
  late bool datenweiterverwendung;

  bool isMitgliedLeiter() {
    for (Taetigkeit t in getActiveTaetigkeiten()) {
      if (t.isLeitung()) {
        return true;
      }
    }
    return false;
  }

  Future<LatLng?> getCoordinates() async {
    try {
      final res = await locationFromAddress('$strasse, $plz $ort');
      return LatLng(res.first.latitude, res.first.longitude);
    } on NoResultFoundException catch (_, __) {}
    return null;
  }

  List<Taetigkeit> getZukuenftigeTaetigkeiten() {
    List<Taetigkeit> zukuenftigeTaetigkeiten = [];
    for (Taetigkeit taetigkeit in taetigkeiten) {
      if (!taetigkeit.isActive() && taetigkeit.isFutureTaetigkeit()) {
        zukuenftigeTaetigkeiten.add(taetigkeit);
      }
    }
    return zukuenftigeTaetigkeiten;
  }

  List<Taetigkeit> getActiveTaetigkeiten() {
    List<Taetigkeit> aktiveTaetigkeiten = [];
    for (Taetigkeit taetigkeit in taetigkeiten) {
      if (taetigkeit.isActive() && !taetigkeit.isFutureTaetigkeit()) {
        aktiveTaetigkeiten.add(taetigkeit);
      }
    }
    return aktiveTaetigkeiten;
  }

  List<Taetigkeit> getAlteTaetigkeiten() {
    List<Taetigkeit> alteTaetigkeiten = [];
    for (Taetigkeit taetigkeit in taetigkeiten) {
      if (!taetigkeit.isActive() && !taetigkeit.isFutureTaetigkeit()) {
        alteTaetigkeiten.add(taetigkeit);
      }
    }
    return alteTaetigkeiten;
  }

  Stufe get currentStufe {
    if (isMitgliedLeiter()) {
      return Stufe.LEITER;
    }

    for (Taetigkeit taetigkeit in getActiveTaetigkeiten()) {
      if (taetigkeit.untergliederung != null &&
          taetigkeit.untergliederung!.isNotEmpty) {
        return Stufe.getStufeByString(taetigkeit.untergliederung!);
      }
    }

    return Stufe.KEINE_STUFE;
  }

  /// Gibt die Untergliederung zurück, wenn es eine Stufe ist
  Stufe get currentStufeWithoutLeiter {
    for (Taetigkeit taetigkeit in getActiveTaetigkeiten()) {
      if (taetigkeit.untergliederung != null &&
          taetigkeit.untergliederung!.isNotEmpty) {
        Stufe s = Stufe.getStufeByString(taetigkeit.untergliederung!);
        if (s == Stufe.KEINE_STUFE) {
          continue;
        }
        return s;
      }
    }
    return Stufe.KEINE_STUFE;
  }

  Stufe? get nextStufe {
    return Stufe.getStufeByOrder(currentStufe.index + 1);
  }

  DateTime? getMinStufenWechselDatum() {
    DateTime nextStufenwechselDatum = getNextStufenwechselDatum();
    int alterNextStufenwechsel =
        getAlterAm(referenceDate: nextStufenwechselDatum);

    if (nextStufe != null &&
        nextStufe!.isStufeYouCanChangeTo &&
        !isMitgliedLeiter()) {
      return DateTime(
              nextStufenwechselDatum.year -
                  alterNextStufenwechsel +
                  getStufeMinAge(nextStufe!)!,
              nextStufenwechselDatum.month,
              nextStufenwechselDatum.day)
          .subtract(const Duration(days: 1));
    } else {
      return null;
    }
  }

  DateTime? getMaxStufenWechselDatum() {
    DateTime nextStufenwechselDatum = getNextStufenwechselDatum();
    int alterNextStufenwechsel =
        getAlterAm(referenceDate: nextStufenwechselDatum);

    if (nextStufe != null &&
        currentStufe != Stufe.KEINE_STUFE &&
        (nextStufe!.isStufeYouCanChangeTo || currentStufe == Stufe.ROVER) &&
        !isMitgliedLeiter()) {
      return DateTime(
          nextStufenwechselDatum.year -
              alterNextStufenwechsel +
              getStufeMaxAge(currentStufe)!,
          nextStufenwechselDatum.month,
          nextStufenwechselDatum.day);
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

  /// 0 gleich | <0 this ist alpabetisch früher | >0 this ist alpabetisch später
  int compareByLastName(Mitglied mitglied) {
    String m1Name = '$nachname $vorname ';
    String m2Name = '${mitglied.nachname} ${mitglied.vorname}';
    return m1Name.compareTo(m2Name);
  }

  /// 0 gleich | <0 this ist jüngere Stufe | >0 this ist ältere Stufe
  int compareByStufe(Mitglied mitglied) {
    return currentStufe.compareTo(mitglied.currentStufe);
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

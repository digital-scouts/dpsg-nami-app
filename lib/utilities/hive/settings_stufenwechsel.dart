import 'package:hive_ce/hive.dart';
import 'package:nami/utilities/stufe.dart';

enum SettingStufenwechselValue { stufenwechselDatum, minAge, maxAge }

Box get settingsStufenwechselBox => Hive.box('settingsBox');

void setStufeMinAge(Stufe stufe, int minAge) {
  settingsStufenwechselBox.put(
      '${stufe.display}${SettingStufenwechselValue.minAge}', minAge);
}

void setStufeMaxAge(Stufe stufe, int maxAge) {
  settingsStufenwechselBox.put(
      '${stufe.display}${SettingStufenwechselValue.maxAge}', maxAge);
}

int? getStufeMinAge(Stufe stufe) {
  return settingsStufenwechselBox
          .get('${stufe.display}${SettingStufenwechselValue.minAge}') ??
      stufe.alterMin;
}

int? getStufeMaxAge(Stufe stufe) {
  return settingsStufenwechselBox
          .get('${stufe.display}${SettingStufenwechselValue.maxAge}') ??
      stufe.alterMax;
}

void setStufenwechselDatum(DateTime stufenwechselDatum) {
  settingsStufenwechselBox.put(
      SettingStufenwechselValue.stufenwechselDatum.toString(),
      stufenwechselDatum);
}

DateTime getStufenWechselDatum() {
  return settingsStufenwechselBox
          .get(SettingStufenwechselValue.stufenwechselDatum.toString()) ??
      DateTime.now();
}

DateTime getNextStufenwechselDatum() {
  DateTime now = DateTime.now();
  DateTime safedStufenwechselDatum = settingsStufenwechselBox
          .get(SettingStufenwechselValue.stufenwechselDatum.toString()) ??
      DateTime.utc(1989, 10, 1);
  safedStufenwechselDatum = DateTime.utc(
      now.year, safedStufenwechselDatum.month, safedStufenwechselDatum.day);

  // set year of safedStufenwechselDatum to current year or next year if it is in the past
  DateTime stufenwechselDatum;

  DateTime stufenwechselPlus14Days =
      safedStufenwechselDatum.add(const Duration(days: 14));

  if (stufenwechselPlus14Days.isBefore(now)) {
    stufenwechselDatum = DateTime(now.year + 1, safedStufenwechselDatum.month,
        safedStufenwechselDatum.day);
  } else {
    stufenwechselDatum = DateTime(
        now.year, safedStufenwechselDatum.month, safedStufenwechselDatum.day);
  }

  return stufenwechselDatum;
}

void deleteStufenwechselDatum() {
  settingsStufenwechselBox
      .delete(SettingStufenwechselValue.stufenwechselDatum.toString());
}

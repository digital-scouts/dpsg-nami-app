import 'package:hive/hive.dart';

// flutter packages pub run build_runner build
enum SettingValue {
  namiApiCookie,
  namiLoginId,
  namiPassword,
  namiUrl,
  namiPath,
  gruppierungId,
  gruppierungName,
  lastNamiSync,
  lastLoginCheck,
  stufenwechselDatum,
  metaGeschechtOptions,
  metaLandOptions,
  metaBeitragsartOptions,
  metaRegionOptions,
  metaStaatsangehoerigkeitOptions,
  metaMitgliedstypOptions,
}

void setMetaData(
    List<String> geschlecht,
    List<String> land,
    List<String> region,
    List<String> beitragsart,
    List<String> staatsangehoerigkeit,
    List<String> mitgliedstyp) {
  Hive.box('settingsBox')
      .put(SettingValue.metaGeschechtOptions.toString(), geschlecht);
  Hive.box('settingsBox').put(SettingValue.metaLandOptions.toString(), land);
  Hive.box('settingsBox')
      .put(SettingValue.metaBeitragsartOptions.toString(), beitragsart);
  Hive.box('settingsBox')
      .put(SettingValue.metaRegionOptions.toString(), region);
  Hive.box('settingsBox').put(
      SettingValue.metaStaatsangehoerigkeitOptions.toString(),
      staatsangehoerigkeit);
  Hive.box('settingsBox')
      .put(SettingValue.metaMitgliedstypOptions.toString(), mitgliedstyp);
}

List<String> getMetaGeschlechtOptions() {
  return Hive.box('settingsBox')
          .get(SettingValue.metaGeschechtOptions.toString()) ??
      [];
}

List<String> getMetaLandOptions() {
  return Hive.box('settingsBox').get(SettingValue.metaLandOptions.toString()) ??
      [];
}

List<String> getMetaBeitragsartOptions() {
  return Hive.box('settingsBox')
          .get(SettingValue.metaBeitragsartOptions.toString()) ??
      [];
}

List<String> getMetaRegionOptions() {
  return Hive.box('settingsBox')
          .get(SettingValue.metaRegionOptions.toString()) ??
      [];
}

List<String> getMetaStaatsangehoerigkeitOptions() {
  return Hive.box('settingsBox')
          .get(SettingValue.metaStaatsangehoerigkeitOptions.toString()) ??
      [];
}

List<String> getMetaMitgliedstypOptions() {
  return Hive.box('settingsBox')
          .get(SettingValue.metaMitgliedstypOptions.toString()) ??
      [];
}

void setNamiApiCookie(String namiApiToken) {
  Hive.box('settingsBox')
      .put(SettingValue.namiApiCookie.toString(), namiApiToken);
}

void setStufenwechselDatum(DateTime stufenwechselDatum) {
  Hive.box('settingsBox')
      .put(SettingValue.stufenwechselDatum.toString(), stufenwechselDatum);
}

void setNamiLoginId(int loginId) async {
  Hive.box('settingsBox').put(SettingValue.namiLoginId.toString(), loginId);
}

void setNamiPassword(String password) async {
  Hive.box('settingsBox').put(SettingValue.namiPassword.toString(), password);
}

void setNamiUrl(String url) async {
  Hive.box('settingsBox').put(SettingValue.namiUrl.toString(), url);
}

void setNamiPath(String path) async {
  Hive.box('settingsBox').put(SettingValue.namiPath.toString(), path);
}

void setGruppierungId(int gruppierung) {
  Hive.box('settingsBox')
      .put(SettingValue.gruppierungId.toString(), gruppierung);
}

void setGruppierungName(String gruppierungName) {
  Hive.box('settingsBox')
      .put(SettingValue.gruppierungName.toString(), gruppierungName);
}

void setLastNamiSync(DateTime lastNamiSync) {
  Hive.box('settingsBox')
      .put(SettingValue.lastNamiSync.toString(), lastNamiSync);
}

void setLastLoginCheck(DateTime lastLoginCheck) {
  Hive.box('settingsBox')
      .put(SettingValue.lastLoginCheck.toString(), lastLoginCheck);
}

String getNamiApiCookie() {
  return Hive.box('settingsBox').get(SettingValue.namiApiCookie.toString()) ??
      '';
}

DateTime getLastLoginCheck() {
  return Hive.box('settingsBox').get(SettingValue.lastLoginCheck.toString()) ??
      DateTime.utc(1989, 1, 1);
}

DateTime getNextStufenwechselDatum() {
  DateTime now = DateTime.now();
  DateTime safedStufenwechselDatum =
      Hive.box('settingsBox').get(SettingValue.stufenwechselDatum.toString()) ??
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

int? getGruppierungId() {
  return Hive.box('settingsBox').get(SettingValue.gruppierungId.toString());
}

String? getGruppierungName() {
  return Hive.box('settingsBox').get(SettingValue.gruppierungName.toString());
}

int? getNamiLoginId() {
  return Hive.box('settingsBox').get(SettingValue.namiLoginId.toString());
}

String? getNamiPassword() {
  return Hive.box('settingsBox').get(SettingValue.namiPassword.toString());
}

String getNamiLUrl() {
  return 'https://nami.dpsg.de';
}

String getNamiPath() {
  return Hive.box('settingsBox').get(SettingValue.namiPath.toString()) ??
      '/ica/rest/api/1/1/service/nami';
}

DateTime getLastNamiSync() {
  return Hive.box('settingsBox').get(SettingValue.lastNamiSync.toString()) ??
      DateTime.utc(1989, 1, 1);
}

void deleteNamiApiCookie() {
  Hive.box('settingsBox').delete(SettingValue.namiApiCookie.toString());
}

void deleteLastLoginCheck() {
  Hive.box('settingsBox').delete(SettingValue.lastLoginCheck.toString());
}

void deleteLastNamiSync() {
  Hive.box('settingsBox').delete(SettingValue.lastNamiSync.toString());
}

void deleteNamiLoginId() {
  Hive.box('settingsBox').delete(SettingValue.namiLoginId.toString());
}

void deleteNamiPassword() {
  Hive.box('settingsBox').delete(SettingValue.namiPassword.toString());
}

void deleteGruppierungId() {
  Hive.box('settingsBox').delete(SettingValue.gruppierungId.toString());
}

void deleteGruppierungName() {
  Hive.box('settingsBox').delete(SettingValue.gruppierungName.toString());
}

void deleteStufenwechselDatum() {
  Hive.box('settingsBox').delete(SettingValue.stufenwechselDatum.toString());
}

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

Box box = Hive.box('settingsBox');

void setMetaData(
    List<String> geschlecht,
    List<String> land,
    List<String> region,
    List<String> beitragsart,
    List<String> staatsangehoerigkeit,
    List<String> mitgliedstyp) {
  box.put(SettingValue.metaGeschechtOptions.toString(), geschlecht);
  box.put(SettingValue.metaLandOptions.toString(), land);
  box.put(SettingValue.metaBeitragsartOptions.toString(), beitragsart);
  box.put(SettingValue.metaRegionOptions.toString(), region);
  box.put(SettingValue.metaStaatsangehoerigkeitOptions.toString(),
      staatsangehoerigkeit);
  box.put(SettingValue.metaMitgliedstypOptions.toString(), mitgliedstyp);
}

List<String> getMetaGeschlechtOptions() {
  return box.get(SettingValue.metaGeschechtOptions.toString()) ?? [];
}

List<String> getMetaLandOptions() {
  return box.get(SettingValue.metaLandOptions.toString()) ?? [];
}

List<String> getMetaBeitragsartOptions() {
  return box.get(SettingValue.metaBeitragsartOptions.toString()) ?? [];
}

List<String> getMetaRegionOptions() {
  return box.get(SettingValue.metaRegionOptions.toString()) ?? [];
}

List<String> getMetaStaatsangehoerigkeitOptions() {
  return box.get(SettingValue.metaStaatsangehoerigkeitOptions.toString()) ?? [];
}

List<String> getMetaMitgliedstypOptions() {
  return box.get(SettingValue.metaMitgliedstypOptions.toString()) ?? [];
}

void setNamiApiCookie(String namiApiToken) {
  box.put(SettingValue.namiApiCookie.toString(), namiApiToken);
}

void setStufenwechselDatum(DateTime stufenwechselDatum) {
  box.put(SettingValue.stufenwechselDatum.toString(), stufenwechselDatum);
}

void setNamiLoginId(int loginId) async {
  box.put(SettingValue.namiLoginId.toString(), loginId);
}

void setNamiPassword(String password) async {
  box.put(SettingValue.namiPassword.toString(), password);
}

void setNamiUrl(String url) async {
  box.put(SettingValue.namiUrl.toString(), url);
}

void setNamiPath(String path) async {
  box.put(SettingValue.namiPath.toString(), path);
}

void setGruppierungId(int gruppierung) {
  box.put(SettingValue.gruppierungId.toString(), gruppierung);
}

void setGruppierungName(String gruppierungName) {
  box.put(SettingValue.gruppierungName.toString(), gruppierungName);
}

void setLastNamiSync(DateTime lastNamiSync) {
  box.put(SettingValue.lastNamiSync.toString(), lastNamiSync);
}

void setLastLoginCheck(DateTime lastLoginCheck) {
  box.put(SettingValue.lastLoginCheck.toString(), lastLoginCheck);
}

String getNamiApiCookie() {
  return box.get(SettingValue.namiApiCookie.toString()) ?? '';
}

DateTime getLastLoginCheck() {
  return box.get(SettingValue.lastLoginCheck.toString()) ??
      DateTime.utc(1989, 1, 1);
}

DateTime getNextStufenwechselDatum() {
  DateTime now = DateTime.now();
  DateTime safedStufenwechselDatum =
      box.get(SettingValue.stufenwechselDatum.toString()) ??
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
  return box.get(SettingValue.gruppierungId.toString());
}

String? getGruppierungName() {
  return box.get(SettingValue.gruppierungName.toString());
}

int? getNamiLoginId() {
  return box.get(SettingValue.namiLoginId.toString());
}

String? getNamiPassword() {
  return box.get(SettingValue.namiPassword.toString());
}

String getNamiLUrl() {
  return 'https://nami.dpsg.de';
}

String getNamiPath() {
  return box.get(SettingValue.namiPath.toString()) ??
      '/ica/rest/api/1/1/service/nami';
}

DateTime? getLastNamiSync() {
  return box.get(SettingValue.lastNamiSync.toString()) ??
      DateTime.utc(1989, 1, 1);
}

void deleteNamiApiCookie() {
  box.delete(SettingValue.namiApiCookie.toString());
}

void deleteLastLoginCheck() {
  box.delete(SettingValue.lastLoginCheck.toString());
}

void deleteLastNamiSync() {
  box.delete(SettingValue.lastNamiSync.toString());
}

void deleteNamiLoginId() {
  box.delete(SettingValue.namiLoginId.toString());
}

void deleteNamiPassword() {
  box.delete(SettingValue.namiPassword.toString());
}

void deleteGruppierungId() {
  box.delete(SettingValue.gruppierungId.toString());
}

void deleteGruppierungName() {
  box.delete(SettingValue.gruppierungName.toString());
}

void deleteStufenwechselDatum() {
  box.delete(SettingValue.stufenwechselDatum.toString());
}

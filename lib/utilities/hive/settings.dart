import 'package:hive/hive.dart';

// flutter packages pub run build_runner build
enum SettingValue {
  namiApiCookie,
  namiLoginId,
  namiPassword,
  namiUrl,
  namiPath,
  gruppierung,
  lastNamiSync,
  lastLoginCheck
}

Box box = Hive.box('settingsBox');

void setNamiApiCookie(String namiApiToken) {
  box.put(SettingValue.namiApiCookie.toString(), namiApiToken);
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

void setGruppierung(int gruppierung) {
  box.put(SettingValue.gruppierung.toString(), gruppierung);
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

int? getGruppierung() {
  return box.get(SettingValue.gruppierung.toString());
}

int? getNamiLoginId() {
  return box.get(SettingValue.namiLoginId.toString());
}

String? getNamiPassword() {
  return box.get(SettingValue.namiPassword.toString());
}

String getNamiLUrl() {
  return box.get(SettingValue.namiUrl.toString()) ?? 'https://nami.dpsg.de';
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

void deleteGruppierung() {
  box.delete(SettingValue.gruppierung.toString());
}

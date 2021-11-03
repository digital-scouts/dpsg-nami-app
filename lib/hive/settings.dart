import 'package:hive/hive.dart';

// flutter packages pub run build_runner build
enum SettingValue {
  namiApiCookie,
  namiLoginId,
  namiPassword,
  namiUrl,
  namiPath,
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

String? getNamiApiCookie() {
  return box.get(SettingValue.namiApiCookie.toString());
}

int? getNamiLoginId() {
  return box.get(SettingValue.namiLoginId.toString());
}

String? getNamiPassword() {
  return box.get(SettingValue.namiPassword.toString());
}

String getNamiLUrl() {
  return box.get(SettingValue.namiUrl.toString());
}

String getNamiPath() {
  return box.get(SettingValue.namiPath.toString());
}

void deleteNamiApiCookie() {
  box.delete(SettingValue.namiApiCookie.toString());
}

void deleteNamiLoginId() {
  box.delete(SettingValue.namiLoginId.toString());
}

void deleteNamiPassword() {
  box.delete(SettingValue.namiPassword.toString());
}

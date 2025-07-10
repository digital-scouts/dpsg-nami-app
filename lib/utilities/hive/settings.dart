import 'package:flutter/material.dart';
import 'package:hive_ce/hive.dart';
import 'package:nami/utilities/stufe.dart';

// flutter packages pub run build_runner build
enum SettingValue {
  namiApiCookie,
  namiLoginId,
  loggedInUserId,
  namiPassword,
  namiUrl,
  namiPath,
  gruppierungId,
  gruppierungName,
  lastNamiSync,
  lastNamiSyncTry,
  lastLoginCheck,
  syncDataLoadingOverWifiOnly,
  stammheim,
  welcomeMessageShown,
  favouriteList,
  metaGeschechtOptions,
  metaLandOptions,
  metaBeitragsartOptions,
  metaRegionOptions,
  metaStaatsangehoerigkeitOptions,
  metaMitgliedstypOptions,
  metaKonfessionOptions,
  metaErsteTaetigkeitOptions,
  biometricAuthenticationEnabled,
  namiChangesEnabled,
  rechte,
  mapTileCachingEnabled,
  lastAppVerion,
  newVersionInfoShown,
  themeMode,
  isTestDevice,
  geburtstagsbenachrichtigungen,
  benachrichtigungenActive,
  benachrichtigungsZeit,
}

enum GeburtstagsbenachrichtigungenGruppen { favouriten }

void setMetaData(
  Map<String, String> geschlecht,
  Map<String, String> land,
  Map<String, String> region,
  Map<String, String> beitragsart,
  Map<String, String> staatsangehoerigkeit,
  Map<String, String> mitgliedstyp,
  Map<String, String> konfession,
  Map<String, String> ersteTaetigkeit,
) {
  settingsBox.put(SettingValue.metaGeschechtOptions.toString(), geschlecht);
  settingsBox.put(SettingValue.metaLandOptions.toString(), land);
  settingsBox.put(SettingValue.metaBeitragsartOptions.toString(), beitragsart);
  settingsBox.put(SettingValue.metaRegionOptions.toString(), region);
  settingsBox.put(
    SettingValue.metaStaatsangehoerigkeitOptions.toString(),
    staatsangehoerigkeit,
  );
  settingsBox.put(
    SettingValue.metaMitgliedstypOptions.toString(),
    mitgliedstyp,
  );
  settingsBox.put(SettingValue.metaKonfessionOptions.toString(), konfession);
  settingsBox.put(
    SettingValue.metaErsteTaetigkeitOptions.toString(),
    ersteTaetigkeit,
  );
}

Box get settingsBox => Hive.box('settingsBox');

bool getWelcomeMessageShown() {
  return settingsBox.get(SettingValue.welcomeMessageShown.toString()) ?? false;
}

Map<String, String> getMetaGeschlechtOptions() {
  final dynamicMap =
      settingsBox.get(SettingValue.metaGeschechtOptions.toString()) ?? {};
  return Map<String, String>.from(dynamicMap);
}

Map<String, String> getMetaLandOptions() {
  final dynamicMap =
      settingsBox.get(SettingValue.metaLandOptions.toString()) ?? {};
  return Map<String, String>.from(dynamicMap);
}

Map<String, String> getMetaBeitragsartOptions() {
  final dynamicMap =
      settingsBox.get(SettingValue.metaBeitragsartOptions.toString()) ?? {};
  return Map<String, String>.from(dynamicMap);
}

Map<String, String> getMetaRegionOptions() {
  final dynamicMap =
      settingsBox.get(SettingValue.metaRegionOptions.toString()) ?? {};
  return Map<String, String>.from(dynamicMap);
}

Map<String, String> getMetaStaatsangehoerigkeitOptions() {
  final dynamicMap =
      settingsBox.get(
        SettingValue.metaStaatsangehoerigkeitOptions.toString(),
      ) ??
      {};
  return Map<String, String>.from(dynamicMap);
}

Map<String, String> getMetaKonfessionOptions() {
  final dynamicMap =
      settingsBox.get(SettingValue.metaKonfessionOptions.toString()) ?? {};
  return Map<String, String>.from(dynamicMap);
}

Map<String, String> getErsteTaetigkeitOptions() {
  final dynamicMap =
      settingsBox.get(SettingValue.metaErsteTaetigkeitOptions.toString()) ?? {};
  return Map<String, String>.from(dynamicMap);
}

Map<String, String> getMetaMitgliedstypOptions() {
  final dynamicMap =
      settingsBox.get(SettingValue.metaMitgliedstypOptions.toString()) ?? {};
  return Map<String, String>.from(dynamicMap);
}

List<int> getFavouriteList() {
  return settingsBox.get(SettingValue.favouriteList.toString()) ?? [];
}

bool getBiometricAuthenticationEnabled() {
  return settingsBox.get(
        SettingValue.biometricAuthenticationEnabled.toString(),
      ) ??
      false;
}

bool getNamiChangesEnabled() {
  return settingsBox.get(SettingValue.namiChangesEnabled.toString()) ?? false;
}

void setNamiChangesEnabled(bool value) {
  settingsBox.put(SettingValue.namiChangesEnabled.toString(), value);
}

List<int> getRechte() {
  return settingsBox.get(SettingValue.rechte.toString()) ?? [];
}

int addFavouriteList(int id) {
  List<int> favouritList =
      settingsBox.get(SettingValue.favouriteList.toString()) ?? [];
  favouritList.add(id);
  settingsBox.put(SettingValue.favouriteList.toString(), favouritList);
  return id;
}

void removeFavouriteList(int id) {
  List<int> favouritList =
      settingsBox.get(SettingValue.favouriteList.toString()) ?? [];
  favouritList.remove(id);
  settingsBox.put(SettingValue.favouriteList.toString(), favouritList);
}

void setFavouriteList(List<int> favouritList) {
  settingsBox.put(SettingValue.favouriteList.toString(), favouritList);
}

void setWelcomeMessageShown(bool value) {
  settingsBox.put(SettingValue.welcomeMessageShown.toString(), value);
}

void setNamiApiCookie(String namiApiToken) {
  settingsBox.put(SettingValue.namiApiCookie.toString(), namiApiToken);
}

void setStammheim(String stammheim) {
  if (stammheim.isEmpty) {
    settingsBox.delete(SettingValue.stammheim.toString());
    return;
  }
  settingsBox.put(SettingValue.stammheim.toString(), stammheim);
}

void setNamiLoginId(int loginId) async {
  settingsBox.put(SettingValue.namiLoginId.toString(), loginId);
}

void setLoggedInUserId(int userId) async {
  settingsBox.put(SettingValue.loggedInUserId.toString(), userId);
}

void setNamiPassword(String password) async {
  settingsBox.put(SettingValue.namiPassword.toString(), password);
}

void setNamiUrl(String url) async {
  settingsBox.put(SettingValue.namiUrl.toString(), url);
}

void setNamiPath(String path) async {
  settingsBox.put(SettingValue.namiPath.toString(), path);
}

void setGruppierungId(int gruppierung) {
  settingsBox.put(SettingValue.gruppierungId.toString(), gruppierung);
}

void setGruppierungName(String gruppierungName) {
  settingsBox.put(SettingValue.gruppierungName.toString(), gruppierungName);
}

void setLastNamiSync(DateTime lastNamiSync) {
  settingsBox.put(SettingValue.lastNamiSync.toString(), lastNamiSync);
}

void setLastNamiSyncTry(DateTime lastNamiSyncTry) {
  settingsBox.put(SettingValue.lastNamiSyncTry.toString(), lastNamiSyncTry);
}

void setLastLoginCheck(DateTime lastLoginCheck) {
  settingsBox.put(SettingValue.lastLoginCheck.toString(), lastLoginCheck);
}

void setDataLoadingOverWifiOnly(bool value) {
  settingsBox.put(SettingValue.syncDataLoadingOverWifiOnly.toString(), value);
}

void setBiometricAuthenticationEnabled(bool value) {
  settingsBox.put(
    SettingValue.biometricAuthenticationEnabled.toString(),
    value,
  );
}

void setRechte(List<int> rechte) {
  settingsBox.put(SettingValue.rechte.toString(), rechte);
}

String getNamiApiCookie() {
  return settingsBox.get(SettingValue.namiApiCookie.toString()) ?? '';
}

DateTime getLastLoginCheck() {
  return settingsBox.get(SettingValue.lastLoginCheck.toString()) ??
      DateTime.utc(1989, 1, 1);
}

bool getDataLoadingOverWifiOnly() {
  return settingsBox.get(SettingValue.syncDataLoadingOverWifiOnly.toString()) ??
      true;
}

String? getStammheim() {
  return settingsBox.get(SettingValue.stammheim.toString());
}

int? getGruppierungId() {
  return settingsBox.get(SettingValue.gruppierungId.toString());
}

String? getGruppierungName() {
  return settingsBox.get(SettingValue.gruppierungName.toString());
}

int? getNamiLoginId() {
  return settingsBox.get(SettingValue.namiLoginId.toString());
}

int? getLoggedInUserId() {
  return settingsBox.get(SettingValue.loggedInUserId.toString());
}

String? getNamiPassword() {
  return settingsBox.get(SettingValue.namiPassword.toString());
}

String getNamiLUrl() {
  return 'https://nami.dpsg.de';
}

String getNamiPath() {
  return settingsBox.get(SettingValue.namiPath.toString()) ??
      '/ica/rest/api/1/1/service/nami';
}

DateTime getLastNamiSync() {
  return settingsBox.get(SettingValue.lastNamiSync.toString()) ??
      DateTime.utc(1989, 1, 1);
}

DateTime getLastNamiSyncTry() {
  return settingsBox.get(SettingValue.lastNamiSyncTry.toString()) ??
      DateTime.utc(1989, 1, 1);
}

void deleteNamiApiCookie() {
  settingsBox.delete(SettingValue.namiApiCookie.toString());
}

void deleteLastLoginCheck() {
  settingsBox.delete(SettingValue.lastLoginCheck.toString());
}

void deleteLastNamiSync() {
  settingsBox.delete(SettingValue.lastNamiSync.toString());
}

void deleteLastNamiSyncTry() {
  settingsBox.delete(SettingValue.lastNamiSyncTry.toString());
}

void deleteNamiLoginId() {
  settingsBox.delete(SettingValue.namiLoginId.toString());
}

void deleteLoggedInUserId() {
  settingsBox.delete(SettingValue.loggedInUserId.toString());
}

void deleteNamiPassword() {
  settingsBox.delete(SettingValue.namiPassword.toString());
}

void deleteGruppierungId() {
  settingsBox.delete(SettingValue.gruppierungId.toString());
}

void deleteGruppierungName() {
  settingsBox.delete(SettingValue.gruppierungName.toString());
}

void enableMapTileCaching() {
  settingsBox.put(SettingValue.mapTileCachingEnabled.toString(), true);
}

bool isMapTileCachingEnabled() {
  return settingsBox.get(SettingValue.mapTileCachingEnabled.toString()) ??
      false;
}

bool isNewVersionInfoShown() {
  return settingsBox.get(SettingValue.newVersionInfoShown.toString()) ?? false;
}

String getLastAppVersion() {
  return settingsBox.get(SettingValue.lastAppVerion.toString()) ?? '';
}

void setLastAppVersion(String version) {
  settingsBox.put(SettingValue.lastAppVerion.toString(), version);
}

void setNewVersionInfoShown(bool value) {
  settingsBox.put(SettingValue.newVersionInfoShown.toString(), value);
}

void setThemeMode(ThemeMode mode) {
  settingsBox.put(SettingValue.themeMode.toString(), mode.index);
}

ThemeMode getThemeMode() {
  return ThemeMode.values[settingsBox.get(SettingValue.themeMode.toString()) ??
      ThemeMode.system.index];
}

void setIsTestDevice(bool value) {
  settingsBox.put(SettingValue.isTestDevice.toString(), value);
}

bool getIsTestDevice() {
  return settingsBox.get(SettingValue.isTestDevice.toString()) ?? false;
}

void setBenachrichtigungenActive(bool value) {
  settingsBox.put(SettingValue.benachrichtigungenActive.toString(), value);
}

bool getBenachrichtigungenActive() {
  return settingsBox.get(SettingValue.benachrichtigungenActive.toString()) ??
      true;
}

void setBenachrichtungsZeitpunkt(BenachrichtigungsZeit zeit) {
  settingsBox.put(
    SettingValue.benachrichtigungsZeit.toString(),
    zeit.displayName,
  );
}

BenachrichtigungsZeit getBenachrichtigungsZeitpunkt() {
  final String? zeitName = settingsBox.get(
    SettingValue.benachrichtigungsZeit.toString(),
  );
  if (zeitName == null) return BenachrichtigungsZeit.morgens;
  return BenachrichtigungsZeit.values.firstWhere(
    (zeit) => zeit.displayName == zeitName,
    orElse: () => BenachrichtigungsZeit.morgens,
  );
}

enum BenachrichtigungsZeit {
  vorabend('Vorabend', 0, 20, -1),
  morgens('Morgens', 1, 10, 0),
  mittag('Mittags', 2, 13, 0);

  const BenachrichtigungsZeit(
    this.displayName,
    this.i,
    this.stunde,
    this.tageOffset,
  );
  final String displayName;
  final int i;
  final int stunde;
  final int tageOffset; // -1 für Vorabend, 0 für am Tag selbst
}

void setGeburtstagsbenachrichtigungenGruppen(List<Stufe> value) {
  List<int> gruppenIndices = value.map((e) => e.index).toList();

  settingsBox.put(
    SettingValue.geburtstagsbenachrichtigungen.toString(),
    gruppenIndices,
  );
}

List<Stufe> getGeburtstagsbenachrichtigungenGruppen() {
  final dynamicList =
      settingsBox.get(SettingValue.geburtstagsbenachrichtigungen.toString()) ??
      [
        Stufe.BIBER.index,
        Stufe.WOELFLING.index,
        Stufe.JUNGPADFINDER.index,
        Stufe.PFADFINDER.index,
        Stufe.ROVER.index,
        Stufe.LEITER.index,
      ];
  // Stelle sicher, dass dynamicList eine List<int> ist
  final List<int> indices = List<int>.from(dynamicList);
  return indices
      .map((e) => Stufe.getStufeByOrder(e))
      .whereType<Stufe>()
      .toList();
}

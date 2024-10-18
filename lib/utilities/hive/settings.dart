import 'package:flutter/material.dart';
import 'package:hive_ce/hive.dart';
import 'package:nami/utilities/mitglied.filterAndSort.dart';

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
  listSortBy,
  listFilterInactive,
  listFilterPassive,
  listSubtext,
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
}

void setMetaData(
    Map<String, String> geschlecht,
    Map<String, String> land,
    Map<String, String> region,
    Map<String, String> beitragsart,
    Map<String, String> staatsangehoerigkeit,
    Map<String, String> mitgliedstyp,
    Map<String, String> konfession,
    Map<String, String> ersteTaetigkeit) {
  settingsBox.put(SettingValue.metaGeschechtOptions.toString(), geschlecht);
  settingsBox.put(SettingValue.metaLandOptions.toString(), land);
  settingsBox.put(SettingValue.metaBeitragsartOptions.toString(), beitragsart);
  settingsBox.put(SettingValue.metaRegionOptions.toString(), region);
  settingsBox.put(SettingValue.metaStaatsangehoerigkeitOptions.toString(),
      staatsangehoerigkeit);
  settingsBox.put(
      SettingValue.metaMitgliedstypOptions.toString(), mitgliedstyp);
  settingsBox.put(SettingValue.metaKonfessionOptions.toString(), konfession);
  settingsBox.put(
      SettingValue.metaErsteTaetigkeitOptions.toString(), ersteTaetigkeit);
}

Box get settingsBox => Hive.box('settingsBox');

MemberSorting getListSort() {
  String? sortingString = settingsBox.get(SettingValue.listSortBy.toString());
  return MemberSorting.values.firstWhere(
    (e) => e.toString() == sortingString,
    orElse: () => MemberSorting.name,
  );
}

MemberSubElement getListSubtext() {
  String? subElementString =
      settingsBox.get(SettingValue.listSubtext.toString());
  return MemberSubElement.values.firstWhere(
    (e) => e.toString() == subElementString,
    orElse: () => MemberSubElement.id,
  );
}

bool getListFilterInactive() {
  return settingsBox.get(SettingValue.listFilterInactive.toString()) ?? true;
}

bool getListFilterPassive() {
  return settingsBox.get(SettingValue.listFilterPassive.toString()) ?? false;
}

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
  final dynamicMap = settingsBox
          .get(SettingValue.metaStaatsangehoerigkeitOptions.toString()) ??
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
  return settingsBox
          .get(SettingValue.biometricAuthenticationEnabled.toString()) ??
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

void setListSort(MemberSorting value) {
  settingsBox.put(SettingValue.listSortBy.toString(), value.toString());
}

void setListFilterInactive(bool value) {
  settingsBox.put(SettingValue.listFilterInactive.toString(), value);
}

void setListFilterPassive(bool value) {
  settingsBox.put(SettingValue.listFilterPassive.toString(), value);
}

void setListSubtext(MemberSubElement value) {
  settingsBox.put(SettingValue.listSubtext.toString(), value.toString());
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
      SettingValue.biometricAuthenticationEnabled.toString(), value);
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

void deleteListSort() {
  settingsBox.delete(SettingValue.listSortBy.toString());
}

void deleteListSubtext() {
  settingsBox.delete(SettingValue.listSubtext.toString());
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

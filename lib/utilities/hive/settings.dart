import 'package:hive/hive.dart';
import 'package:nami/utilities/mitglied.filterAndSort.dart';

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
  lastNamiSyncTry,
  lastLoginCheck,
  syncDataLoadingOverWifiOnly,
  stammheim,
  welcomeMessageShown,
  favouriteList,
  listSortBy,
  listFilterInactive,
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
}

void setMetaData(
    List<String> geschlecht,
    List<String> land,
    List<String> region,
    List<String> beitragsart,
    List<String> staatsangehoerigkeit,
    List<String> mitgliedstyp,
    List<String> konfession,
    List<String> ersteTaetigkeit) {
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

bool getWelcomeMessageShown() {
  return settingsBox.get(SettingValue.welcomeMessageShown.toString()) ?? false;
}

List<String> getMetaGeschlechtOptions() {
  return settingsBox.get(SettingValue.metaGeschechtOptions.toString()) ?? [];
}

List<String> getMetaLandOptions() {
  return settingsBox.get(SettingValue.metaLandOptions.toString()) ?? [];
}

List<String> getMetaBeitragsartOptions() {
  return settingsBox.get(SettingValue.metaBeitragsartOptions.toString()) ?? [];
}

List<String> getMetaRegionOptions() {
  return settingsBox.get(SettingValue.metaRegionOptions.toString()) ?? [];
}

List<String> getMetaStaatsangehoerigkeitOptions() {
  return settingsBox
          .get(SettingValue.metaStaatsangehoerigkeitOptions.toString()) ??
      [];
}

List<String> getMetaKonfessionOptions() {
  return settingsBox.get(SettingValue.metaKonfessionOptions.toString()) ?? [];
}

List<String> getErsteTaetigkeitOptions() {
  return settingsBox.get(SettingValue.metaErsteTaetigkeitOptions.toString()) ??
      [];
}

List<String> getMetaMitgliedstypOptions() {
  return settingsBox.get(SettingValue.metaMitgliedstypOptions.toString()) ?? [];
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

void deleteListFilterInactive() {
  settingsBox.delete(SettingValue.listFilterInactive.toString());
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

void deleteNamiPassword() {
  settingsBox.delete(SettingValue.namiPassword.toString());
}

void deleteGruppierungId() {
  settingsBox.delete(SettingValue.gruppierungId.toString());
}

void deleteGruppierungName() {
  settingsBox.delete(SettingValue.gruppierungName.toString());
}

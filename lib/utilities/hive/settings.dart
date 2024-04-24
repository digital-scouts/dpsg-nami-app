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
  stufenwechselDatum,
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
  biometricAuthenticationEnabled,
  rechte,
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

MemberSorting getListSort() {
  String? sortingString =
      Hive.box('settingsBox').get(SettingValue.listSortBy.toString());
  return MemberSorting.values.firstWhere(
    (e) => e.toString() == sortingString,
    orElse: () => MemberSorting.name,
  );
}

MemberSubElement getListSubtext() {
  String? subElementString =
      Hive.box('settingsBox').get(SettingValue.listSubtext.toString());
  return MemberSubElement.values.firstWhere(
    (e) => e.toString() == subElementString,
    orElse: () => MemberSubElement.id,
  );
}

bool getListFilterInactive() {
  return Hive.box('settingsBox')
          .get(SettingValue.listFilterInactive.toString()) ??
      true;
}

bool getWelcomeMessageShown() {
  return Hive.box('settingsBox')
          .get(SettingValue.welcomeMessageShown.toString()) ??
      false;
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

List<int> getFavouriteList() {
  return Hive.box('settingsBox').get(SettingValue.favouriteList.toString()) ??
      [];
}

bool getBiometricAuthenticationEnabled() {
  return Hive.box('settingsBox')
          .get(SettingValue.biometricAuthenticationEnabled.toString()) ??
      false;
}

List<int> getRechte() {
  return Hive.box('settingsBox').get(SettingValue.rechte.toString()) ?? [];
}

int addFavouriteList(int id) {
  List<int> favouritList =
      Hive.box('settingsBox').get(SettingValue.favouriteList.toString()) ?? [];
  favouritList.add(id);
  Hive.box('settingsBox')
      .put(SettingValue.favouriteList.toString(), favouritList);
  return id;
}

void setListSort(MemberSorting value) {
  Hive.box('settingsBox')
      .put(SettingValue.listSortBy.toString(), value.toString());
}

void setListFilterInactive(bool value) {
  Hive.box('settingsBox')
      .put(SettingValue.listFilterInactive.toString(), value);
}

void setListSubtext(MemberSubElement value) {
  Hive.box('settingsBox')
      .put(SettingValue.listSubtext.toString(), value.toString());
}

void removeFavouriteList(int id) {
  List<int> favouritList =
      Hive.box('settingsBox').get(SettingValue.favouriteList.toString()) ?? [];
  favouritList.remove(id);
  Hive.box('settingsBox')
      .put(SettingValue.favouriteList.toString(), favouritList);
}

void setFavouriteList(List<int> favouritList) {
  Hive.box('settingsBox')
      .put(SettingValue.favouriteList.toString(), favouritList);
}

void setWelcomeMessageShown(bool value) {
  Hive.box('settingsBox')
      .put(SettingValue.welcomeMessageShown.toString(), value);
}

void setNamiApiCookie(String namiApiToken) {
  Hive.box('settingsBox')
      .put(SettingValue.namiApiCookie.toString(), namiApiToken);
}

void setStufenwechselDatum(DateTime stufenwechselDatum) {
  Hive.box('settingsBox')
      .put(SettingValue.stufenwechselDatum.toString(), stufenwechselDatum);
}

void setStammheim(String stammheim) {
  if (stammheim.isEmpty) {
    Hive.box('settingsBox').delete(SettingValue.stammheim.toString());
    return;
  }
  Hive.box('settingsBox').put(SettingValue.stammheim.toString(), stammheim);
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

void setLastNamiSyncTry(DateTime lastNamiSyncTry) {
  Hive.box('settingsBox')
      .put(SettingValue.lastNamiSyncTry.toString(), lastNamiSyncTry);
}

void setLastLoginCheck(DateTime lastLoginCheck) {
  Hive.box('settingsBox')
      .put(SettingValue.lastLoginCheck.toString(), lastLoginCheck);
}

void setDataLoadingOverWifiOnly(bool value) {
  Hive.box('settingsBox')
      .put(SettingValue.syncDataLoadingOverWifiOnly.toString(), value);
}

void setBiometricAuthenticationEnabled(bool value) {
  Hive.box('settingsBox')
      .put(SettingValue.biometricAuthenticationEnabled.toString(), value);
}

void setRechte(List<int> rechte) {
  Hive.box('settingsBox').put(SettingValue.rechte.toString(), rechte);
}

String getNamiApiCookie() {
  return Hive.box('settingsBox').get(SettingValue.namiApiCookie.toString()) ??
      '';
}

DateTime getLastLoginCheck() {
  return Hive.box('settingsBox').get(SettingValue.lastLoginCheck.toString()) ??
      DateTime.utc(1989, 1, 1);
}

bool getDataLoadingOverWifiOnly() {
  return Hive.box('settingsBox')
          .get(SettingValue.syncDataLoadingOverWifiOnly.toString()) ??
      true;
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

String? getStammheim() {
  return Hive.box('settingsBox').get(SettingValue.stammheim.toString());
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

DateTime getLastNamiSyncTry() {
  return Hive.box('settingsBox').get(SettingValue.lastNamiSyncTry.toString()) ??
      DateTime.utc(1989, 1, 1);
}

void deleteListSort() {
  Hive.box('settingsBox').delete(SettingValue.listSortBy.toString());
}

void deleteListFilterInactive() {
  Hive.box('settingsBox').delete(SettingValue.listFilterInactive.toString());
}

void deleteListSubtext() {
  Hive.box('settingsBox').delete(SettingValue.listSubtext.toString());
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

void deleteLastNamiSyncTry() {
  Hive.box('settingsBox').delete(SettingValue.lastNamiSyncTry.toString());
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

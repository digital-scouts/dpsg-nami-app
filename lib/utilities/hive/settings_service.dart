import 'package:flutter/material.dart';
import 'package:hive_ce/hive.dart';
import 'package:nami/utilities/stufe.dart';

// Enum für Settings-Werte
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
  lastAppVersion,
  newVersionInfoShown,
  themeMode,
  isTestDevice,
  geburtstagsbenachrichtigungen,
  benachrichtigungenActive,
  benachrichtigungsZeit,
}

enum GeburtstagsbenachrichtigungenGruppen { favouriten }

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

// Abstrakte Klasse für Settings-Service
abstract class SettingsService {
  // Getter für Box
  Box get settingsBox;

  // Metadata methods
  void setMetaData(
    Map<String, String> geschlecht,
    Map<String, String> land,
    Map<String, String> region,
    Map<String, String> beitragsart,
    Map<String, String> staatsangehoerigkeit,
    Map<String, String> mitgliedstyp,
    Map<String, String> konfession,
    Map<String, String> ersteTaetigkeit,
  );

  // Getter methods
  bool getWelcomeMessageShown();
  Map<String, String> getMetaGeschlechtOptions();
  Map<String, String> getMetaLandOptions();
  Map<String, String> getMetaBeitragsartOptions();
  Map<String, String> getMetaRegionOptions();
  Map<String, String> getMetaStaatsangehoerigkeitOptions();
  Map<String, String> getMetaKonfessionOptions();
  Map<String, String> getErsteTaetigkeitOptions();
  Map<String, String> getMetaMitgliedstypOptions();
  List<int> getFavouriteList();
  bool getBiometricAuthenticationEnabled();
  bool getNamiChangesEnabled();
  List<int> getRechte();
  String getNamiApiCookie();
  DateTime getLastLoginCheck();
  bool getDataLoadingOverWifiOnly();
  String? getStammheim();
  int? getGruppierungId();
  String? getGruppierungName();
  int? getNamiLoginId();
  int? getLoggedInUserId();
  String? getNamiPassword();
  String getNamiLUrl();
  String getNamiPath();
  DateTime getLastNamiSync();
  DateTime getLastNamiSyncTry();
  bool isMapTileCachingEnabled();
  bool isNewVersionInfoShown();
  String getLastAppVersion();
  ThemeMode getThemeMode();
  bool getIsTestDevice();
  bool getBenachrichtigungenActive();
  BenachrichtigungsZeit getBenachrichtigungsZeitpunkt();
  List<Stufe> getGeburtstagsbenachrichtigungenGruppen();

  // Setter methods
  void setWelcomeMessageShown(bool value);
  void setNamiApiCookie(String namiApiToken);
  void setStammheim(String stammheim);
  void setNamiLoginId(int loginId);
  void setLoggedInUserId(int userId);
  void setNamiPassword(String password);
  void setNamiUrl(String url);
  void setNamiPath(String path);
  void setGruppierungId(int gruppierung);
  void setGruppierungName(String gruppierungName);
  void setLastNamiSync(DateTime lastNamiSync);
  void setLastNamiSyncTry(DateTime lastNamiSyncTry);
  void setLastLoginCheck(DateTime lastLoginCheck);
  void setDataLoadingOverWifiOnly(bool value);
  void setBiometricAuthenticationEnabled(bool value);
  void setRechte(List<int> rechte);
  void setNamiChangesEnabled(bool value);
  void setLastAppVersion(String version);
  void setNewVersionInfoShown(bool value);
  void setThemeMode(ThemeMode mode);
  void setIsTestDevice(bool value);
  void setBenachrichtigungenActive(bool value);
  void setBenachrichtungsZeitpunkt(BenachrichtigungsZeit zeit);
  void setGeburtstagsbenachrichtigungenGruppen(List<Stufe> value);

  // Favourite list methods
  int addFavouriteList(int id);
  void removeFavouriteList(int id);
  void setFavouriteList(List<int> favouritList);

  // Delete methods
  void deleteNamiApiCookie();
  void deleteLastLoginCheck();
  void deleteLastNamiSync();
  void deleteLastNamiSyncTry();
  void deleteNamiLoginId();
  void deleteLoggedInUserId();
  void deleteNamiPassword();
  void deleteGruppierungId();
  void deleteGruppierungName();

  // Map tile caching
  void enableMapTileCaching();
}

// Konkrete Implementierung für echte Hive-Box
class HiveSettingsService implements SettingsService {
  final Box _settingsBox;

  HiveSettingsService(this._settingsBox);

  @override
  Box get settingsBox => _settingsBox;

  @override
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
    settingsBox.put(
      SettingValue.metaBeitragsartOptions.toString(),
      beitragsart,
    );
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

  @override
  bool getWelcomeMessageShown() {
    return settingsBox.get(SettingValue.welcomeMessageShown.toString()) ??
        false;
  }

  @override
  Map<String, String> getMetaGeschlechtOptions() {
    final dynamicMap =
        settingsBox.get(SettingValue.metaGeschechtOptions.toString()) ?? {};
    return Map<String, String>.from(dynamicMap);
  }

  @override
  Map<String, String> getMetaLandOptions() {
    final dynamicMap =
        settingsBox.get(SettingValue.metaLandOptions.toString()) ?? {};
    return Map<String, String>.from(dynamicMap);
  }

  @override
  Map<String, String> getMetaBeitragsartOptions() {
    final dynamicMap =
        settingsBox.get(SettingValue.metaBeitragsartOptions.toString()) ?? {};
    return Map<String, String>.from(dynamicMap);
  }

  @override
  Map<String, String> getMetaRegionOptions() {
    final dynamicMap =
        settingsBox.get(SettingValue.metaRegionOptions.toString()) ?? {};
    return Map<String, String>.from(dynamicMap);
  }

  @override
  Map<String, String> getMetaStaatsangehoerigkeitOptions() {
    final dynamicMap =
        settingsBox.get(
          SettingValue.metaStaatsangehoerigkeitOptions.toString(),
        ) ??
        {};
    return Map<String, String>.from(dynamicMap);
  }

  @override
  Map<String, String> getMetaKonfessionOptions() {
    final dynamicMap =
        settingsBox.get(SettingValue.metaKonfessionOptions.toString()) ?? {};
    return Map<String, String>.from(dynamicMap);
  }

  @override
  Map<String, String> getErsteTaetigkeitOptions() {
    final dynamicMap =
        settingsBox.get(SettingValue.metaErsteTaetigkeitOptions.toString()) ??
        {};
    return Map<String, String>.from(dynamicMap);
  }

  @override
  Map<String, String> getMetaMitgliedstypOptions() {
    final dynamicMap =
        settingsBox.get(SettingValue.metaMitgliedstypOptions.toString()) ?? {};
    return Map<String, String>.from(dynamicMap);
  }

  @override
  List<int> getFavouriteList() {
    return settingsBox.get(SettingValue.favouriteList.toString()) ?? [];
  }

  @override
  bool getBiometricAuthenticationEnabled() {
    return settingsBox.get(
          SettingValue.biometricAuthenticationEnabled.toString(),
        ) ??
        false;
  }

  @override
  bool getNamiChangesEnabled() {
    return settingsBox.get(SettingValue.namiChangesEnabled.toString()) ?? false;
  }

  @override
  List<int> getRechte() {
    return settingsBox.get(SettingValue.rechte.toString()) ?? [];
  }

  @override
  String getNamiApiCookie() {
    return settingsBox.get(SettingValue.namiApiCookie.toString()) ?? '';
  }

  @override
  DateTime getLastLoginCheck() {
    return settingsBox.get(SettingValue.lastLoginCheck.toString()) ??
        DateTime.utc(1989, 1, 1);
  }

  @override
  bool getDataLoadingOverWifiOnly() {
    return settingsBox.get(
          SettingValue.syncDataLoadingOverWifiOnly.toString(),
        ) ??
        true;
  }

  @override
  String? getStammheim() {
    return settingsBox.get(SettingValue.stammheim.toString());
  }

  @override
  int? getGruppierungId() {
    return settingsBox.get(SettingValue.gruppierungId.toString());
  }

  @override
  String? getGruppierungName() {
    return settingsBox.get(SettingValue.gruppierungName.toString());
  }

  @override
  int? getNamiLoginId() {
    return settingsBox.get(SettingValue.namiLoginId.toString());
  }

  @override
  int? getLoggedInUserId() {
    return settingsBox.get(SettingValue.loggedInUserId.toString());
  }

  @override
  String? getNamiPassword() {
    return settingsBox.get(SettingValue.namiPassword.toString());
  }

  @override
  String getNamiLUrl() {
    return 'https://nami.dpsg.de';
  }

  @override
  String getNamiPath() {
    return settingsBox.get(SettingValue.namiPath.toString()) ??
        '/ica/rest/api/1/1/service/nami';
  }

  @override
  DateTime getLastNamiSync() {
    return settingsBox.get(SettingValue.lastNamiSync.toString()) ??
        DateTime.utc(1989, 1, 1);
  }

  @override
  DateTime getLastNamiSyncTry() {
    return settingsBox.get(SettingValue.lastNamiSyncTry.toString()) ??
        DateTime.utc(1989, 1, 1);
  }

  @override
  bool isMapTileCachingEnabled() {
    return settingsBox.get(SettingValue.mapTileCachingEnabled.toString()) ??
        false;
  }

  @override
  bool isNewVersionInfoShown() {
    return settingsBox.get(SettingValue.newVersionInfoShown.toString()) ??
        false;
  }

  @override
  String getLastAppVersion() {
    return settingsBox.get(SettingValue.lastAppVersion.toString()) ?? '';
  }

  @override
  ThemeMode getThemeMode() {
    return ThemeMode.values[settingsBox.get(
          SettingValue.themeMode.toString(),
        ) ??
        ThemeMode.system.index];
  }

  @override
  bool getIsTestDevice() {
    return settingsBox.get(SettingValue.isTestDevice.toString()) ?? false;
  }

  @override
  bool getBenachrichtigungenActive() {
    return settingsBox.get(SettingValue.benachrichtigungenActive.toString()) ??
        true;
  }

  @override
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

  @override
  List<Stufe> getGeburtstagsbenachrichtigungenGruppen() {
    final dynamicList =
        settingsBox.get(
          SettingValue.geburtstagsbenachrichtigungen.toString(),
        ) ??
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

  // Setter methods
  @override
  void setWelcomeMessageShown(bool value) {
    settingsBox.put(SettingValue.welcomeMessageShown.toString(), value);
  }

  @override
  void setNamiApiCookie(String namiApiToken) {
    settingsBox.put(SettingValue.namiApiCookie.toString(), namiApiToken);
  }

  @override
  void setStammheim(String stammheim) {
    if (stammheim.isEmpty) {
      settingsBox.delete(SettingValue.stammheim.toString());
      return;
    }
    settingsBox.put(SettingValue.stammheim.toString(), stammheim);
  }

  @override
  void setNamiLoginId(int loginId) {
    settingsBox.put(SettingValue.namiLoginId.toString(), loginId);
  }

  @override
  void setLoggedInUserId(int userId) {
    settingsBox.put(SettingValue.loggedInUserId.toString(), userId);
  }

  @override
  void setNamiPassword(String password) {
    settingsBox.put(SettingValue.namiPassword.toString(), password);
  }

  @override
  void setNamiUrl(String url) {
    settingsBox.put(SettingValue.namiUrl.toString(), url);
  }

  @override
  void setNamiPath(String path) {
    settingsBox.put(SettingValue.namiPath.toString(), path);
  }

  @override
  void setGruppierungId(int gruppierung) {
    settingsBox.put(SettingValue.gruppierungId.toString(), gruppierung);
  }

  @override
  void setGruppierungName(String gruppierungName) {
    settingsBox.put(SettingValue.gruppierungName.toString(), gruppierungName);
  }

  @override
  void setLastNamiSync(DateTime lastNamiSync) {
    settingsBox.put(SettingValue.lastNamiSync.toString(), lastNamiSync);
  }

  @override
  void setLastNamiSyncTry(DateTime lastNamiSyncTry) {
    settingsBox.put(SettingValue.lastNamiSyncTry.toString(), lastNamiSyncTry);
  }

  @override
  void setLastLoginCheck(DateTime lastLoginCheck) {
    settingsBox.put(SettingValue.lastLoginCheck.toString(), lastLoginCheck);
  }

  @override
  void setDataLoadingOverWifiOnly(bool value) {
    settingsBox.put(SettingValue.syncDataLoadingOverWifiOnly.toString(), value);
  }

  @override
  void setBiometricAuthenticationEnabled(bool value) {
    settingsBox.put(
      SettingValue.biometricAuthenticationEnabled.toString(),
      value,
    );
  }

  @override
  void setRechte(List<int> rechte) {
    settingsBox.put(SettingValue.rechte.toString(), rechte);
  }

  @override
  void setNamiChangesEnabled(bool value) {
    settingsBox.put(SettingValue.namiChangesEnabled.toString(), value);
  }

  @override
  void setLastAppVersion(String version) {
    settingsBox.put(SettingValue.lastAppVersion.toString(), version);
  }

  @override
  void setNewVersionInfoShown(bool value) {
    settingsBox.put(SettingValue.newVersionInfoShown.toString(), value);
  }

  @override
  void setThemeMode(ThemeMode mode) {
    settingsBox.put(SettingValue.themeMode.toString(), mode.index);
  }

  @override
  void setIsTestDevice(bool value) {
    settingsBox.put(SettingValue.isTestDevice.toString(), value);
  }

  @override
  void setBenachrichtigungenActive(bool value) {
    settingsBox.put(SettingValue.benachrichtigungenActive.toString(), value);
  }

  @override
  void setBenachrichtungsZeitpunkt(BenachrichtigungsZeit zeit) {
    settingsBox.put(
      SettingValue.benachrichtigungsZeit.toString(),
      zeit.displayName,
    );
  }

  @override
  void setGeburtstagsbenachrichtigungenGruppen(List<Stufe> value) {
    List<int> gruppenIndices = value.map((e) => e.index).toList();
    settingsBox.put(
      SettingValue.geburtstagsbenachrichtigungen.toString(),
      gruppenIndices,
    );
  }

  // Favourite list methods
  @override
  int addFavouriteList(int id) {
    List<int> favouritList =
        settingsBox.get(SettingValue.favouriteList.toString()) ?? [];
    favouritList.add(id);
    settingsBox.put(SettingValue.favouriteList.toString(), favouritList);
    return id;
  }

  @override
  void removeFavouriteList(int id) {
    List<int> favouritList =
        settingsBox.get(SettingValue.favouriteList.toString()) ?? [];
    favouritList.remove(id);
    settingsBox.put(SettingValue.favouriteList.toString(), favouritList);
  }

  @override
  void setFavouriteList(List<int> favouritList) {
    settingsBox.put(SettingValue.favouriteList.toString(), favouritList);
  }

  // Delete methods
  @override
  void deleteNamiApiCookie() {
    settingsBox.delete(SettingValue.namiApiCookie.toString());
  }

  @override
  void deleteLastLoginCheck() {
    settingsBox.delete(SettingValue.lastLoginCheck.toString());
  }

  @override
  void deleteLastNamiSync() {
    settingsBox.delete(SettingValue.lastNamiSync.toString());
  }

  @override
  void deleteLastNamiSyncTry() {
    settingsBox.delete(SettingValue.lastNamiSyncTry.toString());
  }

  @override
  void deleteNamiLoginId() {
    settingsBox.delete(SettingValue.namiLoginId.toString());
  }

  @override
  void deleteLoggedInUserId() {
    settingsBox.delete(SettingValue.loggedInUserId.toString());
  }

  @override
  void deleteNamiPassword() {
    settingsBox.delete(SettingValue.namiPassword.toString());
  }

  @override
  void deleteGruppierungId() {
    settingsBox.delete(SettingValue.gruppierungId.toString());
  }

  @override
  void deleteGruppierungName() {
    settingsBox.delete(SettingValue.gruppierungName.toString());
  }

  @override
  void enableMapTileCaching() {
    settingsBox.put(SettingValue.mapTileCachingEnabled.toString(), true);
  }
}

// Globale Instanz des Settings-Service
late SettingsService settingsService;

// Initialisierung für Production
void initializeSettingsService() {
  settingsService = HiveSettingsService(Hive.box('settingsBox'));
}

// Rückwärtskompatibilität - Wrapper-Funktionen für die bestehende API
void setMetaData(
  Map<String, String> geschlecht,
  Map<String, String> land,
  Map<String, String> region,
  Map<String, String> beitragsart,
  Map<String, String> staatsangehoerigkeit,
  Map<String, String> mitgliedstyp,
  Map<String, String> konfession,
  Map<String, String> ersteTaetigkeit,
) => settingsService.setMetaData(
  geschlecht,
  land,
  region,
  beitragsart,
  staatsangehoerigkeit,
  mitgliedstyp,
  konfession,
  ersteTaetigkeit,
);

Box get _settingsBox => settingsService.settingsBox;
bool getWelcomeMessageShown() => settingsService.getWelcomeMessageShown();
Map<String, String> getMetaGeschlechtOptions() =>
    settingsService.getMetaGeschlechtOptions();
Map<String, String> getMetaLandOptions() =>
    settingsService.getMetaLandOptions();
Map<String, String> getMetaBeitragsartOptions() =>
    settingsService.getMetaBeitragsartOptions();
Map<String, String> getMetaRegionOptions() =>
    settingsService.getMetaRegionOptions();
Map<String, String> getMetaStaatsangehoerigkeitOptions() =>
    settingsService.getMetaStaatsangehoerigkeitOptions();
Map<String, String> getMetaKonfessionOptions() =>
    settingsService.getMetaKonfessionOptions();
Map<String, String> getErsteTaetigkeitOptions() =>
    settingsService.getErsteTaetigkeitOptions();
Map<String, String> getMetaMitgliedstypOptions() =>
    settingsService.getMetaMitgliedstypOptions();
List<int> getFavouriteList() => settingsService.getFavouriteList();
bool getBiometricAuthenticationEnabled() =>
    settingsService.getBiometricAuthenticationEnabled();
bool getNamiChangesEnabled() => settingsService.getNamiChangesEnabled();
List<int> getRechte() => settingsService.getRechte();
String getNamiApiCookie() => settingsService.getNamiApiCookie();
DateTime getLastLoginCheck() => settingsService.getLastLoginCheck();
bool getDataLoadingOverWifiOnly() =>
    settingsService.getDataLoadingOverWifiOnly();
String? getStammheim() => settingsService.getStammheim();
int? getGruppierungId() => settingsService.getGruppierungId();
String? getGruppierungName() => settingsService.getGruppierungName();
int? getNamiLoginId() => settingsService.getNamiLoginId();
int? getLoggedInUserId() => settingsService.getLoggedInUserId();
String? getNamiPassword() => settingsService.getNamiPassword();
String getNamiLUrl() => settingsService.getNamiLUrl();
String getNamiPath() => settingsService.getNamiPath();
DateTime getLastNamiSync() => settingsService.getLastNamiSync();
DateTime getLastNamiSyncTry() => settingsService.getLastNamiSyncTry();
bool isMapTileCachingEnabled() => settingsService.isMapTileCachingEnabled();
bool isNewVersionInfoShown() => settingsService.isNewVersionInfoShown();
String getLastAppVersion() => settingsService.getLastAppVersion();
ThemeMode getThemeMode() => settingsService.getThemeMode();
bool getIsTestDevice() => settingsService.getIsTestDevice();
bool getBenachrichtigungenActive() =>
    settingsService.getBenachrichtigungenActive();
BenachrichtigungsZeit getBenachrichtigungsZeitpunkt() =>
    settingsService.getBenachrichtigungsZeitpunkt();
List<Stufe> getGeburtstagsbenachrichtigungenGruppen() =>
    settingsService.getGeburtstagsbenachrichtigungenGruppen();

// Setter Wrapper
void setWelcomeMessageShown(bool value) =>
    settingsService.setWelcomeMessageShown(value);
void setNamiApiCookie(String namiApiToken) =>
    settingsService.setNamiApiCookie(namiApiToken);
void setStammheim(String stammheim) => settingsService.setStammheim(stammheim);
void setNamiLoginId(int loginId) => settingsService.setNamiLoginId(loginId);
void setLoggedInUserId(int userId) => settingsService.setLoggedInUserId(userId);
void setNamiPassword(String password) =>
    settingsService.setNamiPassword(password);
void setNamiUrl(String url) => settingsService.setNamiUrl(url);
void setNamiPath(String path) => settingsService.setNamiPath(path);
void setGruppierungId(int gruppierung) =>
    settingsService.setGruppierungId(gruppierung);
void setGruppierungName(String gruppierungName) =>
    settingsService.setGruppierungName(gruppierungName);
void setLastNamiSync(DateTime lastNamiSync) =>
    settingsService.setLastNamiSync(lastNamiSync);
void setLastNamiSyncTry(DateTime lastNamiSyncTry) =>
    settingsService.setLastNamiSyncTry(lastNamiSyncTry);
void setLastLoginCheck(DateTime lastLoginCheck) =>
    settingsService.setLastLoginCheck(lastLoginCheck);
void setDataLoadingOverWifiOnly(bool value) =>
    settingsService.setDataLoadingOverWifiOnly(value);
void setBiometricAuthenticationEnabled(bool value) =>
    settingsService.setBiometricAuthenticationEnabled(value);
void setRechte(List<int> rechte) => settingsService.setRechte(rechte);
void setNamiChangesEnabled(bool value) =>
    settingsService.setNamiChangesEnabled(value);
void setLastAppVersion(String version) =>
    settingsService.setLastAppVersion(version);
void setNewVersionInfoShown(bool value) =>
    settingsService.setNewVersionInfoShown(value);
void setThemeMode(ThemeMode mode) => settingsService.setThemeMode(mode);
void setIsTestDevice(bool value) => settingsService.setIsTestDevice(value);
void setBenachrichtigungenActive(bool value) =>
    settingsService.setBenachrichtigungenActive(value);
void setBenachrichtungsZeitpunkt(BenachrichtigungsZeit zeit) =>
    settingsService.setBenachrichtungsZeitpunkt(zeit);
void setGeburtstagsbenachrichtigungenGruppen(List<Stufe> value) =>
    settingsService.setGeburtstagsbenachrichtigungenGruppen(value);

// Favourite list wrappers
int addFavouriteList(int id) => settingsService.addFavouriteList(id);
void removeFavouriteList(int id) => settingsService.removeFavouriteList(id);
void setFavouriteList(List<int> favouritList) =>
    settingsService.setFavouriteList(favouritList);

// Delete wrappers
void deleteNamiApiCookie() => settingsService.deleteNamiApiCookie();
void deleteLastLoginCheck() => settingsService.deleteLastLoginCheck();
void deleteLastNamiSync() => settingsService.deleteLastNamiSync();
void deleteLastNamiSyncTry() => settingsService.deleteLastNamiSyncTry();
void deleteNamiLoginId() => settingsService.deleteNamiLoginId();
void deleteLoggedInUserId() => settingsService.deleteLoggedInUserId();
void deleteNamiPassword() => settingsService.deleteNamiPassword();
void deleteGruppierungId() => settingsService.deleteGruppierungId();
void deleteGruppierungName() => settingsService.deleteGruppierungName();
void enableMapTileCaching() => settingsService.enableMapTileCaching();

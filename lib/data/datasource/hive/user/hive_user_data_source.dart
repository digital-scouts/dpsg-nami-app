import 'package:hive_ce_flutter/hive_flutter.dart';

import 'user.data.dart';

class HiveUserDataSource implements UserDataSource {
  final Box _settingsBox;

  HiveUserDataSource(this._settingsBox);

  static const _keyCookie = 'namiApiCookie';
  static const _keyUserId = 'loggedInUserId';
  static const _keyLoginId = 'namiLoginId';
  static const _keyPassword = 'namiPassword';

  @override
  int? getLoggedInUserId() {
    return _settingsBox.get(_keyUserId);
  }

  @override
  String getNamiApiCookie() {
    return _settingsBox.get(_keyCookie) ?? '';
  }

  @override
  int? getNamiLoginId() {
    return _settingsBox.get(_keyLoginId);
  }

  @override
  String? getNamiPassword() {
    return _settingsBox.get(_keyPassword);
  }

  @override
  void setLoggedInUserId(int userId) {
    _settingsBox.put(_keyUserId, userId);
  }

  @override
  void setNamiApiCookie(String namiApiToken) {
    _settingsBox.put(_keyCookie, namiApiToken);
  }

  @override
  void setNamiLoginId(int loginId) {
    _settingsBox.put(_keyLoginId, loginId);
  }

  @override
  void setNamiPassword(String password) {
    _settingsBox.put(_keyPassword, password);
  }

  @override
  void deleteLoggedInUserId() {
    _settingsBox.delete(_keyUserId);
  }

  @override
  void deleteNamiApiCookie() {
    _settingsBox.delete(_keyCookie);
  }

  @override
  void deleteNamiLoginId() {
    _settingsBox.delete(_keyLoginId);
  }

  @override
  void deleteNamiPassword() {
    _settingsBox.delete(_keyPassword);
  }
}

abstract class UserDataSource {
  String getNamiApiCookie();
  void setNamiApiCookie(String namiApiToken);
  void deleteNamiApiCookie();

  int? getNamiLoginId();
  void setNamiLoginId(int loginId);
  void deleteNamiLoginId();

  int? getLoggedInUserId();
  void setLoggedInUserId(int userId);
  void deleteLoggedInUserId();

  String? getNamiPassword();
  void setNamiPassword(String password);
  void deleteNamiPassword();
}

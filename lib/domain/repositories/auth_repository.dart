abstract class AuthRepository {
  Future<void> login(int userId, String password, {bool rememberMe = false});
  Future<void> testLogin();
  Future<void> logout();
  Future<bool> isLoggedIn();
  int? getSavedLoginId();
}

import 'package:nami/data/datasource/hive/user/user.data.dart';
import 'package:nami/data/datasource/nami/login.api.dart';
import 'package:nami/domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  final LoginApi loginApi;
  final UserDataSource userData;

  AuthRepositoryImpl(this.loginApi, this.userData);

  @override
  Future<void> login(
    int userId,
    String password, {
    bool rememberMe = false,
  }) async {
    final cookie = await loginApi.loginWithPassword(userId, password);
    userData.setNamiApiCookie(cookie);
    userData.setLoggedInUserId(userId);

    if (rememberMe) {
      userData.setNamiLoginId(userId);
      userData.setNamiPassword(password);
    } else {
      userData.deleteNamiLoginId();
      userData.deleteNamiPassword();
    }
  }

  @override
  Future<void> testLogin() async {
    userData.setNamiApiCookie('testLoginCookie');
    userData.setLoggedInUserId(1234);
  }

  @override
  Future<void> logout() async {
    userData.deleteNamiApiCookie();
    // userData.deleteLoggedInUserId();
    userData.deleteNamiLoginId();
    userData.deleteNamiPassword();
  }

  @override
  Future<bool> isLoggedIn() async {
    return userData.getNamiApiCookie().isNotEmpty;
  }

  @override
  int? getSavedLoginId() {
    return userData.getLoggedInUserId();
  }
}

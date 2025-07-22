abstract class AppException implements Exception {
  final String message;
  AppException(this.message);
}

class LoginFailedException extends AppException {
  LoginFailedException(super.message);
}

class NetworkException extends AppException {
  NetworkException(super.message);
}

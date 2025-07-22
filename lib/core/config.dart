class ApiConfig {
  static const String baseUrl = 'https://nami.dpsg.de';
  static const String basePath = '/ica/rest/api/1/1/service/nami';
  static const String loginPath = '/auth/manual/sessionStartup';

  static const Map<String, String> defaultHeaders = {
    "Host": 'nami.dpsg.de',
    "Origin": 'https://nami.dpsg.de',
    "Content-Type": 'application/x-www-form-urlencoded',
  };
}

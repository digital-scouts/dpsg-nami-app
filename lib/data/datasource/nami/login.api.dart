import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:nami/core/config.dart';
import 'package:nami/core/exceptions/app_exception.dart';

class LoginApi {
  Future<String> loginWithPassword(int userId, String password) async {
    // 1. Initial Login-Request
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}${ApiConfig.basePath}${ApiConfig.loginPath}',
    );
    final body = {
      'username': userId.toString(),
      'password': password,
      'Login': 'API',
    };

    final authResponse = await http.post(
      uri,
      body: body,
      headers: ApiConfig.defaultHeaders,
    );

    final statusCode = authResponse.statusCode;

    if (statusCode != 302 && statusCode != 200) {
      throw NetworkException('Login fehlgeschlagen mit Status $statusCode');
    }

    // 2. Redirect-Handling
    http.Response tokenResponse;
    if (statusCode == 302 &&
        authResponse.headers['location']?.isNotEmpty == true) {
      String redirectLocation = authResponse.headers['location']!;
      if (redirectLocation.startsWith('http://')) {
        redirectLocation = redirectLocation.replaceFirst('http://', 'https://');
      }
      final redirectUri = Uri.parse(redirectLocation);
      tokenResponse = await http.get(redirectUri);
    } else {
      tokenResponse = authResponse;
    }

    // 3. Cookie prüfen
    final cookie = tokenResponse.headers["set-cookie"]?.split(';').first;
    if (tokenResponse.statusCode != 200 || cookie == null) {
      throw LoginFailedException('Token oder Cookie fehlt');
    }

    final resBody = json.decode(tokenResponse.body);
    if (resBody['statusCode'] != 0 ||
        resBody['statusMessage']?.isNotEmpty == true) {
      throw LoginFailedException(resBody['statusMessage']);
    }

    return cookie;
  }
}

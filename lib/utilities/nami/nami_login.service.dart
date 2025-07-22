import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:nami/utilities/hive/settings.dart';
import 'package:nami/utilities/logger.dart';
import 'package:wiredash/wiredash.dart';

import 'nami.service.dart';

/// prüft anhand eines Test-Requests, ob der Nutzer eingeloggt ist.
Future<bool> isLoggedIn() async {
  //check if token exists
  String? token = getNamiApiCookie();
  if (token.isEmpty) {
    return false;
  }

  //check if token is valid
  try {
    await loadNamiStats();
  } catch (ex) {
    return false;
  }

  setLastLoginCheck(DateTime.now());
  return true;
}

/// Versucht ein Login mit ID und Passwort. True wenn erfolgreich.
Future<bool> namiLoginWithPassword(int userId, String password) async {
  if (userId == 1234 && password == 'test') {
    setNamiApiCookie('testLoginCookie');
    setLastLoginCheck(DateTime.now());
    return true;
  }
  String url = getNamiLUrl();
  String path = getNamiPath();

  // login
  Uri uri = Uri.parse('$url$path/auth/manual/sessionStartup');
  Map<String, String> body = {
    'username': userId.toString(),
    'password': password,
    'Login': 'API',
  };
  Map<String, String> headers = {
    "Host": 'nami.dpsg.de',
    "Origin": 'https://nami.dpsg.de',
    'Content-Type': 'application/x-www-form-urlencoded',
  };
  sensLog.i('Request: login for ${sensId(userId)} request to $uri');
  final authResponse = await http.post(uri, body: body, headers: headers);

  final statusCode = authResponse.statusCode;
  if (statusCode != 302 && statusCode != 200) {
    sensLog.e(
      'Failed to login for ${sensId(userId)} with status code: $statusCode: ${authResponse.body}',
    );
    return false;
  }

  http.Response tokenResponse;
  if (statusCode == 302 && authResponse.headers['location']!.isNotEmpty) {
    //redirect
    Uri redirectUri = Uri.parse(authResponse.headers['location']!);
    sensLog.i('Request: login redirect request');
    tokenResponse = await http.get(redirectUri);
  } else {
    tokenResponse = authResponse;
  }

  if (tokenResponse.statusCode != 200 ||
      !tokenResponse.headers.containsKey('set-cookie')) {
    sensLog.e(
      'Failed to login for ${sensId(userId)} with status code: ${tokenResponse.statusCode}',
    );
    return false;
  }
  final resBody = json.decode(tokenResponse.body);
  if (resBody['statusCode'] != 0 || resBody['statusMessage'].length > 0) {
    sensLog.e(
      'Failed to login for ${sensId(userId)} with status code: ${resBody['statusCode']}: ${resBody['statusMessage']}',
    );
    return false;
  }
  String cookie = tokenResponse.headers["set-cookie"]!.split(';')[0];
  setNamiApiCookie(cookie);
  setLastLoginCheck(DateTime.now());
  sensLog.i('Success: login for ${sensId(userId)}');
  Wiredash.trackEvent('Nami Login successfull');
  return true;
}

Future<bool> updateLoginData() async {
  int? loginId = getNamiLoginId();
  String? password = getNamiPassword();
  if (loginId != null && password != null) {
    return await namiLoginWithPassword(loginId, password);
  }
  return false;
}

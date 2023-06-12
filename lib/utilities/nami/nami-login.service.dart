import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:nami/utilities/hive/settings.dart';

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
  String url = getNamiLUrl();
  String path = getNamiPath();

  // login
  Uri uri = Uri.parse('$url$path/auth/manual/sessionStartup');
  Map<String, String> body = {
    'username': userId.toString(),
    'password': password,
    'Login': 'API'
  };
  Map<String, String> headers = {
    "Host": 'nami.dpsg.de',
    "Origin": 'https://nami.dpsg.de',
    'Content-Type': 'application/x-www-form-urlencoded',
  };
  debugPrint('Request: Auth Request');
  http.Response authResponse =
      await http.post(uri, body: body, headers: headers);

  if (authResponse.statusCode != 302 ||
      authResponse.headers['location']!.isEmpty) {
    return false;
  }

  //redirect
  Uri redirectUri = Uri.parse(authResponse.headers['location']!);
  debugPrint('Request: Auth redirect Request');
  http.Response tokenResponse = await http.get(redirectUri);

  if (tokenResponse.statusCode != 200 ||
      !tokenResponse.headers.containsKey('set-cookie')) {
    return false;
  }
  var resBody = json.decode(tokenResponse.body);
  if (resBody['statusCode'] != 0 || resBody['statusMessage'].length > 0) {
    return false;
  }
  String cookie = tokenResponse.headers["set-cookie"]!.split(';')[0];
  setNamiApiCookie(cookie);
  setLastLoginCheck(DateTime.now());
  return true;
}

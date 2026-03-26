import 'dart:convert';
import 'dart:math';

import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;

import '../domain/auth/auth_session.dart';
import 'hitobito_auth_env.dart';
import 'logger_service.dart';

class HitobitoAuthException implements Exception {
  const HitobitoAuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

class HitobitoOauthService {
  HitobitoOauthService({
    required this.config,
    http.Client? httpClient,
    DateTime Function()? nowProvider,
    LoggerService? logger,
  }) : _httpClient = httpClient ?? http.Client(),
       _now = nowProvider ?? DateTime.now,
       _logger = logger;

  final HitobitoAuthConfig config;
  final http.Client _httpClient;
  final DateTime Function() _now;
  final LoggerService? _logger;

  Future<AuthSession> authenticateInteractive() async {
    await _logger?.log('auth_oauth', 'Interaktiver OAuth-Login gestartet');

    if (!config.isConfigured) {
      throw const HitobitoAuthException(
        'OAuth ist nicht vollstaendig konfiguriert.',
      );
    }

    final state = _randomState();
    final authorizationUri = Uri.parse(config.authorizationUrl).replace(
      queryParameters: <String, String>{
        'client_id': config.clientId,
        'redirect_uri': config.redirectUri,
        'response_type': 'code',
        'scope': config.scopeString,
        'state': state,
      },
    );

    final callback = await FlutterWebAuth2.authenticate(
      url: authorizationUri.toString(),
      callbackUrlScheme: config.callbackScheme,
    );

    final callbackUri = Uri.parse(callback);
    final returnedState = callbackUri.queryParameters['state'];
    final error = callbackUri.queryParameters['error'];
    final errorDescription = callbackUri.queryParameters['error_description'];

    if (error != null && error.isNotEmpty) {
      throw HitobitoAuthException(errorDescription ?? error);
    }

    if (returnedState != state) {
      throw const HitobitoAuthException(
        'Ungueltiger OAuth-Status in der Rueckleitung.',
      );
    }

    final code = callbackUri.queryParameters['code'];
    if (code == null || code.isEmpty) {
      throw const HitobitoAuthException(
        'Kein Authorization Code in der Rueckleitung enthalten.',
      );
    }

    final tokenPayload = await _requestToken(<String, String>{
      'grant_type': 'authorization_code',
      'client_id': config.clientId,
      'client_secret': config.clientSecret,
      'redirect_uri': config.redirectUri,
      'code': code,
    });

    final session = _mapSession(tokenPayload);
    await _logger?.log('auth_oauth', 'OAuth-Login erfolgreich abgeschlossen');
    return session;
  }

  Future<AuthSession> refresh(AuthSession session) async {
    if (!session.canRefresh) {
      throw const HitobitoAuthException(
        'Fuer diese Session ist kein Refresh Token verfuegbar.',
      );
    }

    final tokenPayload = await _requestToken(<String, String>{
      'grant_type': 'refresh_token',
      'client_id': config.clientId,
      'client_secret': config.clientSecret,
      'refresh_token': session.refreshToken!,
    });

    final refreshed = _mapSession(tokenPayload, previous: session);
    return refreshed;
  }

  Future<AuthSession> refreshIfNeeded(
    AuthSession session, {
    Duration threshold = const Duration(minutes: 5),
  }) async {
    final expiresAt = session.expiresAt;
    if (expiresAt == null || !session.canRefresh) {
      return session;
    }

    if (expiresAt.difference(_now()) > threshold) {
      return session;
    }

    return refresh(session);
  }

  Future<Map<String, dynamic>> _requestToken(
    Map<String, String> payload,
  ) async {
    final response = await _httpClient.post(
      Uri.parse(config.tokenUrl),
      headers: const <String, String>{
        'Accept': 'application/json',
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: payload,
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HitobitoAuthException(
        'Token-Anfrage fehlgeschlagen (${response.statusCode}).',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const HitobitoAuthException(
        'Token-Antwort hat ein ungueltiges Format.',
      );
    }

    return decoded;
  }

  AuthSession _mapSession(
    Map<String, dynamic> tokenPayload, {
    AuthSession? previous,
  }) {
    final expiresInRaw = tokenPayload['expires_in'];
    final expiresIn = expiresInRaw is num
        ? expiresInRaw.toInt()
        : int.tryParse(expiresInRaw?.toString() ?? '');
    final receivedAt = _now();
    final idToken = tokenPayload['id_token']?.toString() ?? previous?.idToken;
    final idTokenClaims = _decodeJwtPayload(idToken);
    final scopeString = tokenPayload['scope']?.toString() ?? config.scopeString;

    return AuthSession(
      accessToken:
          tokenPayload['access_token']?.toString() ??
          previous?.accessToken ??
          '',
      refreshToken:
          tokenPayload['refresh_token']?.toString() ?? previous?.refreshToken,
      idToken: idToken,
      receivedAt: receivedAt,
      expiresAt: expiresIn != null
          ? receivedAt.add(Duration(seconds: expiresIn))
          : previous?.expiresAt,
      scopes: scopeString
          .split(RegExp(r'\s+'))
          .where((scope) => scope.isNotEmpty)
          .toList(),
      principal:
          idTokenClaims['sub']?.toString() ??
          previous?.principal ??
          idTokenClaims['preferred_username']?.toString(),
      email: idTokenClaims['email']?.toString() ?? previous?.email,
      displayName: idTokenClaims['name']?.toString() ?? previous?.displayName,
    );
  }

  Map<String, dynamic> _decodeJwtPayload(String? token) {
    if (token == null || token.isEmpty) {
      return const <String, dynamic>{};
    }

    final parts = token.split('.');
    if (parts.length < 2) {
      return const <String, dynamic>{};
    }

    try {
      final normalized = base64Url.normalize(parts[1]);
      final decoded = utf8.decode(base64Url.decode(normalized));
      final json = jsonDecode(decoded);
      if (json is Map<String, dynamic>) {
        return json;
      }
    } catch (_) {
      // Ignorieren: Claims sind optional fuer das lokale Session-Modell.
    }

    return const <String, dynamic>{};
  }

  String _randomState() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }
}

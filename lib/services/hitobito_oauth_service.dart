import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;

import '../domain/auth/auth_profile.dart';
import '../domain/auth/auth_session.dart';
import 'hitobito_auth_env.dart';
import 'hitobito_http_client.dart';
import 'logger_service.dart';

/// Was ein Fehler am Token-Endpunkt fuer die Sitzung bedeutet.
enum HitobitoAuthFehlerArt {
  /// Hitobito hat den Refresh-Token abgelehnt (`invalid_grant`), etwa nach
  /// einer Woche ohne Nutzung. Nur eine neue Anmeldung hilft.
  sitzungBeendet,

  /// Ueberlast oder Serverfehler (429, 5xx). Die Sitzung kann noch gueltig
  /// sein, ein spaeterer Versuch kann gelingen.
  voruebergehend,

  /// Client-ID oder Secret passen nicht (`invalid_client`). Auch eine neue
  /// Anmeldung hilft nicht.
  konfiguration,
}

class HitobitoAuthException implements Exception {
  const HitobitoAuthException(
    this.message, {
    this.statusCode,
    this.art,
    this.isExpectedInteractionFailure = false,
  });

  final String message;
  final int? statusCode;
  final HitobitoAuthFehlerArt? art;
  final bool isExpectedInteractionFailure;

  factory HitobitoAuthException.fromPlatformException(PlatformException error) {
    final code = error.code.toUpperCase();
    final message = error.message?.toLowerCase() ?? '';
    final isCanceled = code == 'CANCELED' || message.contains('cancel');

    if (isCanceled) {
      return const HitobitoAuthException(
        'Die Hitobito-Anmeldung wurde abgebrochen.',
        isExpectedInteractionFailure: true,
      );
    }

    return const HitobitoAuthException(
      'Die Hitobito-Anmeldung konnte nicht gestartet werden. Bitte pruefe die OAuth-Konfiguration.',
      isExpectedInteractionFailure: true,
    );
  }

  @override
  String toString() => message;
}

/// Öffnet die Anmeldeseite und liefert die Rückleitungs-URL.
typedef HitobitoWebAuthenticator =
    Future<String> Function({
      required String url,
      required String callbackUrlScheme,
    });

class HitobitoOauthService {
  HitobitoOauthService({
    required this.config,
    http.Client? httpClient,
    DateTime Function()? nowProvider,
    LoggerService? logger,
    HitobitoWebAuthenticator? webAuthenticator,
    Duration revokeTimeout = const Duration(seconds: 5),
  }) : _httpClient =
           httpClient ??
           HitobitoHttpClient(
             antwortZeitlimit: HitobitoHttpClient.anmeldungZeitlimit,
           ),
       _now = nowProvider ?? DateTime.now,
       _logger = logger,
       _webAuthenticator = webAuthenticator ?? _flutterWebAuth,
       _revokeTimeout = revokeTimeout;

  HitobitoAuthConfig config;
  final http.Client _httpClient;
  final DateTime Function() _now;
  final LoggerService? _logger;
  final HitobitoWebAuthenticator _webAuthenticator;
  final Duration _revokeTimeout;

  static Future<String> _flutterWebAuth({
    required String url,
    required String callbackUrlScheme,
  }) => FlutterWebAuth2.authenticate(
    url: url,
    callbackUrlScheme: callbackUrlScheme,
  );

  void updateConfig(HitobitoAuthConfig nextConfig) {
    config = nextConfig;
  }

  Future<AuthSession> authenticateInteractive() async {
    await _logger?.log('auth_oauth', 'Interaktiver OAuth-Login gestartet');

    if (!config.isConfigured) {
      throw const HitobitoAuthException(
        'OAuth ist nicht vollstaendig konfiguriert.',
      );
    }

    final state = _randomState();
    // PKCE (RFC 7636): Ein abgefangener Code ist ohne den Verifier wertlos.
    final codeVerifier = _randomState();
    final authorizationUri = Uri.parse(config.authorizationUrl).replace(
      queryParameters: <String, String>{
        'client_id': config.clientId,
        'redirect_uri': config.redirectUri,
        'response_type': 'code',
        'scope': config.scopeString,
        'state': state,
        'code_challenge': _codeChallenge(codeVerifier),
        'code_challenge_method': 'S256',
      },
    );

    final String callback;
    try {
      callback = await _webAuthenticator(
        url: authorizationUri.toString(),
        callbackUrlScheme: config.callbackScheme,
      );
    } on PlatformException catch (error) {
      throw HitobitoAuthException.fromPlatformException(error);
    } on MissingPluginException {
      throw const HitobitoAuthException(
        'Die Hitobito-Anmeldung konnte nicht gestartet werden. Bitte pruefe die OAuth-Konfiguration.',
        isExpectedInteractionFailure: true,
      );
    }

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
      'code_verifier': codeVerifier,
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

  /// Widerruft die Tokens der Sitzung bei Hitobito. Weil Access- und
  /// Refresh-Token einen gemeinsamen Datensatz bilden, reicht der
  /// Refresh-Token. Wirft nie; liefert `true`, wenn Hitobito bestätigt hat.
  Future<bool> revoke(AuthSession session) async {
    final token = (session.refreshToken?.isNotEmpty ?? false)
        ? session.refreshToken!
        : session.accessToken;
    final requestUri = Uri.tryParse(config.revokeUrl);
    if (token.isEmpty || requestUri == null || config.revokeUrl.isEmpty) {
      return false;
    }
    try {
      final response = await _httpClient
          .post(
            requestUri,
            headers: const <String, String>{
              'Accept': 'application/json',
              'Content-Type': 'application/x-www-form-urlencoded',
            },
            body: <String, String>{
              'token': token,
              'token_type_hint': token == session.refreshToken
                  ? 'refresh_token'
                  : 'access_token',
              'client_id': config.clientId,
              'client_secret': config.clientSecret,
            },
          )
          .timeout(_revokeTimeout);
      await _logger?.logHttpRequest(
        source: 'hitobito_revoke',
        method: 'POST',
        uri: requestUri,
        statusCode: response.statusCode,
      );
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (error) {
      await _logger?.logHttpRequest(
        source: 'hitobito_revoke',
        method: 'POST',
        uri: requestUri,
        error: error,
      );
      return false;
    }
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

  Future<AuthProfile> fetchProfile(AuthSession session) async {
    if (config.profileUrl.isEmpty) {
      throw const HitobitoAuthException(
        'Der Profil-Endpoint ist nicht konfiguriert.',
      );
    }

    final requestUri = Uri.parse(config.profileUrl);

    http.Response response;
    try {
      response = await _httpClient.get(
        requestUri,
        headers: <String, String>{
          'Accept': 'application/json',
          'Authorization': 'Bearer ${session.accessToken}',
          'X-Scope': 'with_roles',
        },
      );
    } catch (error) {
      await _logger?.logHttpRequest(
        source: 'hitobito_profile',
        method: 'GET',
        uri: requestUri,
        error: error,
      );
      rethrow;
    }

    await _logger?.logHttpRequest(
      source: 'hitobito_profile',
      method: 'GET',
      uri: requestUri,
      statusCode: response.statusCode,
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HitobitoAuthException(
        'Profil-Anfrage fehlgeschlagen (${response.statusCode}).',
        statusCode: response.statusCode,
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const HitobitoAuthException(
        'Profil-Antwort hat ein ungueltiges Format.',
      );
    }

    return AuthProfile.fromJson(decoded);
  }

  Future<Map<String, dynamic>> _requestToken(
    Map<String, String> payload,
  ) async {
    final requestUri = Uri.parse(config.tokenUrl);
    http.Response response;
    try {
      response = await _httpClient.post(
        requestUri,
        headers: const <String, String>{
          'Accept': 'application/json',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: payload,
      );
    } catch (error) {
      await _logger?.logHttpRequest(
        source: 'hitobito_token',
        method: 'POST',
        uri: requestUri,
        error: error,
      );
      rethrow;
    }

    await _logger?.logHttpRequest(
      source: 'hitobito_token',
      method: 'POST',
      uri: requestUri,
      statusCode: response.statusCode,
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final oauthFehler = _oauthFehlercode(response.body);
      throw HitobitoAuthException(
        oauthFehler == null
            ? 'Token-Anfrage fehlgeschlagen (${response.statusCode}).'
            : 'Token-Anfrage fehlgeschlagen (${response.statusCode}, $oauthFehler).',
        statusCode: response.statusCode,
        art: _fehlerArt(response.statusCode, oauthFehler),
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const HitobitoAuthException(
        'Token-Antwort hat ein ungültiges Format.',
      );
    }
    final accessToken = decoded['access_token'];
    if (accessToken is! String || accessToken.isEmpty) {
      throw const HitobitoAuthException('Token-Antwort ohne Zugangstoken.');
    }

    return decoded;
  }

  /// Doorkeeper beantwortet abgelaufene oder widerrufene Refresh-Tokens mit
  /// 400 `invalid_grant`; 401 gibt es nur bei `invalid_client`.
  static HitobitoAuthFehlerArt? _fehlerArt(
    int statusCode,
    String? oauthFehler,
  ) {
    if (oauthFehler == 'invalid_client') {
      return HitobitoAuthFehlerArt.konfiguration;
    }
    if (oauthFehler == 'invalid_grant' || statusCode == 401) {
      return HitobitoAuthFehlerArt.sitzungBeendet;
    }
    if (statusCode == 429 || statusCode >= 500) {
      return HitobitoAuthFehlerArt.voruebergehend;
    }
    return null;
  }

  static String? _oauthFehlercode(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final error = decoded['error'];
        return error is String && error.isNotEmpty ? error : null;
      }
    } on FormatException {
      // Kein JSON, etwa eine HTML-Fehlerseite eines Proxys.
    }
    return null;
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

  static String _codeChallenge(String verifier) {
    final digest = sha256.convert(ascii.encode(verifier));
    return base64UrlEncode(digest.bytes).replaceAll('=', '');
  }

  String _randomState() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }
}

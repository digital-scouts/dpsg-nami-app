import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nami/domain/auth/auth_session.dart';
import 'package:nami/services/hitobito_auth_env.dart';
import 'package:nami/services/hitobito_oauth_service.dart';

void main() {
  test('uebersetzt abgebrochenen OAuth-Login in fachliche Meldung', () {
    final error = HitobitoAuthException.fromPlatformException(
      PlatformException(code: 'CANCELED', message: 'User canceled login'),
    );

    expect(error.toString(), 'Die Hitobito-Anmeldung wurde abgebrochen.');
    expect(error.isExpectedInteractionFailure, isTrue);
  });

  test(
    'wertet technische OAuth-Plugin-Fehler als Fehlschlag, nicht als Abbruch',
    () {
      final error = HitobitoAuthException.fromPlatformException(
        PlatformException(
          code: 'ACTIVITY_NOT_FOUND',
          message: 'No activity found to handle intent',
        ),
      );

      expect(
        error.toString(),
        'Die Anmeldung konnte nicht gestartet werden. Bitte versuche es noch einmal.',
      );
      expect(error.plattformCode, 'ACTIVITY_NOT_FOUND');
      expect(error.isExpectedInteractionFailure, isFalse);
    },
  );

  test(
    'laedt /profile mit with_roles und mappt Rollen korrekt',
    () async {
      late Uri requestedUri;
      late Map<String, String> requestHeaders;

      final client = MockClient((request) async {
        requestedUri = request.url;
        requestHeaders = request.headers;

        return http.Response(
          '''
        {
          "id": 34,
          "primary_group_id": 1,
          "email": "julia@example.com",
          "first_name": "Julia",
          "last_name": "Keller",
          "nickname": "Polka",
          "language": "de",
          "roles": [
            {
              "group_id": 1,
              "group_name": "hitobito",
              "role_name": "Mitarbeiter*in GS",
              "role_class": "Group::Bund::MitarbeiterGs",
              "permissions": ["layer_and_below_full", "contact_data"]
            }
          ]
        }
        ''',
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      });

      final service = HitobitoOauthService(
        config: const HitobitoAuthConfig(
          clientId: 'client',
          clientSecret: 'secret',
          authorizationUrl: 'https://demo.hitobito.com/oauth/authorize',
          tokenUrl: 'https://demo.hitobito.com/oauth/token',
          redirectUri: 'de.jlange.nami.app:/oauth/callback',
          scopeString: 'openid email',
          discoveryUrl: '',
          profileUrl: 'https://demo.hitobito.com/oauth/profile',
        ),
        httpClient: client,
      );

      final profile = await service.fetchProfile(
        AuthSession(
          accessToken: 'token-123',
          receivedAt: DateTime(2026, 3, 27),
        ),
      );

      expect(
        requestedUri.toString(),
        'https://demo.hitobito.com/oauth/profile',
      );
      expect(requestHeaders['Authorization'], 'Bearer token-123');
      expect(requestHeaders['X-Scope'], 'with_roles');
      expect(profile.namiId, 34);
      expect(profile.primaryGroupId, 1);
      expect(profile.email, 'julia@example.com');
      expect(profile.primaryDisplayName, 'Polka');
      expect(profile.secondaryDisplayName, 'Julia Keller');
      expect(profile.normalizedLanguage, 'de');
      expect(profile.roles, hasLength(1));
      expect(profile.roles.single.roleName, 'Mitarbeiter*in GS');
      expect(profile.roles.single.groupName, 'hitobito');
      expect(profile.roles.single.permissions, <String>[
        'layer_and_below_full',
        'contact_data',
      ]);
    },
    timeout: const Timeout(Duration(seconds: 3)),
  );

  group('PKCE und Widerruf', () {
    const config = HitobitoAuthConfig(
      clientId: 'client',
      clientSecret: 'secret',
      authorizationUrl: 'https://demo.hitobito.com/oauth/authorize',
      tokenUrl: 'https://demo.hitobito.com/oauth/token',
      redirectUri: 'de.jlange.nami.app:/oauth/callback',
      scopeString: 'openid email',
      discoveryUrl: '',
      profileUrl: 'https://demo.hitobito.com/oauth/profile',
    );

    test('sendet Challenge beim Login und Verifier beim Code-Tausch', () async {
      late Uri anmeldeUrl;
      late Map<String, String> tokenBody;
      final service = HitobitoOauthService(
        config: config,
        nowProvider: () => DateTime(2026, 10, 7),
        webAuthenticator: ({required url, required callbackUrlScheme}) async {
          anmeldeUrl = Uri.parse(url);
          final state = anmeldeUrl.queryParameters['state'];
          return 'de.jlange.nami.app:/oauth/callback?code=abc&state=$state';
        },
        httpClient: MockClient((request) async {
          tokenBody = request.bodyFields;
          return http.Response(
            '{"access_token":"a","refresh_token":"r","expires_in":7200}',
            200,
          );
        }),
      );

      await service.authenticateInteractive();

      final challenge = anmeldeUrl.queryParameters['code_challenge']!;
      final verifier = tokenBody['code_verifier']!;
      expect(anmeldeUrl.queryParameters['code_challenge_method'], 'S256');
      expect(verifier.length, inInclusiveRange(43, 128));
      expect(
        challenge,
        base64UrlEncode(
          sha256.convert(ascii.encode(verifier)).bytes,
        ).replaceAll('=', ''),
      );
      expect(tokenBody['code'], 'abc');
    });

    test(
      'zeigt Fehlertext einer Rueckleitung nur mit gueltigem Status',
      () async {
        final service = HitobitoOauthService(
          config: config,
          webAuthenticator:
              ({required url, required callbackUrlScheme}) async =>
                  'de.jlange.nami.app:/oauth/callback?error=access_denied'
                  '&error_description=Bitte+Passwort+hier+eingeben&state=fremd',
          httpClient: MockClient((_) async => http.Response('', 500)),
        );

        await expectLater(
          service.authenticateInteractive(),
          throwsA(
            isA<HitobitoAuthException>().having(
              (error) => error.message,
              'message',
              'Ungültiger OAuth-Status in der Rückleitung.',
            ),
          ),
        );
      },
    );

    test('widerruft den Refresh-Token am Revoke-Endpunkt', () async {
      late http.Request anfrage;
      final service = HitobitoOauthService(
        config: config,
        httpClient: MockClient((request) async {
          anfrage = request;
          return http.Response('{}', 200);
        }),
      );

      final ok = await service.revoke(
        AuthSession(
          accessToken: 'a',
          refreshToken: 'r',
          receivedAt: DateTime(2026, 10, 7),
        ),
      );

      expect(ok, isTrue);
      expect(anfrage.url.toString(), 'https://demo.hitobito.com/oauth/revoke');
      expect(anfrage.bodyFields, <String, String>{
        'token': 'r',
        'token_type_hint': 'refresh_token',
        'client_id': 'client',
        'client_secret': 'secret',
      });
    });

    test('Widerruf wirft nicht bei Fehler oder Zeitueberschreitung', () async {
      final fehler = HitobitoOauthService(
        config: config,
        httpClient: MockClient((request) async => throw Exception('offline')),
      );
      final haengt = HitobitoOauthService(
        config: config,
        revokeTimeout: const Duration(milliseconds: 10),
        httpClient: MockClient((request) => Completer<http.Response>().future),
      );
      final session = AuthSession(
        accessToken: 'a',
        receivedAt: DateTime(2026, 10, 7),
      );

      expect(await fehler.revoke(session), isFalse);
      expect(await haengt.revoke(session), isFalse);
    });
  });

  group('Fehler am Token-Endpunkt', () {
    const config = HitobitoAuthConfig(
      clientId: 'client',
      clientSecret: 'secret',
      authorizationUrl: 'https://demo.hitobito.com/oauth/authorize',
      tokenUrl: 'https://demo.hitobito.com/oauth/token',
      redirectUri: 'de.jlange.nami.app:/oauth/callback',
      scopeString: 'openid email',
      discoveryUrl: '',
      profileUrl: 'https://demo.hitobito.com/oauth/profile',
    );
    final session = AuthSession(
      accessToken: 'alt',
      refreshToken: 'refresh-alt',
      receivedAt: DateTime(2026, 10, 1),
    );

    Future<HitobitoAuthException> refreshFehler(http.Response antwort) async {
      final service = HitobitoOauthService(
        config: config,
        httpClient: MockClient((_) async => antwort),
      );
      try {
        await service.refresh(session);
      } on HitobitoAuthException catch (error) {
        return error;
      }
      fail('Refresh haette scheitern muessen');
    }

    http.Response oauthFehler(int status, String code) => http.Response(
      jsonEncode(<String, String>{'error': code}),
      status,
      headers: const <String, String>{'content-type': 'application/json'},
    );

    test('invalid_grant beendet die Sitzung', () async {
      final error = await refreshFehler(oauthFehler(400, 'invalid_grant'));

      expect(error.art, HitobitoAuthFehlerArt.sitzungBeendet);
      expect(error.statusCode, 400);
    });

    test('invalid_client ist ein Konfigurationsfehler', () async {
      final error = await refreshFehler(oauthFehler(401, 'invalid_client'));

      expect(error.art, HitobitoAuthFehlerArt.konfiguration);
    });

    test('401 ohne Fehlercode beendet die Sitzung', () async {
      final error = await refreshFehler(http.Response('', 401));

      expect(error.art, HitobitoAuthFehlerArt.sitzungBeendet);
    });

    test('429 und 503 sind voruebergehend', () async {
      final ueberlast = await refreshFehler(http.Response('', 429));
      final wartung = await refreshFehler(
        http.Response('<html>Wartung</html>', 503),
      );

      expect(ueberlast.art, HitobitoAuthFehlerArt.voruebergehend);
      expect(wartung.art, HitobitoAuthFehlerArt.voruebergehend);
    });

    test('Antwort ohne access_token wird abgelehnt', () async {
      final error = await refreshFehler(
        http.Response(
          jsonEncode(<String, Object>{'token_type': 'Bearer'}),
          200,
          headers: const <String, String>{'content-type': 'application/json'},
        ),
      );

      expect(error.art, isNull);
      expect(error.toString(), 'Token-Antwort ohne Zugangstoken.');
    });
  });
}

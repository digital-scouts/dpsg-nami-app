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

  test('uebersetzt technische OAuth-Plugin-Fehler in fachliche Meldung', () {
    final error = HitobitoAuthException.fromPlatformException(
      PlatformException(
        code: 'ACTIVITY_NOT_FOUND',
        message: 'No activity found to handle intent',
      ),
    );

    expect(
      error.toString(),
      'Die Hitobito-Anmeldung konnte nicht gestartet werden. Bitte pruefe die OAuth-Konfiguration.',
    );
    expect(error.isExpectedInteractionFailure, isTrue);
  });

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
}

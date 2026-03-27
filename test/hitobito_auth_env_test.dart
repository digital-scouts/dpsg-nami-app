import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nami/services/hitobito_auth_env.dart';

void main() {
  test('liefert Defaults fuer Retention und leere OAuth-Konfiguration', () {
    dotenv.loadFromString(envString: '', isOptional: true);

    final config = HitobitoAuthEnv.authConfig;
    expect(config.isConfigured, isFalse);
    expect(config.scopeString, HitobitoAuthConfig.defaultScopeString);
    expect(HitobitoAuthEnv.maxDataAge, const Duration(days: 90));
    expect(HitobitoAuthEnv.refreshInterval, const Duration(hours: 24));
  });

  test(
    'leitet OAuth-Endpunkte aus Basis-URL und Retention-Werte aus der Env ab',
    () {
      dotenv.loadFromString(
        envString:
            'HITOBITO_BASE_URL=https://demo.hitobito.com/\n'
            'HITOBITO_OAUTH_CLIENT_ID=client\n'
            'HITOBITO_OAUTH_CLIENT_SECRET=secret\n'
            'HITOBITO_OAUTH_REDIRECT_URI=de.jlange.nami.app:/oauth/callback\n'
            'HITOBITO_DATA_MAX_AGE_DAYS=60\n'
            'HITOBITO_REFRESH_INTERVAL_HOURS=12\n',
      );

      final config = HitobitoAuthEnv.authConfig;
      expect(config.isConfigured, isTrue);
      expect(config.callbackScheme, 'de.jlange.nami.app');
      expect(
        config.authorizationUrl,
        'https://demo.hitobito.com/oauth/authorize',
      );
      expect(config.tokenUrl, 'https://demo.hitobito.com/oauth/token');
      expect(
        config.discoveryUrl,
        'https://demo.hitobito.com/.well-known/openid-configuration',
      );
      expect(config.profileUrl, 'https://demo.hitobito.com/de/oauth/profile');
      expect(
        config.peopleUri,
        Uri.parse('https://demo.hitobito.com/api/people'),
      );
      expect(config.scopes, HitobitoAuthConfig.defaultScopeString.split(' '));
      expect(HitobitoAuthEnv.maxDataAge, const Duration(days: 60));
      expect(HitobitoAuthEnv.refreshInterval, const Duration(hours: 12));
    },
  );
}

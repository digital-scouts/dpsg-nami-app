import 'package:flutter_test/flutter_test.dart';
import 'package:nami/services/hitobito_auth_config_controller.dart';
import 'package:nami/services/hitobito_auth_env.dart';
import 'package:nami/services/hitobito_groups_service.dart';
import 'package:nami/services/hitobito_oauth_service.dart';
import 'package:nami/services/hitobito_people_service.dart';
import 'package:nami/services/sensitive_storage_service.dart';

void main() {
  test(
    'laedt OAuth-Overrides aus sicherem Speicher und aktualisiert Services',
    () async {
      final storage = _FakeSensitiveStorageService()
        ..clientId = 'override-client'
        ..clientSecret = 'override-secret';
      final envConfig = HitobitoAuthConfig.fromBaseUrl(
        clientId: 'env-client',
        clientSecret: 'env-secret',
        baseUrl: 'https://demo.hitobito.com',
        redirectUri: 'de.jlange.nami.app:/oauth/callback',
      );
      final oauthService = HitobitoOauthService(config: envConfig);
      final groupsService = HitobitoGroupsService(config: envConfig);
      final peopleService = HitobitoPeopleService(config: envConfig);
      final controller = HitobitoAuthConfigController(
        sensitiveStorageService: storage,
        oauthService: oauthService,
        groupsService: groupsService,
        peopleService: peopleService,
        envConfig: envConfig,
      );

      await controller.initialize();

      expect(controller.hasOverride, isTrue);
      expect(controller.config.clientId, 'override-client');
      expect(controller.config.clientSecret, 'override-secret');
      expect(oauthService.config.clientId, 'override-client');
      expect(groupsService.config.clientId, 'override-client');
      expect(peopleService.config.clientId, 'override-client');
    },
  );
}

class _FakeSensitiveStorageService extends SensitiveStorageService {
  String? clientId;
  String? clientSecret;

  @override
  Future<void> clearHitobitoOauthOverride() async {
    clientId = null;
    clientSecret = null;
  }

  @override
  Future<String?> loadHitobitoOauthClientId() async => clientId;

  @override
  Future<String?> loadHitobitoOauthClientSecret() async => clientSecret;

  @override
  Future<void> saveHitobitoOauthClientId(String? value) async {
    clientId = value;
  }

  @override
  Future<void> saveHitobitoOauthClientSecret(String? value) async {
    clientSecret = value;
  }
}

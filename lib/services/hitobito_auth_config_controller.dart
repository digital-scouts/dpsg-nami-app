import 'package:flutter/foundation.dart';

import 'hitobito_auth_env.dart';
import 'hitobito_groups_service.dart';
import 'hitobito_oauth_service.dart';
import 'hitobito_people_service.dart';
import 'hitobito_roles_service.dart';
import 'logger_service.dart';
import 'sensitive_storage_service.dart';

class HitobitoAuthConfigController extends ChangeNotifier {
  HitobitoAuthConfigController({
    required SensitiveStorageService sensitiveStorageService,
    required HitobitoOauthService oauthService,
    required HitobitoGroupsService groupsService,
    required HitobitoPeopleService peopleService,
    HitobitoRolesService? rolesService,
    LoggerService? logger,
    HitobitoAuthConfig? envConfig,
  }) : _sensitiveStorageService = sensitiveStorageService,
       _oauthService = oauthService,
       _groupsService = groupsService,
       _peopleService = peopleService,
       _rolesService = rolesService,
       _logger = logger,
       _envConfig = envConfig ?? HitobitoAuthEnv.authConfig,
       _effectiveConfig = envConfig ?? HitobitoAuthEnv.authConfig;

  final SensitiveStorageService _sensitiveStorageService;
  final HitobitoOauthService _oauthService;
  final HitobitoGroupsService _groupsService;
  final HitobitoPeopleService _peopleService;
  final HitobitoRolesService? _rolesService;
  final LoggerService? _logger;
  final HitobitoAuthConfig _envConfig;

  HitobitoAuthConfig _effectiveConfig;
  bool _hasOverride = false;

  HitobitoAuthConfig get config => _effectiveConfig;
  bool get hasOverride => _hasOverride;
  String get effectiveClientId => _effectiveConfig.clientId;

  Future<void> initialize() async {
    final override = await loadOverride();
    final resolved = buildResolvedConfig(
      clientId: override?.clientId,
      clientSecret: override?.clientSecret,
    );
    _applyConfig(resolved, hasOverride: override != null, notify: false);
  }

  Future<HitobitoAuthCredentialsOverride?> loadOverride() async {
    final clientId = await _sensitiveStorageService.loadHitobitoOauthClientId();
    final clientSecret = await _sensitiveStorageService
        .loadHitobitoOauthClientSecret();
    if ((clientId == null || clientId.isEmpty) &&
        (clientSecret == null || clientSecret.isEmpty)) {
      return null;
    }

    return HitobitoAuthCredentialsOverride(
      clientId: clientId ?? '',
      clientSecret: clientSecret ?? '',
    );
  }

  HitobitoAuthConfig buildResolvedConfig({
    String? clientId,
    String? clientSecret,
  }) {
    final nextClientId = (clientId ?? _envConfig.clientId).trim();
    final nextClientSecret = (clientSecret ?? _envConfig.clientSecret).trim();
    return _envConfig.copyWith(
      clientId: nextClientId,
      clientSecret: nextClientSecret,
    );
  }

  Future<void> saveOverride({
    required String clientId,
    required String clientSecret,
  }) async {
    await _sensitiveStorageService.saveHitobitoOauthClientId(clientId.trim());
    await _sensitiveStorageService.saveHitobitoOauthClientSecret(
      clientSecret.trim(),
    );
    _applyConfig(
      buildResolvedConfig(clientId: clientId, clientSecret: clientSecret),
      hasOverride: true,
      notify: true,
    );
    await _logger?.log('auth_config', 'Hitobito OAuth-Override aktiviert');
  }

  HitobitoAuthConfig applyEphemeralOverride({
    required String clientId,
    required String clientSecret,
  }) {
    final previousConfig = _effectiveConfig;
    _applyConfig(
      buildResolvedConfig(clientId: clientId, clientSecret: clientSecret),
      hasOverride: _hasOverride,
      notify: false,
    );
    return previousConfig;
  }

  void restoreConfig(HitobitoAuthConfig config) {
    _applyConfig(config, hasOverride: _hasOverride, notify: false);
  }

  Future<void> clearOverride() async {
    await _sensitiveStorageService.clearHitobitoOauthOverride();
    _applyConfig(_envConfig, hasOverride: false, notify: true);
    await _logger?.log('auth_config', 'Hitobito OAuth-Override entfernt');
  }

  void _applyConfig(
    HitobitoAuthConfig nextConfig, {
    required bool hasOverride,
    required bool notify,
  }) {
    _effectiveConfig = nextConfig;
    _hasOverride = hasOverride;
    _oauthService.updateConfig(nextConfig);
    _groupsService.updateConfig(nextConfig);
    _peopleService.updateConfig(nextConfig);
    _rolesService?.updateConfig(nextConfig);
    if (notify) {
      notifyListeners();
    }
  }
}

class HitobitoAuthCredentialsOverride {
  const HitobitoAuthCredentialsOverride({
    required this.clientId,
    required this.clientSecret,
  });

  final String clientId;
  final String clientSecret;
}

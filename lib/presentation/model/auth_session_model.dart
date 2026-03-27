import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/auth/auth_profile.dart';
import '../../domain/auth/auth_session.dart';
import '../../domain/auth/auth_session_repository.dart';
import '../../domain/auth/auth_state.dart';
import '../../services/biometric_lock_service.dart';
import '../../services/hitobito_data_retention_policy.dart';
import '../../services/hitobito_oauth_service.dart';
import '../../services/logger_service.dart';
import '../../services/sensitive_storage_service.dart';

class AuthSessionModel extends ChangeNotifier {
  static const Duration _resumeUnlockSuppressionWindow = Duration(seconds: 3);

  AuthSessionModel({
    required AuthSessionRepository repository,
    required HitobitoOauthService oauthService,
    required BiometricLockService biometricLockService,
    required SensitiveStorageService sensitiveStorageService,
    required HitobitoDataRetentionPolicy retentionPolicy,
    required LoggerService logger,
    Future<void> Function(String languageCode)? onPreferredLanguageChanged,
  }) : _repository = repository,
       _oauthService = oauthService,
       _biometricLockService = biometricLockService,
       _sensitiveStorageService = sensitiveStorageService,
       _retentionPolicy = retentionPolicy,
       _logger = logger,
       _onPreferredLanguageChanged = onPreferredLanguageChanged;

  final AuthSessionRepository _repository;
  final HitobitoOauthService _oauthService;
  final BiometricLockService _biometricLockService;
  final SensitiveStorageService _sensitiveStorageService;
  final HitobitoDataRetentionPolicy _retentionPolicy;
  final LoggerService _logger;
  final Future<void> Function(String languageCode)? _onPreferredLanguageChanged;

  AuthState _state = AuthState.initializing;
  AuthSession? _session;
  AuthProfile? _profile;
  DateTime? _lastSensitiveSyncAt;
  String? _errorMessage;
  DateTime? _lastSuccessfulUnlockAt;
  bool _isLoadingProfile = false;

  AuthState get state => _state;
  AuthSession? get session => _session;
  AuthProfile? get profile => _profile;
  DateTime? get lastSensitiveSyncAt => _lastSensitiveSyncAt;
  String? get errorMessage => _errorMessage;
  bool get isLoadingProfile => _isLoadingProfile;
  bool get isConfigured => _oauthService.config.isConfigured;
  bool get isRefreshDue => _retentionPolicy.isRefreshDue(_lastSensitiveSyncAt);
  Duration? get remainingUntilRelogin =>
      _retentionPolicy.remainingUntilRelogin(_lastSensitiveSyncAt);

  Future<void> initialize() async {
    await _logger.log('auth_flow', 'Initialisierung gestartet');
    _state = AuthState.initializing;
    notifyListeners();

    _session = await _repository.load();
    _lastSensitiveSyncAt = await _sensitiveStorageService
        .loadLastSensitiveSyncAt();

    await _deriveState(requireUnlock: true);
    if (_state == AuthState.signedIn) {
      await ensureProfileLoaded(force: true);
    }
  }

  Future<void> signIn() async {
    await _logger.log('auth_flow', 'Login gestartet');
    final previousState = _state;
    _state = AuthState.authenticating;
    _errorMessage = null;
    notifyListeners();

    try {
      final previousPrincipal = await _sensitiveStorageService.loadPrincipal();
      final authenticatedSession = await _oauthService
          .authenticateInteractive();
      final nextPrincipal = authenticatedSession.principal;
      final mustPurgeExistingData =
          previousPrincipal != null &&
          previousPrincipal.isNotEmpty &&
          (nextPrincipal == null || nextPrincipal != previousPrincipal);

      if (mustPurgeExistingData) {
        await _logger.log(
          'auth_flow',
          'Vorhandene sensible Daten werden wegen Benutzerwechsel geloescht',
        );
        await _sensitiveStorageService.purgeSensitiveData();
      }

      await _repository.save(authenticatedSession);
      await _sensitiveStorageService.savePrincipal(nextPrincipal);

      final verifiedAt = DateTime.now();
      await _sensitiveStorageService.saveLastSensitiveSyncAt(verifiedAt);

      _session = authenticatedSession;
      _lastSensitiveSyncAt = verifiedAt;
      await ensureProfileLoaded(force: true);
      _state = AuthState.signedIn;
      await _logger.log('auth_flow', 'Login erfolgreich abgeschlossen');
      notifyListeners();
    } catch (error, stack) {
      await _logger.log('auth', 'OAuth-Login fehlgeschlagen: $error\n$stack');
      _errorMessage = error.toString();
      _state = previousState == AuthState.reloginRequired
          ? AuthState.reloginRequired
          : AuthState.signedOut;
      notifyListeners();
    }
  }

  Future<void> unlock() async {
    if (_state != AuthState.unlockRequired) {
      return;
    }

    await _logger.log('auth_flow', 'Lokale Entsperrung gestartet');

    final success = await _biometricLockService.authenticate();
    if (!success) {
      await _logger.log(
        'auth_flow',
        'Lokale Entsperrung fehlgeschlagen oder abgebrochen',
      );
      _errorMessage =
          'Die lokale Entsperrung wurde abgebrochen oder ist fehlgeschlagen.';
      notifyListeners();
      return;
    }

    _errorMessage = null;
    _state = AuthState.signedIn;
    _lastSuccessfulUnlockAt = DateTime.now();
    await _logger.log('auth_flow', 'Lokale Entsperrung erfolgreich');
    notifyListeners();
    unawaited(ensureProfileLoaded());
    unawaited(performBackgroundMaintenance(trigger: 'unlock'));
  }

  Future<void> logout() async {
    await _logger.log('auth_flow', 'Logout gestartet');
    await _repository.clear();
    await _sensitiveStorageService.purgeSensitiveData();

    _session = null;
    _profile = null;
    _isLoadingProfile = false;
    _lastSensitiveSyncAt = null;
    _errorMessage = null;
    _state = AuthState.signedOut;
    await _logger.log(
      'auth_flow',
      'Logout abgeschlossen, sensible Daten geloescht',
    );
    notifyListeners();
  }

  Future<void> onAppResumed() async {
    if (_session == null) {
      return;
    }

    if (_retentionPolicy.isReloginRequired(_lastSensitiveSyncAt)) {
      _state = AuthState.reloginRequired;
      await _logger.log(
        'auth_flow',
        'Relogin erforderlich: Datenfrist abgelaufen',
      );
      notifyListeners();
      return;
    }

    if (_shouldSuppressResumeUnlock()) {
      unawaited(performBackgroundMaintenance(trigger: 'resume'));
      return;
    }

    if (await _biometricLockService.isAvailable()) {
      _state = AuthState.unlockRequired;
      await _logger.log(
        'auth_flow',
        'Lokale Entsperrung nach Resume erforderlich',
      );
      notifyListeners();
    }

    unawaited(performBackgroundMaintenance(trigger: 'resume'));
  }

  bool _shouldSuppressResumeUnlock() {
    final lastSuccessfulUnlockAt = _lastSuccessfulUnlockAt;
    if (lastSuccessfulUnlockAt == null) {
      return false;
    }

    return DateTime.now().difference(lastSuccessfulUnlockAt) <
        _resumeUnlockSuppressionWindow;
  }

  Future<void> performBackgroundMaintenance({required String trigger}) async {
    if (_session == null || _state == AuthState.reloginRequired) {
      return;
    }

    if (_retentionPolicy.isReloginRequired(_lastSensitiveSyncAt)) {
      _state = AuthState.reloginRequired;
      await _logger.log(
        'auth_flow',
        'Relogin erforderlich: Datenfrist abgelaufen',
      );
      notifyListeners();
      return;
    }

    try {
      final refreshedSession = await _oauthService.refreshIfNeeded(_session!);
      if (refreshedSession.accessToken != _session!.accessToken ||
          refreshedSession.refreshToken != _session!.refreshToken ||
          refreshedSession.expiresAt != _session!.expiresAt) {
        await _logger.log('auth_flow', 'Session durch Wartung aktualisiert');
        _session = refreshedSession;
        await _repository.save(refreshedSession);
      }
    } catch (error, stack) {
      await _logger.log(
        'auth',
        'Session-Wartung fehlgeschlagen ($trigger): $error\n$stack',
      );
    }

    if (_retentionPolicy.isReloginRequired(_lastSensitiveSyncAt)) {
      _state = AuthState.reloginRequired;
      await _logger.log(
        'auth_flow',
        'Relogin erforderlich: Datenfrist abgelaufen',
      );
      notifyListeners();
    }
  }

  Future<void> ensureProfileLoaded({bool force = false}) async {
    if (_session == null || _state == AuthState.reloginRequired) {
      return;
    }

    if (_isLoadingProfile) {
      return;
    }

    if (!force && _profile != null) {
      return;
    }

    _isLoadingProfile = true;
    notifyListeners();

    try {
      final loadedProfile = await _oauthService.fetchProfile(_session!);
      _profile = loadedProfile;
      _errorMessage = null;
      await _syncPreferredLanguage(loadedProfile.normalizedLanguage);
    } catch (error, stack) {
      await _logger.log(
        'auth',
        'Profil konnte nicht geladen werden: $error\n$stack',
      );
      _errorMessage = error.toString();
    } finally {
      _isLoadingProfile = false;
      notifyListeners();
    }
  }

  Future<void> _deriveState({required bool requireUnlock}) async {
    if (_session == null) {
      _state = AuthState.signedOut;
      notifyListeners();
      return;
    }

    if (_retentionPolicy.isReloginRequired(_lastSensitiveSyncAt)) {
      _state = AuthState.reloginRequired;
      await _logger.log(
        'auth_flow',
        'Relogin erforderlich: Datenfrist abgelaufen',
      );
      notifyListeners();
      return;
    }

    if (requireUnlock && await _biometricLockService.isAvailable()) {
      _state = AuthState.unlockRequired;
      await _logger.log('auth_flow', 'Lokale Entsperrung erforderlich');
      notifyListeners();
      return;
    }

    _state = AuthState.signedIn;
    notifyListeners();
    unawaited(performBackgroundMaintenance(trigger: 'bootstrap'));
  }

  Future<void> _syncPreferredLanguage(String languageCode) async {
    final handler = _onPreferredLanguageChanged;
    if (handler == null) {
      return;
    }

    await handler(AuthProfile.normalizeLanguageCode(languageCode));
  }
}

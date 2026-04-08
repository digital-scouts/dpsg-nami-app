import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/auth/auth_profile.dart';
import '../../domain/auth/auth_profile_repository.dart';
import '../../domain/auth/auth_session.dart';
import '../../domain/auth/auth_session_repository.dart';
import '../../domain/auth/auth_state.dart';
import '../../services/biometric_lock_service.dart';
import '../../services/hitobito_data_retention_policy.dart';
import '../../services/hitobito_oauth_service.dart';
import '../../services/logger_service.dart';
import '../../services/sensitive_storage_service.dart';

class AuthSessionModel extends ChangeNotifier {
  AuthSessionModel({
    required AuthSessionRepository repository,
    required AuthProfileRepository profileRepository,
    required HitobitoOauthService oauthService,
    required BiometricLockService biometricLockService,
    required SensitiveStorageService sensitiveStorageService,
    required HitobitoDataRetentionPolicy retentionPolicy,
    required LoggerService logger,
    Future<void> Function(String languageCode)? onPreferredLanguageChanged,
    bool Function()? isAppLockEnabled,
    Duration lockTimeout = const Duration(seconds: 60),
  }) : _repository = repository,
       _profileRepository = profileRepository,
       _oauthService = oauthService,
       _biometricLockService = biometricLockService,
       _sensitiveStorageService = sensitiveStorageService,
       _retentionPolicy = retentionPolicy,
       _logger = logger,
       _onPreferredLanguageChanged = onPreferredLanguageChanged,
       _isAppLockEnabled = isAppLockEnabled ?? _appLockDisabled,
       _lockTimeout = lockTimeout;

  final AuthSessionRepository _repository;
  final AuthProfileRepository _profileRepository;
  final HitobitoOauthService _oauthService;
  final BiometricLockService _biometricLockService;
  final SensitiveStorageService _sensitiveStorageService;
  final HitobitoDataRetentionPolicy _retentionPolicy;
  final LoggerService _logger;
  final Future<void> Function(String languageCode)? _onPreferredLanguageChanged;
  final bool Function() _isAppLockEnabled;
  final Duration _lockTimeout;

  static bool _appLockDisabled() => false;

  AuthState _state = AuthState.initializing;
  AuthSession? _session;
  AuthProfile? _profile;
  DateTime? _lastSensitiveSyncAt;
  DateTime? _lastSensitiveSyncAttemptAt;
  DateTime? _lastProfileSyncAt;
  DateTime? _lastBackgroundedAt;
  String? _errorMessage;
  String? _remoteAccessIssueMessage;
  bool _requiresInteractiveLogin = false;
  bool _isLoadingProfile = false;
  bool _isSyncingHitobitoData = false;

  AuthState get state => _state;
  AuthSession? get session => _session;
  AuthProfile? get profile => _profile;
  DateTime? get lastSensitiveSyncAt => _lastSensitiveSyncAt;
  DateTime? get lastSensitiveSyncAttemptAt => _lastSensitiveSyncAttemptAt;
  DateTime? get lastProfileSyncAt => _lastProfileSyncAt;
  String? get errorMessage => _errorMessage;
  String? get remoteAccessIssueMessage => _remoteAccessIssueMessage;
  bool get isLoadingProfile => _isLoadingProfile;
  bool get isSyncingHitobitoData => _isSyncingHitobitoData;
  bool get isConfigured => _oauthService.config.isConfigured;
  bool get hasRemoteAccessIssue => _remoteAccessIssueMessage != null;
  bool get requiresInteractiveLogin => _requiresInteractiveLogin;
  bool get isRefreshDue => _retentionPolicy.isRefreshDue(_lastSensitiveSyncAt);
  bool get isRefreshAttemptDue =>
      !_requiresInteractiveLogin &&
      _retentionPolicy.isRefreshDue(
        _lastSensitiveSyncAttemptAt ?? _lastSensitiveSyncAt,
      );
  bool get isProfileRefreshDue =>
      _retentionPolicy.isRefreshDue(_lastProfileSyncAt);
  Duration? get remainingUntilRelogin =>
      _retentionPolicy.remainingUntilRelogin(_lastSensitiveSyncAt);

  Future<void> initialize() async {
    await _logger.log('auth_flow', 'Initialisierung gestartet');
    _state = AuthState.initializing;
    notifyListeners();

    _session = await _repository.load();
    _lastSensitiveSyncAt = await _sensitiveStorageService
        .loadLastSensitiveSyncAt();
    _lastSensitiveSyncAttemptAt = await _sensitiveStorageService
        .loadLastSensitiveSyncAttemptAt();
    _lastBackgroundedAt = await _sensitiveStorageService
        .loadLastBackgroundedAt();
    _lastProfileSyncAt = await _profileRepository.loadLastSyncAt();
    _profile = await _profileRepository.loadCached();

    if (await _shouldResetStaleSessionBeforeUnlock()) {
      await _logger.log(
        'auth_flow',
        'Uebernommene Session ohne restorable Profildaten erkannt, Login wird zurueckgesetzt',
      );
      await _repository.clear();
      await _profileRepository.clear();
      await _sensitiveStorageService.purgeSensitiveData();
      _session = null;
      _profile = null;
      _lastSensitiveSyncAt = null;
      _lastSensitiveSyncAttemptAt = null;
      _lastProfileSyncAt = null;
      _lastBackgroundedAt = null;
    }

    await _deriveState(requireUnlock: true);
    if (_state == AuthState.signedIn) {
      await ensureProfileLoaded();
    }
  }

  Future<bool> _shouldResetStaleSessionBeforeUnlock() async {
    if (_session == null) {
      return false;
    }

    final hasRestorableProfile = _profile != null || _lastProfileSyncAt != null;
    final hasSensitiveSyncState =
        _lastSensitiveSyncAt != null || _lastSensitiveSyncAttemptAt != null;
    if (hasRestorableProfile || hasSensitiveSyncState) {
      return false;
    }

    return _isAppLockEnabled() && await _biometricLockService.isAvailable();
  }

  Future<void> signIn() async {
    await _logger.logInfo(
      'auth_flow',
      'login started method=interactive_oauth',
    );
    await _logger.trackAuthFlow(
      'login',
      'started',
      properties: const {'method': 'interactive_oauth'},
    );
    final previousState = _state;
    _state = AuthState.authenticating;
    _errorMessage = null;
    notifyListeners();

    try {
      final authenticatedSession = await _oauthService
          .authenticateInteractive();
      await _completeSuccessfulSignIn(authenticatedSession);
      await _logger.logInfo(
        'auth_flow',
        'login success method=interactive_oauth',
      );
      await _logger.trackAuthFlow(
        'login',
        'success',
        properties: const {'method': 'interactive_oauth'},
      );
      notifyListeners();
    } catch (error, stack) {
      if (error is HitobitoAuthException &&
          error.isExpectedInteractionFailure) {
        await _logger.logInfo(
          'auth_flow',
          'login cancelled method=interactive_oauth error_type=${error.runtimeType}',
        );
        await _logger.trackAuthFlow(
          'login',
          'cancelled',
          properties: {
            'method': 'interactive_oauth',
            'error_type': error.runtimeType.toString(),
          },
        );
      } else {
        await _logger.logError(
          'auth',
          'login failure method=interactive_oauth',
          error: error,
          stackTrace: stack,
        );
        await _logger.trackAuthFlow(
          'login',
          'failure',
          properties: {
            'method': 'interactive_oauth',
            'error_type': error.runtimeType.toString(),
          },
        );
      }
      _errorMessage = error.toString();
      _state = previousState;
      notifyListeners();
    }
  }

  Future<void> signInWithAuthenticatedSession(
    AuthSession authenticatedSession,
  ) async {
    await _logger.logInfo(
      'auth_flow',
      'login started method=authenticated_session',
    );
    await _logger.trackAuthFlow(
      'login',
      'started',
      properties: const {'method': 'authenticated_session'},
    );
    final previousState = _state;
    _state = AuthState.authenticating;
    _errorMessage = null;
    notifyListeners();

    try {
      await _completeSuccessfulSignIn(authenticatedSession);
      await _logger.logInfo(
        'auth_flow',
        'login success method=authenticated_session',
      );
      await _logger.trackAuthFlow(
        'login',
        'success',
        properties: const {'method': 'authenticated_session'},
      );
      notifyListeners();
    } catch (error, stack) {
      await _logger.logError(
        'auth',
        'login failure method=authenticated_session',
        error: error,
        stackTrace: stack,
      );
      await _logger.trackAuthFlow(
        'login',
        'failure',
        properties: {
          'method': 'authenticated_session',
          'error_type': error.runtimeType.toString(),
        },
      );
      _errorMessage = error.toString();
      _state = previousState;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> _completeSuccessfulSignIn(
    AuthSession authenticatedSession,
  ) async {
    final previousPrincipal = await _sensitiveStorageService.loadPrincipal();
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
      await _profileRepository.clear();
      await _sensitiveStorageService.purgeSensitiveData();
    }

    await _repository.save(authenticatedSession);
    await _sensitiveStorageService.savePrincipal(nextPrincipal);
    await _sensitiveStorageService.saveLastBackgroundedAt(null);
    await _sensitiveStorageService.saveLastSensitiveSyncAttemptAt(null);

    _session = authenticatedSession;
    _lastBackgroundedAt = null;
    _lastSensitiveSyncAttemptAt = null;
    _requiresInteractiveLogin = false;
    _remoteAccessIssueMessage = null;
    await ensureProfileLoaded(force: true);
    _state = AuthState.signedIn;
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
    await _clearBackgroundedAt();
    await _logger.log('auth_flow', 'Lokale Entsperrung erfolgreich');
    notifyListeners();
    unawaited(_refreshAfterUnlock());
  }

  Future<void> logout() async {
    await _logger.logInfo('auth_flow', 'logout started');
    await _logger.trackAuthFlow('logout', 'started');
    await _repository.clear();
    await _profileRepository.clear();
    await _sensitiveStorageService.purgeSensitiveData();

    _session = null;
    _profile = null;
    _isLoadingProfile = false;
    _isSyncingHitobitoData = false;
    _lastSensitiveSyncAt = null;
    _lastSensitiveSyncAttemptAt = null;
    _lastProfileSyncAt = null;
    _lastBackgroundedAt = null;
    _errorMessage = null;
    _remoteAccessIssueMessage = null;
    _requiresInteractiveLogin = false;
    _state = AuthState.signedOut;
    await _logger.logInfo(
      'auth_flow',
      'logout success sensitive_data_cleared=true',
    );
    await _logger.trackAuthFlow(
      'logout',
      'success',
      properties: const {'sensitive_data_cleared': true},
    );
    notifyListeners();
  }

  Future<void> onAppBackgrounded() async {
    if (_session == null) {
      return;
    }

    final backgroundedAt = _retentionPolicy.now();
    _lastBackgroundedAt = backgroundedAt;
    await _sensitiveStorageService.saveLastBackgroundedAt(backgroundedAt);
    await _logger.log('auth_flow', 'App-Hintergrundzeitpunkt gespeichert');
  }

  Future<void> onAppResumed() async {
    if (_session == null) {
      return;
    }

    if (_retentionPolicy.isReloginRequired(_lastSensitiveSyncAt)) {
      await _expireSensitiveData();
      return;
    }

    final shouldRequireUnlock = _shouldRequireUnlockAfterResume();
    await _clearBackgroundedAt();

    if (shouldRequireUnlock &&
        _isAppLockEnabled() &&
        await _biometricLockService.isAvailable()) {
      _state = AuthState.unlockRequired;
      await _logger.log(
        'auth_flow',
        'Lokale Entsperrung nach Resume erforderlich',
      );
      notifyListeners();
    }
  }

  bool _shouldRequireUnlockAfterResume() {
    final lastBackgroundedAt = _lastBackgroundedAt;
    if (lastBackgroundedAt == null) {
      return false;
    }

    return _retentionPolicy.now().difference(lastBackgroundedAt) >=
        _lockTimeout;
  }

  Future<void> performBackgroundMaintenance({required String trigger}) async {
    if (_session == null || _state == AuthState.reloginRequired) {
      return;
    }

    if (_retentionPolicy.isReloginRequired(_lastSensitiveSyncAt)) {
      await _expireSensitiveData();
      return;
    }

    try {
      await prepareSessionForRemoteAccess(trigger: trigger);
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

  Future<AuthSession?> prepareSessionForRemoteAccess({
    required String trigger,
    bool forceRefresh = false,
  }) async {
    if (_session == null || _state == AuthState.reloginRequired) {
      return null;
    }

    if (_requiresInteractiveLogin) {
      return null;
    }

    if (_retentionPolicy.isReloginRequired(_lastSensitiveSyncAt)) {
      await _expireSensitiveData();
      return null;
    }

    try {
      final currentSession = _session!;
      final refreshedSession = forceRefresh && currentSession.canRefresh
          ? await _oauthService.refresh(currentSession)
          : await _oauthService.refreshIfNeeded(currentSession);
      if (refreshedSession.accessToken != currentSession.accessToken ||
          refreshedSession.refreshToken != currentSession.refreshToken ||
          refreshedSession.expiresAt != currentSession.expiresAt) {
        await _logger.log('auth_flow', 'Session durch $trigger aktualisiert');
        _session = refreshedSession;
        await _repository.save(refreshedSession);
      }
      _clearRemoteAccessIssue(notify: false);
    } catch (error, stack) {
      await _logger.log(
        'auth',
        'Session-Auffrischung fehlgeschlagen ($trigger): $error\n$stack',
      );
      reportRemoteDataIssue(
        error.toString(),
        requiresInteractiveLogin: _isUnauthorized(error),
        notify: false,
      );
      if (_requiresInteractiveLogin) {
        return null;
      }
    }

    return _session;
  }

  Future<void> ensureProfileLoaded({bool force = false}) async {
    if (_session == null || _state == AuthState.reloginRequired) {
      return;
    }

    final hadProfile = _profile != null;
    await _restoreCachedProfile();
    if (!hadProfile && _profile != null) {
      notifyListeners();
    }

    if (_isLoadingProfile) {
      return;
    }

    if (!force &&
        _profile != null &&
        !_retentionPolicy.isRefreshDue(_lastProfileSyncAt)) {
      return;
    }

    _isLoadingProfile = true;
    notifyListeners();

    try {
      final activeSession = await prepareSessionForRemoteAccess(
        trigger: force ? 'profile_force' : 'profile_load',
      );
      if (activeSession == null) {
        return;
      }

      await _loadProfileFromRemote(activeSession);
    } catch (error, stack) {
      if (!_isUnauthorized(error)) {
        await _logger.log(
          'auth',
          'Profil konnte nicht geladen werden: $error\n$stack',
        );
      }
      _errorMessage = error.toString();
    } finally {
      _isLoadingProfile = false;
      notifyListeners();
    }
  }

  Future<void> syncHitobitoData({
    required Future<void> Function(String accessToken) syncMembers,
    bool force = false,
    String trigger = 'manual',
  }) async {
    if (_isSyncingHitobitoData ||
        _session == null ||
        _state == AuthState.reloginRequired) {
      return;
    }

    if (!force && !isRefreshAttemptDue) {
      return;
    }

    await markSensitiveDataSyncAttempted();
    _isSyncingHitobitoData = true;
    notifyListeners();

    try {
      final activeSession = await prepareSessionForRemoteAccess(
        trigger: '${trigger}_session',
        forceRefresh: force,
      );
      if (activeSession == null) {
        return;
      }

      await _loadProfileFromRemote(activeSession);
      if (_requiresInteractiveLogin) {
        return;
      }
      await syncMembers(activeSession.accessToken);

      await markSensitiveDataSynced();
      _errorMessage = null;
      _clearRemoteAccessIssue(notify: false);
    } catch (error, stack) {
      await _logger.log(
        'hitobito_sync',
        'Hitobito-Sync fehlgeschlagen ($trigger): $error\n$stack',
      );
      _errorMessage ??= error.toString();
      reportRemoteDataIssue(
        error.toString(),
        requiresInteractiveLogin: _isUnauthorized(error),
        notify: false,
      );
    } finally {
      _isSyncingHitobitoData = false;
      notifyListeners();
    }
  }

  Future<void> _loadProfileFromRemote(
    AuthSession session, {
    bool retryOnUnauthorized = true,
  }) async {
    try {
      final loadedProfile = await _oauthService.fetchProfile(session);
      final syncAt = _retentionPolicy.now();
      _profile = loadedProfile;
      _lastProfileSyncAt = syncAt;
      _errorMessage = null;
      await _profileRepository.save(loadedProfile);
      await _profileRepository.saveLastSyncAt(syncAt);
      await _syncPreferredLanguage(loadedProfile.normalizedLanguage);
    } on HitobitoAuthException catch (error, stack) {
      if (!_isUnauthorized(error)) {
        await _logger.log(
          'auth',
          'Profil konnte nicht geladen werden: $error\n$stack',
        );
      }

      if (retryOnUnauthorized && error.statusCode == 401) {
        final refreshedSession = await prepareSessionForRemoteAccess(
          trigger: 'profile_retry',
          forceRefresh: true,
        );
        if (refreshedSession != null &&
            refreshedSession.accessToken != session.accessToken) {
          return _loadProfileFromRemote(
            refreshedSession,
            retryOnUnauthorized: false,
          );
        }

        reportRemoteDataIssue(error.toString(), requiresInteractiveLogin: true);
        return;
      }

      _errorMessage = error.toString();
      reportRemoteDataIssue(
        error.toString(),
        requiresInteractiveLogin: false,
        notify: false,
      );
      rethrow;
    }
  }

  Future<void> _restoreCachedProfile() async {
    _lastProfileSyncAt ??= await _profileRepository.loadLastSyncAt();
    _profile ??= await _profileRepository.loadCached();
  }

  Future<void> _refreshAfterUnlock() async {
    if (isRefreshAttemptDue) {
      await ensureProfileLoaded(force: true);
    }
  }

  Future<void> _clearBackgroundedAt() async {
    _lastBackgroundedAt = null;
    await _sensitiveStorageService.saveLastBackgroundedAt(null);
  }

  Future<void> _deriveState({required bool requireUnlock}) async {
    if (_session == null) {
      _state = AuthState.signedOut;
      notifyListeners();
      return;
    }

    if (_retentionPolicy.isReloginRequired(_lastSensitiveSyncAt)) {
      await _expireSensitiveData();
      return;
    }

    if (requireUnlock &&
        _isAppLockEnabled() &&
        await _biometricLockService.isAvailable()) {
      _state = AuthState.unlockRequired;
      await _logger.log('auth_flow', 'Lokale Entsperrung erforderlich');
      notifyListeners();
      return;
    }

    _state = AuthState.signedIn;
    _state = AuthState.signedIn;
    notifyListeners();
  }

  Future<void> _syncPreferredLanguage(String languageCode) async {
    final handler = _onPreferredLanguageChanged;
    if (handler == null) {
      return;
    }

    await handler(AuthProfile.normalizeLanguageCode(languageCode));
  }

  Future<void> markSensitiveDataSynced() async {
    final verifiedAt = _retentionPolicy.now();
    _lastSensitiveSyncAt = verifiedAt;
    _lastSensitiveSyncAttemptAt = verifiedAt;
    await _sensitiveStorageService.saveLastSensitiveSyncAt(verifiedAt);
    await _sensitiveStorageService.saveLastSensitiveSyncAttemptAt(verifiedAt);
  }

  Future<void> markSensitiveDataSyncAttempted() async {
    final attemptedAt = _retentionPolicy.now();
    _lastSensitiveSyncAttemptAt = attemptedAt;
    await _sensitiveStorageService.saveLastSensitiveSyncAttemptAt(attemptedAt);
  }

  void clearRemoteDataIssue() {
    _clearRemoteAccessIssue(notify: true);
  }

  void reportRemoteDataIssue(
    String message, {
    bool requiresInteractiveLogin = false,
    bool notify = true,
  }) {
    _remoteAccessIssueMessage = message;
    _requiresInteractiveLogin =
        _requiresInteractiveLogin || requiresInteractiveLogin;
    if (notify) {
      notifyListeners();
    }
  }

  void _clearRemoteAccessIssue({required bool notify}) {
    _remoteAccessIssueMessage = null;
    _requiresInteractiveLogin = false;
    if (notify) {
      notifyListeners();
    }
  }

  bool _isUnauthorized(Object error) {
    return error is HitobitoAuthException && error.statusCode == 401;
  }

  Future<void> _expireSensitiveData() async {
    await _logger.log(
      'auth_flow',
      'Gespeicherte Daten sind abgelaufen und werden geloescht',
    );
    await logout();
  }
}

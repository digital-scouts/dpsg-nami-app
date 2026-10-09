import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../domain/auth/auth_profile.dart';
import '../../domain/auth/auth_profile_repository.dart';
import '../../domain/auth/auth_session.dart';
import '../../domain/auth/auth_session_repository.dart';
import '../../domain/auth/auth_state.dart';
import '../../services/app_startup_state_service.dart';
import '../../services/biometric_lock_service.dart';
import '../../services/hitobito_api_exception.dart';
import '../../services/hitobito_auth_env.dart';
import '../../services/hitobito_data_retention_policy.dart';
import '../../services/hitobito_oauth_service.dart';
import '../../services/logger_service.dart';
import '../../services/network_access_policy.dart';
import '../../services/sensitive_storage_service.dart';
import 'nutzer_fehlermeldung.dart';

enum SyncAttemptResult {
  success,
  wifiOnly,
  loginRequired,
  networkError,
  serverError,
  unknownError,
}

enum NextSyncDisplayKind { atTime, whenWifiAvailable, loginRequired }

/// Warum die App ohne Zutun der Person abgemeldet hat.
enum LogoutReason { keineBerechtigung }

class DataSyncStatus {
  const DataSyncStatus({
    required this.isSyncing,
    required this.hasValidLocalData,
    required this.lastSuccessfulSyncAt,
    required this.lastAttemptAt,
    required this.lastAttemptResult,
    required this.nextSyncKind,
    required this.nextSyncAt,
  });

  final bool isSyncing;
  final bool hasValidLocalData;
  final DateTime? lastSuccessfulSyncAt;
  final DateTime? lastAttemptAt;
  final SyncAttemptResult? lastAttemptResult;
  final NextSyncDisplayKind? nextSyncKind;
  final DateTime? nextSyncAt;
}

class AuthSessionModel extends ChangeNotifier {
  AuthSessionModel({
    required AuthSessionRepository repository,
    required AuthProfileRepository profileRepository,
    required HitobitoOauthService oauthService,
    required BiometricLockService biometricLockService,
    required SensitiveStorageService sensitiveStorageService,
    required HitobitoDataRetentionPolicy retentionPolicy,
    required LoggerService logger,
    NetworkAccessPolicy? networkAccessPolicy,
    Future<void> Function(String languageCode)? onPreferredLanguageChanged,
    bool Function()? isAppLockEnabled,
    Duration lockTimeout = const Duration(seconds: 60),
    Future<void> Function()? purgeLocalPersonalData,
    Duration Function()? monotonicElapsed,
    AppStartupStateService? startupStateService,
  }) : _repository = repository,
       _profileRepository = profileRepository,
       _oauthService = oauthService,
       _biometricLockService = biometricLockService,
       _sensitiveStorageService = sensitiveStorageService,
       _retentionPolicy = retentionPolicy,
       _logger = logger,
       _networkAccessPolicy = networkAccessPolicy,
       _onPreferredLanguageChanged = onPreferredLanguageChanged,
       _isAppLockEnabled = isAppLockEnabled ?? _appLockDisabled,
       _lockTimeout = lockTimeout,
       _purgeLocalPersonalData = purgeLocalPersonalData,
       _monotonicElapsed = monotonicElapsed ?? _prozessUhr(),
       _startupStateService = startupStateService;

  final AuthSessionRepository _repository;
  final AuthProfileRepository _profileRepository;
  final HitobitoOauthService _oauthService;
  final BiometricLockService _biometricLockService;
  final SensitiveStorageService _sensitiveStorageService;
  final HitobitoDataRetentionPolicy _retentionPolicy;
  final LoggerService _logger;
  final NetworkAccessPolicy? _networkAccessPolicy;
  final Future<void> Function(String languageCode)? _onPreferredLanguageChanged;
  final bool Function() _isAppLockEnabled;
  final Duration _lockTimeout;
  // Loescht personenbezogene Daten ausserhalb der Hive-Boxen, etwa den
  // Geocoding- und Kartencache.
  final Future<void> Function()? _purgeLocalPersonalData;

  static bool _appLockDisabled() => false;

  // Merkt sich einen laufenden Browser-Login ueber ein Prozessende hinweg.
  final AppStartupStateService? _startupStateService;

  /// So lange gilt ein gemerkter Login nach dem Neustart als unterbrochen.
  static const Duration _anmeldungUnterbrochenFrist = Duration(minutes: 30);

  // Monotone Zeit seit Prozessstart. Anders als die Wanduhr laesst sie sich
  // nicht zurueckstellen und schuetzt so die Sperre beim Warmstart (A-18).
  final Duration Function() _monotonicElapsed;

  static Duration Function() _prozessUhr() {
    final uhr = Stopwatch()..start();
    return () => uhr.elapsed;
  }

  AuthState _state = AuthState.initializing;
  // Steigt mit jedem Ende einer Sitzung (Logout, Benutzerwechsel,
  // Datenablauf). Laufende Vorgaenge vergleichen sie nach jedem await und
  // verwerfen ihr Ergebnis, wenn die Sitzung inzwischen gewechselt hat.
  int _sessionGeneration = 0;
  Object? _activeSyncToken;
  _LaufenderRefresh? _laufenderRefresh;
  Future<AuthSession>? _laufendeBrowserAnmeldung;
  AuthSession? _session;
  AuthProfile? _profile;
  DateTime? _lastSensitiveSyncAt;
  DateTime? _lastSensitiveSyncAttemptAt;
  DateTime? _lastProfileSyncAt;
  DateTime? _lastBackgroundedAt;
  // Nur im laufenden Prozess bekannt; ein Kaltstart sperrt ohnehin immer.
  Duration? _backgroundedMonotonic;
  String? _errorMessage;
  String? _remoteAccessIssueMessage;
  NetworkAccessBlockedReason? _remoteAccessBlockedReason;
  bool _requiresInteractiveLogin = false;
  bool _hasShownRemoteAccessIssueNotice = false;
  bool _isLoadingProfile = false;
  bool _isSyncingHitobitoData = false;
  bool _isUserInitiatedSyncInProgress = false;
  bool _isNeuanmeldungAktiv = false;
  bool _anmeldungUnterbrochen = false;
  int _neuanmeldungen = 0;
  SyncAttemptResult? _lastSyncAttemptResult;
  LogoutReason? _logoutReason;

  AuthState get state => _state;
  int get sessionGeneration => _sessionGeneration;
  AuthSession? get session => _session;
  AuthProfile? get profile => _profile;
  DateTime? get lastSensitiveSyncAt => _lastSensitiveSyncAt;
  DateTime? get lastSensitiveSyncAttemptAt => _lastSensitiveSyncAttemptAt;
  DateTime? get lastProfileSyncAt => _lastProfileSyncAt;
  String? get errorMessage => _errorMessage;
  String? get remoteAccessIssueMessage => _remoteAccessIssueMessage;
  NetworkAccessBlockedReason? get remoteAccessBlockedReason =>
      _remoteAccessBlockedReason;
  bool get isLoadingProfile => _isLoadingProfile;
  bool get isSyncingHitobitoData => _isSyncingHitobitoData;
  bool get isUserInitiatedSyncInProgress => _isUserInitiatedSyncInProgress;

  /// Laeuft gerade [neuAnmelden]; der Arbeitskontext bleibt dabei sichtbar.
  bool get isNeuanmeldungAktiv => _isNeuanmeldungAktiv;

  /// Das System hat die App beim letzten Mal waehrend der Anmeldung im
  /// Browser beendet. Gilt bis zum naechsten Anmeldeversuch.
  bool get anmeldungUnterbrochen => _anmeldungUnterbrochen;

  /// Zaehlt erfolgreiche Neuanmeldungen. Wer synchronisiert, erkennt daran,
  /// dass nach einer abgelaufenen Anmeldung wieder Zugriffe moeglich sind.
  int get neuanmeldungen => _neuanmeldungen;
  SyncAttemptResult? get lastSyncAttemptResult => _lastSyncAttemptResult;

  /// Grund der letzten automatischen Abmeldung, bis zur naechsten Anmeldung.
  LogoutReason? get logoutReason => _logoutReason;
  DataSyncStatus get dataSyncStatus => DataSyncStatus(
    isSyncing: _isSyncingHitobitoData,
    hasValidLocalData: _lastSensitiveSyncAt != null,
    lastSuccessfulSyncAt: _lastSensitiveSyncAt,
    lastAttemptAt: _lastSensitiveSyncAttemptAt,
    lastAttemptResult: _lastSyncAttemptResult,
    nextSyncKind: _resolveNextSyncKind(),
    nextSyncAt: _resolveNextSyncAt(),
  );
  bool get isConfigured => _oauthService.config.isConfigured;
  bool get hasRemoteAccessIssue => _remoteAccessIssueMessage != null;
  bool get hasUnseenRemoteAccessIssueNotice =>
      hasRemoteAccessIssue && !_hasShownRemoteAccessIssueNotice;
  bool get isRemoteAccessBlockedByNetworkPolicy =>
      _remoteAccessBlockedReason != null;
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
    await _pruefeUnterbrocheneAnmeldung();

    try {
      _session = await _repository.load();
      if (_session != null && await _isSessionWithoutLocalData()) {
        // Der Schluesselbund ueberdauert unter iOS das Loeschen der App, die
        // App-Daten nicht. Eine solche Session gehoert zu einer frueheren
        // Installation und meldet niemanden an.
        await _logger.log(
          'auth_flow',
          'Uebernommene Session ohne lokale App-Daten erkannt, Login wird zurueckgesetzt',
        );
        await _repository.clear();
        try {
          await _profileRepository.clear();
        } on SensitiveSessionEndedException {
          // Die Profil-Box loescht der folgende Purge.
        }
        await _purgeSensitiveData();
        _session = null;
      }
      if (_session != null) {
        // Ohne Session bleiben die sensiblen Boxen geschlossen; es gibt dann
        // nichts zu lesen und es soll auch nichts entstehen.
        _sensitiveStorageService.beginSession();
        _lastSensitiveSyncAt = await _sensitiveStorageService
            .loadLastSensitiveSyncAt();
        _lastSensitiveSyncAttemptAt = await _sensitiveStorageService
            .loadLastSensitiveSyncAttemptAt();
        _lastBackgroundedAt = await _sensitiveStorageService
            .loadLastBackgroundedAt();
        _lastProfileSyncAt = await _profileRepository.loadLastSyncAt();
        _profile = await _profileRepository.loadCached();
      }

      await _deriveState(requireUnlock: true);
      if (_state == AuthState.signedIn) {
        await ensureProfileLoaded();
      }
    } catch (error, stack) {
      // Ohne dieses catch wuerde ein Fehler hier (z.B. Storage-Zugriff beim
      // Kaltstart) unbehandelt aus main() propagieren, bevor die App-Shell
      // ueberhaupt existiert - der Nutzer saehe dann dauerhaft nur einen
      // leeren/weissen Screen statt einer Fehleranzeige mit Retry.
      await _logger.log(
        'auth_flow',
        'Initialisierung fehlgeschlagen: $error\n$stack',
      );
      _state = AuthState.error;
      _errorMessage = nutzerFehlermeldung(error);
    } finally {
      notifyListeners();
    }
  }

  Future<bool> _isSessionWithoutLocalData() async {
    try {
      return !await _sensitiveStorageService.hasLocalSensitiveData();
    } catch (error, stack) {
      // Im Zweifel nicht abmelden; der Zustand ist dann nur unbekannt.
      await _logger.log(
        'auth_flow',
        'Pruefung auf lokale App-Daten fehlgeschlagen: $error\n$stack',
      );
      return false;
    }
  }

  Future<void> signIn() async {
    if (_laufendeBrowserAnmeldung != null) {
      // Ein zweiter Tipp oeffnet keinen zweiten Login.
      return;
    }
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
      final authenticatedSession = await _anmeldenImBrowser();
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
          'login failure method=interactive_oauth${_plattformCode(error)}',
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
      _errorMessage = nutzerFehlermeldung(error);
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
      _errorMessage = nutzerFehlermeldung(error);
      _state = previousState;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> _completeSuccessfulSignIn(
    AuthSession authenticatedSession,
  ) async {
    await _persistAuthenticatedSession(authenticatedSession);
    await ensureProfileLoaded(force: true);
  }

  Future<void> _persistAuthenticatedSession(
    AuthSession authenticatedSession,
  ) async {
    _sensitiveStorageService.beginSession();
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
      await _purgeSensitiveData();
      _profile = null;
      _lastProfileSyncAt = null;
      _lastSensitiveSyncAt = null;
      _lastSensitiveSyncAttemptAt = null;
      _remoteAccessIssueMessage = null;
      _requiresInteractiveLogin = false;
      _hasShownRemoteAccessIssueNotice = false;
      _errorMessage = null;
      _sensitiveStorageService.beginSession();
    }

    await _repository.save(authenticatedSession);
    await _sensitiveStorageService.savePrincipal(nextPrincipal);
    await _sensitiveStorageService.saveLastBackgroundedAt(null);
    await _sensitiveStorageService.saveLastSensitiveSyncAttemptAt(null);

    _session = authenticatedSession;
    _logoutReason = null;
    _lastBackgroundedAt = null;
    _backgroundedMonotonic = null;
    _lastSensitiveSyncAttemptAt = null;
    _errorMessage = null;
    _requiresInteractiveLogin = false;
    _remoteAccessIssueMessage = null;
    _hasShownRemoteAccessIssueNotice = false;
    // Greift die App-Sperre waehrend des Logins im Browser, bleibt sie
    // bestehen; nur die lokale Entsperrung hebt sie auf.
    if (_state != AuthState.unlockRequired) {
      _state = AuthState.signedIn;
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
    await _clearBackgroundedAt();
    await _logger.log('auth_flow', 'Lokale Entsperrung erfolgreich');
    notifyListeners();
    unawaited(_refreshAfterUnlock());
  }

  Future<void> logout() async {
    // Sofort beenden, damit laufende Vorgaenge waehrend der folgenden awaits
    // nichts mehr schreiben.
    _endSession();
    final beendeteSession = _session;
    _session = null;
    if (beendeteSession != null) {
      // Im Hintergrund, damit der Logout offline und bei langsamer Leitung
      // nicht wartet; die lokale Loeschung haengt nicht davon ab.
      unawaited(_widerrufen(beendeteSession));
    }
    _logoutReason = null;
    await _logger.logInfo('auth_flow', 'logout started');
    await _logger.trackAuthFlow('logout', 'started');
    await _repository.clear();
    try {
      await _profileRepository.clear();
    } on SensitiveSessionEndedException {
      // Die Profil-Box loescht der folgende Purge.
    }
    await _purgeSensitiveData();

    _profile = null;
    _isLoadingProfile = false;
    _isSyncingHitobitoData = false;
    _activeSyncToken = null;
    _laufenderRefresh = null;
    _isNeuanmeldungAktiv = false;
    _isUserInitiatedSyncInProgress = false;
    _lastSyncAttemptResult = null;
    _lastSensitiveSyncAt = null;
    _lastSensitiveSyncAttemptAt = null;
    _lastProfileSyncAt = null;
    _lastBackgroundedAt = null;
    _backgroundedMonotonic = null;
    _errorMessage = null;
    _remoteAccessIssueMessage = null;
    _requiresInteractiveLogin = false;
    _hasShownRemoteAccessIssueNotice = false;
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

  Future<void> _widerrufen(AuthSession session) async {
    try {
      await _networkAccessPolicy?.ensureNetworkAllowed(
        trigger: 'logout_revoke',
        feature: 'Hitobito',
        allowMobileDataOverride: true,
      );
    } on NetworkAccessBlockedException {
      await _logger.log('auth_flow', 'Token-Widerruf uebersprungen: offline');
      return;
    }
    final widerrufen = await _oauthService.revoke(session);
    await _logger.logInfo('auth_flow', 'logout token_revoked=$widerrufen');
  }

  /// Meldet ab, weil das Konto keinen lesbaren Layer mehr hat. Alle lokalen
  /// Daten werden wie beim Logout geloescht.
  Future<void> logoutWegenFehlenderRechte() async {
    await _logger.logInfo('auth_flow', 'logout reason=keine_berechtigung');
    await logout();
    _logoutReason = LogoutReason.keineBerechtigung;
    notifyListeners();
  }

  Future<void> onAppBackgrounded() async {
    if (_session == null) {
      return;
    }

    final backgroundedAt = _retentionPolicy.now();
    _lastBackgroundedAt = backgroundedAt;
    _backgroundedMonotonic = _monotonicElapsed();
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

    final shouldRequireUnlock =
        _shouldRequireUnlockAfterResume() && _isAppLockEnabled();
    final previousState = _state;
    if (shouldRequireUnlock) {
      // Sofort sperren: Andere Resume-Handler starten direkt danach
      // Remote-Zugriffe und muessen die Sperre schon sehen.
      _state = AuthState.unlockRequired;
      notifyListeners();
    }
    await _clearBackgroundedAt();
    if (!shouldRequireUnlock) {
      unawaited(sitzungFrischHalten(trigger: 'resume'));
      return;
    }

    if (!await _biometricLockService.isAvailable()) {
      if (_state == AuthState.unlockRequired) {
        _state = previousState;
        notifyListeners();
      }
      return;
    }
    await _logger.log(
      'auth_flow',
      'Lokale Entsperrung nach Resume erforderlich',
    );
  }

  bool _shouldRequireUnlockAfterResume() {
    final lastBackgroundedAt = _lastBackgroundedAt;
    if (lastBackgroundedAt == null) {
      return false;
    }

    final wanduhr = _retentionPolicy.now().difference(lastBackgroundedAt);
    // Eine zurueckgestellte Uhr ergibt eine negative Differenz und sperrt.
    if (wanduhr.isNegative || wanduhr >= _lockTimeout) {
      return true;
    }
    final backgroundedMonotonic = _backgroundedMonotonic;
    return backgroundedMonotonic != null &&
        _monotonicElapsed() - backgroundedMonotonic >= _lockTimeout;
  }

  Future<AuthSession?> prepareSessionForRemoteAccess({
    required String trigger,
    bool forceRefresh = false,
    bool allowMobileDataOverride = false,
  }) {
    return _prepareSessionForRemoteAccess(
      trigger: trigger,
      forceRefresh: forceRefresh,
      allowMobileDataOverride: allowMobileDataOverride,
    );
  }

  /// [abgelehntesAccessToken]: Hitobito hat dieses Access-Token bereits mit
  /// 401 abgelehnt. Hat ein paralleler Zugriff es inzwischen erneuert, gilt
  /// die neue Session. Scheitert der Refresh voruebergehend, wird der Fehler
  /// durchgereicht, statt das abgelehnte Token erneut zu senden.
  Future<AuthSession?> _prepareSessionForRemoteAccess({
    required String trigger,
    bool forceRefresh = false,
    bool allowMobileDataOverride = false,
    String? abgelehntesAccessToken,
  }) async {
    final generation = _sessionGeneration;
    if (_session == null || _state == AuthState.reloginRequired) {
      await _logger.log(
        'auth_flow',
        'Remote-Zugriff abgebrochen ($trigger): '
            'session=${_session != null} state=$_state',
      );
      return null;
    }

    if (_state == AuthState.unlockRequired) {
      // Hinter der App-Sperre gibt es weder Sync noch Login-Browser.
      await _logger.log(
        'auth_flow',
        'Remote-Zugriff abgebrochen ($trigger): App-Sperre aktiv',
      );
      return null;
    }

    if (_requiresInteractiveLogin) {
      await _logger.log(
        'auth_flow',
        'Remote-Zugriff abgebrochen ($trigger): '
            'interaktiver Login erforderlich',
      );
      return null;
    }

    if (_retentionPolicy.isReloginRequired(_lastSensitiveSyncAt)) {
      await _logger.log(
        'auth_flow',
        'Remote-Zugriff abgebrochen ($trigger): '
            'Aufbewahrungsrichtlinie verlangt Relogin '
            '(lastSensitiveSyncAt=$_lastSensitiveSyncAt)',
      );
      await _expireSensitiveData();
      return null;
    }

    await _networkAccessPolicy?.ensureNetworkAllowed(
      trigger: trigger,
      feature: 'Hitobito',
      allowMobileDataOverride: allowMobileDataOverride,
    );

    if (generation != _sessionGeneration || _session == null) {
      return null;
    }

    final currentSession = _session!;
    try {
      final bereitsErneuert =
          abgelehntesAccessToken != null &&
          currentSession.accessToken != abgelehntesAccessToken;
      final refreshedSession = bereitsErneuert
          ? currentSession
          : await _erneuereGemeinsam(currentSession, erzwingen: forceRefresh);
      if (generation != _sessionGeneration) {
        // Nach einem Logout darf die alte Session nicht zurueckkehren.
        return null;
      }
      final bisher = _session;
      if (bisher == null ||
          refreshedSession.accessToken != bisher.accessToken ||
          refreshedSession.refreshToken != bisher.refreshToken ||
          refreshedSession.expiresAt != bisher.expiresAt) {
        await _logger.log('auth_flow', 'Session durch $trigger aktualisiert');
        _session = refreshedSession;
        await _repository.save(refreshedSession);
      }
      _clearRemoteAccessIssue(notify: false);
    } catch (error, stack) {
      if (generation != _sessionGeneration || _requiresInteractiveLogin) {
        return null;
      }
      if (_istSitzungsende(error)) {
        // Hitobito hat die Anmeldung beendet. Den Browser oeffnet nur die
        // Person selbst ueber „Neu anmelden“.
        await _requireReloginForRemoteFailure(
          error.toString(),
          trigger: trigger,
        );
        return null;
      }
      await _logger.log(
        'auth',
        'Session-Auffrischung fehlgeschlagen ($trigger): $error\n$stack',
      );
      reportRemoteDataIssue(
        error.toString(),
        requiresInteractiveLogin: false,
        notify: false,
      );
      // Hitobito lehnt das alte Token ab. Ein Zugriff damit scheitert mit
      // 401 und wuerde eine Stoerung am Token-Endpunkt (Ueberlast,
      // Zeitlimit) faelschlich als abgelaufene Anmeldung werten. Ist
      // Hitobito gar nicht erreichbar, scheitert auch der naechste Zugriff;
      // er wuerde nur ein weiteres Zeitlimit abwarten.
      if (abgelehntesAccessToken != null ||
          _istAbgelaufen(currentSession) ||
          _istNichtErreichbar(error)) {
        rethrow;
      }
    }

    return _session;
  }

  /// Erneuert die Session hoechstens einmal gleichzeitig. Hitobito rotiert
  /// den Refresh-Token bei jeder Nutzung; ein zweiter paralleler Refresh mit
  /// demselben Token wuerde abgelehnt und die Sitzung faelschlich beenden.
  Future<AuthSession> _erneuereGemeinsam(
    AuthSession session, {
    required bool erzwingen,
  }) async {
    final laufend = _laufenderRefresh;
    if (laufend != null) {
      if (laufend.quelle == session.refreshToken &&
          (laufend.erzwungen || !erzwingen)) {
        return laufend.ergebnis;
      }
      try {
        await laufend.ergebnis;
      } on Object {
        // Den Fehler behandelt der Aufrufer des laufenden Refreshs.
      }
      return _erneuereGemeinsam(_session ?? session, erzwingen: erzwingen);
    }

    final ergebnis = erzwingen && session.canRefresh
        ? _oauthService.refresh(session)
        : _oauthService.refreshIfNeeded(session);
    final eintrag = _LaufenderRefresh(
      quelle: session.refreshToken,
      erzwungen: erzwingen,
      ergebnis: ergebnis,
    );
    _laufenderRefresh = eintrag;
    try {
      return await ergebnis;
    } finally {
      if (identical(_laufenderRefresh, eintrag)) {
        _laufenderRefresh = null;
      }
    }
  }

  /// Oeffnet hoechstens eine Hitobito-Anmeldung im Browser gleichzeitig.
  Future<AuthSession> _anmeldenImBrowser() {
    return _laufendeBrowserAnmeldung ??= _browserAnmeldung().whenComplete(
      () => _laufendeBrowserAnmeldung = null,
    );
  }

  Future<AuthSession> _browserAnmeldung() async {
    _anmeldungUnterbrochen = false;
    await _merkeAnmeldungBegonnen(_retentionPolicy.now());
    try {
      return await _oauthService.authenticateInteractive();
    } finally {
      await _merkeAnmeldungBegonnen(null);
    }
  }

  Future<void> _merkeAnmeldungBegonnen(DateTime? zeitpunkt) async {
    try {
      await _startupStateService?.saveAnmeldungBegonnen(zeitpunkt);
    } catch (error) {
      // Nur fuer den Hinweis nach einem Prozessende; die Anmeldung selbst
      // haengt nicht davon ab.
      await _logger.log(
        'auth_flow',
        'Anmeldevorgang konnte nicht gemerkt werden: $error',
      );
    }
  }

  Future<void> _pruefeUnterbrocheneAnmeldung() async {
    final DateTime? begonnen;
    try {
      begonnen = await _startupStateService?.loadAnmeldungBegonnen();
    } catch (error) {
      await _logger.log(
        'auth_flow',
        'Anmeldevorgang konnte nicht gelesen werden: $error',
      );
      return;
    }
    if (begonnen == null) {
      return;
    }
    await _merkeAnmeldungBegonnen(null);
    final alter = _retentionPolicy.now().difference(begonnen);
    if (alter.isNegative || alter > _anmeldungUnterbrochenFrist) {
      return;
    }
    _anmeldungUnterbrochen = true;
    await _logger.logInfo(
      'auth_flow',
      'login interrupted by process end age_s=${alter.inSeconds}',
    );
  }

  /// Fuehrt [action] mit einer gueltigen Session aus. Lehnt Hitobito das
  /// Token mit 401 ab, wird es einmal erneuert und die Aktion wiederholt.
  /// Ist die Anmeldung beendet, liefert der Aufruf `null` und setzt
  /// [requiresInteractiveLogin]; einen Login-Browser oeffnet er nie.
  Future<T?> executeRemoteAccess<T>({
    required String trigger,
    required Future<T> Function(AuthSession session) action,
    bool forceRefresh = false,
    bool retryOnUnauthorized = true,
    bool allowMobileDataOverride = false,
  }) async {
    final generation = _sessionGeneration;
    final activeSession = await _prepareSessionForRemoteAccess(
      trigger: '${trigger}_session',
      forceRefresh: forceRefresh,
      allowMobileDataOverride: allowMobileDataOverride,
    );
    if (activeSession == null || generation != _sessionGeneration) {
      return null;
    }

    try {
      return await action(activeSession);
    } catch (error) {
      if (generation != _sessionGeneration || !_isUnauthorized(error)) {
        rethrow;
      }

      await _logExpiredLoginRetry(trigger: trigger);

      if (!retryOnUnauthorized) {
        await _requireReloginForRemoteFailure(
          error.toString(),
          trigger: trigger,
        );
        return null;
      }

      final refreshedSession = await _prepareSessionForRemoteAccess(
        trigger: '${trigger}_retry',
        forceRefresh: true,
        allowMobileDataOverride: allowMobileDataOverride,
        abgelehntesAccessToken: activeSession.accessToken,
      );
      if (refreshedSession == null || generation != _sessionGeneration) {
        return null;
      }

      try {
        return await action(refreshedSession);
      } catch (retryError) {
        if (generation == _sessionGeneration && _isUnauthorized(retryError)) {
          // Auch das frisch erneuerte Token wird abgelehnt.
          await _requireReloginForRemoteFailure(
            retryError.toString(),
            trigger: trigger,
          );
          return null;
        }
        rethrow;
      }
    }
  }

  static const String anderesKontoMeldung =
      'Du hast dich mit einem anderen Konto angemeldet. Die gespeicherten '
      'Daten gehören zum bisherigen Konto. Melde dich mit diesem Konto an '
      'oder wechsle über „Abmelden“.';

  /// Gehoert [neu] zu einem anderen Konto als die gespeicherten Daten?
  Future<bool> _istAnderesKonto(AuthSession neu) async {
    final bisher = await _sensitiveStorageService.loadPrincipal();
    if (bisher == null || bisher.isEmpty) {
      return false;
    }
    return neu.principal == null || neu.principal != bisher;
  }

  /// Meldet bei Hitobito neu an, waehrend die Session und die lokalen Daten
  /// bestehen bleiben. Nur fuer ausdrueckliche Nutzeraktionen wie „Neu
  /// anmelden“. Liefert `true`, wenn die Anmeldung samt Profil gelungen ist.
  Future<bool> neuAnmelden({String trigger = 'manual'}) async {
    if (_session == null ||
        _state == AuthState.unlockRequired ||
        _isNeuanmeldungAktiv) {
      return false;
    }

    _isNeuanmeldungAktiv = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _logger.logInfo(
        'auth_flow',
        'interaktiver relogin gestartet trigger=$trigger',
      );
      final authenticatedSession = await _anmeldenImBrowser();
      if (await _istAnderesKonto(authenticatedSession)) {
        // Die Neuanmeldung gehoert zum gespeicherten Konto. Daten und
        // vorgemerkte Aenderungen bleiben; ein Kontowechsel laeuft ueber
        // Abmelden, das vorher nachfragt.
        unawaited(_widerrufen(authenticatedSession));
        _errorMessage = anderesKontoMeldung;
        await _logger.logInfo(
          'auth_flow',
          'interaktiver relogin abgelehnt trigger=$trigger reason=other_account',
        );
        return false;
      }
      await _persistAuthenticatedSession(authenticatedSession);
      try {
        await _loadProfileFromRemote(authenticatedSession);
      } catch (error, stack) {
        if (!_isUnauthorized(error)) {
          await _logger.logError(
            'auth',
            'Profil nach interaktivem relogin fehlgeschlagen trigger=$trigger',
            error: error,
            stackTrace: stack,
          );
        }
        _errorMessage = nutzerFehlermeldung(error);
        return false;
      }
      await _logger.logInfo(
        'auth_flow',
        'interaktiver relogin erfolgreich trigger=$trigger',
      );
      _neuanmeldungen += 1;
      return true;
    } catch (error, stack) {
      if (error is HitobitoAuthException &&
          error.isExpectedInteractionFailure) {
        await _logger.logInfo(
          'auth_flow',
          'interaktiver relogin abgebrochen trigger=$trigger error_type=${error.runtimeType}',
        );
      } else {
        await _logger.logError(
          'auth',
          'interaktiver relogin fehlgeschlagen trigger=$trigger${_plattformCode(error)}',
          error: error,
          stackTrace: stack,
        );
      }
      _errorMessage = nutzerFehlermeldung(error);
      return false;
    } finally {
      _isNeuanmeldungAktiv = false;
      notifyListeners();
    }
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

    final generation = _sessionGeneration;
    try {
      await executeRemoteAccess<void>(
        trigger: force ? 'profile_force' : 'profile_load',
        action: _loadProfileFromRemote,
      );
      if (_requiresInteractiveLogin) {
        return;
      }
    } catch (error, stack) {
      if (generation != _sessionGeneration) {
        return;
      }
      if (!_isUnauthorized(error)) {
        await _logger.log(
          'auth',
          'Profil konnte nicht geladen werden: $error\n$stack',
        );
      }
      _errorMessage = nutzerFehlermeldung(error);
    } finally {
      _isLoadingProfile = false;
      notifyListeners();
    }
  }

  Future<void> syncHitobitoData({
    required Future<void> Function(String accessToken) syncMembers,
    bool force = false,
    String trigger = 'manual',
    bool userInitiated = true,
    bool allowMobileDataOverride = false,
  }) {
    return _syncHitobitoData(
      syncMembers: syncMembers,
      force: force,
      trigger: trigger,
      userInitiated: userInitiated,
      allowMobileDataOverride: allowMobileDataOverride,
    );
  }

  Future<void> _syncHitobitoData({
    required Future<void> Function(String accessToken) syncMembers,
    required bool force,
    required String trigger,
    required bool userInitiated,
    required bool allowMobileDataOverride,
  }) async {
    await _logger.logInfo(
      'hitobito_sync',
      'Hitobito-Sync angefragt trigger=$trigger force=$force userInitiated=$userInitiated',
    );

    if (_isSyncingHitobitoData) {
      await _logger.logInfo(
        'hitobito_sync',
        'Hitobito-Sync uebersprungen trigger=$trigger reason=already_running',
      );
      return;
    }

    if (_state == AuthState.initializing) {
      // Session und Sync-Zeitpunkte sind noch nicht geladen. Ein hier
      // gespeicherter Versuch wuerde den eigentlichen Start-Sync als nicht
      // faellig erscheinen lassen.
      await _logger.logInfo(
        'hitobito_sync',
        'Hitobito-Sync uebersprungen trigger=$trigger reason=initializing',
      );
      return;
    }

    if (_state == AuthState.unlockRequired) {
      // Kein Versuch speichern: Nach dem Entsperren soll der Sync faellig
      // bleiben.
      await _logger.logInfo(
        'hitobito_sync',
        'Hitobito-Sync uebersprungen trigger=$trigger reason=locked',
      );
      return;
    }

    if (_session == null ||
        _state == AuthState.reloginRequired ||
        _requiresInteractiveLogin) {
      await markSensitiveDataSyncAttempted();
      _lastSyncAttemptResult = SyncAttemptResult.loginRequired;
      notifyListeners();

      // Den Login-Browser oeffnet nur „Neu anmelden“; der Aufrufer fragt
      // anhand von [lastSyncAttemptResult] danach.
      await _logger.logInfo(
        'hitobito_sync',
        'Hitobito-Sync uebersprungen trigger=$trigger reason=login_required',
      );
      return;
    }

    if (!force && !isRefreshAttemptDue) {
      await _logger.logInfo(
        'hitobito_sync',
        'Hitobito-Sync uebersprungen trigger=$trigger reason=not_due',
      );
      return;
    }

    await markSensitiveDataSyncAttempted();
    final generation = _sessionGeneration;
    final syncToken = Object();
    _activeSyncToken = syncToken;
    _isSyncingHitobitoData = true;
    _isUserInitiatedSyncInProgress = userInitiated;
    notifyListeners();

    try {
      final profileLoaded = await executeRemoteAccess<bool>(
        trigger: '${trigger}_profile',
        forceRefresh: force,
        allowMobileDataOverride: allowMobileDataOverride,
        action: (session) async {
          await _loadProfileFromRemote(session);
          return true;
        },
      );
      if (generation != _sessionGeneration) {
        await _logSyncAbortedForEndedSession(trigger);
        return;
      }
      if (profileLoaded == null) {
        await _handleSyncWithoutRemoteAccess(
          trigger: trigger,
          phase: 'profile',
        );
        return;
      }
      // Die Profil-Phase hat das Token bei [force] bereits erneuert. Ein
      // zweiter erzwungener Refresh wuerde den Refresh-Token ohne Nutzen
      // erneut rotieren.
      final membersLoaded = await executeRemoteAccess<bool>(
        trigger: '${trigger}_members',
        allowMobileDataOverride: allowMobileDataOverride,
        action: (session) async {
          await syncMembers(session.accessToken);
          return true;
        },
      );
      if (generation != _sessionGeneration) {
        await _logSyncAbortedForEndedSession(trigger);
        return;
      }
      if (membersLoaded == null) {
        await _handleSyncWithoutRemoteAccess(
          trigger: trigger,
          phase: 'members',
        );
        return;
      }

      await markSensitiveDataSynced();
      _lastSyncAttemptResult = SyncAttemptResult.success;
      _errorMessage = null;
      _clearRemoteAccessIssue(notify: false);
      await _logger.logInfo(
        'hitobito_sync',
        'Hitobito-Sync erfolgreich trigger=$trigger',
      );
    } on NetworkAccessBlockedException catch (error) {
      if (generation != _sessionGeneration) {
        await _logSyncAbortedForEndedSession(trigger);
        return;
      }
      await _logger.logInfo(
        'hitobito_sync',
        'Hitobito-Sync blockiert ($trigger): ${error.message}',
      );
      _lastSyncAttemptResult = error.isBlockedByNoMobileData
          ? SyncAttemptResult.wifiOnly
          : SyncAttemptResult.networkError;
      _reportNetworkAccessBlockedIssue(error, notify: false);
      _zeigeHinweisErneutFuerManuellenSync(userInitiated);
    } catch (error, stack) {
      if (generation != _sessionGeneration) {
        await _logSyncAbortedForEndedSession(trigger);
        return;
      }
      await _logger.log(
        'hitobito_sync',
        'Hitobito-Sync fehlgeschlagen ($trigger): $error\n$stack',
      );
      _errorMessage ??= error.toString();
      // Bricht der Mitglieder-Sync ab, weil eine Anmeldung noetig ist, zaehlt
      // das wie bisher als Login-Pflicht und nicht als unbekannter Fehler.
      _lastSyncAttemptResult = _requiresInteractiveLogin
          ? SyncAttemptResult.loginRequired
          : _classifySyncError(error);
      reportRemoteDataIssue(
        error.toString(),
        requiresInteractiveLogin: _isUnauthorized(error),
        notify: false,
      );
      _zeigeHinweisErneutFuerManuellenSync(userInitiated);
    } finally {
      // Ein neuer Sync nach Logout oder Benutzerwechsel hat eigene Flags.
      if (identical(_activeSyncToken, syncToken)) {
        _activeSyncToken = null;
        _isSyncingHitobitoData = false;
        _isUserInitiatedSyncInProgress = false;
        notifyListeners();
      }
    }
  }

  /// Automatische Syncs melden eine Stoerung nur einmal. Wer selbst
  /// aktualisiert, bekommt bei jedem gescheiterten Versuch eine Rueckmeldung;
  /// eine noetige Neuanmeldung fragt der Aufrufer stattdessen ab.
  void _zeigeHinweisErneutFuerManuellenSync(bool userInitiated) {
    if (userInitiated && hasRemoteAccessIssue && !_requiresInteractiveLogin) {
      _hasShownRemoteAccessIssueNotice = false;
    }
  }

  Future<void> _handleSyncWithoutRemoteAccess({
    required String trigger,
    required String phase,
  }) async {
    if (_requiresInteractiveLogin) {
      _lastSyncAttemptResult = SyncAttemptResult.loginRequired;
      await _logger.logInfo(
        'hitobito_sync',
        'Hitobito-Sync abgebrochen trigger=$trigger phase=$phase reason=login_required',
      );
      return;
    }
    await _logger.logInfo(
      'hitobito_sync',
      'Hitobito-Sync abgebrochen trigger=$trigger phase=$phase reason=no_remote_access state=$_state',
    );
  }

  Future<void> _logSyncAbortedForEndedSession(String trigger) {
    return _logger.logInfo(
      'hitobito_sync',
      'Hitobito-Sync verworfen trigger=$trigger reason=session_ended',
    );
  }

  NextSyncDisplayKind? _resolveNextSyncKind() {
    if (_isSyncingHitobitoData) {
      return null;
    }
    return switch (_lastSyncAttemptResult) {
      SyncAttemptResult.wifiOnly => NextSyncDisplayKind.whenWifiAvailable,
      SyncAttemptResult.loginRequired => NextSyncDisplayKind.loginRequired,
      SyncAttemptResult.networkError ||
      SyncAttemptResult.serverError ||
      SyncAttemptResult.unknownError => NextSyncDisplayKind.atTime,
      SyncAttemptResult.success => NextSyncDisplayKind.atTime,
      null => _lastSensitiveSyncAt == null ? null : NextSyncDisplayKind.atTime,
    };
  }

  DateTime? _resolveNextSyncAt() {
    if (_isSyncingHitobitoData) {
      return null;
    }
    final attemptAt = _lastSensitiveSyncAttemptAt;
    return switch (_lastSyncAttemptResult) {
      SyncAttemptResult.networkError ||
      SyncAttemptResult.serverError ||
      SyncAttemptResult.unknownError => attemptAt?.add(
        const Duration(minutes: 10),
      ),
      SyncAttemptResult.success => _lastSensitiveSyncAt?.add(
        _retentionPolicy.refreshInterval,
      ),
      SyncAttemptResult.wifiOnly || SyncAttemptResult.loginRequired => null,
      null => _lastSensitiveSyncAt?.add(_retentionPolicy.refreshInterval),
    };
  }

  SyncAttemptResult _classifySyncError(Object error) {
    if (_isUnauthorized(error)) {
      return SyncAttemptResult.loginRequired;
    }
    // Zeitlimit und abgebrochene Verbindung: Hitobito war nicht erreichbar,
    // ein spaeterer Versuch kann gelingen.
    if (_istNichtErreichbar(error)) {
      return SyncAttemptResult.networkError;
    }
    final statusCode = switch (error) {
      HitobitoApiException(:final statusCode) => statusCode,
      HitobitoAuthException(:final statusCode) => statusCode,
      _ => null,
    };
    if (statusCode != null && (statusCode >= 500 || statusCode == 429)) {
      return SyncAttemptResult.serverError;
    }
    return SyncAttemptResult.unknownError;
  }

  Future<void> _loadProfileFromRemote(AuthSession session) async {
    final generation = _sessionGeneration;
    try {
      final loadedProfile = await _oauthService.fetchProfile(session);
      if (generation != _sessionGeneration) {
        return;
      }
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
        _errorMessage = nutzerFehlermeldung(error);
        reportRemoteDataIssue(
          error.toString(),
          requiresInteractiveLogin: false,
          notify: false,
        );
      }
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
    await sitzungFrischHalten(trigger: 'unlock');
  }

  /// Erneuert das Token still, wenn es aelter als
  /// [HitobitoAuthEnv.sitzungAuffrischenNach] ist. Hitobito loescht
  /// Refresh-Tokens nach etwa einer Woche ohne Erneuerung; der regulaere
  /// Sync erneuert nur, wenn er faellig ist und das Netz ihn erlaubt.
  /// Der Refresh uebertraegt nur wenige Bytes und laeuft deshalb auch bei
  /// eingeschraenkten mobilen Daten. Fehler bleiben still; nur ein
  /// Sitzungsende setzt [requiresInteractiveLogin].
  Future<void> sitzungFrischHalten({required String trigger}) async {
    final session = _session;
    if (session == null ||
        !session.canRefresh ||
        _state != AuthState.signedIn ||
        _requiresInteractiveLogin ||
        _retentionPolicy.now().difference(session.receivedAt) <
            HitobitoAuthEnv.sitzungAuffrischenNach) {
      return;
    }

    final generation = _sessionGeneration;
    try {
      await _networkAccessPolicy?.ensureNetworkAllowed(
        trigger: '${trigger}_token_refresh',
        feature: 'Hitobito',
        allowMobileDataOverride: true,
      );
      if (generation != _sessionGeneration || _session == null) {
        return;
      }
      final erneuert = await _erneuereGemeinsam(_session!, erzwingen: true);
      if (generation != _sessionGeneration) {
        return;
      }
      if (erneuert.accessToken != _session?.accessToken ||
          erneuert.refreshToken != _session?.refreshToken) {
        _session = erneuert;
        await _repository.save(erneuert);
        await _logger.log('auth_flow', 'Session still erneuert ($trigger)');
        notifyListeners();
      }
    } catch (error) {
      if (generation != _sessionGeneration) {
        return;
      }
      if (_istSitzungsende(error)) {
        await _requireReloginForRemoteFailure(
          error.toString(),
          trigger: trigger,
        );
        return;
      }
      await _logger.log(
        'auth_flow',
        'Stille Token-Erneuerung fehlgeschlagen ($trigger): $error',
      );
    }
  }

  Future<void> _clearBackgroundedAt() async {
    _lastBackgroundedAt = null;
    _backgroundedMonotonic = null;
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
    _lastSyncAttemptResult = null;
    if (_session == null) {
      // Ohne Sitzung gibt es keinen Speicher, dem der Versuch gehoert.
      return;
    }
    await _sensitiveStorageService.saveLastSensitiveSyncAttemptAt(attemptedAt);
  }

  void clearRemoteDataIssue() {
    _clearRemoteAccessIssue(notify: true);
  }

  void markRemoteAccessIssueNoticeShown() {
    if (!hasRemoteAccessIssue || _hasShownRemoteAccessIssueNotice) {
      return;
    }
    _hasShownRemoteAccessIssueNotice = true;
  }

  void reportRemoteDataIssue(
    String message, {
    bool requiresInteractiveLogin = false,
    bool notify = true,
  }) {
    final hadRemoteAccessIssue = hasRemoteAccessIssue;
    _remoteAccessIssueMessage = message;
    if (requiresInteractiveLogin) {
      _remoteAccessBlockedReason = null;
    }
    _requiresInteractiveLogin =
        _requiresInteractiveLogin || requiresInteractiveLogin;
    if (!hadRemoteAccessIssue) {
      _hasShownRemoteAccessIssueNotice = false;
    }
    if (notify) {
      notifyListeners();
    }
  }

  void _reportNetworkAccessBlockedIssue(
    NetworkAccessBlockedException error, {
    required bool notify,
  }) {
    final hadRemoteAccessIssue = hasRemoteAccessIssue;
    _errorMessage = error.message;
    _remoteAccessBlockedReason = error.reason;
    _remoteAccessIssueMessage = error.message;
    _requiresInteractiveLogin = false;
    if (!hadRemoteAccessIssue) {
      _hasShownRemoteAccessIssueNotice = false;
    }
    if (notify) {
      notifyListeners();
    }
  }

  void _clearRemoteAccessIssue({required bool notify}) {
    _remoteAccessIssueMessage = null;
    _remoteAccessBlockedReason = null;
    _requiresInteractiveLogin = false;
    _hasShownRemoteAccessIssueNotice = false;
    if (notify) {
      notifyListeners();
    }
  }

  static String _plattformCode(Object error) {
    final code = error is HitobitoAuthException ? error.plattformCode : null;
    return code == null ? '' : ' code=$code';
  }

  /// Der Token-Endpunkt hat die Sitzung beendet; nur eine neue Anmeldung
  /// hilft. Andere Refresh-Fehler lassen die Sitzung bestehen.
  bool _istSitzungsende(Object error) {
    if (error is! HitobitoAuthException) {
      return false;
    }
    return error.art == HitobitoAuthFehlerArt.sitzungBeendet ||
        (error.art == null && error.statusCode == 401);
  }

  /// Zeitlimit oder abgebrochene Verbindung: Hitobito hat gar nicht
  /// geantwortet.
  bool _istNichtErreichbar(Object error) {
    return error is TimeoutException || error is http.ClientException;
  }

  bool _istAbgelaufen(AuthSession session) {
    final expiresAt = session.expiresAt;
    return expiresAt != null && !expiresAt.isAfter(_retentionPolicy.now());
  }

  bool _isUnauthorized(Object error) {
    return (error is HitobitoAuthException && error.statusCode == 401) ||
        (error is HitobitoApiException && error.statusCode == 401);
  }

  Future<void> _logExpiredLoginRetry({required String trigger}) async {
    await _logger.logInfo(
      'auth_flow',
      'Login abgelaufen, versuche Retry trigger=$trigger',
    );
  }

  Future<void> _requireReloginForRemoteFailure(
    String message, {
    String? trigger,
  }) async {
    _errorMessage = message;
    reportRemoteDataIssue(
      message,
      requiresInteractiveLogin: true,
      notify: false,
    );
    await _logger.logInfo(
      'auth_flow',
      'Retry fehlgeschlagen, interaktiver Relogin fuer Remote-Zugriffe erforderlich${trigger == null ? '' : ' trigger=$trigger'}',
    );
    notifyListeners();
  }

  // Beendet die Sitzung sofort: Laufende Vorgaenge erkennen den Wechsel an
  // der Generation und koennen keine sensible Box mehr oeffnen.
  void _endSession() {
    _sessionGeneration += 1;
    _sensitiveStorageService.endSession();
  }

  Future<void> _purgeSensitiveData() async {
    _endSession();
    await _sensitiveStorageService.purgeSensitiveData();
    final purgeLocalPersonalData = _purgeLocalPersonalData;
    if (purgeLocalPersonalData == null) {
      return;
    }
    try {
      await purgeLocalPersonalData();
    } catch (error, stackTrace) {
      // Ein Cache-Fehler darf Logout und Datenablauf nicht abbrechen.
      await _logger.logError(
        'auth_flow',
        'Lokale Caches konnten nicht geloescht werden',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _expireSensitiveData() async {
    await _logger.log(
      'auth_flow',
      'Gespeicherte Daten sind abgelaufen und werden geloescht',
    );
    await logout();
  }
}

class _LaufenderRefresh {
  const _LaufenderRefresh({
    required this.quelle,
    required this.erzwungen,
    required this.ergebnis,
  });

  /// Refresh-Token, mit dem der Refresh gestartet wurde.
  final String? quelle;
  final bool erzwungen;
  final Future<AuthSession> ergebnis;
}

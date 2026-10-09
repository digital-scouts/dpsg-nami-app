import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../../domain/auth/auth_state.dart';
import '../../services/network_access_policy.dart';
import '../../services/wifi_sync_trigger.dart';
import 'auth_session_model.dart';
import 'member_edit_model.dart';

/// Steuert den automatischen Sync im Vordergrund: Bei erlaubter Verbindung
/// (Start, Resume, Verbindungswechsel, geaenderte Mobilfunk-Einstellung)
/// laeuft einmal der Hitobito-Sync mit anschliessendem Nachsenden der
/// ausstehenden Aenderungen; dazwischen prueft ein Timer, ob ein Retry laut
/// Backoff faellig ist.
///
/// Automatische Zugriffe oeffnen nie den interaktiven Login; ein abgelaufener
/// Login fuehrt stattdessen zu [AuthSessionModel.requiresInteractiveLogin].
class PendingSyncCoordinator {
  PendingSyncCoordinator({
    required Connectivity connectivity,
    required AuthSessionModel authModel,
    required MemberEditModel memberEditModel,
    required bool Function() noMobileDataEnabled,
    required Future<void> Function() syncMembers,
    WifiSyncTrigger? wifiSyncTrigger,
    bool pendingRetryEnabled = true,
    Duration pendingRetryInterval = const Duration(minutes: 1),
    void Function(PendingPersonUpdateRetrySummary summary)? onRetrySummary,
  }) : _onRetrySummary = onRetrySummary,
       _connectivity = connectivity,
       _authModel = authModel,
       _memberEditModel = memberEditModel,
       _noMobileDataEnabled = noMobileDataEnabled,
       _syncMembers = syncMembers,
       _wifiSyncTrigger = wifiSyncTrigger ?? WifiSyncTrigger(),
       _pendingRetryEnabled = pendingRetryEnabled,
       _pendingRetryInterval = pendingRetryInterval;

  final Connectivity _connectivity;
  final AuthSessionModel _authModel;
  final MemberEditModel _memberEditModel;
  final bool Function() _noMobileDataEnabled;
  final Future<void> Function() _syncMembers;
  final WifiSyncTrigger _wifiSyncTrigger;
  final bool _pendingRetryEnabled;
  final Duration _pendingRetryInterval;

  /// Ergebnis jedes automatischen Nachsendens, z. B. fuer einen Hinweis bei
  /// abgelehnten Aenderungen.
  final void Function(PendingPersonUpdateRetrySummary summary)? _onRetrySummary;

  bool _isPaused = false;
  bool _isForegroundSyncRunning = false;
  bool _waitsForAuthReady = false;
  int _bekannteNeuanmeldungen = 0;
  Timer? _pendingRetryTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  bool get isPaused => _isPaused;

  /// Startet Connectivity-Listener und Retry-Timer neu.
  void start() {
    _bekannteNeuanmeldungen = _authModel.neuanmeldungen;
    _authModel.removeListener(_handleAuthChanged);
    _authModel.addListener(_handleAuthChanged);
    _startConnectivityListener();
    _startPendingRetryTimer();
  }

  void pause() {
    _isPaused = true;
  }

  void resume() {
    _isPaused = false;
    _wifiSyncTrigger.reset();
    unawaited(checkCurrentConnectivity(trigger: 'resume'));
  }

  Future<void> checkCurrentConnectivity({required String trigger}) async {
    final connectionType = await _resolveCurrentConnectionType();
    await _handleForegroundSyncOpportunity(connectionType, trigger: trigger);
  }

  void dispose() {
    _authModel.removeListener(_handleAuthChanged);
    _pendingRetryTimer?.cancel();
    _pendingRetryTimer = null;
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
  }

  /// Laeuft die Auth-Initialisierung noch, sind Session und Sync-Zeitpunkte
  /// unbekannt; hinter der App-Sperre wird nicht synchronisiert. Statt die
  /// Verbindung dann als bereits genutzt zu werten, wird die Pruefung
  /// nachgeholt, sobald beides vorbei ist.
  ///
  /// Nach einer Neuanmeldung holt der Koordinator Sync und Nachsenden nach,
  /// die waehrend der abgelaufenen Anmeldung ausgefallen sind.
  void _handleAuthChanged() {
    if (_authModel.neuanmeldungen != _bekannteNeuanmeldungen) {
      _bekannteNeuanmeldungen = _authModel.neuanmeldungen;
      _waitsForAuthReady = false;
      _wifiSyncTrigger.reset();
      unawaited(checkCurrentConnectivity(trigger: 'relogin'));
      return;
    }
    if (!_waitsForAuthReady || _isAuthPending()) {
      return;
    }
    _waitsForAuthReady = false;
    unawaited(checkCurrentConnectivity(trigger: 'auth_ready'));
  }

  bool _isAuthPending() {
    final state = _authModel.state;
    return state == AuthState.initializing || state == AuthState.unlockRequired;
  }

  void _startConnectivityListener() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((
      results,
    ) {
      unawaited(
        _handleForegroundSyncOpportunity(
          NetworkAccessPolicy.classifyConnectivityResults(results),
          trigger: 'connectivity_changed',
        ),
      );
    });
  }

  void _startPendingRetryTimer() {
    _pendingRetryTimer?.cancel();
    if (!_pendingRetryEnabled) {
      return;
    }
    _pendingRetryTimer = Timer.periodic(_pendingRetryInterval, (_) {
      unawaited(
        _retryPendingPersonUpdatesIfPossible(trigger: 'pending_retry_timer'),
      );
    });
  }

  Future<NetworkConnectionType> _resolveCurrentConnectionType() async {
    final results = await _connectivity.checkConnectivity();
    return NetworkAccessPolicy.classifyConnectivityResults(results);
  }

  Future<void> _handleForegroundSyncOpportunity(
    NetworkConnectionType connectionType, {
    required String trigger,
  }) async {
    if (_isPaused) {
      return;
    }
    if (_isAuthPending()) {
      _waitsForAuthReady = true;
      return;
    }
    if (!_wifiSyncTrigger.shouldTrigger(
      connectionType,
      noMobileDataEnabled: _noMobileDataEnabled(),
    )) {
      return;
    }

    await _runForegroundSync(trigger: trigger);
  }

  Future<void> _runForegroundSync({required String trigger}) async {
    if (_isForegroundSyncRunning) {
      return;
    }

    _isForegroundSyncRunning = true;
    try {
      await _authModel.syncHitobitoData(
        syncMembers: (_) => _syncMembers(),
        trigger: trigger,
        userInitiated: false,
      );
      await _retryPendingPersonUpdatesIfPossible(trigger: '${trigger}_pending');
    } finally {
      _isForegroundSyncRunning = false;
    }
  }

  Future<void> _retryPendingPersonUpdatesIfPossible({
    required String trigger,
  }) async {
    if (_isPaused || _memberEditModel.isBusy) {
      return;
    }

    if (!_memberEditModel.hasDueAutomaticRetry) {
      return;
    }

    if (_authModel.state != AuthState.signedIn) {
      return;
    }

    final accessToken = _authModel.session?.accessToken;
    if (accessToken == null ||
        accessToken.isEmpty ||
        _authModel.requiresInteractiveLogin) {
      return;
    }

    final connectionType = await _resolveCurrentConnectionType();
    if (!_wifiSyncTrigger.isSyncAllowed(
      connectionType,
      noMobileDataEnabled: _noMobileDataEnabled(),
    )) {
      return;
    }

    final summary = await _memberEditModel.retryPending(
      accessToken: accessToken,
      trigger: trigger,
      automatic: true,
    );
    if (summary.results.isNotEmpty) {
      _onRetrySummary?.call(summary);
    }
  }
}

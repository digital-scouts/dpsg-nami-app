import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

import 'logger_service.dart';

enum NetworkConnectionType { wifi, mobile, offline, unknown }

enum NetworkAccessBlockedReason { offline, noMobileDataEnabled }

typedef NoMobileDataEnabledProvider = bool Function();

class NetworkAccessDecision {
  const NetworkAccessDecision._({
    required this.allowed,
    required this.connectionType,
    this.blockedReason,
    this.message,
  });

  const NetworkAccessDecision.allowed({required NetworkConnectionType type})
    : this._(allowed: true, connectionType: type);

  const NetworkAccessDecision.blocked({
    required NetworkConnectionType type,
    required NetworkAccessBlockedReason reason,
    required String message,
  }) : this._(
         allowed: false,
         connectionType: type,
         blockedReason: reason,
         message: message,
       );

  final bool allowed;
  final NetworkConnectionType connectionType;
  final NetworkAccessBlockedReason? blockedReason;
  final String? message;

  bool get isOffline => blockedReason == NetworkAccessBlockedReason.offline;
  bool get isBlockedByNoMobileData =>
      blockedReason == NetworkAccessBlockedReason.noMobileDataEnabled;
}

class NetworkAccessBlockedException implements Exception {
  const NetworkAccessBlockedException({
    required this.reason,
    required this.connectionType,
    required this.message,
  });

  final NetworkAccessBlockedReason reason;
  final NetworkConnectionType connectionType;
  final String message;

  bool get isOffline => reason == NetworkAccessBlockedReason.offline;
  bool get isBlockedByNoMobileData =>
      reason == NetworkAccessBlockedReason.noMobileDataEnabled;

  @override
  String toString() => message;
}

class NetworkAccessPolicy {
  NetworkAccessPolicy({
    Connectivity? connectivity,
    NoMobileDataEnabledProvider? noMobileDataEnabled,
    LoggerService? logger,
    Duration checkTimeout = const Duration(seconds: 3),
  }) : _connectivity = connectivity ?? Connectivity(),
       _noMobileDataEnabled = noMobileDataEnabled ?? _defaultNoMobileDataMode,
       _logger = logger,
       _checkTimeout = checkTimeout;

  final Connectivity _connectivity;
  final NoMobileDataEnabledProvider _noMobileDataEnabled;
  final LoggerService? _logger;
  final Duration _checkTimeout;

  static bool _defaultNoMobileDataMode() => false;

  bool get isNoMobileDataEnabled => _noMobileDataEnabled();

  Future<NetworkAccessDecision> evaluateAccess({
    required String trigger,
    String feature = 'Netzwerk',
  }) async {
    final connectionType = await _resolveConnectionType();
    if (connectionType == NetworkConnectionType.offline) {
      return NetworkAccessDecision.blocked(
        type: connectionType,
        reason: NetworkAccessBlockedReason.offline,
        message:
            'Das Geraet ist offline. $feature ist derzeit nicht verfuegbar.',
      );
    }

    if (isNoMobileDataEnabled && connectionType != NetworkConnectionType.wifi) {
      return NetworkAccessDecision.blocked(
        type: connectionType,
        reason: NetworkAccessBlockedReason.noMobileDataEnabled,
        message:
            'Keine Mobilen Daten ist aktiviert. $feature ist nur ueber WLAN verfuegbar.',
      );
    }

    return NetworkAccessDecision.allowed(type: connectionType);
  }

  Future<void> ensureNetworkAllowed({
    required String trigger,
    String feature = 'Netzwerkzugriff',
  }) async {
    final decision = await evaluateAccess(trigger: trigger, feature: feature);
    if (decision.allowed) {
      return;
    }

    await _logger?.log(
      'network',
      'Netzwerkzugriff blockiert: trigger=$trigger feature=$feature reason=${decision.blockedReason?.name ?? 'unknown'} connection=${decision.connectionType.name}',
    );
    throw NetworkAccessBlockedException(
      reason: decision.blockedReason!,
      connectionType: decision.connectionType,
      message: decision.message!,
    );
  }

  Future<NetworkConnectionType> _resolveConnectionType() async {
    final results = await _connectivity.checkConnectivity().timeout(
      _checkTimeout,
      onTimeout: () => const <ConnectivityResult>[],
    );
    final values = results.toSet();
    if (values.contains(ConnectivityResult.wifi) ||
        values.contains(ConnectivityResult.ethernet)) {
      return NetworkConnectionType.wifi;
    }
    if (values.contains(ConnectivityResult.mobile)) {
      return NetworkConnectionType.mobile;
    }
    if (values.isEmpty || values.contains(ConnectivityResult.none)) {
      return NetworkConnectionType.offline;
    }
    return NetworkConnectionType.unknown;
  }
}
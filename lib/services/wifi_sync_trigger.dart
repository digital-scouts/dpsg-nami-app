import 'network_access_policy.dart';

class WifiSyncTrigger {
  bool _hasTriggeredForCurrentAllowedConnection = false;

  void reset() {
    _hasTriggeredForCurrentAllowedConnection = false;
  }

  bool isSyncAllowed(
    NetworkConnectionType connectionType, {
    required bool noMobileDataEnabled,
  }) {
    return switch (connectionType) {
      NetworkConnectionType.wifi => true,
      NetworkConnectionType.mobile => !noMobileDataEnabled,
      NetworkConnectionType.offline || NetworkConnectionType.unknown => false,
    };
  }

  bool shouldTrigger(
    NetworkConnectionType connectionType, {
    required bool noMobileDataEnabled,
  }) {
    if (!isSyncAllowed(
      connectionType,
      noMobileDataEnabled: noMobileDataEnabled,
    )) {
      _hasTriggeredForCurrentAllowedConnection = false;
      return false;
    }

    if (_hasTriggeredForCurrentAllowedConnection) {
      return false;
    }

    _hasTriggeredForCurrentAllowedConnection = true;
    return true;
  }
}

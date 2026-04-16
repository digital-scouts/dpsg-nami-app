import 'network_access_policy.dart';

class WifiSyncTrigger {
  bool _hasTriggeredForCurrentWifiAvailability = false;

  void reset() {
    _hasTriggeredForCurrentWifiAvailability = false;
  }

  bool shouldTrigger(NetworkConnectionType connectionType) {
    if (connectionType != NetworkConnectionType.wifi) {
      _hasTriggeredForCurrentWifiAvailability = false;
      return false;
    }

    if (_hasTriggeredForCurrentWifiAvailability) {
      return false;
    }

    _hasTriggeredForCurrentWifiAvailability = true;
    return true;
  }
}

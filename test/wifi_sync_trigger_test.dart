import 'package:flutter_test/flutter_test.dart';
import 'package:nami/services/network_access_policy.dart';
import 'package:nami/services/wifi_sync_trigger.dart';

void main() {
  test('WifiSyncTrigger triggert genau einmal pro WLAN-Verfuegbarkeit', () {
    final trigger = WifiSyncTrigger();

    expect(trigger.shouldTrigger(NetworkConnectionType.offline), isFalse);
    expect(trigger.shouldTrigger(NetworkConnectionType.wifi), isTrue);
    expect(trigger.shouldTrigger(NetworkConnectionType.wifi), isFalse);

    expect(trigger.shouldTrigger(NetworkConnectionType.mobile), isFalse);
    expect(trigger.shouldTrigger(NetworkConnectionType.wifi), isTrue);

    trigger.reset();
    expect(trigger.shouldTrigger(NetworkConnectionType.wifi), isTrue);
  });
}

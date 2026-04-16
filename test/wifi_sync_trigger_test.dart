import 'package:flutter_test/flutter_test.dart';
import 'package:nami/services/network_access_policy.dart';
import 'package:nami/services/wifi_sync_trigger.dart';

void main() {
  test('WifiSyncTrigger triggert genau einmal pro erlaubter Verbindung', () {
    final trigger = WifiSyncTrigger();

    expect(
      trigger.shouldTrigger(
        NetworkConnectionType.offline,
        noMobileDataEnabled: true,
      ),
      isFalse,
    );
    expect(
      trigger.shouldTrigger(
        NetworkConnectionType.wifi,
        noMobileDataEnabled: true,
      ),
      isTrue,
    );
    expect(
      trigger.shouldTrigger(
        NetworkConnectionType.wifi,
        noMobileDataEnabled: true,
      ),
      isFalse,
    );

    expect(
      trigger.shouldTrigger(
        NetworkConnectionType.mobile,
        noMobileDataEnabled: true,
      ),
      isFalse,
    );
    expect(
      trigger.shouldTrigger(
        NetworkConnectionType.mobile,
        noMobileDataEnabled: false,
      ),
      isTrue,
    );
    expect(
      trigger.shouldTrigger(
        NetworkConnectionType.mobile,
        noMobileDataEnabled: false,
      ),
      isFalse,
    );

    expect(
      trigger.shouldTrigger(
        NetworkConnectionType.mobile,
        noMobileDataEnabled: true,
      ),
      isFalse,
    );
    expect(
      trigger.shouldTrigger(
        NetworkConnectionType.mobile,
        noMobileDataEnabled: false,
      ),
      isTrue,
    );

    trigger.reset();
    expect(
      trigger.shouldTrigger(
        NetworkConnectionType.wifi,
        noMobileDataEnabled: true,
      ),
      isTrue,
    );
  });
}

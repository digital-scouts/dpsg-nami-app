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
  test('WifiSyncTrigger triggert nie bei unbekannter Verbindung', () {
    final trigger = WifiSyncTrigger();

    expect(
      trigger.isSyncAllowed(
        NetworkConnectionType.unknown,
        noMobileDataEnabled: false,
      ),
      isFalse,
    );
    expect(
      trigger.shouldTrigger(
        NetworkConnectionType.unknown,
        noMobileDataEnabled: false,
      ),
      isFalse,
    );
    expect(
      trigger.shouldTrigger(
        NetworkConnectionType.wifi,
        noMobileDataEnabled: false,
      ),
      isTrue,
    );
    expect(
      trigger.shouldTrigger(
        NetworkConnectionType.unknown,
        noMobileDataEnabled: false,
      ),
      isFalse,
    );
    expect(
      trigger.shouldTrigger(
        NetworkConnectionType.wifi,
        noMobileDataEnabled: false,
      ),
      isTrue,
    );
  });

  test(
    'WifiSyncTrigger triggert nicht erneut bei Wechsel von WLAN zu mobil',
    () {
      final trigger = WifiSyncTrigger();

      expect(
        trigger.shouldTrigger(
          NetworkConnectionType.wifi,
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
          NetworkConnectionType.wifi,
          noMobileDataEnabled: false,
        ),
        isFalse,
      );
    },
  );

  test(
    'WifiSyncTrigger triggert nach WLAN-mobil-WLAN erneut bei Keine Mobilen Daten',
    () {
      final trigger = WifiSyncTrigger();

      expect(
        trigger.shouldTrigger(
          NetworkConnectionType.wifi,
          noMobileDataEnabled: true,
        ),
        isTrue,
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
          NetworkConnectionType.wifi,
          noMobileDataEnabled: true,
        ),
        isTrue,
      );
    },
  );
}

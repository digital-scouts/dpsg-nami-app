import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nami/services/network_access_policy.dart';

NetworkConnectionType _classify(List<ConnectivityResult> results) =>
    NetworkAccessPolicy.classifyConnectivityResults(results);

void main() {
  group('NetworkAccessPolicy.classifyConnectivityResults', () {
    test('wertet WLAN als wifi', () {
      expect(_classify([ConnectivityResult.wifi]), NetworkConnectionType.wifi);
    });

    test('wertet Ethernet als wifi', () {
      expect(
        _classify([ConnectivityResult.ethernet]),
        NetworkConnectionType.wifi,
      );
    });

    test('wertet Mobilfunk als mobile', () {
      expect(
        _classify([ConnectivityResult.mobile]),
        NetworkConnectionType.mobile,
      );
    });

    test('wertet leere Liste als offline', () {
      expect(_classify(<ConnectivityResult>[]), NetworkConnectionType.offline);
    });

    test('wertet none als offline', () {
      expect(
        _classify([ConnectivityResult.none]),
        NetworkConnectionType.offline,
      );
    });

    test('bevorzugt WLAN in gemischter Liste mit Mobilfunk', () {
      expect(
        _classify([ConnectivityResult.mobile, ConnectivityResult.wifi]),
        NetworkConnectionType.wifi,
      );
      expect(
        _classify([ConnectivityResult.vpn, ConnectivityResult.ethernet]),
        NetworkConnectionType.wifi,
      );
    });

    test('bevorzugt Mobilfunk vor VPN und Bluetooth', () {
      expect(
        _classify([
          ConnectivityResult.vpn,
          ConnectivityResult.bluetooth,
          ConnectivityResult.mobile,
        ]),
        NetworkConnectionType.mobile,
      );
    });

    test('wertet none gemischt mit WLAN als wifi', () {
      expect(
        _classify([ConnectivityResult.none, ConnectivityResult.wifi]),
        NetworkConnectionType.wifi,
      );
    });

    test('wertet none gemischt mit VPN als offline', () {
      expect(
        _classify([ConnectivityResult.none, ConnectivityResult.vpn]),
        NetworkConnectionType.offline,
      );
    });

    test('wertet other, VPN und Bluetooth als unknown', () {
      expect(
        _classify([ConnectivityResult.other]),
        NetworkConnectionType.unknown,
      );
      expect(
        _classify([ConnectivityResult.vpn]),
        NetworkConnectionType.unknown,
      );
      expect(
        _classify([ConnectivityResult.bluetooth]),
        NetworkConnectionType.unknown,
      );
      expect(
        _classify([ConnectivityResult.other, ConnectivityResult.vpn]),
        NetworkConnectionType.unknown,
      );
    });

    test('ignoriert doppelte Eintraege', () {
      expect(
        _classify([ConnectivityResult.mobile, ConnectivityResult.mobile]),
        NetworkConnectionType.mobile,
      );
    });
  });
}

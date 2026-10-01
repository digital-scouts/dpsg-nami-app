import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Steuerbare Verbindung: [set] aendert den aktuellen Zustand und meldet ihn
/// wie das Plugin ueber [onConnectivityChanged].
class FakeConnectivity implements Connectivity {
  FakeConnectivity([
    List<ConnectivityResult> initial = const <ConnectivityResult>[
      ConnectivityResult.none,
    ],
  ]) : _current = List<ConnectivityResult>.from(initial);

  FakeConnectivity.wifi() : this(const [ConnectivityResult.wifi]);

  FakeConnectivity.mobile() : this(const [ConnectivityResult.mobile]);

  FakeConnectivity.offline() : this(const [ConnectivityResult.none]);

  final StreamController<List<ConnectivityResult>> _changes =
      StreamController<List<ConnectivityResult>>.broadcast();
  List<ConnectivityResult> _current;
  int checkCount = 0;

  bool get hasListener => _changes.hasListener;

  void set(List<ConnectivityResult> results) {
    _current = List<ConnectivityResult>.from(results);
    _changes.add(List<ConnectivityResult>.unmodifiable(_current));
  }

  void setWifi() => set(const <ConnectivityResult>[ConnectivityResult.wifi]);

  void setMobile() =>
      set(const <ConnectivityResult>[ConnectivityResult.mobile]);

  void setOffline() => set(const <ConnectivityResult>[ConnectivityResult.none]);

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async {
    checkCount += 1;
    return List<ConnectivityResult>.unmodifiable(_current);
  }

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged => _changes.stream;

  Future<void> close() => _changes.close();
}

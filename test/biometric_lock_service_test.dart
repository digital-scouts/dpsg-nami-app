import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:nami/services/biometric_lock_service.dart';

class _FakeLocalAuthentication implements LocalAuthentication {
  _FakeLocalAuthentication({
    this.hardware = false,
    this.deviceSupported = false,
    this.deviceSupportedError,
    this.authenticateResult = true,
    this.authenticateError,
  });

  final bool hardware;
  final bool deviceSupported;
  final Object? deviceSupportedError;
  final bool authenticateResult;
  final Object? authenticateError;
  int authenticateCallCount = 0;
  bool? letztesPersistAcrossBackgrounding;

  @override
  Future<bool> get canCheckBiometrics async => hardware;

  @override
  Future<bool> isDeviceSupported() async {
    final error = deviceSupportedError;
    if (error != null) {
      throw error;
    }
    return deviceSupported;
  }

  @override
  Future<bool> authenticate({
    required String localizedReason,
    Iterable<Object?> authMessages = const <Object?>[],
    bool biometricOnly = false,
    bool sensitiveTransaction = true,
    bool persistAcrossBackgrounding = false,
  }) async {
    authenticateCallCount += 1;
    letztesPersistAcrossBackgrounding = persistAcrossBackgrounding;
    final error = authenticateError;
    if (error != null) {
      throw error;
    }
    return authenticateResult;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('isAvailable', () {
    test(
      'reine Biometrie-Hardware ohne Geraetesicherung gilt nicht (A-19)',
      () async {
        final service = BiometricLockService(
          localAuthentication: _FakeLocalAuthentication(hardware: true),
        );

        expect(await service.isAvailable(), isFalse);
      },
    );

    test('mit Displaysperre oder Geraetecode verfuegbar', () async {
      final service = BiometricLockService(
        localAuthentication: _FakeLocalAuthentication(deviceSupported: true),
      );

      expect(await service.isAvailable(), isTrue);
    });

    test('Plattformfehler gilt als nicht verfuegbar', () async {
      final service = BiometricLockService(
        localAuthentication: _FakeLocalAuthentication(
          deviceSupportedError: StateError('kein Activity'),
        ),
      );

      expect(await service.isAvailable(), isFalse);
    });
  });

  group('bestaetigen', () {
    test('ohne Geraetesicherung keine Abfrage und nicht verfuegbar', () async {
      final auth = _FakeLocalAuthentication(hardware: true);
      final service = BiometricLockService(localAuthentication: auth);

      expect(
        await service.bestaetigen(),
        AppSperreBestaetigung.nichtVerfuegbar,
      );
      expect(auth.authenticateCallCount, 0);
    });

    test('erfolgreiche Abfrage bestaetigt', () async {
      final auth = _FakeLocalAuthentication(deviceSupported: true);
      final service = BiometricLockService(localAuthentication: auth);

      expect(await service.bestaetigen(), AppSperreBestaetigung.bestaetigt);
      expect(auth.authenticateCallCount, 1);
    });

    test(
      'startet die Abfrage nach der PIN-Activity nicht erneut (Android 8.1)',
      () async {
        final auth = _FakeLocalAuthentication(deviceSupported: true);
        final service = BiometricLockService(localAuthentication: auth);

        await service.bestaetigen();
        expect(auth.letztesPersistAcrossBackgrounding, isFalse);

        await service.authenticate();
        expect(auth.letztesPersistAcrossBackgrounding, isFalse);
      },
    );

    test('abgelehnte Abfrage gilt als abgebrochen', () async {
      final service = BiometricLockService(
        localAuthentication: _FakeLocalAuthentication(
          deviceSupported: true,
          authenticateResult: false,
        ),
      );

      expect(await service.bestaetigen(), AppSperreBestaetigung.abgebrochen);
    });

    test('fehlende Zugangsdaten melden nicht verfuegbar', () async {
      final service = BiometricLockService(
        localAuthentication: _FakeLocalAuthentication(
          deviceSupported: true,
          authenticateError: const LocalAuthException(
            code: LocalAuthExceptionCode.noCredentialsSet,
          ),
        ),
      );

      expect(
        await service.bestaetigen(),
        AppSperreBestaetigung.nichtVerfuegbar,
      );
    });

    test('Abbruch durch Nutzer gilt als abgebrochen', () async {
      final service = BiometricLockService(
        localAuthentication: _FakeLocalAuthentication(
          deviceSupported: true,
          authenticateError: const LocalAuthException(
            code: LocalAuthExceptionCode.userCanceled,
          ),
        ),
      );

      expect(await service.bestaetigen(), AppSperreBestaetigung.abgebrochen);
    });

    test('unerwarteter Fehler gilt als abgebrochen', () async {
      final service = BiometricLockService(
        localAuthentication: _FakeLocalAuthentication(
          deviceSupported: true,
          authenticateError: StateError('Plugin'),
        ),
      );

      expect(await service.bestaetigen(), AppSperreBestaetigung.abgebrochen);
    });
  });

  group('authenticate', () {
    test('ohne Geraetesicherung fail-open ohne Abfrage', () async {
      final auth = _FakeLocalAuthentication(hardware: true);
      final service = BiometricLockService(localAuthentication: auth);

      expect(await service.authenticate(), isTrue);
      expect(auth.authenticateCallCount, 0);
    });

    test('Fehler bei der Abfrage entsperrt nicht', () async {
      final service = BiometricLockService(
        localAuthentication: _FakeLocalAuthentication(
          deviceSupported: true,
          authenticateError: const LocalAuthException(
            code: LocalAuthExceptionCode.noCredentialsSet,
          ),
        ),
      );

      expect(await service.authenticate(), isFalse);
    });

    test('abgelehnte Abfrage entsperrt nicht', () async {
      final service = BiometricLockService(
        localAuthentication: _FakeLocalAuthentication(
          deviceSupported: true,
          authenticateResult: false,
        ),
      );

      expect(await service.authenticate(), isFalse);
    });
  });
}

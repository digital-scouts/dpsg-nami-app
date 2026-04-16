import 'package:local_auth/local_auth.dart';

import 'logger_service.dart';

class BiometricLockService {
  BiometricLockService({
    LocalAuthentication? localAuthentication,
    LoggerService? logger,
  }) : _localAuthentication = localAuthentication ?? LocalAuthentication(),
       _logger = logger;

  final LocalAuthentication _localAuthentication;
  final LoggerService? _logger;

  Future<bool> isAvailable() async {
    try {
      final canCheckBiometrics = await _localAuthentication.canCheckBiometrics;
      final isDeviceSupported = await _localAuthentication.isDeviceSupported();
      return canCheckBiometrics || isDeviceSupported;
    } catch (error, stack) {
      await _logger?.log(
        'auth_biometric',
        'Verfuegbarkeitspruefung fehlgeschlagen: $error\n$stack',
      );
      return false;
    }
  }

  Future<bool> authenticate() async {
    if (!await isAvailable()) {
      return true;
    }

    try {
      final authenticated = await _localAuthentication.authenticate(
        localizedReason:
            'Bitte entsperre die App, um auf lokal gespeicherte DPSG-Daten zuzugreifen.',
        biometricOnly: false,
        sensitiveTransaction: true,
        persistAcrossBackgrounding: true,
      );
      return authenticated;
    } catch (error, stack) {
      await _logger?.log(
        'auth_biometric',
        'Lokale Entsperrung fehlgeschlagen: $error\n$stack',
      );
      return false;
    }
  }
}

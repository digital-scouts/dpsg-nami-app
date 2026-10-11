import 'package:local_auth/local_auth.dart';

import 'logger_service.dart';

/// Ergebnis einer Bestaetigung beim Ein- oder Ausschalten der App-Sperre.
enum AppSperreBestaetigung {
  bestaetigt,

  /// Weder Displaysperre bzw. Geraetecode noch Biometrie eingerichtet.
  nichtVerfuegbar,
  abgebrochen,
}

class BiometricLockService {
  BiometricLockService({
    LocalAuthentication? localAuthentication,
    LoggerService? logger,
  }) : _localAuthentication = localAuthentication ?? LocalAuthentication(),
       _logger = logger;

  final LocalAuthentication _localAuthentication;
  final LoggerService? _logger;

  /// Fehlende Geraetesicherung meldet das Plugin erst bei der Abfrage.
  static const _fehlendeSicherung = {
    LocalAuthExceptionCode.noCredentialsSet,
    LocalAuthExceptionCode.noBiometricHardware,
    LocalAuthExceptionCode.noBiometricsEnrolled,
  };

  /// Ob eine Displaysperre bzw. ein Geraetecode oder eingerichtete Biometrie
  /// vorhanden ist. `canCheckBiometrics` meldet unter Android schon reine
  /// Biometrie-Hardware und taugt deshalb nicht als Pruefung.
  Future<bool> isAvailable() async {
    try {
      return await _localAuthentication.isDeviceSupported();
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
      return await _abfrage();
    } catch (error, stack) {
      await _logger?.log(
        'auth_biometric',
        'Lokale Entsperrung fehlgeschlagen: $error\n$stack',
      );
      return false;
    }
  }

  /// Verlangt vor dem Ein- oder Ausschalten der Sperre einmal Biometrie oder
  /// Geraetecode. Anders als [authenticate] gilt fehlende Geraetesicherung
  /// nicht als Erfolg.
  Future<AppSperreBestaetigung> bestaetigen() async {
    if (!await isAvailable()) {
      return AppSperreBestaetigung.nichtVerfuegbar;
    }

    try {
      return await _abfrage()
          ? AppSperreBestaetigung.bestaetigt
          : AppSperreBestaetigung.abgebrochen;
    } on LocalAuthException catch (error) {
      await _logger?.log(
        'auth_biometric',
        'Bestaetigung der App-Sperre fehlgeschlagen: ${error.code.name}',
      );
      return _fehlendeSicherung.contains(error.code)
          ? AppSperreBestaetigung.nichtVerfuegbar
          : AppSperreBestaetigung.abgebrochen;
    } catch (error, stack) {
      await _logger?.log(
        'auth_biometric',
        'Bestaetigung der App-Sperre fehlgeschlagen: $error\n$stack',
      );
      return AppSperreBestaetigung.abgebrochen;
    }
  }

  Future<bool> _abfrage() {
    return _localAuthentication.authenticate(
      localizedReason:
          'Bitte entsperre die App, um auf lokal gespeicherte DPSG-Daten zuzugreifen.',
      biometricOnly: false,
      sensitiveTransaction: true,
      // Unter aelterem Android (geprueft 8.1) ist die PIN-Abfrage eine eigene
      // Activity; mit persistAcrossBackgrounding startet local_auth nach
      // deren Ende eine zweite Abfrage, die erst ein weiteres Abbrechen
      // schliesst und den Fingerabdruck ins Leere laufen laesst. Entsperrt
      // wird nur auf Tipp, nach einem Abbruch genuegt erneutes Tippen.
      persistAcrossBackgrounding: false,
    );
  }
}

import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../services/hitobito_api_exception.dart';
import '../../services/hitobito_groups_service.dart';
import '../../services/hitobito_oauth_service.dart';
import '../../services/network_access_policy.dart';

/// Übersetzt einen Fehler in eine Meldung für die Oberfläche.
///
/// Serverantworten, Stacktraces und Ausnahmetexte gehören nicht in die App,
/// sondern ins Log (Einstellungen → Debug & Tools → Logs & Diagnose). Texte,
/// die die App selbst formuliert (Anmeldung, Netzrichtlinie), bleiben.
String nutzerFehlermeldung(Object error) {
  const details = 'Details stehen in den Einstellungen unter „Debug & Tools“.';
  return switch (error) {
    HitobitoAuthException(:final message) => message,
    NetworkAccessBlockedException(:final message) => message,
    // Bekannter Fehler in Hitobito: Eine Gruppe mit ungültigen Daten (z. B.
    // leere PLZ) lässt die ganze Gruppenliste scheitern.
    HitobitoGroupsException(statusCode: 400) =>
      'Hitobito konnte die Gruppen nicht liefern (Fehler 400). Meist steckt '
          'eine Gruppe mit fehlerhaften Daten dahinter. In den Einstellungen '
          'unter „Debug & Tools“ findet „Fehlerhafte Gruppe suchen“ sie.',
    HitobitoApiException(statusCode: final code?)
        when code == 401 || code == 403 =>
      'Hitobito hat den Zugriff verweigert (Fehler $code). Bitte melde dich '
          'erneut an.',
    HitobitoApiException(statusCode: final code?) when code >= 500 =>
      'Hitobito hat einen Serverfehler gemeldet (Fehler $code). Bitte '
          'versuche es später erneut.',
    HitobitoApiException(statusCode: final code?) =>
      'Hitobito hat die Anfrage abgelehnt (Fehler $code). $details',
    HitobitoApiException() =>
      'Hitobito hat unerwartete Daten geliefert. $details',
    SocketException() ||
    TimeoutException() ||
    HandshakeException() ||
    http.ClientException() =>
      'Hitobito ist gerade nicht erreichbar. Bitte prüfe die Verbindung und '
          'versuche es erneut.',
    _ => 'Beim Laden ist ein unerwarteter Fehler aufgetreten. $details',
  };
}

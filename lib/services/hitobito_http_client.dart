import 'dart:async';

import 'package:http/http.dart' as http;

/// HTTP-Client fuer Hitobito mit Zeitlimits.
///
/// Der `dart:io`-Client wartet auf eine stumme Verbindung (Netzwechsel,
/// Captive Portal) unbegrenzt. Dann haengen Sync, Anmeldung und Ladebalken bis
/// zum Neustart der App. Dieser Client bricht deshalb mit einer
/// [TimeoutException] ab, wenn die Antwort-Header nicht innerhalb von
/// [antwortZeitlimit] eintreffen oder der Body laenger als [leerlaufZeitlimit]
/// keine Daten liefert.
class HitobitoHttpClient extends http.BaseClient {
  HitobitoHttpClient({
    http.Client? inner,
    this.antwortZeitlimit = standardZeitlimit,
    this.leerlaufZeitlimit = standardZeitlimit,
  }) : _inner = inner ?? http.Client();

  static const Duration standardZeitlimit = Duration(seconds: 30);

  /// Fuer Token- und Profil-Anfragen: kleine Antworten, auf die eine
  /// Anmeldung wartet.
  static const Duration anmeldungZeitlimit = Duration(seconds: 20);

  final http.Client _inner;
  final Duration antwortZeitlimit;
  final Duration leerlaufZeitlimit;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await _inner
        .send(request)
        .timeout(
          antwortZeitlimit,
          onTimeout: () => throw TimeoutException(
            'Keine Antwort von ${request.url.host}',
            antwortZeitlimit,
          ),
        );
    return http.StreamedResponse(
      response.stream.timeout(
        leerlaufZeitlimit,
        onTimeout: (sink) {
          sink
            ..addError(
              TimeoutException(
                'Antwort von ${request.url.host} abgebrochen',
                leerlaufZeitlimit,
              ),
            )
            ..close();
        },
      ),
      response.statusCode,
      contentLength: response.contentLength,
      request: response.request,
      headers: response.headers,
      isRedirect: response.isRedirect,
      persistentConnection: response.persistentConnection,
      reasonPhrase: response.reasonPhrase,
    );
  }

  @override
  void close() => _inner.close();
}

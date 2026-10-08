import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:nami/services/hitobito_http_client.dart';

class _HaengenderClient extends http.BaseClient {
  _HaengenderClient({this.koerper});

  /// Ohne Koerper kommen nie Header an; mit Koerper kommen sie sofort, der
  /// Body stammt aus diesem Stream.
  final Stream<List<int>>? koerper;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    final stream = koerper;
    if (stream == null) {
      return Completer<http.StreamedResponse>().future;
    }
    return Future.value(http.StreamedResponse(stream, 200, request: request));
  }
}

void main() {
  final uri = Uri.parse('https://hitobito.example/api/people');

  test('bricht ab, wenn keine Antwort-Header kommen', () async {
    final client = HitobitoHttpClient(
      inner: _HaengenderClient(),
      antwortZeitlimit: const Duration(milliseconds: 10),
    );

    await expectLater(client.get(uri), throwsA(isA<TimeoutException>()));
  });

  test('bricht ab, wenn der Body stockt', () async {
    final koerper = StreamController<List<int>>();
    addTearDown(koerper.close);
    final client = HitobitoHttpClient(
      inner: _HaengenderClient(koerper: koerper.stream),
      leerlaufZeitlimit: const Duration(milliseconds: 10),
    );
    koerper.add(utf8.encode('{"data":'));

    await expectLater(client.get(uri), throwsA(isA<TimeoutException>()));
  });

  test('reicht vollstaendige Antworten unveraendert durch', () async {
    final client = HitobitoHttpClient(
      inner: _HaengenderClient(
        koerper: Stream.value(utf8.encode('{"data":[]}')),
      ),
      antwortZeitlimit: const Duration(milliseconds: 10),
      leerlaufZeitlimit: const Duration(milliseconds: 10),
    );

    final response = await client.get(uri);

    expect(response.statusCode, 200);
    expect(response.body, '{"data":[]}');
  });
}

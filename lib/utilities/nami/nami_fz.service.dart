import 'package:nami/utilities/hive/settings.dart';
import 'package:nami/utilities/logger.dart';

import 'package:http/http.dart' as http;
import 'package:nami/utilities/nami/model/nami_fz.model.dart';
import 'package:nami/utilities/nami/nami.service.dart';
import 'package:nami/utilities/types.dart';

Future<List<FzDocument>> loadFzDocumenets() async {
  String url = getNamiLUrl();
  String fullUrl =
      '$url/ica/rest/nami/fz/eigene-bescheinigungen/flist?page=1&start=0&limit=15';

  sensLog.i('Request: Lade Führungszeugnis Dokumente');
  final body = await withMaybeRetry(() async {
    final cookie = getNamiApiCookie();
    return await http.get(Uri.parse(fullUrl), headers: {'Cookie': cookie});
  });

  if (!body['success']) {
    sensLog.e('Failed to load Führungszeugnisse.');
    throw Exception('Failed to load Führungszeugnisse');
  }

  List<FzDocument> documents = body['data']
      .map((item) => FzDocument.fromJson(item))
      .toList()
      .cast<FzDocument>();

  return documents;
}

Future<List<int>> loadFzDocument(int id) async {
  String url = getNamiLUrl();
  String fullUrl =
      '$url/ica/rest/nami/fz/eigene-bescheinigungen/download-pdf-eigene-bescheinigung?&id=$id';

  sensLog.i('Request: Lade Führungszeugnis Dokument');
  return loadPdfDocument(fullUrl);
}

Future<List<int>> loadFzAntrag() async {
  String url = getNamiLUrl();
  String fullUrl = '$url/ica/rest/fz-beantragen/download-beantragung';

  sensLog.i('Request: Lade Führungszeugnis Antragsunterlagen');
  return loadPdfDocument(fullUrl);
}

Future<List<int>> loadPdfDocument(String url) async {
  sensLog.i('Request: Lade Führungszeugnis Dokument');

  final cookie = getNamiApiCookie();
  final body = await http.get(Uri.parse(url), headers: {'Cookie': cookie});

  // Check if cookie is still valid - withMaybeRetry does not work here
  if (body.statusCode != 200) {
    sensLog.e('Failed to load Führungszeugnis Dokument.');
    throw SessionExpired();
  }

  return body.bodyBytes;
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../domain/bundesstatistik/bundesaggregat.dart';
import '../../domain/bundesstatistik/bundesstatistik_repository.dart';
import '../../domain/bundesstatistik/installation_credentials.dart';
import '../../domain/bundesstatistik/stammes_snapshot.dart';

/// HTTP-Anbindung an den Statistikserver (`server/spec/*.md`).
class HttpBundesstatistikRepository implements BundesstatistikRepository {
  HttpBundesstatistikRepository({
    required String baseUrl,
    http.Client? httpClient,
    Duration timeout = const Duration(seconds: 10),
  }) : _baseUri = Uri.parse(baseUrl.endsWith('/') ? baseUrl : '$baseUrl/'),
       _httpClient = httpClient ?? http.Client(),
       _timeout = timeout;

  final Uri _baseUri;
  final http.Client _httpClient;
  final Duration _timeout;

  @override
  Future<void> sendeSnapshot(
    StammesSnapshot snapshot,
    InstallationCredentials credentials,
  ) async {
    final response = await _send(
      () => _httpClient.post(
        _baseUri.resolve('snapshots/stamm'),
        headers: <String, String>{
          ..._authHeaders(credentials),
          'content-type': 'application/json',
        },
        body: jsonEncode(snapshot.toJson()),
      ),
    );

    if (response.statusCode != 204 && response.statusCode != 200) {
      throw _exceptionFor(response);
    }
  }

  @override
  Future<Bundesaggregat> ladeBundesaggregat(
    InstallationCredentials credentials,
  ) async {
    final response = await _send(
      () => _httpClient.get(
        _baseUri.resolve('aggregates/bund/latest'),
        headers: <String, String>{
          ..._authHeaders(credentials),
          'x-sender-id': credentials.id,
        },
      ),
    );

    if (response.statusCode != 200) {
      throw _exceptionFor(response);
    }

    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Antwort ist kein Objekt');
      }
      return Bundesaggregat.fromJson(decoded);
    } on FormatException {
      throw const BundesstatistikException(
        BundesstatistikFehlerArt.unbekannt,
        code: 'invalid_response',
        statusCode: 200,
      );
    }
  }

  Map<String, String> _authHeaders(InstallationCredentials credentials) =>
      <String, String>{
        'authorization': 'Bearer ${credentials.secret}',
        'accept': 'application/json',
      };

  Future<http.Response> _send(Future<http.Response> Function() request) async {
    try {
      return await request().timeout(_timeout);
    } on TimeoutException {
      throw const BundesstatistikException(
        BundesstatistikFehlerArt.netzwerk,
        code: 'timeout',
      );
    } on SocketException {
      throw const BundesstatistikException(BundesstatistikFehlerArt.netzwerk);
    } on http.ClientException {
      throw const BundesstatistikException(BundesstatistikFehlerArt.netzwerk);
    }
  }

  BundesstatistikException _exceptionFor(http.Response response) {
    final code = _errorCode(response);
    final art = switch ((response.statusCode, code)) {
      (401, _) => BundesstatistikFehlerArt.ungueltigeCredentials,
      (403, _) => BundesstatistikFehlerArt.nichtTeilnehmend,
      (429, _) => BundesstatistikFehlerArt.zuVieleAnfragen,
      (400, _) => BundesstatistikFehlerArt.abgelehnt,
      _ => BundesstatistikFehlerArt.unbekannt,
    };
    return BundesstatistikException(
      art,
      code: code,
      statusCode: response.statusCode,
    );
  }

  String? _errorCode(http.Response response) {
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, dynamic>) {
        final error = decoded['error'];
        if (error is Map<String, dynamic>) {
          return error['code']?.toString();
        }
      }
    } catch (_) {
      // Keine strukturierte Fehlerantwort, z. B. von einem Proxy.
    }
    return null;
  }
}

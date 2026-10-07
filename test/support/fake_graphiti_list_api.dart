import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Ein Datensatz eines Listen-Endpunkts von [FakeGraphitiListApi].
class GraphitiRecord {
  const GraphitiRecord({
    required this.id,
    required this.attributes,
    this.included = const <Map<String, dynamic>>[],
  });

  final int id;
  final Map<String, dynamic> attributes;

  /// Sideloads, die bei gesetztem `include` mit ausgeliefert werden.
  final List<Map<String, dynamic>> included;
}

/// Nachbildung der Hitobito-Listen-Endpunkte (Graphiti) fuer einen
/// `MockClient`: 20 Eintraege je Seite ohne `page[size]`, hoechstens 1000,
/// Offset-Paging ueber `page[number]` und `links.next`, Filter als
/// kommagetrennte Liste (`filter[x]` oder `filter[x][eq]`), `sort` und
/// `fields`. Jeder Request wird gezaehlt.
///
/// Mit [instabileReihenfolge] ordnet der Fake Eintraege ohne eindeutige
/// Sortierung je Request anders an, wie PostgreSQL bei LIMIT/OFFSET ohne
/// eindeutiges ORDER BY.
class FakeGraphitiListApi {
  FakeGraphitiListApi({this.instabileReihenfolge = false});

  static const int standardSeitengroesse = 20;
  static const int maxSeitengroesse = 1000;

  final bool instabileReihenfolge;

  final Map<String, List<GraphitiRecord>> _ressourcen =
      <String, List<GraphitiRecord>>{};

  /// Pro Gruppen-ID das Attribut, an dessen Serialisierung die ganze Seite
  /// mit 500 scheitert (z.B. eine nicht numerische PLZ in `zip_code`).
  final Map<int, String> defekteGruppen = <int, String>{};

  final List<Uri> requests = <Uri>[];

  late final http.Client client = MockClient(_handle);

  void setze(String typ, List<GraphitiRecord> records) {
    _ressourcen[typ] = List<GraphitiRecord>.of(records);
  }

  int anfragen(String typ) =>
      requests.where((uri) => uri.path == '/api/$typ').length;

  Map<String, int> anfragenJeRessource() {
    final result = <String, int>{};
    for (final uri in requests) {
      final typ = uri.path.replaceFirst('/api/', '');
      result[typ] = (result[typ] ?? 0) + 1;
    }
    return result;
  }

  Future<http.Response> _handle(http.Request request) async {
    requests.add(request.url);
    final typ = request.url.path.replaceFirst('/api/', '');
    final records = _ressourcen[typ];
    if (records == null) {
      return http.Response('', 404);
    }
    final query = request.url.queryParameters;

    final seitengroesse =
        int.tryParse(query['page[size]'] ?? '') ?? standardSeitengroesse;
    if (seitengroesse > maxSeitengroesse) {
      return http.Response('{"errors":[{"title":"page size"}]}', 400);
    }
    final seite = int.tryParse(query['page[number]'] ?? '') ?? 1;

    final gefiltert = records.where((record) => _passt(record, query)).toList();
    final sortiert = _sortiere(gefiltert, query['sort']);
    final start = (seite - 1) * seitengroesse;
    final seitenRecords = sortiert
        .skip(start)
        .take(seitengroesse)
        .toList(growable: false);

    final felder = query['fields[$typ]']?.split(',').toSet();
    if (typ == 'groups') {
      for (final record in seitenRecords) {
        final defekt = defekteGruppen[record.id];
        if (defekt != null && (felder == null || felder.contains(defekt))) {
          return http.Response('{"errors":[{"title":"Internal"}]}', 500);
        }
      }
    }

    final hatWeitere = start + seitengroesse < sortiert.length;
    final next = hatWeitere
        ? request.url.replace(
            queryParameters: <String, String>{
              ...query,
              'page[number]': '${seite + 1}',
              'page[size]': '$seitengroesse',
            },
          )
        : null;

    final included = <String, Map<String, dynamic>>{};
    if ((query['include'] ?? '').isNotEmpty) {
      for (final record in seitenRecords) {
        for (final entry in record.included) {
          included['${entry['type']}-${entry['id']}'] = entry;
        }
      }
    }

    return http.Response(
      jsonEncode(<String, dynamic>{
        'data': <Map<String, dynamic>>[
          for (final record in seitenRecords)
            <String, dynamic>{
              'id': '${record.id}',
              'type': typ,
              'attributes': <String, dynamic>{
                for (final entry in record.attributes.entries)
                  if (felder == null || felder.contains(entry.key))
                    entry.key: entry.value,
              },
            },
        ],
        'included': included.values.toList(),
        'links': <String, dynamic>{'next': next?.toString()},
      }),
      200,
      headers: <String, String>{'content-type': 'application/vnd.api+json'},
    );
  }

  bool _passt(GraphitiRecord record, Map<String, String> query) {
    for (final entry in query.entries) {
      final match = RegExp(
        r'^filter\[(\w+)\](?:\[eq\])?$',
      ).firstMatch(entry.key);
      if (match == null) {
        continue;
      }
      final feld = match.group(1)!;
      final wert = feld == 'id' ? record.id : record.attributes[feld];
      if (!entry.value.split(',').contains('$wert')) {
        return false;
      }
    }
    return true;
  }

  List<GraphitiRecord> _sortiere(List<GraphitiRecord> records, String? sort) {
    final result = List<GraphitiRecord>.of(records);
    if (instabileReihenfolge) {
      result.shuffle(Random(requests.length));
    }
    if (sort == null || sort.isEmpty) {
      return result;
    }
    final absteigend = sort.startsWith('-');
    final feld = absteigend ? sort.substring(1) : sort;
    Comparable<Object?>? schluessel(GraphitiRecord record) =>
        (feld == 'id' ? record.id : record.attributes[feld])
            as Comparable<Object?>?;
    // List.sort ist nicht stabil zugesichert; Gleichstaende behalten hier
    // bewusst die (ggf. gemischte) Reihenfolge des Requests.
    final indexed = result.asMap().entries.toList()
      ..sort((a, b) {
        final ka = schluessel(a.value);
        final kb = schluessel(b.value);
        final vergleich = ka == null || kb == null
            ? 0
            : (absteigend ? kb.compareTo(ka) : ka.compareTo(kb));
        return vergleich != 0 ? vergleich : a.key.compareTo(b.key);
      });
    return indexed.map((entry) => entry.value).toList();
  }
}

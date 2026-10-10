import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/veranstaltung/veranstaltung.dart';
import 'hitobito_api_exception.dart';
import 'hitobito_auth_env.dart';
import 'hitobito_http_client.dart';
import 'hitobito_pagination.dart';
import 'hitobito_traffic_log_service.dart';
import 'logger_service.dart';

class HitobitoEventsException extends HitobitoApiException {
  const HitobitoEventsException(super.message, {super.statusCode});
}

/// Liest Kurse und Veranstaltungen aus `/api/events` (nur Hitobito-Core).
/// Kurse kommen als JSON:API-Typ `courses`, einfache Events als `events`;
/// beide teilen sich die Felder, Kurse liefern zusaetzlich Belegung und
/// Leitung.
class HitobitoEventsService {
  HitobitoEventsService({
    required this.config,
    http.Client? httpClient,
    HitobitoTrafficLogService? trafficLogService,
    LoggerService? logger,
  }) : _httpClient = httpClient ?? HitobitoHttpClient(),
       _trafficLogService = trafficLogService,
       _logger = logger;

  HitobitoAuthConfig config;
  final http.Client _httpClient;
  final HitobitoTrafficLogService? _trafficLogService;
  final LoggerService? _logger;

  static const String kursTyp = 'Event::Course';

  /// Felder fuer Liste und Detail; `description` und
  /// `application_conditions` braucht nur das Detail.
  static const String _listenFelder =
      'type,name,group_ids,kind_id,motto,location,cost,'
      'application_opening_at,application_closing_at,maximum_participants,'
      'participant_count,external_application_link';
  static const String _detailFelder =
      '$_listenFelder,description,application_conditions';
  static const String _terminFelder = 'label,location,start_at,finish_at';
  static const String _kursartFelder =
      'label,short_name,minimum_age,kind_category';
  static const String _kursartDetailFelder =
      '$_kursartFelder,general_information,application_conditions';

  /// Groesse der ID-Bloecke fuer `filter[id]` bzw. `filter[group_id]`, damit
  /// die URL kurz bleibt.
  static const int idBlockGroesse = 200;

  void updateConfig(HitobitoAuthConfig nextConfig) {
    config = nextConfig;
  }

  /// Events mit einem Termin ab [abTag]. Mit [gruppenIds] nur Events dieser
  /// Gruppen; ohne alle, die Hitobito der Person zeigt.
  Future<List<Veranstaltung>> fetchVeranstaltungen(
    String accessToken, {
    required DateTime abTag,
    Set<int>? gruppenIds,
  }) async {
    final requestUri = config.eventsUri;
    if (requestUri == null) {
      throw const HitobitoEventsException(
        'Der Events-Endpoint konnte nicht aus der OAuth-Konfiguration abgeleitet werden.',
      );
    }
    final basisFilter = <String, String>{'filter[after_or_on]': _datum(abTag)};
    if (gruppenIds == null) {
      return _fetchListe(requestUri, accessToken, basisFilter);
    }
    if (gruppenIds.isEmpty) {
      return const <Veranstaltung>[];
    }
    final ids = gruppenIds.toList()..sort();
    final ergebnis = <int, Veranstaltung>{};
    for (var i = 0; i < ids.length; i += idBlockGroesse) {
      final block = ids.sublist(
        i,
        i + idBlockGroesse > ids.length ? ids.length : i + idBlockGroesse,
      );
      final teil = await _fetchListe(requestUri, accessToken, {
        ...basisFilter,
        'filter[group_id]': block.join(','),
      });
      for (final veranstaltung in teil) {
        ergebnis[veranstaltung.id] = veranstaltung;
      }
    }
    return ergebnis.values.toList(growable: false);
  }

  /// Ein Event mit Beschreibung, Kontakt, Leitung und Kursart-Details.
  Future<Veranstaltung> fetchVeranstaltung(
    String accessToken, {
    required int id,
  }) async {
    final basis = config.eventsUri;
    if (basis == null) {
      throw const HitobitoEventsException(
        'Der Events-Endpoint konnte nicht aus der OAuth-Konfiguration abgeleitet werden.',
      );
    }
    final uri = basis.replace(
      path: '${basis.path}/$id',
      queryParameters: <String, String>{
        'include': 'dates,kind.kind_category,contact,leaders',
        'fields[events]': _detailFelder,
        'fields[courses]': _detailFelder,
        'fields[dates]': _terminFelder,
        'fields[event_kinds]': _kursartDetailFelder,
        'fields[event_kind_categories]': 'label',
        'fields[people]': 'first_name,last_name,nickname',
      },
    );
    final decoded = await _fetch(uri, accessToken);
    final data = decoded['data'];
    if (data is! Map<String, dynamic>) {
      throw const HitobitoEventsException(
        'Event-Antwort enthält keinen gültigen Datensatz.',
      );
    }
    final included = _Included(decoded['included']);
    final veranstaltung = _mapEvent(data, included, mitPersonen: true);
    if (veranstaltung == null) {
      throw const HitobitoEventsException(
        'Event-Antwort enthält keinen gültigen Datensatz.',
      );
    }
    return veranstaltung;
  }

  /// Namen von Gruppen, die die App nicht aus dem Arbeitskontext kennt, z. B.
  /// Bezirk, Dioezese oder andere Staemme als Veranstalter.
  Future<Map<int, String>> fetchGruppenNamen(
    String accessToken,
    Set<int> gruppenIds,
  ) async {
    final requestUri = config.groupsUri;
    if (requestUri == null || gruppenIds.isEmpty) {
      return const <int, String>{};
    }
    final ids = gruppenIds.toList()..sort();
    final namen = <int, String>{};
    for (var i = 0; i < ids.length; i += idBlockGroesse) {
      final block = ids.sublist(
        i,
        i + idBlockGroesse > ids.length ? ids.length : i + idBlockGroesse,
      );
      Uri? nextUri = withHitobitoListFilter(
        withHitobitoListPaging(
          requestUri.replace(
            queryParameters: const <String, String>{'fields[groups]': 'name'},
          ),
        ),
        {'filter[id]': block.join(',')},
      );
      while (nextUri != null) {
        final decoded = await _fetch(nextUri, accessToken);
        for (final resource in _datenliste(decoded)) {
          final id = _int(resource['id']);
          final name = _text(_attribute(resource)['name']);
          if (id != null && name != null) {
            namen[id] = name;
          }
        }
        nextUri = _naechsteSeite(decoded, currentUri: nextUri);
      }
    }
    return namen;
  }

  Future<List<Veranstaltung>> _fetchListe(
    Uri requestUri,
    String accessToken,
    Map<String, String> filter,
  ) async {
    final veranstaltungen = <Veranstaltung>[];
    Uri? nextUri = requestUri;
    while (nextUri != null) {
      final effectiveUri = withHitobitoListFilter(
        _dekoriereListe(nextUri),
        filter,
      );
      final decoded = await _fetch(effectiveUri, accessToken);
      final included = _Included(decoded['included']);
      for (final resource in _datenliste(decoded)) {
        final veranstaltung = _mapEvent(resource, included, mitPersonen: false);
        if (veranstaltung != null) {
          veranstaltungen.add(veranstaltung);
        }
      }
      nextUri = _naechsteSeite(decoded, currentUri: effectiveUri);
    }
    return veranstaltungen;
  }

  Uri _dekoriereListe(Uri uri) {
    final queryParameters = Map<String, String>.from(uri.queryParameters);
    queryParameters['include'] = 'dates,kind.kind_category';
    queryParameters['fields[events]'] = _listenFelder;
    queryParameters['fields[courses]'] = _listenFelder;
    queryParameters['fields[dates]'] = _terminFelder;
    queryParameters['fields[event_kinds]'] = _kursartFelder;
    queryParameters['fields[event_kind_categories]'] = 'label';
    // Events sind nur nach id sortierbar; ohne feste Sortierung waere das
    // Offset-Paging instabil. Die Reihenfolge nach Datum entsteht lokal.
    return withHitobitoListPaging(
      uri.replace(queryParameters: queryParameters),
    );
  }

  Future<Map<String, dynamic>> _fetch(Uri uri, String accessToken) async {
    final headers = <String, String>{
      'Accept': 'application/vnd.api+json, application/json',
      'Authorization': 'Bearer $accessToken',
    };

    http.Response response;
    try {
      response = await _httpClient.get(uri, headers: headers);
    } catch (error) {
      await _logger?.logHttpRequest(
        source: 'hitobito_events',
        method: 'GET',
        uri: uri,
        error: error,
      );
      await _trafficLogService?.logResponse(
        source: 'events',
        method: 'GET',
        uri: uri,
        error: error,
      );
      rethrow;
    }

    await _logger?.logHttpRequest(
      source: 'hitobito_events',
      method: 'GET',
      uri: uri,
      statusCode: response.statusCode,
    );
    await _trafficLogService?.logResponse(
      source: 'events',
      method: 'GET',
      uri: uri,
      statusCode: response.statusCode,
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HitobitoEventsException(
        'Events-Anfrage fehlgeschlagen (${response.statusCode}).',
        statusCode: response.statusCode,
      );
    }

    // JSON ist immer UTF-8 (RFC 8259), auch wenn der Header kein charset
    // nennt.
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map<String, dynamic>) {
      throw const HitobitoEventsException(
        'Events-Antwort hat ein ungültiges Format.',
      );
    }
    return decoded;
  }

  /// Liefert `null` fuer Eintraege ohne Namen oder Termin, statt den ganzen
  /// Abruf scheitern zu lassen.
  Veranstaltung? _mapEvent(
    Map<String, dynamic> resource,
    _Included included, {
    required bool mitPersonen,
  }) {
    final id = _int(resource['id']);
    final attribute = _attribute(resource);
    final name = _text(attribute['name']);
    if (id == null || name == null) {
      return null;
    }

    final termine = <VeranstaltungsTermin>[
      for (final ref in _beziehungen(resource, 'dates'))
        ?_mapTermin(included.finde('dates', ref)),
    ];
    if (termine.isEmpty) {
      return null;
    }

    final rohTyp = _text(attribute['type']);
    final kindRef = _beziehungen(resource, 'kind').firstOrNull;
    final kursart = kindRef == null
        ? null
        : _mapKursart(included.finde('event_kinds', kindRef), included);
    final art = rohTyp == kursTyp || resource['type'] == 'courses'
        ? VeranstaltungsArt.kurs
        : VeranstaltungsArt.veranstaltung;

    VeranstaltungsPerson? kontakt;
    var leitung = const <VeranstaltungsPerson>[];
    if (mitPersonen) {
      final kontaktRef = _beziehungen(resource, 'contact').firstOrNull;
      kontakt = kontaktRef == null
          ? null
          : _mapPerson(included.finde('people', kontaktRef));
      leitung = <VeranstaltungsPerson>[
        for (final ref in _beziehungen(resource, 'leaders'))
          ?_mapPerson(included.findeId(ref)),
      ];
    }

    final link = _text(attribute['external_application_link']);
    return Veranstaltung(
      id: id,
      art: art,
      rohTyp: rohTyp,
      name: name,
      termine: termine,
      gruppenIds: _intListe(attribute['group_ids']),
      motto: _text(attribute['motto']),
      beschreibung: _text(attribute['description']),
      ort: _text(attribute['location']),
      kosten: _text(attribute['cost']),
      anmeldungAb: _datumWert(attribute['application_opening_at']),
      anmeldungBis: _datumWert(attribute['application_closing_at']),
      maxTeilnehmende: _int(attribute['maximum_participants']),
      teilnehmende: _int(attribute['participant_count']),
      kursart: kursart,
      anmeldeLinkExtern: link == null ? null : Uri.tryParse(link),
      voraussetzungen: _text(attribute['application_conditions']),
      kontakt: kontakt,
      leitung: leitung,
    );
  }

  VeranstaltungsTermin? _mapTermin(Map<String, dynamic>? resource) {
    if (resource == null) {
      return null;
    }
    final attribute = _attribute(resource);
    final beginn = _zeitpunkt(attribute['start_at']);
    if (beginn == null) {
      return null;
    }
    return VeranstaltungsTermin(
      beginn: beginn,
      ende: _zeitpunkt(attribute['finish_at']),
      label: _text(attribute['label']),
      ort: _text(attribute['location']),
    );
  }

  Kursart? _mapKursart(Map<String, dynamic>? resource, _Included included) {
    if (resource == null) {
      return null;
    }
    final id = _int(resource['id']);
    final attribute = _attribute(resource);
    final label = _text(attribute['label']);
    if (id == null || label == null) {
      return null;
    }
    final kategorieRef = _beziehungen(resource, 'kind_category').firstOrNull;
    return Kursart(
      id: id,
      label: label,
      kurzname: _text(attribute['short_name']),
      kategorie: kategorieRef == null
          ? null
          : _mapKategorie(
              included.finde('event_kind_categories', kategorieRef),
            ),
      mindestalter: _int(attribute['minimum_age']),
      allgemeineInfos: _text(attribute['general_information']),
      voraussetzungen: _text(attribute['application_conditions']),
    );
  }

  KursartKategorie? _mapKategorie(Map<String, dynamic>? resource) {
    if (resource == null) {
      return null;
    }
    final id = _int(resource['id']);
    final label = _text(_attribute(resource)['label']);
    if (id == null || label == null) {
      return null;
    }
    return KursartKategorie(id: id, label: label);
  }

  VeranstaltungsPerson? _mapPerson(Map<String, dynamic>? resource) {
    if (resource == null) {
      return null;
    }
    final id = _int(resource['id']);
    final attribute = _attribute(resource);
    final name = [
      _text(attribute['first_name']),
      _text(attribute['last_name']),
    ].whereType<String>().join(' ');
    final anzeige = name.isNotEmpty ? name : _text(attribute['nickname']);
    if (id == null || anzeige == null) {
      return null;
    }
    return VeranstaltungsPerson(id: id, name: anzeige);
  }

  static Iterable<Map<String, dynamic>> _datenliste(
    Map<String, dynamic> decoded,
  ) {
    final data = decoded['data'];
    if (data is! List) {
      throw const HitobitoEventsException(
        'Events-Antwort enthält keine gültige Datensammlung.',
      );
    }
    return data.whereType<Map<String, dynamic>>();
  }

  static Map<String, dynamic> _attribute(Map<String, dynamic> resource) {
    final attribute = resource['attributes'];
    return attribute is Map<String, dynamic>
        ? attribute
        : const <String, dynamic>{};
  }

  /// Referenzen `(type, id)` einer Beziehung, egal ob einzeln oder Liste.
  static List<({String type, String id})> _beziehungen(
    Map<String, dynamic> resource,
    String name,
  ) {
    final beziehungen = resource['relationships'];
    if (beziehungen is! Map<String, dynamic>) {
      return const [];
    }
    final beziehung = beziehungen[name];
    if (beziehung is! Map<String, dynamic>) {
      return const [];
    }
    final data = beziehung['data'];
    final eintraege = data is List ? data : [data];
    return [
      for (final eintrag in eintraege.whereType<Map<String, dynamic>>())
        if (eintrag['id'] != null)
          (type: '${eintrag['type']}', id: '${eintrag['id']}'),
    ];
  }

  Uri? _naechsteSeite(Map<String, dynamic> decoded, {required Uri currentUri}) {
    final links = decoded['links'];
    if (links is! Map<String, dynamic>) {
      return null;
    }
    final next = links['next'];
    final nextValue = next is String
        ? next
        : next is Map<String, dynamic>
        ? next['href']?.toString()
        : null;
    if (nextValue == null || nextValue.isEmpty) {
      return null;
    }
    return currentUri.resolve(nextValue);
  }

  static String _datum(DateTime tag) =>
      '${tag.year.toString().padLeft(4, '0')}-'
      '${tag.month.toString().padLeft(2, '0')}-'
      '${tag.day.toString().padLeft(2, '0')}';

  static DateTime? _zeitpunkt(Object? wert) {
    final raw = _text(wert);
    return raw == null ? null : DateTime.tryParse(raw)?.toLocal();
  }

  /// Datumsfelder ohne Zeit als lokaler Kalendertag.
  static DateTime? _datumWert(Object? wert) {
    final raw = _text(wert);
    if (raw == null) {
      return null;
    }
    final geparst = DateTime.tryParse(raw);
    return geparst == null
        ? null
        : DateTime(geparst.year, geparst.month, geparst.day);
  }

  static String? _text(Object? wert) {
    final text = wert?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  static int? _int(Object? wert) {
    if (wert is int) {
      return wert;
    }
    return int.tryParse(wert?.toString() ?? '');
  }

  static List<int> _intListe(Object? wert) {
    if (wert is! List) {
      return const <int>[];
    }
    return [for (final eintrag in wert) ?_int(eintrag)];
  }
}

/// Sideloads einer Antwort, nach Typ und ID nachschlagbar.
class _Included {
  _Included(Object? included) {
    if (included is! List) {
      return;
    }
    for (final eintrag in included.whereType<Map<String, dynamic>>()) {
      final type = eintrag['type']?.toString();
      final id = eintrag['id']?.toString();
      if (type != null && id != null) {
        _eintraege['$type:$id'] = eintrag;
        _nachId.putIfAbsent(id, () => <Map<String, dynamic>>[]).add(eintrag);
      }
    }
  }

  final Map<String, Map<String, dynamic>> _eintraege = {};
  final Map<String, List<Map<String, dynamic>>> _nachId = {};

  /// Sucht zuerst den angegebenen Typ, dann den Typ aus der Referenz.
  Map<String, dynamic>? finde(
    String erwarteterTyp,
    ({String type, String id}) ref,
  ) =>
      _eintraege['${ref.type}:${ref.id}'] ??
      _eintraege['$erwarteterTyp:${ref.id}'];

  /// Fuer Beziehungen mit wechselnden Typnamen wie `leaders`
  /// (`person-name`).
  Map<String, dynamic>? findeId(({String type, String id}) ref) =>
      _eintraege['${ref.type}:${ref.id}'] ?? _nachId[ref.id]?.firstOrNull;
}

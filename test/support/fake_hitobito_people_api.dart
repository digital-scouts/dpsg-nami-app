import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'hitobito_jsonapi_fixtures.dart';

/// Ein Request, den [FakeHitobitoPeopleApi] beantwortet hat.
class FakeApiRequest {
  const FakeApiRequest({
    required this.method,
    required this.path,
    required this.accessToken,
    required this.at,
    this.body,
  });

  final String method;
  final String path;
  final String? accessToken;
  final DateTime? at;
  final Map<String, dynamic>? body;

  @override
  String toString() => '$method $path';
}

/// Feste Antwort fuer alle folgenden `PUT /api/people/{id}`.
class FakePutFailure {
  const FakePutFailure(this.statusCode, {this.body});

  final int statusCode;
  final Map<String, dynamic>? body;
}

class _FakePerson {
  _FakePerson({
    required this.attributes,
    required this.phoneNumbers,
    required this.updatedAt,
  });

  final Map<String, dynamic> attributes;
  final List<FixturePhoneNumber> phoneNumbers;
  DateTime updatedAt;
}

/// Zustandsbehaftete Nachbildung von `/api/people/{id}` fuer einen
/// `MockClient`: GET liefert den aktuellen Serverstand, PUT uebernimmt
/// Attribute und Telefonnummern (JSON:API-Sideposting) und erhoeht
/// `updated_at`. Die Zeitstempel ruecken deterministisch vor, ohne echte Uhr.
class FakeHitobitoPeopleApi {
  FakeHitobitoPeopleApi({this.clock});

  /// Liefert den Zeitpunkt, der an jedem Request vermerkt wird.
  final DateTime Function()? clock;

  final Map<int, _FakePerson> _people = <int, _FakePerson>{};
  final List<FakeApiRequest> requests = <FakeApiRequest>[];

  /// Ohne Netz: jeder Request scheitert wie bei fehlender Verbindung.
  bool offline = false;

  /// Access-Tokens, die Hitobito mit 401 ablehnt.
  final Set<String> rejectedAccessTokens = <String>{};

  /// Solange gesetzt, scheitert jedes PUT mit dieser Antwort.
  FakePutFailure? putFailure;

  var _nextPhoneNumberId = 900;

  late final http.Client client = MockClient(_handle);

  List<FakeApiRequest> get putRequests =>
      requests.where((request) => request.method == 'PUT').toList();

  List<FakeApiRequest> get getRequests =>
      requests.where((request) => request.method == 'GET').toList();

  void addPerson({
    required int id,
    required DateTime updatedAt,
    int? membershipNumber,
    String firstName = 'Julia',
    String lastName = 'Keller',
    String? nickname,
    List<FixturePhoneNumber> phoneNumbers = const <FixturePhoneNumber>[],
  }) {
    _people[id] = _FakePerson(
      attributes: <String, dynamic>{
        'first_name': firstName,
        'last_name': lastName,
        'nickname': nickname,
        'membership_number': membershipNumber,
      },
      phoneNumbers: List<FixturePhoneNumber>.from(phoneNumbers),
      updatedAt: updatedAt,
    );
  }

  /// Aenderung durch jemand anderen direkt in Hitobito.
  void serverEdit(int personId, Map<String, dynamic> attributes) {
    final person = _person(personId);
    person.attributes.addAll(attributes);
    _touch(person);
  }

  Map<String, dynamic> personDocument(int personId) {
    final person = _person(personId);
    return personResourceDocument(
      id: personId,
      updatedAt: person.updatedAt,
      membershipNumber: person.attributes['membership_number'] as int?,
      firstName: person.attributes['first_name'] as String? ?? '',
      lastName: person.attributes['last_name'] as String? ?? '',
      nickname: person.attributes['nickname'] as String?,
      phoneNumbers: person.phoneNumbers,
      extraAttributes: Map<String, dynamic>.from(person.attributes)
        ..remove('first_name')
        ..remove('last_name')
        ..remove('nickname')
        ..remove('membership_number'),
    );
  }

  List<FixturePhoneNumber> phoneNumbersOf(int personId) =>
      List<FixturePhoneNumber>.unmodifiable(_person(personId).phoneNumbers);

  Object? attributeOf(int personId, String attribute) =>
      _person(personId).attributes[attribute];

  Future<http.Response> _handle(http.Request request) async {
    final accessToken = _bearerToken(request);
    final body = request.body.isEmpty
        ? null
        : jsonDecode(request.body) as Map<String, dynamic>;
    requests.add(
      FakeApiRequest(
        method: request.method,
        path: request.url.path,
        accessToken: accessToken,
        at: clock?.call(),
        body: body,
      ),
    );

    if (offline) {
      throw const SocketException('Netzwerk nicht erreichbar');
    }
    if (accessToken == null || rejectedAccessTokens.contains(accessToken)) {
      return http.Response('Unauthorized', 401);
    }

    final match = RegExp(r'^/api/people/(\d+)$').firstMatch(request.url.path);
    if (match == null) {
      return http.Response('Not Found', 404);
    }
    final personId = int.parse(match.group(1)!);
    if (!_people.containsKey(personId)) {
      return http.Response('Not Found', 404);
    }

    switch (request.method) {
      case 'GET':
        return _json(200, personDocument(personId));
      case 'PUT':
        final failure = putFailure;
        if (failure != null) {
          return failure.body == null
              ? http.Response('', failure.statusCode)
              : _json(failure.statusCode, failure.body!);
        }
        _applyMutation(_person(personId), body ?? const <String, dynamic>{});
        return _json(200, personDocument(personId));
      default:
        return http.Response('Method Not Allowed', 405);
    }
  }

  void _applyMutation(_FakePerson person, Map<String, dynamic> document) {
    final data = document['data'] as Map<String, dynamic>? ?? const {};
    final attributes = data['attributes'] as Map<String, dynamic>?;
    if (attributes != null) {
      person.attributes.addAll(attributes);
    }

    final included = (document['included'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>()
        .where((resource) => resource['type'] == 'phone_numbers')
        .toList();
    Map<String, dynamic> includedAttributes(Map<String, dynamic> reference) {
      final key = reference.containsKey('temp-id') ? 'temp-id' : 'id';
      final resource = included.firstWhere(
        (candidate) => candidate[key] == reference[key],
      );
      return resource['attributes'] as Map<String, dynamic>;
    }

    final relationships = data['relationships'] as Map<String, dynamic>?;
    final phoneData =
        (relationships?['phone_numbers']?['data'] as List<dynamic>? ?? const [])
            .cast<Map<String, dynamic>>();
    for (final reference in phoneData) {
      switch (reference['method']) {
        case 'create':
          final values = includedAttributes(reference);
          person.phoneNumbers.add(
            FixturePhoneNumber(
              id: _nextPhoneNumberId++,
              number: values['number'] as String,
              label: values['label'] as String?,
            ),
          );
        case 'update':
          final id = int.parse(reference['id'] as String);
          final values = includedAttributes(reference);
          final index = person.phoneNumbers.indexWhere(
            (phone) => phone.id == id,
          );
          person.phoneNumbers[index] = FixturePhoneNumber(
            id: id,
            number: values['number'] as String,
            label: values['label'] as String?,
          );
        case 'destroy':
          final id = int.parse(reference['id'] as String);
          person.phoneNumbers.removeWhere((phone) => phone.id == id);
      }
    }

    _touch(person);
  }

  void _touch(_FakePerson person) {
    person.updatedAt = person.updatedAt.add(const Duration(minutes: 1));
  }

  _FakePerson _person(int personId) {
    final person = _people[personId];
    if (person == null) {
      throw StateError('Person $personId ist im Fake nicht angelegt.');
    }
    return person;
  }

  static String? _bearerToken(http.Request request) {
    final header = request.headers['Authorization'];
    if (header == null || !header.startsWith('Bearer ')) {
      return null;
    }
    return header.substring('Bearer '.length);
  }

  static http.Response _json(int statusCode, Map<String, dynamic> body) {
    return http.Response(
      jsonEncode(body),
      statusCode,
      headers: <String, String>{
        'content-type': 'application/vnd.api+json; charset=utf-8',
      },
    );
  }
}

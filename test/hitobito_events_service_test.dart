import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nami/domain/veranstaltung/veranstaltung.dart';
import 'package:nami/services/hitobito_auth_env.dart';
import 'package:nami/services/hitobito_events_service.dart';

/// Antwortform wie im lokalen dpsg-stack beobachtet: Kurse kommen als
/// `courses`, einfache Events als `events` mit `type: null`, Termine als
/// `dates`, Leitung als `person-name`.
const _liste = '''
{
  "data": [
    {
      "id": "5", "type": "courses",
      "attributes": {
        "group_ids": [11], "type": "Event::Course", "kind_id": 1,
        "name": "Gruppenleitungskurs Bezirk Silberbach",
        "location": "Jugendhaus Silberbach", "cost": "60 €",
        "application_opening_at": "2026-09-20", "application_closing_at": "2026-11-04",
        "maximum_participants": 12, "participant_count": 4,
        "external_application_link": null
      },
      "relationships": {
        "kind": { "data": { "type": "event_kinds", "id": "1" } },
        "dates": { "data": [ { "type": "dates", "id": "21" }, { "type": "dates", "id": "20" } ] }
      }
    },
    {
      "id": "2", "type": "events",
      "attributes": {
        "group_ids": [12], "type": null, "name": "Sommerlager Fuchsbau",
        "location": "  ", "application_opening_at": null, "application_closing_at": "2026-11-09"
      },
      "relationships": {
        "kind": { "data": null },
        "dates": { "data": [ { "type": "dates", "id": "30" } ] }
      }
    },
    {
      "id": "9", "type": "events",
      "attributes": { "group_ids": [11], "type": null, "name": "Ohne Termin" },
      "relationships": { "dates": { "data": [] } }
    }
  ],
  "included": [
    { "id": "20", "type": "dates", "attributes": { "label": "Wochenende 1", "location": null, "start_at": "2026-11-14T18:00:00+01:00", "finish_at": "2026-11-16T14:00:00+01:00" } },
    { "id": "21", "type": "dates", "attributes": { "label": "Wochenende 2", "location": null, "start_at": "2026-11-28T18:00:00+01:00", "finish_at": "2026-11-30T14:00:00+01:00" } },
    { "id": "30", "type": "dates", "attributes": { "label": "Lager", "location": "Zeltplatz", "start_at": "2026-11-21T14:00:00+01:00", "finish_at": null } },
    { "id": "1", "type": "event_kinds", "attributes": { "label": "Gruppenleitungskurs", "short_name": "GLK", "minimum_age": 16 },
      "relationships": { "kind_category": { "data": { "type": "event_kind_categories", "id": "3" } } } },
    { "id": "3", "type": "event_kind_categories", "attributes": { "label": "Ausbildung" } }
  ],
  "links": { "next": null }
}
''';

const _detail = '''
{
  "data": {
    "id": "5", "type": "courses",
    "attributes": {
      "group_ids": [11], "type": "Event::Course", "name": "Gruppenleitungskurs Bezirk Silberbach",
      "description": "Zwei Wochenenden.", "application_conditions": "Mit Anmeldung durch die Stammesleitung.",
      "external_application_link": "https://nami.example/groups/11/public_events/5"
    },
    "relationships": {
      "contact": { "data": { "type": "people", "id": "6" } },
      "leaders": { "data": [ { "type": "person-name", "id": "7" } ] },
      "kind": { "data": { "type": "event_kinds", "id": "1" } },
      "dates": { "data": [ { "type": "dates", "id": "20" } ] }
    }
  },
  "included": [
    { "id": "20", "type": "dates", "attributes": { "start_at": "2026-11-14T18:00:00+01:00" } },
    { "id": "6", "type": "people", "attributes": { "first_name": "Finn", "last_name": "Stammesführung", "nickname": null } },
    { "id": "7", "type": "person-name", "attributes": { "first_name": null, "last_name": null, "nickname": "Luchs" } },
    { "id": "1", "type": "event_kinds", "attributes": { "label": "Gruppenleitungskurs", "general_information": "Grundlagen.", "application_conditions": "Erste Hilfe." } }
  ]
}
''';

void main() {
  HitobitoEventsService serviceMit(MockClient client) => HitobitoEventsService(
    config: HitobitoAuthConfig.fromBaseUrl(
      clientId: 'client',
      clientSecret: 'secret',
      baseUrl: 'https://demo.hitobito.com',
      redirectUri: 'de.jlange.nami.app:/oauth/callback',
      scopeString: 'openid api',
    ),
    httpClient: client,
  );

  test('laedt Kurse und Veranstaltungen mit Terminen und Kursart', () async {
    final uris = <Uri>[];
    final service = serviceMit(
      MockClient((request) async {
        uris.add(request.url);
        expect(request.headers['Authorization'], 'Bearer token');
        return http.Response.bytes(utf8.encode(_liste), 200);
      }),
    );

    final liste = await service.fetchVeranstaltungen(
      'token',
      abTag: DateTime(2026, 10, 10, 15, 30),
    );

    expect(uris, hasLength(1));
    final query = uris.single.queryParameters;
    expect(uris.single.path, '/api/events');
    expect(query['filter[after_or_on]'], '2026-10-10');
    expect(query.containsKey('filter[group_id]'), isFalse);
    expect(query['include'], 'dates,kind.kind_category');
    // Sparse Fields fuer beide JSON:API-Typen.
    expect(query['fields[events]'], contains('participant_count'));
    expect(query['fields[courses]'], query['fields[events]']);
    expect(query['sort'], 'id');

    // Ein Event ohne Termin wird uebersprungen.
    expect(liste.map((v) => v.id), [5, 2]);
    final kurs = liste.first;
    expect(kurs.art, VeranstaltungsArt.kurs);
    expect(kurs.gruppenIds, [11]);
    expect(kurs.termine.map((t) => t.label), ['Wochenende 1', 'Wochenende 2']);
    expect(kurs.kursart?.kurzname, 'GLK');
    expect(kurs.kursart?.kategorie?.label, 'Ausbildung');
    expect(kurs.freiePlaetze, 8);
    expect(kurs.anmeldungAb, DateTime(2026, 9, 20));
    expect(kurs.anmeldungBis, DateTime(2026, 11, 4));

    final lager = liste.last;
    expect(lager.art, VeranstaltungsArt.veranstaltung);
    expect(lager.rohTyp, isNull);
    expect(lager.ort, isNull);
    expect(lager.kursart, isNull);
    expect(lager.termine.single.ort, 'Zeltplatz');
    expect(lager.freiePlaetze, isNull);
  });

  test(
    'teilt den Gruppenfilter in Bloecke und fuehrt Ergebnisse zusammen',
    () async {
      final gruppenFilter = <String>[];
      final service = serviceMit(
        MockClient((request) async {
          gruppenFilter.add(request.url.queryParameters['filter[group_id]']!);
          return http.Response.bytes(utf8.encode(_liste), 200);
        }),
      );

      final liste = await service.fetchVeranstaltungen(
        'token',
        abTag: DateTime(2026, 10, 10),
        gruppenIds: {
          for (var id = 1; id <= HitobitoEventsService.idBlockGroesse + 1; id++)
            id,
        },
      );

      expect(gruppenFilter, hasLength(2));
      expect(gruppenFilter.last, '${HitobitoEventsService.idBlockGroesse + 1}');
      // Dieselben Events aus beiden Bloecken nur einmal.
      expect(liste.map((v) => v.id), [5, 2]);
    },
  );

  test('leere Gruppenauswahl fragt nicht an', () async {
    var anfragen = 0;
    final service = serviceMit(
      MockClient((request) async {
        anfragen++;
        return http.Response('{}', 200);
      }),
    );

    final liste = await service.fetchVeranstaltungen(
      'token',
      abTag: DateTime(2026, 10, 10),
      gruppenIds: const {},
    );

    expect(liste, isEmpty);
    expect(anfragen, 0);
  });

  test('folgt links.next ueber alle Seiten', () async {
    final seiten = <String?>[];
    final service = serviceMit(
      MockClient((request) async {
        final seite = request.url.queryParameters['page[number]'];
        seiten.add(seite);
        final body = jsonDecode(_liste) as Map<String, dynamic>;
        if (seite == null) {
          body['links'] = {'next': '/api/events?page[number]=2'};
        } else {
          (body['data'] as List).removeRange(0, 2);
        }
        return http.Response.bytes(utf8.encode(jsonEncode(body)), 200);
      }),
    );

    await service.fetchVeranstaltungen('token', abTag: DateTime(2026, 10, 10));

    expect(seiten, [null, '2']);
  });

  test(
    'Detail liefert Kontakt, Leitung, Kursart-Infos und externen Link',
    () async {
      Uri? uri;
      final service = serviceMit(
        MockClient((request) async {
          uri = request.url;
          return http.Response.bytes(utf8.encode(_detail), 200);
        }),
      );

      final kurs = await service.fetchVeranstaltung('token', id: 5);

      expect(uri!.path, '/api/events/5');
      expect(uri!.queryParameters['include'], contains('leaders'));
      expect(kurs.kontakt?.name, 'Finn Stammesführung');
      expect(kurs.leitung.single.name, 'Luchs');
      expect(kurs.beschreibung, 'Zwei Wochenenden.');
      expect(kurs.voraussetzungen, 'Mit Anmeldung durch die Stammesleitung.');
      expect(kurs.kursart?.allgemeineInfos, 'Grundlagen.');
      expect(kurs.kursart?.voraussetzungen, 'Erste Hilfe.');
      expect(
        kurs.anmeldeLinkExtern,
        Uri.parse('https://nami.example/groups/11/public_events/5'),
      );
    },
  );

  test('Gruppennamen per filter[id]', () async {
    Uri? uri;
    final service = serviceMit(
      MockClient((request) async {
        uri = request.url;
        return http.Response.bytes(
          utf8.encode('''
          { "data": [
              { "id": "11", "type": "groups", "attributes": { "name": "Bezirk Silberbach" } },
              { "id": "1", "type": "groups", "attributes": { "name": "Bundesebene" } }
          ], "links": { "next": null } }
          '''),
          200,
        );
      }),
    );

    final namen = await service.fetchGruppenNamen('token', {11, 1});

    expect(uri!.path, '/api/groups');
    expect(uri!.queryParameters['filter[id]'], '1,11');
    expect(namen, {11: 'Bezirk Silberbach', 1: 'Bundesebene'});
  });

  test('Fehlerstatus wird zur HitobitoEventsException', () async {
    final service = serviceMit(
      MockClient((request) async => http.Response('{}', 403)),
    );

    expect(
      () => service.fetchVeranstaltungen('token', abTag: DateTime(2026)),
      throwsA(
        isA<HitobitoEventsException>().having(
          (e) => e.statusCode,
          'statusCode',
          403,
        ),
      ),
    );
  });

  test('Webseite eines Events', () {
    final config = HitobitoAuthConfig.fromBaseUrl(
      clientId: 'client',
      clientSecret: 'secret',
      baseUrl: 'https://demo.hitobito.com',
      redirectUri: 'de.jlange.nami.app:/oauth/callback',
      scopeString: 'openid api',
    );

    expect(
      config.eventWebUri(groupId: 11, eventId: 5),
      Uri.parse('https://demo.hitobito.com/groups/11/events/5'),
    );
  });
}

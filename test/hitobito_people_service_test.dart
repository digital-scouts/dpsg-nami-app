import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nami/domain/member/mitglied.dart';
import 'package:nami/services/hitobito_auth_env.dart';
import 'package:nami/services/hitobito_people_service.dart';

void main() {
  test(
    'laedt /api/people mit erweiterten Includes und mappt Primaer- und Zusatzkontakte',
    () async {
      final requestedUris = <Uri>[];
      late Map<String, String> requestHeaders;

      final client = MockClient((request) async {
        requestedUris.add(request.url);
        requestHeaders = request.headers;

        if (request.url.queryParameters['page'] == '2') {
          return http.Response(
            '''
        {
          "data": [
            {
              "id": "24",
              "type": "people",
              "attributes": {
                "first_name": "Max",
                "last_name": "Mustermann",
                "nickname": "Moe",
                "primary_group_id": 11
              },
              "relationships": {
                "roles": {
                  "data": [
                    { "id": "502", "type": "roles" }
                  ]
                },
                "phone_numbers": {
                  "data": []
                },
                "additional_emails": {
                  "data": []
                },
                "additional_addresses": {
                  "data": []
                }
              }
            }
          ],
          "included": [
            {
              "id": "502",
              "type": "roles",
              "attributes": {
                "person_id": 24,
                "group_id": 12,
                "type": "Group::Mitglied",
                "label": null,
                "name": "Mitglied"
              }
            }
          ],
          "links": {
            "next": null
          }
        }
        ''',
            200,
            headers: <String, String>{'content-type': 'application/json'},
          );
        }

        return http.Response(
          '''
        {
          "data": [
            {
              "id": "23",
              "type": "people",
              "attributes": {
                "first_name": "Julia",
                "last_name": "Keller",
                "nickname": "Polka",
                "membership_number": 1001,
                "primary_group_id": 11,
                "email": "julia@example.org",
                "birthday": "2008-05-12",
                "entry_date": "2021-09-01",
                "updated_at": "2024-11-07T14:35:00Z",
                "gender": "w",
                "pronoun": "sie/ihr",
                "street": "Musterweg",
                "housenumber": "4",
                "zip_code": "50667",
                "town": "Koeln",
                "country": "DE"
              },
              "relationships": {
                "roles": {
                  "data": [
                    { "id": "501", "type": "roles" }
                  ]
                },
                "phone_numbers": {
                  "data": [
                    { "id": "701", "type": "phone_numbers" }
                  ]
                },
                "additional_emails": {
                  "data": [
                    { "id": "601", "type": "additional_emails" }
                  ]
                },
                "additional_addresses": {
                  "data": [
                    { "id": "801", "type": "additional_addresses" }
                  ]
                }
              }
            }
          ],
          "included": [
            {
              "id": "501",
              "type": "roles",
              "attributes": {
                "person_id": 23,
                "group_id": 11,
                "type": "Group::RegionOffice::Treasurer",
                "label": null,
                "name": "Vorstandsmitglied"
              }
            },
            {
              "id": "701",
              "type": "phone_numbers",
              "attributes": {
                "contactable_id": 23,
                "contactable_type": "Person",
                "label": "Mobil",
                "number": "+49 170 1234567"
              }
            },
            {
              "id": "702",
              "type": "phone_numbers",
              "attributes": {
                "contactable_id": 23,
                "contactable_type": "Person",
                "label": "Festnetz",
                "number": "+49 40 9876543"
              }
            },
            {
              "id": "601",
              "type": "additional_emails",
              "attributes": {
                "contactable_id": 23,
                "contactable_type": "Person",
                "label": "Privat",
                "email": "julia.privat@example.org"
              }
            },
            {
              "id": "602",
              "type": "additional_emails",
              "attributes": {
                "contactable_id": 23,
                "contactable_type": "Person",
                "label": null,
                "email": "eltern@example.org"
              }
            },
            {
              "id": "801",
              "type": "additional_addresses",
              "attributes": {
                "contactable_id": 23,
                "contactable_type": "Person",
                "label": "Elternhaus",
                "address_care_of": null,
                "street": "Nebenweg",
                "housenumber": "5",
                "postbox": null,
                "zip_code": "50668",
                "town": "Koeln",
                "country": "DE"
              }
            },
            {
              "id": "802",
              "type": "additional_addresses",
              "attributes": {
                "contactable_id": 23,
                "contactable_type": "Person",
                "label": "Postfach",
                "address_care_of": null,
                "street": null,
                "housenumber": null,
                "postbox": "PF 12",
                "zip_code": "50669",
                "town": "Koeln",
                "country": "DE"
              }
            }
          ],
          "links": {
            "next": "https://demo.hitobito.com/api/people?page=2"
          }
        }
        ''',
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      });

      final service = HitobitoPeopleService(
        config: const HitobitoAuthConfig(
          clientId: 'client',
          clientSecret: 'secret',
          authorizationUrl: 'https://demo.hitobito.com/oauth/authorize',
          tokenUrl: 'https://demo.hitobito.com/oauth/token',
          redirectUri: 'de.jlange.nami.app:/oauth/callback',
          scopeString: 'openid email api',
          discoveryUrl: '',
          profileUrl: 'https://demo.hitobito.com/oauth/profile',
        ),
        httpClient: client,
      );

      final people = await service.fetchPeople('token-123');

      expect(requestedUris, hasLength(2));
      expect(requestedUris.first.path, '/api/people');
      expect(
        requestedUris.first.queryParameters['include'],
        'roles,phone_numbers,additional_emails,additional_addresses',
      );
      expect(
        requestedUris.first.queryParameters['fields[roles]'],
        'created_at,updated_at,start_on,end_on,name,person_id,group_id,type,label',
      );
      expect(
        requestedUris.first.queryParameters['fields[phone_numbers]'],
        'contactable_id,contactable_type,label,number',
      );
      expect(
        requestedUris.first.queryParameters['fields[additional_emails]'],
        'contactable_id,contactable_type,label,email',
      );
      expect(
        requestedUris.first.queryParameters['fields[additional_addresses]'],
        'contactable_id,contactable_type,label,address_care_of,street,housenumber,postbox,zip_code,town,country',
      );
      expect(requestedUris.last.path, '/api/people');
      expect(requestedUris.last.queryParameters['page'], '2');
      expect(
        requestedUris.last.queryParameters['include'],
        'roles,phone_numbers,additional_emails,additional_addresses',
      );
      expect(requestHeaders['Authorization'], 'Bearer token-123');
      expect(people, hasLength(2));
      expect(people.first.vorname, 'Julia');
      expect(people.first.nachname, 'Keller');
      expect(people.first.fahrtenname, 'Polka');
      expect(people.first.personId, 23);
      expect(people.first.mitgliedsnummer, '1001');
      expect(people.first.gender, 'w');
      expect(people.first.pronoun, 'sie/ihr');
      expect(people.first.emailAdressen, const <MitgliedKontaktEmail>[
        MitgliedKontaktEmail(
          wert: 'julia@example.org',
          label: Mitglied.primaryEmailLabel,
          istPrimaer: true,
        ),
        MitgliedKontaktEmail(
          additionalEmailId: 601,
          wert: 'julia.privat@example.org',
          label: 'Privat',
        ),
        MitgliedKontaktEmail(
          additionalEmailId: 602,
          wert: 'eltern@example.org',
        ),
      ]);
      expect(people.first.telefonnummern, const <MitgliedKontaktTelefon>[
        MitgliedKontaktTelefon(
          phoneNumberId: 701,
          wert: '+49 170 1234567',
          label: 'Mobil',
        ),
        MitgliedKontaktTelefon(
          phoneNumberId: 702,
          wert: '+49 40 9876543',
          label: 'Festnetz',
        ),
      ]);
      expect(people.first.adressen, const <MitgliedKontaktAdresse>[
        MitgliedKontaktAdresse(
          additionalAddressId: 0,
          street: 'Musterweg',
          housenumber: '4',
          zipCode: '50667',
          town: 'Koeln',
          country: 'DE',
        ),
        MitgliedKontaktAdresse(
          additionalAddressId: 801,
          label: 'Elternhaus',
          street: 'Nebenweg',
          housenumber: '5',
          zipCode: '50668',
          town: 'Koeln',
          country: 'DE',
        ),
        MitgliedKontaktAdresse(
          additionalAddressId: 802,
          label: 'Postfach',
          postbox: 'PF 12',
          zipCode: '50669',
          town: 'Koeln',
          country: 'DE',
        ),
      ]);
      expect(people.first.geburtsdatum, DateTime(2008, 5, 12));
      expect(people.first.eintrittsdatum, DateTime(2021, 9, 1));
      expect(people.first.updatedAt, DateTime.parse('2024-11-07T14:35:00Z'));
      expect(people.last.mitgliedsnummer, '24');

      final resources = await service.fetchPeopleResources('token-123');
      expect(resources.first.emailAdressen, people.first.emailAdressen);
      expect(resources.first.telefonnummern, people.first.telefonnummern);
      expect(resources.first.adressen, people.first.adressen);
      expect(resources.first.updatedAt, DateTime.parse('2024-11-07T14:35:00Z'));
      expect(resources.first.gender, 'w');
      expect(resources.first.roles, hasLength(1));
      expect(resources.first.roles.first.groupId, 11);
      expect(
        resources.first.roles.first.roleType,
        'Group::RegionOffice::Treasurer',
      );
      expect(resources.first.roles.first.roleLabel, isNull);
      expect(
        resources.first.roles.first.resolvedRoleLabel,
        'Vorstandsmitglied',
      );
    },
    timeout: const Timeout(Duration(seconds: 3)),
  );

  test(
    'sendet JSON-API-Mutationen fuer Person und Unterressourcen mit demo-kompatiblem Contract',
    () async {
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        return http.Response('', 204);
      });

      final service = HitobitoPeopleService(
        config: const HitobitoAuthConfig(
          clientId: 'client',
          clientSecret: 'secret',
          authorizationUrl: 'https://demo.hitobito.com/oauth/authorize',
          tokenUrl: 'https://demo.hitobito.com/oauth/token',
          redirectUri: 'de.jlange.nami.app:/oauth/callback',
          scopeString: 'openid email api',
          discoveryUrl: '',
          profileUrl: 'https://demo.hitobito.com/oauth/profile',
        ),
        httpClient: client,
      );

      final mitglied = Mitglied(
        personId: 23,
        mitgliedsnummer: '4711',
        vorname: 'Julia',
        nachname: 'Keller',
        fahrtenname: 'Polka',
        geburtsdatum: DateTime.utc(2010, 4, 6),
        eintrittsdatum: DateTime(2020, 5, 1),
        austrittsdatum: DateTime.utc(2026, 4, 14),
        gender: 'divers',
        pronoun: 'sie/ihr',
        bankAccountOwner: 'Julia Keller',
        iban: 'DE02120300000000202051',
        bic: 'BYLADEM1001',
        bankName: 'Testbank',
        paymentMethod: 'manual',
        emailAdressen: const <MitgliedKontaktEmail>[
          MitgliedKontaktEmail(
            wert: 'julia@example.org',
            label: Mitglied.primaryEmailLabel,
            istPrimaer: true,
          ),
        ],
        adressen: const <MitgliedKontaktAdresse>[
          MitgliedKontaktAdresse(
            addressCareOf: 'c/o Familie Keller',
            street: 'Musterweg',
            housenumber: '4',
            zipCode: '50667',
            town: 'Koeln',
            country: 'DE',
          ),
        ],
      );

      await service.updatePerson('token-123', mitglied: mitglied);
      await service.createPhoneNumber(
        'token-123',
        personId: 23,
        telefonnummer: const MitgliedKontaktTelefon(
          wert: '+49 170 1234567',
          label: 'Mobil',
        ),
      );
      await service.updateAdditionalEmail(
        'token-123',
        email: const MitgliedKontaktEmail(
          additionalEmailId: 601,
          wert: 'julia.privat@example.org',
          label: 'Privat',
        ),
      );
      await service.deleteAdditionalAddress(
        'token-123',
        additionalAddressId: 801,
      );

      expect(requests, hasLength(4));

      final updatePersonRequest = requests[0];
      final updatePersonBody =
          jsonDecode(updatePersonRequest.body) as Map<String, dynamic>;
      expect(updatePersonRequest.method, 'PUT');
      expect(updatePersonRequest.url.path, '/api/people/23');
      expect(
        updatePersonRequest.headers['Accept'],
        'application/vnd.api+json, application/json',
      );
      expect(
        updatePersonRequest.headers['Content-Type'],
        'application/vnd.api+json',
      );
      expect(updatePersonRequest.headers['Authorization'], 'Bearer token-123');
      expect(updatePersonBody['data']['type'], 'people');
      expect(updatePersonBody['data']['id'], '23');
      expect(updatePersonBody['data']['attributes']['first_name'], 'Julia');
      expect(updatePersonBody['data']['attributes']['last_name'], 'Keller');
      expect(updatePersonBody['data']['attributes']['nickname'], 'Polka');
      expect(updatePersonBody['data']['attributes']['gender'], 'divers');
      expect(
        updatePersonBody['data']['attributes']['email'],
        'julia@example.org',
      );
      expect(
        updatePersonBody['data']['attributes']['address_care_of'],
        'c/o Familie Keller',
      );
      expect(updatePersonBody['data']['attributes']['street'], 'Musterweg');
      expect(updatePersonBody['data']['attributes']['housenumber'], '4');
      expect(updatePersonBody['data']['attributes']['postbox'], isNull);
      expect(updatePersonBody['data']['attributes']['zip_code'], '50667');
      expect(updatePersonBody['data']['attributes']['town'], 'Koeln');
      expect(updatePersonBody['data']['attributes']['country'], 'DE');
      expect(updatePersonBody['data']['attributes']['birthday'], '2010-04-06');
      expect(
        updatePersonBody['data']['attributes'],
        isNot(contains('exit_date')),
      );
      expect(
        updatePersonBody['data']['attributes'],
        isNot(contains('pronoun')),
      );
      expect(
        updatePersonBody['data']['attributes'],
        isNot(contains('bank_account_owner')),
      );
      expect(updatePersonBody['data']['attributes'], isNot(contains('iban')));
      expect(updatePersonBody['data']['attributes'], isNot(contains('bic')));
      expect(
        updatePersonBody['data']['attributes'],
        isNot(contains('bank_name')),
      );
      expect(
        updatePersonBody['data']['attributes'],
        isNot(contains('payment_method')),
      );

      final createPhoneRequest = requests[1];
      final createPhoneBody =
          jsonDecode(createPhoneRequest.body) as Map<String, dynamic>;
      expect(createPhoneRequest.method, 'POST');
      expect(createPhoneRequest.url.path, '/api/phone_numbers');
      expect(
        createPhoneRequest.headers['Accept'],
        'application/vnd.api+json, application/json',
      );
      expect(
        createPhoneRequest.headers['Content-Type'],
        'application/vnd.api+json',
      );
      expect(createPhoneBody['data']['type'], 'phone_numbers');
      expect(createPhoneBody['data']['attributes']['label'], 'Mobil');
      expect(createPhoneBody['data']['attributes']['contactable_id'], 23);
      expect(
        createPhoneBody['data']['attributes']['contactable_type'],
        'Person',
      );
      expect(
        createPhoneBody['data']['attributes']['number'],
        '+49 170 1234567',
      );

      final updateAdditionalEmailRequest = requests[2];
      final updateAdditionalEmailBody =
          jsonDecode(updateAdditionalEmailRequest.body) as Map<String, dynamic>;
      expect(updateAdditionalEmailRequest.method, 'PUT');
      expect(
        updateAdditionalEmailRequest.url.path,
        '/api/additional_emails/601',
      );
      expect(
        updateAdditionalEmailRequest.headers['Accept'],
        'application/vnd.api+json, application/json',
      );
      expect(
        updateAdditionalEmailRequest.headers['Content-Type'],
        'application/vnd.api+json',
      );
      expect(updateAdditionalEmailBody['data']['type'], 'additional_emails');
      expect(updateAdditionalEmailBody['data']['id'], '601');
      expect(
        updateAdditionalEmailBody['data']['attributes']['label'],
        'Privat',
      );
      expect(
        updateAdditionalEmailBody['data']['attributes']['email'],
        'julia.privat@example.org',
      );

      final deleteAdditionalAddressRequest = requests[3];
      expect(deleteAdditionalAddressRequest.method, 'DELETE');
      expect(
        deleteAdditionalAddressRequest.url.path,
        '/api/additional_addresses/801',
      );
      expect(
        deleteAdditionalAddressRequest.headers['Accept'],
        'application/vnd.api+json, application/json',
      );
      expect(
        deleteAdditionalAddressRequest.headers.containsKey('Content-Type'),
        isFalse,
      );
      expect(deleteAdditionalAddressRequest.body, isEmpty);
    },
    timeout: const Timeout(Duration(seconds: 3)),
  );

  test('sendet leeres Geburtsdatum nicht als 1900 an Hitobito', () async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      return http.Response('', 204);
    });

    final service = HitobitoPeopleService(
      config: const HitobitoAuthConfig(
        clientId: 'client',
        clientSecret: 'secret',
        authorizationUrl: 'https://demo.hitobito.com/oauth/authorize',
        tokenUrl: 'https://demo.hitobito.com/oauth/token',
        redirectUri: 'de.jlange.nami.app:/oauth/callback',
        scopeString: 'openid email api',
        discoveryUrl: '',
        profileUrl: 'https://demo.hitobito.com/oauth/profile',
      ),
      httpClient: client,
    );

    final mitglied = Mitglied(
      personId: 23,
      mitgliedsnummer: '4711',
      vorname: 'Julia',
      nachname: 'Keller',
      geburtsdatum: Mitglied.peoplePlaceholderDate,
      eintrittsdatum: DateTime(2020, 5, 1),
    );

    await service.updatePerson('token-123', mitglied: mitglied);

    final updatePersonBody =
        jsonDecode(requests.single.body) as Map<String, dynamic>;
    expect(updatePersonBody['data']['attributes']['birthday'], isNull);
  });

  test('haelt den HTTP-Status bei 401 aus dem People-Endpoint fest', () async {
    final client = MockClient((_) async => http.Response('Unauthorized', 401));
    final service = HitobitoPeopleService(
      config: const HitobitoAuthConfig(
        clientId: 'client',
        clientSecret: 'secret',
        authorizationUrl: 'https://demo.hitobito.com/oauth/authorize',
        tokenUrl: 'https://demo.hitobito.com/oauth/token',
        redirectUri: 'de.jlange.nami.app:/oauth/callback',
        scopeString: 'openid email api',
        discoveryUrl: '',
        profileUrl: 'https://demo.hitobito.com/oauth/profile',
      ),
      httpClient: client,
    );

    await expectLater(
      () => service.fetchPeopleResources('token-401'),
      throwsA(
        isA<HitobitoPeopleException>().having(
          (error) => error.statusCode,
          'statusCode',
          401,
        ),
      ),
    );
  });

  test('haelt den genauen JSON-API-Fehlergrund bei Mutation fest', () async {
    final client = MockClient(
      (_) async => http.Response(
        '''
          {
            "errors": [
              {
                "status": "400",
                "title": "Request Error",
                "detail": "data.attributes.exit_date is an unknown attribute",
                "source": {"pointer": "data/attributes/exit_date"},
                "meta": {
                  "attribute": "data.attributes.exit_date",
                  "message": "is an unknown attribute"
                }
              }
            ]
          }
          ''',
        400,
        headers: <String, String>{'content-type': 'application/vnd.api+json'},
      ),
    );
    final service = HitobitoPeopleService(
      config: const HitobitoAuthConfig(
        clientId: 'client',
        clientSecret: 'secret',
        authorizationUrl: 'https://demo.hitobito.com/oauth/authorize',
        tokenUrl: 'https://demo.hitobito.com/oauth/token',
        redirectUri: 'de.jlange.nami.app:/oauth/callback',
        scopeString: 'openid email api',
        discoveryUrl: '',
        profileUrl: 'https://demo.hitobito.com/oauth/profile',
      ),
      httpClient: client,
    );

    await expectLater(
      () => service.updatePerson(
        'token-123',
        mitglied: Mitglied.peopleListItem(
          mitgliedsnummer: '4711',
          personId: 23,
          vorname: 'Julia',
          nachname: 'Keller',
        ),
      ),
      throwsA(
        isA<HitobitoPeopleException>().having(
          (error) => error.message,
          'message',
          contains(
            'Grund: data.attributes.exit_date is an unknown attribute [data.attributes.exit_date]',
          ),
        ),
      ),
    );
  });
}

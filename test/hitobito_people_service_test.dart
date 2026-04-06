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
        'person_id,group_id,type,label,name',
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
      expect(people.first.pronoun, 'sie/ihr');
      expect(people.first.emailAdressen, const <MitgliedKontaktEmail>[
        MitgliedKontaktEmail(
          wert: 'julia@example.org',
          label: Mitglied.primaryEmailLabel,
          istPrimaer: true,
        ),
        MitgliedKontaktEmail(wert: 'julia.privat@example.org', label: 'Privat'),
        MitgliedKontaktEmail(wert: 'eltern@example.org'),
      ]);
      expect(people.first.telefonnummern, const <MitgliedKontaktTelefon>[
        MitgliedKontaktTelefon(wert: '+49 170 1234567', label: 'Mobil'),
        MitgliedKontaktTelefon(wert: '+49 40 9876543', label: 'Festnetz'),
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
}

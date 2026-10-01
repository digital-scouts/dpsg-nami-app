import 'package:nami/services/hitobito_auth_env.dart';

/// Hitobito-Konfiguration fuer Tests gegen die Demo-Instanz.
const testHitobitoAuthConfig = HitobitoAuthConfig(
  clientId: 'client',
  clientSecret: 'secret',
  authorizationUrl: 'https://demo.hitobito.com/oauth/authorize',
  tokenUrl: 'https://demo.hitobito.com/oauth/token',
  redirectUri: 'de.jlange.nami.app:/oauth/callback',
  scopeString: 'openid email api',
  discoveryUrl: '',
  profileUrl: 'https://demo.hitobito.com/oauth/profile',
);

/// Telefonnummer einer Person, wie Hitobito sie in `included` liefert.
class FixturePhoneNumber {
  const FixturePhoneNumber({
    required this.id,
    required this.number,
    this.label,
  });

  final int id;
  final String number;
  final String? label;

  Map<String, dynamic> toIncluded(int personId) => <String, dynamic>{
    'id': id.toString(),
    'type': 'phone_numbers',
    'attributes': <String, dynamic>{
      'contactable_id': personId,
      'contactable_type': 'Person',
      'label': label,
      'number': number,
    },
  };
}

/// JSON:API-Dokument fuer `GET /api/people/{id}`.
Map<String, dynamic> personResourceDocument({
  required int id,
  required DateTime updatedAt,
  int? membershipNumber,
  String firstName = 'Julia',
  String lastName = 'Keller',
  String? nickname,
  List<FixturePhoneNumber> phoneNumbers = const <FixturePhoneNumber>[],
  Map<String, dynamic> extraAttributes = const <String, dynamic>{},
}) {
  return <String, dynamic>{
    'data': <String, dynamic>{
      'id': id.toString(),
      'type': 'people',
      'attributes': <String, dynamic>{
        'first_name': firstName,
        'last_name': lastName,
        'nickname': nickname,
        'membership_number': membershipNumber,
        'updated_at': updatedAt.toUtc().toIso8601String(),
        ...extraAttributes,
      },
      'relationships': <String, dynamic>{
        'roles': <String, dynamic>{'data': <Map<String, dynamic>>[]},
        'phone_numbers': <String, dynamic>{
          'data': <Map<String, dynamic>>[
            for (final phone in phoneNumbers)
              <String, dynamic>{
                'id': phone.id.toString(),
                'type': 'phone_numbers',
              },
          ],
        },
        'additional_emails': <String, dynamic>{
          'data': <Map<String, dynamic>>[],
        },
        'additional_addresses': <String, dynamic>{
          'data': <Map<String, dynamic>>[],
        },
      },
    },
    'included': <Map<String, dynamic>>[
      for (final phone in phoneNumbers) phone.toIncluded(id),
    ],
  };
}

/// JSON:API-Fehlerdokument einer abgelehnten Mutation (422) fuer ein
/// Attribut einer Telefonnummer, wie Hitobito es bei Sideposting liefert.
Map<String, dynamic> phoneNumberValidationErrorDocument({
  required String detail,
  int? phoneNumberId,
  String attribute = 'number',
  String code = 'invalid',
}) {
  return <String, dynamic>{
    'errors': <Map<String, dynamic>>[
      <String, dynamic>{
        'code': 'unprocessable_entity',
        'status': '422',
        'title': 'Validation Error',
        'detail': detail,
        'source': <String, dynamic>{'pointer': '/data/attributes/$attribute'},
        'meta': <String, dynamic>{
          'relationship': <String, dynamic>{
            'attribute': attribute,
            'message': detail,
            'code': code,
            'name': 'phone_numbers',
            'type': 'phone_numbers',
            'id': phoneNumberId,
          },
        },
      },
    ],
  };
}

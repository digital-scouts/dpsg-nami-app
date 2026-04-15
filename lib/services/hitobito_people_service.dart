import 'dart:convert';

import 'package:http/http.dart' as http;

import '../data/arbeitskontext/hitobito_person_resource.dart';
import '../domain/member/mitglied.dart';
import 'hitobito_api_exception.dart';
import 'hitobito_auth_env.dart';

class HitobitoPeopleException extends HitobitoApiException {
  const HitobitoPeopleException(
    super.message, {
    super.statusCode,
    super.validationErrors = const <HitobitoApiValidationError>[],
  });
}

enum HitobitoRelationshipMutationMethod { create, update, destroy }

class HitobitoRelationshipMutation<T> {
  const HitobitoRelationshipMutation({
    required this.method,
    required this.value,
  });

  final HitobitoRelationshipMutationMethod method;
  final T value;
}

class _HitobitoRelationshipPayload {
  const _HitobitoRelationshipPayload({
    required this.data,
    required this.included,
  });

  final List<Map<String, dynamic>> data;
  final List<Map<String, dynamic>> included;
}

class HitobitoPeopleService {
  HitobitoPeopleService({required this.config, http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  HitobitoAuthConfig config;
  final http.Client _httpClient;

  void updateConfig(HitobitoAuthConfig nextConfig) {
    config = nextConfig;
  }

  Future<List<Mitglied>> fetchPeople(String accessToken) async {
    final resources = await fetchPeopleResources(accessToken);
    return resources
        .map((resource) => resource.toMitglied())
        .toList(growable: false);
  }

  Future<List<HitobitoPersonResource>> fetchPeopleResources(
    String accessToken,
  ) async {
    final requestUri = config.peopleUri;
    if (requestUri == null) {
      throw const HitobitoPeopleException(
        'Der People-Endpoint konnte nicht aus der OAuth-Konfiguration abgeleitet werden.',
      );
    }

    final resources = <HitobitoPersonResource>[];
    Uri? nextUri = requestUri;

    while (nextUri != null) {
      final effectiveRequestUri = _decoratePeopleRequestUri(nextUri);
      final decoded = await _fetchPeoplePage(
        requestUri: effectiveRequestUri,
        accessToken: accessToken,
      );
      final data = decoded['data'];
      if (data is! List) {
        throw const HitobitoPeopleException(
          'People-Antwort enthaelt keine gueltige Datensammlung.',
        );
      }

      final includedPeopleResources = _extractIncludedPeopleResources(decoded);

      resources.addAll(
        data.whereType<Map<String, dynamic>>().map(
          (resource) => _mapPersonResource(
            resource,
            includedRolesById: includedPeopleResources.rolesById,
            includedRolesByPersonId: includedPeopleResources.rolesByPersonId,
            includedPeopleResources: includedPeopleResources,
          ),
        ),
      );
      nextUri = _resolveNextUri(decoded, currentUri: effectiveRequestUri);
    }

    return resources;
  }

  Future<HitobitoPersonResource> fetchPersonResourceById(
    String accessToken,
    int personId,
  ) async {
    if (personId <= 0) {
      throw const HitobitoPeopleException(
        'Die Person-ID fuer den Detailabruf ist ungueltig.',
      );
    }

    final requestUri = _resourceUri('/api/people/$personId');
    final effectiveRequestUri = _decoratePeopleRequestUri(requestUri);
    final decoded = await _fetchPeoplePage(
      requestUri: effectiveRequestUri,
      accessToken: accessToken,
    );
    final data = decoded['data'];
    if (data is! Map<String, dynamic>) {
      throw const HitobitoPeopleException(
        'People-Detailantwort enthaelt keine gueltige Person.',
      );
    }

    final includedPeopleResources = _extractIncludedPeopleResources(decoded);
    return _mapPersonResource(
      data,
      includedRolesById: includedPeopleResources.rolesById,
      includedRolesByPersonId: includedPeopleResources.rolesByPersonId,
      includedPeopleResources: includedPeopleResources,
    );
  }

  Future<void> updatePerson(
    String accessToken, {
    required Mitglied mitglied,
  }) async {
    final personId = mitglied.personId;
    if (personId == null || personId <= 0) {
      throw const HitobitoPeopleException(
        'Die Person kann ohne gueltige Person-ID nicht aktualisiert werden.',
      );
    }

    await _sendJsonApiMutation(
      method: 'PUT',
      accessToken: accessToken,
      requestUri: _resourceUri('/api/people/$personId'),
      body: <String, dynamic>{
        'data': <String, dynamic>{
          'type': 'people',
          'id': personId.toString(),
          'attributes': _buildPersonAttributes(mitglied),
        },
      },
    );
  }

  Future<void> updatePersonWithRelationships(
    String accessToken, {
    required Mitglied mitglied,
    List<HitobitoRelationshipMutation<MitgliedKontaktTelefon>>
        phoneNumberMutations =
        const <HitobitoRelationshipMutation<MitgliedKontaktTelefon>>[],
    List<HitobitoRelationshipMutation<MitgliedKontaktEmail>>
        additionalEmailMutations =
        const <HitobitoRelationshipMutation<MitgliedKontaktEmail>>[],
    List<HitobitoRelationshipMutation<MitgliedKontaktAdresse>>
        additionalAddressMutations =
        const <HitobitoRelationshipMutation<MitgliedKontaktAdresse>>[],
  }) async {
    final personId = mitglied.personId;
    if (personId == null || personId <= 0) {
      throw const HitobitoPeopleException(
        'Die Person kann ohne gueltige Person-ID nicht aktualisiert werden.',
      );
    }

    final relationships = <String, dynamic>{};
    final included = <Map<String, dynamic>>[];

    if (phoneNumberMutations.isNotEmpty) {
      final payload = _buildPhoneNumberPayload(phoneNumberMutations);
      relationships['phone_numbers'] = <String, dynamic>{'data': payload.data};
      included.addAll(payload.included);
    }

    if (additionalEmailMutations.isNotEmpty) {
      final payload = _buildAdditionalEmailPayload(additionalEmailMutations);
      relationships['additional_emails'] = <String, dynamic>{
        'data': payload.data,
      };
      included.addAll(payload.included);
    }

    if (additionalAddressMutations.isNotEmpty) {
      final payload = _buildAdditionalAddressPayload(
        additionalAddressMutations,
      );
      relationships['additional_addresses'] = <String, dynamic>{
        'data': payload.data,
      };
      included.addAll(payload.included);
    }

    await _sendJsonApiMutation(
      method: 'PUT',
      accessToken: accessToken,
      requestUri: _resourceUri('/api/people/$personId'),
      body: <String, dynamic>{
        'data': <String, dynamic>{
          'type': 'people',
          'id': personId.toString(),
          'attributes': _buildPersonAttributes(mitglied),
          if (relationships.isNotEmpty) 'relationships': relationships,
        },
        if (included.isNotEmpty) 'included': included,
      },
    );
  }

  Future<void> createPhoneNumber(
    String accessToken, {
    required int personId,
    required MitgliedKontaktTelefon telefonnummer,
  }) {
    return _sendJsonApiMutation(
      method: 'POST',
      accessToken: accessToken,
      requestUri: _resourceUri('/api/phone_numbers'),
      body: <String, dynamic>{
        'data': <String, dynamic>{
          'type': 'phone_numbers',
          'attributes': <String, dynamic>{
            'label': telefonnummer.label,
            'contactable_id': personId,
            'contactable_type': 'Person',
            'number': telefonnummer.wert,
          },
        },
      },
    );
  }

  Future<void> updatePhoneNumber(
    String accessToken, {
    required MitgliedKontaktTelefon telefonnummer,
  }) {
    final phoneNumberId = telefonnummer.phoneNumberId;
    if (phoneNumberId == null || phoneNumberId <= 0) {
      throw const HitobitoPeopleException(
        'Die Telefonnummer kann ohne gueltige ID nicht aktualisiert werden.',
      );
    }

    return _sendJsonApiMutation(
      method: 'PUT',
      accessToken: accessToken,
      requestUri: _resourceUri('/api/phone_numbers/$phoneNumberId'),
      body: <String, dynamic>{
        'data': <String, dynamic>{
          'type': 'phone_numbers',
          'id': phoneNumberId.toString(),
          'attributes': <String, dynamic>{
            'label': telefonnummer.label,
            'number': telefonnummer.wert,
          },
        },
      },
    );
  }

  Future<void> deletePhoneNumber(
    String accessToken, {
    required int phoneNumberId,
  }) {
    return _sendJsonApiMutation(
      method: 'DELETE',
      accessToken: accessToken,
      requestUri: _resourceUri('/api/phone_numbers/$phoneNumberId'),
    );
  }

  Future<void> createAdditionalEmail(
    String accessToken, {
    required int personId,
    required MitgliedKontaktEmail email,
  }) {
    return _sendJsonApiMutation(
      method: 'POST',
      accessToken: accessToken,
      requestUri: _resourceUri('/api/additional_emails'),
      body: <String, dynamic>{
        'data': <String, dynamic>{
          'type': 'additional_emails',
          'attributes': <String, dynamic>{
            'label': email.label,
            'contactable_id': personId,
            'contactable_type': 'Person',
            'email': email.wert,
          },
        },
      },
    );
  }

  Future<void> updateAdditionalEmail(
    String accessToken, {
    required MitgliedKontaktEmail email,
  }) {
    final additionalEmailId = email.additionalEmailId;
    if (additionalEmailId == null || additionalEmailId <= 0) {
      throw const HitobitoPeopleException(
        'Die Zusatzmail kann ohne gueltige ID nicht aktualisiert werden.',
      );
    }

    return _sendJsonApiMutation(
      method: 'PUT',
      accessToken: accessToken,
      requestUri: _resourceUri('/api/additional_emails/$additionalEmailId'),
      body: <String, dynamic>{
        'data': <String, dynamic>{
          'type': 'additional_emails',
          'id': additionalEmailId.toString(),
          'attributes': <String, dynamic>{
            'label': email.label,
            'email': email.wert,
          },
        },
      },
    );
  }

  Future<void> deleteAdditionalEmail(
    String accessToken, {
    required int additionalEmailId,
  }) {
    return _sendJsonApiMutation(
      method: 'DELETE',
      accessToken: accessToken,
      requestUri: _resourceUri('/api/additional_emails/$additionalEmailId'),
    );
  }

  Future<void> createAdditionalAddress(
    String accessToken, {
    required int personId,
    required MitgliedKontaktAdresse adresse,
  }) {
    return _sendJsonApiMutation(
      method: 'POST',
      accessToken: accessToken,
      requestUri: _resourceUri('/api/additional_addresses'),
      body: <String, dynamic>{
        'data': <String, dynamic>{
          'type': 'additional_addresses',
          'attributes': <String, dynamic>{
            'label': adresse.label,
            'contactable_id': personId,
            'contactable_type': 'Person',
            'address_care_of': adresse.addressCareOf,
            'street': adresse.street,
            'housenumber': adresse.housenumber,
            'postbox': adresse.postbox,
            'zip_code': adresse.zipCode,
            'town': adresse.town,
            'country': adresse.country,
          },
        },
      },
    );
  }

  Future<void> updateAdditionalAddress(
    String accessToken, {
    required MitgliedKontaktAdresse adresse,
  }) {
    final additionalAddressId = adresse.additionalAddressId;
    if (additionalAddressId == null || additionalAddressId <= 0) {
      throw const HitobitoPeopleException(
        'Die Zusatzadresse kann ohne gueltige ID nicht aktualisiert werden.',
      );
    }

    return _sendJsonApiMutation(
      method: 'PUT',
      accessToken: accessToken,
      requestUri: _resourceUri(
        '/api/additional_addresses/$additionalAddressId',
      ),
      body: <String, dynamic>{
        'data': <String, dynamic>{
          'type': 'additional_addresses',
          'id': additionalAddressId.toString(),
          'attributes': <String, dynamic>{
            'label': adresse.label,
            'address_care_of': adresse.addressCareOf,
            'street': adresse.street,
            'housenumber': adresse.housenumber,
            'postbox': adresse.postbox,
            'zip_code': adresse.zipCode,
            'town': adresse.town,
            'country': adresse.country,
          },
        },
      },
    );
  }

  Future<void> deleteAdditionalAddress(
    String accessToken, {
    required int additionalAddressId,
  }) {
    return _sendJsonApiMutation(
      method: 'DELETE',
      accessToken: accessToken,
      requestUri: _resourceUri(
        '/api/additional_addresses/$additionalAddressId',
      ),
    );
  }

  Map<String, dynamic> _buildPersonAttributes(Mitglied mitglied) {
    final primaryEmail = _resolvePrimaryEmail(mitglied.emailAdressen);
    final primaryAddress = _resolvePrimaryAddress(mitglied.adressen);
    return <String, dynamic>{
      'first_name': mitglied.vorname,
      'last_name': mitglied.nachname,
      'nickname': mitglied.fahrtenname,
      'gender': mitglied.gender,
      'email': primaryEmail?.wert,
      'address_care_of': primaryAddress?.addressCareOf,
      'street': primaryAddress?.street,
      'housenumber': primaryAddress?.housenumber,
      'postbox': primaryAddress?.postbox,
      'zip_code': primaryAddress?.zipCode,
      'town': primaryAddress?.town,
      'country': primaryAddress?.country,
      'birthday': _toDateStringOrNull(mitglied.geburtsdatum),
    };
  }

  _HitobitoRelationshipPayload _buildPhoneNumberPayload(
    List<HitobitoRelationshipMutation<MitgliedKontaktTelefon>> mutations,
  ) {
    var nextTempId = 1;
    final data = <Map<String, dynamic>>[];
    final included = <Map<String, dynamic>>[];

    for (final mutation in mutations) {
      final telefonnummer = mutation.value;
      switch (mutation.method) {
        case HitobitoRelationshipMutationMethod.create:
          final tempId = 'new-phone-$nextTempId';
          nextTempId++;
          data.add(<String, dynamic>{
            'type': 'phone_numbers',
            'temp-id': tempId,
            'method': 'create',
          });
          included.add(<String, dynamic>{
            'type': 'phone_numbers',
            'temp-id': tempId,
            'attributes': <String, dynamic>{
              'label': telefonnummer.label,
              'number': telefonnummer.wert,
              "public": false,
            },
          });
        case HitobitoRelationshipMutationMethod.update:
          final phoneNumberId = telefonnummer.phoneNumberId;
          if (phoneNumberId == null || phoneNumberId <= 0) {
            throw const HitobitoPeopleException(
              'Telefon-Update ohne gueltige ID ist nicht moeglich.',
            );
          }
          data.add(<String, dynamic>{
            'type': 'phone_numbers',
            'id': phoneNumberId.toString(),
            'method': 'update',
          });
          included.add(<String, dynamic>{
            'type': 'phone_numbers',
            'id': phoneNumberId.toString(),
            'attributes': <String, dynamic>{
              'label': telefonnummer.label,
              'number': telefonnummer.wert,
            },
          });
        case HitobitoRelationshipMutationMethod.destroy:
          final phoneNumberId = telefonnummer.phoneNumberId;
          if (phoneNumberId == null || phoneNumberId <= 0) {
            throw const HitobitoPeopleException(
              'Telefon-Loeschen ohne gueltige ID ist nicht moeglich.',
            );
          }
          data.add(<String, dynamic>{
            'type': 'phone_numbers',
            'id': phoneNumberId.toString(),
            'method': 'destroy',
          });
      }
    }

    return _HitobitoRelationshipPayload(data: data, included: included);
  }

  _HitobitoRelationshipPayload _buildAdditionalEmailPayload(
    List<HitobitoRelationshipMutation<MitgliedKontaktEmail>> mutations,
  ) {
    var nextTempId = 1;
    final data = <Map<String, dynamic>>[];
    final included = <Map<String, dynamic>>[];

    for (final mutation in mutations) {
      final email = mutation.value;
      switch (mutation.method) {
        case HitobitoRelationshipMutationMethod.create:
          final tempId = 'new-email-$nextTempId';
          nextTempId++;
          data.add(<String, dynamic>{
            'type': 'additional_emails',
            'temp-id': tempId,
            'method': 'create',
          });
          included.add(<String, dynamic>{
            'type': 'additional_emails',
            'temp-id': tempId,
            'attributes': <String, dynamic>{
              'label': email.label,
              'email': email.wert,
            },
          });
        case HitobitoRelationshipMutationMethod.update:
          final additionalEmailId = email.additionalEmailId;
          if (additionalEmailId == null || additionalEmailId <= 0) {
            throw const HitobitoPeopleException(
              'Zusatzmail-Update ohne gueltige ID ist nicht moeglich.',
            );
          }
          data.add(<String, dynamic>{
            'type': 'additional_emails',
            'id': additionalEmailId.toString(),
            'method': 'update',
          });
          included.add(<String, dynamic>{
            'type': 'additional_emails',
            'id': additionalEmailId.toString(),
            'attributes': <String, dynamic>{
              'label': email.label,
              'email': email.wert,
            },
          });
        case HitobitoRelationshipMutationMethod.destroy:
          final additionalEmailId = email.additionalEmailId;
          if (additionalEmailId == null || additionalEmailId <= 0) {
            throw const HitobitoPeopleException(
              'Zusatzmail-Loeschen ohne gueltige ID ist nicht moeglich.',
            );
          }
          data.add(<String, dynamic>{
            'type': 'additional_emails',
            'id': additionalEmailId.toString(),
            'method': 'destroy',
          });
      }
    }

    return _HitobitoRelationshipPayload(data: data, included: included);
  }

  _HitobitoRelationshipPayload _buildAdditionalAddressPayload(
    List<HitobitoRelationshipMutation<MitgliedKontaktAdresse>> mutations,
  ) {
    var nextTempId = 1;
    final data = <Map<String, dynamic>>[];
    final included = <Map<String, dynamic>>[];

    for (final mutation in mutations) {
      final adresse = mutation.value;
      switch (mutation.method) {
        case HitobitoRelationshipMutationMethod.create:
          final tempId = 'new-address-$nextTempId';
          nextTempId++;
          data.add(<String, dynamic>{
            'type': 'additional_addresses',
            'temp-id': tempId,
            'method': 'create',
          });
          included.add(<String, dynamic>{
            'type': 'additional_addresses',
            'temp-id': tempId,
            'attributes': <String, dynamic>{
              'label': adresse.label,
              'address_care_of': adresse.addressCareOf,
              'street': adresse.street,
              'housenumber': adresse.housenumber,
              'postbox': adresse.postbox,
              'zip_code': adresse.zipCode,
              'town': adresse.town,
              'country': adresse.country,
            },
          });
        case HitobitoRelationshipMutationMethod.update:
          final additionalAddressId = adresse.additionalAddressId;
          if (additionalAddressId == null || additionalAddressId <= 0) {
            throw const HitobitoPeopleException(
              'Zusatzadresse-Update ohne gueltige ID ist nicht moeglich.',
            );
          }
          data.add(<String, dynamic>{
            'type': 'additional_addresses',
            'id': additionalAddressId.toString(),
            'method': 'update',
          });
          included.add(<String, dynamic>{
            'type': 'additional_addresses',
            'id': additionalAddressId.toString(),
            'attributes': <String, dynamic>{
              'label': adresse.label,
              'address_care_of': adresse.addressCareOf,
              'street': adresse.street,
              'housenumber': adresse.housenumber,
              'postbox': adresse.postbox,
              'zip_code': adresse.zipCode,
              'town': adresse.town,
              'country': adresse.country,
            },
          });
        case HitobitoRelationshipMutationMethod.destroy:
          final additionalAddressId = adresse.additionalAddressId;
          if (additionalAddressId == null || additionalAddressId <= 0) {
            throw const HitobitoPeopleException(
              'Zusatzadresse-Loeschen ohne gueltige ID ist nicht moeglich.',
            );
          }
          data.add(<String, dynamic>{
            'type': 'additional_addresses',
            'id': additionalAddressId.toString(),
            'method': 'destroy',
          });
      }
    }

    return _HitobitoRelationshipPayload(data: data, included: included);
  }

  Uri _decoratePeopleRequestUri(Uri uri) {
    final queryParameters = Map<String, String>.from(uri.queryParameters);
    var includeValue = queryParameters['include'];
    for (final relationship in const <String>[
      'roles',
      'phone_numbers',
      'additional_emails',
      'additional_addresses',
    ]) {
      includeValue = _mergeCsvValue(includeValue, relationship);
    }
    queryParameters['include'] = includeValue ?? '';
    queryParameters['fields[roles]'] =
        'created_at,updated_at,start_on,end_on,name,person_id,group_id,type,label';
    queryParameters['fields[phone_numbers]'] =
        'contactable_id,contactable_type,label,number';
    queryParameters['fields[additional_emails]'] =
        'contactable_id,contactable_type,label,email';
    queryParameters['fields[additional_addresses]'] =
        'contactable_id,contactable_type,label,address_care_of,street,housenumber,postbox,zip_code,town,country';
    return uri.replace(queryParameters: queryParameters);
  }

  Future<Map<String, dynamic>> _fetchPeoplePage({
    required Uri requestUri,
    required String accessToken,
  }) async {
    final response = await _httpClient.get(
      requestUri,
      headers: <String, String>{
        'Accept': 'application/vnd.api+json, application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HitobitoPeopleException(
        'People-Anfrage fehlgeschlagen (${response.statusCode}).',
        statusCode: response.statusCode,
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const HitobitoPeopleException(
        'People-Antwort hat ein ungueltiges Format.',
      );
    }
    return decoded;
  }

  Future<void> _sendJsonApiMutation({
    required String method,
    required String accessToken,
    required Uri requestUri,
    Map<String, dynamic>? body,
  }) async {
    final request = http.Request(method, requestUri)
      ..headers.addAll(<String, String>{
        'Accept': 'application/vnd.api+json, application/json',
        'Authorization': 'Bearer $accessToken',
        if (body != null) 'Content-Type': 'application/vnd.api+json',
      });
    if (body != null) {
      request.body = jsonEncode(body);
    }

    final streamedResponse = await _httpClient.send(request);
    final response = await http.Response.fromStream(streamedResponse);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }

    throw HitobitoPeopleException(
      _buildMutationErrorMessage(method: method, response: response),
      statusCode: response.statusCode,
      validationErrors: _extractMutationValidationErrors(response.body),
    );
  }

  HitobitoPersonResource _mapPersonResource(
    Map<String, dynamic> resource, {
    required Map<String, HitobitoPersonRoleResource> includedRolesById,
    required Map<int, List<HitobitoPersonRoleResource>> includedRolesByPersonId,
    required _IncludedPeopleResources includedPeopleResources,
  }) {
    final attributes = resource['attributes'];
    final attributesMap = attributes is Map<String, dynamic>
        ? attributes
        : const <String, dynamic>{};
    final relationships = resource['relationships'];
    final relationshipsMap = relationships is Map<String, dynamic>
        ? relationships
        : const <String, dynamic>{};

    final id = _toInt(resource['id']);
    if (id <= 0) {
      throw const HitobitoPeopleException(
        'People-Antwort enthaelt eine ungueltige Person.',
      );
    }

    final roleIds = _extractRelationshipIds(relationshipsMap['roles']);
    final roles = <HitobitoPersonRoleResource>[];
    final seenRoleIds = <int>{};
    for (final roleId in roleIds) {
      final role = includedRolesById[roleId];
      if (role == null || !seenRoleIds.add(role.id)) {
        continue;
      }
      roles.add(role);
    }
    if (roles.isEmpty) {
      for (final role
          in includedRolesByPersonId[id] ??
              const <HitobitoPersonRoleResource>[]) {
        if (!seenRoleIds.add(role.id)) {
          continue;
        }
        roles.add(role);
      }
    }

    final phoneNumberIds = _extractRelationshipIds(
      relationshipsMap['phone_numbers'],
    );
    final additionalEmailIds = _extractRelationshipIds(
      relationshipsMap['additional_emails'],
    );
    final additionalAddressIds = _extractRelationshipIds(
      relationshipsMap['additional_addresses'],
    );

    return HitobitoPersonResource(
      id: id,
      firstName: attributesMap['first_name']?.toString() ?? '',
      lastName: attributesMap['last_name']?.toString() ?? '',
      nickname: attributesMap['nickname']?.toString(),
      primaryGroupId: _toNullableInt(attributesMap['primary_group_id']),
      membershipNumber: _toNullableInt(attributesMap['membership_number']),
      birthday: _toDateTime(attributesMap['birthday']),
      entryDate: _toDateTime(attributesMap['entry_date']),
      exitDate: _toDateTime(attributesMap['exit_date']),
      updatedAt: _toDateTime(attributesMap['updated_at']),
      gender: _toNullableString(attributesMap['gender']),
      pronoun: _toNullableString(attributesMap['pronoun']),
      bankAccountOwner: _toNullableString(attributesMap['bank_account_owner']),
      iban: _toNullableString(attributesMap['iban']),
      bic: _toNullableString(attributesMap['bic']),
      bankName: _toNullableString(attributesMap['bank_name']),
      paymentMethod: _toNullableString(attributesMap['payment_method']),
      telefonnummern: _mapTelefonnummern(
        personId: id,
        relationshipIds: phoneNumberIds,
        includedPeopleResources: includedPeopleResources,
      ),
      emailAdressen: _mapEmailAdressen(
        attributesMap: attributesMap,
        personId: id,
        relationshipIds: additionalEmailIds,
        includedPeopleResources: includedPeopleResources,
      ),
      adressen: _mapAdressen(
        attributesMap: attributesMap,
        personId: id,
        relationshipIds: additionalAddressIds,
        includedPeopleResources: includedPeopleResources,
      ),
      roles: roles,
    );
  }

  _IncludedPeopleResources _extractIncludedPeopleResources(
    Map<String, dynamic> decoded,
  ) {
    final included = decoded['included'];
    if (included is! List) {
      return const _IncludedPeopleResources();
    }

    final rolesById = <String, HitobitoPersonRoleResource>{};
    final rolesByPersonId = <int, List<HitobitoPersonRoleResource>>{};
    final phoneNumbersById =
        <String, _IncludedPersonValue<MitgliedKontaktTelefon>>{};
    final phoneNumbersByPersonId =
        <int, List<_IncludedPersonValue<MitgliedKontaktTelefon>>>{};
    final additionalEmailsById =
        <String, _IncludedPersonValue<MitgliedKontaktEmail>>{};
    final additionalEmailsByPersonId =
        <int, List<_IncludedPersonValue<MitgliedKontaktEmail>>>{};
    final additionalAddressesById =
        <String, _IncludedPersonValue<MitgliedKontaktAdresse>>{};
    final additionalAddressesByPersonId =
        <int, List<_IncludedPersonValue<MitgliedKontaktAdresse>>>{};

    for (final resource in included.whereType<Map<String, dynamic>>()) {
      final type = resource['type']?.toString();

      if (type == 'roles') {
        final role = _mapRoleResource(resource);
        if (role == null) {
          continue;
        }
        rolesById[role.id.toString()] = role;
        final personId = role.personId;
        if (personId != null) {
          rolesByPersonId
              .putIfAbsent(personId, () => <HitobitoPersonRoleResource>[])
              .add(role);
        }
        continue;
      }

      if (type == 'phone_numbers') {
        final phoneNumber = _mapPhoneNumberResource(resource);
        if (phoneNumber == null) {
          continue;
        }
        phoneNumbersById[phoneNumber.id.toString()] = phoneNumber;
        phoneNumbersByPersonId
            .putIfAbsent(
              phoneNumber.personId,
              () => <_IncludedPersonValue<MitgliedKontaktTelefon>>[],
            )
            .add(phoneNumber);
        continue;
      }

      if (type == 'additional_emails') {
        final additionalEmail = _mapAdditionalEmailResource(resource);
        if (additionalEmail == null) {
          continue;
        }
        additionalEmailsById[additionalEmail.id.toString()] = additionalEmail;
        additionalEmailsByPersonId
            .putIfAbsent(
              additionalEmail.personId,
              () => <_IncludedPersonValue<MitgliedKontaktEmail>>[],
            )
            .add(additionalEmail);
        continue;
      }

      if (type == 'additional_addresses') {
        final additionalAddress = _mapAdditionalAddressResource(resource);
        if (additionalAddress == null) {
          continue;
        }
        additionalAddressesById[additionalAddress.id.toString()] =
            additionalAddress;
        additionalAddressesByPersonId
            .putIfAbsent(
              additionalAddress.personId,
              () => <_IncludedPersonValue<MitgliedKontaktAdresse>>[],
            )
            .add(additionalAddress);
      }
    }

    return _IncludedPeopleResources(
      rolesById: rolesById,
      rolesByPersonId: rolesByPersonId,
      phoneNumbersById: phoneNumbersById,
      phoneNumbersByPersonId: phoneNumbersByPersonId,
      additionalEmailsById: additionalEmailsById,
      additionalEmailsByPersonId: additionalEmailsByPersonId,
      additionalAddressesById: additionalAddressesById,
      additionalAddressesByPersonId: additionalAddressesByPersonId,
    );
  }

  HitobitoPersonRoleResource? _mapRoleResource(Map<String, dynamic> resource) {
    final attributes = resource['attributes'];
    final attributesMap = attributes is Map<String, dynamic>
        ? attributes
        : const <String, dynamic>{};
    final id = _toInt(resource['id']);
    final groupId = _toNullableInt(attributesMap['group_id']);
    if (id <= 0 || groupId == null) {
      return null;
    }

    return HitobitoPersonRoleResource(
      id: id,
      groupId: groupId,
      personId: _toNullableInt(attributesMap['person_id']),
      createdAt: _toDateTime(attributesMap['created_at']),
      updatedAt: _toDateTime(attributesMap['updated_at']),
      startOn: _toDateTime(attributesMap['start_on']),
      endOn: _toDateTime(attributesMap['end_on']),
      roleType: attributesMap['type']?.toString(),
      roleName: attributesMap['name']?.toString(),
      roleLabel: attributesMap['label']?.toString(),
    );
  }

  _IncludedPersonValue<MitgliedKontaktTelefon>? _mapPhoneNumberResource(
    Map<String, dynamic> resource,
  ) {
    final attributes = resource['attributes'];
    final attributesMap = attributes is Map<String, dynamic>
        ? attributes
        : const <String, dynamic>{};
    final id = _toInt(resource['id']);
    final personId = _toContactablePersonId(attributesMap);
    final number = _toNullableString(attributesMap['number']);
    if (id <= 0 || personId == null || number == null) {
      return null;
    }

    return _IncludedPersonValue<MitgliedKontaktTelefon>(
      id: id,
      personId: personId,
      value: MitgliedKontaktTelefon(
        phoneNumberId: id,
        wert: number,
        label: _toNullableString(attributesMap['label']),
      ),
    );
  }

  _IncludedPersonValue<MitgliedKontaktEmail>? _mapAdditionalEmailResource(
    Map<String, dynamic> resource,
  ) {
    final attributes = resource['attributes'];
    final attributesMap = attributes is Map<String, dynamic>
        ? attributes
        : const <String, dynamic>{};
    final id = _toInt(resource['id']);
    final personId = _toContactablePersonId(attributesMap);
    final email = _toNullableString(attributesMap['email']);
    if (id <= 0 || personId == null || email == null) {
      return null;
    }

    return _IncludedPersonValue<MitgliedKontaktEmail>(
      id: id,
      personId: personId,
      value: MitgliedKontaktEmail(
        additionalEmailId: id,
        wert: email,
        label: _toNullableString(attributesMap['label']),
      ),
    );
  }

  _IncludedPersonValue<MitgliedKontaktAdresse>? _mapAdditionalAddressResource(
    Map<String, dynamic> resource,
  ) {
    final attributes = resource['attributes'];
    final attributesMap = attributes is Map<String, dynamic>
        ? attributes
        : const <String, dynamic>{};
    final id = _toInt(resource['id']);
    final personId = _toContactablePersonId(attributesMap);
    final adresse = MitgliedKontaktAdresse(
      additionalAddressId: id,
      label: _toNullableString(attributesMap['label']),
      addressCareOf: _toNullableString(attributesMap['address_care_of']),
      street: _toNullableString(attributesMap['street']),
      housenumber: _toNullableString(attributesMap['housenumber']),
      postbox: _toNullableString(attributesMap['postbox']),
      zipCode: _toNullableString(attributesMap['zip_code']),
      town: _toNullableString(attributesMap['town']),
      country: _toNullableString(attributesMap['country']),
    );
    if (id <= 0 || personId == null || adresse.istLeer) {
      return null;
    }

    return _IncludedPersonValue<MitgliedKontaktAdresse>(
      id: id,
      personId: personId,
      value: adresse,
    );
  }

  List<String> _extractRelationshipIds(Object? relationship) {
    if (relationship is! Map<String, dynamic>) {
      return const <String>[];
    }

    final data = relationship['data'];
    if (data is! List) {
      return const <String>[];
    }

    return data
        .whereType<Map<String, dynamic>>()
        .map((entry) => entry['id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
  }

  int? _toContactablePersonId(Map<String, dynamic> attributesMap) {
    final contactableType = _toNullableString(
      attributesMap['contactable_type'],
    );
    if (contactableType != null &&
        !contactableType.toLowerCase().contains('person')) {
      return null;
    }

    return _toNullableInt(attributesMap['contactable_id']);
  }

  List<T> _resolveIncludedValues<T>({
    required int personId,
    required List<String> relationshipIds,
    required Map<String, _IncludedPersonValue<T>> byId,
    required Map<int, List<_IncludedPersonValue<T>>> byPersonId,
  }) {
    final result = <T>[];
    final seenIds = <int>{};

    for (final relationshipId in relationshipIds) {
      final value = byId[relationshipId];
      if (value == null ||
          value.personId != personId ||
          !seenIds.add(value.id)) {
        continue;
      }
      result.add(value.value);
    }

    for (final value in byPersonId[personId] ?? <_IncludedPersonValue<T>>[]) {
      if (!seenIds.add(value.id)) {
        continue;
      }
      result.add(value.value);
    }

    return result;
  }

  Uri? _resolveNextUri(
    Map<String, dynamic> decoded, {
    required Uri currentUri,
  }) {
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

  int _toInt(Object? value) {
    if (value is int) {
      return value;
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  int? _toNullableInt(Object? value) {
    final parsed = _toInt(value);
    if (parsed <= 0) {
      return null;
    }
    return parsed;
  }

  String _mergeCsvValue(String? currentValue, String requiredValue) {
    final values = currentValue == null || currentValue.isEmpty
        ? <String>[]
        : currentValue
              .split(',')
              .map((value) => value.trim())
              .where((value) => value.isNotEmpty)
              .toList(growable: true);
    if (!values.contains(requiredValue)) {
      values.add(requiredValue);
    }
    return values.join(',');
  }

  DateTime? _toDateTime(Object? value) {
    final raw = _toNullableString(value);
    if (raw == null) {
      return null;
    }
    return DateTime.tryParse(raw);
  }

  String? _toNullableString(Object? value) {
    final raw = value?.toString().trim();
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return raw;
  }

  List<MitgliedKontaktTelefon> _mapTelefonnummern({
    required int personId,
    required List<String> relationshipIds,
    required _IncludedPeopleResources includedPeopleResources,
  }) {
    return _resolveIncludedValues<MitgliedKontaktTelefon>(
      personId: personId,
      relationshipIds: relationshipIds,
      byId: includedPeopleResources.phoneNumbersById,
      byPersonId: includedPeopleResources.phoneNumbersByPersonId,
    );
  }

  List<MitgliedKontaktEmail> _mapEmailAdressen({
    required Map<String, dynamic> attributesMap,
    required int personId,
    required List<String> relationshipIds,
    required _IncludedPeopleResources includedPeopleResources,
  }) {
    final result = <MitgliedKontaktEmail>[];
    final primaryEmail = _toNullableString(attributesMap['email']);
    if (primaryEmail != null) {
      result.add(
        MitgliedKontaktEmail(
          wert: primaryEmail,
          label: Mitglied.primaryEmailLabel,
          istPrimaer: true,
        ),
      );
    }

    result.addAll(
      _resolveIncludedValues<MitgliedKontaktEmail>(
        personId: personId,
        relationshipIds: relationshipIds,
        byId: includedPeopleResources.additionalEmailsById,
        byPersonId: includedPeopleResources.additionalEmailsByPersonId,
      ),
    );

    return result;
  }

  List<MitgliedKontaktAdresse> _mapAdressen({
    required Map<String, dynamic> attributesMap,
    required int personId,
    required List<String> relationshipIds,
    required _IncludedPeopleResources includedPeopleResources,
  }) {
    final result = <MitgliedKontaktAdresse>[];
    final adresse = MitgliedKontaktAdresse(
      additionalAddressId: 0,
      addressCareOf: _toNullableString(attributesMap['address_care_of']),
      street: _toNullableString(attributesMap['street']),
      housenumber: _toNullableString(attributesMap['housenumber']),
      postbox: _toNullableString(attributesMap['postbox']),
      zipCode: _toNullableString(attributesMap['zip_code']),
      town: _toNullableString(attributesMap['town']),
      country: _toNullableString(attributesMap['country']),
    );
    if (!adresse.istLeer) {
      result.add(adresse);
    }

    result.addAll(
      _resolveIncludedValues<MitgliedKontaktAdresse>(
        personId: personId,
        relationshipIds: relationshipIds,
        byId: includedPeopleResources.additionalAddressesById,
        byPersonId: includedPeopleResources.additionalAddressesByPersonId,
      ),
    );

    return result;
  }

  Uri _resourceUri(String path) {
    final baseUri = config.peopleUri;
    if (baseUri == null) {
      throw const HitobitoPeopleException(
        'Der People-Endpoint konnte nicht aus der OAuth-Konfiguration abgeleitet werden.',
      );
    }

    return baseUri.replace(path: path, queryParameters: null);
  }

  MitgliedKontaktEmail? _resolvePrimaryEmail(
    List<MitgliedKontaktEmail> emailAdressen,
  ) {
    for (final email in emailAdressen) {
      if (email.istPrimaer) {
        return email;
      }
    }
    return emailAdressen.isEmpty ? null : emailAdressen.first;
  }

  MitgliedKontaktAdresse? _resolvePrimaryAddress(
    List<MitgliedKontaktAdresse> adressen,
  ) {
    for (final adresse in adressen) {
      if ((adresse.additionalAddressId ?? 0) == 0) {
        return adresse;
      }
    }
    return adressen.isEmpty ? null : adressen.first;
  }

  String? _toDateStringOrNull(DateTime value) {
    if (value == Mitglied.peoplePlaceholderDate) {
      return null;
    }
    final normalized = value.toUtc();
    return normalized.toIso8601String().split('T').first;
  }

  String _mutationLabel(String method) {
    switch (method.toUpperCase()) {
      case 'POST':
        return 'Anlage';
      case 'PUT':
        return 'Aktualisierung';
      case 'DELETE':
        return 'Loeschen';
      default:
        return 'Mutation';
    }
  }

  String _buildMutationErrorMessage({
    required String method,
    required http.Response response,
  }) {
    final baseMessage =
        '${_mutationLabel(method)} fehlgeschlagen (${response.statusCode}).';
    final detail = _extractMutationFailureDetail(response.body);
    if (detail == null) {
      return baseMessage;
    }
    return '$baseMessage Grund: $detail';
  }

  String? _extractMutationFailureDetail(String body) {
    final trimmedBody = body.trim();
    if (trimmedBody.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(trimmedBody);
      if (decoded is Map<String, dynamic>) {
        final errors = decoded['errors'];
        if (errors is List) {
          final details = errors
              .whereType<Map<String, dynamic>>()
              .map(_extractMutationFailureItemDetail)
              .whereType<String>()
              .map((detail) => detail.trim())
              .where((detail) => detail.isNotEmpty)
              .toList(growable: false);
          if (details.isNotEmpty) {
            return details.join(' | ');
          }
        }

        final detail = _toNullableString(decoded['detail']);
        if (detail != null) {
          return detail;
        }
      }
    } catch (_) {
      // Fallback auf kompakten Klartext weiter unten.
    }

    if (trimmedBody.contains('<html') ||
        trimmedBody.contains('<!DOCTYPE html')) {
      return null;
    }

    return trimmedBody.replaceAll(RegExp(r'\s+'), ' ');
  }

  List<HitobitoApiValidationError> _extractMutationValidationErrors(
    String body,
  ) {
    final trimmedBody = body.trim();
    if (trimmedBody.isEmpty) {
      return const <HitobitoApiValidationError>[];
    }

    try {
      final decoded = jsonDecode(trimmedBody);
      if (decoded is! Map<String, dynamic>) {
        return const <HitobitoApiValidationError>[];
      }
      final errors = decoded['errors'];
      if (errors is! List) {
        return const <HitobitoApiValidationError>[];
      }

      return errors
          .whereType<Map<String, dynamic>>()
          .map(_extractMutationValidationError)
          .whereType<HitobitoApiValidationError>()
          .toList(growable: false);
    } catch (_) {
      return const <HitobitoApiValidationError>[];
    }
  }

  HitobitoApiValidationError? _extractMutationValidationError(
    Map<String, dynamic> error,
  ) {
    final detail = _toNullableString(error['detail']);
    final title = _toNullableString(error['title']);
    final source = error['source'];
    final sourceMap = source is Map<String, dynamic>
        ? source
        : const <String, dynamic>{};
    final pointer = _toNullableString(sourceMap['pointer']);
    final meta = error['meta'];
    final metaMap = meta is Map<String, dynamic>
        ? meta
        : const <String, dynamic>{};
    final attribute = _toNullableString(metaMap['attribute']);
    final relationship = metaMap['relationship'];
    final relationshipMap = relationship is Map<String, dynamic>
        ? relationship
        : const <String, dynamic>{};
    final relationshipAttribute = _toNullableString(
      relationshipMap['attribute'],
    );
    final relationshipName = _toNullableString(relationshipMap['name']);
    final relationshipType = _toNullableString(relationshipMap['type']);
    final relationshipId = _toNullableInt(relationshipMap['id']);
    final relationshipMessage = _toNullableString(relationshipMap['message']);
    final code =
        _toNullableString(relationshipMap['code']) ??
        _toNullableString(metaMap['code']);

    final message = detail ?? relationshipMessage ?? title;
    if (message == null &&
        pointer == null &&
        attribute == null &&
        relationshipAttribute == null &&
        relationshipName == null &&
        relationshipType == null &&
        relationshipId == null) {
      return null;
    }

    return HitobitoApiValidationError(
      message: message ?? 'Validierungsfehler',
      pointer: pointer,
      attribute: attribute,
      relationshipName: relationshipName,
      relationshipAttribute: relationshipAttribute,
      relationshipType: relationshipType,
      relationshipId: relationshipId,
      code: code,
    );
  }

  String? _extractMutationFailureItemDetail(Map<String, dynamic> error) {
    final validationError = _extractMutationValidationError(error);
    final reason = validationError?.message;
    if (reason == null) {
      return null;
    }

    final sourceHint =
        validationError?.relationshipAttribute ??
        validationError?.attribute ??
        validationError?.pointer;
    if (sourceHint == null) {
      return reason;
    }
    return '$reason [$sourceHint]';
  }
}

class _IncludedPeopleResources {
  const _IncludedPeopleResources({
    this.rolesById = const <String, HitobitoPersonRoleResource>{},
    this.rolesByPersonId = const <int, List<HitobitoPersonRoleResource>>{},
    this.phoneNumbersById =
        const <String, _IncludedPersonValue<MitgliedKontaktTelefon>>{},
    this.phoneNumbersByPersonId =
        const <int, List<_IncludedPersonValue<MitgliedKontaktTelefon>>>{},
    this.additionalEmailsById =
        const <String, _IncludedPersonValue<MitgliedKontaktEmail>>{},
    this.additionalEmailsByPersonId =
        const <int, List<_IncludedPersonValue<MitgliedKontaktEmail>>>{},
    this.additionalAddressesById =
        const <String, _IncludedPersonValue<MitgliedKontaktAdresse>>{},
    this.additionalAddressesByPersonId =
        const <int, List<_IncludedPersonValue<MitgliedKontaktAdresse>>>{},
  });

  final Map<String, HitobitoPersonRoleResource> rolesById;
  final Map<int, List<HitobitoPersonRoleResource>> rolesByPersonId;
  final Map<String, _IncludedPersonValue<MitgliedKontaktTelefon>>
  phoneNumbersById;
  final Map<int, List<_IncludedPersonValue<MitgliedKontaktTelefon>>>
  phoneNumbersByPersonId;
  final Map<String, _IncludedPersonValue<MitgliedKontaktEmail>>
  additionalEmailsById;
  final Map<int, List<_IncludedPersonValue<MitgliedKontaktEmail>>>
  additionalEmailsByPersonId;
  final Map<String, _IncludedPersonValue<MitgliedKontaktAdresse>>
  additionalAddressesById;
  final Map<int, List<_IncludedPersonValue<MitgliedKontaktAdresse>>>
  additionalAddressesByPersonId;
}

class _IncludedPersonValue<T> {
  const _IncludedPersonValue({
    required this.id,
    required this.personId,
    required this.value,
  });

  final int id;
  final int personId;
  final T value;
}

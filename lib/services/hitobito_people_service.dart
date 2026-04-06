import 'dart:convert';

import 'package:http/http.dart' as http;

import '../data/arbeitskontext/hitobito_person_resource.dart';
import '../domain/member/mitglied.dart';
import 'hitobito_auth_env.dart';

class HitobitoPeopleException implements Exception {
  const HitobitoPeopleException(this.message);

  final String message;

  @override
  String toString() => message;
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
    queryParameters['fields[roles]'] = 'person_id,group_id,type,label,name';
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
        'Accept': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HitobitoPeopleException(
        'People-Anfrage fehlgeschlagen (${response.statusCode}).',
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

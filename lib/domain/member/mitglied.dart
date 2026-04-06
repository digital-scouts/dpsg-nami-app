import '../taetigkeit/role_derivation.dart';
import '../taetigkeit/roles.dart';
import '../taetigkeit/stufe.dart';

class MitgliedKontaktEmail {
  const MitgliedKontaktEmail({
    required this.wert,
    this.label,
    this.istPrimaer = false,
  }) : assert(wert != '');

  final String wert;
  final String? label;
  final bool istPrimaer;

  MitgliedKontaktEmail copyWith({
    String? wert,
    String? label,
    bool? istPrimaer,
    bool labelLoeschen = false,
  }) => MitgliedKontaktEmail(
    wert: wert ?? this.wert,
    label: labelLoeschen ? null : label ?? this.label,
    istPrimaer: istPrimaer ?? this.istPrimaer,
  );

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'wert': wert,
      'label': label,
      'ist_primaer': istPrimaer,
    };
  }

  factory MitgliedKontaktEmail.fromJson(Map<String, dynamic> json) {
    final wert = json['wert']?.toString().trim() ?? '';
    return MitgliedKontaktEmail(
      wert: wert,
      label: _trimToNull(json['label']?.toString()),
      istPrimaer: json['ist_primaer'] == true,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is MitgliedKontaktEmail &&
        other.wert == wert &&
        other.label == label &&
        other.istPrimaer == istPrimaer;
  }

  @override
  int get hashCode => Object.hash(wert, label, istPrimaer);
}

class MitgliedKontaktTelefon {
  const MitgliedKontaktTelefon({required this.wert, this.label})
    : assert(wert != '');

  final String wert;
  final String? label;

  MitgliedKontaktTelefon copyWith({
    String? wert,
    String? label,
    bool labelLoeschen = false,
  }) => MitgliedKontaktTelefon(
    wert: wert ?? this.wert,
    label: labelLoeschen ? null : label ?? this.label,
  );

  Map<String, dynamic> toJson() {
    return <String, dynamic>{'wert': wert, 'label': label};
  }

  factory MitgliedKontaktTelefon.fromJson(Map<String, dynamic> json) {
    final wert = json['wert']?.toString().trim() ?? '';
    return MitgliedKontaktTelefon(
      wert: wert,
      label: _trimToNull(json['label']?.toString()),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is MitgliedKontaktTelefon &&
        other.wert == wert &&
        other.label == label;
  }

  @override
  int get hashCode => Object.hash(wert, label);
}

class MitgliedKontaktAdresse {
  const MitgliedKontaktAdresse({
    this.additionalAddressId,
    this.label,
    this.addressCareOf,
    this.street,
    this.housenumber,
    this.postbox,
    this.zipCode,
    this.town,
    this.country,
  });

  final int? additionalAddressId;
  final String? label;
  final String? addressCareOf;
  final String? street;
  final String? housenumber;
  final String? postbox;
  final String? zipCode;
  final String? town;
  final String? country;

  bool get istLeer {
    return _trimToNull(addressCareOf) == null &&
        _trimToNull(street) == null &&
        _trimToNull(housenumber) == null &&
        _trimToNull(postbox) == null &&
        _trimToNull(zipCode) == null &&
        _trimToNull(town) == null &&
        _trimToNull(country) == null;
  }

  MitgliedKontaktAdresse copyWith({
    int? additionalAddressId,
    String? label,
    String? addressCareOf,
    String? street,
    String? housenumber,
    String? postbox,
    String? zipCode,
    String? town,
    String? country,
    bool additionalAddressIdLoeschen = false,
    bool labelLoeschen = false,
    bool addressCareOfLoeschen = false,
    bool streetLoeschen = false,
    bool housenumberLoeschen = false,
    bool postboxLoeschen = false,
    bool zipCodeLoeschen = false,
    bool townLoeschen = false,
    bool countryLoeschen = false,
  }) => MitgliedKontaktAdresse(
    additionalAddressId: additionalAddressIdLoeschen
        ? null
        : additionalAddressId ?? this.additionalAddressId,
    label: labelLoeschen ? null : label ?? this.label,
    addressCareOf: addressCareOfLoeschen
        ? null
        : addressCareOf ?? this.addressCareOf,
    street: streetLoeschen ? null : street ?? this.street,
    housenumber: housenumberLoeschen ? null : housenumber ?? this.housenumber,
    postbox: postboxLoeschen ? null : postbox ?? this.postbox,
    zipCode: zipCodeLoeschen ? null : zipCode ?? this.zipCode,
    town: townLoeschen ? null : town ?? this.town,
    country: countryLoeschen ? null : country ?? this.country,
  );

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'additional_address_id': additionalAddressId,
      'label': label,
      'address_care_of': addressCareOf,
      'street': street,
      'housenumber': housenumber,
      'postbox': postbox,
      'zip_code': zipCode,
      'town': town,
      'country': country,
    };
  }

  factory MitgliedKontaktAdresse.fromJson(Map<String, dynamic> json) {
    return MitgliedKontaktAdresse(
      additionalAddressId: _parseInt(json['additional_address_id']),
      label: _trimToNull(json['label']?.toString()),
      addressCareOf: _trimToNull(json['address_care_of']?.toString()),
      street: _trimToNull(json['street']?.toString()),
      housenumber: _trimToNull(json['housenumber']?.toString()),
      postbox: _trimToNull(json['postbox']?.toString()),
      zipCode: _trimToNull(json['zip_code']?.toString()),
      town: _trimToNull(json['town']?.toString()),
      country: _trimToNull(json['country']?.toString()),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is MitgliedKontaktAdresse &&
        other.additionalAddressId == additionalAddressId &&
        other.label == label &&
        other.addressCareOf == addressCareOf &&
        other.street == street &&
        other.housenumber == housenumber &&
        other.postbox == postbox &&
        other.zipCode == zipCode &&
        other.town == town &&
        other.country == country;
  }

  @override
  int get hashCode => Object.hash(
    additionalAddressId,
    label,
    addressCareOf,
    street,
    housenumber,
    postbox,
    zipCode,
    town,
    country,
  );
}

class Mitglied {
  static const String primaryEmailLabel = 'E-Mail';
  static const String secondaryEmailLabel = 'E-Mail Vertretungsberechtigte/r';
  static const String phoneLandlineLabel = 'Festnetznummer';
  static const String phoneMobileLabel = 'Mobilfunknummer';
  static const String phoneBusinessLabel = 'Geschäftlich';
  static final DateTime _peoplePlaceholderDate = DateTime(1900, 1, 1);

  Mitglied({
    required this.vorname,
    required this.nachname,
    this.fahrtenname,
    required this.geburtsdatum,
    required this.eintrittsdatum,
    this.austrittsdatum,
    this.updatedAt,
    this.personId,
    required this.mitgliedsnummer,
    List<MitgliedKontaktTelefon>? telefonnummern,
    List<MitgliedKontaktEmail>? emailAdressen,
    List<MitgliedKontaktAdresse>? adressen,
    this.pronoun,
    this.bankAccountOwner,
    this.iban,
    this.bic,
    this.bankName,
    this.paymentMethod,
    List<Role>? roles,
  }) : assert(mitgliedsnummer.isNotEmpty),
       telefonnummern = List.unmodifiable(
         _normalizeTelefonnummern(telefonnummern ?? const []),
       ),
       emailAdressen = List.unmodifiable(
         _normalizeEmailAdressen(emailAdressen ?? const []),
       ),
       adressen = List.unmodifiable(_normalizeAdressen(adressen ?? const [])),
       roles = List.unmodifiable(roles ?? const []);

  Mitglied.peopleListItem({
    required this.vorname,
    required this.nachname,
    required this.mitgliedsnummer,
    this.fahrtenname,
    this.updatedAt,
    this.personId,
    List<MitgliedKontaktTelefon>? telefonnummern,
    List<MitgliedKontaktEmail>? emailAdressen,
    List<MitgliedKontaktAdresse>? adressen,
    this.pronoun,
    this.bankAccountOwner,
    this.iban,
    this.bic,
    this.bankName,
    this.paymentMethod,
  }) : assert(mitgliedsnummer.isNotEmpty),
       geburtsdatum = _peoplePlaceholderDate,
       eintrittsdatum = _peoplePlaceholderDate,
       austrittsdatum = null,
       telefonnummern = List.unmodifiable(
         _normalizeTelefonnummern(telefonnummern ?? const []),
       ),
       emailAdressen = List.unmodifiable(
         _normalizeEmailAdressen(emailAdressen ?? const []),
       ),
       adressen = List.unmodifiable(_normalizeAdressen(adressen ?? const [])),
       roles = const [];

  final String vorname;
  final String nachname;
  final String? fahrtenname;
  final DateTime geburtsdatum;
  final DateTime eintrittsdatum;
  final DateTime? austrittsdatum;
  final DateTime? updatedAt;
  final int? personId;
  final String mitgliedsnummer;
  final List<MitgliedKontaktTelefon> telefonnummern;
  final List<MitgliedKontaktEmail> emailAdressen;
  final List<MitgliedKontaktAdresse> adressen;
  final String? pronoun;
  final String? bankAccountOwner;
  final String? iban;
  final String? bic;
  final String? bankName;
  final String? paymentMethod;
  final List<Role> roles;

  static DateTime get peoplePlaceholderDate => _peoplePlaceholderDate;

  MitgliedKontaktAdresse? get primaryAddress =>
      adressen.isEmpty ? null : adressen.first;

  String? get primaryAddressCacheKey {
    final address = primaryAddress;
    final currentPersonId = personId;
    if (address == null || currentPersonId == null || currentPersonId <= 0) {
      return null;
    }
    return '$currentPersonId:${address.additionalAddressId ?? 0}';
  }

  String get fullName => '$vorname $nachname'.trim();

  bool get istAusgetreten =>
      austrittsdatum != null && austrittsdatum!.isBefore(DateTime.now());

  Mitglied copyWith({
    String? vorname,
    String? nachname,
    String? fahrtenname,
    DateTime? geburtsdatum,
    DateTime? eintrittsdatum,
    DateTime? austrittsdatum,
    DateTime? updatedAt,
    int? personId,
    String? mitgliedsnummer,
    List<MitgliedKontaktTelefon>? telefonnummern,
    List<MitgliedKontaktEmail>? emailAdressen,
    List<MitgliedKontaktAdresse>? adressen,
    String? pronoun,
    String? bankAccountOwner,
    String? iban,
    String? bic,
    String? bankName,
    String? paymentMethod,
    List<Role>? roles,
    bool fahrtennameLoeschen = false,
    bool austrittsdatumLoeschen = false,
    bool updatedAtLoeschen = false,
    bool personIdLoeschen = false,
    bool pronounLoeschen = false,
    bool bankAccountOwnerLoeschen = false,
    bool ibanLoeschen = false,
    bool bicLoeschen = false,
    bool bankNameLoeschen = false,
    bool paymentMethodLoeschen = false,
  }) => Mitglied(
    vorname: vorname ?? this.vorname,
    nachname: nachname ?? this.nachname,
    fahrtenname: fahrtennameLoeschen ? null : fahrtenname ?? this.fahrtenname,
    geburtsdatum: geburtsdatum ?? this.geburtsdatum,
    eintrittsdatum: eintrittsdatum ?? this.eintrittsdatum,
    austrittsdatum: austrittsdatumLoeschen
        ? null
        : austrittsdatum ?? this.austrittsdatum,
    updatedAt: updatedAtLoeschen ? null : updatedAt ?? this.updatedAt,
    personId: personIdLoeschen ? null : personId ?? this.personId,
    mitgliedsnummer: mitgliedsnummer ?? this.mitgliedsnummer,
    telefonnummern: telefonnummern ?? this.telefonnummern,
    emailAdressen: emailAdressen ?? this.emailAdressen,
    adressen: adressen ?? this.adressen,
    pronoun: pronounLoeschen ? null : pronoun ?? this.pronoun,
    bankAccountOwner: bankAccountOwnerLoeschen
        ? null
        : bankAccountOwner ?? this.bankAccountOwner,
    iban: ibanLoeschen ? null : iban ?? this.iban,
    bic: bicLoeschen ? null : bic ?? this.bic,
    bankName: bankNameLoeschen ? null : bankName ?? this.bankName,
    paymentMethod: paymentMethodLoeschen
        ? null
        : paymentMethod ?? this.paymentMethod,
    roles: roles ?? this.roles,
  );

  Mitglied addRole(Role role) => copyWith(roles: [...roles, role]);

  Map<String, dynamic> toPeopleListJson() {
    return {
      'mitgliedsnummer': mitgliedsnummer,
      'vorname': vorname,
      'nachname': nachname,
      'fahrtenname': fahrtenname,
      'geburtsdatum': geburtsdatum.toIso8601String(),
      'eintrittsdatum': eintrittsdatum.toIso8601String(),
      'austrittsdatum': austrittsdatum?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'person_id': personId,
      'telefonnummern': telefonnummern
          .map((telefonnummer) => telefonnummer.toJson())
          .toList(growable: false),
      'email_adressen': emailAdressen
          .map((emailAdresse) => emailAdresse.toJson())
          .toList(growable: false),
      'adressen': adressen
          .map((adresse) => adresse.toJson())
          .toList(growable: false),
      'roles': roles.map((role) => role.toJson()).toList(growable: false),
      'pronoun': pronoun,
      'bank_account_owner': bankAccountOwner,
      'iban': iban,
      'bic': bic,
      'bank_name': bankName,
      'payment_method': paymentMethod,
    };
  }

  factory Mitglied.fromPeopleListJson(Map<String, dynamic> json) {
    final telefonnummernJson = json['telefonnummern'];
    final telefonnummern = telefonnummernJson is List
        ? telefonnummernJson
              .whereType<Map<String, dynamic>>()
              .map(MitgliedKontaktTelefon.fromJson)
              .toList(growable: false)
        : const <MitgliedKontaktTelefon>[];
    final emailAdressenJson = json['email_adressen'];
    final emailAdressen = emailAdressenJson is List
        ? emailAdressenJson
              .whereType<Map<String, dynamic>>()
              .map(MitgliedKontaktEmail.fromJson)
              .toList(growable: false)
        : const <MitgliedKontaktEmail>[];
    final adressenJson = json['adressen'];
    final adressen = adressenJson is List
        ? adressenJson
              .whereType<Map<String, dynamic>>()
              .map(MitgliedKontaktAdresse.fromJson)
              .where((adresse) => !adresse.istLeer)
              .toList(growable: false)
        : const <MitgliedKontaktAdresse>[];
    final rolesJson = json['roles'] ?? json['taetigkeiten'];
    final roles = rolesJson is List
        ? rolesJson
              .whereType<Map<String, dynamic>>()
              .map(Role.fromJson)
              .toList(growable: false)
        : const <Role>[];

    return Mitglied(
      mitgliedsnummer: json['mitgliedsnummer']?.toString() ?? '',
      vorname: json['vorname']?.toString() ?? '',
      nachname: json['nachname']?.toString() ?? '',
      fahrtenname: _trimToNull(json['fahrtenname']?.toString()),
      geburtsdatum:
          _parseDateTime(json['geburtsdatum']) ?? peoplePlaceholderDate,
      eintrittsdatum:
          _parseDateTime(json['eintrittsdatum']) ?? peoplePlaceholderDate,
      austrittsdatum: _parseDateTime(json['austrittsdatum']),
      updatedAt: _parseDateTime(json['updated_at']),
      personId: _parseInt(json['person_id']),
      telefonnummern: telefonnummern,
      emailAdressen: emailAdressen,
      adressen: adressen,
      roles: roles,
      pronoun: _trimToNull(json['pronoun']?.toString()),
      bankAccountOwner: _trimToNull(json['bank_account_owner']?.toString()),
      iban: _trimToNull(json['iban']?.toString()),
      bic: _trimToNull(json['bic']?.toString()),
      bankName: _trimToNull(json['bank_name']?.toString()),
      paymentMethod: _trimToNull(json['payment_method']?.toString()),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is Mitglied &&
        other.vorname == vorname &&
        other.nachname == nachname &&
        other.fahrtenname == fahrtenname &&
        other.geburtsdatum == geburtsdatum &&
        other.eintrittsdatum == eintrittsdatum &&
        other.austrittsdatum == austrittsdatum &&
        other.updatedAt == updatedAt &&
        other.personId == personId &&
        other.mitgliedsnummer == mitgliedsnummer &&
        other.pronoun == pronoun &&
        other.bankAccountOwner == bankAccountOwner &&
        other.iban == iban &&
        other.bic == bic &&
        other.bankName == bankName &&
        other.paymentMethod == paymentMethod &&
        _listEquals(other.telefonnummern, telefonnummern) &&
        _listEquals(other.emailAdressen, emailAdressen) &&
        _listEquals(other.adressen, adressen) &&
        _listEquals(other.roles, roles);
  }

  @override
  int get hashCode => Object.hash(
    vorname,
    nachname,
    fahrtenname,
    geburtsdatum,
    eintrittsdatum,
    austrittsdatum,
    updatedAt,
    personId,
    mitgliedsnummer,
    pronoun,
    bankAccountOwner,
    iban,
    bic,
    bankName,
    paymentMethod,
    Object.hashAll(telefonnummern),
    Object.hashAll(emailAdressen),
    Object.hashAll(adressen),
    Object.hashAll(roles),
  );

  @override
  String toString() {
    final buffer = StringBuffer('Mitglied(');
    buffer.write('mitgliedsnummer: $mitgliedsnummer, ');
    buffer.write('vorname: $vorname, ');
    buffer.write('nachname: $nachname');
    if (fahrtenname != null) {
      buffer.write(', fahrtenname: $fahrtenname');
    }
    buffer.write(
      ', geburtsdatum: ${geburtsdatum.toIso8601String().split('T')[0]}',
    );
    buffer.write(
      ', eintrittsdatum: ${eintrittsdatum.toIso8601String().split('T')[0]}',
    );
    if (austrittsdatum != null) {
      buffer.write(
        ', austrittsdatum: ${austrittsdatum!.toIso8601String().split('T')[0]}',
      );
    }
    if (updatedAt != null) {
      buffer.write(', updatedAt: ${updatedAt!.toIso8601String()}');
    }
    if (personId != null) {
      buffer.write(', personId: $personId');
    }
    if (emailAdressen.isNotEmpty) {
      buffer.write(', emailAdressen: $emailAdressen');
    }
    if (telefonnummern.isNotEmpty) {
      buffer.write(', telefonnummern: $telefonnummern');
    }
    if (adressen.isNotEmpty) {
      buffer.write(', adressen: $adressen');
    }
    if (pronoun != null) {
      buffer.write(', pronoun: $pronoun');
    }
    if (roles.isNotEmpty) {
      buffer.write(', roles: [');
      for (var i = 0; i < roles.length; i++) {
        if (i > 0) buffer.write(', ');
        buffer.write(roles[i].toString());
      }
      buffer.write(']');
    }
    buffer.write(')');
    return buffer.toString();
  }

  static bool _listEquals<T>(List<T> a, List<T> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static List<MitgliedKontaktEmail> _normalizeEmailAdressen(
    List<MitgliedKontaktEmail> emailAdressen,
  ) {
    final result = <MitgliedKontaktEmail>[];
    final seen = <String>{};

    for (final emailAdresse in emailAdressen) {
      final wert = _trimToNull(emailAdresse.wert);
      if (wert == null) {
        continue;
      }

      final normalized = emailAdresse.copyWith(
        wert: wert,
        label: _trimToNull(emailAdresse.label),
      );
      final key =
          '${wert.toLowerCase()}|${normalized.label ?? ''}|${normalized.istPrimaer}';
      if (!seen.add(key)) {
        continue;
      }
      result.add(normalized);
    }

    return result;
  }

  static List<MitgliedKontaktTelefon> _normalizeTelefonnummern(
    List<MitgliedKontaktTelefon> telefonnummern,
  ) {
    final result = <MitgliedKontaktTelefon>[];
    final seen = <String>{};

    for (final telefonnummer in telefonnummern) {
      final wert = _trimToNull(telefonnummer.wert);
      if (wert == null) {
        continue;
      }

      final normalized = telefonnummer.copyWith(
        wert: wert,
        label: _trimToNull(telefonnummer.label),
      );
      final key = '${wert.toLowerCase()}|${normalized.label ?? ''}';
      if (!seen.add(key)) {
        continue;
      }
      result.add(normalized);
    }

    return result;
  }

  static List<MitgliedKontaktAdresse> _normalizeAdressen(
    List<MitgliedKontaktAdresse> adressen,
  ) {
    final result = <MitgliedKontaktAdresse>[];
    final seen = <String>{};

    for (final adresse in adressen) {
      if (adresse.istLeer) {
        continue;
      }

      final normalized = adresse.copyWith(
        additionalAddressId: adresse.additionalAddressId,
        label: _trimToNull(adresse.label),
        addressCareOf: _trimToNull(adresse.addressCareOf),
        street: _trimToNull(adresse.street),
        housenumber: _trimToNull(adresse.housenumber),
        postbox: _trimToNull(adresse.postbox),
        zipCode: _trimToNull(adresse.zipCode),
        town: _trimToNull(adresse.town),
        country: _trimToNull(adresse.country),
      );
      final key = [
        normalized.additionalAddressId?.toString() ?? '',
        normalized.label ?? '',
        normalized.addressCareOf ?? '',
        normalized.street ?? '',
        normalized.housenumber ?? '',
        normalized.postbox ?? '',
        normalized.zipCode ?? '',
        normalized.town ?? '',
        normalized.country ?? '',
      ].join('|');
      if (!seen.add(key)) {
        continue;
      }
      result.add(normalized);
    }

    return result;
  }
}

String? _trimToNull(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  return trimmed;
}

DateTime? _parseDateTime(Object? value) {
  final raw = _trimToNull(value?.toString());
  if (raw == null) {
    return null;
  }
  return DateTime.tryParse(raw);
}

int? _parseInt(Object? value) {
  final raw = _trimToNull(value?.toString());
  if (raw == null) {
    return null;
  }
  return int.tryParse(raw);
}

class MitgliedFactory {
  static Mitglied demo({int index = 1}) {
    final now = DateTime.now();
    final ageYears = 12 + (index % 17);
    final birthMonth = 1 + (index % 12);
    final birthDay = 1 + (index % 28);
    final geburtsdatum = DateTime(now.year - ageYears, birthMonth, birthDay);

    final membershipYears = 1 + (index % 10);
    final eintrittsdatum = DateTime(
      now.year - membershipYears,
      (birthMonth % 12) + 1,
      (birthDay % 27) + 1,
    );

    const fahrtenNamen = [
      'Falke',
      'Luchs',
      'Bergwolf',
      'Rotfuchs',
      'Habicht',
      'Milan',
      'Dachs',
      'Iltis',
      'Marder',
      'Wiesel',
      'Eisvogel',
      'Fjord',
    ];
    final fahrtenname = index % 2 == 0
        ? fahrtenNamen[index % fahrtenNamen.length]
        : null;

    final telMobil =
        '+49 17${(10 + index % 80).toString().padLeft(2, '0')} ${900000 + index}';
    final telFestnetz = index % 2 == 0 ? '+49 30 ${400000 + index}' : null;
    final telBusiness = index % 5 == 0 ? '+49 221 ${500000 + index}' : null;

    final primaryEmail = 'mitglied$index@example.org';
    final secondaryEmail = index % 4 == 0
        ? '${fahrtenname?.toLowerCase() ?? 'alias'}$index@scoutmail.de'
        : null;

    return Mitglied(
      vorname: 'Max',
      nachname: 'Mustermann$index',
      fahrtenname: fahrtenname,
      geburtsdatum: geburtsdatum,
      eintrittsdatum: eintrittsdatum,
      mitgliedsnummer: 'M-${DateTime.now().millisecondsSinceEpoch}-$index',
      telefonnummern: <MitgliedKontaktTelefon>[
        if (telFestnetz != null)
          MitgliedKontaktTelefon(
            wert: telFestnetz,
            label: Mitglied.phoneLandlineLabel,
          ),
        MitgliedKontaktTelefon(
          wert: telMobil,
          label: Mitglied.phoneMobileLabel,
        ),
        if (telBusiness != null)
          MitgliedKontaktTelefon(
            wert: telBusiness,
            label: Mitglied.phoneBusinessLabel,
          ),
      ],
      emailAdressen: <MitgliedKontaktEmail>[
        MitgliedKontaktEmail(
          wert: primaryEmail,
          label: Mitglied.primaryEmailLabel,
          istPrimaer: true,
        ),
        if (secondaryEmail != null)
          MitgliedKontaktEmail(
            wert: secondaryEmail,
            label: Mitglied.secondaryEmailLabel,
          ),
      ],
      roles: [
        roleFromLegacy(
          stufe: switch (index % 5) {
            0 => Stufe.woelfling,
            1 => Stufe.jungpfadfinder,
            2 => Stufe.pfadfinder,
            3 => Stufe.rover,
            _ => Stufe.pfadfinder,
          },
          art: RoleCategory.mitglied,
          start: eintrittsdatum,
        ),
        if (index % 6 == 0)
          roleFromLegacy(
            stufe: Stufe.rover,
            art: RoleCategory.leitung,
            start: DateTime(
              eintrittsdatum.year + 2,
              eintrittsdatum.month,
              eintrittsdatum.day,
            ),
          ),
      ],
    );
  }
}

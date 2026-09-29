/// Kategorien fuer Kontakteintraege einer Person (Hitobito
/// `ContactAccountCategory`).
///
/// Hitobito verlangt seit hitobito#4359 fuer jede Telefonnummer, Zusatzmail
/// und Zusatzadresse eine Kategorie. Die JSON:API liefert davon nur die
/// instanzabhaengige `category_id`. Stabil sind die Keys, die der DPSG-Wagon
/// in hitobito_pfadi_de#102 festlegt. Die Zuordnung Key zu ID kommt deshalb
/// aus der Konfiguration, siehe [ContactCategoryCatalog.parse].
enum ContactAccountType {
  phoneNumber('phone_number'),
  additionalEmail('additional_email'),
  additionalAddress('additional_address');

  const ContactAccountType(this.configName);

  /// Praefix in der Konfiguration, etwa `phone_number.mobile=12`.
  final String configName;
}

class ContactCategoryDefinition {
  const ContactCategoryDefinition({
    required this.type,
    required this.key,
    required this.name,
    required this.uniquePerContactable,
  });

  final ContactAccountType type;
  final String key;
  final String name;

  /// Darf pro Person hoechstens einmal vorkommen.
  final bool uniquePerContactable;
}

class ContactCategory {
  const ContactCategory({required this.id, required this.definition});

  final int id;
  final ContactCategoryDefinition definition;

  ContactAccountType get type => definition.type;
  String get key => definition.key;
  String get name => definition.name;
  bool get uniquePerContactable => definition.uniquePerContactable;
}

class ContactCategoryCatalog {
  const ContactCategoryCatalog._(this._categories);

  const ContactCategoryCatalog.empty()
    : _categories = const <ContactCategory>[];

  static const String otherKey = 'other';

  /// Personen-Kategorien des DPSG-Wagons in Hitobito-Reihenfolge.
  static const List<ContactCategoryDefinition> definitions =
      <ContactCategoryDefinition>[
        ContactCategoryDefinition(
          type: ContactAccountType.phoneNumber,
          key: 'private',
          name: 'Privat',
          uniquePerContactable: true,
        ),
        ContactCategoryDefinition(
          type: ContactAccountType.phoneNumber,
          key: 'mobile',
          name: 'Mobil',
          uniquePerContactable: true,
        ),
        ContactCategoryDefinition(
          type: ContactAccountType.phoneNumber,
          key: 'work',
          name: 'Arbeit',
          uniquePerContactable: true,
        ),
        ContactCategoryDefinition(
          type: ContactAccountType.phoneNumber,
          key: 'guardians',
          name: 'Erziehungsberechtigte',
          uniquePerContactable: true,
        ),
        ContactCategoryDefinition(
          type: ContactAccountType.phoneNumber,
          key: 'father',
          name: 'Vater',
          uniquePerContactable: true,
        ),
        ContactCategoryDefinition(
          type: ContactAccountType.phoneNumber,
          key: 'mother',
          name: 'Mutter',
          uniquePerContactable: true,
        ),
        ContactCategoryDefinition(
          type: ContactAccountType.phoneNumber,
          key: otherKey,
          name: 'Andere',
          uniquePerContactable: false,
        ),
        ContactCategoryDefinition(
          type: ContactAccountType.additionalEmail,
          key: 'guardians',
          name: 'Erziehungsberechtigte',
          uniquePerContactable: true,
        ),
        ContactCategoryDefinition(
          type: ContactAccountType.additionalEmail,
          key: 'father',
          name: 'Vater',
          uniquePerContactable: true,
        ),
        ContactCategoryDefinition(
          type: ContactAccountType.additionalEmail,
          key: 'mother',
          name: 'Mutter',
          uniquePerContactable: true,
        ),
        ContactCategoryDefinition(
          type: ContactAccountType.additionalEmail,
          key: otherKey,
          name: 'Andere',
          uniquePerContactable: false,
        ),
        ContactCategoryDefinition(
          type: ContactAccountType.additionalAddress,
          key: 'parents_guardians',
          name: 'Abweichende Adresse Eltern/Erziehungsberechtigte',
          uniquePerContactable: true,
        ),
        ContactCategoryDefinition(
          type: ContactAccountType.additionalAddress,
          key: 'secondary_address',
          name: 'Zweitanschrift',
          uniquePerContactable: true,
        ),
        ContactCategoryDefinition(
          type: ContactAccountType.additionalAddress,
          key: otherKey,
          name: 'Andere',
          uniquePerContactable: false,
        ),
      ];

  final List<ContactCategory> _categories;

  /// Liest eine Zuordnung wie `phone_number.mobile=12,phone_number.other=17`.
  ///
  /// Unbekannte Typen oder Keys, ungueltige IDs und doppelt vergebene IDs
  /// werden verworfen, damit nie eine falsche Kategorie gesendet wird.
  factory ContactCategoryCatalog.parse(String? raw) {
    final idsByDefinition = <ContactCategoryDefinition, int>{};
    final seenIds = <ContactAccountType, Map<int, int>>{};
    for (final entry in (raw ?? '').split(',')) {
      final separator = entry.indexOf('=');
      if (separator <= 0) {
        continue;
      }
      final name = entry.substring(0, separator).trim();
      final id = int.tryParse(entry.substring(separator + 1).trim());
      final dot = name.indexOf('.');
      if (id == null || id <= 0 || dot <= 0) {
        continue;
      }
      final typeName = name.substring(0, dot);
      final key = name.substring(dot + 1);
      final definition = definitions
          .where(
            (candidate) =>
                candidate.type.configName == typeName && candidate.key == key,
          )
          .firstOrNull;
      if (definition == null) {
        continue;
      }
      idsByDefinition[definition] = id;
      final counts = seenIds.putIfAbsent(definition.type, () => <int, int>{});
      counts[id] = (counts[id] ?? 0) + 1;
    }

    final categories = <ContactCategory>[
      for (final definition in definitions)
        if (idsByDefinition[definition] case final id?)
          if ((seenIds[definition.type]?[id] ?? 0) == 1)
            ContactCategory(id: id, definition: definition),
    ];
    return ContactCategoryCatalog._(List.unmodifiable(categories));
  }

  List<ContactCategory> forType(ContactAccountType type) => _categories
      .where((category) => category.type == type)
      .toList(growable: false);

  /// Neue Eintraege sind nur moeglich, wenn fuer den Typ Kategorien bekannt
  /// sind; ohne Kategorie lehnt Hitobito die Anlage ab.
  bool supports(ContactAccountType type) =>
      _categories.any((category) => category.type == type);

  ContactCategory? byId(ContactAccountType type, int? id) {
    if (id == null) {
      return null;
    }
    for (final category in _categories) {
      if (category.type == type && category.id == id) {
        return category;
      }
    }
    return null;
  }

  /// Anzeigetext fuer einen Kontakteintrag: Kategoriename und optionaler
  /// Freitext-Zusatz, etwa `Andere, Oma`. Unbekannte Kategorien fallen weg.
  String? displayLabel(
    ContactAccountType type,
    int? categoryId,
    String? label,
  ) {
    final parts = <String>[
      ?byId(type, categoryId)?.name,
      if (label?.trim() case final trimmed? when trimmed.isNotEmpty) trimmed,
    ];
    return parts.isEmpty ? null : parts.join(', ');
  }

  ContactCategory? other(ContactAccountType type) {
    for (final category in _categories) {
      if (category.type == type && category.key == otherKey) {
        return category;
      }
    }
    return null;
  }
}

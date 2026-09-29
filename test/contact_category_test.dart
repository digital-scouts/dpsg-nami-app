import 'package:flutter_test/flutter_test.dart';
import 'package:nami/domain/member/contact_category.dart';

void main() {
  test('liest die Key-ID-Zuordnung je Kontaktart', () {
    final catalog = ContactCategoryCatalog.parse(
      ' phone_number.mobile = 12 , phone_number.other=17,'
      'additional_email.guardians=21,additional_address.other=33',
    );

    expect(
      catalog
          .forType(ContactAccountType.phoneNumber)
          .map((category) => '${category.key}:${category.id}'),
      <String>['mobile:12', 'other:17'],
    );
    expect(catalog.byId(ContactAccountType.phoneNumber, 12)?.name, 'Mobil');
    expect(catalog.byId(ContactAccountType.additionalEmail, 12), isNull);
    expect(catalog.other(ContactAccountType.additionalAddress)?.id, 33);
    expect(catalog.supports(ContactAccountType.additionalEmail), isTrue);
    expect(
      catalog.byId(ContactAccountType.phoneNumber, 12)?.uniquePerContactable,
      isTrue,
    );
    expect(
      catalog.byId(ContactAccountType.phoneNumber, 17)?.uniquePerContactable,
      isFalse,
    );
  });

  test('verwirft unbekannte Keys, ungueltige und doppelte IDs', () {
    final catalog = ContactCategoryCatalog.parse(
      'phone_number.fax=3,phone_number.mobile=abc,phone_number.work=-1,'
      'social_account.other=9,phone_number.private=5,phone_number.father=5,'
      'additional_email.other=5,kaputt,=7',
    );

    // private und father teilen sich die 5 und werden beide verworfen; fuer
    // eine andere Kontaktart darf dieselbe ID vorkommen.
    expect(catalog.supports(ContactAccountType.phoneNumber), isFalse);
    expect(catalog.byId(ContactAccountType.additionalEmail, 5)?.key, 'other');
    expect(catalog.supports(ContactAccountType.additionalAddress), isFalse);
  });

  test('baut Anzeigetext aus Kategorie und Zusatz', () {
    final catalog = ContactCategoryCatalog.parse(
      'phone_number.mobile=12,phone_number.other=17',
    );

    expect(
      catalog.displayLabel(ContactAccountType.phoneNumber, 12, null),
      'Mobil',
    );
    expect(
      catalog.displayLabel(ContactAccountType.phoneNumber, 17, ' Oma '),
      'Andere, Oma',
    );
    expect(
      catalog.displayLabel(ContactAccountType.phoneNumber, 99, 'Alt'),
      'Alt',
    );
    expect(
      catalog.displayLabel(ContactAccountType.phoneNumber, null, ''),
      isNull,
    );
  });

  test('ist ohne Konfiguration leer', () {
    for (final raw in <String?>[null, '', '   ']) {
      final catalog = ContactCategoryCatalog.parse(raw);
      for (final type in ContactAccountType.values) {
        expect(catalog.supports(type), isFalse);
        expect(catalog.forType(type), isEmpty);
      }
    }
  });
}

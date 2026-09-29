import 'package:flutter_test/flutter_test.dart';
import 'package:nami/presentation/model/member_bank_input.dart';

void main() {
  group('IBAN', () {
    test('akzeptiert gueltige IBANs mit und ohne Leerzeichen', () {
      for (final iban in <String>[
        'DE89370400440532013000',
        'de89 3704 0044 0532 0130 00',
        'AT611904300234573201',
        'CH9300762011623852957',
        'NL91ABNA0417164300',
      ]) {
        expect(MemberBankInput.isValidIban(iban), isTrue, reason: iban);
      }
    });

    test('akzeptiert eine leere IBAN', () {
      expect(MemberBankInput.isValidIban(null), isTrue);
      expect(MemberBankInput.isValidIban('  '), isTrue);
    });

    test('lehnt falsche Pruefziffer, Laenge und Zeichen ab', () {
      for (final iban in <String>[
        'DE88370400440532013000',
        'DE8937040044053201300',
        'DE89 3704 0044 0532 0130 00 1',
        'DE89-3704-0044-0532-0130-00',
        '1234',
      ]) {
        expect(MemberBankInput.isValidIban(iban), isFalse, reason: iban);
      }
    });

    test('normalisiert auf Grossbuchstaben ohne Leerzeichen', () {
      expect(
        MemberBankInput.normalizeIban(' de89 3704 0044 0532 0130 00 '),
        'DE89370400440532013000',
      );
      expect(MemberBankInput.normalizeIban(' '), isNull);
    });
  });

  group('BIC', () {
    test('akzeptiert BICs mit 8 und 11 Zeichen', () {
      expect(MemberBankInput.isValidBic('COBADEFF'), isTrue);
      expect(MemberBankInput.isValidBic('byla dem 1001'), isTrue);
      expect(MemberBankInput.isValidBic(null), isTrue);
    });

    test('lehnt andere Laengen und Formate ab', () {
      expect(MemberBankInput.isValidBic('COBADE'), isFalse);
      expect(MemberBankInput.isValidBic('COBADEFF1'), isFalse);
      expect(MemberBankInput.isValidBic('1OBADEFF'), isFalse);
    });
  });
}

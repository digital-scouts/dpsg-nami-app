import 'package:flutter_test/flutter_test.dart';
import 'package:nami/domain/member/member_phone_input.dart';

void main() {
  test('zerlegt bekannte europaeische Vorwahlen', () {
    final result = MemberPhoneInput.split('+352621123456');

    expect(result.countryId, 'lu');
    expect(result.localNumber, '621123456');
  });

  test('ordnet unbekannte Vorwahlen Sonstige zu', () {
    final result = MemberPhoneInput.split('+12125550123');

    expect(result.countryId, MemberPhoneInput.otherCountryId);
    expect(result.localNumber, '+12125550123');
  });

  test('normalisiert bekannte Vorwahl und lokalen Teil zu einer Nummer', () {
    final value = MemberPhoneInput.compose(
      countryId: 'de',
      localNumber: '170 123 45 67',
    );

    expect(value, '+491701234567');
  });

  test('normalisiert internationale Eingaben mit 00-Praefix', () {
    final value = MemberPhoneInput.compose(
      countryId: 'de',
      localNumber: '0049 170 123 45 67',
    );

    expect(value, '+491701234567');
  });

  test('akzeptiert Sonstige nur mit internationalem Plus-Praefix', () {
    final error = MemberPhoneInput.validate(
      countryId: MemberPhoneInput.otherCountryId,
      localNumber: '2125550123',
      required: true,
    );

    expect(
      error,
      'Bitte bei Sonstige die vollständige Telefonnummer mit +XX angeben.',
    );
  });

  test('akzeptiert Sonstige auch mit 00-Praefix', () {
    final error = MemberPhoneInput.validate(
      countryId: MemberPhoneInput.otherCountryId,
      localNumber: '00412125550123',
      required: true,
    );

    expect(error, isNull);
  });

  test('lehnt zu kurze Telefonnummern ab', () {
    final error = MemberPhoneInput.validate(
      countryId: 'de',
      localNumber: '123',
      required: true,
    );

    expect(error, 'Bitte eine gültige Telefonnummer eingeben.');
  });

  test('lehnt zu lange Telefonnummern ab', () {
    final error = MemberPhoneInput.validate(
      countryId: MemberPhoneInput.otherCountryId,
      localNumber: '+1234567890123456',
      required: true,
    );

    expect(error, 'Bitte eine gültige Telefonnummer eingeben.');
  });

  group('Verkehrsausscheidungsziffer und nationale Laenge', () {
    test('entfernt die fuehrende 0 einer nationalen Eingabe', () {
      expect(
        MemberPhoneInput.compose(countryId: 'de', localNumber: '0170 1234567'),
        '+491701234567',
      );
      expect(
        MemberPhoneInput.compose(countryId: 'ch', localNumber: '044 123 45 67'),
        '+41441234567',
      );
    });

    test('entfernt (0) und 0 nach der Laendervorwahl', () {
      expect(
        MemberPhoneInput.normalizeInternational('+49 (0) 170 1234567'),
        '+491701234567',
      );
      expect(
        MemberPhoneInput.normalizeInternational('+49 01701234567'),
        '+491701234567',
      );
      expect(
        MemberPhoneInput.normalizeInternational('0049 (03160) 0214700'),
        '+4931600214700',
      );
    });

    test('laesst die 0 in Laendern ohne Verkehrsausscheidungsziffer', () {
      expect(
        MemberPhoneInput.compose(countryId: 'dk', localNumber: '01234567'),
        '+4501234567',
      );
    });

    test('zerlegt Hitobito-Formate ohne fuehrende 0', () {
      final result = MemberPhoneInput.split('+49 (03160) 0214700');

      expect(result.countryId, 'de');
      expect(result.localNumber, '31600214700');
    });

    test('zaehlt die Mindestlaenge ohne Laendervorwahl', () {
      String? validateDe(String value) => MemberPhoneInput.validate(
        countryId: 'de',
        localNumber: value,
        required: true,
      );

      expect(validateDe('1111'), 'Bitte eine gültige Telefonnummer eingeben.');
      expect(validateDe('01111'), 'Bitte eine gültige Telefonnummer eingeben.');
      expect(
        validateDe('+49 1111'),
        'Bitte eine gültige Telefonnummer eingeben.',
      );
      expect(validateDe('030 1234'), isNull);
      expect(validateDe('0170 1234567'), isNull);
    });

    test('nutzt die Mindestlaenge des Landes', () {
      expect(
        MemberPhoneInput.validate(countryId: 'ch', localNumber: '044 123 45'),
        'Bitte eine gültige Telefonnummer eingeben.',
      );
      expect(
        MemberPhoneInput.validate(countryId: 'lu', localNumber: '1234'),
        isNull,
      );
    });

    test('erkennt dieselbe Nummer trotz anderer Formatierung', () {
      expect(
        MemberPhoneInput.isSameNumber('+49 675-4747883', '+496754747883'),
        isTrue,
      );
      expect(
        MemberPhoneInput.isSameNumber('+49 (0170) 1234567', '+491701234567'),
        isTrue,
      );
      expect(
        MemberPhoneInput.isSameNumber('+49 170 1234567', '+49 170 1234568'),
        isFalse,
      );
    });
  });
}

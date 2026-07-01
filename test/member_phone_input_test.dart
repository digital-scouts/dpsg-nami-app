import 'package:flutter_test/flutter_test.dart';
import 'package:nami/presentation/model/member_phone_input.dart';

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
}

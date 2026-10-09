import 'package:flutter_test/flutter_test.dart';
import 'package:nami/services/log_sanitizer.dart';

void main() {
  test('maskiert E-Mail, Telefon, IBAN und Tokens', () {
    final text = LogSanitizer.text(
      'detail="julia.keller@example.org ist vergeben" tel=0170 1234567 '
      'alt=+49 170 1234567 iban=DE89 3704 0044 0532 0130 00 '
      'Authorization: Bearer abc.def.ghi url=/oauth?code=xyz&state=1',
    );

    expect(text, isNot(contains('julia.keller')));
    expect(text, isNot(contains('1234567')));
    expect(text, isNot(contains('0532')));
    expect(text, isNot(contains('abc.def.ghi')));
    expect(text, isNot(contains('xyz')));
    expect(text, contains('<email>'));
    expect(text, contains('<telefon>'));
    expect(text, contains('<iban>'));
    expect(text, contains('Bearer <token>'));
    expect(text, contains('code=<token>&state=1'));
  });

  test('laesst Datum, Uhrzeit, IDs und Zaehler stehen', () {
    const text =
        'updated_at=2026-04-14T09:00:00Z person_id=12345678 layer=11 '
        'dauer=1234ms status=422';

    expect(LogSanitizer.text(text), text);
  });

  test('kuerzt auf die Hoechstlaenge', () {
    expect(LogSanitizer.text('a' * 50, maxLength: 10), 'aaaaaaa...');
  });

  test('fehler nennt Typ und bereinigte erste Zeile', () {
    final fehler = LogSanitizer.fehler(
      StateError('Mail an lena@example.org fehlgeschlagen\nZweite Zeile'),
    );

    expect(fehler, startsWith('StateError: '));
    expect(fehler, contains('<email>'));
    expect(fehler, isNot(contains('Zweite Zeile')));
  });
}

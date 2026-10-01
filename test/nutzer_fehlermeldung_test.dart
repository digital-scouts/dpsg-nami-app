import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:nami/presentation/model/nutzer_fehlermeldung.dart';
import 'package:nami/services/hitobito_groups_service.dart';
import 'package:nami/services/hitobito_oauth_service.dart';
import 'package:nami/services/hitobito_people_service.dart';

void main() {
  group('nutzerFehlermeldung', () {
    test('defekte Gruppe: Hinweis auf die Suche, keine Serverantwort', () {
      final meldung = nutzerFehlermeldung(
        const HitobitoGroupsException(
          'Groups-Anfrage fehlgeschlagen (400). Grund: Failed typecasting '
          ':zip_code! /app-src/vendor/bundle/ruby',
          statusCode: 400,
        ),
      );
      expect(meldung, contains('Fehler 400'));
      expect(meldung, contains('Fehlerhafte Gruppe suchen'));
      expect(meldung, isNot(contains('zip_code')));
      expect(meldung, isNot(contains('/app-src/')));
    });

    test('Statuscodes werden zu verständlichen Meldungen', () {
      expect(
        nutzerFehlermeldung(
          const HitobitoPeopleException('People (403)', statusCode: 403),
        ),
        contains('Zugriff verweigert'),
      );
      expect(
        nutzerFehlermeldung(
          const HitobitoPeopleException('People (502)', statusCode: 502),
        ),
        contains('Serverfehler'),
      );
      final abgelehnt = nutzerFehlermeldung(
        const HitobitoPeopleException('People (422)', statusCode: 422),
      );
      expect(abgelehnt, contains('Fehler 422'));
      expect(abgelehnt, contains('Debug & Tools'));
    });

    test('Netzfehler melden fehlende Verbindung', () {
      for (final fehler in [
        const SocketException('Failed host lookup'),
        TimeoutException('zu langsam'),
        http.ClientException('Connection closed'),
      ]) {
        expect(
          nutzerFehlermeldung(fehler),
          contains('nicht erreichbar'),
          reason: '$fehler',
        );
      }
    });

    test('eigene Texte der Anmeldung bleiben', () {
      expect(
        nutzerFehlermeldung(
          const HitobitoAuthException(
            'Die Hitobito-Anmeldung wurde abgebrochen.',
          ),
        ),
        'Die Hitobito-Anmeldung wurde abgebrochen.',
      );
    });

    test('Unbekanntes zeigt keinen Ausnahmetext', () {
      final meldung = nutzerFehlermeldung(
        StateError('Bad state: interner Zustand'),
      );
      expect(meldung, isNot(contains('Bad state')));
      expect(meldung, contains('Debug & Tools'));
    });
  });
}

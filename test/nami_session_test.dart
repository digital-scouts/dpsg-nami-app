import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:logger/logger.dart';
import 'package:nami/utilities/app.state.dart';
import 'package:nami/utilities/hive/data_changes.dart';
import 'package:nami/utilities/hive/settings_service.dart';
import 'package:nami/utilities/logger.dart' as logger_utils;
import 'package:nami/utilities/nami/nami.service.dart';
import 'package:nami/utilities/nami/nami_login.service.dart';
import 'package:nami/utilities/nami/nami_member_add.service.dart';
import 'package:nami/utilities/nami/model/nami_member_details.model.dart';
import 'package:nami/utilities/types.dart';

class _SilentOutput extends LogOutput {
  @override
  void output(OutputEvent event) {}
}

/// Zugangsdaten des Demo-Logins, der ohne Netzwerk funktioniert
const demoLoginId = 1234;
const demoPassword = 'test';

http.Response jsonResponse(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

final loginPage = http.Response(
  '<html><body>Login</body></html>',
  200,
  headers: {'content-type': 'text/html'},
);

void main() {
  late Directory hiveDir;

  setUpAll(() async {
    logger_utils.sensLog = Logger(output: _SilentOutput());
    hiveDir = await Directory.systemTemp.createTemp('nami_session_test');
    Hive.init(hiveDir.path);
    settingsService = HiveSettingsService(await Hive.openBox('settingsBox'));
    // für den AppStateHandler
    Hive.registerAdapter(DataChangeAdapter());
    await Hive.openBox<DataChange>('dataChanges');
    logger_utils.salt = 1;
  });

  tearDownAll(() async {
    await Hive.close();
    await hiveDir.delete(recursive: true);
  });

  setUp(() async {
    await settingsBox.clear();
    setNamiApiCookie('oldCookie');
  });

  group('isNamiSessionExpired', () {
    test('erkennt Session-Ende an Nachricht, 500 und Login-Seite', () {
      final expired = jsonResponse({
        'success': false,
        'message': 'Session expired',
      });
      expect(isNamiSessionExpired(expired, tryDecodeNamiBody(expired)), true);

      final serverExpired = http.Response('Session expired', 500);
      expect(isNamiSessionExpired(serverExpired, null), true);

      expect(isNamiSessionExpired(loginPage, null), true);
    });

    test('normale Serverfehler gelten nicht als Session-Ende', () {
      final error = jsonResponse({
        'success': false,
        'message': 'Validierung fehlgeschlagen',
      }, 500);
      expect(isNamiSessionExpired(error, tryDecodeNamiBody(error)), false);
    });
  });

  group('withMaybeRetry', () {
    test('meldet sich mit gespeichertem Passwort still neu an', () async {
      setNamiLoginId(demoLoginId);
      setNamiPassword(demoPassword);
      final usedCookies = <String?>[];

      final body = await http.runWithClient(
        () => withMaybeRetry(
          () => http.get(
            Uri.parse('https://nami.test/api'),
            headers: {'Cookie': getNamiApiCookie()},
          ),
        ),
        () => MockClient((request) async {
          usedCookies.add(request.headers['Cookie']);
          return usedCookies.length == 1
              ? loginPage
              : jsonResponse({'success': true, 'data': 42});
        }),
      );

      expect(body['data'], 42);
      expect(usedCookies, ['oldCookie', 'testLoginCookie']);
      expect(
        DateTime.now().difference(getLastLoginCheck()).inMinutes,
        lessThan(1),
      );
    });

    test('wirft SessionExpiredException ohne gespeichertes Passwort', () {
      setNamiLoginId(demoLoginId);

      expect(
        http.runWithClient(
          () => withMaybeRetry(
            () => http.get(Uri.parse('https://nami.test/api')),
          ),
          () => MockClient((_) async => loginPage),
        ),
        throwsA(isA<SessionExpiredException>()),
      );
    });

    test('parallele Relogins teilen sich einen Login-Request', () {
      setNamiLoginId(demoLoginId);
      setNamiPassword(demoPassword);

      final first = updateLoginData();
      final second = updateLoginData();

      expect(identical(first, second), true);
    });
  });

  group('namiEditMember', () {
    NamiMemberDetailsModel member() => NamiMemberDetailsModel(
      vorname: 'Max',
      nachname: 'Muster',
      geschlechtId: 1,
      geburtsDatum: DateTime(2010),
      eintrittsdatum: DateTime(2015),
      version: 3,
      gruppierungId: 1,
      emailVertretungsberechtigter: null,
      staatsangehoerigkeitId: 1,
      landId: 1,
      konfessionId: null,
      zeitschriftenversand: false,
      telefon1: null,
      telefon2: null,
      telefon3: null,
      email: null,
      strasse: 'Weg 1',
      ort: 'Stadt',
      plz: '12345',
      wiederverwendenFlag: false,
      regionId: 1,
      beitragsartId: 1,
    );

    setUp(() {
      setNamiChangesEnabled(true);
      setGruppierungId(1);
    });

    test('Fehlerantwort ohne data führt zu lesbarer Exception', () {
      expect(
        http.runWithClient(
          () => namiEditMember(member()),
          () => MockClient(
            (_) async => jsonResponse({
              'success': false,
              'message': 'Version veraltet',
              'data': null,
            }),
          ),
        ),
        throwsA(
          isA<MemberCreationException>().having(
            (e) => e.message,
            'message',
            'Version veraltet',
          ),
        ),
      );
    });

    test('abgelaufene Session ohne Passwort wird gemeldet', () {
      expect(
        http.runWithClient(
          () => namiEditMember(member()),
          () => MockClient((_) async => loginPage),
        ),
        throwsA(isA<SessionExpiredException>()),
      );
    });

    test('nutzt nach einem Relogin den neuen Cookie', () async {
      setNamiLoginId(demoLoginId);
      setNamiPassword(demoPassword);
      final usedCookies = <String?>[];

      await http.runWithClient(
        () => namiEditMember(member()),
        () => MockClient((request) async {
          usedCookies.add(request.headers['Cookie']);
          return usedCookies.length == 1
              ? loginPage
              : jsonResponse({
                  'success': true,
                  'data': {'id': 7},
                });
        }),
      );

      expect(usedCookies, ['oldCookie', 'testLoginCookie']);
    });
  });

  group('isTooLongOffline', () {
    test('hängt nur vom letzten erfolgreichen Kontakt mit NaMi ab', () {
      setLastNamiSync(DateTime(2000));
      setLastLoginCheck(DateTime.now().subtract(const Duration(days: 2)));
      expect(AppStateHandler().isTooLongOffline(), false);

      setLastLoginCheck(DateTime.now().subtract(const Duration(days: 31)));
      expect(AppStateHandler().isTooLongOffline(), true);
    });
  });
}

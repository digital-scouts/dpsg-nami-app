import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nami/domain/hilfe/problem_meldung.dart';
import 'package:nami/domain/rechtliches/anbieter.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/services/problem_melden_service.dart';
import 'package:nami/services/teilen_ordner.dart';

import 'support/fake_logger_service.dart';

class _LogLogger extends FakeLoggerService {
  _LogLogger(this.inhalt);

  final String inhalt;

  @override
  Future<String> readLogs({String? selectionId}) async => inhalt;
}

void main() {
  final t = AppLocalizations(const Locale('de')).t;

  group('ProblemMeldung', () {
    test('baut Betreff und Text, offene Fragen als –', () {
      const meldung = ProblemMeldung(
        arten: {ProblemArt.statistik, ProblemArt.datenSync},
        gemacht: ' Liste aktualisiert ',
        passiert: 'Fehlermeldung',
      );

      expect(meldung.betreff(t), 'NaMi: Problem – Daten & Sync, Statistik');
      expect(
        meldung.text(t, geraet: 'App 1.0.0 (1) · ios 27'),
        'Art des Problems: Daten & Sync, Statistik\n'
        '\n'
        'Was hast du gemacht?\nListe aktualisiert\n'
        '\n'
        'Was ist passiert?\nFehlermeldung\n'
        '\n'
        'Was hast du erwartet?\n–\n'
        '\n'
        'App 1.0.0 (1) · ios 27',
      );
    });

    test('ohne Angaben bleibt der Betreff kurz', () {
      expect(const ProblemMeldung().betreff(t), 'NaMi: Problem');
    });
  });

  group('ProblemMeldenService', () {
    late Directory temp;

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('problem_melden_');
    });

    tearDown(() async => temp.delete(recursive: true));

    test(
      'haengt nur die letzten 24 Stunden an und adressiert den Entwickler',
      () async {
        Email? gesendet;
        final service = ProblemMeldenService(
          logger: _LogLogger(
            '[2026-10-06 09:00:00] [info] [auth] alt\n'
            '[2026-10-07 21:00:00] [error] [sync] neu\n'
            'Folgezeile\n',
          ),
          senden: (email) async => gesendet = email,
          temp: () async => temp,
          geraet: () async => 'App 1.0.0 (1) · ios 27',
          nowProvider: () => DateTime(2026, 10, 7, 22),
        );

        await service.melden(
          const ProblemMeldung(arten: {ProblemArt.absturz}),
          t,
        );

        expect(gesendet!.recipients, [Anbieter.email]);
        expect(gesendet!.subject, 'NaMi: Problem – Absturz');
        final anhang = File(gesendet!.attachmentPaths!.single);
        expect(anhang.parent.path, '${temp.path}/${TeilenOrdner.name}');
        expect(
          await anhang.readAsString(),
          '[2026-10-07 21:00:00] [error] [sync] neu\nFolgezeile\n',
        );
      },
    );

    test('ohne Protokoll keine Anlage', () async {
      Email? gesendet;
      final service = ProblemMeldenService(
        logger: _LogLogger(''),
        senden: (email) async => gesendet = email,
        temp: () async => temp,
        geraet: () async => 'x',
      );

      await service.melden(const ProblemMeldung(), t);

      expect(gesendet!.attachmentPaths, isEmpty);
    });
  });
}

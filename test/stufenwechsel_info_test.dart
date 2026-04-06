import 'package:flutter_test/flutter_test.dart';
import 'package:nami/domain/member/mitglied.dart';
import 'package:nami/domain/stufenwechsel/stufenwechsel_info.dart';
import 'package:nami/domain/taetigkeit/role_derivation.dart';
import 'package:nami/domain/taetigkeit/roles.dart';
import 'package:nami/domain/taetigkeit/stufe.dart';

void main() {
  group('Stufenwechsel Info', () {
    test('Beispiel Max: Wös (8 Jahre, Dez 2025) und Stichtag Sep 2026', () {
      final mitglied = Mitglied(
        vorname: 'Max',
        nachname: 'Orange',
        geburtsdatum: DateTime(2017, 7, 1),
        eintrittsdatum: DateTime(2023, 9, 1),
        mitgliedsnummer: 'w1',
        roles: [
          roleFromLegacy(
            stufe: Stufe.woelfling,
            art: RoleCategory.mitglied,
            start: DateTime(2023, 9, 1),
          ),
        ],
      );

      final grenzen = Altersgrenzen({
        Stufe.biber: const AgeRange(minJahre: 5, maxJahre: 7),
        Stufe.woelfling: const AgeRange(minJahre: 7, maxJahre: 11),
        Stufe.jungpfadfinder: const AgeRange(minJahre: 9, maxJahre: 14),
        Stufe.pfadfinder: const AgeRange(minJahre: 13, maxJahre: 16),
        Stufe.rover: const AgeRange(minJahre: 16, maxJahre: 21),
      });

      final stichtag = DateTime(2026, 9, 1);
      final infos = computeStufenwechselInfos(
        mitglieder: [mitglied],
        stichtag: stichtag,
        grenzen: grenzen,
      );

      expect(infos.length, 1);
      final info = infos.first;
      expect(info.id, 'w1');
      expect(info.vorname, 'Max');
      // Alter zum Stichtag: ca. 9 Jahre, 2 Monate → Duration in Tagen ~ 9*365 + 62
      final alterTage = info.alterZumStichtag.inDays;
      expect(alterTage, greaterThan(9 * 365));
      expect(alterTage, lessThan(10 * 365));

      // Wechselzeitraum: Start 2026 (minAlter Jufi erreicht), Ende 2028 (vor Überschreitung max Wö 11)
      expect(info.wechselzeitraum.startJahr, 2026);
      expect(info.wechselzeitraum.endJahr, 2028);
      // Innerhalb des Fensters am Stichtag → sollte wechseln
      expect(info.shouldWechselNext, isTrue);
    });

    test('Rover: nur Endjahr = Ende Mitgliedschaft', () {
      final rita = Mitglied(
        vorname: 'Rita',
        nachname: 'Rot',
        geburtsdatum: DateTime(2008, 3, 10),
        eintrittsdatum: DateTime(2023, 9, 1),
        mitgliedsnummer: 'r1',
        roles: [
          roleFromLegacy(
            stufe: Stufe.rover,
            art: RoleCategory.mitglied,
            start: DateTime(2023, 9, 1),
          ),
        ],
      );

      final grenzen = Altersgrenzen({
        Stufe.biber: const AgeRange(minJahre: 5, maxJahre: 7),
        Stufe.woelfling: const AgeRange(minJahre: 7, maxJahre: 11),
        Stufe.jungpfadfinder: const AgeRange(minJahre: 9, maxJahre: 14),
        Stufe.pfadfinder: const AgeRange(minJahre: 13, maxJahre: 16),
        Stufe.rover: const AgeRange(minJahre: 16, maxJahre: 21),
      });

      final infos = computeStufenwechselInfos(
        mitglieder: [rita],
        stichtag: DateTime(2025, 10, 1),
        grenzen: grenzen,
      );

      final info = infos.first;
      expect(info.wechselzeitraum.startJahr, isNull);
      expect(info.wechselzeitraum.endJahr, 2008 + 21);
    });
  });

  group('Altersgrenzen-Varianten', () {
    test('Harte Grenzen: biber 4-6, wö 6-9', () {
      final m = Mitglied(
        vorname: 'Tom',
        nachname: 'Tester',
        geburtsdatum: DateTime(2018, 9, 1),
        eintrittsdatum: DateTime(2024, 9, 1),
        mitgliedsnummer: 'A-1',
        roles: [
          roleFromLegacy(
            stufe: Stufe.woelfling,
            art: RoleCategory.mitglied,
            start: DateTime(2024, 9, 1),
          ),
        ],
      );

      final grenzen = Altersgrenzen({
        Stufe.biber: const AgeRange(minJahre: 4, maxJahre: 6),
        Stufe.woelfling: const AgeRange(minJahre: 6, maxJahre: 9),
        Stufe.jungpfadfinder: const AgeRange(minJahre: 9, maxJahre: 14),
        Stufe.pfadfinder: const AgeRange(minJahre: 12, maxJahre: 17),
        Stufe.rover: const AgeRange(minJahre: 17, maxJahre: 21),
      });

      final stichtag = DateTime(2027, 9, 1); // genau 9 Jahre alt
      final info = computeStufenwechselInfos(
        mitglieder: [m],
        stichtag: stichtag,
        grenzen: grenzen,
      ).first;

      // Wölfling → Jufi: Start bei 9, Ende bei 9 (eng)
      expect(info.wechselzeitraum.startJahr, 2018 + 9);
      expect(info.wechselzeitraum.endJahr, 2018 + 9);
      expect(info.shouldWechselNext, isTrue); // exakt im Fenster
    });

    test('Überlappung: biber 4-8, wö 6-10, jufi 8-14', () {
      final m = Mitglied(
        vorname: 'Mia',
        nachname: 'Muster',
        geburtsdatum: DateTime(2017, 1, 1),
        eintrittsdatum: DateTime(2023, 9, 1),
        mitgliedsnummer: 'A-2',
        roles: [
          roleFromLegacy(
            stufe: Stufe.woelfling,
            art: RoleCategory.mitglied,
            start: DateTime(2023, 9, 1),
          ),
        ],
      );

      final grenzen = Altersgrenzen({
        Stufe.biber: const AgeRange(minJahre: 4, maxJahre: 8),
        Stufe.woelfling: const AgeRange(minJahre: 6, maxJahre: 10),
        Stufe.jungpfadfinder: const AgeRange(minJahre: 8, maxJahre: 14),
        Stufe.pfadfinder: const AgeRange(minJahre: 12, maxJahre: 17),
        Stufe.rover: const AgeRange(minJahre: 17, maxJahre: 21),
      });

      final stichtag = DateTime(2026, 9, 1); // 9 Jahre
      final info = computeStufenwechselInfos(
        mitglieder: [m],
        stichtag: stichtag,
        grenzen: grenzen,
      ).first;

      // Wö → Jufi: Start 2017+8=2025, Ende 2017+10=2027 (überlappt großflächig)
      expect(info.wechselzeitraum.startJahr, 2017 + 8);
      expect(info.wechselzeitraum.endJahr, 2017 + 10);
      expect(info.shouldWechselNext, isTrue); // innerhalb des Fensters
    });
  });

  group('Wechselndes Alter des Mitglieds', () {
    test('Zu jung für Wechsel → shouldWchselNext=false', () {
      final m = Mitglied(
        vorname: 'Leo',
        nachname: 'Jung',
        geburtsdatum: DateTime(2020, 6, 1),
        eintrittsdatum: DateTime(2024, 9, 1),
        mitgliedsnummer: 'B-1',
        roles: [
          roleFromLegacy(
            stufe: Stufe.woelfling,
            art: RoleCategory.mitglied,
            start: DateTime(2024, 9, 1),
          ),
        ],
      );

      final grenzen = Altersgrenzen({
        Stufe.biber: const AgeRange(minJahre: 4, maxJahre: 6),
        Stufe.woelfling: const AgeRange(minJahre: 6, maxJahre: 10),
        Stufe.jungpfadfinder: const AgeRange(minJahre: 9, maxJahre: 14),
        Stufe.pfadfinder: const AgeRange(minJahre: 12, maxJahre: 17),
        Stufe.rover: const AgeRange(minJahre: 17, maxJahre: 21),
      });

      final stichtag = DateTime(2026, 9, 1); // 6 Jahre → StartJahr wäre 2029
      final info = computeStufenwechselInfos(
        mitglieder: [m],
        stichtag: stichtag,
        grenzen: grenzen,
      ).first;

      expect(info.wechselzeitraum.startJahr, 2020 + 9);
      expect(info.wechselzeitraum.endJahr, 2020 + 10);
      expect(info.shouldWechselNext, isFalse);
    });

    test('Zu alt für Wechsel → shouldWchselNext=true', () {
      final m = Mitglied(
        vorname: 'Anna',
        nachname: 'Alt',
        geburtsdatum: DateTime(2014, 1, 1),
        eintrittsdatum: DateTime(2020, 9, 1),
        mitgliedsnummer: 'B-2',
        roles: [
          roleFromLegacy(
            stufe: Stufe.woelfling,
            art: RoleCategory.mitglied,
            start: DateTime(2020, 9, 1),
          ),
        ],
      );

      final grenzen = Altersgrenzen({
        Stufe.biber: const AgeRange(minJahre: 4, maxJahre: 6),
        Stufe.woelfling: const AgeRange(minJahre: 6, maxJahre: 10),
        Stufe.jungpfadfinder: const AgeRange(minJahre: 9, maxJahre: 14),
        Stufe.pfadfinder: const AgeRange(minJahre: 12, maxJahre: 17),
        Stufe.rover: const AgeRange(minJahre: 17, maxJahre: 21),
      });

      final stichtag = DateTime(2025, 9, 1); // 11 Jahre → über max (9) der Wö
      final info = computeStufenwechselInfos(
        mitglieder: [m],
        stichtag: stichtag,
        grenzen: grenzen,
      ).first;

      expect(info.wechselzeitraum.startJahr, 2014 + 9);
      expect(info.wechselzeitraum.endJahr, 2014 + 10);
      expect(info.shouldWechselNext, isTrue);
    });
  });

  group('Filter & geplante nächste Stufe', () {
    test('Liste enthält nur aktive Mitglieder (keine Leitung)', () {
      final mAktiv = Mitglied(
        vorname: 'Linus',
        nachname: 'Live',
        geburtsdatum: DateTime(2015, 5, 1),
        eintrittsdatum: DateTime(2022, 9, 1),
        mitgliedsnummer: 'F-1',
        roles: [
          roleFromLegacy(
            stufe: Stufe.woelfling,
            art: RoleCategory.mitglied,
            start: DateTime(2022, 9, 1),
          ),
        ],
      );
      final mPassiv = Mitglied(
        vorname: 'Paul',
        nachname: 'Passiv',
        geburtsdatum: DateTime(2015, 5, 1),
        eintrittsdatum: DateTime(2022, 9, 1),
        mitgliedsnummer: 'F-3',
        roles: [
          roleFromLegacy(
            stufe: Stufe.woelfling,
            art: RoleCategory.mitglied,
            start: DateTime(2022, 9, 1),
            ende: DateTime(2024, 8, 31),
          ),
        ],
      );
      final mLeitung = Mitglied(
        vorname: 'Lea',
        nachname: 'Leitung',
        geburtsdatum: DateTime(2000, 1, 1),
        eintrittsdatum: DateTime(2020, 1, 1),
        mitgliedsnummer: 'F-2',
        roles: [
          roleFromLegacy(
            stufe: Stufe.leitung,
            art: RoleCategory.leitung,
            start: DateTime(2023, 1, 1),
          ),
        ],
      );

      final grenzen = Altersgrenzen({
        Stufe.biber: const AgeRange(minJahre: 4, maxJahre: 6),
        Stufe.woelfling: const AgeRange(minJahre: 6, maxJahre: 9),
        Stufe.jungpfadfinder: const AgeRange(minJahre: 9, maxJahre: 14),
        Stufe.pfadfinder: const AgeRange(minJahre: 12, maxJahre: 17),
        Stufe.rover: const AgeRange(minJahre: 17, maxJahre: 21),
      });

      final stichtag = DateTime(2025, 9, 1);
      final infos = computeStufenwechselInfos(
        mitglieder: [mAktiv, mLeitung, mPassiv],
        stichtag: stichtag,
        grenzen: grenzen,
      );
      expect(infos.length, 1);
      expect(infos.first.id, 'F-1');
    });

    test(
      'Geplante zukünftige Mitglieds-Tätigkeit in nächster Stufe → shouldWchselNext=false',
      () {
        final m = Mitglied(
          vorname: 'Paul',
          nachname: 'Plan',
          geburtsdatum: DateTime(2016, 6, 1),
          eintrittsdatum: DateTime(2023, 9, 1),
          mitgliedsnummer: 'F-3',
          roles: [
            roleFromLegacy(
              stufe: Stufe.woelfling,
              art: RoleCategory.mitglied,
              start: DateTime(2023, 9, 1),
            ),
            // Geplante Aufnahme als Jufi nach Stichtag
            roleFromLegacy(
              stufe: Stufe.jungpfadfinder,
              art: RoleCategory.mitglied,
              start: DateTime(2026, 10, 1),
            ),
          ],
        );

        final grenzen = Altersgrenzen({
          Stufe.biber: const AgeRange(minJahre: 4, maxJahre: 6),
          Stufe.woelfling: const AgeRange(minJahre: 6, maxJahre: 9),
          Stufe.jungpfadfinder: const AgeRange(minJahre: 9, maxJahre: 14),
          Stufe.pfadfinder: const AgeRange(minJahre: 12, maxJahre: 17),
          Stufe.rover: const AgeRange(minJahre: 17, maxJahre: 21),
        });

        final stichtag = DateTime(2026, 9, 1);
        final info = computeStufenwechselInfos(
          mitglieder: [m],
          stichtag: stichtag,
          grenzen: grenzen,
        ).first;

        expect(info.shouldWechselNext, isFalse);
      },
    );
  });
}

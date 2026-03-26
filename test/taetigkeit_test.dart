import 'package:flutter_test/flutter_test.dart';
import 'package:nami/domain/taetigkeit/stufe.dart';
import 'package:nami/domain/taetigkeit/taetigkeit.dart';

void main() {
  test('istAktiv ist wahr ohne Ende oder mit zukuenftigem Ende', () {
    final open = Taetigkeit(
      stufe: Stufe.rover,
      art: TaetigkeitsArt.mitglied,
      start: DateTime(2025, 1, 1),
    );
    final futureEnd = Taetigkeit(
      stufe: Stufe.rover,
      art: TaetigkeitsArt.leitung,
      start: DateTime(2025, 1, 1),
      ende: DateTime.now().add(const Duration(days: 1)),
    );

    expect(open.istAktiv, isTrue);
    expect(futureEnd.istAktiv, isTrue);
  });

  test('istAktiv ist falsch bei vergangenem Ende', () {
    final taetigkeit = Taetigkeit(
      stufe: Stufe.pfadfinder,
      art: TaetigkeitsArt.mitglied,
      start: DateTime(2024, 1, 1),
      ende: DateTime.now().subtract(const Duration(days: 1)),
    );

    expect(taetigkeit.istAktiv, isFalse);
  });

  test('copyWith uebernimmt neue Werte und behaelt alte bei', () {
    final original = Taetigkeit(
      stufe: Stufe.woelfling,
      art: TaetigkeitsArt.mitglied,
      start: DateTime(2024, 2, 3),
      permission: 'read',
    );

    final updated = original.copyWith(
      art: TaetigkeitsArt.leitung,
      permission: 'write',
    );

    expect(updated.stufe, Stufe.woelfling);
    expect(updated.art, TaetigkeitsArt.leitung);
    expect(updated.start, DateTime(2024, 2, 3));
    expect(updated.permission, 'write');
  });

  test(
    'gleichheit ignoriert permission nicht und bleibt ueber hash stabil',
    () {
      final first = Taetigkeit(
        stufe: Stufe.biber,
        art: TaetigkeitsArt.mitglied,
        start: DateTime(2024, 5, 1),
        permission: 'x',
      );
      final second = Taetigkeit(
        stufe: Stufe.biber,
        art: TaetigkeitsArt.mitglied,
        start: DateTime(2024, 5, 1),
        permission: 'y',
      );

      expect(first, second);
      expect(first.hashCode, second.hashCode);
    },
  );
}

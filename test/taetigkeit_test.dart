import 'package:flutter_test/flutter_test.dart';
import 'package:nami/domain/taetigkeit/role_derivation.dart';
import 'package:nami/domain/taetigkeit/roles.dart';
import 'package:nami/domain/taetigkeit/stufe.dart';

void main() {
  test('istAktiv ist wahr ohne Ende oder mit zukuenftigem Ende', () {
    final open = roleFromLegacy(
      stufe: Stufe.rover,
      art: RoleCategory.mitglied,
      start: DateTime(2025, 1, 1),
    );
    final futureEnd = roleFromLegacy(
      stufe: Stufe.rover,
      art: RoleCategory.leitung,
      start: DateTime(2025, 1, 1),
      ende: DateTime.now().add(const Duration(days: 1)),
    );

    expect(open.istAktiv, isTrue);
    expect(futureEnd.istAktiv, isTrue);
  });

  test('istAktiv ist falsch bei vergangenem Ende', () {
    final taetigkeit = roleFromLegacy(
      stufe: Stufe.pfadfinder,
      art: RoleCategory.mitglied,
      start: DateTime(2024, 1, 1),
      ende: DateTime.now().subtract(const Duration(days: 1)),
    );

    expect(taetigkeit.istAktiv, isFalse);
  });

  test('copyWith uebernimmt neue Werte und behaelt alte bei', () {
    final original = roleFromLegacy(
      stufe: Stufe.woelfling,
      art: RoleCategory.mitglied,
      start: DateTime(2024, 2, 3),
      permission: 'read',
    );

    final updated = roleFromLegacy(
      stufe: original.stufe,
      art: RoleCategory.leitung,
      start: original.start,
      permission: 'write',
    );

    expect(updated.stufe, Stufe.woelfling);
    expect(updated.art, RoleCategory.leitung);
    expect(updated.start, DateTime(2024, 2, 3));
    expect(updated.permission, 'write');
  });

  test('gleichheit beruecksichtigt unterschiedliche Rohdaten', () {
    final first = roleFromLegacy(
      stufe: Stufe.biber,
      art: RoleCategory.mitglied,
      start: DateTime(2024, 5, 1),
      permission: 'x',
    );
    final second = roleFromLegacy(
      stufe: Stufe.biber,
      art: RoleCategory.mitglied,
      start: DateTime(2024, 5, 1),
      permission: 'y',
    );

    expect(first, isNot(second));
    expect(first.hashCode, isNot(second.hashCode));
  });
}

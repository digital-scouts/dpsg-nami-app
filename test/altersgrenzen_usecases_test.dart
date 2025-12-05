import 'package:flutter_test/flutter_test.dart';
import 'package:nami/data/settings/in_memory_stufen_settings_repository.dart';
import 'package:nami/domain/stufe/altersgrenzen.dart';
import 'package:nami/domain/stufe/usecases/get_altersgrenzen_usecase.dart';
import 'package:nami/domain/stufe/usecases/update_altersgrenzen_usecase.dart';
import 'package:nami/domain/taetigkeit/stufe.dart';

void main() {
  group('Altersgrenzen UseCases', () {
    test('Defaults are loaded', () async {
      final repo = InMemoryStufenSettingsRepository();
      final get = GetAltersgrenzenUseCase(repo);
      final g = await get();
      expect(g.forStufe(Stufe.woelfling).minJahre, 6);
      expect(g.forStufe(Stufe.jungpfadfinder).minJahre, 9);
    });

    test('Invalid: Jufi min <= Wö min throws', () async {
      final repo = InMemoryStufenSettingsRepository();
      final update = UpdateAltersgrenzenUseCase(repo);
      final get = GetAltersgrenzenUseCase(repo);
      var g = await get();
      // Set Jufi min to 6 (<= Wö min 6)
      g = g.copyWithFor(
        Stufe.jungpfadfinder,
        AltersIntervall(
          minJahre: g.forStufe(Stufe.woelfling).minJahre,
          maxJahre: 13,
        ),
      );
      expect(() => update(g), throwsA(isA<AltersgrenzenValidationError>()));
    });

    test('Invalid: min >= max for any stufe throws', () async {
      final repo = InMemoryStufenSettingsRepository();
      final update = UpdateAltersgrenzenUseCase(repo);
      final get = GetAltersgrenzenUseCase(repo);
      var g = await get();
      g = g.copyWithFor(
        Stufe.pfadfinder,
        const AltersIntervall(minJahre: 17, maxJahre: 17),
      );
      expect(() => update(g), throwsA(isA<AltersgrenzenValidationError>()));
    });

    group('UpdateAltersgrenzenUseCase gap validation', () {
      test('throws when there is a gap between consecutive stufen', () async {
        final repo = InMemoryStufenSettingsRepository();
        final usecase = UpdateAltersgrenzenUseCase(repo);

        // Start from defaults and create a gap: Wö max=8, Jufi min=10
        final defaults = StufenDefaults.build();
        final wo = defaults.forStufe(Stufe.woelfling);
        final jufi = defaults.forStufe(Stufe.jungpfadfinder);

        final withGap = defaults
            .copyWithFor(Stufe.woelfling, wo.copyWith(maxJahre: 8))
            .copyWithFor(Stufe.jungpfadfinder, jufi.copyWith(minJahre: 9));

        expect(
          () => usecase.call(withGap),
          throwsA(isA<AltersgrenzenValidationError>()),
        );
      });

      test('does not throw when next.min <= prev.max (no gap)', () async {
        final repo = InMemoryStufenSettingsRepository();
        final usecase = UpdateAltersgrenzenUseCase(repo);

        final defaults = StufenDefaults.build();
        // Align boundaries: Wö max=9, Jufi min=9 => touch/overlap, no gap
        final wo = defaults.forStufe(Stufe.woelfling);
        final jufi = defaults.forStufe(Stufe.jungpfadfinder);

        final aligned = defaults
            .copyWithFor(Stufe.woelfling, wo.copyWith(maxJahre: 9))
            .copyWithFor(Stufe.jungpfadfinder, jufi.copyWith(minJahre: 9));

        await usecase.call(aligned);
        final saved = await repo.load();
        expect(saved.forStufe(Stufe.woelfling).maxJahre, 9);
        expect(saved.forStufe(Stufe.jungpfadfinder).minJahre, 9);
      });
    });
  });
}

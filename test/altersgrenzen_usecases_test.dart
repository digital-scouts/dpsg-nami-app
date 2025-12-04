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

    test('Update valid: Jufi greater than Wö and consistent', () async {
      final repo = InMemoryStufenSettingsRepository();
      final update = UpdateAltersgrenzenUseCase(repo);
      final get = GetAltersgrenzenUseCase(repo);
      var g = await get();
      final w = g.forStufe(Stufe.woelfling);
      // Set Jufi min/max strictly greater than Wö, but keep below Pfadi
      g = g.copyWithFor(
        Stufe.jungpfadfinder,
        AltersIntervall(minJahre: w.minJahre + 1, maxJahre: w.maxJahre + 1),
      );
      await update(g);
      final after = await get();
      expect(after.forStufe(Stufe.jungpfadfinder).minJahre, w.minJahre + 1);
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
  });
}

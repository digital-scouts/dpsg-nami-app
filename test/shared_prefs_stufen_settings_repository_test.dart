import 'package:flutter_test/flutter_test.dart';
import 'package:nami/data/settings/shared_prefs_stufen_settings_repository.dart';
import 'package:nami/domain/stufe/altersgrenzen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SharedPrefsStufenSettingsRepository', () {
    test('loads defaults when empty', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = SharedPrefsStufenSettingsRepository();
      final s = await repo.load();
      expect(
        s.grenzen.forStufe(StufenDefaults.build().grenzen.keys.first).minJahre,
        isNonZero,
      );
      expect(s.stufenwechselDatum, isNull);
    });

    test('persists stufenwechsel and grenzen', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = SharedPrefsStufenSettingsRepository();
      final initial = await repo.load();
      final updated = initial.copyWith(
        grenzen: initial.grenzen.copyWithFor(
          initial.grenzen.grenzen.keys.first,
          const AltersIntervall(minJahre: 8, maxJahre: 12),
        ),
      );
      await repo.saveAltersgrenzen(updated);
      final now = DateTime.now();
      await repo.saveStufenwechselDatum(now);
      final s2 = await repo.load();
      expect(
        s2.stufenwechselDatum?.millisecondsSinceEpoch,
        now.millisecondsSinceEpoch,
      );
      expect(
        s2.grenzen.forStufe(initial.grenzen.grenzen.keys.first).minJahre,
        8,
      );
      expect(
        s2.grenzen.forStufe(initial.grenzen.grenzen.keys.first).maxJahre,
        12,
      );
    });
  });
}

import 'dart:async';

import 'package:nami/domain/stufe/altersgrenzen.dart';
import 'package:nami/domain/stufe/stufen_settings_repository.dart';

import '../../domain/settings/stufen_settings.dart';
import 'shared_prefs_stufen_settings_repository.dart';

/// Adapter, der den SharedPrefs-Repository (arbeitet mit StufenSettings)
/// auf das Domain-Interface `StufenSettingsRepository` (arbeitet mit Altersgrenzen)
/// abbildet, damit der `UpdateAltersgrenzenUseCase` verwendet werden kann.
class StufenSettingsRepoAdapter implements StufenSettingsRepository {
  final SharedPrefsStufenSettingsRepository prefsRepo;
  final DateTime? Function() currentDateProvider;

  StufenSettingsRepoAdapter({
    required this.prefsRepo,
    required this.currentDateProvider,
  });

  @override
  Future<Altersgrenzen> load() async {
    final s = await prefsRepo.load();
    return s.grenzen;
  }

  @override
  Future<void> save(Altersgrenzen grenzen) async {
    final date = currentDateProvider();
    await prefsRepo.saveAltersgrenzen(
      StufenSettings(grenzen: grenzen, stufenwechselDatum: date),
    );
  }

  @override
  Stream<Altersgrenzen> watch() {
    // SharedPrefs hat kein echtes Watch – wir geben einen leeren Stream zurück.
    return const Stream.empty();
  }
}

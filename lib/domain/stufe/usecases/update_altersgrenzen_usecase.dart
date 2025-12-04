import 'package:nami/domain/stufe/altersgrenzen.dart';
import 'package:nami/domain/stufe/stufen_settings_repository.dart';
import 'package:nami/domain/taetigkeit/stufe.dart';

class AltersgrenzenValidationError implements Exception {
  final String message;
  AltersgrenzenValidationError(this.message);
  @override
  String toString() => message;
}

class UpdateAltersgrenzenUseCase {
  final StufenSettingsRepository repo;
  UpdateAltersgrenzenUseCase(this.repo);

  Future<void> call(Altersgrenzen grenzen) async {
    _validate(grenzen);
    await repo.save(grenzen);
  }

  void _validate(Altersgrenzen g) {
    // 1) max > min in jeder Stufe
    for (final entry in g.grenzen.entries) {
      final s = entry.key;
      final iv = entry.value;
      if (iv.maxJahre <= iv.minJahre) {
        throw AltersgrenzenValidationError(
          'Ungültiger Bereich für ${s.shortDisplayName}: max (${iv.maxJahre}) muss größer sein als min (${iv.minJahre}).',
        );
      }
    }

    // 2) Für jede Folge-Stufe: min(next) > min(prev) und max(next) > max(prev)
    // Annahme: Enum-Reihenfolge bildet die Stufenfolge ab (Biber → Wö → Jufi → Pfadi → Rover)
    final ordered = [
      Stufe.biber,
      Stufe.woelfling,
      Stufe.jungpfadfinder,
      Stufe.pfadfinder,
      Stufe.rover,
    ];
    for (var i = 0; i < ordered.length - 1; i++) {
      final prev = ordered[i];
      final next = ordered[i + 1];
      if (!g.grenzen.containsKey(prev) || !g.grenzen.containsKey(next)) {
        continue;
      }
      final p = g.forStufe(prev);
      final n = g.forStufe(next);
      if (n.minJahre <= p.minJahre) {
        throw AltersgrenzenValidationError(
          'Mindestalter ${next.shortDisplayName} (${n.minJahre}) muss größer sein als ${prev.shortDisplayName} (${p.minJahre}).',
        );
      }
      if (n.maxJahre <= p.maxJahre) {
        throw AltersgrenzenValidationError(
          'Höchstalter ${next.shortDisplayName} (${n.maxJahre}) muss größer sein als ${prev.shortDisplayName} (${p.maxJahre}).',
        );
      }
    }
  }
}

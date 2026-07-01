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
      final current = ordered[i];
      final next = ordered[i + 1];
      if (!g.grenzen.containsKey(current) || !g.grenzen.containsKey(next)) {
        continue;
      }
      final cur = g.forStufe(current);
      final nex = g.forStufe(next);
      if (nex.minJahre <= cur.minJahre) {
        throw AltersgrenzenValidationError(
          'Mindestalter ${next.shortDisplayName} (${nex.minJahre}) muss größer sein als ${current.shortDisplayName} (${cur.minJahre}).',
        );
      }
      if (nex.maxJahre <= cur.maxJahre) {
        throw AltersgrenzenValidationError(
          'Höchstalter ${next.shortDisplayName} (${nex.maxJahre}) muss größer sein als ${current.shortDisplayName} (${cur.maxJahre}).',
        );
      }
      // 3) Keine Lücken zwischen aufeinanderfolgenden Stufen: Beginn der nächsten Stufe
      //    darf nicht größer sein als das Höchstalter der vorherigen Stufe.
      //    Beispiel: Wö max=8 und Jufi min=9 -> Lücke (8.x Jahre)
      if (nex.minJahre > cur.maxJahre) {
        throw AltersgrenzenValidationError(
          'Es darf keine Lücke zwischen ${current.shortDisplayName} und ${next.shortDisplayName} entstehen. '
          'Aktuell: Mindestalter ${next.shortDisplayName} (${nex.minJahre}) > Höchstalter ${current.shortDisplayName} (${cur.maxJahre}).',
        );
      }
    }
  }
}

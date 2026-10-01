import '../domain/arbeitskontext/arbeitskontext_read_model.dart';
import '../domain/statistiks/berechne_stamm_statistik_usecase.dart';
import '../domain/statistiks/statistik_verlauf.dart';

/// Hält einmal im Monat die Summen des aktiven Stamms fest, damit die
/// Kachel „Verlauf“ über die Zeit eine Kurve zeigen kann.
///
/// Aufgezeichnet wird nur ein vollständiger Stand: Rollen geladen, kein
/// Laden mehr aktiv (keine Zwischenstände beim seitenweisen Laden).
class StatistikVerlaufService {
  StatistikVerlaufService({
    required StatistikVerlaufRepository repository,
    DateTime Function()? heute,
  }) : _aufzeichnen = ZeichneStatistikVerlaufAufUseCase(repository),
       _heute = heute ?? DateTime.now;

  final ZeichneStatistikVerlaufAufUseCase _aufzeichnen;
  final DateTime Function() _heute;
  ArbeitskontextReadModel? _zuletzt;

  Future<void> aktualisiere(
    ArbeitskontextReadModel? readModel, {
    required bool ladeLaeuft,
  }) async {
    if (readModel == null ||
        ladeLaeuft ||
        !readModel.rolesSindGeladen ||
        identical(readModel, _zuletzt)) {
      return;
    }
    _zuletzt = readModel;
    final heute = _heute();
    try {
      await _aufzeichnen(
        layerId: readModel.arbeitskontext.aktiverLayer.id,
        statistik: const BerechneStammStatistikUseCase()(
          readModel,
          heute: heute,
        ),
        heute: heute,
      );
    } catch (_) {
      // Der Verlauf ist eine Zusatzinformation; Fehler beim Speichern dürfen
      // den Arbeitskontext nicht stören. Nächster Versuch beim nächsten Stand.
      _zuletzt = null;
    }
  }
}

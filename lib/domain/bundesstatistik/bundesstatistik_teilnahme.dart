/// Lokal gespeicherter Stand der Teilnahme an der bundesweiten Statistik.
class BundesstatistikTeilnahme {
  const BundesstatistikTeilnahme({
    this.einwilligungFuer,
    this.einwilligungAm,
    this.zuletztGesendetAm,
    this.zuletztGesendeterStammId,
    this.zuletztGesendeterSnapshotJson,
  });

  static const BundesstatistikTeilnahme leer = BundesstatistikTeilnahme();

  /// Hitobito-Personen-ID, fuer die die Einwilligung erteilt wurde. Eine
  /// Einwilligung gilt nie fuer eine andere Person am selben Geraet.
  final String? einwilligungFuer;
  final DateTime? einwilligungAm;
  final DateTime? zuletztGesendetAm;
  final String? zuletztGesendeterStammId;

  /// Exakt der zuletzt gesendete Payload, damit sichtbar bleibt, was geteilt wurde.
  final String? zuletztGesendeterSnapshotJson;

  bool hatEinwilligungFuer(String personId) => einwilligungFuer == personId;

  BundesstatistikTeilnahme mitEinwilligung(String personId, DateTime am) =>
      BundesstatistikTeilnahme(
        einwilligungFuer: personId,
        einwilligungAm: am,
        zuletztGesendetAm: zuletztGesendetAm,
        zuletztGesendeterStammId: zuletztGesendeterStammId,
        zuletztGesendeterSnapshotJson: zuletztGesendeterSnapshotJson,
      );

  BundesstatistikTeilnahme ohneEinwilligung() => BundesstatistikTeilnahme(
    zuletztGesendetAm: zuletztGesendetAm,
    zuletztGesendeterStammId: zuletztGesendeterStammId,
    zuletztGesendeterSnapshotJson: zuletztGesendeterSnapshotJson,
  );

  BundesstatistikTeilnahme mitGesendetemSnapshot({
    required DateTime am,
    required String stammId,
    required String snapshotJson,
  }) => BundesstatistikTeilnahme(
    einwilligungFuer: einwilligungFuer,
    einwilligungAm: einwilligungAm,
    zuletztGesendetAm: am,
    zuletztGesendeterStammId: stammId,
    zuletztGesendeterSnapshotJson: snapshotJson,
  );

  /// Nach neuen Credentials muss erneut gesendet werden, bevor gelesen werden darf.
  BundesstatistikTeilnahme ohneSendestand() => BundesstatistikTeilnahme(
    einwilligungFuer: einwilligungFuer,
    einwilligungAm: einwilligungAm,
    zuletztGesendeterSnapshotJson: zuletztGesendeterSnapshotJson,
  );
}

abstract class BundesstatistikTeilnahmeRepository {
  Future<BundesstatistikTeilnahme> load();
  Future<void> save(BundesstatistikTeilnahme teilnahme);
}

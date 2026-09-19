import 'stufen_settings.dart';

abstract class StufenSettingsRepository {
  Future<StufenSettings> load();
  Future<void> saveAltersgrenzen(StufenSettings settings);
  Future<void> saveStufenwechselDatum(DateTime? date);
}

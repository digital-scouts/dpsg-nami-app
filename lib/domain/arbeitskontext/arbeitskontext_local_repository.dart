import 'arbeitskontext_read_model.dart';

abstract class ArbeitskontextLocalRepository {
  Future<ArbeitskontextReadModel?> loadLastCached();

  Future<void> saveCached(ArbeitskontextReadModel readModel);

  Future<void> clearCached();
}

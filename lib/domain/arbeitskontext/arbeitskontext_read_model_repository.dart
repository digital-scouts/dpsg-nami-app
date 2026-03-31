import 'arbeitskontext.dart';
import 'arbeitskontext_read_model.dart';

abstract class ArbeitskontextReadModelRepository {
  Future<ArbeitskontextReadModel> loadCached(Arbeitskontext arbeitskontext);

  Future<ArbeitskontextReadModel> refresh({
    required String accessToken,
    required Arbeitskontext arbeitskontext,
  });
}

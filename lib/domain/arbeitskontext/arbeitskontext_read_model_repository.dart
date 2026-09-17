import '../../data/arbeitskontext/hitobito_group_resource.dart';
import 'arbeitskontext.dart';
import 'arbeitskontext_read_model.dart';

abstract class ArbeitskontextReadModelRepository {
  Future<ArbeitskontextReadModel> loadCached(Arbeitskontext arbeitskontext);

  Future<ArbeitskontextReadModel> refresh({
    required String accessToken,
    required Arbeitskontext arbeitskontext,
    List<HitobitoGroupResource>? accessibleGroups,
    void Function(ArbeitskontextReadModel partial)? onProgress,
  });

  Future<ArbeitskontextReadModel> loadRoles({
    required String accessToken,
    required ArbeitskontextReadModel readModel,
  });
}

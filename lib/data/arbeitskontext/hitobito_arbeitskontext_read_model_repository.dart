import '../../domain/arbeitskontext/arbeitskontext.dart';
import '../../domain/arbeitskontext/arbeitskontext_local_repository.dart';
import '../../domain/arbeitskontext/arbeitskontext_read_model.dart';
import '../../domain/arbeitskontext/arbeitskontext_read_model_repository.dart';
import '../../domain/member/mitglied.dart';
import '../../services/hitobito_groups_service.dart';
import '../../services/hitobito_people_service.dart';
import 'hitobito_group_resource.dart';
import 'hitobito_person_resource.dart';

class HitobitoArbeitskontextReadModelRepository
    implements ArbeitskontextReadModelRepository {
  HitobitoArbeitskontextReadModelRepository({
    required HitobitoGroupsService groupsService,
    required HitobitoPeopleService peopleService,
    required ArbeitskontextLocalRepository localRepository,
  }) : _groupsService = groupsService,
       _peopleService = peopleService,
       _localRepository = localRepository;

  final HitobitoGroupsService _groupsService;
  final HitobitoPeopleService _peopleService;
  final ArbeitskontextLocalRepository _localRepository;

  @override
  Future<ArbeitskontextReadModel> loadCached(
    Arbeitskontext arbeitskontext,
  ) async {
    final cached = await _localRepository.loadLastCached();
    if (cached == null ||
        cached.arbeitskontext.aktiverLayer.id !=
            arbeitskontext.aktiverLayer.id) {
      return ArbeitskontextReadModel(arbeitskontext: arbeitskontext);
    }

    return cached.copyWith(arbeitskontext: arbeitskontext);
  }

  @override
  Future<ArbeitskontextReadModel> refresh({
    required String accessToken,
    required Arbeitskontext arbeitskontext,
  }) async {
    final accessibleGroupsFuture = _groupsService.fetchAccessibleGroups(
      accessToken,
    );
    final peopleResourcesFuture = _peopleService.fetchPeopleResources(
      accessToken,
    );
    final accessibleGroups = await accessibleGroupsFuture;
    final peopleResources = await peopleResourcesFuture;
    final accessibleLayers = _extractAccessibleLayers(accessibleGroups);
    final relevanteLayer = _resolveRelevantLayers(
      requestedArbeitskontext: arbeitskontext,
      accessibleLayers: accessibleLayers,
    );
    final aktiverLayer = _findOrFallbackActiveLayer(
      requestedLayer: arbeitskontext.aktiverLayer,
      accessibleLayers: relevanteLayer,
    );
    final aktuellerKontext = Arbeitskontext(
      aktiverLayer: aktiverLayer,
      verfuegbareLayer: relevanteLayer,
    );
    final gruppen = _extractKontextGruppen(
      accessibleGroups: accessibleGroups,
      aktiverLayerId: aktuellerKontext.aktiverLayer.id,
    );
    final mitglieder = _extractKontextMitglieder(
      peopleResources: peopleResources,
      accessibleGroups: accessibleGroups,
      aktiverLayerId: aktuellerKontext.aktiverLayer.id,
    );
    final readModel = ArbeitskontextReadModel(
      arbeitskontext: aktuellerKontext,
      mitglieder: mitglieder,
      gruppen: gruppen,
    );
    await _localRepository.saveCached(readModel);
    return readModel;
  }

  List<ArbeitskontextLayer> _resolveRelevantLayers({
    required Arbeitskontext requestedArbeitskontext,
    required List<ArbeitskontextLayer> accessibleLayers,
  }) {
    final accessibleById = <int, ArbeitskontextLayer>{
      for (final layer in accessibleLayers) layer.id: layer,
    };
    final requestedLayers = <ArbeitskontextLayer>[
      requestedArbeitskontext.aktiverLayer,
      ...requestedArbeitskontext.verfuegbareLayer,
    ];
    final resolvedLayers = <ArbeitskontextLayer>[];
    final ids = <int>{};

    for (final layer in requestedLayers) {
      final resolved = accessibleById[layer.id] ?? layer;
      if (!ids.add(resolved.id)) {
        continue;
      }
      resolvedLayers.add(resolved);
    }

    return resolvedLayers;
  }

  List<ArbeitskontextLayer> _extractAccessibleLayers(
    List<HitobitoGroupResource> accessibleGroups,
  ) {
    final ids = <int>{};
    final result = <ArbeitskontextLayer>[];

    for (final group in accessibleGroups) {
      if (!group.isLayer || !ids.add(group.id)) {
        continue;
      }
      result.add(group.toArbeitskontextLayer());
    }

    return result;
  }

  ArbeitskontextLayer _findOrFallbackActiveLayer({
    required ArbeitskontextLayer requestedLayer,
    required List<ArbeitskontextLayer> accessibleLayers,
  }) {
    for (final layer in accessibleLayers) {
      if (layer.id == requestedLayer.id) {
        return layer;
      }
    }

    return requestedLayer;
  }

  List<ArbeitskontextGruppe> _extractKontextGruppen({
    required List<HitobitoGroupResource> accessibleGroups,
    required int aktiverLayerId,
  }) {
    final groupsById = <int, HitobitoGroupResource>{
      for (final group in accessibleGroups) group.id: group,
    };
    final ids = <int>{};
    final result = <ArbeitskontextGruppe>[];

    for (final group in accessibleGroups) {
      if (group.isLayer) {
        continue;
      }

      final resolvedLayerId = _resolveLayerId(group, groupsById);
      if (resolvedLayerId != aktiverLayerId || !ids.add(group.id)) {
        continue;
      }

      final mapped = group.toArbeitskontextGruppe(
        aktiverLayerId: aktiverLayerId,
      );
      if (mapped != null) {
        result.add(mapped);
      }
    }

    return result;
  }

  List<Mitglied> _extractKontextMitglieder({
    required List<HitobitoPersonResource> peopleResources,
    required List<HitobitoGroupResource> accessibleGroups,
    required int aktiverLayerId,
  }) {
    final groupsById = <int, HitobitoGroupResource>{
      for (final group in accessibleGroups) group.id: group,
    };
    final ids = <String>{};
    final result = <Mitglied>[];

    for (final person in peopleResources) {
      final resolvedLayerId = _resolvePersonLayerId(
        person.primaryGroupId,
        groupsById,
      );
      if (resolvedLayerId != aktiverLayerId) {
        continue;
      }

      final mitglied = person.toMitglied();
      if (!ids.add(mitglied.mitgliedsnummer)) {
        continue;
      }

      result.add(mitglied);
    }

    return result;
  }

  int? _resolvePersonLayerId(
    int? primaryGroupId,
    Map<int, HitobitoGroupResource> groupsById,
  ) {
    if (primaryGroupId == null) {
      return null;
    }

    final primaryGroup = groupsById[primaryGroupId];
    if (primaryGroup == null) {
      return primaryGroupId;
    }

    return _resolveLayerId(primaryGroup, groupsById);
  }

  int? _resolveLayerId(
    HitobitoGroupResource group,
    Map<int, HitobitoGroupResource> groupsById,
  ) {
    if (group.isLayer) {
      return group.id;
    }
    if (group.layerGroupId != null && group.layerGroupId! > 0) {
      return group.layerGroupId;
    }
    final parentId = group.parentId;
    if (parentId == null) {
      return null;
    }
    final parent = groupsById[parentId];
    if (parent == null) {
      return null;
    }
    if (parent.isLayer) {
      return parent.id;
    }
    return parent.layerGroupId;
  }
}

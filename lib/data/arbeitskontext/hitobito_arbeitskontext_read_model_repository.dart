import '../../domain/arbeitskontext/arbeitskontext.dart';
import '../../domain/arbeitskontext/arbeitskontext_local_repository.dart';
import '../../domain/arbeitskontext/arbeitskontext_read_model.dart';
import '../../domain/arbeitskontext/arbeitskontext_read_model_repository.dart';
import '../../domain/member/mitglied.dart';
import '../../domain/taetigkeit/roles.dart';
import '../../services/hitobito_groups_service.dart';
import '../../services/hitobito_people_service.dart';
import '../../services/hitobito_roles_service.dart';
import 'hitobito_group_resource.dart';
import 'hitobito_person_resource.dart';

class HitobitoArbeitskontextReadModelRepository
    implements ArbeitskontextReadModelRepository {
  HitobitoArbeitskontextReadModelRepository({
    required HitobitoGroupsService groupsService,
    required HitobitoPeopleService peopleService,
    HitobitoRolesService? rolesService,
    required ArbeitskontextLocalRepository localRepository,
  }) : _groupsService = groupsService,
       _peopleService = peopleService,
       _rolesService = rolesService,
       _localRepository = localRepository;

  final HitobitoGroupsService _groupsService;
  final HitobitoPeopleService _peopleService;
  final HitobitoRolesService? _rolesService;
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
    final mitgliedsdaten = _extractKontextMitgliedsdaten(
      peopleResources: peopleResources,
      accessibleGroups: accessibleGroups,
      aktiverLayerId: aktuellerKontext.aktiverLayer.id,
    );
    final readModel = ArbeitskontextReadModel(
      arbeitskontext: aktuellerKontext,
      mitglieder: mitgliedsdaten.mitglieder,
      gruppen: gruppen,
      mitgliedsZuordnungen: mitgliedsdaten.mitgliedsZuordnungen,
    );
    await _localRepository.saveCached(readModel);
    return readModel;
  }

  @override
  Future<ArbeitskontextReadModel> loadRoles({
    required String accessToken,
    required ArbeitskontextReadModel readModel,
  }) async {
    if (readModel.rolesSindGeladen) {
      return readModel;
    }

    final rolesService = _rolesService;
    if (rolesService == null) {
      return readModel;
    }

    final personIdsToMitglieder = <int, Mitglied>{
      for (final mitglied in readModel.mitglieder)
        if (mitglied.personId != null && mitglied.personId! > 0)
          mitglied.personId!: mitglied,
    };
    final relevanteGruppenIds = <int>{
      readModel.arbeitskontext.aktiverLayer.id,
      ...readModel.gruppen.map((gruppe) => gruppe.id),
    };
    final gruppenNamenById = <int, String>{
      readModel.arbeitskontext.aktiverLayer.id:
          readModel.arbeitskontext.aktiverLayer.name,
      for (final gruppe in readModel.gruppen) gruppe.id: gruppe.name,
    };
    final rollen = await rolesService.fetchRoleResources(accessToken);
    final rolesByMitgliedsnummer = <String, List<Role>>{};

    for (final role in rollen) {
      final personId = role.personId;
      if (personId == null || !relevanteGruppenIds.contains(role.groupId)) {
        continue;
      }

      final mitglied = personIdsToMitglieder[personId];
      if (mitglied == null) {
        continue;
      }

      rolesByMitgliedsnummer
          .putIfAbsent(mitglied.mitgliedsnummer, () => <Role>[])
          .add(
            _mapRoleToDomainRole(
              role: role,
              mitglied: mitglied,
              gruppenName: gruppenNamenById[role.groupId],
            ),
          );
    }

    final updated = readModel.copyWith(
      rolesSindGeladen: true,
      mitglieder: readModel.mitglieder.map((mitglied) {
        final roles = rolesByMitgliedsnummer[mitglied.mitgliedsnummer];
        return mitglied.copyWith(roles: roles ?? const <Role>[]);
      }),
    );
    await _localRepository.saveCached(updated);
    return updated;
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

  _KontextMitgliedsdaten _extractKontextMitgliedsdaten({
    required List<HitobitoPersonResource> peopleResources,
    required List<HitobitoGroupResource> accessibleGroups,
    required int aktiverLayerId,
  }) {
    final groupsById = <int, HitobitoGroupResource>{
      for (final group in accessibleGroups) group.id: group,
    };
    final ids = <String>{};
    final mitglieder = <Mitglied>[];
    final mitgliedsZuordnungen = <ArbeitskontextMitgliedsZuordnung>[];

    for (final person in peopleResources) {
      final relevanteRollen = _extractRelevanteRollenZuordnungen(
        person: person,
        groupsById: groupsById,
        aktiverLayerId: aktiverLayerId,
      );
      final hatRolleImAktivenLayer = _hasRolleImAktivenLayer(
        person: person,
        groupsById: groupsById,
        aktiverLayerId: aktiverLayerId,
      );
      final resolvedPrimaryLayerId = _resolveGroupLayerId(
        person.primaryGroupId,
        groupsById,
      );
      final gehoertZumAktivenLayer =
          hatRolleImAktivenLayer || resolvedPrimaryLayerId == aktiverLayerId;
      if (!gehoertZumAktivenLayer) {
        continue;
      }

      final mitglied = person.toMitglied();
      if (!ids.add(mitglied.mitgliedsnummer)) {
        mitgliedsZuordnungen.addAll(relevanteRollen);
        continue;
      }

      mitglieder.add(mitglied);
      mitgliedsZuordnungen.addAll(relevanteRollen);
    }

    return _KontextMitgliedsdaten(
      mitglieder: mitglieder,
      mitgliedsZuordnungen: mitgliedsZuordnungen,
    );
  }

  List<ArbeitskontextMitgliedsZuordnung> _extractRelevanteRollenZuordnungen({
    required HitobitoPersonResource person,
    required Map<int, HitobitoGroupResource> groupsById,
    required int aktiverLayerId,
  }) {
    final result = <ArbeitskontextMitgliedsZuordnung>[];

    for (final role in person.roles) {
      final group = groupsById[role.groupId];
      if (group == null || group.isLayer) {
        continue;
      }

      final resolvedLayerId = _resolveLayerId(group, groupsById);
      if (resolvedLayerId != aktiverLayerId) {
        continue;
      }

      result.add(role.toMitgliedsZuordnung(mitgliedsnummer: person.memberId));
    }

    return result;
  }

  bool _hasRolleImAktivenLayer({
    required HitobitoPersonResource person,
    required Map<int, HitobitoGroupResource> groupsById,
    required int aktiverLayerId,
  }) {
    for (final role in person.roles) {
      final group = groupsById[role.groupId];
      if (group == null) {
        continue;
      }

      final resolvedLayerId = _resolveLayerId(group, groupsById);
      if (resolvedLayerId == aktiverLayerId) {
        return true;
      }
    }

    return false;
  }

  int? _resolveGroupLayerId(
    int? groupId,
    Map<int, HitobitoGroupResource> groupsById,
  ) {
    if (groupId == null) {
      return null;
    }

    final group = groupsById[groupId];
    if (group == null) {
      return groupId;
    }

    return _resolveLayerId(group, groupsById);
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

  Role _mapRoleToDomainRole({
    required HitobitoPersonRoleResource role,
    required Mitglied mitglied,
    required String? gruppenName,
  }) {
    return Role(
      id: role.id,
      createdAt: role.createdAt,
      updatedAt: role.updatedAt,
      startOn: role.startOn ?? mitglied.eintrittsdatum,
      endOn: role.endOn,
      name: role.roleName,
      personId: role.personId ?? mitglied.personId,
      groupId: role.groupId,
      type: role.roleType,
      label: role.roleLabel ?? role.resolvedRoleLabel ?? gruppenName,
    );
  }
}

class _KontextMitgliedsdaten {
  const _KontextMitgliedsdaten({
    required this.mitglieder,
    required this.mitgliedsZuordnungen,
  });

  final List<Mitglied> mitglieder;
  final List<ArbeitskontextMitgliedsZuordnung> mitgliedsZuordnungen;
}

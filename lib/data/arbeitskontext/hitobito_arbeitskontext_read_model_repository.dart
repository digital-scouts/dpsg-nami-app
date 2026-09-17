import '../../domain/arbeitskontext/arbeitskontext.dart';
import '../../domain/arbeitskontext/arbeitskontext_local_repository.dart';
import '../../domain/arbeitskontext/arbeitskontext_read_model.dart';
import '../../domain/arbeitskontext/arbeitskontext_read_model_repository.dart';
import '../../domain/member/mitglied.dart';
import '../../domain/taetigkeit/roles.dart';
import '../../services/hitobito_groups_service.dart';
import '../../services/hitobito_people_service.dart';
import '../../services/hitobito_roles_service.dart';
import '../../services/logger_service.dart';
import 'hitobito_group_resource.dart';
import 'hitobito_person_resource.dart';

class HitobitoArbeitskontextReadModelRepository
    implements ArbeitskontextReadModelRepository {
  HitobitoArbeitskontextReadModelRepository({
    required HitobitoGroupsService groupsService,
    required HitobitoPeopleService peopleService,
    HitobitoRolesService? rolesService,
    required ArbeitskontextLocalRepository localRepository,
    LoggerService? logger,
  }) : _groupsService = groupsService,
       _peopleService = peopleService,
       _rolesService = rolesService,
       _localRepository = localRepository,
       _logger = logger;

  final HitobitoGroupsService _groupsService;
  final HitobitoPeopleService _peopleService;
  final HitobitoRolesService? _rolesService;
  final ArbeitskontextLocalRepository _localRepository;
  final LoggerService? _logger;

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
    List<HitobitoGroupResource>? accessibleGroups,
    void Function(ArbeitskontextReadModel partial)? onProgress,
  }) async {
    // Gruppen werden bewusst VOR den Mitgliedern/Rollen vollstaendig geladen:
    // fuer ein Fortschritts-Readmodel pro Seite (onProgress) muessen die
    // Gruppen schon vollstaendig bekannt sein, damit
    // _extractKontextMitgliedsdaten() die Layer-Zugehoerigkeit korrekt
    // filtern kann. Gruppen sind ueblicherweise 1-3 schnelle Requests, der
    // Verlust der Parallelitaet dazu ist gering.
    final resolvedAccessibleGroups =
        accessibleGroups ??
        await _groupsService.fetchAccessibleGroups(accessToken);
    final accessibleLayers = _extractAccessibleLayers(resolvedAccessibleGroups);
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
      accessibleGroups: resolvedAccessibleGroups,
      aktiverLayerId: aktuellerKontext.aktiverLayer.id,
    );

    // Personen und Rollen werden bewusst PARALLEL geladen (statt erst alle
    // Personen, dann alle Rollen): beides sind unabhaengige GET-Endpunkte,
    // und bereits eingetroffene Rollen koennen so sofort auf bereits bekannte
    // Mitglieder angewendet werden, statt erst ganz am Ende in einem Rutsch
    // sichtbar zu werden. Ein Fehler beim Rollen-Fetch darf den
    // Mitglieder-Refresh nicht scheitern lassen (siehe _fetchRolesIsolated) -
    // ensureRolesLoaded() holt Rollen in dem Fall eigenstaendig nochmal nach.
    var latestPeople = const <HitobitoPersonResource>[];
    var latestRoles = const <HitobitoPersonRoleResource>[];

    void emitProgress() {
      if (onProgress == null) {
        return;
      }
      final partialMitgliedsdaten = _extractKontextMitgliedsdaten(
        peopleResources: latestPeople,
        accessibleGroups: resolvedAccessibleGroups,
        aktiverLayerId: aktuellerKontext.aktiverLayer.id,
      );
      onProgress(
        ArbeitskontextReadModel(
          arbeitskontext: aktuellerKontext,
          mitglieder: _attachRollenZuMitgliedern(
            mitglieder: partialMitgliedsdaten.mitglieder,
            rollen: latestRoles,
            gruppen: gruppen,
            arbeitskontext: aktuellerKontext,
          ),
          gruppen: gruppen,
          mitgliedsZuordnungen: partialMitgliedsdaten.mitgliedsZuordnungen,
        ),
      );
    }

    final peopleFuture = _peopleService.fetchPeopleResources(
      accessToken,
      onPageLoaded: (loadedSoFar) {
        latestPeople = loadedSoFar;
        emitProgress();
      },
    );
    final rolesFuture = _fetchRolesIsolated(
      accessToken: accessToken,
      onLoadedSoFar: (loadedSoFar) {
        latestRoles = loadedSoFar;
        emitProgress();
      },
    );

    final peopleResources = await peopleFuture;
    final rolesResult = await rolesFuture;

    final mitgliedsdaten = _extractKontextMitgliedsdaten(
      peopleResources: peopleResources,
      accessibleGroups: resolvedAccessibleGroups,
      aktiverLayerId: aktuellerKontext.aktiverLayer.id,
    );
    final mitgliederMitRollen = rolesResult.succeeded
        ? _attachRollenZuMitgliedern(
            mitglieder: mitgliedsdaten.mitglieder,
            rollen: rolesResult.rollen,
            gruppen: gruppen,
            arbeitskontext: aktuellerKontext,
          )
        : mitgliedsdaten.mitglieder;

    final readModel = ArbeitskontextReadModel(
      arbeitskontext: aktuellerKontext,
      mitglieder: mitgliederMitRollen,
      gruppen: gruppen,
      mitgliedsZuordnungen: mitgliedsdaten.mitgliedsZuordnungen,
      rolesSindGeladen: rolesResult.succeeded,
    );
    await _localRepository.saveCached(readModel);
    return readModel;
  }

  /// Kapselt den zu [refresh] parallel laufenden Rollen-Fetch: ein Fehler
  /// hier darf den Mitglieder-Refresh nicht mit reissen. ensureRolesLoaded()
  /// (ueber ArbeitskontextModel.loadRoles) holt Rollen in dem Fall separat
  /// nochmal nach.
  Future<_RollenFetchResult> _fetchRolesIsolated({
    required String accessToken,
    required void Function(List<HitobitoPersonRoleResource> loadedSoFar)
    onLoadedSoFar,
  }) async {
    final rolesService = _rolesService;
    if (rolesService == null) {
      return const _RollenFetchResult(
        rollen: <HitobitoPersonRoleResource>[],
        succeeded: false,
      );
    }

    try {
      final rollen = await rolesService.fetchRoleResources(
        accessToken,
        onPageLoaded: onLoadedSoFar,
      );
      return _RollenFetchResult(rollen: rollen, succeeded: true);
    } catch (error, stack) {
      await _logger?.logWarn(
        'arbeitskontext_repository',
        'Paralleles Rollen-Laden waehrend refresh() fehlgeschlagen: '
            '$error\n$stack',
      );
      return const _RollenFetchResult(
        rollen: <HitobitoPersonRoleResource>[],
        succeeded: false,
      );
    }
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

    final rollen = await rolesService.fetchRoleResources(accessToken);
    final updated = readModel.copyWith(
      rolesSindGeladen: true,
      mitglieder: _attachRollenZuMitgliedern(
        mitglieder: readModel.mitglieder,
        rollen: rollen,
        gruppen: readModel.gruppen,
        arbeitskontext: readModel.arbeitskontext,
      ),
    );
    await _localRepository.saveCached(updated);
    return updated;
  }

  /// Ordnet [rollen] den passenden [mitglieder] per personId zu und liefert
  /// eine neue Mitgliederliste mit gesetztem `roles`-Feld. Wird sowohl vom
  /// parallelen Rollen-Fetch in [refresh] als auch von [loadRoles] genutzt,
  /// damit die Zuordnungslogik nicht doppelt gepflegt werden muss.
  List<Mitglied> _attachRollenZuMitgliedern({
    required List<Mitglied> mitglieder,
    required List<HitobitoPersonRoleResource> rollen,
    required List<ArbeitskontextGruppe> gruppen,
    required Arbeitskontext arbeitskontext,
  }) {
    final personIdsToMitglieder = <int, Mitglied>{
      for (final mitglied in mitglieder)
        if (mitglied.personId != null && mitglied.personId! > 0)
          mitglied.personId!: mitglied,
    };
    final gruppenNamenById = <int, String>{
      arbeitskontext.aktiverLayer.id: arbeitskontext.aktiverLayer.name,
      for (final gruppe in gruppen) gruppe.id: gruppe.name,
    };
    final rolesByMitgliedsnummer = <String, List<Role>>{};

    for (final role in rollen) {
      final personId = role.personId;
      if (personId == null) {
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

    return mitglieder
        .map(
          (mitglied) => mitglied.copyWith(
            roles:
                rolesByMitgliedsnummer[mitglied.mitgliedsnummer] ??
                const <Role>[],
          ),
        )
        .toList(growable: false);
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

class _RollenFetchResult {
  const _RollenFetchResult({required this.rollen, required this.succeeded});

  final List<HitobitoPersonRoleResource> rollen;
  final bool succeeded;
}

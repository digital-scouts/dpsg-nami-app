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
    final uebergeordneteGruppenIds = _extractUebergeordneteGruppenIds(
      accessibleGroups: resolvedAccessibleGroups,
      accessibleLayers: accessibleLayers,
      aktiverLayer: aktuellerKontext.aktiverLayer,
    );

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
          uebergeordneteGruppenIds: uebergeordneteGruppenIds,
        ),
      );
    }

    final rolesService = _rolesService;
    final List<HitobitoPersonResource> peopleResources;
    final _RollenFetchResult rolesResult;
    if (rolesService == null) {
      peopleResources = await _peopleService.fetchPeopleResources(
        accessToken,
        onPageLoaded: (loadedSoFar) {
          latestPeople = loadedSoFar;
          emitProgress();
        },
      );
      rolesResult = const _RollenFetchResult(
        rollen: <HitobitoPersonRoleResource>[],
        succeeded: false,
      );
    } else {
      // Nur die Personen des aktiven Layers laden statt aller lesbaren
      // Personen der Instanz - die App verwirft alle anderen ohnehin in
      // _extractKontextMitgliedsdaten(). Zum Layer gehoert, wer dort eine
      // Rolle hat oder dort seine Hauptgruppe hat. Die API kennt keinen
      // Personenfilter ueber Rollen, deshalb in zwei Schritten:
      // 1. parallel: Rollen der Layergruppen (liefert die person_ids) und
      //    Personen mit Hauptgruppe im Layer,
      // 2. parallel: die noch fehlenden Personen per filter[id] und alle
      //    Rollen dieser Personen per filter[person_id] (auch Rollen
      //    ausserhalb des Layers, wie bisher).
      final layerGruppenIds = _extractLayerGruppenIds(
        accessibleGroups: resolvedAccessibleGroups,
        aktiverLayerId: aktuellerKontext.aktiverLayer.id,
      ).toList()..sort();
      final layerGruppenFilter = layerGruppenIds.join(',');

      final layerRollenFuture = rolesService.fetchRoleResources(
        accessToken,
        filter: <String, String>{'filter[group_id]': layerGruppenFilter},
      );
      final hauptgruppenPeopleFuture = _peopleService.fetchPeopleResources(
        accessToken,
        filter: <String, String>{
          'filter[primary_group_id]': layerGruppenFilter,
        },
        onPageLoaded: (loadedSoFar) {
          latestPeople = loadedSoFar;
          emitProgress();
        },
      );
      await Future.wait<void>(<Future<void>>[
        layerRollenFuture,
        hauptgruppenPeopleFuture,
      ]);
      final layerRollen = await layerRollenFuture;
      final hauptgruppenPeople = await hauptgruppenPeopleFuture;

      final bekanntePersonIds = <int>{
        for (final person in hauptgruppenPeople) person.id,
      };
      final fehlendePersonIds = <int>{
        for (final rolle in layerRollen)
          if (rolle.personId != null &&
              !bekanntePersonIds.contains(rolle.personId))
            rolle.personId!,
      };

      final weiterePeopleFuture = _fetchPeopleByIds(
        accessToken: accessToken,
        personIds: fehlendePersonIds,
        onLoadedSoFar: (loadedSoFar) {
          latestPeople = <HitobitoPersonResource>[
            ...hauptgruppenPeople,
            ...loadedSoFar,
          ];
          emitProgress();
        },
      );
      final rolesFuture = _fetchRolesIsolated(
        accessToken: accessToken,
        personIds: <int>{...bekanntePersonIds, ...fehlendePersonIds},
        onLoadedSoFar: (loadedSoFar) {
          latestRoles = loadedSoFar;
          emitProgress();
        },
      );

      peopleResources = <HitobitoPersonResource>[
        ...hauptgruppenPeople,
        ...await weiterePeopleFuture,
      ];
      rolesResult = await rolesFuture;
    }

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
      uebergeordneteGruppenIds: uebergeordneteGruppenIds,
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
    required Set<int> personIds,
    required void Function(List<HitobitoPersonRoleResource> loadedSoFar)
    onLoadedSoFar,
  }) async {
    try {
      final rollen = await _fetchRolesByPersonIds(
        accessToken: accessToken,
        personIds: personIds,
        onLoadedSoFar: onLoadedSoFar,
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

  /// Hoechstzahl IDs pro gefiltertem Request. Haelt die URL kurz und verteilt
  /// grosse Layer auf parallele Requests, die der Server gleichzeitig
  /// bearbeitet.
  static const int _idsProRequest = 200;

  Future<List<HitobitoPersonResource>> _fetchPeopleByIds({
    required String accessToken,
    required Set<int> personIds,
    required void Function(List<HitobitoPersonResource> loadedSoFar)
    onLoadedSoFar,
  }) {
    return _fetchInIdBloecken<HitobitoPersonResource>(
      ids: personIds,
      onLoadedSoFar: onLoadedSoFar,
      fetch: (idFilter) => _peopleService.fetchPeopleResources(
        accessToken,
        filter: <String, String>{'filter[id]': idFilter},
      ),
    );
  }

  Future<List<HitobitoPersonRoleResource>> _fetchRolesByPersonIds({
    required String accessToken,
    required Set<int> personIds,
    void Function(List<HitobitoPersonRoleResource> loadedSoFar)? onLoadedSoFar,
  }) {
    final rolesService = _rolesService;
    if (rolesService == null) {
      return Future.value(const <HitobitoPersonRoleResource>[]);
    }
    return _fetchInIdBloecken<HitobitoPersonRoleResource>(
      ids: personIds,
      onLoadedSoFar: onLoadedSoFar,
      fetch: (idFilter) => rolesService.fetchRoleResources(
        accessToken,
        filter: <String, String>{'filter[person_id]': idFilter},
      ),
    );
  }

  /// Laedt [ids] in Bloecken von [_idsProRequest] parallel und meldet nach
  /// jedem fertigen Block den kumulierten Stand.
  Future<List<T>> _fetchInIdBloecken<T>({
    required Set<int> ids,
    required Future<List<T>> Function(String idFilter) fetch,
    void Function(List<T> loadedSoFar)? onLoadedSoFar,
  }) async {
    if (ids.isEmpty) {
      return <T>[];
    }
    final sortierteIds = ids.toList()..sort();
    final geladen = <T>[];
    final bloecke = <Future<void>>[
      for (var start = 0; start < sortierteIds.length; start += _idsProRequest)
        fetch(
          sortierteIds
              .sublist(
                start,
                start + _idsProRequest > sortierteIds.length
                    ? sortierteIds.length
                    : start + _idsProRequest,
              )
              .join(','),
        ).then((block) {
          geladen.addAll(block);
          onLoadedSoFar?.call(List.unmodifiable(geladen));
        }),
    ];
    await Future.wait<void>(bloecke);
    return geladen;
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

    final rollen = await _fetchRolesByPersonIds(
      accessToken: accessToken,
      personIds: <int>{
        for (final mitglied in readModel.mitglieder)
          if (mitglied.personId != null && mitglied.personId! > 0)
            mitglied.personId!,
      },
    );
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

  /// Gruppen in Layern oberhalb des aktiven Layers (Bezirk, Dioezese ...).
  Set<int> _extractUebergeordneteGruppenIds({
    required List<HitobitoGroupResource> accessibleGroups,
    required List<ArbeitskontextLayer> accessibleLayers,
    required ArbeitskontextLayer aktiverLayer,
  }) {
    final layerById = <int, ArbeitskontextLayer>{
      for (final layer in accessibleLayers) layer.id: layer,
    };
    final vorfahren = <int>{};
    var parentId =
        layerById[aktiverLayer.id]?.parentLayerId ?? aktiverLayer.parentLayerId;
    while (parentId != null && vorfahren.add(parentId)) {
      parentId = layerById[parentId]?.parentLayerId;
    }
    if (vorfahren.isEmpty) {
      return const <int>{};
    }

    final groupsById = <int, HitobitoGroupResource>{
      for (final group in accessibleGroups) group.id: group,
    };
    return <int>{
      for (final group in accessibleGroups)
        if (vorfahren.contains(
          group.isLayer ? group.id : _resolveLayerId(group, groupsById),
        ))
          group.id,
    };
  }

  /// Der aktive Layer selbst plus alle lesbaren Gruppen darunter, die nicht
  /// zu einem Unterlayer gehoeren - dieselbe Zuordnung wie in
  /// _extractKontextMitgliedsdaten().
  Set<int> _extractLayerGruppenIds({
    required List<HitobitoGroupResource> accessibleGroups,
    required int aktiverLayerId,
  }) {
    final groupsById = <int, HitobitoGroupResource>{
      for (final group in accessibleGroups) group.id: group,
    };
    return <int>{
      aktiverLayerId,
      for (final group in accessibleGroups)
        if (_resolveLayerId(group, groupsById) == aktiverLayerId) group.id,
    };
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

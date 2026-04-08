import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/arbeitskontext/hitobito_group_resource.dart';
import '../../domain/arbeitskontext/arbeitskontext.dart';
import '../../domain/arbeitskontext/arbeitskontext_local_repository.dart';
import '../../domain/arbeitskontext/arbeitskontext_read_model.dart';
import '../../domain/arbeitskontext/arbeitskontext_read_model_repository.dart';
import '../../domain/arbeitskontext/relevante_layer_input.dart';
import '../../domain/arbeitskontext/startkontext_input.dart';
import '../../domain/arbeitskontext/usecases/bestimme_relevante_layer_usecase.dart';
import '../../domain/arbeitskontext/usecases/bestimme_startkontext_usecase.dart';
import '../../domain/auth/auth_profile.dart';
import '../../domain/auth/auth_session.dart';
import '../../domain/auth/auth_state.dart';
import '../../services/hitobito_groups_service.dart';
import '../../services/logger_service.dart';

enum ArbeitskontextStatus { initial, loading, ready, unauthorized, error }

class ArbeitskontextModel extends ChangeNotifier {
  static const String layerSwitchFailedMessage =
      'Layer konnte nicht gewechselt werden';

  ArbeitskontextModel({
    required ArbeitskontextLocalRepository localRepository,
    required ArbeitskontextReadModelRepository readModelRepository,
    required HitobitoGroupsService groupsService,
    required BestimmeStartkontextUseCase bestimmeStartkontextUseCase,
    BestimmeRelevanteLayerUseCase bestimmeRelevanteLayerUseCase =
        const BestimmeRelevanteLayerUseCase(),
    required LoggerService logger,
  }) : _localRepository = localRepository,
       _readModelRepository = readModelRepository,
       _groupsService = groupsService,
       _bestimmeStartkontextUseCase = bestimmeStartkontextUseCase,
       _bestimmeRelevanteLayerUseCase = bestimmeRelevanteLayerUseCase,
       _logger = logger;

  final ArbeitskontextLocalRepository _localRepository;
  final ArbeitskontextReadModelRepository _readModelRepository;
  final HitobitoGroupsService _groupsService;
  final BestimmeStartkontextUseCase _bestimmeStartkontextUseCase;
  final BestimmeRelevanteLayerUseCase _bestimmeRelevanteLayerUseCase;
  final LoggerService _logger;

  static const String unauthorizedMessage =
      'Du hast nicht die notwendigen Berechtigungen um die App zu nutzen';
  static const Set<String> _exactLayerPermissions = <String>{
    'layer_full',
    'layer_read',
    'group_read',
    'group_and_below_full',
    'group_and_below_read',
  };
  static const Set<String> _layerAndBelowPermissions = <String>{
    'layer_and_below_full',
    'layer_and_below_read',
  };

  ArbeitskontextStatus _status = ArbeitskontextStatus.initial;
  Arbeitskontext? _arbeitskontext;
  ArbeitskontextReadModel? _readModel;
  AuthSession? _session;
  String? _errorMessage;
  int? _activeProfileId;
  String? _profileFingerprint;
  bool _isSynchronizing = false;
  bool _isSwitchingLayer = false;
  bool _isLoadingRoles = false;

  ArbeitskontextStatus get status => _status;
  Arbeitskontext? get arbeitskontext => _arbeitskontext;
  ArbeitskontextReadModel? get readModel => _readModel;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _status == ArbeitskontextStatus.loading;
  bool get isReady => _status == ArbeitskontextStatus.ready;
  bool get isUnauthorized => _status == ArbeitskontextStatus.unauthorized;
  bool get hasError => _status == ArbeitskontextStatus.error;
  bool get isSwitchingLayer => _isSwitchingLayer;
  bool get isLoadingRoles => _isLoadingRoles;
  bool get areRolesLoaded => _readModel?.rolesSindGeladen ?? false;

  Future<void> syncForAuth({
    required AuthState authState,
    required AuthSession? session,
    required AuthProfile? profile,
  }) async {
    final mustClear =
        authState == AuthState.signedOut ||
        authState == AuthState.error ||
        authState == AuthState.reloginRequired ||
        profile == null;

    if (mustClear) {
      _resetState();
      return;
    }

    _session = session;
    await initializeForProfile(profile, session: session);
  }

  Future<void> initializeForProfile(
    AuthProfile profile, {
    required AuthSession? session,
    bool force = false,
  }) async {
    final fingerprint = _buildProfileFingerprint(profile);
    if (_isSynchronizing) {
      return;
    }
    if (!force &&
        _status == ArbeitskontextStatus.ready &&
        _activeProfileId == profile.namiId &&
        _profileFingerprint == fingerprint &&
        _arbeitskontext != null) {
      return;
    }

    _isSynchronizing = true;
    _status = ArbeitskontextStatus.loading;
    _errorMessage = null;
    _activeProfileId = profile.namiId;
    _profileFingerprint = fingerprint;
    notifyListeners();

    try {
      final cached = await _localRepository.loadLastCached();
      if (cached != null) {
        _readModel = cached;
        _arbeitskontext = cached.arbeitskontext;
        _status = ArbeitskontextStatus.ready;
        await _logger.log(
          'arbeitskontext',
          'Arbeitskontext erfolgreich aus lokalem Cache geladen: layer=${cached.arbeitskontext.aktiverLayer.id} name=${cached.arbeitskontext.aktiverLayer.name}',
        );
        _scheduleRolesPreload();
        return;
      }

      if (session == null || session.accessToken.isEmpty) {
        throw StateError(
          'Es ist keine gueltige Session fuer den Arbeitskontext verfuegbar.',
        );
      }

      final accessibleGroups = await _groupsService.fetchAccessibleGroups(
        session.accessToken,
      );
      final arbeitskontext = _bestimmeStartkontext(
        profile: profile,
        accessibleGroups: accessibleGroups,
      );
      if (arbeitskontext == null) {
        _setUnauthorizedState();
        return;
      }

      _readModel = await _readModelRepository.refresh(
        accessToken: session.accessToken,
        arbeitskontext: arbeitskontext,
      );
      _arbeitskontext = _readModel?.arbeitskontext;
      _status = ArbeitskontextStatus.ready;
      if (_arbeitskontext != null) {
        await _logger.log(
          'arbeitskontext',
          'Arbeitskontext erfolgreich remote geladen: layer=${_arbeitskontext!.aktiverLayer.id} name=${_arbeitskontext!.aktiverLayer.name} gruppen=${_readModel?.gruppen.length ?? 0} mitglieder=${_readModel?.mitglieder.length ?? 0}',
        );
      }
      _scheduleRolesPreload();
    } catch (error, stack) {
      await _logger.log(
        'arbeitskontext',
        'Arbeitskontext konnte nicht initialisiert werden: $error\n$stack',
      );
      _arbeitskontext = null;
      _readModel = null;
      _status = ArbeitskontextStatus.error;
      _errorMessage = error.toString();
    } finally {
      _isSynchronizing = false;
      notifyListeners();
    }
  }

  Future<void> retry(AuthProfile? profile) async {
    if (profile == null) {
      return;
    }

    await initializeForProfile(profile, session: _session, force: true);
  }

  Future<void> refreshFromRemote({
    required AuthSession? session,
    required AuthProfile? profile,
  }) async {
    if (session == null || profile == null || session.accessToken.isEmpty) {
      return;
    }

    _session = session;
    if (_isSynchronizing) {
      return;
    }

    final previousStatus = _status;
    _isSynchronizing = true;
    if (_status != ArbeitskontextStatus.ready) {
      _status = ArbeitskontextStatus.loading;
      notifyListeners();
    }

    try {
      final accessibleGroups = await _groupsService.fetchAccessibleGroups(
        session.accessToken,
      );
      final nextArbeitskontext = _arbeitskontext != null
          ? _mergeCurrentKontext(
              current: _arbeitskontext!,
              profile: profile,
              accessibleGroups: accessibleGroups,
            )
          : _bestimmeStartkontext(
              profile: profile,
              accessibleGroups: accessibleGroups,
            );
      if (nextArbeitskontext == null) {
        _setUnauthorizedState();
        return;
      }
      _readModel = await _readModelRepository.refresh(
        accessToken: session.accessToken,
        arbeitskontext: nextArbeitskontext,
      );
      _arbeitskontext = _readModel?.arbeitskontext;
      _errorMessage = null;
      _status = ArbeitskontextStatus.ready;
      if (_arbeitskontext != null) {
        await _logger.log(
          'arbeitskontext',
          'Arbeitskontext erfolgreich aktualisiert: layer=${_arbeitskontext!.aktiverLayer.id} name=${_arbeitskontext!.aktiverLayer.name} gruppen=${_readModel?.gruppen.length ?? 0} mitglieder=${_readModel?.mitglieder.length ?? 0}',
        );
      }
      _scheduleRolesPreload();
    } catch (error, stack) {
      await _logger.log(
        'arbeitskontext',
        'Arbeitskontext-Refresh fehlgeschlagen: $error\n$stack',
      );
      _status = previousStatus == ArbeitskontextStatus.initial
          ? ArbeitskontextStatus.error
          : previousStatus;
      _errorMessage = error.toString();
    } finally {
      _isSynchronizing = false;
      notifyListeners();
    }
  }

  Future<bool> ensureRolesLoaded() async {
    return _loadRoles(surfaceErrors: true);
  }

  Future<bool> _loadRoles({required bool surfaceErrors}) async {
    final currentReadModel = _readModel;
    final session = _session;
    if (currentReadModel == null) {
      return false;
    }
    if (currentReadModel.rolesSindGeladen) {
      return true;
    }
    if (_isSynchronizing || _isSwitchingLayer || _isLoadingRoles) {
      return false;
    }
    if (session == null || session.accessToken.isEmpty) {
      return false;
    }

    _isLoadingRoles = true;
    if (surfaceErrors) {
      _errorMessage = null;
    }
    notifyListeners();

    try {
      _readModel = await _readModelRepository.loadRoles(
        accessToken: session.accessToken,
        readModel: currentReadModel,
      );
      _arbeitskontext = _readModel?.arbeitskontext;
      await _logger.log(
        'arbeitskontext',
        'Roles erfolgreich nachgeladen: layer=${_arbeitskontext?.aktiverLayer.id} mitglieder=${_readModel?.mitglieder.length ?? 0}',
      );
      return true;
    } catch (error, stack) {
      await _logger.log(
        'arbeitskontext',
        'Roles-Nachladen fehlgeschlagen: $error\n$stack',
      );
      if (surfaceErrors) {
        _errorMessage = error.toString();
      }
      return false;
    } finally {
      _isLoadingRoles = false;
      notifyListeners();
    }
  }

  Future<bool> switchToLayer({
    required ArbeitskontextLayer targetLayer,
    required AuthSession? session,
    required AuthProfile? profile,
  }) async {
    final current = _arbeitskontext;
    if (current == null || session == null || profile == null) {
      await _logger.logWarn(
        'arbeitskontext',
        'layer switch rejected reason=missing_context target=${targetLayer.id}',
      );
      _errorMessage =
          'Der Arbeitskontext kann ohne gueltige Sitzung nicht gewechselt werden.';
      notifyListeners();
      return false;
    }

    if (_isSynchronizing || _isSwitchingLayer) {
      return false;
    }

    if (targetLayer.id == current.aktiverLayer.id) {
      return false;
    }

    final allowedTarget = current.verfuegbareLayer.any(
      (layer) => layer.id == targetLayer.id,
    );
    if (!allowedTarget) {
      await _logger.logWarn(
        'arbeitskontext',
        'layer switch rejected reason=unavailable_target target=${targetLayer.id}',
      );
      _errorMessage =
          'Der ausgewaehlte Layer ist kein erreichbares Wechselziel.';
      notifyListeners();
      return false;
    }

    await _logger.logInfo(
      'arbeitskontext',
      'layer switch started from=${current.aktiverLayer.id} to=${targetLayer.id}',
    );
    await _logger.trackLayerSwitch(
      'started',
      properties: {
        'from_layer_id': current.aktiverLayer.id,
        'from_layer_name': current.aktiverLayer.name,
        'to_layer_id': targetLayer.id,
        'to_layer_name': targetLayer.name,
      },
    );

    _session = session;
    _isSwitchingLayer = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final accessibleGroups = await _groupsService.fetchAccessibleGroups(
        session.accessToken,
      );
      final nextArbeitskontext = _buildArbeitskontextForTargetLayer(
        profile: profile,
        accessibleGroups: accessibleGroups,
        targetLayerId: targetLayer.id,
      );
      if (nextArbeitskontext == null) {
        await _logger.trackLayerSwitch(
          'failure',
          properties: {
            'from_layer_id': current.aktiverLayer.id,
            'from_layer_name': current.aktiverLayer.name,
            'to_layer_id': targetLayer.id,
            'to_layer_name': targetLayer.name,
            'reason': 'target_not_resolvable',
          },
        );
        _setUnauthorizedState();
        return false;
      }
      _readModel = await _readModelRepository.refresh(
        accessToken: session.accessToken,
        arbeitskontext: nextArbeitskontext,
      );
      _arbeitskontext = _readModel?.arbeitskontext;
      _status = ArbeitskontextStatus.ready;
      _errorMessage = null;
      if (_arbeitskontext != null) {
        await _logger.logInfo(
          'arbeitskontext',
          'layer switch success from=${current.aktiverLayer.id} to=${_arbeitskontext!.aktiverLayer.id} gruppen=${_readModel?.gruppen.length ?? 0} mitglieder=${_readModel?.mitglieder.length ?? 0}',
        );
        await _logger.trackLayerSwitch(
          'success',
          properties: {
            'from_layer_id': current.aktiverLayer.id,
            'from_layer_name': current.aktiverLayer.name,
            'to_layer_id': _arbeitskontext!.aktiverLayer.id,
            'to_layer_name': _arbeitskontext!.aktiverLayer.name,
          },
        );
      }
      _scheduleRolesPreload();
      return true;
    } catch (error, stack) {
      await _logger.logError(
        'arbeitskontext',
        'layer switch failure from=${current.aktiverLayer.id} to=${targetLayer.id}',
        error: error,
        stackTrace: stack,
      );
      await _logger.trackLayerSwitch(
        'failure',
        properties: {
          'from_layer_id': current.aktiverLayer.id,
          'from_layer_name': current.aktiverLayer.name,
          'to_layer_id': targetLayer.id,
          'to_layer_name': targetLayer.name,
          'error_type': error.runtimeType.toString(),
        },
      );
      _errorMessage = layerSwitchFailedMessage;
      return false;
    } finally {
      _isSwitchingLayer = false;
      notifyListeners();
    }
  }

  void _resetState() {
    final hadState =
        _status != ArbeitskontextStatus.initial ||
        _arbeitskontext != null ||
        _readModel != null ||
        _errorMessage != null ||
        _activeProfileId != null ||
        _profileFingerprint != null;
    if (!hadState) {
      return;
    }

    _status = ArbeitskontextStatus.initial;
    _arbeitskontext = null;
    _readModel = null;
    _session = null;
    _errorMessage = null;
    _activeProfileId = null;
    _profileFingerprint = null;
    notifyListeners();
  }

  void _scheduleRolesPreload() {
    unawaited(
      Future<void>.microtask(() async {
        await _preloadRolesInBackground();
      }),
    );
  }

  Future<void> _preloadRolesInBackground() async {
    await _loadRoles(surfaceErrors: false);
  }

  Arbeitskontext? _bestimmeStartkontext({
    required AuthProfile profile,
    required List<HitobitoGroupResource> accessibleGroups,
  }) {
    final input = _buildStartkontextInput(
      profile: profile,
      accessibleGroups: accessibleGroups,
    );
    if (input.verfuegbareLayer.isEmpty) {
      return null;
    }
    return _bestimmeStartkontextUseCase(input);
  }

  StartkontextInput _buildStartkontextInput({
    required AuthProfile profile,
    required List<HitobitoGroupResource> accessibleGroups,
  }) {
    final relevanteLayer = _bestimmeRelevanteLayerUseCase(
      _buildRelevanteLayerInput(
        profile: profile,
        accessibleGroups: accessibleGroups,
      ),
    );
    final groupsById = <int, HitobitoGroupResource>{
      for (final group in accessibleGroups) group.id: group,
    };
    final mappings = <PrimaryGroupLayerZuordnung>[];

    for (final group in accessibleGroups) {
      if (group.isLayer) {
        continue;
      }

      final resolvedLayerId = _resolveLayerId(group, groupsById);
      final mapping = group.toPrimaryGroupLayerZuordnung(resolvedLayerId);
      if (mapping != null) {
        mappings.add(mapping);
      }
    }

    return StartkontextInput(
      primaryGroupId: profile.primaryGroupId,
      verfuegbareLayer: relevanteLayer,
      groupLayerZuordnungen: mappings,
    );
  }

  RelevanteLayerInput _buildRelevanteLayerInput({
    required AuthProfile profile,
    required List<HitobitoGroupResource> accessibleGroups,
  }) {
    final groupsById = <int, HitobitoGroupResource>{
      for (final group in accessibleGroups) group.id: group,
    };
    final sichtbareLayer = <ArbeitskontextLayer>[];
    final sichtbareLayerIds = <int>{};
    final rollenRelevanzen = <RollenRelevanzZuLayer>[];
    final rollenRelevanzKeys = <String>{};

    for (final group in accessibleGroups) {
      if (!group.isLayer || !sichtbareLayerIds.add(group.id)) {
        continue;
      }
      sichtbareLayer.add(group.toArbeitskontextLayer());
    }

    for (final role in profile.roles) {
      final scope = _resolveRelevantLayerScope(role.permissions);
      if (scope == null) {
        continue;
      }

      final roleGroup = groupsById[role.groupId];
      final layerId = roleGroup != null
          ? _resolveLayerId(roleGroup, groupsById)
          : role.groupId;
      if (layerId == null || layerId <= 0) {
        continue;
      }

      final key = '$layerId|$scope';
      if (!rollenRelevanzKeys.add(key)) {
        continue;
      }
      rollenRelevanzen.add(
        RollenRelevanzZuLayer(layerId: layerId, scope: scope),
      );
    }

    return RelevanteLayerInput(
      sichtbareLayer: sichtbareLayer,
      rollenRelevanzen: rollenRelevanzen,
    );
  }

  Arbeitskontext? _mergeCurrentKontext({
    required Arbeitskontext current,
    required AuthProfile profile,
    required List<HitobitoGroupResource> accessibleGroups,
  }) {
    final input = _buildStartkontextInput(
      profile: profile,
      accessibleGroups: accessibleGroups,
    );
    final layers = input.verfuegbareLayer;
    if (layers.isEmpty) {
      return null;
    }

    for (final layer in layers) {
      if (layer.id == current.aktiverLayer.id) {
        return Arbeitskontext(aktiverLayer: layer, verfuegbareLayer: layers);
      }
    }

    return _bestimmeStartkontextUseCase(input);
  }

  Arbeitskontext? _buildArbeitskontextForTargetLayer({
    required AuthProfile profile,
    required List<HitobitoGroupResource> accessibleGroups,
    required int targetLayerId,
  }) {
    final input = _buildStartkontextInput(
      profile: profile,
      accessibleGroups: accessibleGroups,
    );
    if (input.verfuegbareLayer.isEmpty) {
      return null;
    }

    for (final layer in input.verfuegbareLayer) {
      if (layer.id == targetLayerId) {
        return Arbeitskontext(
          aktiverLayer: layer,
          verfuegbareLayer: input.verfuegbareLayer,
        );
      }
    }

    throw StateError(
      'Der ausgewaehlte Layer ist in Hitobito nicht mehr als erreichbares Wechselziel verfuegbar.',
    );
  }

  RelevanterLayerScope? _resolveRelevantLayerScope(List<String> permissions) {
    var includeDescendants = false;
    var includeLayer = false;

    for (final permission in permissions) {
      final normalized = permission.trim().toLowerCase();
      if (_layerAndBelowPermissions.contains(normalized)) {
        includeDescendants = true;
        includeLayer = true;
        continue;
      }
      if (_exactLayerPermissions.contains(normalized)) {
        includeLayer = true;
      }
    }

    if (includeDescendants) {
      return RelevanterLayerScope.layerUndUnterlayer;
    }
    if (includeLayer) {
      return RelevanterLayerScope.exactLayer;
    }
    return null;
  }

  void _setUnauthorizedState() {
    _arbeitskontext = null;
    _readModel = null;
    _status = ArbeitskontextStatus.unauthorized;
    _errorMessage = unauthorizedMessage;
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

  String _buildProfileFingerprint(AuthProfile profile) {
    final roles =
        profile.roles
            .map(
              (role) =>
                  '${role.groupId}:${role.groupName.trim()}:${role.permissions.map((permission) => permission.trim().toLowerCase()).toList(growable: false)..sort()}',
            )
            .toList(growable: false)
          ..sort();
    return '${profile.namiId}|${roles.join('|')}';
  }
}

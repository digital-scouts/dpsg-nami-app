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
import '../../domain/member/mitglied.dart';
import '../../services/hitobito_groups_service.dart';
import '../../services/logger_service.dart';

enum ArbeitskontextStatus { initial, loading, ready, unauthorized, error }

enum ArbeitskontextLoadingStep { checkingLogin, loadingGroups, loadingMembers }

enum ArbeitskontextLoadingStepState { waiting, loading, done }

class ArbeitskontextLoadingStepStatus {
  const ArbeitskontextLoadingStepStatus({
    required this.labelKey,
    required this.state,
    this.detailKey,
    this.detailCount,
  });

  /// l10n-Key fuer den Zeilentitel (z.B. "Gruppen").
  final String labelKey;
  final ArbeitskontextLoadingStepState state;
  /// l10n-Key fuer einen abweichenden Statustext (z.B. "{count} Gruppen
  /// gefunden"), nur gesetzt wenn state == done und ein Zaehler bekannt ist.
  final String? detailKey;
  final int? detailCount;
}

typedef ArbeitskontextRemoteAccessExecutor =
    Future<T?> Function<T>({
      required String trigger,
      required Future<T> Function(AuthSession session) action,
      bool forceRefresh,
      bool allowMobileDataOverride,
    });

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
    ArbeitskontextRemoteAccessExecutor? remoteAccessExecutor,
    required LoggerService logger,
  }) : _localRepository = localRepository,
       _readModelRepository = readModelRepository,
       _groupsService = groupsService,
       _bestimmeStartkontextUseCase = bestimmeStartkontextUseCase,
       _bestimmeRelevanteLayerUseCase = bestimmeRelevanteLayerUseCase,
       _remoteAccessExecutor = remoteAccessExecutor,
       _logger = logger;

  final ArbeitskontextLocalRepository _localRepository;
  final ArbeitskontextReadModelRepository _readModelRepository;
  final HitobitoGroupsService _groupsService;
  final BestimmeStartkontextUseCase _bestimmeStartkontextUseCase;
  final BestimmeRelevanteLayerUseCase _bestimmeRelevanteLayerUseCase;
  final ArbeitskontextRemoteAccessExecutor? _remoteAccessExecutor;
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
  static const Set<String> _writeLayerPermissions = <String>{'layer_full'};
  static const Set<String> _writeLayerAndBelowPermissions = <String>{
    'layer_and_below_full',
  };
  static const Set<String> _writeGroupPermissions = <String>{'group_full'};
  static const Set<String> _writeGroupAndBelowPermissions = <String>{
    'group_and_below_full',
  };

  ArbeitskontextStatus _status = ArbeitskontextStatus.initial;
  Arbeitskontext? _arbeitskontext;
  ArbeitskontextReadModel? _readModel;
  AuthSession? _session;
  AuthProfile? _profile;
  String? _errorMessage;
  int? _activeProfileId;
  String? _profileFingerprint;
  bool _isSynchronizing = false;
  bool _isSwitchingLayer = false;
  bool _isLoadingRoles = false;
  // Wird von initializeForProfile/refreshFromRemote gemeinsam genutzt, damit
  // ein zweiter, ueberlappender Aufruf (z.B. reaktiv durch einen
  // AuthSessionModel-Listener waehrend ein manueller Sync laeuft) auf das
  // Ergebnis des bereits laufenden Vorgangs wartet, statt sofort und
  // stillschweigend mit einem veralteten ReadModel abzubrechen.
  Future<void>? _syncInFlight;
  Future<bool>? _rolesInFlight;
  // Nur waehrend des initialen Ladevorgangs (initializeForProfile ohne
  // Cache-Treffer) gesetzt, damit die UI dem Nutzer zeigen kann, welcher von
  // mehreren Schritten gerade laeuft. Hintergrund-Refreshes beeinflussen
  // dieses Feld bewusst nicht.
  ArbeitskontextLoadingStep? _loadingStep;
  int? _lastGroupsCount;
  int? _lastMembersCount;
  // Ab dem ersten initializeForProfile-Durchlauf (egal ob per Cache oder
  // remote) bis zum Abschluss des zugehoerigen Rollen-Nachladens true -
  // steuert die kompakte Checklisten-Anzeige, nachdem die Shell schon
  // sichtbar ist. Spaetere Refreshes/Layerwechsel setzen dieses Feld
  // bewusst nicht erneut, damit es kein Dauer-Banner wird.
  bool _isInitialSequenceActive = false;

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
  /// True waehrend initializeForProfile/refreshFromRemote laufen (Login-
  /// Pruefung bis Mitglieder geladen) - unabhaengig davon, ob es sich um den
  /// initialen Login oder einen spaeteren Sync (Pull-to-refresh, Debug-Tools)
  /// handelt.
  bool get isSynchronizing => _isSynchronizing;
  bool get areRolesLoaded => _readModel?.rolesSindGeladen ?? false;
  bool get hasStaleDataWarning =>
      status == ArbeitskontextStatus.ready && errorMessage != null;
  /// True, solange die dem Login folgende Erstladesequenz (Gruppen,
  /// Mitglieder, Rollen) noch nicht vollstaendig abgeschlossen ist - auch
  /// nachdem die Shell (arbeitskontext != null) schon sichtbar ist.
  bool get isInitialSequenceActive => _isInitialSequenceActive;

  /// Die vier Phasen des initialen Ladevorgangs (Login, Gruppen, Mitglieder,
  /// Rollen) samt aktuellem Status - fuer eine Checklisten-Anzeige waehrend
  /// des Logins. Rollen laden im Hintergrund weiter, auch nachdem die
  /// ersten drei Schritte bereits abgeschlossen sind.
  List<ArbeitskontextLoadingStepStatus> get loadingSteps {
    final currentPhaseIndex = switch (_loadingStep) {
      ArbeitskontextLoadingStep.checkingLogin => 0,
      ArbeitskontextLoadingStep.loadingGroups => 1,
      ArbeitskontextLoadingStep.loadingMembers => 2,
      null => _status == ArbeitskontextStatus.initial ? -1 : 3,
    };

    ArbeitskontextLoadingStepState stateFor(int index) {
      if (currentPhaseIndex < 0) {
        return ArbeitskontextLoadingStepState.waiting;
      }
      if (index < currentPhaseIndex) {
        return ArbeitskontextLoadingStepState.done;
      }
      if (index == currentPhaseIndex) {
        return ArbeitskontextLoadingStepState.loading;
      }
      return ArbeitskontextLoadingStepState.waiting;
    }

    final groupsState = stateFor(1);
    final membersState = stateFor(2);
    final rolesState = areRolesLoaded
        ? ArbeitskontextLoadingStepState.done
        : (_isLoadingRoles
              ? ArbeitskontextLoadingStepState.loading
              : ArbeitskontextLoadingStepState.waiting);

    return <ArbeitskontextLoadingStepStatus>[
      ArbeitskontextLoadingStepStatus(
        labelKey: 'nav_work_context_step_login',
        state: stateFor(0),
      ),
      ArbeitskontextLoadingStepStatus(
        labelKey: 'nav_work_context_step_groups',
        state: groupsState,
        detailKey: groupsState == ArbeitskontextLoadingStepState.done
            ? 'nav_work_context_step_groups_done'
            : null,
        detailCount: _lastGroupsCount,
      ),
      ArbeitskontextLoadingStepStatus(
        labelKey: 'nav_work_context_step_members',
        state: membersState,
        detailKey: switch (membersState) {
          ArbeitskontextLoadingStepState.done =>
            'nav_work_context_step_members_done',
          ArbeitskontextLoadingStepState.loading when _lastMembersCount != null =>
            'nav_work_context_step_members_loading_count',
          _ => null,
        },
        detailCount: _lastMembersCount,
      ),
      ArbeitskontextLoadingStepStatus(
        labelKey: 'nav_work_context_step_roles',
        state: rolesState,
      ),
    ];
  }

  bool istMitgliedSchreibbar(Mitglied mitglied) {
    final readModel = _readModel;
    final arbeitskontext = _arbeitskontext;
    final profile = _profile;
    if (readModel == null || arbeitskontext == null || profile == null) {
      return false;
    }

    final zielGruppenIds = <int>{
      if (mitglied.primaryGroupId != null && mitglied.primaryGroupId! > 0)
        mitglied.primaryGroupId!,
      ...readModel
          .findeMitgliedsZuordnungen(mitglied.mitgliedsnummer)
          .map((zuordnung) => zuordnung.gruppenId),
    };

    for (final role in profile.roles) {
      final permissions = role.permissions
          .map((permission) => permission.trim().toLowerCase())
          .toSet();
      if (_hasWritePermissionOnActiveLayer(
        roleGroupId: role.groupId,
        permissions: permissions,
        arbeitskontext: arbeitskontext,
        readModel: readModel,
      )) {
        return true;
      }
      if (_hasWritePermissionOnTargetGroups(
        roleGroupId: role.groupId,
        permissions: permissions,
        zielGruppenIds: zielGruppenIds,
        readModel: readModel,
      )) {
        return true;
      }
    }

    return false;
  }

  Future<void> ersetzeMitglied(Mitglied mitglied) async {
    final readModel = _readModel;
    if (readModel == null) {
      return;
    }

    final nextMitglieder = readModel.mitglieder
        .map((existing) {
          if (existing.mitgliedsnummer == mitglied.mitgliedsnummer) {
            return mitglied;
          }
          return existing;
        })
        .toList(growable: false);
    _readModel = readModel.copyWith(mitglieder: nextMitglieder);
    await _localRepository.saveCached(_readModel!);
    notifyListeners();
  }

  Future<void> syncForAuth({
    required AuthState authState,
    required AuthSession? session,
    required AuthProfile? profile,
  }) async {
    final isSignedInState =
        authState == AuthState.signedIn ||
        authState == AuthState.unlockRequired;

    if (!isSignedInState && authState != AuthState.reloginRequired) {
      _resetState();
      return;
    }

    if (authState == AuthState.reloginRequired) {
      _session = session;
      _profile = profile;
      return;
    }

    _session = session;

    if (profile == null) {
      // Angemeldet, aber (noch) kein Profil verfuegbar - z.B. weil der
      // Profil-Abruf fehlgeschlagen ist. Ohne Profil (insb. profile.roles)
      // kann kein Startkontext bestimmt werden. Statt still auf "initial"
      // zurueckzufallen (unsichtbarer, dauerhafter Ladezustand ohne
      // Fehleranzeige/Retry), zeigen wir einen echten Fehlerzustand, sofern
      // noch kein Arbeitskontext aus einer frueheren Sitzung vorhanden ist.
      if (_arbeitskontext == null) {
        _status = ArbeitskontextStatus.error;
        _errorMessage =
            'Profil konnte nicht geladen werden. Bitte erneut versuchen.';
        notifyListeners();
      }
      return;
    }

    _profile = profile;
    await initializeForProfile(profile, session: session);
  }

  Future<void> initializeForProfile(
    AuthProfile profile, {
    required AuthSession? session,
    bool force = false,
  }) async {
    final fingerprint = _buildProfileFingerprint(profile);
    _profile = profile;

    final inFlightSync = _syncInFlight;
    if (inFlightSync != null) {
      await inFlightSync;
      return;
    }

    if (!force &&
        _status == ArbeitskontextStatus.ready &&
        _activeProfileId == profile.namiId &&
        _profileFingerprint == fingerprint &&
        _arbeitskontext != null) {
      return;
    }

    final operation = _runInitializeForProfile(
      profile,
      session: session,
      fingerprint: fingerprint,
    );
    _syncInFlight = operation;
    try {
      await operation;
    } finally {
      if (identical(_syncInFlight, operation)) {
        _syncInFlight = null;
      }
    }
  }

  Future<void> _runInitializeForProfile(
    AuthProfile profile, {
    required AuthSession? session,
    required String fingerprint,
  }) async {
    _isSynchronizing = true;
    _status = ArbeitskontextStatus.loading;
    _errorMessage = null;
    _activeProfileId = profile.namiId;
    _profileFingerprint = fingerprint;
    _loadingStep = ArbeitskontextLoadingStep.checkingLogin;
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
        _isInitialSequenceActive = true;
        _scheduleRolesPreload();
        return;
      }

      if (session == null || session.accessToken.isEmpty) {
        throw StateError(
          'Es ist keine gueltige Session fuer den Arbeitskontext verfuegbar.',
        );
      }

      _loadingStep = ArbeitskontextLoadingStep.loadingGroups;
      _lastGroupsCount = null;
      _lastMembersCount = null;
      notifyListeners();
      final accessibleGroups =
          await _executeRemoteAccess<List<HitobitoGroupResource>>(
            trigger: 'arbeitskontext_initialize_groups',
            session: session,
            action: (activeSession) =>
                _groupsService.fetchAccessibleGroups(activeSession.accessToken),
          );
      if (accessibleGroups == null) {
        _status = _readModel != null
            ? ArbeitskontextStatus.ready
            : ArbeitskontextStatus.initial;
        return;
      }
      _lastGroupsCount = accessibleGroups.length;
      final arbeitskontext = _bestimmeStartkontext(
        profile: profile,
        accessibleGroups: accessibleGroups,
      );
      if (arbeitskontext == null) {
        _setUnauthorizedState();
        return;
      }

      // Kontext schon freigeben, bevor die (potenziell langsame)
      // Mitgliederliste vollstaendig da ist: die App-Shell kann damit schon
      // angezeigt werden, waehrend Mitglieder im Hintergrund weiterladen.
      _arbeitskontext = arbeitskontext;
      _loadingStep = ArbeitskontextLoadingStep.loadingMembers;
      notifyListeners();

      _readModel = await _executeRemoteAccess<ArbeitskontextReadModel>(
        trigger: 'arbeitskontext_initialize_read_model',
        session: session,
        action: (activeSession) => _readModelRepository.refresh(
          accessToken: activeSession.accessToken,
          arbeitskontext: arbeitskontext,
          accessibleGroups: accessibleGroups,
          onProgress: _applyProgressReadModel,
        ),
      );
      if (_readModel == null) {
        _status = _arbeitskontext != null
            ? ArbeitskontextStatus.ready
            : ArbeitskontextStatus.initial;
        return;
      }
      _arbeitskontext = _readModel?.arbeitskontext ?? _arbeitskontext;
      _status = ArbeitskontextStatus.ready;
      _lastMembersCount = _readModel?.mitglieder.length;
      if (_arbeitskontext != null) {
        await _logger.log(
          'arbeitskontext',
          'Arbeitskontext erfolgreich remote geladen: layer=${_arbeitskontext!.aktiverLayer.id} name=${_arbeitskontext!.aktiverLayer.name} gruppen=${_readModel?.gruppen.length ?? 0} mitglieder=${_readModel?.mitglieder.length ?? 0}',
        );
      }
      _isInitialSequenceActive = true;
      _scheduleRolesPreload();
    } catch (error, stack) {
      await _logger.log(
        'arbeitskontext',
        'Arbeitskontext konnte nicht initialisiert werden: $error\n$stack',
      );
      _status = _arbeitskontext != null
          ? ArbeitskontextStatus.ready
          : ArbeitskontextStatus.error;
      _errorMessage = error.toString();
    } finally {
      _isSynchronizing = false;
      _loadingStep = null;
      notifyListeners();
    }
  }

  /// Wird pro geladener People-Seite aufgerufen (siehe
  /// ArbeitskontextReadModelRepository.refresh's onProgress-Parameter), damit
  /// bereits geladene Mitglieder sofort sichtbar werden, waehrend weitere
  /// Seiten im Hintergrund nachladen.
  void _applyProgressReadModel(ArbeitskontextReadModel partial) {
    _readModel = partial;
    _arbeitskontext = partial.arbeitskontext;
    _lastMembersCount = partial.mitglieder.length;
    notifyListeners();
  }

  Future<void> retry(AuthProfile? profile) async {
    if (profile == null) {
      return;
    }

    await initializeForProfile(profile, session: _session, force: true);
  }

  Future<void> clearCachedData() async {
    await _localRepository.clearCached();
    _readModel = null;
    _arbeitskontext = null;
    _status = ArbeitskontextStatus.initial;
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> refreshFromRemote({
    required AuthSession? session,
    required AuthProfile? profile,
    bool allowMobileDataOverride = false,
    bool scheduleRolesPreload = true,
  }) async {
    if (session == null || profile == null || session.accessToken.isEmpty) {
      return;
    }

    _session = session;
    _profile = profile;

    final inFlightSync = _syncInFlight;
    if (inFlightSync != null) {
      await inFlightSync;
      return;
    }

    final operation = _runRefreshFromRemote(
      session: session,
      profile: profile,
      allowMobileDataOverride: allowMobileDataOverride,
      scheduleRolesPreload: scheduleRolesPreload,
    );
    _syncInFlight = operation;
    try {
      await operation;
    } finally {
      if (identical(_syncInFlight, operation)) {
        _syncInFlight = null;
      }
    }
  }

  Future<void> _runRefreshFromRemote({
    required AuthSession session,
    required AuthProfile profile,
    required bool allowMobileDataOverride,
    required bool scheduleRolesPreload,
  }) async {
    final previousStatus = _status;
    // Viele Startup-/Maintenance-Trigger (main.dart: _syncArbeitskontextComplete,
    // Auth-Maintenance-Timer, Connectivity-Listener) fuehren den allerersten
    // Ladevorgang der Session ueber refreshFromRemote statt initializeForProfile
    // aus. Ohne diese Erkennung wuerde die gleiche Fehlerbehandlung/Progress-
    // Anzeige, die initializeForProfile bereits bekommen hat, hier fehlen.
    final isInitialLoad = _arbeitskontext == null;
    _isSynchronizing = true;
    if (_status != ArbeitskontextStatus.ready) {
      _status = ArbeitskontextStatus.loading;
      if (isInitialLoad) {
        _loadingStep = ArbeitskontextLoadingStep.checkingLogin;
      }
      notifyListeners();
    }

    try {
      // Anders als isInitialSequenceActive laeuft die Schritt-Anzeige
      // (loadingStep) hier bewusst auch fuer spaetere Syncs (Pull-to-refresh,
      // Debug-Tools) mit, damit die Ladeinfo-Checkliste im Tab-Shell-Banner
      // bei jedem Sync sinnvolle Zwischenstaende zeigt statt nur "OK".
      _loadingStep = ArbeitskontextLoadingStep.loadingGroups;
      _lastGroupsCount = null;
      _lastMembersCount = null;
      notifyListeners();
      final accessibleGroups =
          await _executeRemoteAccess<List<HitobitoGroupResource>>(
            trigger: 'arbeitskontext_refresh_groups',
            session: session,
            allowMobileDataOverride: allowMobileDataOverride,
            action: (activeSession) =>
                _groupsService.fetchAccessibleGroups(activeSession.accessToken),
          );
      if (accessibleGroups == null) {
        await _logger.log(
          'arbeitskontext',
          'Arbeitskontext-Refresh abgebrochen: '
              'Remote-Zugriff fuer Groups lieferte kein Ergebnis '
              '(siehe auth_flow-Log fuer den Grund)',
        );
        _status = previousStatus;
        return;
      }
      _lastGroupsCount = accessibleGroups.length;
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
      if (isInitialLoad) {
        // Kontext schon freigeben, bevor die Mitgliederliste fertig ist -
        // siehe initializeForProfile fuer die identische Begruendung.
        _arbeitskontext = nextArbeitskontext;
      }
      _loadingStep = ArbeitskontextLoadingStep.loadingMembers;
      notifyListeners();
      _readModel = await _executeRemoteAccess<ArbeitskontextReadModel>(
        trigger: 'arbeitskontext_refresh_read_model',
        session: session,
        allowMobileDataOverride: allowMobileDataOverride,
        action: (activeSession) => _readModelRepository.refresh(
          accessToken: activeSession.accessToken,
          arbeitskontext: nextArbeitskontext,
          accessibleGroups: accessibleGroups,
          onProgress: _applyProgressReadModel,
        ),
      );
      if (_readModel == null) {
        await _logger.log(
          'arbeitskontext',
          'Arbeitskontext-Refresh abgebrochen: '
              'Remote-Zugriff fuer ReadModel lieferte kein Ergebnis '
              '(siehe auth_flow-Log fuer den Grund)',
        );
        _status = previousStatus;
        return;
      }
      _arbeitskontext = _readModel?.arbeitskontext ?? _arbeitskontext;
      _errorMessage = null;
      _status = ArbeitskontextStatus.ready;
      _lastMembersCount = _readModel?.mitglieder.length;
      if (_arbeitskontext != null) {
        await _logger.log(
          'arbeitskontext',
          'Arbeitskontext erfolgreich aktualisiert: layer=${_arbeitskontext!.aktiverLayer.id} name=${_arbeitskontext!.aktiverLayer.name} gruppen=${_readModel?.gruppen.length ?? 0} mitglieder=${_readModel?.mitglieder.length ?? 0}',
        );
      }
      if (isInitialLoad) {
        _isInitialSequenceActive = true;
      }
      if (scheduleRolesPreload) {
        _scheduleRolesPreload();
      }
    } catch (error, stack) {
      await _logger.log(
        'arbeitskontext',
        'Arbeitskontext-Refresh fehlgeschlagen: $error\n$stack',
      );
      // War schon ein Kontext bekannt (entweder von vorher, oder weil dieser
      // Durchlauf ihn bereits fruehzeitig gesetzt hat), zeigen wir keinen
      // Vollbild-Fehler, sondern behalten die Daten mit dezentem Hinweis.
      _status = _arbeitskontext != null
          ? ArbeitskontextStatus.ready
          : ArbeitskontextStatus.error;
      _errorMessage = error.toString();
    } finally {
      _isSynchronizing = false;
      _loadingStep = null;
      notifyListeners();
    }
  }

  Future<bool> ensureRolesLoaded({bool allowMobileDataOverride = false}) async {
    final inFlightSync = _syncInFlight;
    if (inFlightSync != null) {
      // Ein Arbeitskontext-Sync (initializeForProfile/refreshFromRemote)
      // laeuft bereits (z.B. reaktiv durch einen AuthSessionModel-Listener
      // ausgeloest) und liefert gleich ein frisches ReadModel. Ohne dieses
      // Warten wuerde der folgende _loadRoles-Aufruf sofort mit "kein
      // ReadModel" scheitern, obwohl der Sync Sekunden spaeter erfolgreich
      // durchlaeuft.
      await inFlightSync;
    }
    return _loadRoles(
      surfaceErrors: true,
      allowMobileDataOverride: allowMobileDataOverride,
    );
  }

  Future<bool> _loadRoles({
    required bool surfaceErrors,
    bool allowMobileDataOverride = false,
  }) async {
    try {
      final inFlightRoles = _rolesInFlight;
      if (inFlightRoles != null) {
        return await inFlightRoles;
      }

      final currentReadModel = _readModel;
      final session = _session;
      if (currentReadModel == null) {
        return false;
      }
      if (currentReadModel.rolesSindGeladen) {
        return true;
      }
      if (_isSynchronizing || _isSwitchingLayer) {
        return false;
      }
      if (session == null || session.accessToken.isEmpty) {
        return false;
      }

      final operation = _runLoadRoles(
        currentReadModel: currentReadModel,
        session: session,
        surfaceErrors: surfaceErrors,
        allowMobileDataOverride: allowMobileDataOverride,
      );
      _rolesInFlight = operation;
      try {
        return await operation;
      } finally {
        if (identical(_rolesInFlight, operation)) {
          _rolesInFlight = null;
        }
      }
    } finally {
      // Unabhaengig davon, ueber welchen Pfad _loadRoles endet (Rollen
      // schon geladen, kein ReadModel, tatsaechlicher Remote-Aufruf, ...):
      // die Erstladesequenz-Anzeige darf danach nicht haengen bleiben.
      if (_isInitialSequenceActive) {
        _isInitialSequenceActive = false;
        notifyListeners();
      }
    }
  }

  Future<bool> _runLoadRoles({
    required ArbeitskontextReadModel currentReadModel,
    required AuthSession session,
    required bool surfaceErrors,
    required bool allowMobileDataOverride,
  }) async {
    _isLoadingRoles = true;
    if (surfaceErrors) {
      _errorMessage = null;
    }
    notifyListeners();

    try {
      _readModel = await _executeRemoteAccess<ArbeitskontextReadModel>(
        trigger: 'arbeitskontext_load_roles',
        session: session,
        allowMobileDataOverride: allowMobileDataOverride,
        action: (activeSession) => _readModelRepository.loadRoles(
          accessToken: activeSession.accessToken,
          readModel: currentReadModel,
        ),
      );
      if (_readModel == null) {
        await _logger.log(
          'arbeitskontext',
          'Roles-Nachladen abgebrochen: Remote-Zugriff lieferte kein '
              'Ergebnis (siehe auth_flow-Log fuer den Grund)',
        );
        return false;
      }
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
      final accessibleGroups =
          await _executeRemoteAccess<List<HitobitoGroupResource>>(
            trigger: 'arbeitskontext_switch_layer_groups',
            session: session,
            action: (activeSession) =>
                _groupsService.fetchAccessibleGroups(activeSession.accessToken),
          );
      if (accessibleGroups == null) {
        return false;
      }
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
      _readModel = await _executeRemoteAccess<ArbeitskontextReadModel>(
        trigger: 'arbeitskontext_switch_layer_read_model',
        session: session,
        action: (activeSession) => _readModelRepository.refresh(
          accessToken: activeSession.accessToken,
          arbeitskontext: nextArbeitskontext,
          accessibleGroups: accessibleGroups,
        ),
      );
      if (_readModel == null) {
        return false;
      }
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
    _profile = null;
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

  Future<T?> _executeRemoteAccess<T>({
    required String trigger,
    required AuthSession session,
    required Future<T> Function(AuthSession session) action,
    bool allowMobileDataOverride = false,
  }) async {
    final executor = _remoteAccessExecutor;
    if (executor != null) {
      return executor<T>(
        trigger: trigger,
        action: action,
        allowMobileDataOverride: allowMobileDataOverride,
      );
    }
    return action(session);
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

  bool _hasWritePermissionOnActiveLayer({
    required int roleGroupId,
    required Set<String> permissions,
    required Arbeitskontext arbeitskontext,
    required ArbeitskontextReadModel readModel,
  }) {
    final roleLayerId = _resolveRoleLayerIdInCurrentContext(
      roleGroupId: roleGroupId,
      arbeitskontext: arbeitskontext,
      readModel: readModel,
    );
    if (permissions.any(_writeLayerPermissions.contains) &&
        roleLayerId == arbeitskontext.aktiverLayer.id) {
      return true;
    }

    if (!permissions.any(_writeLayerAndBelowPermissions.contains)) {
      return false;
    }
    if (roleLayerId == null) {
      return false;
    }

    var currentLayer = arbeitskontext.aktiverLayer;
    if (currentLayer.id == roleLayerId) {
      return true;
    }

    final layersById = <int, ArbeitskontextLayer>{
      for (final layer in arbeitskontext.verfuegbareLayer) layer.id: layer,
      currentLayer.id: currentLayer,
    };
    while (currentLayer.parentLayerId != null) {
      final parentLayerId = currentLayer.parentLayerId!;
      if (parentLayerId == roleLayerId) {
        return true;
      }
      final parentLayer = layersById[parentLayerId];
      if (parentLayer == null) {
        break;
      }
      currentLayer = parentLayer;
    }

    return false;
  }

  int? _resolveRoleLayerIdInCurrentContext({
    required int roleGroupId,
    required Arbeitskontext arbeitskontext,
    required ArbeitskontextReadModel readModel,
  }) {
    if (arbeitskontext.enthaeltLayer(roleGroupId)) {
      return roleGroupId;
    }

    return readModel.findeGruppe(roleGroupId)?.layerId;
  }

  bool _hasWritePermissionOnTargetGroups({
    required int roleGroupId,
    required Set<String> permissions,
    required Set<int> zielGruppenIds,
    required ArbeitskontextReadModel readModel,
  }) {
    if (permissions.any(_writeGroupPermissions.contains) &&
        zielGruppenIds.contains(roleGroupId)) {
      return true;
    }

    if (!permissions.any(_writeGroupAndBelowPermissions.contains)) {
      return false;
    }

    for (final zielGruppenId in zielGruppenIds) {
      if (_isGroupDescendantOrSame(
        gruppenId: zielGruppenId,
        ancestorGroupId: roleGroupId,
        readModel: readModel,
      )) {
        return true;
      }
    }

    return false;
  }

  bool _isGroupDescendantOrSame({
    required int gruppenId,
    required int ancestorGroupId,
    required ArbeitskontextReadModel readModel,
  }) {
    if (gruppenId == ancestorGroupId) {
      return true;
    }

    final gruppenById = <int, ArbeitskontextGruppe>{
      for (final gruppe in readModel.gruppen) gruppe.id: gruppe,
    };
    var current = gruppenById[gruppenId];
    while (current?.parentId != null) {
      if (current!.parentId == ancestorGroupId) {
        return true;
      }
      current = gruppenById[current.parentId!];
    }

    return false;
  }
}

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nami/domain/auth/auth_profile.dart';
import 'package:nami/domain/auth/auth_session.dart';
import 'package:nami/domain/auth/auth_state.dart';
import 'package:nami/domain/member/member_write_repository.dart';
import 'package:nami/domain/member/mitglied.dart';
import 'package:nami/domain/member/pending_person_update.dart';
import 'package:nami/presentation/model/auth_session_model.dart';
import 'package:nami/presentation/model/member_edit_model.dart';
import 'package:nami/presentation/model/pending_sync_coordinator.dart';
import 'package:nami/services/hitobito_data_retention_policy.dart';

import 'support/auth_session_fakes.dart';
import 'support/fake_connectivity.dart';
import 'support/fake_logger_service.dart';
import 'support/in_memory_pending_person_update_repository.dart';

final _start = DateTime(2026, 4, 14, 9);

void main() {
  test('sendet beim Start im WLAN nach dem Sync die faelligen Eintraege', () {
    fakeAsync((async) {
      final harness = _Harness(async, connectivity: FakeConnectivity.wifi());

      harness.coordinator.start();
      unawaited(
        harness.coordinator.checkCurrentConnectivity(trigger: 'startup'),
      );
      async.flushMicrotasks();

      expect(harness.authModel.syncTriggers, <String>['startup']);
      expect(harness.writeRepository.updateCount, 1);
      expect(harness.memberEditModel.pendingUpdates, isEmpty);
      harness.dispose();
    });
  });

  test(
    'wartet bei mobilen Daten mit Nur-WLAN und sendet nach dem Wechsel ins WLAN',
    () {
      fakeAsync((async) {
        final harness = _Harness(
          async,
          connectivity: FakeConnectivity.mobile(),
          noMobileDataEnabled: true,
        );

        harness.coordinator.start();
        unawaited(
          harness.coordinator.checkCurrentConnectivity(trigger: 'startup'),
        );
        async.elapse(const Duration(minutes: 3));

        expect(harness.authModel.syncTriggers, isEmpty);
        expect(harness.writeRepository.updateCount, 0);

        harness.connectivity.setWifi();
        async.flushMicrotasks();

        expect(harness.authModel.syncTriggers, <String>[
          'connectivity_changed',
        ]);
        expect(harness.writeRepository.updateCount, 1);
        harness.dispose();
      });
    },
  );

  test('sendet bei erlaubten mobilen Daten sofort', () {
    fakeAsync((async) {
      final harness = _Harness(async, connectivity: FakeConnectivity.mobile());

      harness.coordinator.start();
      unawaited(
        harness.coordinator.checkCurrentConnectivity(trigger: 'startup'),
      );
      async.flushMicrotasks();

      expect(harness.authModel.syncTriggers, <String>['startup']);
      expect(harness.writeRepository.updateCount, 1);
      harness.dispose();
    });
  });

  test(
    'loest den Vordergrund-Sync nur einmal pro erlaubter Verbindung aus',
    () {
      fakeAsync((async) {
        final harness = _Harness(
          async,
          connectivity: FakeConnectivity.offline(),
          entries: const <PendingPersonUpdate>[],
        );
        harness.coordinator.start();

        harness.connectivity.setWifi();
        async.flushMicrotasks();
        harness.connectivity.setMobile();
        async.flushMicrotasks();
        harness.connectivity.setWifi();
        async.flushMicrotasks();

        expect(harness.authModel.syncTriggers, <String>[
          'connectivity_changed',
        ]);

        harness.connectivity.setOffline();
        async.flushMicrotasks();
        harness.connectivity.setWifi();
        async.flushMicrotasks();

        expect(harness.authModel.syncTriggers, <String>[
          'connectivity_changed',
          'connectivity_changed',
        ]);
        harness.dispose();
      });
    },
  );

  test('startet keinen zweiten Vordergrund-Sync, solange einer laeuft', () {
    fakeAsync((async) {
      final harness = _Harness(async, connectivity: FakeConnectivity.wifi());
      final blocker = Completer<void>();
      harness.authModel.onSync = () => blocker.future;
      harness.coordinator.start();

      unawaited(harness.coordinator.checkCurrentConnectivity(trigger: 'a'));
      async.flushMicrotasks();
      harness.coordinator.pause();
      harness.coordinator.resume();
      async.flushMicrotasks();

      expect(harness.authModel.syncTriggers, <String>['a']);
      blocker.complete();
      async.flushMicrotasks();
      harness.dispose();
    });
  });

  test('der Timer sendet erst, wenn der Backoff abgelaufen ist', () {
    fakeAsync((async) {
      final harness = _Harness(async, connectivity: FakeConnectivity.wifi());
      harness.writeRepository.error = Exception('Hitobito antwortet nicht');
      harness.coordinator.start();

      // Versuch 1 nach einer Minute, danach 1, 2, 4 Minuten Wartezeit.
      async.elapse(const Duration(minutes: 1));
      expect(harness.writeRepository.updateTimes, <Duration>[
        const Duration(minutes: 1),
      ]);
      async.elapse(const Duration(minutes: 7));

      expect(harness.writeRepository.updateTimes, <Duration>[
        const Duration(minutes: 1),
        const Duration(minutes: 2),
        const Duration(minutes: 4),
        const Duration(minutes: 8),
      ]);
      harness.dispose();
    });
  });

  test('der Timer sendet nicht ohne Verbindung', () {
    fakeAsync((async) {
      final harness = _Harness(async, connectivity: FakeConnectivity.offline());
      harness.coordinator.start();

      async.elapse(const Duration(minutes: 5));

      expect(harness.writeRepository.updateCount, 0);
      harness.dispose();
    });
  });

  test('sendet im Hintergrund nichts und prueft beim Resume neu', () {
    fakeAsync((async) {
      final harness = _Harness(async, connectivity: FakeConnectivity.wifi());
      harness.coordinator.start();
      harness.coordinator.pause();

      async.elapse(const Duration(minutes: 5));
      harness.connectivity.setWifi();
      async.flushMicrotasks();

      expect(harness.coordinator.isPaused, isTrue);
      expect(harness.authModel.syncTriggers, isEmpty);
      expect(harness.writeRepository.updateCount, 0);

      harness.coordinator.resume();
      async.flushMicrotasks();

      expect(harness.coordinator.isPaused, isFalse);
      expect(harness.authModel.syncTriggers, <String>['resume']);
      expect(harness.writeRepository.updateCount, 1);
      harness.dispose();
    });
  });

  test('sendet nicht, wenn ein interaktiver Login noetig ist', () {
    fakeAsync((async) {
      final harness = _Harness(async, connectivity: FakeConnectivity.wifi());
      harness.authModel.requiresInteractiveLoginOverride = true;
      harness.coordinator.start();

      async.elapse(const Duration(minutes: 3));

      expect(harness.writeRepository.updateCount, 0);
      harness.dispose();
    });
  });

  test('sendet nicht ohne Session', () {
    fakeAsync((async) {
      final harness = _Harness(async, connectivity: FakeConnectivity.wifi());
      harness.authModel.hasSession = false;
      harness.coordinator.start();

      async.elapse(const Duration(minutes: 3));

      expect(harness.writeRepository.updateCount, 0);
      harness.dispose();
    });
  });

  test('startet keinen zweiten Retry, solange einer laeuft', () {
    fakeAsync((async) {
      final harness = _Harness(async, connectivity: FakeConnectivity.wifi());
      final blocker = Completer<Mitglied>();
      harness.writeRepository.onUpdate = (_) => blocker.future;
      harness.coordinator.start();

      async.elapse(const Duration(minutes: 1));
      expect(harness.memberEditModel.isBusy, isTrue);
      async.elapse(const Duration(minutes: 3));

      expect(harness.writeRepository.updateCount, 1);
      blocker.complete(_ziel);
      async.flushMicrotasks();
      expect(harness.memberEditModel.pendingUpdates, isEmpty);
      harness.dispose();
    });
  });

  test('ohne Retry-Timer (Demo) sendet der Timer nichts', () {
    fakeAsync((async) {
      final harness = _Harness(
        async,
        connectivity: FakeConnectivity.wifi(),
        pendingRetryEnabled: false,
      );
      harness.coordinator.start();

      async.elapse(const Duration(minutes: 5));

      expect(harness.writeRepository.updateCount, 0);
      harness.dispose();
    });
  });

  test(
    'holt den Start-Check nach, wenn die Auth-Initialisierung noch laeuft',
    () {
      fakeAsync((async) {
        final harness = _Harness(async, connectivity: FakeConnectivity.wifi());
        harness.authModel.changeState(AuthState.initializing);
        harness.coordinator.start();

        unawaited(
          harness.coordinator.checkCurrentConnectivity(trigger: 'startup'),
        );
        harness.connectivity.setWifi();
        async.flushMicrotasks();

        expect(harness.authModel.syncTriggers, isEmpty);
        expect(harness.writeRepository.updateCount, 0);

        harness.authModel.changeState(AuthState.signedIn);
        async.flushMicrotasks();

        expect(harness.authModel.syncTriggers, <String>['auth_ready']);
        expect(harness.writeRepository.updateCount, 1);

        // Weitere Auth-Aenderungen loesen keinen zweiten Start-Check aus.
        harness.authModel.changeState(AuthState.signedIn);
        async.flushMicrotasks();
        expect(harness.authModel.syncTriggers, <String>['auth_ready']);
        harness.dispose();
      });
    },
  );

  test(
    'sendet hinter der App-Sperre nichts und holt nach dem Entsperren nach',
    () {
      fakeAsync((async) {
        final harness = _Harness(async, connectivity: FakeConnectivity.wifi());
        harness.authModel.changeState(AuthState.unlockRequired);
        harness.coordinator.start();

        unawaited(
          harness.coordinator.checkCurrentConnectivity(trigger: 'resume'),
        );
        // Auch der Retry-Timer laeuft, waehrend die Sperre aktiv ist.
        async.elapse(const Duration(minutes: 3));

        expect(harness.authModel.syncTriggers, isEmpty);
        expect(harness.writeRepository.updateCount, 0);

        harness.authModel.changeState(AuthState.signedIn);
        async.flushMicrotasks();

        expect(harness.authModel.syncTriggers, <String>['auth_ready']);
        expect(harness.writeRepository.updateCount, 1);
        harness.dispose();
      });
    },
  );

  test('dispose beendet Listener und Timer', () {
    fakeAsync((async) {
      final harness = _Harness(async, connectivity: FakeConnectivity.wifi());
      harness.coordinator.start();
      expect(harness.connectivity.hasListener, isTrue);

      harness.coordinator.dispose();
      async.elapse(const Duration(minutes: 5));

      expect(harness.connectivity.hasListener, isFalse);
      expect(harness.writeRepository.updateCount, 0);
      expect(async.periodicTimerCount, 0);
    });
  });
}

final _basis = Mitglied.peopleListItem(
  mitgliedsnummer: '4711',
  personId: 23,
  vorname: 'Julia',
  nachname: 'Keller',
).copyWith(updatedAt: DateTime(2026, 4, 1));

final _ziel = _basis.copyWith(fahrtenname: 'Polka');

PendingPersonUpdate _pendingEntry() => PendingPersonUpdate(
  entryId: 'person-23',
  personId: 23,
  mitgliedsnummer: '4711',
  displayName: _basis.fullName,
  basisMitglied: _basis,
  zielMitglied: _ziel,
  queuedAt: _start,
);

class _Harness {
  _Harness(
    this.async, {
    required this.connectivity,
    bool noMobileDataEnabled = false,
    bool pendingRetryEnabled = true,
    List<PendingPersonUpdate>? entries,
  }) {
    DateTime now() => _start.add(async.elapsed);
    writeRepository = _RecordingMemberWriteRepository(
      elapsed: () => async.elapsed,
    );
    memberEditModel = MemberEditModel(
      memberWriteRepository: writeRepository,
      pendingRepository: InMemoryPendingPersonUpdateRepository(
        entries: entries ?? <PendingPersonUpdate>[_pendingEntry()],
      ),
      logger: FakeLoggerService(),
      onMemberUpdated: (_) async {},
      nowProvider: now,
    );
    unawaited(memberEditModel.loadPending());
    authModel = _StubAuthSessionModel();
    coordinator = PendingSyncCoordinator(
      connectivity: connectivity,
      authModel: authModel,
      memberEditModel: memberEditModel,
      noMobileDataEnabled: () => noMobileDataEnabled,
      syncMembers: () async {},
      pendingRetryEnabled: pendingRetryEnabled,
    );
    async.flushMicrotasks();
  }

  final FakeAsync async;
  final FakeConnectivity connectivity;
  late final _RecordingMemberWriteRepository writeRepository;
  late final MemberEditModel memberEditModel;
  late final _StubAuthSessionModel authModel;
  late final PendingSyncCoordinator coordinator;

  void dispose() {
    coordinator.dispose();
    async.flushMicrotasks();
  }
}

/// Auth-Modell mit fester Session; der Hitobito-Sync wird nur mitgeschrieben.
class _StubAuthSessionModel extends AuthSessionModel {
  _StubAuthSessionModel()
    : super(
        repository: InMemoryAuthSessionRepository(),
        profileRepository: InMemoryAuthProfileRepository(),
        oauthService: FakeOauthService(
          sessionToReturn: AuthSession(
            accessToken: 'token',
            receivedAt: DateTime(2026, 4, 14),
          ),
          profileToReturn: const AuthProfile(namiId: 1),
        ),
        biometricLockService: FakeBiometricLockService(),
        sensitiveStorageService: FakeSensitiveStorageService(),
        retentionPolicy: HitobitoDataRetentionPolicy(
          maxDataAge: const Duration(days: 90),
          refreshInterval: const Duration(hours: 24),
          nowProvider: () => _start,
        ),
        logger: FakeLoggerService(),
      );

  final List<String> syncTriggers = <String>[];
  Future<void> Function()? onSync;
  bool hasSession = true;
  bool requiresInteractiveLoginOverride = false;
  AuthState _stateOverride = AuthState.signedIn;

  @override
  AuthState get state => _stateOverride;

  void changeState(AuthState value) {
    _stateOverride = value;
    notifyListeners();
  }

  @override
  AuthSession? get session => hasSession
      ? AuthSession(accessToken: 'token', receivedAt: DateTime(2026, 4, 14))
      : null;

  @override
  bool get requiresInteractiveLogin => requiresInteractiveLoginOverride;

  @override
  Future<void> syncHitobitoData({
    required Future<void> Function(String accessToken) syncMembers,
    bool force = false,
    String trigger = 'manual',
    bool userInitiated = true,
    bool allowMobileDataOverride = false,
    bool interactiveLoginOnRequired = false,
  }) async {
    expect(userInitiated, isFalse);
    syncTriggers.add(trigger);
    await onSync?.call();
  }
}

class _RecordingMemberWriteRepository implements MemberWriteRepository {
  _RecordingMemberWriteRepository({required this.elapsed});

  final Duration Function() elapsed;
  final List<Duration> updateTimes = <Duration>[];
  Object? error;
  Future<Mitglied> Function(Mitglied ziel)? onUpdate;

  int get updateCount => updateTimes.length;

  @override
  Future<Mitglied> fetchRemoteMember({
    required String accessToken,
    required int personId,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<Mitglied> updateMember({
    required String accessToken,
    required Mitglied basisMitglied,
    required Mitglied zielMitglied,
  }) async {
    updateTimes.add(elapsed());
    final handler = onUpdate;
    if (handler != null) {
      return handler(zielMitglied);
    }
    final currentError = error;
    if (currentError != null) {
      throw currentError;
    }
    return zielMitglied;
  }
}

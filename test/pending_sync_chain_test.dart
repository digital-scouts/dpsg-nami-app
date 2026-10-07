import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nami/data/member/hitobito_member_write_repository.dart';
import 'package:nami/domain/auth/auth_profile.dart';
import 'package:nami/domain/auth/auth_session.dart';
import 'package:nami/domain/member/member_resolution.dart';
import 'package:nami/domain/member/mitglied.dart';
import 'package:nami/presentation/model/auth_session_model.dart';
import 'package:nami/presentation/model/member_edit_model.dart';
import 'package:nami/presentation/model/pending_sync_coordinator.dart';
import 'package:nami/services/hitobito_data_retention_policy.dart';
import 'package:nami/services/hitobito_people_service.dart';
import 'package:nami/services/network_access_policy.dart';

import 'support/auth_session_fakes.dart';
import 'support/fake_connectivity.dart';
import 'support/fake_hitobito_people_api.dart';
import 'support/fake_logger_service.dart';
import 'support/hitobito_jsonapi_fixtures.dart';
import 'support/in_memory_pending_person_update_repository.dart';

/// Durchgehende Sync-Szenarien ueber die echte Kette
/// HitobitoPeopleService (MockClient) -> HitobitoMemberWriteRepository
/// (mit AuthSessionModel.executeRemoteAccess) -> MemberEditModel ->
/// Pending-Speicher, gesteuert vom PendingSyncCoordinator.
void main() {
  test(
    'Offline-Konflikt: lokale und fremde Aenderung desselben Felds werden zum Problemfall',
    () {
      fakeAsync((async) {
        final chain = _SyncChain(
          async,
          connectivity: FakeConnectivity.offline(),
        );
        final basis = chain.loadMember();

        final result = chain.submit(basis.copyWith(fahrtenname: 'Polka'));

        expect(result.wasQueued, isTrue);
        expect(result.suppressNotice, isTrue);
        expect(chain.api.requests, isEmpty);

        chain.api.serverEdit(_personId, <String, dynamic>{'nickname': 'Pfiff'});
        chain.connectivity.setWifi();
        async.flushMicrotasks();

        expect(chain.api.getRequests, hasLength(1));
        expect(chain.api.putRequests, isEmpty);
        expect(chain.memberEditModel.openResolutionCount, 1);
        final entry = chain.memberEditModel.firstResolutionEntry!;
        expect(entry.status, PendingPersonUpdateStatus.needsResolution);
        final resolutionCase = entry.resolutionCase!;
        expect(resolutionCase.source, MemberResolutionSource.pendingRetry);
        expect(resolutionCase.remoteMitglied.fahrtenname, 'Pfiff');
        expect(
          resolutionCase.items.map((item) => item.target.type),
          contains(MemberResolutionTargetType.nickname),
        );
        expect(
          resolutionCase.items.every(
            (item) => item.problemType == MemberResolutionProblemType.conflict,
          ),
          isTrue,
        );

        // Ein Problemfall wird nie automatisch gesendet.
        async.elapse(const Duration(hours: 2));
        expect(chain.api.requests, hasLength(1));
        expect(chain.api.attributeOf(_personId, 'nickname'), 'Pfiff');
        chain.dispose();
      });
    },
  );

  test(
    'Problemloesung sendet nur die strittige Aenderung und erhaelt fremde Aenderungen',
    () {
      fakeAsync((async) {
        final chain = _SyncChain(
          async,
          connectivity: FakeConnectivity.offline(),
        );
        chain.api.serverEdit(_personId, <String, dynamic>{
          'street': 'Alte Strasse',
          'housenumber': '1',
        });
        final basis = chain.loadMember();
        chain.submit(basis.copyWith(fahrtenname: 'Polka'));

        // Jemand anderes aendert in Hitobito dasselbe Feld, ein weiteres Feld
        // und legt eine Telefonnummer an.
        chain.api.serverEdit(_personId, <String, dynamic>{
          'nickname': 'Pfiff',
          'street': 'Neue Strasse',
        });
        chain.api.serverAddPhoneNumber(
          _personId,
          number: '+49 171 3333333',
          label: 'Mobil',
        );
        chain.connectivity.setWifi();
        async.flushMicrotasks();

        final entry = chain.memberEditModel.firstResolutionEntry!;
        expect(entry.basisMitglied, entry.resolutionCase!.remoteMitglied);
        expect(entry.zielMitglied.fahrtenname, 'Polka');
        expect(entry.zielMitglied.primaryAddress?.street, 'Neue Strasse');
        expect(entry.zielMitglied.telefonnummern, hasLength(1));

        // „Lokal behalten“ und speichern, wie die Bearbeiten-Seite.
        late MemberEditSubmitResult result;
        chain.memberEditModel
            .submitUpdate(
              accessToken: chain.authModel.session!.accessToken,
              basisMitglied: entry.basisMitglied,
              zielMitglied: entry.zielMitglied,
              trigger: 'manual_resolution',
              existingResolutionCase: entry.resolutionCase,
            )
            .then((value) => result = value);
        async.flushMicrotasks();

        expect(result.success, isTrue);
        final data = chain.api.putRequests.single.body!['data'];
        expect(data['attributes'], <String, dynamic>{'nickname': 'Polka'});
        final phoneData =
            data['relationships']?['phone_numbers']?['data'] as List<dynamic>?;
        expect(phoneData ?? const <dynamic>[], isEmpty);
        expect(chain.api.attributeOf(_personId, 'nickname'), 'Polka');
        expect(chain.api.attributeOf(_personId, 'street'), 'Neue Strasse');
        expect(chain.api.phoneNumbersOf(_personId), hasLength(1));
        expect(chain.memberEditModel.pendingUpdates, isEmpty);
        chain.dispose();
      });
    },
  );

  test(
    'Speichern eines wartenden Entwurfs waehrend eines Retry-Konflikts meldet keinen Erfolg',
    () {
      fakeAsync((async) {
        final chain = _SyncChain(
          async,
          connectivity: FakeConnectivity.offline(),
        );
        final basis = chain.loadMember();
        final entwurf = basis.copyWith(fahrtenname: 'Polka');
        chain.submit(entwurf);

        // Die Bearbeiten-Seite oeffnet den wartenden Entwurf samt Basis.
        late MemberEditPrepareResult prepared;
        chain.memberEditModel
            .prepareForEdit(
              accessToken: chain.authModel.session!.accessToken,
              mitglied: basis,
            )
            .then((value) => prepared = value);
        async.flushMicrotasks();
        expect(prepared.member, entwurf);
        expect(prepared.pendingEntry!.basisMitglied, basis);

        chain.api.serverEdit(_personId, <String, dynamic>{'nickname': 'Pfiff'});
        chain.connectivity.setWifi();
        // Ein Retry laeuft an, waehrend die Seite eine weitere Aenderung
        // speichert.
        unawaited(
          chain.memberEditModel.retryPending(
            accessToken: chain.authModel.session!.accessToken,
          ),
        );
        late MemberEditSubmitResult result;
        chain.memberEditModel
            .submitUpdate(
              accessToken: chain.authModel.session!.accessToken,
              basisMitglied: prepared.pendingEntry!.basisMitglied,
              zielMitglied: entwurf.copyWith(nachname: 'Kellermann'),
            )
            .then((value) => result = value);
        async.flushMicrotasks();

        expect(result.success, isFalse);
        expect(result.requiresResolution, isTrue);
        expect(chain.api.putRequests, isEmpty);
        expect(chain.api.attributeOf(_personId, 'nickname'), 'Pfiff');
        final entry = chain.memberEditModel.pendingUpdates.single;
        expect(entry.needsResolution, isTrue);
        expect(entry.zielMitglied.fahrtenname, 'Polka');
        expect(entry.zielMitglied.nachname, 'Kellermann');
        chain.dispose();
      });
    },
  );

  test(
    '422 bei einer Telefonnummer: offline gespeicherte Nummer wird zum Problemfall',
    () {
      fakeAsync((async) {
        final chain = _SyncChain(
          async,
          connectivity: FakeConnectivity.offline(),
        );
        final basis = chain.loadMember();

        final result = chain.submit(
          basis.copyWith(
            telefonnummern: const <MitgliedKontaktTelefon>[
              MitgliedKontaktTelefon(wert: '0170 abc', label: 'Mobil'),
            ],
          ),
        );
        expect(result.wasQueued, isTrue);

        chain.api.putFailure = FakePutFailure(
          422,
          body: validationErrorDocument(<Map<String, dynamic>>[
            phoneNumberValidationError(
              detail: 'Kategorie muss ausgefüllt werden',
              tempId: 'new-phone-1',
              attribute: 'category',
              code: 'blank',
            ),
            phoneNumberValidationError(
              detail: 'Nummer ist nicht gültig',
              tempId: 'new-phone-1',
            ),
          ]),
        );
        chain.connectivity.setWifi();
        async.flushMicrotasks();

        final put = chain.api.putRequests.single;
        final phoneData =
            put.body!['data']['relationships']['phone_numbers']['data']
                as List<dynamic>;
        expect(phoneData.single['method'], 'create');

        expect(chain.memberEditModel.openResolutionCount, 1);
        final resolutionCase =
            chain.memberEditModel.firstResolutionEntry!.resolutionCase!;
        expect(resolutionCase.items.map((item) => item.message), <String>[
          'Kategorie muss ausgefüllt werden',
          'Nummer ist nicht gültig',
        ]);
        for (final item in resolutionCase.items) {
          expect(item.problemType, MemberResolutionProblemType.validation);
          expect(item.target.type, MemberResolutionTargetType.phone);
          expect(item.target.relationshipId, isNull);
          expect(item.target.newContactOrdinal, 1);
        }
        // Beide Meldungen betreffen dieselbe Nummer und teilen sich die
        // Karte im Problemfall.
        expect(
          resolutionCase.items.map((item) => item.itemId).toSet(),
          hasLength(1),
        );
        expect(resolutionCase.source, MemberResolutionSource.pendingRetry);

        async.elapse(const Duration(hours: 2));
        expect(chain.api.putRequests, hasLength(1));
        expect(chain.api.phoneNumbersOf(_personId), isEmpty);
        chain.dispose();
      });
    },
  );

  test(
    '422 bei der zweiten neuen Nummer neben einer bestehenden trifft diese Nummer',
    () {
      fakeAsync((async) {
        final chain = _SyncChain(
          async,
          connectivity: FakeConnectivity.offline(),
          phoneNumbers: const <FixturePhoneNumber>[
            FixturePhoneNumber(
              id: 701,
              number: '+49401234567',
              label: 'Festnetz',
            ),
          ],
        );
        final basis = chain.loadMember();

        chain.submit(
          basis.copyWith(
            telefonnummern: <MitgliedKontaktTelefon>[
              ...basis.telefonnummern,
              const MitgliedKontaktTelefon(
                wert: '+491701234567',
                label: 'Mobil',
              ),
              const MitgliedKontaktTelefon(wert: '+49 abc', label: 'Dienst'),
            ],
          ),
        );
        chain.api.putFailure = FakePutFailure(
          422,
          body: validationErrorDocument(<Map<String, dynamic>>[
            phoneNumberValidationError(
              detail: 'Nummer ist nicht gültig',
              tempId: 'new-phone-2',
            ),
          ]),
        );
        chain.connectivity.setWifi();
        async.flushMicrotasks();

        final item = chain
            .memberEditModel
            .firstResolutionEntry!
            .resolutionCase!
            .items
            .single;
        expect(item.target.newContactOrdinal, 2);
        expect(item.message, 'Nummer ist nicht gültig');
        chain.dispose();
      });
    },
  );

  group('Auto-Sync bei aktiver Nutzung', () {
    test('wartet mit Nur-WLAN auf mobilen Daten und sendet im WLAN', () {
      fakeAsync((async) {
        final chain = _SyncChain(
          async,
          connectivity: FakeConnectivity.mobile(),
          noMobileDataEnabled: true,
        );
        final basis = chain.loadMember();

        final result = chain.submit(basis.copyWith(fahrtenname: 'Polka'));
        expect(result.wasQueued, isTrue);

        async.elapse(const Duration(minutes: 10));
        expect(chain.api.requests, isEmpty);

        chain.connectivity.setWifi();
        async.flushMicrotasks();

        expect(chain.api.putRequests, hasLength(1));
        expect(chain.memberEditModel.pendingUpdates, isEmpty);
        expect(chain.api.attributeOf(_personId, 'nickname'), 'Polka');
        chain.dispose();
      });
    });

    test('sendet bei erlaubten mobilen Daten, sobald Netz da ist', () {
      fakeAsync((async) {
        final chain = _SyncChain(
          async,
          connectivity: FakeConnectivity.offline(),
        );
        final basis = chain.loadMember();
        chain.submit(basis.copyWith(fahrtenname: 'Polka'));

        chain.connectivity.setMobile();
        async.flushMicrotasks();

        expect(chain.api.putRequests, hasLength(1));
        expect(chain.memberEditModel.pendingUpdates, isEmpty);
        expect(chain.api.attributeOf(_personId, 'nickname'), 'Polka');
        chain.dispose();
      });
    });

    test(
      'drosselt Fehlversuche, pausiert nach zehn und erlaubt nach Neustart einen weiteren',
      () {
        fakeAsync((async) {
          final chain = _SyncChain(
            async,
            connectivity: FakeConnectivity.wifi(),
          );
          final basis = chain.loadMember();
          chain.api.putFailure = const FakePutFailure(503);

          final result = chain.submit(basis.copyWith(fahrtenname: 'Polka'));
          expect(result.wasQueued, isTrue);

          async.elapse(const Duration(hours: 6));

          // Erster PUT beim Speichern, danach Timer-Versuche mit 1, 2, 4 ...
          // Minuten Abstand bis maximal 60 Minuten.
          expect(chain.putMinutes(), <int>[
            0,
            1,
            2,
            4,
            8,
            16,
            32,
            64,
            124,
            184,
            244,
          ]);
          expect(chain.memberEditModel.isAutomaticRetryPaused('4711'), isTrue);
          expect(
            chain.memberEditModel.pendingUpdates.single.status,
            PendingPersonUpdateStatus.queued,
          );

          chain.restartApp();
          async.elapse(const Duration(hours: 2));

          // Der Start-Check sendet sofort einmal, danach bleibt es pausiert.
          expect(chain.putMinutes().skip(11), <int>[360]);
          expect(chain.memberEditModel.isAutomaticRetryPaused('4711'), isTrue);

          chain.api.putFailure = null;
          chain.restartApp();
          expect(chain.putMinutes().last, 480);
          expect(chain.memberEditModel.pendingUpdates, isEmpty);
          expect(chain.api.attributeOf(_personId, 'nickname'), 'Polka');
          chain.dispose();
        });
      },
    );
  });

  test(
    'ungueltige Sitzung: kein Login-Browser, Hinweis einmal, Bearbeiten weiter wie offline',
    () {
      fakeAsync((async) {
        final chain = _SyncChain(
          async,
          connectivity: FakeConnectivity.offline(),
        );
        final basis = chain.loadMember();
        chain.submit(basis.copyWith(fahrtenname: 'Polka'));
        chain.api.rejectedAccessTokens.addAll(<String>[
          _storedToken,
          _refreshedToken,
        ]);

        chain.connectivity.setWifi();
        async.flushMicrotasks();

        // Gespeichertes und aufgefrischtes Token werden abgelehnt.
        expect(
          chain.api.requests.map((request) => request.accessToken),
          <String>[_storedToken, _refreshedToken],
        );
        expect(chain.oauthService.authenticateInteractiveCallCount, 0);
        expect(chain.authModel.requiresInteractiveLogin, isTrue);
        expect(chain.authModel.hasUnseenRemoteAccessIssueNotice, isTrue);
        expect(
          chain.memberEditModel.pendingUpdates.single.status,
          PendingPersonUpdateStatus.queued,
        );

        // Die Mitgliederliste zeigt den Hinweis und markiert ihn als gesehen.
        chain.authModel.markRemoteAccessIssueNoticeShown();
        chain.connectivity.setOffline();
        async.flushMicrotasks();
        chain.connectivity.setWifi();
        async.elapse(const Duration(hours: 2));

        expect(chain.api.requests, hasLength(2));
        expect(chain.authModel.hasUnseenRemoteAccessIssueNotice, isFalse);

        final next = chain.submit(basis.copyWith(fahrtenname: 'Polka II'));
        expect(next.wasQueued, isTrue);
        expect(next.suppressNotice, isTrue);
        expect(
          chain.memberEditModel.pendingUpdates.single.zielMitglied.fahrtenname,
          'Polka II',
        );
        expect(chain.api.requests, hasLength(2));
        expect(chain.authModel.hasUnseenRemoteAccessIssueNotice, isFalse);
        expect(chain.oauthService.authenticateInteractiveCallCount, 0);
        chain.dispose();
      });
    },
  );
}

const _personId = 23;
const _storedToken = 'stored-token';
const _refreshedToken = 'refreshed-token';
final _start = DateTime(2026, 4, 14, 9);

class _SyncChain {
  _SyncChain(
    this.async, {
    required this.connectivity,
    bool noMobileDataEnabled = false,
    List<FixturePhoneNumber> phoneNumbers = const <FixturePhoneNumber>[],
  }) {
    DateTime now() => _start.add(async.elapsed);
    final logger = FakeLoggerService();
    api = FakeHitobitoPeopleApi(clock: now)
      ..addPerson(
        id: _personId,
        membershipNumber: 4711,
        updatedAt: DateTime.utc(2026, 4, 1, 12),
        phoneNumbers: phoneNumbers,
      );
    oauthService = FakeOauthService(
      sessionToReturn: AuthSession(
        accessToken: _refreshedToken,
        refreshToken: 'refreshed-refresh-token',
        receivedAt: _start,
      ),
      profileToReturn: const AuthProfile(namiId: 1, language: 'de'),
    );
    authModel = AuthSessionModel(
      repository: InMemoryAuthSessionRepository(
        initialSession: AuthSession(
          accessToken: _storedToken,
          refreshToken: 'stored-refresh-token',
          receivedAt: _start,
        ),
      ),
      profileRepository: InMemoryAuthProfileRepository(
        profile: const AuthProfile(namiId: 1, language: 'de'),
        lastSyncAt: _start,
      ),
      oauthService: oauthService,
      biometricLockService: FakeBiometricLockService(),
      sensitiveStorageService: FakeSensitiveStorageService()
        ..lastSensitiveSyncAt = _start,
      retentionPolicy: HitobitoDataRetentionPolicy(
        maxDataAge: const Duration(days: 90),
        refreshInterval: const Duration(hours: 24),
        nowProvider: now,
      ),
      logger: logger,
      networkAccessPolicy: NetworkAccessPolicy(
        connectivity: connectivity,
        noMobileDataEnabled: () => noMobileDataEnabled,
        logger: logger,
      ),
    );
    unawaited(authModel.initialize());
    final peopleService = HitobitoPeopleService(
      config: testHitobitoAuthConfig,
      httpClient: api.client,
      logger: logger,
    );
    _writeRepository = HitobitoMemberWriteRepository(
      peopleService: peopleService,
      remoteAccessExecutor: authModel.executeRemoteAccess,
      logger: logger,
    );
    _peopleService = peopleService;
    _logger = logger;
    _now = now;
    _noMobileDataEnabled = noMobileDataEnabled;
    _startApp();
  }

  final FakeAsync async;
  final FakeConnectivity connectivity;
  late final FakeHitobitoPeopleApi api;
  late final FakeOauthService oauthService;
  late final AuthSessionModel authModel;
  late final HitobitoMemberWriteRepository _writeRepository;
  late final HitobitoPeopleService _peopleService;
  late final FakeLoggerService _logger;
  late final DateTime Function() _now;
  late final bool _noMobileDataEnabled;
  final InMemoryPendingPersonUpdateRepository _pendingRepository =
      InMemoryPendingPersonUpdateRepository();
  late MemberEditModel memberEditModel;
  late PendingSyncCoordinator _coordinator;
  Mitglied? _loadedMember;

  /// Stand der Person, wie ihn die App zuletzt geladen hat.
  Mitglied loadMember() {
    final wasOffline = api.offline;
    api.offline = false;
    late Mitglied member;
    _peopleService
        .fetchPersonResourceById(_storedToken, _personId)
        .then((resource) => member = resource.toMitglied());
    async.flushMicrotasks();
    api.offline = wasOffline;
    api.requests.clear();
    return _loadedMember = member;
  }

  /// Speichert [ziel] wie der Bearbeiten-Dialog auf Basis des zuletzt
  /// geladenen Stands.
  MemberEditSubmitResult submit(Mitglied ziel) {
    late MemberEditSubmitResult result;
    memberEditModel
        .submitUpdate(
          accessToken: authModel.session!.accessToken,
          basisMitglied: _loadedMember!,
          zielMitglied: ziel,
        )
        .then((value) => result = value);
    async.flushMicrotasks();
    return result;
  }

  /// Minuten seit Teststart, zu denen ein PUT ankam.
  List<int> putMinutes() => api.putRequests
      .map((request) => request.at!.difference(_start).inMinutes)
      .toList();

  /// Simuliert einen Neustart der App: neues MemberEditModel mit neuem
  /// Sitzungsbeginn und neuer Steuerung, gleicher Pending-Speicher.
  void restartApp() {
    _coordinator.dispose();
    _startApp();
  }

  void dispose() {
    _coordinator.dispose();
    async.flushMicrotasks();
  }

  void _startApp() {
    memberEditModel = MemberEditModel(
      memberWriteRepository: _writeRepository,
      pendingRepository: _pendingRepository,
      logger: _logger,
      onMemberUpdated: (_) async {},
      nowProvider: _now,
    );
    unawaited(memberEditModel.loadPending());
    _coordinator = PendingSyncCoordinator(
      connectivity: connectivity,
      authModel: authModel,
      memberEditModel: memberEditModel,
      noMobileDataEnabled: () => _noMobileDataEnabled,
      syncMembers: () async {},
    );
    _coordinator.start();
    unawaited(_coordinator.checkCurrentConnectivity(trigger: 'startup'));
    async.flushMicrotasks();
  }
}

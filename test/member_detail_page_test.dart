import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:latlong2/latlong.dart';
import 'package:nami/data/arbeitskontext/hitobito_group_resource.dart';
import 'package:nami/data/maps/in_memory_address_map_location_repository.dart';
import 'package:nami/data/settings/in_memory_address_settings_repository.dart';
import 'package:nami/domain/arbeitskontext/arbeitskontext.dart';
import 'package:nami/domain/arbeitskontext/arbeitskontext_local_repository.dart';
import 'package:nami/domain/arbeitskontext/arbeitskontext_read_model.dart';
import 'package:nami/domain/arbeitskontext/arbeitskontext_read_model_repository.dart';
import 'package:nami/domain/arbeitskontext/usecases/bestimme_startkontext_usecase.dart';
import 'package:nami/domain/auth/auth_profile.dart';
import 'package:nami/domain/auth/auth_profile_repository.dart';
import 'package:nami/domain/auth/auth_session.dart';
import 'package:nami/domain/auth/auth_session_repository.dart';
import 'package:nami/domain/auth/auth_state.dart';
import 'package:nami/domain/member/member_write_repository.dart';
import 'package:nami/domain/member/mitglied.dart';
import 'package:nami/domain/member/pending_person_update.dart';
import 'package:nami/domain/member/pending_person_update_repository.dart';
import 'package:nami/domain/settings/app_settings.dart';
import 'package:nami/domain/settings/app_settings_repository.dart';
import 'package:nami/domain/taetigkeit/stufe.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/presentation/model/arbeitskontext_model.dart';
import 'package:nami/presentation/model/auth_session_model.dart';
import 'package:nami/presentation/model/member_edit_model.dart';
import 'package:nami/presentation/screens/member_detail_page.dart';
import 'package:nami/services/biometric_lock_service.dart';
import 'package:nami/services/geoapify_address_map_service.dart';
import 'package:nami/services/hitobito_auth_env.dart';
import 'package:nami/services/hitobito_data_retention_policy.dart';
import 'package:nami/services/hitobito_groups_service.dart';
import 'package:nami/services/hitobito_oauth_service.dart';
import 'package:nami/services/logger_service.dart';
import 'package:nami/services/sensitive_storage_service.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('de');
  });

  testWidgets(
    'rendert Read-only-Details fuer ein Mitglied',
    (tester) async {
      final member = Mitglied(
        mitgliedsnummer: '4711',
        vorname: 'Julia',
        nachname: 'Keller',
        geburtsdatum: DateTime(2010, 4, 6),
        eintrittsdatum: DateTime(2020, 5, 1),
        updatedAt: DateTime(2024, 11, 7, 14, 35),
        telefonnummern: const <MitgliedKontaktTelefon>[
          MitgliedKontaktTelefon(wert: '+4940123456', label: 'Festnetznummer'),
        ],
        emailAdressen: const <MitgliedKontaktEmail>[
          MitgliedKontaktEmail(wert: 'julia@example.com', label: 'E-Mail'),
        ],
      );

      await tester.pumpWidget(
        _buildTestApp(MemberDetailPage(mitglied: member)),
      );

      await tester.pumpAndSettle();

      expect(find.text('Julia Keller'), findsOneWidget);
      expect(find.text('Allgemeine Informationen'), findsNothing);
      expect(find.text('Mitgliedschaft'), findsNothing);
      expect(find.text('4711'), findsOneWidget);
      expect(find.text('Zuletzt aktualisiert'), findsOneWidget);
      expect(find.text('07.11.2024, 14:35'), findsOneWidget);
    },
    timeout: const Timeout(Duration(seconds: 3)),
  );

  testWidgets(
    'blendet Platzhalterdaten fuer Geburtstag und Eintritt aus',
    (tester) async {
      final member = Mitglied.peopleListItem(
        mitgliedsnummer: '9',
        vorname: 'Max',
        nachname: 'Mustermann',
      );

      await tester.pumpWidget(
        _buildTestApp(MemberDetailPage(mitglied: member)),
      );

      await tester.pumpAndSettle();

      expect(find.text('Geburtstag'), findsNothing);
      expect(find.text('Eintrittsdatum'), findsNothing);
      expect(find.text('Mitgliedschaft'), findsNothing);
      expect(find.text('9'), findsOneWidget);
    },
    timeout: const Timeout(Duration(seconds: 3)),
  );

  testWidgets('zeigt die erste Adresse in den Details an', (tester) async {
    final member = Mitglied(
      personId: 23,
      mitgliedsnummer: '4711',
      vorname: 'Julia',
      nachname: 'Keller',
      geburtsdatum: DateTime(2010, 4, 6),
      eintrittsdatum: DateTime(2020, 5, 1),
      adressen: const <MitgliedKontaktAdresse>[
        MitgliedKontaktAdresse(
          additionalAddressId: 0,
          street: 'Musterweg',
          housenumber: '4',
          zipCode: '50667',
          town: 'Koeln',
          country: 'DE',
        ),
      ],
    );

    await tester.pumpWidget(
      _buildTestApp(
        MemberDetailPage(
          mitglied: member,
          addressLocationRepository: InMemoryAddressMapLocationRepository(),
          mapService: _NeverCompletingGeoapifyAddressMapService(),
          previewTimeout: const Duration(milliseconds: 100),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    expect(find.text('Adresse'), findsNothing);
    expect(find.text('Musterweg 4, 50667 Koeln'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets(
    'bricht eine haengende Kartenauflosung nach Timeout ab',
    (tester) async {
      final member = Mitglied(
        personId: 23,
        mitgliedsnummer: '4711',
        vorname: 'Julia',
        nachname: 'Keller',
        geburtsdatum: DateTime(2010, 4, 6),
        eintrittsdatum: DateTime(2020, 5, 1),
        adressen: const <MitgliedKontaktAdresse>[
          MitgliedKontaktAdresse(
            additionalAddressId: 0,
            street: 'Musterweg',
            housenumber: '4',
            zipCode: '50667',
            town: 'Koeln',
            country: 'DE',
          ),
        ],
      );

      await tester.pumpWidget(
        _buildTestApp(
          MemberDetailPage(
            mitglied: member,
            addressLocationRepository: InMemoryAddressMapLocationRepository(),
            addressSettingsRepository: InMemoryAddressSettingsRepository(),
            mapService: _NeverCompletingGeoapifyAddressMapService(),
            previewTimeout: const Duration(milliseconds: 100),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump();

      expect(find.text('Adresse'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    },
    timeout: const Timeout(Duration(seconds: 3)),
  );

  testWidgets(
    'zeigt Adresse nicht gefunden bei leerem Geocoding-Treffer',
    (tester) async {
      final member = Mitglied(
        personId: 23,
        mitgliedsnummer: '4711',
        vorname: 'Julia',
        nachname: 'Keller',
        geburtsdatum: DateTime(2010, 4, 6),
        eintrittsdatum: DateTime(2020, 5, 1),
        adressen: const <MitgliedKontaktAdresse>[
          MitgliedKontaktAdresse(
            additionalAddressId: 0,
            street: 'Musterweg',
            housenumber: '4',
            zipCode: '50667',
            town: 'Koeln',
            country: 'DE',
          ),
        ],
      );

      await tester.pumpWidget(
        _buildTestApp(
          MemberDetailPage(
            mitglied: member,
            addressLocationRepository: InMemoryAddressMapLocationRepository(),
            addressSettingsRepository: InMemoryAddressSettingsRepository(),
            mapService: _NullGeoapifyAddressMapService(),
            previewTimeout: const Duration(milliseconds: 100),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump();
    },
    timeout: const Timeout(Duration(seconds: 3)),
  );

  testWidgets('zeigt den Bearbeiten-Button bei Schreibrecht', (tester) async {
    final member = Mitglied.peopleListItem(
      mitgliedsnummer: '4711',
      personId: 23,
      primaryGroupId: 111,
      vorname: 'Julia',
      nachname: 'Keller',
    );
    final arbeitskontextModel = await _buildArbeitskontextModel(
      member: member,
      permissions: const <String>['group_and_below_full'],
    );

    await tester.pumpWidget(
      _buildTestApp(
        MemberDetailPage(mitglied: member),
        providers: <SingleChildWidget>[
          ChangeNotifierProvider<ArbeitskontextModel>.value(
            value: arbeitskontextModel,
          ),
        ],
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byTooltip('Person bearbeiten'), findsOneWidget);
  });

  testWidgets('zeigt den Pending-Hinweis fuer das passende Mitglied', (
    tester,
  ) async {
    final member = Mitglied.peopleListItem(
      mitgliedsnummer: '4711',
      personId: 23,
      vorname: 'Julia',
      nachname: 'Keller',
    );
    final memberEditModel = _StubMemberEditModel(
      pendingMitgliedsnummern: const <String>{'4711'},
    );

    await tester.pumpWidget(
      _buildTestApp(
        MemberDetailPage(mitglied: member),
        providers: <SingleChildWidget>[
          ChangeNotifierProvider<MemberEditModel>.value(value: memberEditModel),
        ],
      ),
    );

    await tester.pumpAndSettle();

    expect(
      find.text(
        'Für diese Person liegt eine ausstehende Änderung vor. Ein Retry ist in den Debug-Tools möglich.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('oeffnet den Editor mit dem frisch geladenen Mitglied', (
    tester,
  ) async {
    final member = Mitglied.peopleListItem(
      mitgliedsnummer: '4711',
      personId: 23,
      primaryGroupId: 111,
      vorname: 'Julia',
      nachname: 'Keller',
    );
    final refreshedMember = member.copyWith(
      vorname: 'Juliane',
      updatedAt: DateTime(2026, 4, 14, 12, 0),
    );
    final arbeitskontextModel = await _buildArbeitskontextModel(
      member: member,
      permissions: const <String>['group_and_below_full'],
    );

    await tester.pumpWidget(
      _buildTestApp(
        MemberDetailPage(mitglied: member),
        providers: <SingleChildWidget>[
          ChangeNotifierProvider<ArbeitskontextModel>.value(
            value: arbeitskontextModel,
          ),
          ChangeNotifierProvider<AuthSessionModel>.value(
            value: _StubAuthSessionModel(
              session: AuthSession(
                accessToken: 'token-123',
                receivedAt: DateTime(2026, 4, 14),
              ),
            ),
          ),
          ChangeNotifierProvider<MemberEditModel>.value(
            value: _PreparingMemberEditModel(refreshedMember: refreshedMember),
          ),
        ],
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Person bearbeiten'));
    await tester.pumpAndSettle();

    expect(find.text('Person bearbeiten'), findsOneWidget);
    final vornameField = tester.widget<TextFormField>(
      find.byType(TextFormField).first,
    );
    expect(vornameField.controller?.text, 'Juliane');
  });

  testWidgets('oeffnet den Editor auch mit lokalem Offline-Hinweis', (
    tester,
  ) async {
    final member = Mitglied.peopleListItem(
      mitgliedsnummer: '4711',
      personId: 23,
      primaryGroupId: 111,
      vorname: 'Julia',
      nachname: 'Keller',
    );
    final arbeitskontextModel = await _buildArbeitskontextModel(
      member: member,
      permissions: const <String>['group_and_below_full'],
    );

    await tester.pumpWidget(
      _buildTestApp(
        MemberDetailPage(mitglied: member),
        providers: <SingleChildWidget>[
          ChangeNotifierProvider<ArbeitskontextModel>.value(
            value: arbeitskontextModel,
          ),
          ChangeNotifierProvider<AuthSessionModel>.value(
            value: _StubAuthSessionModel(
              session: AuthSession(
                accessToken: 'token-123',
                receivedAt: DateTime(2026, 4, 14),
              ),
            ),
          ),
          ChangeNotifierProvider<MemberEditModel>.value(
            value: _PreparingMemberEditModel(
              refreshedMember: member,
              message:
                  'Bearbeitung erfolgt mit lokal gespeicherten Daten. Nur ueber WLAN.',
            ),
          ),
        ],
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Person bearbeiten'));
    await tester.pumpAndSettle();

    expect(find.text('Person bearbeiten'), findsOneWidget);
    expect(
      find.text(
        'Bearbeitung erfolgt mit lokal gespeicherten Daten. Nur ueber WLAN.',
      ),
      findsOneWidget,
    );
  });
}

Widget _buildTestApp(
  Widget home, {
  List<SingleChildWidget> providers = const <SingleChildWidget>[],
}) {
  final app = MaterialApp(
    localizationsDelegates: [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('de'), Locale('en')],
    home: home,
  );

  if (providers.isEmpty) {
    return app;
  }

  return MultiProvider(providers: providers, child: app);
}

class _NeverCompletingGeoapifyAddressMapService
    extends GeoapifyAddressMapService {
  _NeverCompletingGeoapifyAddressMapService()
    : super(apiKeyOverride: 'test-key');

  @override
  bool get hasApiKey => true;

  @override
  Future<LatLng?> geocodeAddress(String addressText) {
    return Completer<LatLng?>().future;
  }
}

class _NullGeoapifyAddressMapService extends GeoapifyAddressMapService {
  _NullGeoapifyAddressMapService() : super(apiKeyOverride: 'test-key');

  @override
  bool get hasApiKey => true;

  @override
  Future<LatLng?> geocodeAddress(String addressText) async => null;
}

Future<ArbeitskontextModel> _buildArbeitskontextModel({
  required Mitglied member,
  required List<String> permissions,
}) async {
  final readModel = ArbeitskontextReadModel(
    arbeitskontext: Arbeitskontext(
      aktiverLayer: const ArbeitskontextLayer(id: 11, name: 'Stamm Musterdorf'),
      verfuegbareLayer: const <ArbeitskontextLayer>[],
    ),
    mitglieder: <Mitglied>[member],
    gruppen: const <ArbeitskontextGruppe>[
      ArbeitskontextGruppe(id: 100, name: 'Meute', layerId: 11),
      ArbeitskontextGruppe(
        id: 111,
        name: 'Wölflinge 1',
        layerId: 11,
        parentId: 100,
      ),
    ],
  );
  final model = ArbeitskontextModel(
    localRepository: _FakeArbeitskontextLocalRepository(cached: readModel),
    readModelRepository: _FakeArbeitskontextReadModelRepository(),
    groupsService: _FakeHitobitoGroupsService(),
    bestimmeStartkontextUseCase: const BestimmeStartkontextUseCase(),
    logger: _FakeLoggerService(),
  );

  await model.syncForAuth(
    authState: AuthState.signedIn,
    session: AuthSession(
      accessToken: 'token-123',
      receivedAt: DateTime(2026, 4, 14),
    ),
    profile: AuthProfile(
      namiId: 23,
      roles: <AuthProfileRole>[
        AuthProfileRole(
          groupId: 100,
          groupName: 'Meute',
          roleName: 'Leitung',
          roleClass: 'Group::Woelfe::Leitung',
          permissions: permissions,
        ),
      ],
    ),
  );

  return model;
}

class _StubMemberEditModel extends MemberEditModel {
  _StubMemberEditModel({required this.pendingMitgliedsnummern})
    : super(
        memberWriteRepository: _NoopMemberWriteRepository(),
        pendingRepository: _NoopPendingPersonUpdateRepository(),
        logger: _FakeLoggerService(),
        onMemberUpdated: (_) async {},
      );

  final Set<String> pendingMitgliedsnummern;

  @override
  bool hasPendingForMitglied(String mitgliedsnummer) {
    return pendingMitgliedsnummern.contains(mitgliedsnummer);
  }
}

class _PreparingMemberEditModel extends MemberEditModel {
  _PreparingMemberEditModel({required this.refreshedMember, this.message})
    : super(
        memberWriteRepository: _NoopMemberWriteRepository(),
        pendingRepository: _NoopPendingPersonUpdateRepository(),
        logger: _FakeLoggerService(),
        onMemberUpdated: (_) async {},
      );

  final Mitglied refreshedMember;
  final String? message;

  @override
  Future<MemberEditPrepareResult> prepareForEdit({
    required String accessToken,
    required Mitglied mitglied,
    String trigger = 'detail_edit',
  }) async {
    return MemberEditPrepareResult(
      success: true,
      member: refreshedMember,
      message: message,
    );
  }
}

class _StubAuthSessionModel extends AuthSessionModel {
  _StubAuthSessionModel({required AuthSession session})
    : _sessionOverride = session,
      super(
        repository: _InMemoryAuthSessionRepository(initial: session),
        profileRepository: _InMemoryAuthProfileRepository(),
        oauthService: _FakeOauthService(),
        biometricLockService: _FakeBiometricLockService(),
        sensitiveStorageService: _FakeSensitiveStorageService(),
        retentionPolicy: HitobitoDataRetentionPolicy(
          maxDataAge: const Duration(days: 30),
          refreshInterval: const Duration(days: 1),
        ),
        logger: _FakeLoggerService(),
      );

  final AuthSession _sessionOverride;

  @override
  AuthSession? get session => _sessionOverride;
}

class _FakeArbeitskontextLocalRepository
    implements ArbeitskontextLocalRepository {
  _FakeArbeitskontextLocalRepository({this.cached});

  final ArbeitskontextReadModel? cached;

  @override
  Future<void> clearCached() async {}

  @override
  Future<ArbeitskontextReadModel?> loadLastCached() async => cached;

  @override
  Future<void> saveCached(ArbeitskontextReadModel readModel) async {}
}

class _FakeArbeitskontextReadModelRepository
    implements ArbeitskontextReadModelRepository {
  @override
  Future<ArbeitskontextReadModel> loadCached(
    Arbeitskontext arbeitskontext,
  ) async {
    return ArbeitskontextReadModel(arbeitskontext: arbeitskontext);
  }

  @override
  Future<ArbeitskontextReadModel> loadRoles({
    required String accessToken,
    required ArbeitskontextReadModel readModel,
  }) async {
    return readModel;
  }

  @override
  Future<ArbeitskontextReadModel> refresh({
    required String accessToken,
    required Arbeitskontext arbeitskontext,
  }) async {
    return ArbeitskontextReadModel(arbeitskontext: arbeitskontext);
  }
}

class _FakeHitobitoGroupsService extends HitobitoGroupsService {
  _FakeHitobitoGroupsService()
    : super(
        config: const HitobitoAuthConfig(
          clientId: 'client',
          clientSecret: 'secret',
          authorizationUrl: 'https://demo.hitobito.com/oauth/authorize',
          tokenUrl: 'https://demo.hitobito.com/oauth/token',
          redirectUri: 'de.jlange.nami.app:/oauth/callback',
          scopeString: 'openid email',
          discoveryUrl: '',
          profileUrl: 'https://demo.hitobito.com/oauth/profile',
        ),
      );

  @override
  Future<List<HitobitoGroupResource>> fetchAccessibleGroups(
    String accessToken,
  ) async => const <HitobitoGroupResource>[];
}

class _NoopMemberWriteRepository implements MemberWriteRepository {
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
    return zielMitglied;
  }
}

class _NoopPendingPersonUpdateRepository
    implements PendingPersonUpdateRepository {
  @override
  Future<void> clear() async {}

  @override
  Future<List<PendingPersonUpdate>> loadAll() async {
    return const <PendingPersonUpdate>[];
  }

  @override
  Future<void> remove(String entryId) async {}

  @override
  Future<void> save(PendingPersonUpdate entry) async {}
}

class _InMemoryAuthSessionRepository implements AuthSessionRepository {
  _InMemoryAuthSessionRepository({this.initial});

  final AuthSession? initial;

  @override
  Future<void> clear() async {}

  @override
  Future<AuthSession?> load() async => initial;

  @override
  Future<void> save(AuthSession session) async {}
}

class _InMemoryAuthProfileRepository implements AuthProfileRepository {
  @override
  Future<void> clear() async {}

  @override
  Future<AuthProfile?> loadCached() async => null;

  @override
  Future<DateTime?> loadLastSyncAt() async => null;

  @override
  Future<void> save(AuthProfile profile) async {}

  @override
  Future<void> saveLastSyncAt(DateTime timestamp) async {}
}

class _FakeOauthService extends HitobitoOauthService {
  _FakeOauthService()
    : super(
        config: const HitobitoAuthConfig(
          clientId: 'client',
          clientSecret: 'secret',
          authorizationUrl: 'https://demo.hitobito.com/oauth/authorize',
          tokenUrl: 'https://demo.hitobito.com/oauth/token',
          redirectUri: 'de.jlange.nami.app:/oauth/callback',
          scopeString: 'openid email',
          discoveryUrl: '',
          profileUrl: 'https://demo.hitobito.com/oauth/profile',
        ),
      );
}

class _FakeBiometricLockService extends BiometricLockService {
  _FakeBiometricLockService();

  @override
  Future<bool> authenticate() async => true;

  @override
  Future<bool> isAvailable() async => false;
}

class _FakeSensitiveStorageService extends SensitiveStorageService {
  @override
  Future<DateTime?> loadLastBackgroundedAt() async => null;

  @override
  Future<DateTime?> loadLastSensitiveSyncAt() async => null;

  @override
  Future<DateTime?> loadLastSensitiveSyncAttemptAt() async => null;

  @override
  Future<void> purgeSensitiveData() async {}
}

class _FakeLoggerService extends LoggerService {
  _FakeLoggerService()
    : super(
        settingsRepository: _FakeAppSettingsRepository(),
        navigatorKey: GlobalKey<NavigatorState>(),
      );

  @override
  Future<void> log(String service, String message) async {}

  @override
  Future<void> logInfo(String service, String message) async {}

  @override
  Future<void> logWarn(String service, String message) async {}

  @override
  Future<void> logError(
    String service,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) async {}
}

class _FakeAppSettingsRepository extends AppSettingsRepository {
  @override
  Future<AppSettings> load() async => const AppSettings(
    themeMode: ThemeMode.system,
    languageCode: 'de',
    analyticsEnabled: false,
  );

  @override
  Future<void> saveAnalyticsEnabled(bool enabled) async {}

  @override
  Future<void> saveBiometricLockEnabled(bool enabled) async {}

  @override
  Future<void> saveMemberListSearchResultHighlightEnabled(bool enabled) async {}

  @override
  Future<void> saveGeburstagsbenachrichtigungStufen(Set<Stufe> stufen) async {}

  @override
  Future<void> saveLanguageCode(String code) async {}

  @override
  Future<void> saveNotificationsEnabled(bool enabled) async {}

  @override
  Future<void> saveThemeMode(ThemeMode mode) async {}
}

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nami/data/arbeitskontext/hitobito_group_resource.dart';
import 'package:nami/domain/arbeitskontext/arbeitskontext.dart';
import 'package:nami/domain/arbeitskontext/arbeitskontext_local_repository.dart';
import 'package:nami/domain/arbeitskontext/arbeitskontext_read_model.dart';
import 'package:nami/domain/arbeitskontext/arbeitskontext_read_model_repository.dart';
import 'package:nami/domain/arbeitskontext/usecases/bestimme_startkontext_usecase.dart';
import 'package:nami/domain/auth/auth_profile.dart';
import 'package:nami/domain/auth/auth_session.dart';
import 'package:nami/domain/auth/auth_state.dart';
import 'package:nami/domain/member/mitglied.dart';
import 'package:nami/domain/settings/app_settings.dart';
import 'package:nami/domain/settings/app_settings_repository.dart';
import 'package:nami/domain/taetigkeit/stufe.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/presentation/model/arbeitskontext_model.dart';
import 'package:nami/presentation/screens/statistics_page.dart';
import 'package:nami/services/hitobito_auth_env.dart';
import 'package:nami/services/hitobito_groups_service.dart';
import 'package:nami/services/logger_service.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('zeigt die Mitgliederanzahl des aktiven Arbeitskontexts an', (
    tester,
  ) async {
    final model = await _createArbeitskontextModel();

    await tester.pumpWidget(_buildTestApp(model: model));
    await tester.pump();

    expect(find.text('Anzahl: 2'), findsOneWidget);
  });

  testWidgets('aktualisiert die Anzahl nach einem Layerwechsel', (
    tester,
  ) async {
    final model = await _createArbeitskontextModel();
    final session = AuthSession(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      receivedAt: DateTime(2026, 4, 6),
    );
    const profile = AuthProfile(
      namiId: 7,
      firstName: 'Julia',
      lastName: 'Keller',
      language: 'de',
      primaryGroupId: 11,
      roles: <AuthProfileRole>[
        AuthProfileRole(
          groupId: 11,
          groupName: 'Stamm Musterdorf',
          roleName: 'Stammesfuehrung',
          roleClass: 'Group::Stamm::Leader',
          permissions: <String>['layer_read'],
        ),
        AuthProfileRole(
          groupId: 20,
          groupName: 'Bezirk Rhein',
          roleName: 'Bezirksfuehrung',
          roleClass: 'Group::Bezirk::Leader',
          permissions: <String>['layer_read'],
        ),
      ],
    );

    await tester.pumpWidget(_buildTestApp(model: model));
    await tester.pump();

    expect(find.text('Anzahl: 2'), findsOneWidget);

    final changed = await model.switchToLayer(
      targetLayer: const ArbeitskontextLayer(id: 20, name: 'Bezirk Rhein'),
      session: session,
      profile: profile,
    );

    expect(changed, isTrue);
    await tester.pump();

    expect(find.text('Anzahl: 1'), findsOneWidget);
  });
}

Widget _buildTestApp({required ArbeitskontextModel model}) {
  return ChangeNotifierProvider<ArbeitskontextModel>.value(
    value: model,
    child: MaterialApp(
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('de'), Locale('en')],
      locale: const Locale('de'),
      home: const Scaffold(body: StatisticsPage()),
    ),
  );
}

Future<ArbeitskontextModel> _createArbeitskontextModel() async {
  final repository = _FakeArbeitskontextReadModelRepository();
  final model = ArbeitskontextModel(
    localRepository: _FakeArbeitskontextLocalRepository(
      cached: repository.readModelForLayer(11),
    ),
    readModelRepository: repository,
    groupsService: _FakeHitobitoGroupsService(),
    bestimmeStartkontextUseCase: const BestimmeStartkontextUseCase(),
    logger: _FakeLoggerService(),
  );

  await model.syncForAuth(
    authState: AuthState.signedIn,
    session: AuthSession(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      receivedAt: DateTime(2026, 4, 6),
    ),
    profile: const AuthProfile(
      namiId: 7,
      firstName: 'Julia',
      lastName: 'Keller',
      language: 'de',
      primaryGroupId: 11,
      roles: <AuthProfileRole>[
        AuthProfileRole(
          groupId: 11,
          groupName: 'Stamm Musterdorf',
          roleName: 'Stammesfuehrung',
          roleClass: 'Group::Stamm::Leader',
          permissions: <String>['layer_read'],
        ),
        AuthProfileRole(
          groupId: 20,
          groupName: 'Bezirk Rhein',
          roleName: 'Bezirksfuehrung',
          roleClass: 'Group::Bezirk::Leader',
          permissions: <String>['layer_read'],
        ),
      ],
    ),
  );

  return model;
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
  Future<ArbeitskontextReadModel> loadRoles({
    required String accessToken,
    required ArbeitskontextReadModel readModel,
  }) async {
    return readModel;
  }

  ArbeitskontextReadModel readModelForLayer(int layerId) {
    switch (layerId) {
      case 20:
        return ArbeitskontextReadModel(
          arbeitskontext: Arbeitskontext(
            aktiverLayer: ArbeitskontextLayer(id: 20, name: 'Bezirk Rhein'),
            verfuegbareLayer: <ArbeitskontextLayer>[
              ArbeitskontextLayer(id: 11, name: 'Stamm Musterdorf'),
            ],
          ),
          mitglieder: <Mitglied>[
            Mitglied.peopleListItem(
              mitgliedsnummer: '2001',
              vorname: 'Max',
              nachname: 'Mustermann',
            ),
          ],
        );
      case 11:
      default:
        return ArbeitskontextReadModel(
          arbeitskontext: Arbeitskontext(
            aktiverLayer: ArbeitskontextLayer(id: 11, name: 'Stamm Musterdorf'),
            verfuegbareLayer: <ArbeitskontextLayer>[
              ArbeitskontextLayer(id: 20, name: 'Bezirk Rhein'),
            ],
          ),
          mitglieder: <Mitglied>[
            Mitglied.peopleListItem(
              mitgliedsnummer: '1001',
              vorname: 'Julia',
              nachname: 'Keller',
            ),
            Mitglied.peopleListItem(
              mitgliedsnummer: '1002',
              vorname: 'Lea',
              nachname: 'Beispiel',
            ),
          ],
        );
    }
  }

  @override
  Future<ArbeitskontextReadModel> loadCached(
    Arbeitskontext arbeitskontext,
  ) async {
    return readModelForLayer(arbeitskontext.aktiverLayer.id);
  }

  @override
  Future<ArbeitskontextReadModel> refresh({
    required String accessToken,
    required Arbeitskontext arbeitskontext,
  }) async {
    return readModelForLayer(arbeitskontext.aktiverLayer.id);
  }
}

class _FakeHitobitoGroupsService extends HitobitoGroupsService {
  _FakeHitobitoGroupsService()
    : super(
        config: const HitobitoAuthConfig(
          clientId: 'client',
          clientSecret: 'secret',
          authorizationUrl: 'https://example.invalid/oauth/authorize',
          tokenUrl: 'https://example.invalid/oauth/token',
          redirectUri: 'nami://oauth',
          scopeString: HitobitoAuthConfig.defaultScopeString,
          discoveryUrl:
              'https://example.invalid/.well-known/openid-configuration',
          profileUrl: 'https://example.invalid/de/oauth/profile',
        ),
      );

  @override
  Future<List<HitobitoGroupResource>> fetchAccessibleGroups(
    String accessToken,
  ) async {
    return const <HitobitoGroupResource>[
      HitobitoGroupResource(
        id: 11,
        name: 'Stamm Musterdorf',
        isLayer: true,
        layerGroupId: 11,
      ),
      HitobitoGroupResource(
        id: 20,
        name: 'Bezirk Rhein',
        isLayer: true,
        layerGroupId: 20,
      ),
    ];
  }
}

class _FakeLoggerService extends LoggerService {
  _FakeLoggerService()
    : super(
        settingsRepository: _FakeAppSettingsRepository(),
        navigatorKey: GlobalKey<NavigatorState>(),
        logFileProvider: () async =>
            File('${Directory.systemTemp.path}/statistics_page_test.log'),
      );

  @override
  Future<void> log(String category, String message) async {}

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

class _FakeAppSettingsRepository implements AppSettingsRepository {
  @override
  Future<AppSettings> load() async {
    return const AppSettings(
      themeMode: ThemeMode.system,
      languageCode: 'de',
      analyticsEnabled: false,
    );
  }

  @override
  Future<void> saveAnalyticsEnabled(bool enabled) async {}

  @override
  Future<void> saveGeburstagsbenachrichtigungStufen(Set<Stufe> stufen) async {}

  @override
  Future<void> saveLanguageCode(String code) async {}

  @override
  Future<void> saveMemberListSearchResultHighlightEnabled(bool enabled) async {}

  @override
  Future<void> saveNotificationsEnabled(bool enabled) async {}

  @override
  Future<void> saveThemeMode(ThemeMode mode) async {}

  @override
  Future<void> saveBiometricLockEnabled(bool enabled) async {}
}

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:nami/domain/arbeitskontext/teildaten_stand.dart';
import 'package:nami/domain/auth/auth_profile.dart';
import 'package:nami/domain/auth/auth_session.dart';
import 'package:nami/domain/member/efz_einsichtnahme.dart';
import 'package:nami/domain/member/mitglied.dart';
import 'package:nami/domain/qualifikation/qualifikation.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/presentation/model/auth_session_model.dart';
import 'package:nami/presentation/widgets/member_detail/member_qualifikationen_tab.dart';
import 'package:nami/presentation/widgets/neuanmeldung_sheet.dart';
import 'package:nami/services/hitobito_data_retention_policy.dart';
import 'package:nami/services/hitobito_efz_service.dart';
import 'package:nami/stories/support/mitglied_edge_cases.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import 'support/auth_session_fakes.dart';
import 'support/fake_logger_service.dart';
import 'support/hitobito_jsonapi_fixtures.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('de');
  });

  final mitglied = MitgliedEdgeCases.funke;

  Future<void> zeige(
    WidgetTester tester, {
    TeildatenStand efzStand = TeildatenStand.geladen,
    List<EfzEinsichtnahme> efz = const <EfzEinsichtnahme>[],
    TeildatenStand qualiStand = TeildatenStand.geladen,
    List<Qualifikation> qualis = const <Qualifikation>[],
    bool vollLesbar = true,
    List<SingleChildWidget> provider = const <SingleChildWidget>[],
    Mitglied? anzeigen,
  }) async {
    final app = MaterialApp(
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('de')],
      locale: const Locale('de'),
      home: Scaffold(
        body: MemberQualifikationenTab(
          key: UniqueKey(),
          mitglied: anzeigen ?? mitglied,
          heute: MitgliedEdgeCases.heute,
          efzStand: efzStand,
          efzEinsichtnahmen: efz,
          qualifikationenStand: qualiStand,
          qualifikationen: qualis,
          vollLesbar: vollLesbar,
        ),
      ),
    );
    await tester.pumpWidget(
      provider.isEmpty ? app : MultiProvider(providers: provider, child: app),
    );
    await tester.pump();
  }

  EfzEinsichtnahme ausgestellt(DateTime datum) =>
      EfzEinsichtnahme(id: 1, personId: mitglied.personId!, issuedOn: datum);

  testWidgets('zeigt alle EFZ-Zustaende kompakt', (tester) async {
    await zeige(tester);
    expect(find.text('Keines hinterlegt'), findsOneWidget);
    expect(find.byKey(const Key('efz-antrag-download')), findsOneWidget);

    await zeige(tester, efz: [ausgestellt(DateTime(2025, 8, 30))]);
    expect(find.text('Gültig bis 30.08.2030'), findsOneWidget);
    expect(find.byKey(const ValueKey('status-punkt-gut')), findsOneWidget);

    await zeige(tester, efz: [ausgestellt(DateTime(2021, 11, 20))]);
    expect(find.text('Gültig bis 20.11.2026'), findsOneWidget);
    expect(find.text('noch 7 Wochen'), findsOneWidget);
    expect(find.byKey(const ValueKey('status-punkt-warnung')), findsOneWidget);

    await zeige(tester, efz: [ausgestellt(DateTime(2019, 10, 1))]);
    expect(find.text('Abgelaufen am 01.10.2024'), findsOneWidget);
    expect(find.byKey(const ValueKey('status-punkt-kritisch')), findsOneWidget);

    await zeige(tester, efzStand: TeildatenStand.unbekannt);
    expect(find.text('Noch nicht synchronisiert'), findsOneWidget);
    expect(find.text('Wird beim nächsten Abgleich geladen'), findsOneWidget);

    await zeige(tester, efzStand: TeildatenStand.keineBerechtigung);
    expect(find.text('Keine Berechtigung'), findsOneWidget);
    expect(find.byKey(const Key('efz-antrag-download')), findsNothing);
  });

  testWidgets(
    'zeigt bei nicht voll lesbarer Person Keine Berechtigung statt Keines hinterlegt',
    (tester) async {
      // Hitobito antwortet bei group_read mit 200 und leerer Liste.
      await zeige(tester, vollLesbar: false);

      expect(find.text('Keines hinterlegt'), findsNothing);
      expect(find.text('Keine Qualifikationen hinterlegt'), findsNothing);
      expect(find.text('Keine Berechtigung'), findsNWidgets(2));
      expect(find.byKey(const Key('efz-antrag-download')), findsNothing);
      expect(
        find.text(
          'Qualifikationen und EFZ dieser Person liefert Hitobito mit deinen Rechten nicht.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('sortiert abgelaufene Qualifikationen ans Ende', (tester) async {
    await zeige(
      tester,
      qualis: MitgliedEdgeCases.qualifikationen
          .where((q) => q.personId == mitglied.personId)
          .toList(),
    );

    expect(find.text('5'), findsOneWidget);
    expect(find.text('erworben 10.06.2019 · ohne Ablauf'), findsOneWidget);
    expect(find.text('abgelaufen 01.05.2023 · reaktivierbar'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Juleica')).dy,
      greaterThan(tester.getTopLeft(find.text('Modulausbildung')).dy),
    );
  });

  testWidgets('meldet fehlende Daten statt still zu scheitern', (tester) async {
    await zeige(tester);

    await tester.tap(find.byKey(const Key('efz-antrag-download')));
    await tester.pump();

    expect(
      find.text(
        'Antragsunterlagen konnten nicht geladen werden (fehlende Daten).',
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'fragt bei abgelaufener Anmeldung nach, statt den Browser zu oeffnen',
    (tester) async {
      final tag = DateTime(2026, 10, 8);
      final authModel = AuthSessionModel(
        repository: InMemoryAuthSessionRepository(
          initialSession: AuthSession(
            accessToken: 'alt',
            refreshToken: 'refresh-alt',
            receivedAt: tag,
          ),
        ),
        profileRepository: InMemoryAuthProfileRepository(
          profile: const AuthProfile(namiId: 1, language: 'de'),
          lastSyncAt: tag,
        ),
        oauthService: FakeOauthService(
          sessionToReturn: AuthSession(
            accessToken: 'neu',
            refreshToken: 'refresh-neu',
            receivedAt: tag,
          ),
          profileToReturn: const AuthProfile(namiId: 1, language: 'de'),
        ),
        biometricLockService: FakeBiometricLockService(),
        sensitiveStorageService: FakeSensitiveStorageService()
          ..lastSensitiveSyncAt = tag,
        retentionPolicy: HitobitoDataRetentionPolicy(
          maxDataAge: const Duration(days: 90),
          refreshInterval: const Duration(hours: 24),
          nowProvider: () => tag.add(const Duration(hours: 2)),
        ),
        logger: FakeLoggerService(),
      );
      await authModel.initialize();
      final anfragen = <String>[];
      final efzService = HitobitoEfzService(
        config: testHitobitoAuthConfig,
        httpClient: MockClient((request) async {
          anfragen.add(request.headers['Authorization'] ?? '');
          return http.Response('', 401);
        }),
      );

      await zeige(
        tester,
        anzeigen: mitglied.copyWith(primaryGroupId: 11),
        provider: <SingleChildWidget>[
          ChangeNotifierProvider<AuthSessionModel>.value(value: authModel),
          Provider<HitobitoEfzService>.value(value: efzService),
        ],
      );
      await tester.tap(find.byKey(const Key('efz-antrag-download')));
      await tester.pumpAndSettle();

      expect(find.byType(NeuanmeldungSheet), findsOneWidget);
      expect(anfragen, <String>['Bearer alt', 'Bearer neu']);
      expect(authModel.requiresInteractiveLogin, isTrue);

      await tester.tap(find.byKey(const Key('neuanmeldung-spaeter')));
      await tester.pumpAndSettle();
      expect(find.byType(NeuanmeldungSheet), findsNothing);
    },
  );
}

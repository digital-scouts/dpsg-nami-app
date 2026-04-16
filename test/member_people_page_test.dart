import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:nami/data/arbeitskontext/hitobito_group_resource.dart';
import 'package:nami/domain/arbeitskontext/arbeitskontext.dart';
import 'package:nami/domain/arbeitskontext/arbeitskontext_local_repository.dart';
import 'package:nami/domain/arbeitskontext/arbeitskontext_read_model.dart';
import 'package:nami/domain/arbeitskontext/arbeitskontext_read_model_repository.dart';
import 'package:nami/domain/arbeitskontext/usecases/bestimme_startkontext_usecase.dart';
import 'package:nami/domain/auth/auth_profile.dart';
import 'package:nami/domain/auth/auth_profile_repository.dart';
import 'package:nami/domain/auth/auth_session.dart';
import 'package:nami/domain/auth/auth_session_repository.dart';
import 'package:nami/domain/member/member_write_repository.dart';
import 'package:nami/domain/member/mitglied.dart';
import 'package:nami/domain/member/pending_person_update.dart';
import 'package:nami/domain/member/pending_person_update_repository.dart';
import 'package:nami/domain/member_filters/member_filter_repository.dart';
import 'package:nami/domain/settings/app_settings.dart';
import 'package:nami/domain/settings/app_settings_repository.dart';
import 'package:nami/domain/taetigkeit/stufe.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/presentation/model/arbeitskontext_model.dart';
import 'package:nami/presentation/model/auth_session_model.dart';
import 'package:nami/presentation/model/member_edit_model.dart';
import 'package:nami/presentation/model/member_filters_model.dart';
import 'package:nami/presentation/navigation/app_router.dart';
import 'package:nami/presentation/screens/member_people_page.dart';
import 'package:nami/presentation/widgets/member_basis.dart';
import 'package:nami/presentation/widgets/member_list_group_filter_bar.dart';
import 'package:nami/presentation/widgets/member_list_search_bar.dart';
import 'package:nami/services/biometric_lock_service.dart';
import 'package:nami/services/hitobito_auth_env.dart';
import 'package:nami/services/hitobito_data_retention_policy.dart';
import 'package:nami/services/hitobito_groups_service.dart';
import 'package:nami/services/hitobito_oauth_service.dart';
import 'package:nami/services/logger_service.dart';
import 'package:nami/services/sensitive_storage_service.dart';
import 'package:provider/provider.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('de');
  });

  testWidgets(
    'zeigt lokal geladenen Mitgliederbestand des Arbeitskontexts an',
    (tester) async {
      final authModel = await _createSignedInAuthModel();
      final arbeitskontextModel = await _createArbeitskontextModel(
        mitglieder: <Mitglied>[
          Mitglied.peopleListItem(
            mitgliedsnummer: '1',
            vorname: 'Julia',
            nachname: 'Keller',
          ),
          Mitglied.peopleListItem(
            mitgliedsnummer: '2',
            vorname: 'Max',
            nachname: 'Mustermann',
          ),
        ],
        authModel: authModel,
      );

      await tester.pumpWidget(
        _buildTestApp(
          authModel: authModel,
          arbeitskontextModel: arbeitskontextModel,
        ),
      );

      await tester.pump();

      expect(find.text('Julia Keller'), findsOneWidget);
      expect(find.text('Max Mustermann'), findsOneWidget);
      expect(find.byType(MemberSearchBar), findsOneWidget);
      expect(find.byType(GroupFilterBar), findsOneWidget);
    },
  );

  testWidgets('nutzt auf der Members-Page den Subtitle-Modus der Listen-UI', (
    tester,
  ) async {
    final authModel = await _createSignedInAuthModel();
    final arbeitskontextModel = await _createArbeitskontextModel(
      mitglieder: <Mitglied>[
        Mitglied.peopleListItem(
          mitgliedsnummer: '4711',
          vorname: 'Julia',
          nachname: 'Keller',
        ),
      ],
      gruppen: const <ArbeitskontextGruppe>[
        ArbeitskontextGruppe(id: 21, name: 'Woelflingsmeute', layerId: 11),
        ArbeitskontextGruppe(id: 22, name: 'Juffistufe', layerId: 11),
      ],
      mitgliedsZuordnungen: const <ArbeitskontextMitgliedsZuordnung>[
        ArbeitskontextMitgliedsZuordnung(
          mitgliedsnummer: '4711',
          gruppenId: 21,
          rollenLabel: 'Vorstandsmitglied',
        ),
        ArbeitskontextMitgliedsZuordnung(
          mitgliedsnummer: '4711',
          gruppenId: 22,
          rollenLabel: 'Mitglied',
        ),
      ],
      authModel: authModel,
    );

    await tester.pumpWidget(
      _buildTestApp(
        authModel: authModel,
        arbeitskontextModel: arbeitskontextModel,
      ),
    );

    await tester.pump();

    expect(find.text('Julia Keller'), findsOneWidget);
    expect(find.text('4711'), findsOneWidget);
    expect(find.text('Woelflingsmeute\nVorstandsmitglied'), findsOneWidget);
  });

  testWidgets(
    'zeigt Snackbar bei vorhandenem Remote-Issue und belaesst lokale Daten sichtbar',
    (tester) async {
      final authModel = await _createSignedInAuthModel();
      final arbeitskontextModel = await _createArbeitskontextModel(
        mitglieder: <Mitglied>[
          Mitglied.peopleListItem(
            mitgliedsnummer: '1',
            vorname: 'Julia',
            nachname: 'Keller',
          ),
        ],
        authModel: authModel,
      );
      authModel.reportRemoteDataIssue('offline');

      await tester.pumpWidget(
        _buildTestApp(
          authModel: authModel,
          arbeitskontextModel: arbeitskontextModel,
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Julia Keller'), findsOneWidget);
      expect(
        find.text(
          'Hitobito-Daten konnten nicht aktualisiert werden. Es werden lokale Daten angezeigt.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'zeigt den Remote-Issue-Hinweis nur einmal pro zusammenhaengender Issue-Phase',
    (tester) async {
      final authModel = await _createSignedInAuthModel();
      final arbeitskontextModel = await _createArbeitskontextModel(
        mitglieder: <Mitglied>[
          Mitglied.peopleListItem(
            mitgliedsnummer: '1',
            vorname: 'Julia',
            nachname: 'Keller',
          ),
        ],
        authModel: authModel,
      );
      authModel.reportRemoteDataIssue('offline');

      await tester.pumpWidget(
        _buildTestApp(
          authModel: authModel,
          arbeitskontextModel: arbeitskontextModel,
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(authModel.hasUnseenRemoteAccessIssueNotice, isFalse);
      expect(
        find.text(
          'Hitobito-Daten konnten nicht aktualisiert werden. Es werden lokale Daten angezeigt.',
        ),
        findsOneWidget,
      );

      ScaffoldMessenger.of(
        tester.element(find.byType(MemberPeoplePage)),
      ).hideCurrentSnackBar();
      await tester.pumpAndSettle();

      authModel.reportRemoteDataIssue('weiterhin offline');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(authModel.hasUnseenRemoteAccessIssueNotice, isFalse);
      expect(
        find.text(
          'Hitobito-Daten konnten nicht aktualisiert werden. Es werden lokale Daten angezeigt.',
        ),
        findsNothing,
      );

      authModel.clearRemoteDataIssue();
      authModel.reportRemoteDataIssue('erneut offline');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.text(
          'Hitobito-Daten konnten nicht aktualisiert werden. Es werden lokale Daten angezeigt.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('trackt den Resolution-Hinweis auf der Members-Page', (
    tester,
  ) async {
    final authModel = await _createSignedInAuthModel();
    final arbeitskontextModel = await _createArbeitskontextModel(
      mitglieder: <Mitglied>[
        Mitglied.peopleListItem(
          mitgliedsnummer: '1',
          vorname: 'Julia',
          nachname: 'Keller',
        ),
      ],
      authModel: authModel,
    );
    final memberEditModel = _HintTrackingMemberEditModel(
      openResolutionCount: 2,
    );

    await tester.pumpWidget(
      _buildTestApp(
        authModel: authModel,
        arbeitskontextModel: arbeitskontextModel,
        memberEditModel: memberEditModel,
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.text('Es gibt 2 offene Problemfaelle bei Mitglieds-Aenderungen.'),
      findsOneWidget,
    );
    expect(memberEditModel.loggedHints, <(String, int)>[('people_list', 2)]);
  });

  testWidgets('rendert die neue Listen-UI auch mit leerem Vor- und Nachnamen', (
    tester,
  ) async {
    final authModel = await _createSignedInAuthModel();
    final arbeitskontextModel = await _createArbeitskontextModel(
      mitglieder: <Mitglied>[
        Mitglied.peopleListItem(
          mitgliedsnummer: '3',
          vorname: '',
          nachname: '',
        ),
      ],
      authModel: authModel,
    );

    await tester.pumpWidget(
      _buildTestApp(
        authModel: authModel,
        arbeitskontextModel: arbeitskontextModel,
      ),
    );

    await tester.pump();

    expect(find.byType(MemberSearchBar), findsOneWidget);
    expect(find.byType(GroupFilterBar), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('zeigt Login-Hinweis ohne Session und ohne Kontextdaten', (
    tester,
  ) async {
    final authModel = AuthSessionModel(
      repository: _InMemoryAuthSessionRepository(),
      profileRepository: _InMemoryAuthProfileRepository(),
      oauthService: _FakeOauthService(),
      biometricLockService: _FakeBiometricLockService(),
      sensitiveStorageService: _FakeSensitiveStorageService(),
      retentionPolicy: HitobitoDataRetentionPolicy(
        maxDataAge: const Duration(days: 90),
        refreshInterval: const Duration(hours: 24),
      ),
      logger: _FakeLoggerService(),
    );
    final arbeitskontextModel = ArbeitskontextModel(
      localRepository: _FakeArbeitskontextLocalRepository(),
      readModelRepository: _FakeArbeitskontextReadModelRepository(),
      groupsService: _FakeHitobitoGroupsService(),
      bestimmeStartkontextUseCase: const BestimmeStartkontextUseCase(),
      logger: _FakeLoggerService(),
    );

    await tester.pumpWidget(
      _buildTestApp(
        authModel: authModel,
        arbeitskontextModel: arbeitskontextModel,
      ),
    );

    await tester.pump();

    expect(
      find.text('Melde dich an, um Mitglieder aus Hitobito zu laden.'),
      findsOneWidget,
    );
  });

  testWidgets('oeffnet bei Tap auf ein Mitglied die Read-only-Detailansicht', (
    tester,
  ) async {
    final authModel = await _createSignedInAuthModel();
    final arbeitskontextModel = await _createArbeitskontextModel(
      mitglieder: <Mitglied>[
        Mitglied(
          mitgliedsnummer: '4711',
          vorname: 'Julia',
          nachname: 'Keller',
          geburtsdatum: DateTime(2010, 4, 6),
          eintrittsdatum: DateTime(2020, 5, 1),
          telefonnummern: const <MitgliedKontaktTelefon>[
            MitgliedKontaktTelefon(
              wert: '+4940123456',
              label: 'Festnetznummer',
            ),
          ],
          emailAdressen: const <MitgliedKontaktEmail>[
            MitgliedKontaktEmail(wert: 'julia@example.com', label: 'E-Mail'),
          ],
        ),
      ],
      authModel: authModel,
    );

    await tester.pumpWidget(
      _buildTestApp(
        authModel: authModel,
        arbeitskontextModel: arbeitskontextModel,
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.text('Julia Keller'));
    await tester.pumpAndSettle();

    expect(find.byType(MemberDetails), findsOneWidget);
    expect(find.text('Allgemeine Informationen'), findsNothing);
    expect(find.text('Mitgliedschaft'), findsNothing);
    expect(find.text('Festnetznummer'), findsOneWidget);
    expect(find.text('4711'), findsOneWidget);
  });

  testWidgets(
    'filtert die Members-Page lokal nach Stufen aus dem Arbeitskontext',
    (tester) async {
      final authModel = await _createSignedInAuthModel();
      final arbeitskontextModel = await _createArbeitskontextModel(
        mitglieder: <Mitglied>[
          Mitglied.peopleListItem(
            mitgliedsnummer: '1',
            vorname: 'Julia',
            nachname: 'Keller',
          ),
          Mitglied.peopleListItem(
            mitgliedsnummer: '2',
            vorname: 'Mara',
            nachname: 'Schmidt',
          ),
        ],
        gruppen: const <ArbeitskontextGruppe>[
          ArbeitskontextGruppe(
            id: 21,
            name: 'Woelflinge',
            layerId: 11,
            gruppenTyp: 'Group::Meute',
          ),
          ArbeitskontextGruppe(
            id: 22,
            name: 'Pfadis',
            layerId: 11,
            gruppenTyp: 'Group::Sippe',
          ),
        ],
        mitgliedsZuordnungen: const <ArbeitskontextMitgliedsZuordnung>[
          ArbeitskontextMitgliedsZuordnung(
            mitgliedsnummer: '1',
            gruppenId: 21,
            rollenLabel: 'Woelfling',
          ),
          ArbeitskontextMitgliedsZuordnung(
            mitgliedsnummer: '2',
            gruppenId: 22,
            rollenLabel: 'Pfadfinder in',
          ),
        ],
        authModel: authModel,
      );

      await tester.pumpWidget(
        _buildTestApp(
          authModel: authModel,
          arbeitskontextModel: arbeitskontextModel,
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Julia Keller'), findsOneWidget);
      expect(find.text('Mara Schmidt'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Wölfling'));
      await tester.pumpAndSettle();

      expect(find.text('Julia Keller'), findsOneWidget);
      expect(find.text('Mara Schmidt'), findsNothing);

      await tester.tap(find.bySemanticsLabel('Pfadfinder'));
      await tester.pumpAndSettle();

      expect(find.text('Julia Keller'), findsOneWidget);
      expect(find.text('Mara Schmidt'), findsOneWidget);
    },
  );

  testWidgets('zeigt den Biber-Filter nur wenn mindestens ein Biber da ist', (
    tester,
  ) async {
    final authModel = await _createSignedInAuthModel();
    final ohneBiberModel = await _createArbeitskontextModel(
      mitglieder: <Mitglied>[
        Mitglied.peopleListItem(
          mitgliedsnummer: '1',
          vorname: 'Julia',
          nachname: 'Keller',
        ),
      ],
      gruppen: const <ArbeitskontextGruppe>[
        ArbeitskontextGruppe(
          id: 21,
          name: 'Woelflinge',
          layerId: 11,
          gruppenTyp: 'Group::Meute',
        ),
      ],
      mitgliedsZuordnungen: const <ArbeitskontextMitgliedsZuordnung>[
        ArbeitskontextMitgliedsZuordnung(mitgliedsnummer: '1', gruppenId: 21),
      ],
      authModel: authModel,
    );

    await tester.pumpWidget(
      _buildTestApp(authModel: authModel, arbeitskontextModel: ohneBiberModel),
    );

    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Biber'), findsNothing);

    final mitBiberModel = await _createArbeitskontextModel(
      mitglieder: <Mitglied>[
        Mitglied.peopleListItem(
          mitgliedsnummer: '1',
          vorname: 'Ben',
          nachname: 'Biber',
        ),
      ],
      gruppen: const <ArbeitskontextGruppe>[
        ArbeitskontextGruppe(
          id: 22,
          name: 'Bibergruppe',
          layerId: 11,
          gruppenTyp: 'Group::Biber',
        ),
      ],
      mitgliedsZuordnungen: const <ArbeitskontextMitgliedsZuordnung>[
        ArbeitskontextMitgliedsZuordnung(mitgliedsnummer: '1', gruppenId: 22),
      ],
      authModel: authModel,
    );

    await tester.pumpWidget(
      _buildTestApp(authModel: authModel, arbeitskontextModel: mitBiberModel),
    );

    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Biber'), findsOneWidget);
  });

  testWidgets('filtert ueber Alle anderen nicht zugeordnete Mitglieder', (
    tester,
  ) async {
    final authModel = await _createSignedInAuthModel();
    final arbeitskontextModel = await _createArbeitskontextModel(
      mitglieder: <Mitglied>[
        Mitglied.peopleListItem(
          mitgliedsnummer: '1',
          vorname: 'Julia',
          nachname: 'Keller',
        ),
        Mitglied.peopleListItem(
          mitgliedsnummer: '2',
          vorname: 'Mara',
          nachname: 'Schmidt',
        ),
      ],
      gruppen: const <ArbeitskontextGruppe>[
        ArbeitskontextGruppe(
          id: 21,
          name: 'Woelflinge',
          layerId: 11,
          gruppenTyp: 'Group::Meute',
        ),
      ],
      mitgliedsZuordnungen: const <ArbeitskontextMitgliedsZuordnung>[
        ArbeitskontextMitgliedsZuordnung(mitgliedsnummer: '1', gruppenId: 21),
      ],
      authModel: authModel,
    );

    await tester.pumpWidget(
      _buildTestApp(
        authModel: authModel,
        arbeitskontextModel: arbeitskontextModel,
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Julia Keller'), findsOneWidget);
    expect(find.text('Mara Schmidt'), findsOneWidget);

    await tester.tap(find.text('Rest'));
    await tester.pumpAndSettle();

    expect(find.text('Julia Keller'), findsNothing);
    expect(find.text('Mara Schmidt'), findsOneWidget);
  });

  testWidgets('bietet bei leerem Filterergebnis das Zuruecksetzen an', (
    tester,
  ) async {
    final authModel = await _createSignedInAuthModel();
    final arbeitskontextModel = await _createArbeitskontextModel(
      mitglieder: <Mitglied>[
        Mitglied.peopleListItem(
          mitgliedsnummer: '1',
          vorname: 'Julia',
          nachname: 'Keller',
        ),
      ],
      gruppen: const <ArbeitskontextGruppe>[
        ArbeitskontextGruppe(
          id: 21,
          name: 'Woelflinge',
          layerId: 11,
          gruppenTyp: 'Group::Meute',
        ),
      ],
      mitgliedsZuordnungen: const <ArbeitskontextMitgliedsZuordnung>[
        ArbeitskontextMitgliedsZuordnung(mitgliedsnummer: '1', gruppenId: 21),
      ],
      authModel: authModel,
    );

    await tester.pumpWidget(
      _buildTestApp(
        authModel: authModel,
        arbeitskontextModel: arbeitskontextModel,
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Pfadfinder'));
    await tester.pumpAndSettle();

    expect(find.text('Keine Mitglieder gefunden'), findsOneWidget);
    expect(find.text('Filter zurücksetzen'), findsOneWidget);

    await tester.tap(find.text('Filter zurücksetzen'));
    await tester.pumpAndSettle();

    expect(find.text('Julia Keller'), findsOneWidget);
    expect(find.text('Keine Mitglieder gefunden'), findsNothing);
  });

  testWidgets('oeffnet das Modal Filtern und Sortieren', (tester) async {
    final authModel = await _createSignedInAuthModel();
    final arbeitskontextModel = await _createArbeitskontextModel(
      mitglieder: <Mitglied>[
        Mitglied.peopleListItem(
          mitgliedsnummer: '1',
          vorname: 'Julia',
          nachname: 'Keller',
        ),
      ],
      authModel: authModel,
    );

    await tester.pumpWidget(
      _buildTestApp(
        authModel: authModel,
        arbeitskontextModel: arbeitskontextModel,
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Filtern und sortieren'));
    await tester.pumpAndSettle();

    expect(find.text('Filtern & Sortieren'), findsOneWidget);
    expect(find.text('Sortiere nach'), findsOneWidget);
    expect(find.text('Zusatztext'), findsOneWidget);
    expect(find.text('Rest'), findsWidgets);
    expect(find.text('Filtergruppe erstellen'), findsOneWidget);

    await tester.tap(find.text('Filtergruppe erstellen'));
    await tester.pumpAndSettle();

    expect(find.text('Gruppe'), findsOneWidget);
    expect(find.text('Rolle'), findsOneWidget);
  });

  testWidgets('kann die Default-CustomGroup Rest loeschen', (tester) async {
    final authModel = await _createSignedInAuthModel();
    final arbeitskontextModel = await _createArbeitskontextModel(
      mitglieder: <Mitglied>[
        Mitglied.peopleListItem(
          mitgliedsnummer: '1',
          vorname: 'Julia',
          nachname: 'Keller',
        ),
      ],
      authModel: authModel,
    );

    await tester.pumpWidget(
      _buildTestApp(
        authModel: authModel,
        arbeitskontextModel: arbeitskontextModel,
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Rest'), findsOneWidget);

    await tester.tap(find.byTooltip('Filtern und sortieren'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Filtergruppe löschen').first);
    await tester.pumpAndSettle();

    Navigator.of(tester.element(find.text('Filtern & Sortieren'))).pop();
    await tester.pumpAndSettle();

    expect(find.text('Rest'), findsNothing);
  });

  testWidgets('loggt die Navigation in die Mitglied-Detailansicht', (
    tester,
  ) async {
    final logger = _RecordingLoggerService();
    final authModel = await _createSignedInAuthModel();
    final arbeitskontextModel = await _createArbeitskontextModel(
      mitglieder: <Mitglied>[
        Mitglied.peopleListItem(
          mitgliedsnummer: '4711',
          vorname: 'Julia',
          nachname: 'Keller',
        ),
      ],
      authModel: authModel,
    );

    await tester.pumpWidget(
      _buildTestApp(
        authModel: authModel,
        arbeitskontextModel: arbeitskontextModel,
        logger: logger,
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.text('Julia Keller'));
    await tester.pumpAndSettle();

    final memberDetailLog = logger.navigationLogs.where(
      (entry) => entry.$1 == 'route_open' && entry.$2 == AppRoutes.memberDetail,
    );

    expect(memberDetailLog, hasLength(1));
    expect(memberDetailLog.single.$3, AppRoutes.home);
  });
}

Widget _buildTestApp({
  required AuthSessionModel authModel,
  required ArbeitskontextModel arbeitskontextModel,
  LoggerService? logger,
  MemberEditModel? memberEditModel,
}) {
  final effectiveLogger = logger ?? _FakeLoggerService();
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<MemberFiltersModel>(
        create: (_) => MemberFiltersModel(_FakeMemberFilterRepository()),
      ),
      ChangeNotifierProvider<AuthSessionModel>.value(value: authModel),
      ChangeNotifierProvider<ArbeitskontextModel>.value(
        value: arbeitskontextModel,
      ),
      if (memberEditModel != null)
        ChangeNotifierProvider<MemberEditModel>.value(value: memberEditModel),
      Provider<LoggerService>.value(value: effectiveLogger),
    ],
    child: MaterialApp(
      navigatorObservers: [
        AppNavigationLoggingObserver(logger: effectiveLogger),
      ],
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        AppLocalizations.delegate,
      ],
      supportedLocales: const [Locale('de'), Locale('en')],
      locale: const Locale('de'),
      home: const Scaffold(body: MemberPeoplePage()),
    ),
  );
}

Future<AuthSessionModel> _createSignedInAuthModel() async {
  final authModel = AuthSessionModel(
    repository: _InMemoryAuthSessionRepository(),
    profileRepository: _InMemoryAuthProfileRepository(),
    oauthService: _FakeOauthService(),
    biometricLockService: _FakeBiometricLockService(),
    sensitiveStorageService: _FakeSensitiveStorageService(),
    retentionPolicy: HitobitoDataRetentionPolicy(
      maxDataAge: const Duration(days: 90),
      refreshInterval: const Duration(hours: 24),
    ),
    logger: _FakeLoggerService(),
  );
  await authModel.signIn();
  return authModel;
}

Future<ArbeitskontextModel> _createArbeitskontextModel({
  required List<Mitglied> mitglieder,
  List<ArbeitskontextGruppe> gruppen = const <ArbeitskontextGruppe>[],
  List<ArbeitskontextMitgliedsZuordnung> mitgliedsZuordnungen =
      const <ArbeitskontextMitgliedsZuordnung>[],
  required AuthSessionModel authModel,
}) async {
  final model = ArbeitskontextModel(
    localRepository: _FakeArbeitskontextLocalRepository(
      cached: ArbeitskontextReadModel(
        arbeitskontext: Arbeitskontext(
          aktiverLayer: const ArbeitskontextLayer(
            id: 11,
            name: 'Stamm Musterdorf',
          ),
        ),
        mitglieder: mitglieder,
        gruppen: gruppen,
        mitgliedsZuordnungen: mitgliedsZuordnungen,
      ),
    ),
    readModelRepository: _FakeArbeitskontextReadModelRepository(),
    groupsService: _FakeHitobitoGroupsService(),
    bestimmeStartkontextUseCase: const BestimmeStartkontextUseCase(),
    logger: _FakeLoggerService(),
  );

  await model.syncForAuth(
    authState: authModel.state,
    session: authModel.session,
    profile: authModel.profile,
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

  @override
  Future<ArbeitskontextReadModel> loadCached(
    Arbeitskontext arbeitskontext,
  ) async {
    return ArbeitskontextReadModel(arbeitskontext: arbeitskontext);
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
          scopeString: 'openid email api',
          discoveryUrl: '',
          profileUrl: 'https://demo.hitobito.com/oauth/profile',
        ),
      );

  @override
  Future<List<HitobitoGroupResource>> fetchAccessibleGroups(
    String accessToken,
  ) async => const <HitobitoGroupResource>[];
}

class _InMemoryAuthProfileRepository implements AuthProfileRepository {
  AuthProfile? _profile;
  DateTime? _lastSyncAt;

  @override
  Future<void> clear() async {
    _profile = null;
    _lastSyncAt = null;
  }

  @override
  Future<AuthProfile?> loadCached() async => _profile;

  @override
  Future<DateTime?> loadLastSyncAt() async => _lastSyncAt;

  @override
  Future<void> save(AuthProfile profile) async {
    _profile = profile;
  }

  @override
  Future<void> saveLastSyncAt(DateTime timestamp) async {
    _lastSyncAt = timestamp;
  }
}

class _InMemoryAuthSessionRepository implements AuthSessionRepository {
  AuthSession? session;

  @override
  Future<void> clear() async {
    session = null;
  }

  @override
  Future<AuthSession?> load() async => session;

  @override
  Future<void> save(AuthSession session) async {
    this.session = session;
  }
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
          scopeString: 'openid email api',
          discoveryUrl: '',
          profileUrl: 'https://demo.hitobito.com/oauth/profile',
        ),
      );

  @override
  Future<AuthSession> authenticateInteractive() async => AuthSession(
    accessToken: 'token-123',
    refreshToken: 'refresh-token',
    receivedAt: DateTime(2026, 3, 27),
  );

  @override
  Future<AuthSession> refreshIfNeeded(
    AuthSession session, {
    Duration threshold = const Duration(minutes: 5),
  }) async => AuthSession(
    accessToken: 'token-refreshed',
    refreshToken: session.refreshToken,
    receivedAt: session.receivedAt,
    expiresAt: session.expiresAt,
    idToken: session.idToken,
    scopes: session.scopes,
    principal: session.principal,
    email: session.email,
    displayName: session.displayName,
  );

  @override
  Future<AuthProfile> fetchProfile(AuthSession session) async =>
      const AuthProfile(
        namiId: 1,
        firstName: 'Test',
        lastName: 'User',
        language: 'de',
      );
}

class _FakeBiometricLockService extends BiometricLockService {
  _FakeBiometricLockService() : super();

  @override
  Future<bool> isAvailable() async => false;
}

class _FakeSensitiveStorageService extends SensitiveStorageService {
  String? _principal;
  DateTime? _lastSensitiveSyncAt;
  DateTime? _lastSensitiveSyncAttemptAt;
  DateTime? _lastBackgroundedAt;

  _FakeSensitiveStorageService() : super();

  @override
  Future<String?> loadPrincipal() async => _principal;

  @override
  Future<DateTime?> loadLastSensitiveSyncAt() async => _lastSensitiveSyncAt;

  @override
  Future<DateTime?> loadLastSensitiveSyncAttemptAt() async =>
      _lastSensitiveSyncAttemptAt;

  @override
  Future<DateTime?> loadLastBackgroundedAt() async => _lastBackgroundedAt;

  @override
  Future<void> purgeSensitiveData() async {
    _principal = null;
    _lastSensitiveSyncAt = null;
    _lastSensitiveSyncAttemptAt = null;
    _lastBackgroundedAt = null;
  }

  @override
  Future<void> saveLastSensitiveSyncAt(DateTime timestamp) async {
    _lastSensitiveSyncAt = timestamp;
  }

  @override
  Future<void> saveLastSensitiveSyncAttemptAt(DateTime? timestamp) async {
    _lastSensitiveSyncAttemptAt = timestamp;
  }

  @override
  Future<void> saveLastBackgroundedAt(DateTime? timestamp) async {
    _lastBackgroundedAt = timestamp;
  }

  @override
  Future<void> savePrincipal(String? principal) async {
    _principal = principal;
  }
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

class _HintTrackingMemberEditModel extends MemberEditModel {
  _HintTrackingMemberEditModel({required this.openResolutionCount})
    : super(
        memberWriteRepository: _NoopMemberWriteRepository(),
        pendingRepository: _NoopPendingPersonUpdateRepository(),
        logger: _FakeLoggerService(),
        onMemberUpdated: (_) async {},
      );

  @override
  final int openResolutionCount;

  final List<(String, int)> loggedHints = <(String, int)>[];

  @override
  Future<void> logResolutionHintShown({
    required String entryPoint,
    required int openResolutionCount,
  }) async {
    loggedHints.add((entryPoint, openResolutionCount));
  }
}

class _RecordingLoggerService extends _FakeLoggerService {
  final List<(String, String?, String?, Map<String, Object?>)> navigationLogs =
      <(String, String?, String?, Map<String, Object?>)>[];

  @override
  Future<void> logNavigationAction(
    String action, {
    String? route,
    String? fromRoute,
    String? toRoute,
    Map<String, Object?> properties = const <String, Object?>{},
  }) async {
    navigationLogs.add((
      action,
      route,
      fromRoute ?? toRoute,
      Map<String, Object?>.from(properties),
    ));
  }
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
  Future<void> saveGeburstagsbenachrichtigungStufen(Set<Stufe> stufen) async {}

  @override
  Future<void> saveLanguageCode(String code) async {}

  @override
  Future<void> saveNotificationsEnabled(bool enabled) async {}

  @override
  Future<void> saveMemberListSearchResultHighlightEnabled(bool enabled) async {}

  @override
  Future<void> saveThemeMode(ThemeMode mode) async {}
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
    throw UnimplementedError();
  }
}

class _NoopPendingPersonUpdateRepository
    implements PendingPersonUpdateRepository {
  @override
  Future<void> clear() async {}

  @override
  Future<List<PendingPersonUpdate>> loadAll() async =>
      const <PendingPersonUpdate>[];

  @override
  Future<void> remove(String entryId) async {}

  @override
  Future<void> save(PendingPersonUpdate entry) async {}
}

class _FakeMemberFilterRepository implements MemberFilterRepository {
  final Map<int, MemberFilterLayerSettings> _values =
      <int, MemberFilterLayerSettings>{};

  @override
  Future<MemberFilterLayerSettings> loadForLayer(int layerId) async {
    return _values[layerId] ?? const MemberFilterLayerSettings();
  }

  @override
  Future<void> saveForLayer(
    int layerId,
    MemberFilterLayerSettings settings,
  ) async {
    _values[layerId] = settings;
  }
}

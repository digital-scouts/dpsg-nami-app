import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nami/domain/auth/auth_session.dart';
import 'package:nami/domain/member/member_write_repository.dart';
import 'package:nami/domain/member/mitglied.dart';
import 'package:nami/domain/member/pending_person_update.dart';
import 'package:nami/domain/member/pending_person_update_repository.dart';
import 'package:nami/domain/settings/app_settings.dart';
import 'package:nami/domain/settings/app_settings_repository.dart';
import 'package:nami/domain/taetigkeit/stufe.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/presentation/model/auth_session_model.dart';
import 'package:nami/presentation/model/member_edit_model.dart';
import 'package:nami/presentation/widgets/logout_flow.dart';
import 'package:nami/services/logger_service.dart';
import 'package:provider/provider.dart';

void main() {
  setUp(() {
    Provider.debugCheckInvalidValueType = null;
  });

  Future<
    ({
      _FakeAuthSessionModel auth,
      _PendingRepository pending,
      MemberEditModel model,
    })
  >
  pumpFlow(
    WidgetTester tester, {
    List<PendingPersonUpdate> entries = const <PendingPersonUpdate>[],
    Object? updateResult,
  }) async {
    final auth = _FakeAuthSessionModel();
    final pending = _PendingRepository(entries);
    final model = MemberEditModel(
      memberWriteRepository: _FakeMemberWriteRepository(updateResult),
      pendingRepository: pending,
      logger: _FakeLoggerService(),
      onMemberUpdated: (_) async {},
    );
    await model.loadPending();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AuthSessionModel>.value(value: auth),
          ChangeNotifierProvider<MemberEditModel>.value(value: model),
        ],
        child: MaterialApp(
          locale: const Locale('de'),
          supportedLocales: const [Locale('de'), Locale('en')],
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => runLogoutFlow(context),
              child: const Text('Abmelden'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abmelden'));
    await tester.pumpAndSettle();
    return (auth: auth, pending: pending, model: model);
  }

  testWidgets('meldet ohne ausstehende Aenderungen direkt ab', (tester) async {
    final result = await pumpFlow(tester);

    expect(find.byType(AlertDialog), findsNothing);
    expect(result.auth.logoutCalls, 1);
  });

  testWidgets('sendet vor dem Abmelden und fragt nicht nach, wenn alles '
      'gesendet wurde', (tester) async {
    final result = await pumpFlow(tester, entries: [_entry()]);

    expect(find.byType(AlertDialog), findsNothing);
    expect(result.auth.logoutCalls, 1);
    expect(await result.pending.loadAll(), isEmpty);
  });

  testWidgets('warnt vor ungesendeten Aenderungen und bricht auf Wunsch ab', (
    tester,
  ) async {
    final result = await pumpFlow(
      tester,
      entries: [_entry()],
      updateResult: const MemberWriteNetworkBlockedException('Offline.'),
    );

    expect(find.text('Ungesendete Änderungen'), findsOneWidget);
    expect(find.textContaining('1 Änderung(en)'), findsOneWidget);

    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();

    expect(result.auth.logoutCalls, 0);
    expect(await result.pending.loadAll(), hasLength(1));
  });

  testWidgets('meldet nach Bestaetigung trotz ungesendeter Aenderungen ab', (
    tester,
  ) async {
    final result = await pumpFlow(
      tester,
      entries: [_entry()],
      updateResult: const MemberWriteNetworkBlockedException('Offline.'),
    );

    final loadAllCallsVorLogout = result.pending.loadAllCalls;
    await tester.tap(find.byKey(const Key('logout-pending-confirm')));
    await tester.pumpAndSettle();

    expect(result.auth.logoutCalls, 1);
    // Nach dem Logout ist die Box geloescht und darf nicht neu entstehen.
    expect(result.pending.loadAllCalls, loadAllCallsVorLogout);
    expect(result.model.pendingUpdates, isEmpty);
  });
}

PendingPersonUpdate _entry() {
  final mitglied = Mitglied.peopleListItem(
    mitgliedsnummer: '4711',
    personId: 23,
    vorname: 'Julia',
    nachname: 'Keller',
  );
  return PendingPersonUpdate(
    entryId: 'person-23',
    personId: 23,
    mitgliedsnummer: '4711',
    displayName: 'Julia Keller',
    basisMitglied: mitglied,
    zielMitglied: mitglied.copyWith(vorname: 'Juliane'),
    queuedAt: DateTime(2026, 4, 14, 9, 0),
  );
}

class _FakeAuthSessionModel extends Fake implements AuthSessionModel {
  int logoutCalls = 0;

  @override
  AuthSession? get session =>
      AuthSession(accessToken: 'token-123', receivedAt: DateTime(2026, 4, 14));

  @override
  Future<void> logout() async {
    logoutCalls++;
  }
}

class _FakeMemberWriteRepository implements MemberWriteRepository {
  _FakeMemberWriteRepository(this.updateResult);

  final Object? updateResult;

  @override
  Future<Mitglied> fetchRemoteMember({
    required String accessToken,
    required int personId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Mitglied> updateMember({
    required String accessToken,
    required Mitglied basisMitglied,
    required Mitglied zielMitglied,
  }) async {
    final result = updateResult;
    if (result != null) {
      throw result;
    }
    return zielMitglied;
  }
}

class _PendingRepository implements PendingPersonUpdateRepository {
  _PendingRepository(List<PendingPersonUpdate> entries)
    : _entries = List<PendingPersonUpdate>.from(entries);

  final List<PendingPersonUpdate> _entries;
  int loadAllCalls = 0;

  @override
  Future<void> clear() async => _entries.clear();

  @override
  Future<List<PendingPersonUpdate>> loadAll() async {
    loadAllCalls++;
    return List<PendingPersonUpdate>.unmodifiable(_entries);
  }

  @override
  Future<void> remove(String entryId) async =>
      _entries.removeWhere((entry) => entry.entryId == entryId);

  @override
  Future<void> save(PendingPersonUpdate entry) async {
    _entries
      ..removeWhere(
        (existing) =>
            existing.entryId == entry.entryId ||
            existing.personId == entry.personId,
      )
      ..add(entry);
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

  @override
  Future<void> trackEvent(String name, Map<String, Object?> properties) async {}
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

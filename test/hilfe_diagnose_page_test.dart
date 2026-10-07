import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nami/domain/auth/auth_profile.dart';
import 'package:nami/domain/auth/auth_session.dart';
import 'package:nami/domain/hilfe/problem_meldung.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/presentation/model/auth_session_model.dart';
import 'package:nami/presentation/screens/hilfe_diagnose_page.dart';
import 'package:nami/services/hitobito_data_retention_policy.dart';
import 'package:nami/services/logger_service.dart';
import 'package:nami/services/problem_melden_service.dart';
import 'package:provider/provider.dart';

import 'support/auth_session_fakes.dart';
import 'support/fake_logger_service.dart';

class _FakeProblemMelden extends ProblemMeldenService {
  _FakeProblemMelden() : super(logger: FakeLoggerService());

  ProblemMeldung? gemeldet;

  @override
  Future<void> melden(
    ProblemMeldung meldung,
    String Function(String key) t,
  ) async {
    gemeldet = meldung;
  }
}

AuthSessionModel _abgemeldet() => AuthSessionModel(
  repository: InMemoryAuthSessionRepository(),
  profileRepository: InMemoryAuthProfileRepository(),
  oauthService: FakeOauthService(
    sessionToReturn: AuthSession(
      accessToken: 'a',
      receivedAt: DateTime(2026, 10, 7),
    ),
    profileToReturn: const AuthProfile(namiId: 1),
  ),
  biometricLockService: FakeBiometricLockService(available: false),
  sensitiveStorageService: FakeSensitiveStorageService(),
  retentionPolicy: HitobitoDataRetentionPolicy(
    maxDataAge: const Duration(days: 90),
    refreshInterval: const Duration(hours: 24),
    nowProvider: () => DateTime(2026, 10, 7, 12),
  ),
  logger: FakeLoggerService(),
);

Future<void> _pump(
  WidgetTester tester, {
  required bool entwickler,
  ProblemMeldenService? problemMelden,
}) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthSessionModel>.value(value: _abgemeldet()),
        Provider<LoggerService>.value(value: FakeLoggerService()),
      ],
      child: MaterialApp(
        localizationsDelegates: [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          AppLocalizations.delegate,
        ],
        supportedLocales: const [Locale('de'), Locale('en')],
        locale: const Locale('de'),
        home: HilfeDiagnosePage(
          entwicklerFunktionen: entwickler,
          problemMelden: problemMelden,
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('Release zeigt keine Entwickler-Werkzeuge (A-94)', (
    tester,
  ) async {
    await _pump(tester, entwickler: false);

    expect(find.text('Hilfe & Diagnose'), findsOneWidget);
    expect(find.text('Nicht angemeldet'), findsOneWidget);
    expect(find.byKey(const Key('hilfe-protokolle')), findsOneWidget);
    await tester.scrollUntilVisible(find.byKey(const Key('hilfe-reset')), 200);
    expect(find.byKey(const Key('hilfe-entwickler')), findsNothing);
  });

  testWidgets('Debug und Profile zeigen die Entwickler-Werkzeuge', (
    tester,
  ) async {
    await _pump(tester, entwickler: true);
    await tester.scrollUntilVisible(
      find.byKey(const Key('hilfe-entwickler')),
      200,
    );

    expect(find.byKey(const Key('hilfe-entwickler')), findsOneWidget);
  });

  testWidgets('Problem melden fragt erst und reicht die Angaben weiter', (
    tester,
  ) async {
    final dienst = _FakeProblemMelden();
    await _pump(tester, entwickler: false, problemMelden: dienst);

    await tester.tap(find.byKey(const Key('hilfe-problem-melden')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('problem-melden-sheet')), findsOneWidget);

    await tester.tap(find.byKey(const Key('problem-art-datenSync')));
    await tester.enterText(
      find.byKey(const Key('problem-hilfe_frage_gemacht')),
      'Liste aktualisiert',
    );
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('problem-weiter-mail')));
    await tester.tap(find.byKey(const Key('problem-weiter-mail')));
    await tester.pumpAndSettle();

    expect(dienst.gemeldet?.arten, {ProblemArt.datenSync});
    expect(dienst.gemeldet?.gemacht, 'Liste aktualisiert');
  });
}

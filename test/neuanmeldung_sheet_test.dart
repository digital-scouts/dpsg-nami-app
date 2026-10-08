import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nami/domain/auth/auth_profile.dart';
import 'package:nami/domain/auth/auth_session.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/presentation/model/auth_session_model.dart';
import 'package:nami/presentation/widgets/neuanmeldung_sheet.dart';
import 'package:nami/services/hitobito_data_retention_policy.dart';
import 'package:provider/provider.dart';

import 'support/auth_session_fakes.dart';
import 'support/fake_logger_service.dart';

void main() {
  final tag = DateTime(2026, 10, 8);

  Future<({AuthSessionModel model, FakeOauthService oauth})>
  baueModell() async {
    final oauth = FakeOauthService(
      sessionToReturn: AuthSession(
        accessToken: 'neu',
        refreshToken: 'refresh-neu',
        receivedAt: tag,
      ),
      profileToReturn: const AuthProfile(namiId: 1, language: 'de'),
    );
    final model = AuthSessionModel(
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
      oauthService: oauth,
      biometricLockService: FakeBiometricLockService(),
      sensitiveStorageService: FakeSensitiveStorageService()
        ..lastSensitiveSyncAt = tag,
      retentionPolicy: HitobitoDataRetentionPolicy(
        maxDataAge: const Duration(days: 90),
        refreshInterval: const Duration(hours: 24),
        nowProvider: () => tag.add(const Duration(hours: 1)),
      ),
      logger: FakeLoggerService(),
    );
    await model.initialize();
    model.reportRemoteDataIssue(
      'Token-Anfrage fehlgeschlagen (400, invalid_grant).',
      requiresInteractiveLogin: true,
    );
    return (model: model, oauth: oauth);
  }

  Future<Future<bool>> oeffne(
    WidgetTester tester,
    AuthSessionModel model,
  ) async {
    late Future<bool> ergebnis;
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthSessionModel>.value(
        value: model,
        child: MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('de')],
          locale: const Locale('de'),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () =>
                    ergebnis = frageNachNeuanmeldung(context, trigger: 'test'),
                child: const Text('los'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('los'));
    await tester.pumpAndSettle();
    return ergebnis;
  }

  testWidgets('Neu anmelden startet die Anmeldung erst nach dem Tippen', (
    tester,
  ) async {
    final (:model, :oauth) = await baueModell();

    final ergebnis = await oeffne(tester, model);
    expect(find.byType(NeuanmeldungSheet), findsOneWidget);
    expect(oauth.authenticateInteractiveCallCount, 0);

    await tester.tap(find.byKey(const Key('neuanmeldung-bestaetigen')));
    await tester.pumpAndSettle();

    expect(await ergebnis, isTrue);
    expect(oauth.authenticateInteractiveCallCount, 1);
    expect(model.requiresInteractiveLogin, isFalse);
  });

  testWidgets('Später schließt ohne Anmeldung', (tester) async {
    final (:model, :oauth) = await baueModell();

    final ergebnis = await oeffne(tester, model);
    await tester.tap(find.byKey(const Key('neuanmeldung-spaeter')));
    await tester.pumpAndSettle();

    expect(await ergebnis, isFalse);
    expect(oauth.authenticateInteractiveCallCount, 0);
    expect(model.requiresInteractiveLogin, isTrue);
  });
}

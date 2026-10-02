import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nami/demo/demo_services.dart'
    show InMemoryQualifikationsEinstellungenRepository;
import 'package:nami/domain/auth/auth_profile.dart';
import 'package:nami/domain/auth/auth_session.dart';
import 'package:nami/domain/qualifikation/plane_qualifikations_erinnerungen_usecase.dart';
import 'package:nami/domain/qualifikation/qualifikations_einstellungen.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/presentation/model/auth_session_model.dart';
import 'package:nami/presentation/model/qualifikations_einstellungen_model.dart';
import 'package:nami/presentation/notifications/notifications_hub.dart';
import 'package:nami/presentation/notifications/qualifikations_meldung.dart';
import 'package:nami/presentation/screens/settings_notification_page.dart';
import 'package:nami/services/hitobito_data_retention_policy.dart';
import 'package:provider/provider.dart';

import 'support/auth_session_fakes.dart';
import 'support/fake_logger_service.dart';
import 'support/qualifikationen_testdaten.dart';

AuthSessionModel _authModel() => AuthSessionModel(
  repository: InMemoryAuthSessionRepository(),
  profileRepository: InMemoryAuthProfileRepository(),
  oauthService: FakeOauthService(
    sessionToReturn: AuthSession(
      accessToken: 'token',
      receivedAt: DateTime(2026, 10, 2),
    ),
    profileToReturn: const AuthProfile(namiId: 1),
  ),
  biometricLockService: FakeBiometricLockService(),
  sensitiveStorageService: FakeSensitiveStorageService(),
  retentionPolicy: HitobitoDataRetentionPolicy(
    maxDataAge: const Duration(days: 90),
    refreshInterval: const Duration(hours: 24),
  ),
  logger: FakeLoggerService(),
);

void main() {
  testWidgets('Meine Qualifikationen: Schalter, Auswahl und Tage', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390 * 3, 1600 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final model = QualifikationsEinstellungenModel(
      InMemoryQualifikationsEinstellungenRepository(),
    );
    await model.load();
    final readModel = qualiReadModel(
      mitglieder: [
        qualiMitglied('A', 1, [leitung('Rover')]),
      ],
      qualifikationen: [
        quali(1, 1, praeventionId, 'Präventionsschulung', gueltigkeitJahre: 5),
        quali(2, 1, woodbadgeId, 'Woodbadge'),
      ],
    );

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
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
          home: SettingsNotificationPage(readModel: readModel),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('MEINE QUALIFIKATIONEN'), findsOneWidget);
    final woodbadge = tester.widget<FilterChip>(
      find.byKey(const Key('quali-meine-hitobito:3')),
    );
    // Ohne Ablauf laesst sich nicht erinnern.
    expect(woodbadge.onSelected, isNull);

    await tester.tap(find.byKey(const Key('quali-meine-efz')));
    await tester.pumpAndSettle();
    expect(model.einstellungen.eigene.arten, {'hitobito:14'});

    await tester.tap(find.byKey(const Key('quali-tage-weniger')));
    await tester.pumpAndSettle();
    expect(model.einstellungen.eigene.tageVorher, 89);

    await tester.tap(find.byKey(const Key('quali-meine-schalter')));
    await tester.pumpAndSettle();
    expect(model.einstellungen.eigene.aktiv, isFalse);
    expect(find.byKey(const Key('quali-meine-efz')), findsNothing);
  });

  test('Hub-Meldung fuer eigene Ablaeufe', () {
    final meldungen = NotificationsHub.buildInternal(
      authModel: _authModel(),
      unresolvedCount: 0,
      updateInfo: null,
      eigeneQualifikationsAblaeufe: [
        EigenerQualifikationsAblauf(
          artLabel: 'Präventionsschulung',
          gueltigBis: DateTime(2026, 11, 20),
          abgelaufen: false,
        ),
      ],
    );

    final meldung = meldungen.singleWhere(
      (m) => m.id == qualifikationsMeldungId,
    );
    expect(meldung.severity, AppNotificationSeverity.warn);
    expect(meldung.title.de, 'Präventionsschulung läuft bald ab');
    expect(meldung.body.de, 'Deine Qualifikation ist gültig bis 20.11.2026.');
    expect(
      const QualifikationsEinstellungen().eigene.aktiv,
      isTrue,
      reason: 'eigene Erinnerung ist standardmaessig an',
    );
  });
}

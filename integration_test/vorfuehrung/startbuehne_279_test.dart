// Vorführung zu #279 auf Simulator oder Emulator: Kaltstart mit App-Sperre
// auf der Startbühne, Entsperren (E1) und die Sperre bei Rückkehr aus dem
// Hintergrund. Das Anmeldemodell ist echt; gespeicherte Sitzung, Speicher und
// Face ID sind nachgebildet, damit es ohne Hitobito-Login läuft. Der Ablauf
// läuft in Echtzeit von selbst durch.
//
//   flutter test integration_test/vorfuehrung/startbuehne_279_test.dart -d <id>
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nami/domain/appearance/appearance_catalog.dart';
import 'package:nami/domain/auth/auth_profile.dart';
import 'package:nami/domain/auth/auth_session.dart';
import 'package:nami/domain/auth/auth_state.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/presentation/model/auth_session_model.dart';
import 'package:nami/presentation/screens/auth_gate_screen.dart';
import 'package:nami/presentation/theme/theme.dart';
import 'package:nami/presentation/widgets/app_startbuehne.dart';
import 'package:nami/services/hitobito_data_retention_policy.dart';
import 'package:provider/provider.dart';

import '../../test/support/auth_session_fakes.dart';
import '../../test/support/fake_logger_service.dart';
import 'vorfuehrung.dart';

/// Face ID mit kurzer Bedenkzeit wie auf dem Gerät.
class _FaceId extends FakeBiometricLockService {
  _FaceId() : super(available: true);

  @override
  Future<bool> authenticate() async {
    await Future<void>.delayed(const Duration(milliseconds: 700));
    return super.authenticate();
  }
}

/// Bühnenlage nur aus der Anmeldung: Der Inhalt ist bereit, nur die Sperre
/// hält die Bühne.
class _Lage extends ValueNotifier<StartbuehneLage> {
  _Lage(this._auth) : super(_aus(_auth)) {
    _auth.addListener(() => value = _aus(_auth));
  }

  final AuthSessionModel _auth;

  static StartbuehneLage _aus(AuthSessionModel auth) => StartbuehneLage(
    laedt: auth.state == AuthState.initializing,
    gesperrt: auth.state == AuthState.unlockRequired,
    fehler: auth.errorMessage,
  );
}

void main() {
  vorfuehrungBinden();

  testWidgets('Vorführung #279: Kaltstart mit Sperre', (tester) async {
    var jetzt = DateTime.now();
    final session = AuthSession(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      receivedAt: jetzt,
    );
    final auth = AuthSessionModel(
      repository: InMemoryAuthSessionRepository(initialSession: session),
      profileRepository: InMemoryAuthProfileRepository(
        profile: const AuthProfile(namiId: 7),
        lastSyncAt: jetzt,
      ),
      oauthService: FakeOauthService(
        sessionToReturn: session,
        profileToReturn: const AuthProfile(namiId: 7),
      ),
      biometricLockService: _FaceId(),
      sensitiveStorageService: FakeSensitiveStorageService()
        ..principal = 'person-7'
        ..lastSensitiveSyncAt = jetzt
        ..lastSensitiveSyncAttemptAt = jetzt,
      retentionPolicy: HitobitoDataRetentionPolicy(
        maxDataAge: const Duration(days: 90),
        refreshInterval: const Duration(hours: 24),
        nowProvider: () => jetzt,
      ),
      logger: FakeLoggerService(),
      isAppLockEnabled: () => true,
    );
    final lage = _Lage(auth);

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthSessionModel>.value(
        value: auth,
        child: MaterialApp(
          theme: buildTheme(AppPaletteId.standard, Brightness.light),
          darkTheme: buildTheme(AppPaletteId.standard, Brightness.dark),
          localizationsDelegates: [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            AppLocalizations.delegate,
          ],
          supportedLocales: const [Locale('de'), Locale('en')],
          locale: const Locale('de'),
          builder: (context, child) => AppStartbuehne(
            lage: lage,
            onEntsperren: auth.unlock,
            child: Stack(
              fit: StackFit.expand,
              children: [
                AppGesperrterInhalt(
                  gesperrt: auth.state == AuthState.unlockRequired,
                  child: child!,
                ),
                const AppLockOverlay(),
              ],
            ),
          ),
          home: Scaffold(
            appBar: AppBar(title: const Text('Mitglieder')),
            body: ListView(
              children: [
                for (final name in const [
                  'Lena Albrecht',
                  'Mats Brandt',
                  'Sami Engel',
                  'Ali Kaya',
                ])
                  ListTile(title: Text(name)),
              ],
            ),
          ),
        ),
      ),
    );
    // Kaltstart: Die Anmeldung findet die Sitzung und verlangt Entsperren.
    await auth.initialize();
    expect(auth.state, AuthState.unlockRequired);
    await tester.pump(const Duration(milliseconds: 2500));
    expect(find.byKey(const Key('startbuehne')), findsOneWidget);
    expect(find.byKey(const Key('app_lock_unlock')), findsOneWidget);

    await tester.tap(find.byKey(const Key('app_lock_unlock')));
    await tester.pump(const Duration(milliseconds: 2500));
    expect(auth.state, AuthState.signedIn);
    expect(find.byKey(const Key('startbuehne')), findsNothing);
    expect(find.text('Lena Albrecht'), findsOneWidget);

    // Rückkehr aus dem Hintergrund nach mehr als einer Minute: Die Sperre
    // erscheint sofort, ohne Startbühne.
    await auth.onAppBackgrounded();
    jetzt = jetzt.add(const Duration(seconds: 61));
    await auth.onAppResumed();
    await tester.pump(const Duration(milliseconds: 2000));
    expect(find.byKey(const Key('startbuehne')), findsNothing);
    expect(find.byKey(const Key('app_lock_overlay')), findsOneWidget);

    await tester.tap(find.byKey(const Key('app_lock_unlock')));
    await tester.pump(const Duration(milliseconds: 2500));
    expect(find.byKey(const Key('app_lock_overlay')), findsNothing);
  });
}

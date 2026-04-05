import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/presentation/screens/settings_app_page.dart';

void main() {
  testWidgets('zeigt und schaltet den App-Sperre-Toggle', (tester) async {
    bool? changedValue;
    final localizations = AppLocalizations(const Locale('de'));

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          AppLocalizations.delegate,
        ],
        supportedLocales: const [Locale('de'), Locale('en')],
        locale: const Locale('de'),
        home: AppSettingsPage(
          biometricLockEnabled: false,
          onBiometricLockChanged: (value) {
            changedValue = value;
          },
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text(localizations.t('app_lock_enable')), findsOneWidget);
    expect(find.text(localizations.t('app_lock_enable_hint')), findsOneWidget);

    await tester.tap(find.byType(SwitchListTile).at(1));
    await tester.pumpAndSettle();

    expect(changedValue, isTrue);
  });
}

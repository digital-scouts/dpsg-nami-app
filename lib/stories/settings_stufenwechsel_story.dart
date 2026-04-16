import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:nami/data/settings/in_memory_stufen_settings_repository.dart';
import 'package:nami/domain/stufe/altersgrenzen.dart';
import 'package:nami/domain/stufe/usecases/update_altersgrenzen_usecase.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/presentation/notifications/app_snackbar.dart';
import 'package:nami/presentation/widgets/settings_stufenwechsel.dart';
// ignore: depend_on_referenced_packages
import 'package:storybook_flutter/storybook_flutter.dart';

Story stufenwechselSettingsStory() {
  return Story(
    name: 'Einstellungen/Widgets/Stufenwechsel',
    builder: (context) {
      var grenzen = StufenDefaults.build();
      DateTime? next;
      final repo = InMemoryStufenSettingsRepository();
      final usecase = UpdateAltersgrenzenUseCase(repo);
      return MaterialApp(
        localizationsDelegates: [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          AppLocalizations.delegate,
        ],
        supportedLocales: const [Locale('de'), Locale('en')],
        home: Scaffold(
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: StufenwechselSettings(
                grenzen: grenzen,
                nextStufenwechsel: next,
                onDateChanged: (d) => next = d,
                onResetDefaults: () {
                  grenzen = StufenDefaults.build();
                  return grenzen;
                },
                onSave: (g) async {
                  try {
                    await usecase.call(g);
                    AppSnackbar.show(
                      context,
                      title: AppLocalizations.of(
                        context,
                      ).t('snackbar_saved_title'),
                      message: 'Altersgrenzen gespeichert',
                      type: AppSnackbarType.success,
                    );
                    grenzen = g;
                  } on AltersgrenzenValidationError catch (e) {
                    AppSnackbar.show(
                      context,
                      title: AppLocalizations.of(
                        context,
                      ).t('snackbar_invalid_altersgrenzen_title'),
                      message: e.message,
                      type: AppSnackbarType.warning,
                    );
                  } catch (_) {
                    AppSnackbar.show(
                      context,
                      message: 'Speichern fehlgeschlagen.',
                      type: AppSnackbarType.error,
                    );
                  }
                },
              ),
            ),
          ),
        ),
      );
    },
  );
}

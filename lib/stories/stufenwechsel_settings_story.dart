import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:nami/data/settings/in_memory_stufen_settings_repository.dart';
import 'package:nami/domain/stufe/altersgrenzen.dart';
import 'package:nami/domain/stufe/usecases/update_altersgrenzen_usecase.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/presentation/widgets/stufenwechsel_settings.dart';
// ignore: depend_on_referenced_packages
import 'package:storybook_flutter/storybook_flutter.dart';

Story stufenwechselSettingsStory() {
  return Story(
    name: 'Settings/Stufenwechsel',
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
        home: Padding(
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
                // ignore: use_build_context_synchronously
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Altersgrenzen gespeichert')),
                );
                grenzen = g;
              } on AltersgrenzenValidationError catch (e) {
                ScaffoldMessenger.of(
                  // ignore: use_build_context_synchronously
                  context,
                ).showSnackBar(SnackBar(content: Text(e.message)));
              } catch (_) {
                // ignore: use_build_context_synchronously
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Speichern fehlgeschlagen.')),
                );
              }
            },
          ),
        ),
      );
    },
  );
}

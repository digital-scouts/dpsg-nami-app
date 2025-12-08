import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:nami/data/settings/in_memory_address_settings_repository.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/presentation/widgets/stamm_address_settings.dart';
// ignore: depend_on_referenced_packages
import 'package:storybook_flutter/storybook_flutter.dart';

Story stammAddressSettingsStory() {
  return Story(
    name: 'Settings/Stamm Address',
    builder: (context) {
      final repo = InMemoryAddressSettingsRepository();
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
          child: StammAddressSettings(
            repository: repo,
            autocompleteProvider: (q) async {
              return [
                '$q, 12345 Musterstadt',
                '$q, 20095 Hamburg',
                '$q, 10115 Berlin',
              ];
            },
            onDownloadRegion: () {},
          ),
        ),
      );
    },
  );
}

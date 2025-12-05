import 'package:flutter/material.dart';
import 'package:nami/data/settings/in_memory_address_settings_repository.dart';
import 'package:nami/presentation/widgets/stamm_address_settings.dart';
// ignore: depend_on_referenced_packages
import 'package:storybook_flutter/storybook_flutter.dart';

Story stammAddressSettingsStory() {
  return Story(
    name: 'Settings/Stamm Address',
    builder: (context) {
      final repo = InMemoryAddressSettingsRepository();
      return Padding(
        padding: const EdgeInsets.all(16),
        child: StammAddressSettings(
          repository: repo,
          autocompleteProvider: (q) async {
            // Fake provider: returns a few options
            return [
              '$q, 12345 Musterstadt',
              '$q, 20095 Hamburg',
              '$q, 10115 Berlin',
            ];
          },
          onDownloadRegion: () {
            // TODO: Kartenregion downloaden
          },
        ),
      );
    },
  );
}

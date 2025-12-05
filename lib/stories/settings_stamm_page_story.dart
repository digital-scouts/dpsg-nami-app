import 'package:flutter/material.dart';
import 'package:nami/data/settings/in_memory_address_settings_repository.dart';
import 'package:nami/domain/stufe/altersgrenzen.dart';
import 'package:nami/presentation/screens/settings_stamm_page.dart';
import 'package:storybook_flutter/storybook_flutter.dart';

Story buildSettingsStammPageStory() => Story(
  name: 'Screens/Settings Stamm',
  builder: (context) {
    final repo = InMemoryAddressSettingsRepository();
    final grenzen = StufenDefaults.build();
    return SettingsStammPage(
      addressRepository: repo,
      initialAltersgrenzen: grenzen,
      onSaveAltersgrenzen: (g) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Altersgrenzen gespeichert')),
        );
      },
      onStufenwechselChanged: (d) {},
    );
  },
);

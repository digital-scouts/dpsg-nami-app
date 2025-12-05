import 'package:flutter/material.dart';
import 'package:nami/domain/settings/address_settings_repository.dart';
import 'package:nami/domain/stufe/altersgrenzen.dart';
import 'package:nami/presentation/widgets/stamm_address_settings.dart';
import 'package:nami/presentation/widgets/stufenwechsel_settings.dart';
import 'package:nami/services/address_autocomplete_provider.dart';

class SettingsStammPage extends StatelessWidget {
  final AddressSettingsRepository addressRepository;
  final Altersgrenzen initialAltersgrenzen;
  final DateTime? initialStufenwechsel;
  final void Function(Altersgrenzen grenzen)? onSaveAltersgrenzen;
  final void Function(DateTime? date)? onStufenwechselChanged;

  const SettingsStammPage({
    super.key,
    required this.addressRepository,
    required this.initialAltersgrenzen,
    this.initialStufenwechsel,
    this.onSaveAltersgrenzen,
    this.onStufenwechselChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Stamm-Einstellungen')),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
        child: ListView(
          children: [
            Text('Adresse', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            StammAddressSettings(
              repository: addressRepository,
              autocompleteProvider: geoapifyAutocompleteProvider,
            ),
            const SizedBox(height: 24),
            Text('Stufenwechsel', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            StufenwechselSettings(
              nextStufenwechsel: initialStufenwechsel,
              grenzen: initialAltersgrenzen,
              onDateChanged: onStufenwechselChanged,
              onSave: onSaveAltersgrenzen,
              onResetDefaults: () => StufenDefaults.build(),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:nami/domain/settings/address_settings_repository.dart';
import 'package:nami/domain/stufe/altersgrenzen.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/presentation/widgets/settings_stamm_address.dart';
import 'package:nami/presentation/widgets/settings_stufenwechsel.dart';
import 'package:nami/presentation/widgets/settings_stufenwechsel_minmax.dart';
import 'package:nami/presentation/widgets/stufenwechsel_date_row.dart';
import 'package:nami/services/address_autocomplete_provider.dart';

class SettingsStammPage extends StatefulWidget {
  final AddressSettingsRepository addressRepository;
  final Altersgrenzen initialAltersgrenzen;
  final DateTime? initialStufenwechsel;
  final void Function(Altersgrenzen grenzen)? onSaveAltersgrenzen;
  final void Function(DateTime? date)? onStufenwechselChanged;
  final bool useMinMaxVariant;

  const SettingsStammPage({
    super.key,
    required this.addressRepository,
    required this.initialAltersgrenzen,
    this.initialStufenwechsel,
    this.onSaveAltersgrenzen,
    this.onStufenwechselChanged,
    this.useMinMaxVariant = false,
  });

  @override
  State<SettingsStammPage> createState() => _SettingsStammPageState();
}

class _SettingsStammPageState extends State<SettingsStammPage> {
  late bool _useMinMax;

  @override
  void initState() {
    super.initState();
    _useMinMax = widget.useMinMaxVariant;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context);

    Widget sectionLabel(String label) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
        child: Text(
          label.toUpperCase(),
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
      );
    }

    Widget sectionHint(String text) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Text(
          text,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.outlineVariant,
            height: 1.5,
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(t.t('settings_stamm'))),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 16),
        children: [
          // ===== ADRESSE SECTION =====
          sectionLabel(t.t('address_section')),
          sectionHint(t.t('address_help')),
          Card(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            clipBehavior: Clip.antiAlias,
            child: StammAddressSettings(
              repository: widget.addressRepository,
              autocompleteProvider: geoapifyAutocompleteProvider,
            ),
          ),

          // ===== STUFENWECHSEL SECTION =====
          Row(
            children: [
              Expanded(child: sectionLabel(t.t('stufenwechsel_section'))),
              Tooltip(
                message: _useMinMax
                    ? 'Zur Slider-Ansicht wechseln'
                    : 'Zur kompakten Ansicht wechseln',
                child: IconButton(
                  icon: Icon(
                    _useMinMax ? Icons.straighten : Icons.view_list,
                    size: 18,
                  ),
                  onPressed: () {
                    setState(() => _useMinMax = !_useMinMax);
                  },
                  iconSize: 20,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                ),
              ),
            ],
          ),
          sectionHint(t.t('stufenwechsel_help')),

          // --- Datum Card ---
          Card(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            clipBehavior: Clip.antiAlias,
            child: StufenwechselDateRow(
              date: widget.initialStufenwechsel,
              onDateChanged: widget.onStufenwechselChanged,
            ),
          ),

          // --- Altersgruppen Header (mit Reset/Save) ---
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Row(
              children: [
                Text(
                  t.t('altersgruppen').toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.outlineVariant,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: t.t('reset_changes'),
                  icon: const Icon(Icons.restore),
                  onPressed: () {
                    final defaults = StufenDefaults.build();
                    setState(() {
                      // Triggers rebuild of child widgets
                    });
                    widget.onSaveAltersgrenzen?.call(defaults);
                  },
                  iconSize: 20,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                ),
                TextButton(
                  onPressed: () => widget.onSaveAltersgrenzen?.call(
                    widget.initialAltersgrenzen,
                  ),
                  child: Text(t.t('save')),
                ),
              ],
            ),
          ),

          // --- Altersgrenzen Card (Slider oder MinMax) ---
          Card(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            clipBehavior: Clip.antiAlias,
            child: _useMinMax
                ? StufenwechselSettingsMinMax(
                    nextStufenwechsel: widget.initialStufenwechsel,
                    grenzen: widget.initialAltersgrenzen,
                    onDateChanged: widget.onStufenwechselChanged,
                    onSave: widget.onSaveAltersgrenzen,
                    onResetDefaults: () => StufenDefaults.build(),
                  )
                : StufenwechselSettings(
                    nextStufenwechsel: widget.initialStufenwechsel,
                    grenzen: widget.initialAltersgrenzen,
                    onDateChanged: widget.onStufenwechselChanged,
                    onSave: widget.onSaveAltersgrenzen,
                    onResetDefaults: () => StufenDefaults.build(),
                  ),
          ),
        ],
      ),
    );
  }
}

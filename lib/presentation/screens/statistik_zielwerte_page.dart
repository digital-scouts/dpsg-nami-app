import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/statistiks/statistik_kachel_einstellungen.dart';
import '../../domain/taetigkeit/stufe.dart';
import '../../l10n/app_localizations.dart';
import '../model/statistik_kacheln_model.dart';
import '../statistics/statistik_farben.dart';

/// Zielwerte des Stamms: höchste Gruppengröße je Stufe und Neue pro Jahr.
/// Leere Felder setzen keine Marke. Jede Eingabe wird sofort gespeichert.
class StatistikZielwertePage extends StatefulWidget {
  const StatistikZielwertePage({super.key, required this.model});

  final StatistikKachelnModel model;

  static const List<Stufe> stufen = [
    Stufe.biber,
    Stufe.woelfling,
    Stufe.jungpfadfinder,
    Stufe.pfadfinder,
    Stufe.rover,
  ];

  @override
  State<StatistikZielwertePage> createState() => _StatistikZielwertePageState();
}

class _StatistikZielwertePageState extends State<StatistikZielwertePage> {
  late final StatistikZielwerte _start = widget.model.einstellungen.ziele;
  late final Map<Stufe, TextEditingController> _gruppeMax = {
    for (final stufe in StatistikZielwertePage.stufen)
      stufe: TextEditingController(
        text: _start.gruppeMax[stufe]?.toString() ?? '',
      ),
  };
  late final TextEditingController _neu = TextEditingController(
    text: _start.neuProJahr?.toString() ?? '',
  );

  @override
  void dispose() {
    for (final c in _gruppeMax.values) {
      c.dispose();
    }
    _neu.dispose();
    super.dispose();
  }

  static int? _zahl(TextEditingController c) {
    final wert = int.tryParse(c.text.trim());
    return wert != null && wert > 0 ? wert : null;
  }

  void _speichern() {
    widget.model.zieleSpeichern(
      StatistikZielwerte(
        neuProJahr: _zahl(_neu),
        gruppeMax: Map.unmodifiable({
          for (final MapEntry(key: stufe, value: c) in _gruppeMax.entries)
            stufe: ?_zahl(c),
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final farben = StatistikFarben.of(context);
    Widget feld(
      TextEditingController controller,
      String label, {
      Widget? vorne,
      Key? key,
    }) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          if (vorne != null) ...[vorne, const SizedBox(width: 10)],
          Expanded(child: Text(label, style: theme.textTheme.bodyLarge)),
          SizedBox(
            width: 112,
            child: TextField(
              key: key,
              controller: controller,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.end,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(3),
              ],
              decoration: InputDecoration(
                isDense: true,
                border: const OutlineInputBorder(),
                hintText: t.t('statistics_targets_empty'),
              ),
              onChanged: (_) => _speichern(),
            ),
          ),
        ],
      ),
    );
    Widget abschnitt(String text) => Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 4),
      child: Text(
        text,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
    );
    return Scaffold(
      appBar: AppBar(title: Text(t.t('statistics_targets'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Text(
            t.t('statistics_targets_hint'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          abschnitt(t.t('statistics_targets_group_max')),
          Text(
            t.t('statistics_targets_group_max_hint'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          for (final stufe in StatistikZielwertePage.stufen)
            feld(
              _gruppeMax[stufe]!,
              stufe.displayName,
              key: Key('zielwert-${stufe.name}'),
              vorne: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: farben.stufe(stufe),
                  borderRadius: BorderRadius.circular(3),
                  border: farben.kontur(stufe) == null
                      ? null
                      : Border.all(color: farben.kontur(stufe)!),
                ),
              ),
            ),
          abschnitt(t.t('statistics_targets_new_per_year')),
          feld(
            _neu,
            t.t('statistics_targets_new_per_year'),
            key: const Key('zielwert-neu'),
          ),
        ],
      ),
    );
  }
}

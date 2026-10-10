import 'package:add_2_calendar/add_2_calendar.dart' as kalender;
import 'package:flutter/material.dart';

import '../../../domain/veranstaltung/veranstaltung.dart';
import '../../../l10n/app_localizations.dart';
import 'veranstaltung_texte.dart';

/// Oeffnet den Systemdialog des Kalenders mit vorausgefuelltem Termin.
/// Liefert `false`, wenn der Dialog nicht geoeffnet werden konnte.
typedef KalenderEintragen =
    Future<bool> Function(
      Veranstaltung veranstaltung,
      VeranstaltungsTermin termin,
    );

/// Ohne Ende traegt der Dialog eine Stunde ein; der Nutzer kann es dort
/// anpassen.
Future<bool> systemKalenderEintragen(
  Veranstaltung veranstaltung,
  VeranstaltungsTermin termin,
) {
  final label = termin.label;
  return kalender.Add2Calendar.addEvent2Cal(
    kalender.Event(
      title: label == null || label == veranstaltung.name
          ? veranstaltung.name
          : '${veranstaltung.name} · $label',
      description: veranstaltung.beschreibung,
      location: termin.ort ?? veranstaltung.ort,
      startDate: termin.beginn,
      endDate: termin.ende ?? termin.beginn.add(const Duration(hours: 1)),
    ),
  );
}

/// Bei mehreren Terminen zuerst fragen, welcher eingetragen wird; `null`
/// bei Abbruch.
Future<VeranstaltungsTermin?> waehleKalenderTermin(
  BuildContext context,
  Veranstaltung veranstaltung,
) async {
  final termine = veranstaltung.termine;
  if (termine.length <= 1) {
    return termine.firstOrNull;
  }
  return showModalBottomSheet<VeranstaltungsTermin>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    builder: (context) => _TerminAuswahl(veranstaltung: veranstaltung),
  );
}

class _TerminAuswahl extends StatefulWidget {
  const _TerminAuswahl({required this.veranstaltung});

  final Veranstaltung veranstaltung;

  @override
  State<_TerminAuswahl> createState() => _TerminAuswahlState();
}

class _TerminAuswahlState extends State<_TerminAuswahl> {
  late VeranstaltungsTermin _wahl = widget.veranstaltung.termine.first;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final texte = VeranstaltungTexte(context);
    final veranstaltung = widget.veranstaltung;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            t.t('veranstaltung_kalender_titel'),
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            t.t('veranstaltung_kalender_mehrere', {
              'name': veranstaltung.name,
              'n': veranstaltung.termine.length,
            }),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          RadioGroup<VeranstaltungsTermin>(
            groupValue: _wahl,
            onChanged: (termin) {
              if (termin != null) {
                setState(() => _wahl = termin);
              }
            },
            child: Column(
              children: [
                for (final (i, termin) in veranstaltung.termine.indexed)
                  RadioListTile<VeranstaltungsTermin>(
                    key: Key('veranstaltung-kalender-termin-$i'),
                    value: termin,
                    contentPadding: EdgeInsets.zero,
                    title: Text(termin.label ?? texte.zeitraum(veranstaltung)),
                    subtitle: Text(
                      [
                        texte.termin(termin),
                        termin.ort,
                      ].whereType<String>().join(' · '),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(t.t('veranstaltung_abbrechen')),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  key: const Key('veranstaltung-kalender-weiter'),
                  onPressed: () => Navigator.of(context).pop(_wahl),
                  child: Text(t.t('veranstaltung_kalender_weiter')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

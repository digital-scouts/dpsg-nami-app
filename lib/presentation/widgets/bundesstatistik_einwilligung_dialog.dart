import 'package:flutter/material.dart';

/// Fragt die ausdrueckliche Einwilligung zum Teilen der Stammesdaten ab.
/// Liefert `true` nur bei aktiver Zustimmung.
Future<bool> zeigeBundesstatistikEinwilligungDialog(
  BuildContext context,
) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => const BundesstatistikEinwilligungDialog(),
  );
  return result ?? false;
}

class BundesstatistikEinwilligungDialog extends StatelessWidget {
  const BundesstatistikEinwilligungDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Stammesdaten teilen?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Für den bundesweiten Vergleich sendet die App etwa einmal pro '
              'Woche zusammengefasste Zahlen deines Stammes an den '
              'Statistikserver der NaMi-App.',
            ),
            const SizedBox(height: 12),
            Text(
              'Geteilt werden nur Anzahlen:',
              style: theme.textTheme.labelLarge,
            ),
            const SizedBox(height: 4),
            const _Punkt('Mitglieder je Stufe, aufgeteilt nach Geschlecht'),
            const _Punkt('Leitende je Stufe und nach Altersgruppen'),
            const _Punkt(
              'Ordentliche Mitgliedschaften und sonstige Mitglieder',
            ),
            const SizedBox(height: 12),
            Text('Nicht geteilt werden:', style: theme.textTheme.labelLarge),
            const SizedBox(height: 4),
            const _Punkt('Namen, Geburtsdaten, Adressen oder Kontaktdaten'),
            const _Punkt('deine Person oder dein Hitobito-Zugang'),
            const SizedBox(height: 12),
            Text(
              'Der Server speichert Stamm und Installation nur pseudonymisiert. '
              'Bundeswerte siehst du, solange du teilst. Du kannst die '
              'Einwilligung jederzeit widerrufen; bereits geteilte Zahlen '
              'fallen nach zwei Monaten aus der Statistik.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Teilen aktivieren'),
        ),
      ],
    );
  }
}

class _Punkt extends StatelessWidget {
  const _Punkt(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('•  '),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

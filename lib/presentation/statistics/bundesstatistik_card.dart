import 'package:flutter/material.dart';

import '../model/bundesstatistik_model.dart';

/// Einstieg in die bundesweite Statistik im Statistik-Tab.
class BundesstatistikCard extends StatelessWidget {
  const BundesstatistikCard({
    super.key,
    required this.status,
    required this.onEinwilligen,
    required this.onOeffnen,
    this.teilnehmendeStaemme,
    this.isBusy = false,
  });

  final BundesstatistikStatus status;
  final int? teilnehmendeStaemme;
  final bool isBusy;
  final VoidCallback onEinwilligen;
  final VoidCallback onOeffnen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ohneEinwilligung = status == BundesstatistikStatus.keineEinwilligung;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: ohneEinwilligung ? null : onOeffnen,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: Icon(
                        Icons.public,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bundesweiter Vergleich',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(_beschreibung, style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                  if (isBusy)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else if (!ohneEinwilligung)
                    Icon(
                      Icons.chevron_right,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                ],
              ),
              if (ohneEinwilligung) ...[
                const SizedBox(height: 12),
                Text(
                  'Vergleiche deinen Stamm mit anderen Stämmen. Dafür teilt '
                  'die App zusammengefasste Anzahlen deines Stammes, keine '
                  'Einzeldaten.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onOeffnen,
                        child: const Text('Mehr erfahren'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        onPressed: onEinwilligen,
                        child: const Text('Teilen aktivieren'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String get _beschreibung => switch (status) {
    BundesstatistikStatus.keineEinwilligung =>
      'Nur mit deiner Einwilligung verfügbar',
    BundesstatistikStatus.bereit =>
      'Aus ${teilnehmendeStaemme ?? 0} teilnehmenden Stämmen',
    BundesstatistikStatus.zuWenigTeilnahme =>
      'Noch zu wenige teilnehmende Stämme',
    BundesstatistikStatus.nichtTeilnehmend ||
    BundesstatistikStatus.wartetAufDaten => 'Dein Beitrag wird vorbereitet',
    BundesstatistikStatus.keinStamm => 'Nur für Stämme verfügbar',
    BundesstatistikStatus.keineKennzahlen =>
      'Keine Mitglieder in den Stufen gefunden',
    BundesstatistikStatus.abgelehnt =>
      'Vom Server abgelehnt, bitte App aktualisieren',
    BundesstatistikStatus.fehler => 'Derzeit nicht erreichbar',
    BundesstatistikStatus.nichtVerfuegbar => 'Nicht verfügbar',
  };
}

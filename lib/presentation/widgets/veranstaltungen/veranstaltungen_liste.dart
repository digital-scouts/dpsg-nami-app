import 'package:flutter/material.dart';

import '../../../domain/veranstaltung/veranstaltung.dart';
import '../app_lesebreite.dart';
import '../section_header.dart';
import 'veranstaltung_texte.dart';

/// Suchliste nach Monat gruppiert (Entscheidung L3): je Monat eine Karte mit
/// kompakten Zeilen, getrennt durch Abstand.
class VeranstaltungenListe extends StatelessWidget {
  const VeranstaltungenListe({
    super.key,
    required this.veranstaltungen,
    required this.heute,
    required this.veranstalter,
    required this.onTap,
    this.kopfzeile,
    this.ausgewaehltId,
    this.onRefresh,
  });

  /// Bereits sortiert.
  final List<Veranstaltung> veranstaltungen;
  final DateTime heute;
  final String? Function(Veranstaltung veranstaltung) veranstalter;
  final ValueChanged<Veranstaltung> onTap;

  /// Zeile ueber der ersten Gruppe, z. B. die Anzahl.
  final Widget? kopfzeile;
  final int? ausgewaehltId;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final texte = VeranstaltungTexte(context);
    final gruppen = <String, List<Veranstaltung>>{};
    for (final veranstaltung in veranstaltungen) {
      final beginn = veranstaltung.beginn!;
      gruppen.putIfAbsent(texte.monat(beginn), () => []).add(veranstaltung);
    }

    final liste = AppLesebreite(
      builder: (context, rand) => ListView(
        key: const Key('veranstaltungen-liste'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24) + rand,
        children: [
          ?kopfzeile,
          for (final MapEntry(key: monat, value: eintraege) in gruppen.entries)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DpsgSectionHeader(label: monat),
                  Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        children: [
                          for (final veranstaltung in eintraege)
                            _Zeile(
                              veranstaltung: veranstaltung,
                              texte: texte,
                              heute: heute,
                              veranstalter: veranstalter(veranstaltung),
                              ausgewaehlt: veranstaltung.id == ausgewaehltId,
                              onTap: () => onTap(veranstaltung),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
    final onRefresh = this.onRefresh;
    return onRefresh == null
        ? liste
        : RefreshIndicator(onRefresh: onRefresh, child: liste);
  }
}

class _Zeile extends StatelessWidget {
  const _Zeile({
    required this.veranstaltung,
    required this.texte,
    required this.heute,
    required this.veranstalter,
    required this.ausgewaehlt,
    required this.onTap,
  });

  final Veranstaltung veranstaltung;
  final VeranstaltungTexte texte;
  final DateTime heute;
  final String? veranstalter;
  final bool ausgewaehlt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final beginn = veranstaltung.beginn!;
    final status = texte.statusTeile(veranstaltung, heute);
    final artFarbe = VeranstaltungFarben.art(context, veranstaltung.art);
    final grau = theme.colorScheme.onSurfaceVariant;

    return Semantics(
      button: true,
      selected: ausgewaehlt,
      label:
          '${texte.art(veranstaltung)}, ${veranstaltung.name}, '
          '${texte.zeitraum(veranstaltung)}',
      excludeSemantics: false,
      child: Material(
        color: ausgewaehlt
            ? theme.colorScheme.primary.withValues(alpha: 0.1)
            : Colors.transparent,
        child: InkWell(
          key: Key('veranstaltung-${veranstaltung.id}'),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 44,
                  child: ExcludeSemantics(
                    child: Column(
                      children: [
                        Text(
                          texte.tag(beginn),
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            height: 1.1,
                          ),
                        ),
                        Text(
                          texte.wochentag(beginn),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: grau,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text.rich(
                        TextSpan(
                          children: [
                            WidgetSpan(
                              alignment: PlaceholderAlignment.middle,
                              child: Container(
                                width: 8,
                                height: 8,
                                margin: const EdgeInsets.only(right: 6),
                                decoration: BoxDecoration(
                                  color: artFarbe,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                            TextSpan(text: veranstaltung.name),
                          ],
                        ),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (veranstalter != null)
                        Text(
                          veranstalter!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: grau,
                          ),
                        ),
                      if (status.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text.rich(
                            TextSpan(
                              children: [
                                for (final (i, teil) in status.indexed) ...[
                                  if (i > 0)
                                    TextSpan(
                                      text: ' · ',
                                      style: TextStyle(color: grau),
                                    ),
                                  TextSpan(
                                    text: teil.text,
                                    style: TextStyle(color: teil.farbe),
                                  ),
                                ],
                              ],
                            ),
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Icon(Icons.chevron_right, color: grau, size: 20),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

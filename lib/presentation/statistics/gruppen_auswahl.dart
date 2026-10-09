import 'package:flutter/material.dart';

import '../../domain/bundesstatistik/stammes_snapshot.dart';
import '../../domain/statistiks/stamm_statistik.dart';
import '../../domain/taetigkeit/stufe.dart';
import '../../l10n/app_localizations.dart';
import 'statistik_farben.dart';

/// Blatt mit allen Gruppen nach Stufe; liefert die gewählte Gruppen-ID.
///
/// Erreichbar über den Titel der Gruppen-Kachel, eine Stufe mit mehreren
/// Gruppen ([nurStufe]) und den Titel der Gruppendetailseite ([aktuell]).
Future<int?> zeigeGruppenAuswahl(
  BuildContext context, {
  required List<StufenStatistik> stufen,
  int? aktuell,
  Stufe? nurStufe,
}) {
  return showModalBottomSheet<int>(
    useRootNavigator: true,
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.95,
      builder: (context, scroll) => GruppenAuswahlListe(
        stufen: [
          for (final s in stufen)
            if (s.gruppen.isNotEmpty &&
                (nurStufe == null || s.stufe == nurStufe))
              s,
        ],
        aktuell: aktuell,
        scrollController: scroll,
        titel: AppLocalizations.of(context).t(
          aktuell == null
              ? 'statistics_groups_sheet_title'
              : 'statistics_group_switch_title',
        ),
        onGewaehlt: (id) => Navigator.of(context).pop(id),
      ),
    ),
  );
}

class GruppenAuswahlListe extends StatelessWidget {
  const GruppenAuswahlListe({
    super.key,
    required this.stufen,
    required this.titel,
    required this.onGewaehlt,
    this.aktuell,
    this.scrollController,
  });

  final List<StufenStatistik> stufen;
  final String titel;
  final int? aktuell;
  final ValueChanged<int> onGewaehlt;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final farben = StatistikFarben.of(context);
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        Text(
          titel,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        for (final s in stufen) ...[
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    t
                        .t('bund_stage_${stufenSchluessel[s.stufe]}')
                        .toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: scheme.primary,
                    ),
                  ),
                ),
                Text(
                  t.t('statistics_groups_sheet_stage_summary', {
                    'groups': gruppenAnzahlText(t, s.gruppen.length),
                    'children': s.kinder,
                  }),
                  style: TextStyle(fontSize: 12, color: farben.textSchwach),
                ),
              ],
            ),
          ),
          for (final g in s.gruppen)
            InkWell(
              key: Key('gruppen-auswahl-${g.gruppenId}'),
              onTap: () => onGewaehlt(g.gruppenId),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: farben.stufe(g.stufe),
                        shape: BoxShape.circle,
                        border: farben.kontur(g.stufe) != null
                            ? Border.all(color: farben.kontur(g.stufe)!)
                            : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        g.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: g.gruppenId == aktuell
                              ? scheme.primary
                              : farben.text,
                        ),
                      ),
                    ),
                    Text(
                      '${g.kinder} +${g.leitende}',
                      style: TextStyle(
                        fontSize: 14,
                        color: farben.textGedaempft,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      g.gruppenId == aktuell
                          ? Icons.check
                          : Icons.chevron_right,
                      size: 18,
                      color: farben.textSchwach,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ],
    );
  }
}

String gruppenAnzahlText(AppLocalizations t, int anzahl) => anzahl == 1
    ? t.t('statistics_groups_count_one')
    : t.t('statistics_groups_count', {'count': anzahl});

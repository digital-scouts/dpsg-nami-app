import 'package:flutter/material.dart';

import '../../../domain/member/member_utils.dart';
import '../../../domain/member/mitglied.dart';
import '../../../domain/settings/stufen_settings.dart';
import '../../../domain/stufe/altersgrenzen.dart';
import '../../../domain/stufenwechsel/naechster_stufenwechsel.dart';
import '../../../domain/taetigkeit/pfadfinder_verlauf.dart';
import '../../../domain/taetigkeit/stufe.dart';
import '../../../l10n/app_localizations.dart';
import '../section_header.dart';
import 'member_pfadfinder_verlauf.dart';
import 'member_rollen_zeitstrahl.dart';

/// Rollen-Tab: Pfadfinder-Verlauf oben, darunter der Rollen-Zeitstrahl.
class MemberRollenTab extends StatelessWidget {
  const MemberRollenTab({
    super.key,
    required this.mitglied,
    required this.heute,
    this.stufenSettings,
    this.aktiverLayerName,
  });

  final Mitglied mitglied;
  final DateTime heute;

  /// Eingestellte Altersgrenzen und Stufenwechsel-Stichtag; ohne sie gelten
  /// die Standardgrenzen und heute.
  final StufenSettings? stufenSettings;
  final String? aktiverLayerName;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final rollen = mitglied.roles
        .where((rolle) => !MemberUtils.istMitgliederRolle(rolle))
        .toList(growable: false);
    final verlauf = berechnePfadfinderVerlauf(mitglied, heute: heute);
    final grenzen = stufenSettings?.grenzen ?? StufenDefaults.build();
    final stufenwechsel = berechneNaechstenStufenwechsel(
      mitglied,
      altersgrenzen: grenzen,
      stichtag: stufenSettings?.stufenwechselDatum ?? heute,
      heute: heute,
    );
    final historieFehlt =
        verlauf.unbekanntBis != null &&
        !rollen.any((r) => r.endOn != null && r.endOn!.isBefore(heute));

    return ListView(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 16),
      children: [
        DpsgSectionHeader(label: t.t('verlauf_titel')),
        MemberPfadfinderVerlauf(
          verlauf: verlauf,
          heute: heute,
          stufenwechsel: stufenwechsel,
          roverHoechstalter: grenzen.forStufe(Stufe.rover).maxJahre,
        ),
        const SizedBox(height: 18),
        MemberRollenZeitstrahl(
          rollen: rollen,
          heute: heute,
          eintritt: mitglied.hatBekanntesEintrittsdatum
              ? mitglied.eintrittsdatum
              : null,
          aktiverLayerName: aktiverLayerName,
        ),
        if (historieFehlt)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
            child: Row(
              children: [
                Icon(
                  Icons.schedule_outlined,
                  size: 15,
                  color: theme.colorScheme.outlineVariant,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    t.t('rollen_historie_fehlt'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outlineVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

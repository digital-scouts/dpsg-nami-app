import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../services/app_mode_controller.dart';
import '../../services/supporter/supporter_env.dart';

extension DemoZugangTexte on DemoZugang {
  String get titelKey => 'demo_zugang_${name}_title';

  String get beschreibungKey => 'demo_zugang_${name}_body';

  /// Satz für den Demo-Hinweis in den Einstellungen, der die Rolle nennt.
  String get hinweisKey => 'demo_zugang_${name}_hint';

  IconData get icon => switch (this) {
    DemoZugang.stammesvorstand => Icons.groups_outlined,
    DemoZugang.leitung => Icons.hiking,
    DemoZugang.bezirksvorstand => Icons.account_tree_outlined,
    DemoZugang.supporter => Icons.workspace_premium_outlined,
  };
}

/// Auswahl des Demo-Zugangs nach „Demo ansehen“. Gibt den gewählten
/// [DemoZugang] per `Navigator.pop` zurück. „Supporter-Extras“ erscheint nur
/// mit Store-Anbindung ([zeigeSupporter]).
class DemoZugangSheet extends StatelessWidget {
  const DemoZugangSheet({super.key, this.zeigeSupporter = false});

  final bool zeigeSupporter;

  static Future<DemoZugang?> show(BuildContext context) {
    return showModalBottomSheet<DemoZugang>(
      context: context,
      isScrollControlled: true,
      builder: (_) =>
          DemoZugangSheet(zeigeSupporter: SupporterEnv.storeEnabled),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final zugaenge = [
      for (final zugang in DemoZugang.values)
        if (zugang != DemoZugang.supporter || zeigeSupporter) zugang,
    ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t.t('demo_zugang_sheet_title'),
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              t.t('demo_zugang_sheet_hint'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            for (final (index, zugang) in zugaenge.indexed) ...[
              if (index > 0) const Divider(height: 1),
              ListTile(
                key: Key('demo-zugang-${zugang.name}'),
                contentPadding: EdgeInsets.zero,
                leading: Icon(zugang.icon),
                title: Text(t.t(zugang.titelKey)),
                subtitle: Text(t.t(zugang.beschreibungKey)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).pop(zugang),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

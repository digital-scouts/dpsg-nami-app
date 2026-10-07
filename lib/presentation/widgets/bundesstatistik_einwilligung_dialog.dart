import 'package:flutter/material.dart';

import '../../domain/rechtliches/anbieter.dart';
import '../../l10n/app_localizations.dart';
import '../navigation/app_router.dart';

/// Fragt die ausdrueckliche Einwilligung zum Teilen der Stammesdaten ab.
/// Liefert `true` nur bei aktiver Zustimmung.
Future<bool> zeigeBundesstatistikEinwilligungDialog(
  BuildContext context, {
  String? stammName,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) =>
        BundesstatistikEinwilligungDialog(stammName: stammName),
  );
  return result ?? false;
}

/// Gestufter Dialog: drei Kernaussagen, Details hinter „Mehr erfahren“.
class BundesstatistikEinwilligungDialog extends StatefulWidget {
  const BundesstatistikEinwilligungDialog({
    super.key,
    this.stammName,
    this.initialAufgeklappt = false,
  });

  /// Stamm, fuer den eingewilligt wird; die Einwilligung gilt je Stamm.
  final String? stammName;

  /// Nur fuer Storybook und Tests.
  final bool initialAufgeklappt;

  @override
  State<BundesstatistikEinwilligungDialog> createState() =>
      _BundesstatistikEinwilligungDialogState();
}

class _BundesstatistikEinwilligungDialogState
    extends State<BundesstatistikEinwilligungDialog> {
  late bool _aufgeklappt = widget.initialAufgeklappt;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final klein = theme.textTheme.bodySmall?.copyWith(
      color: colors.onSurfaceVariant,
    );
    final stammName = widget.stammName;

    return AlertDialog(
      title: Text(t.t('bund_consent_title')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (stammName != null && stammName.isNotEmpty) ...[
              Container(
                key: const Key('bund-consent-stamm'),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  stammName,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: colors.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Text(t.t('bund_consent_intro')),
            const SizedBox(height: 10),
            _Kernaussage(
              icon: Icons.check,
              farbe: Colors.green.shade700,
              text: t.t('bund_consent_point_counts'),
            ),
            _Kernaussage(
              icon: Icons.close,
              farbe: colors.error,
              text: t.t('bund_consent_point_no_personal'),
            ),
            _Kernaussage(
              icon: Icons.schedule,
              farbe: colors.primary,
              text: t.t('bund_consent_point_retention'),
            ),
            TextButton.icon(
              key: const Key('bund-consent-mehr'),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
              iconAlignment: IconAlignment.end,
              onPressed: () => setState(() => _aufgeklappt = !_aufgeklappt),
              icon: Icon(
                _aufgeklappt ? Icons.expand_less : Icons.expand_more,
                size: 18,
              ),
              label: Text(
                t.t(_aufgeklappt ? 'bund_consent_less' : 'bund_consent_more'),
              ),
            ),
            if (_aufgeklappt)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Detail(
                      t.t('bund_consent_shared_label'),
                      t.t('bund_consent_shared'),
                    ),
                    _Detail(
                      t.t('bund_consent_not_shared_label'),
                      t.t('bund_consent_not_shared'),
                    ),
                    _Detail(
                      t.t('bund_consent_server_label'),
                      t.t('bund_consent_server'),
                    ),
                    _Detail(
                      t.t('bund_consent_withdraw_label'),
                      t.t('bund_consent_withdraw'),
                    ),
                  ],
                ),
              ),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  '${t.t('bund_consent_responsible', {'name': Anbieter.name})} · ',
                  style: klein,
                ),
                InkWell(
                  key: const Key('bund-consent-rechtliches'),
                  onTap: () => Navigator.of(
                    context,
                  ).pushNamed(AppRoutes.settingsRechtliches),
                  child: Text(
                    t.t('legal_title'),
                    style: klein?.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(t.t('bund_consent_cancel')),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(t.t('bund_consent_confirm')),
        ),
      ],
    );
  }
}

class _Kernaussage extends StatelessWidget {
  const _Kernaussage({
    required this.icon,
    required this.farbe,
    required this.text,
  });

  final IconData icon;
  final Color farbe;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: farbe),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail(this.label, this.text);

  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text.rich(
        TextSpan(
          style: style,
          children: [
            TextSpan(
              text: '$label ',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(text: text),
          ],
        ),
      ),
    );
  }
}

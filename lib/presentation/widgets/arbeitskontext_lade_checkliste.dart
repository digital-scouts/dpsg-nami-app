import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../format/date_formatters.dart';
import '../model/arbeitskontext_model.dart';
import '../theme/app_bewegung.dart';
import '../theme/status_farben.dart';

/// Schritte beim ersten Laden des Arbeitskontexts, in der Shell und auf der
/// Startbühne. Ein erledigter Haken erscheint mit Scale 0,8 → 1 und Fade.
class ArbeitskontextLadeCheckliste extends StatelessWidget {
  const ArbeitskontextLadeCheckliste({super.key, required this.steps});

  final List<ArbeitskontextLoadingStepStatus> steps;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final step in steps)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: _LadeSchrittZeile(step: step),
          ),
      ],
    );
  }
}

class _LadeSchrittZeile extends StatelessWidget {
  const _LadeSchrittZeile({required this.step});

  final ArbeitskontextLoadingStepStatus step;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    const iconSize = 20.0;
    // "Wartet" wird bewusst nicht mit theme.colorScheme.outline eingefaerbt:
    // dieser Farbton ist in Material 3 fuer Raender/Trenner gedacht und in
    // beiden Themes zu kontrastarm fuer Text/Icons.
    final Widget icon = switch (step.state) {
      ArbeitskontextLoadingStepState.done => Icon(
        Icons.check_circle,
        size: iconSize,
        color: theme.colorScheme.primary,
      ),
      ArbeitskontextLoadingStepState.loading => SizedBox(
        width: iconSize,
        height: iconSize,
        child: const CircularProgressIndicator(strokeWidth: 2),
      ),
      ArbeitskontextLoadingStepState.waiting => Icon(
        Icons.circle_outlined,
        size: iconSize,
        color: theme.colorScheme.onSurfaceVariant,
      ),
      // Entscheidung design/entscheidung/2026-10-29-teildaten-veraltet.md, L2.
      ArbeitskontextLoadingStepState.stale => Icon(
        Icons.error,
        size: iconSize,
        color: StatusFarben.of(context).warnung,
      ),
    };
    final reduziert = AppBewegung.reduziert(context);
    final animiertesIcon = AnimatedSwitcher(
      duration: AppBewegung.klein,
      switchInCurve: AppBewegung.ausgang,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: reduziert
            ? child
            : ScaleTransition(
                scale: Tween<double>(begin: 0.8, end: 1).animate(animation),
                child: child,
              ),
      ),
      child: KeyedSubtree(key: ValueKey(step.state), child: icon),
    );
    final hasDetail = step.detailKey != null;
    final textStyle = theme.textTheme.bodyMedium;
    final dimmed = step.state == ArbeitskontextLoadingStepState.waiting;
    return Padding(
      padding: EdgeInsets.only(left: step.indent ? 28 : 0),
      child: Row(
        children: [
          animiertesIcon,
          const SizedBox(width: 10),
          Text(
            t.t(step.labelKey),
            style: textStyle?.copyWith(
              color: dimmed ? theme.colorScheme.onSurfaceVariant : null,
            ),
          ),
          if (hasDetail) ...[
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                t.t(step.detailKey!, {
                  if (step.detailCount != null) 'count': '${step.detailCount}',
                  if (step.detailDatum != null)
                    'datum': DateFormatter.formatGermanDayMonth(
                      step.detailDatum!,
                    ),
                }),
                textAlign: TextAlign.right,
                style: textStyle?.copyWith(
                  color: step.state == ArbeitskontextLoadingStepState.stale
                      ? StatusFarben.of(context).warnung
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

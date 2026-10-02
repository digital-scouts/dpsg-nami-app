import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import 'statistik_stamm_ansicht.dart';

/// Kopf des Bearbeiten-Modus: ＋ (Katalog), Titel, „Fertig“ und darunter die
/// Themen als Chips. Überblick bleibt immer, Stufen und Entwicklung lassen
/// sich aus- und wieder einblenden.
class StatistikBearbeitenLeiste extends StatelessWidget {
  const StatistikBearbeitenLeiste({
    super.key,
    required this.stufenSichtbar,
    required this.entwicklungSichtbar,
    required this.onHinzufuegen,
    required this.onFertig,
    required this.onThemaSichtbar,
    this.themenAnzeigen = true,
  });

  /// Ohne Themen (Teilsicht) entfallen die Chips für Stufen und Entwicklung.
  final bool themenAnzeigen;

  final bool stufenSichtbar;
  final bool entwicklungSichtbar;
  final VoidCallback onHinzufuegen;
  final VoidCallback onFertig;
  final void Function(StatistikThema thema, bool sichtbar) onThemaSichtbar;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton.filled(
                tooltip: t.t('statistics_edit_add'),
                onPressed: onHinzufuegen,
                icon: const Icon(Icons.add),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  t.t('statistics_edit_title'),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: onFertig,
                child: Text(
                  t.t('statistics_edit_done'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (themenAnzeigen) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 4, right: 4),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _ThemenChip(text: t.t('statistics_theme_overview')),
                  _ThemenChip(
                    text: t.t('statistics_theme_stages'),
                    sichtbar: stufenSichtbar,
                    onUmschalten: () =>
                        onThemaSichtbar(StatistikThema.stufen, !stufenSichtbar),
                  ),
                  _ThemenChip(
                    text: t.t('statistics_theme_development'),
                    sichtbar: entwicklungSichtbar,
                    onUmschalten: () => onThemaSichtbar(
                      StatistikThema.entwicklung,
                      !entwicklungSichtbar,
                    ),
                  ),
                ],
              ),
            ),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 8, 6, 0),
            child: Text(
              t.t('statistics_edit_hint'),
              style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemenChip extends StatelessWidget {
  const _ThemenChip({
    required this.text,
    this.sichtbar = true,
    this.onUmschalten,
  });

  final String text;
  final bool sichtbar;

  /// `null` = fest (Überblick).
  final VoidCallback? onUmschalten;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final fest = onUmschalten == null;
    final hintergrund = fest
        ? scheme.surface
        : sichtbar
        ? scheme.primary.withValues(alpha: 0.10)
        : Colors.transparent;
    final schrift = fest
        ? scheme.onSurface
        : sichtbar
        ? scheme.primary
        : scheme.onSurfaceVariant;
    final inhalt = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          text,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: schrift,
          ),
        ),
        if (!fest) ...[
          const SizedBox(width: 5),
          Icon(
            sichtbar ? Icons.remove_circle : Icons.add_circle,
            size: 18,
            color: sichtbar ? const Color(0xFFE5383B) : scheme.primary,
          ),
        ],
      ],
    );
    return Semantics(
      button: !fest,
      toggled: fest ? null : sichtbar,
      label: fest
          ? text
          : t.t(
              sichtbar
                  ? 'statistics_edit_hide_theme'
                  : 'statistics_edit_show_theme',
              {'theme': text},
            ),
      excludeSemantics: true,
      child: Material(
        color: hintergrund,
        shape: StadiumBorder(
          side: sichtbar || fest
              ? BorderSide.none
              : BorderSide(color: scheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onUmschalten,
          child: ConstrainedBox(
            // Volles 48-pt-Ziel.
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: inhalt,
            ),
          ),
        ),
      ),
    );
  }
}

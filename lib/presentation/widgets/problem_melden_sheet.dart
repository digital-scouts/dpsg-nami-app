import 'package:flutter/material.dart';

import '../../domain/hilfe/problem_meldung.dart';
import '../../l10n/app_localizations.dart';

/// Fragt vor der Mail kurz nach, worum es geht (Variante D2 aus
/// `design/entscheidung/2026-10-07-hilfe-diagnose.md`). Liefert `null` bei
/// Abbruch.
Future<ProblemMeldung?> showProblemMeldenSheet(BuildContext context) {
  return showModalBottomSheet<ProblemMeldung>(
    useRootNavigator: true,
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (context) => const ProblemMeldenSheet(),
  );
}

class ProblemMeldenSheet extends StatefulWidget {
  const ProblemMeldenSheet({super.key});

  @override
  State<ProblemMeldenSheet> createState() => _ProblemMeldenSheetState();
}

class _ProblemMeldenSheetState extends State<ProblemMeldenSheet> {
  final Set<ProblemArt> _arten = <ProblemArt>{};
  final TextEditingController _gemacht = TextEditingController();
  final TextEditingController _passiert = TextEditingController();
  final TextEditingController _erwartet = TextEditingController();

  @override
  void dispose() {
    _gemacht.dispose();
    _passiert.dispose();
    _erwartet.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final unten = MediaQuery.viewInsetsOf(context).bottom;
    Widget label(String key) => Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 6),
      child: Text(
        t.t(key),
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
    Widget feld(String frage, String hinweis, TextEditingController c) =>
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            label(frage),
            TextField(
              key: Key('problem-$frage'),
              controller: c,
              enableIMEPersonalizedLearning: false,
              minLines: 1,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: t.t(hinweis),
                filled: true,
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        );
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + unten),
      child: SingleChildScrollView(
        child: Column(
          key: const Key('problem-melden-sheet'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              t.t('hilfe_problem_melden'),
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              t.t('hilfe_sheet_hint'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            label('hilfe_problem_art'),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final art in ProblemArt.values)
                  FilterChip(
                    key: Key('problem-art-${art.name}'),
                    label: Text(t.t(art.textKey)),
                    // Primärfarbe statt des roten secondaryContainer aus dem
                    // Chip-Theme, das selectedColor überstimmt.
                    color: WidgetStateProperty.resolveWith(
                      (states) => states.contains(WidgetState.selected)
                          ? theme.colorScheme.primary.withValues(alpha: 0.14)
                          : null,
                    ),
                    checkmarkColor: theme.colorScheme.primary,
                    labelStyle: _arten.contains(art)
                        ? TextStyle(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          )
                        : null,
                    side: _arten.contains(art)
                        ? BorderSide(color: theme.colorScheme.primary)
                        : null,
                    selected: _arten.contains(art),
                    onSelected: (an) => setState(
                      () => an ? _arten.add(art) : _arten.remove(art),
                    ),
                  ),
              ],
            ),
            feld('hilfe_frage_gemacht', 'hilfe_hint_gemacht', _gemacht),
            feld('hilfe_frage_passiert', 'hilfe_hint_passiert', _passiert),
            feld('hilfe_frage_erwartet', 'hilfe_hint_erwartet', _erwartet),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  Icons.attach_file,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    t.t('hilfe_anhang'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            FilledButton(
              key: const Key('problem-weiter-mail'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(46),
              ),
              onPressed: () => Navigator.of(context).pop(
                ProblemMeldung(
                  arten: Set<ProblemArt>.of(_arten),
                  gemacht: _gemacht.text,
                  passiert: _passiert.text,
                  erwartet: _erwartet.text,
                ),
              ),
              child: Text(t.t('hilfe_weiter_mail')),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../domain/appearance/appearance_catalog.dart';
import '../../model/supporter_kauf_model.dart';
import '../../navigation/app_router.dart';
import '../../../l10n/app_localizations.dart';
import 'supporter_bausteine.dart';

/// Einstieg beim Antippen einer gesperrten Option im Erscheinungsbild:
/// mit Paket das Sheet zum Paket, sonst (Badges) direkt „Supporter werden“.
/// `null`, solange die Store-Anbindung aus ist; dann bleibt das Schloss ohne
/// Kaufweg.
VoidCallback? supporterKaufEinstieg(
  BuildContext context,
  SupporterPaket? paket,
) {
  final model = context.watch<SupporterKaufModel?>();
  if (model == null) {
    return null;
  }
  if (paket == null) {
    return () => Navigator.pushNamed(context, AppRoutes.supporter);
  }
  return () => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => ChangeNotifierProvider.value(
      value: model,
      child: SupporterPaketSheet(paket: paket),
    ),
  );
}

class SupporterPaketSheet extends StatefulWidget {
  const SupporterPaketSheet({
    super.key,
    required this.paket,
    this.nowProvider = DateTime.now,
  });

  final SupporterPaket paket;
  final DateTime Function() nowProvider;

  @override
  State<SupporterPaketSheet> createState() => _SupporterPaketSheetState();
}

class _SupporterPaketSheetState extends State<SupporterPaketSheet> {
  bool _geschlossen = false;

  @override
  Widget build(BuildContext context) {
    final paket = widget.paket;
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final model = context.watch<SupporterKaufModel>();
    final produkt = SupporterPaketInfo.produkt(paket);
    final details = model.produkt(produkt);
    final laeuft = model.laeuft(produkt);
    final name = t.t('supporter_paket_${paket.name}');
    void zurSeite() {
      _geschlossen = true;
      final navigator = Navigator.of(context);
      navigator.pop();
      navigator.pushNamed(AppRoutes.supporter);
    }

    // Nach dem Kauf schliesst das Sheet, die Option ist jetzt frei.
    final stand = supporterStand(context, model);
    if ((stand.foerderer || stand.pakete.contains(paket)) && !_geschlossen) {
      _geschlossen = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pop(context);
        }
      });
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          key: Key('supporter-sheet-${paket.name}'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SupporterPaketVorschau(
              paket: paket,
              hoehe: 110,
              radius: BorderRadius.circular(16),
            ),
            const SizedBox(height: 14),
            Text(
              t.t('supporter_sheet_titel', {'paket': name}),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              t.t('supporter_sheet_text', {'paket': name}),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            for (final punkt in [
              t.t('supporter_paket_${paket.name}_text'),
              t.t('supporter_sheet_badges'),
            ])
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.check,
                      size: 17,
                      color: theme.colorScheme.tertiary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(punkt)),
                  ],
                ),
              ),
            const SizedBox(height: 14),
            FilledButton(
              key: const Key('supporter-sheet-kaufen'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: details == null || laeuft
                  ? null
                  : () => model.kaufen(produkt),
              child: laeuft
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : details == null
                  ? Text(t.t('supporter_preis_fehlt'))
                  : Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          '${t.t('supporter_sheet_kaufen', {'paket': name})} · ',
                        ),
                        SupporterPreis(
                          details: details,
                          jetzt: widget.nowProvider(),
                          style: TextStyle(
                            color: theme.colorScheme.onPrimary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 6),
            TextButton(
              key: const Key('supporter-sheet-foerderer'),
              onPressed: zurSeite,
              child: Text(t.t('supporter_sheet_foerderer')),
            ),
            TextButton(
              key: const Key('supporter-sheet-alle'),
              onPressed: zurSeite,
              child: Text(t.t('supporter_sheet_alle')),
            ),
          ],
        ),
      ),
    );
  }
}

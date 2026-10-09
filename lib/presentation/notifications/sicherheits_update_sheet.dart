import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_localizations.dart';
import '../model/sicherheits_update_model.dart';

/// Nachfrage zum Sicherheitsupdate (S2/X2,
/// `design/entscheidung/2026-10-09-schreibpfad-sicherheitsupdate.md`).
/// Nicht wegwischbar: Entweder aktualisieren oder „In 3 Stunden erinnern“.
Future<void> showSicherheitsUpdateSheet(
  BuildContext context,
  SicherheitsUpdateModel model,
) async {
  final info = model.info;
  if (info == null) {
    return;
  }
  final t = AppLocalizations.of(context);
  final languageCode = Localizations.localeOf(context).languageCode;
  final betrifft = info.vorgabe.betrifftFuer(languageCode);
  final verbleibend = model.lage.verbleibendeAufschuebe;

  final spaeter = await showModalBottomSheet<bool>(
    context: context,
    isDismissible: false,
    enableDrag: false,
    showDragHandle: true,
    builder: (context) {
      final theme = Theme.of(context);
      return PopScope(
        canPop: false,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  t.t('security_update_title'),
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(t.t('security_update_body')),
                if (betrifft != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    key: const Key('security-update-betrifft'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      t.t('security_update_betrifft', {'text': betrifft}),
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Text(
                  t.t('security_update_rest', {'count': verbleibend}),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  key: const Key('security-update-now'),
                  onPressed: () async {
                    Navigator.of(context).pop(false);
                    await oeffneStore(info.storeUrl);
                  },
                  child: Text(t.t('security_update_now')),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  key: const Key('security-update-later'),
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(t.t('security_update_later')),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
  if (spaeter == true) {
    await model.spaeter();
  }
}

Future<void> oeffneStore(String storeUrl) async {
  final uri = Uri.tryParse(storeUrl);
  if (uri == null) {
    return;
  }
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

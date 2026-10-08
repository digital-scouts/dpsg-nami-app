import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../model/auth_session_model.dart';
import '../notifications/app_snackbar.dart';

/// Rückfrage, bevor die App für eine abgelaufene Anmeldung den
/// Hitobito-Login im Browser öffnet. Gibt `true` per `Navigator.pop` zurück,
/// wenn die Person neu anmelden möchte.
class NeuanmeldungSheet extends StatelessWidget {
  const NeuanmeldungSheet({super.key});

  static Future<bool?> show(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => const NeuanmeldungSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              t.t('auth_neuanmeldung_title'),
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              t.t('auth_neuanmeldung_body'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              key: const Key('neuanmeldung-bestaetigen'),
              onPressed: () => Navigator.of(context).pop(true),
              icon: const Icon(Icons.login),
              label: Text(t.t('auth_neuanmeldung_action')),
            ),
            const SizedBox(height: 4),
            TextButton(
              key: const Key('neuanmeldung-spaeter'),
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(t.t('auth_neuanmeldung_later')),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fragt bei abgelaufener Anmeldung nach und öffnet erst nach Zustimmung den
/// Hitobito-Login. Liefert `true`, wenn die Neuanmeldung gelungen ist.
Future<bool> frageNachNeuanmeldung(
  BuildContext context, {
  required String trigger,
}) async {
  final authModel = context.read<AuthSessionModel>();
  final bestaetigt = await NeuanmeldungSheet.show(context);
  if (bestaetigt != true) {
    return false;
  }
  final angemeldet = await authModel.neuAnmelden(trigger: trigger);
  final fehler = authModel.errorMessage;
  if (!angemeldet && context.mounted && fehler != null && fehler.isNotEmpty) {
    AppSnackbar.show(context, message: fehler, type: AppSnackbarType.warning);
  }
  return angemeldet;
}

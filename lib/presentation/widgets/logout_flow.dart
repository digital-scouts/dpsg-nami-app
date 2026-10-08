import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../services/app_mode_controller.dart';
import '../model/auth_session_model.dart';
import '../model/member_edit_model.dart';

/// Meldet ab, ohne ungesendete Personenaenderungen stillschweigend zu
/// verlieren.
///
/// Der Logout loescht alle sensiblen Daten einschliesslich vorgemerkter
/// Aenderungen. Deshalb wird zuerst einmal gesendet; bleibt danach etwas
/// uebrig, muss der Nutzer den Verlust bestaetigen.
///
/// Liefert `true`, wenn abgemeldet wurde, `false` bei Abbruch.
Future<bool> runLogoutFlow(BuildContext context) async {
  final appModeController = context.read<AppModeController?>();
  if (appModeController?.isDemo ?? false) {
    // Abmelden beendet im Demo den Demo-Zugang; es gibt keine Aenderungen.
    await appModeController!.exitDemo();
    return true;
  }
  final authModel = context.read<AuthSessionModel>();
  final memberEditModel = context.read<MemberEditModel?>();
  final t = AppLocalizations.of(context);

  if (memberEditModel != null) {
    final accessToken = authModel.session?.accessToken;
    final hasSendable = memberEditModel.pendingUpdates.any(
      (entry) => !entry.needsResolution,
    );
    if (hasSendable && accessToken != null && accessToken.isNotEmpty) {
      final navigator = Navigator.of(context, rootNavigator: true);
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        useRootNavigator: true,
        builder: (_) => PopScope(
          canPop: false,
          child: AlertDialog(
            content: Row(
              children: [
                const SizedBox.square(
                  dimension: 24,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
                const SizedBox(width: 16),
                Expanded(child: Text(t.t('logout_pending_sending'))),
              ],
            ),
          ),
        ),
      );
      try {
        await memberEditModel.retryPending(
          accessToken: accessToken,
          trigger: 'logout',
        );
      } finally {
        navigator.pop();
      }
      if (!context.mounted) {
        return false;
      }
    }

    final remaining = memberEditModel.pendingUpdates.length;
    if (remaining > 0) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(t.t('logout_pending_title')),
          content: Text(t.t('logout_pending_message', {'count': remaining})),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(t.t('logout_pending_cancel')),
            ),
            FilledButton(
              key: const Key('logout-pending-confirm'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(t.t('logout_pending_confirm')),
            ),
          ],
        ),
      );
      if (confirmed != true) {
        return false;
      }
    }
  }

  await authModel.logout();
  // Die Pending-Box ist geloescht; erneutes Laden wuerde sie neu anlegen.
  memberEditModel?.clearPendingInMemory();
  return true;
}

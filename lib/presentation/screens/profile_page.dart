import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../domain/auth/auth_state.dart';
import '../../l10n/app_localizations.dart';
import '../model/auth_session_model.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Consumer<AuthSessionModel>(
      builder: (context, authModel, _) {
        final session = authModel.session;
        final formatter = DateFormat('dd.MM.yyyy HH:mm', 'de_DE');

        return Scaffold(
          appBar: AppBar(title: Text(t.t('profile'))),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ListTile(
                leading: const Icon(Icons.verified_user_outlined),
                title: Text(
                  session?.displayName ??
                      session?.email ??
                      t.t('auth_status_unknown_user'),
                ),
                subtitle: Text(
                  session?.principal ?? t.t('auth_status_signed_out'),
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.security_outlined),
                title: Text(t.t('auth_status_title')),
                subtitle: Text(_statusLabel(context, authModel.state)),
              ),
              ListTile(
                leading: const Icon(Icons.schedule_outlined),
                title: Text(t.t('auth_last_data_sync_title')),
                subtitle: Text(
                  authModel.lastSensitiveSyncAt != null
                      ? formatter.format(
                          authModel.lastSensitiveSyncAt!.toLocal(),
                        )
                      : t.t('auth_last_data_sync_unknown'),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.timelapse_outlined),
                title: Text(t.t('auth_refresh_due_title')),
                subtitle: Text(
                  authModel.isRefreshDue
                      ? t.t('auth_refresh_due_yes')
                      : t.t('auth_refresh_due_no'),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: authModel.isConfigured ? authModel.signIn : null,
                icon: const Icon(Icons.login),
                label: Text(
                  authModel.state == AuthState.reloginRequired
                      ? t.t('auth_relogin_action')
                      : t.t('auth_login_action'),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: session != null
                    ? () => authModel.performBackgroundMaintenance(
                        trigger: 'manual',
                      )
                    : null,
                icon: const Icon(Icons.sync),
                label: Text(t.t('auth_manual_refresh_action')),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: session != null ? authModel.logout : null,
                icon: const Icon(Icons.logout),
                label: Text(t.t('logout')),
              ),
            ],
          ),
        );
      },
    );
  }

  String _statusLabel(BuildContext context, AuthState state) {
    final t = AppLocalizations.of(context);
    switch (state) {
      case AuthState.initializing:
        return t.t('auth_status_initializing');
      case AuthState.signedOut:
        return t.t('auth_status_signed_out');
      case AuthState.authenticating:
        return t.t('auth_status_authenticating');
      case AuthState.signedIn:
        return t.t('auth_status_signed_in');
      case AuthState.unlockRequired:
        return t.t('auth_status_unlock_required');
      case AuthState.reloginRequired:
        return t.t('auth_status_relogin_required');
      case AuthState.error:
        return t.t('auth_status_error');
    }
  }
}

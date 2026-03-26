import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/auth/auth_state.dart';
import '../../l10n/app_localizations.dart';
import '../model/auth_session_model.dart';
import '../navigation/navigation_home.page.dart';

class AuthGateScreen extends StatelessWidget {
  const AuthGateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthSessionModel>(
      builder: (context, authModel, _) {
        switch (authModel.state) {
          case AuthState.initializing:
          case AuthState.authenticating:
            return _AuthInfoScaffold(
              title: AppLocalizations.of(context).t('auth_loading_title'),
              message: AppLocalizations.of(context).t('auth_loading_body'),
              child: const CircularProgressIndicator(),
            );
          case AuthState.unlockRequired:
            return _AuthInfoScaffold(
              title: AppLocalizations.of(context).t('auth_unlock_title'),
              message: AppLocalizations.of(context).t('auth_unlock_body'),
              errorMessage: authModel.errorMessage,
              child: FilledButton.icon(
                onPressed: authModel.unlock,
                icon: const Icon(Icons.lock_open_outlined),
                label: Text(
                  AppLocalizations.of(context).t('auth_unlock_action'),
                ),
              ),
            );
          case AuthState.reloginRequired:
            return _AuthInfoScaffold(
              title: AppLocalizations.of(context).t('auth_relogin_title'),
              message: AppLocalizations.of(context).t('auth_relogin_body'),
              errorMessage: authModel.errorMessage,
              child: FilledButton.icon(
                onPressed: authModel.isConfigured ? authModel.signIn : null,
                icon: const Icon(Icons.login),
                label: Text(
                  AppLocalizations.of(context).t('auth_login_action'),
                ),
              ),
            );
          case AuthState.signedOut:
          case AuthState.error:
            return _AuthInfoScaffold(
              title: AppLocalizations.of(context).t('auth_login_title'),
              message: authModel.isConfigured
                  ? AppLocalizations.of(context).t('auth_login_body')
                  : AppLocalizations.of(context).t('auth_not_configured_body'),
              errorMessage: authModel.errorMessage,
              child: FilledButton.icon(
                onPressed: authModel.isConfigured ? authModel.signIn : null,
                icon: const Icon(Icons.login),
                label: Text(
                  AppLocalizations.of(context).t('auth_login_action'),
                ),
              ),
            );
          case AuthState.signedIn:
            return const NavigationHomeScreen();
        }
      },
    );
  }
}

class _AuthInfoScaffold extends StatelessWidget {
  const _AuthInfoScaffold({
    required this.title,
    required this.message,
    required this.child,
    this.errorMessage,
  });

  final String title;
  final String message;
  final Widget child;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.shield_outlined,
                    size: 48,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    message,
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  if (errorMessage != null && errorMessage!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      errorMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 24),
                  child,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

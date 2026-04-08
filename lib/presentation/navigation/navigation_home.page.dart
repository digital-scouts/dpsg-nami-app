import 'package:flutter/material.dart';
import 'package:nami/domain/auth/auth_state.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/presentation/model/arbeitskontext_model.dart';
import 'package:nami/presentation/model/auth_session_model.dart';
import 'package:nami/presentation/navigation/app_router.dart';
import 'package:nami/presentation/screens/member_people_page.dart';
import 'package:nami/presentation/screens/settings_page.dart';
import 'package:nami/presentation/screens/statistics_page.dart';
import 'package:nami/presentation/widgets/app_bottom_navigation.dart';
import 'package:nami/services/logger_service.dart';
import 'package:provider/provider.dart';

class NavigationHomeScreen extends StatefulWidget {
  const NavigationHomeScreen({super.key});

  @override
  State<NavigationHomeScreen> createState() => _NavigationHomeScreenState();
}

class _NavigationHomeScreenState extends State<NavigationHomeScreen> {
  int _index = 0;

  static const List<String> _tabIds = <String>[
    'my_stage',
    'members',
    'statistics',
    'settings',
  ];

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final authModel = context.watch<AuthSessionModel>();
    final arbeitskontextModel = context.watch<ArbeitskontextModel>();
    final startseitenTitel = t.t('nav_my_stage');
    Widget body;
    switch (_index) {
      case 0:
        body = _buildProtectedBody(
          context,
          readyBody: Center(child: Text(startseitenTitel)),
          authModel: authModel,
          arbeitskontextModel: arbeitskontextModel,
        );
        break;
      case 1:
        body = _buildProtectedBody(
          context,
          readyBody: const MemberPeoplePage(),
          authModel: authModel,
          arbeitskontextModel: arbeitskontextModel,
        );
        break;
      case 2:
        body = _buildProtectedBody(
          context,
          readyBody: const StatisticsPage(),
          authModel: authModel,
          arbeitskontextModel: arbeitskontextModel,
        );
        break;
      case 3:
        body = SettingsPage(
          onStammSettings: () =>
              Navigator.pushNamed(context, AppRoutes.settingsStamm),
          onAppSettings: () =>
              Navigator.pushNamed(context, AppRoutes.settingsApp),
          onMapSettings: () =>
              Navigator.pushNamed(context, AppRoutes.settingsMap),
          onProfile: _isProfileAvailable(authModel, arbeitskontextModel)
              ? () => Navigator.pushNamed(context, AppRoutes.profile)
              : null,
          onDebugTools: () =>
              Navigator.pushNamed(context, AppRoutes.debugTools),
          onNotificationSettings: () =>
              Navigator.pushNamed(context, AppRoutes.settingsNotification),
        );
        break;
      default:
        body = Center(child: Text(t.t('nav_my_stage')));
    }

    return Scaffold(
      body: body,
      bottomNavigationBar: AppBottomNavigation(
        currentIndex: _index,
        onTap: (i) {
          if (i == _index) {
            return;
          }

          final logger = context.read<LoggerService>();
          final previousTab = _tabIds[_index];
          final nextTab = _tabIds[i];
          logger.logNavigationAction(
            'tab_switch',
            fromRoute: previousTab,
            toRoute: nextTab,
          );
          setState(() => _index = i);
        },
      ),
    );
  }

  bool _isProfileAvailable(
    AuthSessionModel authModel,
    ArbeitskontextModel arbeitskontextModel,
  ) {
    final state = authModel.state;
    final authReady =
        state == AuthState.signedIn || state == AuthState.unlockRequired;
    return authReady && arbeitskontextModel.isReady;
  }

  Widget _buildProtectedBody(
    BuildContext context, {
    required Widget readyBody,
    required AuthSessionModel authModel,
    required ArbeitskontextModel arbeitskontextModel,
  }) {
    final placeholder = _buildPlaceholder(
      context,
      authModel: authModel,
      arbeitskontextModel: arbeitskontextModel,
    );
    return SafeArea(bottom: false, child: placeholder ?? readyBody);
  }

  Widget? _buildPlaceholder(
    BuildContext context, {
    required AuthSessionModel authModel,
    required ArbeitskontextModel arbeitskontextModel,
  }) {
    final t = AppLocalizations.of(context);
    switch (authModel.state) {
      case AuthState.initializing:
      case AuthState.authenticating:
        return const _ShellStatusView(
          title: 'Anmeldung wird vorbereitet',
          message:
              'Die App initialisiert die Anmeldung. Einstellungen bleiben bereits erreichbar.',
          child: CircularProgressIndicator(),
        );
      case AuthState.reloginRequired:
        return _ShellStatusView(
          title: t.t('auth_relogin_title'),
          message: t.t('auth_relogin_body'),
          errorMessage: authModel.errorMessage,
          child: FilledButton.icon(
            onPressed: authModel.isConfigured ? authModel.signIn : null,
            icon: const Icon(Icons.login),
            label: Text(t.t('auth_login_action')),
          ),
        );
      case AuthState.signedOut:
      case AuthState.error:
        return _ShellStatusView(
          title: t.t('auth_login_title'),
          message: authModel.isConfigured
              ? t.t('auth_login_body')
              : t.t('auth_not_configured_body'),
          errorMessage: authModel.errorMessage,
          child: FilledButton.icon(
            onPressed: authModel.isConfigured ? authModel.signIn : null,
            icon: const Icon(Icons.login),
            label: Text(t.t('auth_login_action')),
          ),
        );
      case AuthState.unlockRequired:
      case AuthState.signedIn:
        if (arbeitskontextModel.status == ArbeitskontextStatus.initial ||
            arbeitskontextModel.isLoading) {
          return const _ShellStatusView(
            title: 'Arbeitskontext wird geladen',
            message:
                'Der aktive Arbeitskontext wird initialisiert. Danach stehen die kontextgebundenen Funktionen zur Verfuegung.',
            child: CircularProgressIndicator(),
          );
        }
        if (arbeitskontextModel.isUnauthorized) {
          return _ShellStatusView(
            title: ArbeitskontextModel.unauthorizedMessage,
            message:
                'Melde dich mit einem Konto an, das mindestens ein relevantes Layer- oder Gruppenrecht besitzt.',
            errorMessage: arbeitskontextModel.errorMessage,
            child: FilledButton.icon(
              onPressed: authModel.logout,
              icon: const Icon(Icons.logout),
              label: const Text('Abmelden'),
            ),
          );
        }
        if (arbeitskontextModel.hasError) {
          return _ShellStatusView(
            title: 'Arbeitskontext konnte nicht initialisiert werden',
            message:
                'Der App-Start konnte keinen gueltigen Arbeitskontext herstellen. Die Einstellungen bleiben erreichbar.',
            errorMessage: arbeitskontextModel.errorMessage,
            child: FilledButton.icon(
              onPressed: authModel.profile == null
                  ? null
                  : () => arbeitskontextModel.retry(authModel.profile),
              icon: const Icon(Icons.refresh),
              label: const Text('Erneut versuchen'),
            ),
          );
        }

        return null;
    }
  }
}

class _ShellStatusView extends StatelessWidget {
  const _ShellStatusView({
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
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.shield_outlined,
                size: 48,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge,
              ),
              if (errorMessage != null && errorMessage!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  errorMessage!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

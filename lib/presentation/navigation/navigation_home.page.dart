import 'package:flutter/material.dart';
import 'package:nami/core/notifications/pull_notification.dart';
import 'package:nami/domain/auth/auth_state.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/presentation/model/arbeitskontext_model.dart';
import 'package:nami/presentation/model/auth_session_model.dart';
import 'package:nami/presentation/model/urgent_notification_model.dart';
import 'package:nami/presentation/navigation/app_router.dart';
import 'package:nami/presentation/notifications/notification_card.dart';
import 'package:nami/presentation/screens/member_people_page.dart';
import 'package:nami/presentation/screens/settings_page.dart';
import 'package:nami/presentation/screens/settings_stufenwechsel_page.dart';
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
    'members',
    'statistics',
    'stage_change',
    'settings',
  ];

  @override
  Widget build(BuildContext context) {
    final authModel = context.watch<AuthSessionModel>();
    final arbeitskontextModel = context.watch<ArbeitskontextModel>();
    final urgentNotification = _currentUrgentNotification(context);
    Widget body;
    switch (_index) {
      case 0:
        body = _buildProtectedBody(
          context,
          readyBody: const MemberPeoplePage(),
          authModel: authModel,
          arbeitskontextModel: arbeitskontextModel,
        );
        break;
      case 1:
        body = _buildProtectedBody(
          context,
          readyBody: const StatisticsPage(),
          authModel: authModel,
          arbeitskontextModel: arbeitskontextModel,
        );
        break;
      case 2:
        body = _buildProtectedBody(
          context,
          readyBody: const SettingsStufenwechselPage(showAppBar: false),
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
          onMessages: () =>
              Navigator.pushNamed(context, AppRoutes.settingsMessages),
          onImpressum: () =>
              Navigator.pushNamed(context, AppRoutes.settingsImpressum),
          onDatenschutz: () =>
              Navigator.pushNamed(context, AppRoutes.settingsDatenschutz),
          onMapSettings: () =>
              Navigator.pushNamed(context, AppRoutes.settingsMap),
          onQualifikationen: () =>
              Navigator.pushNamed(context, AppRoutes.settingsQualifikationen),
          onNamiAi: () => Navigator.pushNamed(context, AppRoutes.namiAiChat),
          onNamiAiPaywall: () =>
              Navigator.pushNamed(context, AppRoutes.namiAiPaywall),
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
        body = const MemberPeoplePage();
    }

    return Scaffold(
      body: _index == 3
          ? body
          : _buildMainTabShell(
              context,
              content: body,
              urgentNotification: urgentNotification,
              authModel: authModel,
              arbeitskontextModel: arbeitskontextModel,
            ),
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

  PullNotification? _currentUrgentNotification(BuildContext context) {
    if (_index == 3) {
      return null;
    }
    return context.watch<UrgentNotificationModel>().notification;
  }

  Widget _buildMainTabShell(
    BuildContext context, {
    required Widget content,
    required PullNotification? urgentNotification,
    required AuthSessionModel authModel,
    required ArbeitskontextModel arbeitskontextModel,
  }) {
    final showsStaleDataWarning = arbeitskontextModel.hasStaleDataWarning;
    // arbeitskontext == null ausgeschlossen: in dem Fall zeigt bereits der
    // Vollbild-Platzhalter (_buildPlaceholder) dieselbe Checkliste zentriert
    // an - hier wuerde sie sonst doppelt erscheinen. Sobald der Arbeitskontext
    // gesetzt ist, deckt isSynchronizing/isLoadingRoles sowohl den initialen
    // Ladevorgang (ohne Luecke waehrend "Mitglieder laden") als auch spaetere
    // Syncs (Pull-to-refresh, Debug-Tools) ab.
    final showsLoadingChecklist =
        !showsStaleDataWarning &&
        arbeitskontextModel.arbeitskontext != null &&
        (arbeitskontextModel.isSynchronizing ||
            arbeitskontextModel.isLoadingRoles);
    final showsTopBanner = showsStaleDataWarning || showsLoadingChecklist;
    return Column(
      children: [
        if (urgentNotification != null)
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: NotificationCard(
                notification: urgentNotification,
                onClose: () {
                  context.read<UrgentNotificationModel>().acknowledgeCurrent();
                },
              ),
            ),
          ),
        if (showsStaleDataWarning)
          SafeArea(
            bottom: false,
            top: urgentNotification == null,
            child: _StaleDataWarningBanner(
              onRetry: () => arbeitskontextModel.refreshFromRemote(
                session: authModel.session,
                profile: authModel.profile,
              ),
            ),
          ),
        if (showsLoadingChecklist)
          SafeArea(
            bottom: false,
            top: urgentNotification == null,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Theme.of(context).colorScheme.surfaceContainerHigh,
              child: _ArbeitskontextLoadingChecklist(
                steps: arbeitskontextModel.loadingSteps,
                dense: true,
              ),
            ),
          ),
        Expanded(
          child: SafeArea(
            top: urgentNotification == null && !showsTopBanner,
            bottom: false,
            child: content,
          ),
        ),
      ],
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
    return placeholder ?? readyBody;
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
        return _ShellStatusView(
          title: t.t('nav_auth_preparing_title'),
          message: t.t('nav_auth_preparing_body'),
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
        if (arbeitskontextModel.arbeitskontext == null &&
            (arbeitskontextModel.status == ArbeitskontextStatus.initial ||
                arbeitskontextModel.isLoading)) {
          return _ShellStatusView(
            title: t.t('nav_work_context_loading_title'),
            message: t.t('nav_work_context_loading_body'),
            child: _ArbeitskontextLoadingChecklist(
              steps: arbeitskontextModel.loadingSteps,
            ),
          );
        }
        if (arbeitskontextModel.isUnauthorized) {
          return _ShellStatusView(
            title: ArbeitskontextModel.unauthorizedMessage,
            message: t.t('nav_work_context_unauthorized_body'),
            errorMessage: arbeitskontextModel.errorMessage,
            child: FilledButton.icon(
              onPressed: authModel.logout,
              icon: const Icon(Icons.logout),
              label: Text(t.t('logout')),
            ),
          );
        }
        if (arbeitskontextModel.hasError) {
          return _ShellStatusView(
            title: t.t('nav_work_context_error_title'),
            message: t.t('nav_work_context_error_body'),
            errorMessage: arbeitskontextModel.errorMessage,
            child: FilledButton.icon(
              onPressed: () =>
                  _retryArbeitskontext(authModel, arbeitskontextModel),
              icon: const Icon(Icons.refresh),
              label: Text(t.t('common_retry')),
            ),
          );
        }
        if (arbeitskontextModel.arbeitskontext == null &&
            !authModel.dataSyncStatus.hasValidLocalData) {
          return _ShellStatusView(
            title: t.t('nav_work_context_error_title'),
            message: t.t('nav_work_context_error_body'),
            errorMessage: authModel.errorMessage,
            child: FilledButton.icon(
              onPressed: () => _retryInitialDataLoad(
                authModel: authModel,
                arbeitskontextModel: arbeitskontextModel,
              ),
              icon: const Icon(Icons.refresh),
              label: Text(t.t('common_retry')),
            ),
          );
        }

        return null;
    }
  }

  Future<void> _retryArbeitskontext(
    AuthSessionModel authModel,
    ArbeitskontextModel arbeitskontextModel,
  ) async {
    // Ohne Profil (z.B. weil dessen Abruf zuvor fehlgeschlagen ist) kann
    // ArbeitskontextModel.retry() nichts tun - zuerst das Profil erneut
    // laden, bevor der eigentliche Arbeitskontext-Retry versucht wird.
    if (authModel.profile == null) {
      await authModel.ensureProfileLoaded(force: true);
    }
    final profile = authModel.profile;
    if (profile == null) {
      return;
    }
    await arbeitskontextModel.retry(profile);
  }

  Future<void> _retryInitialDataLoad({
    required AuthSessionModel authModel,
    required ArbeitskontextModel arbeitskontextModel,
  }) async {
    await arbeitskontextModel.clearCachedData();
    await authModel.syncHitobitoData(
      force: true,
      trigger: 'initial_data_retry',
      allowMobileDataOverride: true,
      syncMembers: (accessToken) async {
        await arbeitskontextModel.refreshFromRemote(
          session: authModel.session,
          profile: authModel.profile,
          allowMobileDataOverride: true,
          scheduleRolesPreload: false,
        );
        final rolesLoaded = await arbeitskontextModel.ensureRolesLoaded(
          allowMobileDataOverride: true,
        );
        if (!rolesLoaded) {
          throw StateError('Rollen konnten nicht vollstaendig geladen werden.');
        }
      },
    );
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

class _StaleDataWarningBanner extends StatelessWidget {
  const _StaleDataWarningBanner({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: theme.colorScheme.errorContainer,
      child: Row(
        children: [
          Icon(
            Icons.sync_problem,
            size: 18,
            color: theme.colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              t.t('nav_work_context_sync_warning'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          ),
          IconButton(
            iconSize: 18,
            color: theme.colorScheme.onErrorContainer,
            icon: const Icon(Icons.refresh),
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}

class _ArbeitskontextLoadingChecklist extends StatelessWidget {
  const _ArbeitskontextLoadingChecklist({
    required this.steps,
    this.dense = false,
  });

  final List<ArbeitskontextLoadingStepStatus> steps;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final step in steps)
          Padding(
            padding: EdgeInsets.symmetric(vertical: dense ? 2 : 4),
            child: _ArbeitskontextLoadingStepRow(step: step, dense: dense),
          ),
      ],
    );
  }
}

class _ArbeitskontextLoadingStepRow extends StatelessWidget {
  const _ArbeitskontextLoadingStepRow({
    required this.step,
    required this.dense,
  });

  final ArbeitskontextLoadingStepStatus step;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final iconSize = dense ? 16.0 : 20.0;
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
        color: theme.colorScheme.outline,
      ),
    };
    final statusText = step.detailKey != null && step.detailCount != null
        ? t.t(step.detailKey!, {'count': '${step.detailCount}'})
        : t.t(switch (step.state) {
            ArbeitskontextLoadingStepState.done =>
              'nav_work_context_step_state_done',
            ArbeitskontextLoadingStepState.loading =>
              'nav_work_context_step_state_loading',
            ArbeitskontextLoadingStepState.waiting =>
              'nav_work_context_step_state_waiting',
          });
    final textStyle = dense
        ? theme.textTheme.bodySmall
        : theme.textTheme.bodyMedium;
    final dimmed = step.state == ArbeitskontextLoadingStepState.waiting;
    return Row(
      children: [
        icon,
        const SizedBox(width: 10),
        Text(
          t.t(step.labelKey),
          style: textStyle?.copyWith(
            color: dimmed ? theme.colorScheme.outline : null,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            statusText,
            textAlign: TextAlign.right,
            style: textStyle?.copyWith(
              color: dimmed
                  ? theme.colorScheme.outline
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

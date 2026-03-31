import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../domain/arbeitskontext/arbeitskontext.dart';
import '../../domain/auth/auth_profile.dart';
import '../../domain/auth/auth_state.dart';
import '../../l10n/app_localizations.dart';
import '../model/arbeitskontext_model.dart';
import '../model/auth_session_model.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthSessionModel>().ensureProfileLoaded();
    });
  }

  Future<void> _openLayerSwitcher(
    BuildContext context, {
    required AuthSessionModel authModel,
    required ArbeitskontextModel arbeitskontextModel,
  }) async {
    final arbeitskontext = arbeitskontextModel.arbeitskontext;
    if (arbeitskontext == null || arbeitskontext.verfuegbareLayer.isEmpty) {
      return;
    }

    final selectedLayer = await showModalBottomSheet<ArbeitskontextLayer>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) =>
          _LayerSwitcherSheet(arbeitskontext: arbeitskontext),
    );

    if (!mounted || selectedLayer == null) {
      return;
    }

    await arbeitskontextModel.switchToLayer(
      targetLayer: selectedLayer,
      session: authModel.session,
      profile: authModel.profile,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);

    return Consumer2<AuthSessionModel, ArbeitskontextModel>(
      builder: (context, authModel, arbeitskontextModel, _) {
        final profile = authModel.profile;

        return Scaffold(
          appBar: AppBar(title: Text(t.t('profile'))),
          body: Stack(
            children: [
              ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (profile != null) ...[
                    _ProfileHeader(profile: profile),
                    const SizedBox(height: 8),
                    _ProfileInfoCard(profile: profile),
                    const SizedBox(height: 8),
                  ] else ...[
                    _ProfilePlaceholder(
                      isLoading: authModel.isLoadingProfile,
                      errorMessage: authModel.errorMessage,
                    ),
                    const SizedBox(height: 8),
                  ],
                  _ArbeitskontextCard(
                    arbeitskontextModel: arbeitskontextModel,
                    onOpenLayerSwitcher: arbeitskontextModel.isSwitchingLayer
                        ? null
                        : () => _openLayerSwitcher(
                            context,
                            authModel: authModel,
                            arbeitskontextModel: arbeitskontextModel,
                          ),
                  ),
                  const SizedBox(height: 8),
                  if (profile != null) ...[
                    _ProfileRolesCard(profile: profile),
                    const SizedBox(height: 8),
                  ],
                  _ProfileStatusCard(authModel: authModel),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: authModel.session != null
                        ? authModel.logout
                        : null,
                    icon: const Icon(Icons.logout),
                    label: Text(t.t('logout')),
                  ),
                ],
              ),
              if (arbeitskontextModel.isSwitchingLayer)
                const _ProfileLoadingOverlay(),
            ],
          ),
        );
      },
    );
  }
}

class _ArbeitskontextCard extends StatelessWidget {
  const _ArbeitskontextCard({
    required this.arbeitskontextModel,
    required this.onOpenLayerSwitcher,
  });

  final ArbeitskontextModel arbeitskontextModel;
  final VoidCallback? onOpenLayerSwitcher;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final arbeitskontext = arbeitskontextModel.arbeitskontext;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t.t('profile_context_title'),
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            if (arbeitskontextModel.isLoading && arbeitskontext == null) ...[
              const Center(child: CircularProgressIndicator()),
              const SizedBox(height: 12),
              Text(t.t('profile_context_loading')),
            ] else if (arbeitskontext != null) ...[
              _InfoTile(
                icon: Icons.account_tree_outlined,
                label: t.t('profile_context_current_layer_label'),
                value: arbeitskontext.aktiverLayer.name,
              ),
              if (arbeitskontextModel.errorMessage != null &&
                  arbeitskontextModel.errorMessage!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  arbeitskontextModel.errorMessage!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ],
              const SizedBox(height: 12),
              if (arbeitskontext.verfuegbareLayer.isNotEmpty)
                FilledButton.icon(
                  onPressed: onOpenLayerSwitcher,
                  icon: const Icon(Icons.swap_horiz),
                  label: Text(t.t('profile_context_switch_action')),
                )
              else
                Text(
                  t.t('profile_context_no_other_layers'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ] else ...[
              Text(t.t('profile_context_unavailable')),
              if (arbeitskontextModel.errorMessage != null &&
                  arbeitskontextModel.errorMessage!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  arbeitskontextModel.errorMessage!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _LayerSwitcherSheet extends StatelessWidget {
  const _LayerSwitcherSheet({required this.arbeitskontext});

  final Arbeitskontext arbeitskontext;
  static const _layerListKey = ValueKey('layer_switcher_list');

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final maxSheetHeight = MediaQuery.sizeOf(context).height * 0.8;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxSheetHeight),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t.t('profile_context_sheet_title'),
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                t.t('profile_context_sheet_hint'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.check_circle_outline),
                title: Text(arbeitskontext.aktiverLayer.name),
                subtitle: Text(t.t('profile_context_current_badge')),
                trailing: const Icon(Icons.radio_button_checked),
              ),
              const Divider(),
              Flexible(
                fit: FlexFit.loose,
                child: ListView.separated(
                  key: _layerListKey,
                  shrinkWrap: true,
                  itemCount: arbeitskontext.verfuegbareLayer.length,
                  itemBuilder: (context, index) {
                    final layer = arbeitskontext.verfuegbareLayer[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.account_tree_outlined),
                      title: Text(layer.name),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).pop(layer),
                    );
                  },
                  separatorBuilder: (_, _) => const Divider(height: 1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileLoadingOverlay extends StatelessWidget {
  const _ProfileLoadingOverlay();

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);

    return ColoredBox(
      color: Colors.black54,
      child: Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(t.t('profile_context_switch_loading')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileStatusCard extends StatelessWidget {
  const _ProfileStatusCard({required this.authModel});

  final AuthSessionModel authModel;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final stateText = authModel.hasRemoteAccessIssue
        ? authModel.requiresInteractiveLogin
              ? t.t('auth_status_update_login_required')
              : t.t('auth_status_cached_only')
        : switch (authModel.state) {
            AuthState.initializing => t.t('auth_status_initializing'),
            AuthState.signedOut => t.t('auth_status_signed_out'),
            AuthState.authenticating => t.t('auth_status_authenticating'),
            AuthState.signedIn => t.t('auth_status_signed_in'),
            AuthState.unlockRequired => t.t('auth_status_unlock_required'),
            AuthState.reloginRequired => t.t('auth_status_relogin_required'),
            AuthState.error => t.t('auth_status_error'),
          };

    return Card(
      child: Column(
        children: [
          _InfoTile(
            icon: Icons.verified_user_outlined,
            label: t.t('auth_status_title'),
            value: stateText,
          ),
          _InfoTile(
            icon: Icons.update_outlined,
            label: t.t('auth_last_data_sync_title'),
            value: _formatTimestamp(
              context,
              authModel.lastSensitiveSyncAt,
              fallback: t.t('auth_last_data_sync_unknown'),
            ),
          ),
          _InfoTile(
            icon: Icons.account_circle_outlined,
            label: t.t('profile_last_sync_title'),
            value: authModel.isLoadingProfile
                ? t.t('profile_loading')
                : _formatTimestamp(
                    context,
                    authModel.lastProfileSyncAt,
                    fallback: t.t('auth_status_unknown_user'),
                  ),
          ),
          if (authModel.isSyncingHitobitoData)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: LinearProgressIndicator(minHeight: 2),
            ),
        ],
      ),
    );
  }

  String _formatTimestamp(
    BuildContext context,
    DateTime? value, {
    required String fallback,
  }) {
    if (value == null) {
      return fallback;
    }

    final locale = Localizations.localeOf(context).toLanguageTag();
    return DateFormat('dd.MM.yyyy HH:mm', locale).format(value.toLocal());
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.profile});

  final AuthProfile profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final avatarLabel = profile.primaryDisplayName.isNotEmpty
        ? profile.primaryDisplayName.characters.first.toUpperCase()
        : '?';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 28,
              child: Text(avatarLabel, style: theme.textTheme.titleLarge),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.primaryDisplayName,
                    style: theme.textTheme.headlineSmall,
                  ),
                  if (profile.secondaryDisplayName != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      profile.secondaryDisplayName!,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileInfoCard extends StatelessWidget {
  const _ProfileInfoCard({required this.profile});

  final AuthProfile profile;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Card(
      child: Column(
        children: [
          _InfoTile(
            icon: Icons.badge_outlined,
            label: t.t('profile_nami_id_label'),
            value: profile.namiId.toString(),
          ),
          _InfoTile(
            icon: Icons.email_outlined,
            label: t.t('profile_email_label'),
            value: (profile.email?.trim().isNotEmpty ?? false)
                ? profile.email!.trim()
                : '–',
          ),
          _InfoTile(
            icon: Icons.translate_outlined,
            label: t.t('profile_language_label'),
            child: Text(
              profile.normalizedLanguage.toUpperCase(),
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSecondaryContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileRolesCard extends StatelessWidget {
  const _ProfileRolesCard({required this.profile});

  final AuthProfile profile;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.t('profile_roles_title'), style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            if (profile.roles.isEmpty)
              Text(
                t.t('profile_roles_empty'),
                style: theme.textTheme.bodyMedium,
              )
            else
              for (var index = 0; index < profile.roles.length; index++) ...[
                _ProfileRoleTile(role: profile.roles[index]),
                if (index < profile.roles.length - 1) const Divider(height: 24),
              ],
          ],
        ),
      ),
    );
  }
}

class _ProfileRoleTile extends StatelessWidget {
  const _ProfileRoleTile({required this.role});

  final AuthProfileRole role;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final permissions = role.permissions.join(', ');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 2),
          child: Icon(Icons.groups_2_outlined),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                role.roleName,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 2),
              Text(role.groupName),
              if (permissions.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text('${t.t('profile_permissions_label')}: $permissions'),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfilePlaceholder extends StatelessWidget {
  const _ProfilePlaceholder({required this.isLoading, this.errorMessage});

  final bool isLoading;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            if (isLoading) ...[
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(t.t('profile_loading')),
            ] else ...[
              Icon(
                Icons.account_circle_outlined,
                size: 40,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 12),
              Text(t.t('profile_not_loaded'), textAlign: TextAlign.center),
            ],
            if (errorMessage != null && errorMessage!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                errorMessage!,
                style: TextStyle(color: theme.colorScheme.error),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    this.value,
    this.child,
  }) : assert(value != null || child != null);

  final IconData icon;
  final String label;
  final String? value;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      subtitle: child ?? Text(value!),
    );
  }
}

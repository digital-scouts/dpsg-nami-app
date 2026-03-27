import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/auth/auth_profile.dart';
import '../../l10n/app_localizations.dart';
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

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);

    return Consumer<AuthSessionModel>(
      builder: (context, authModel, _) {
        final profile = authModel.profile;

        return Scaffold(
          appBar: AppBar(title: Text(t.t('profile'))),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (profile != null) ...[
                _ProfileHeader(profile: profile),
                const SizedBox(height: 16),
                _ProfileInfoCard(profile: profile),
                const SizedBox(height: 16),
                _ProfileRolesCard(profile: profile),
                const SizedBox(height: 24),
              ] else ...[
                _ProfilePlaceholder(
                  isLoading: authModel.isLoadingProfile,
                  errorMessage: authModel.errorMessage,
                ),
                const SizedBox(height: 24),
              ],
              OutlinedButton.icon(
                onPressed: authModel.session != null ? authModel.logout : null,
                icon: const Icon(Icons.logout),
                label: Text(t.t('logout')),
              ),
            ],
          ),
        );
      },
    );
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
            child: _LanguageBadge(languageCode: profile.normalizedLanguage),
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

class _LanguageBadge extends StatelessWidget {
  const _LanguageBadge({required this.languageCode});

  final String languageCode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        languageCode.toUpperCase(),
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.onSecondaryContainer,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

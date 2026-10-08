import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../domain/appearance/appearance_catalog.dart';
import '../../domain/achievements/achievement_progress.dart';
import '../../domain/arbeitskontext/arbeitskontext.dart';
import '../../domain/auth/auth_profile.dart';
import '../../domain/appearance/support_access.dart';
import '../../l10n/app_localizations.dart';
import '../model/appearance_model.dart';
import '../model/arbeitskontext_model.dart';
import '../model/auth_session_model.dart';
import '../model/supporter_kauf_model.dart';
import '../navigation/app_router.dart';
import '../theme/theme.dart';
import '../widgets/achievement_badge.dart';
import '../widgets/logout_flow.dart';
import '../widgets/supporter_badge.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, this.achievements, this.onAchievements});

  /// Ohne Erfolge (z. B. in Stories) entfällt die Erfolge-Karte.
  final List<AchievementProgress>? achievements;
  final VoidCallback? onAchievements;

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
        final theme = Theme.of(context);
        final profile = authModel.profile;
        final accentColor = _profileAccentColor(theme, profile);

        return Scaffold(
          appBar: AppBar(title: Text(t.t('profile'))),
          body: Stack(
            children: [
              ListView(
                padding: const EdgeInsets.only(bottom: 16),
                children: [
                  if (profile != null) ...[
                    _ProfileHeader(
                      profile: profile,
                      accentColor: accentColor,
                      badge: context.watch<AppearanceModel?>()?.badge,
                      kauf: context.watch<SupporterKaufModel?>(),
                    ),
                    _ProfileSectionLabel(
                      label: 'Persönliche Daten',
                      accentColor: accentColor,
                    ),
                    _ProfileInfoCard(profile: profile),
                  ] else ...[
                    _ProfilePlaceholder(
                      isLoading: authModel.isLoadingProfile,
                      errorMessage: authModel.errorMessage,
                    ),
                  ],
                  if (widget.achievements != null) ...[
                    _ProfileSectionLabel(
                      label: t.t('achievements_title'),
                      accentColor: accentColor,
                    ),
                    _ProfileAchievementsCard(
                      achievements: widget.achievements!,
                      onTap: widget.onAchievements,
                    ),
                  ],
                  _ProfileSectionLabel(
                    label: t.t('profile_context_title'),
                    accentColor: accentColor,
                  ),
                  _ArbeitskontextCard(
                    arbeitskontextModel: arbeitskontextModel,
                    accentColor: accentColor,
                    onOpenLayerSwitcher: arbeitskontextModel.isSwitchingLayer
                        ? null
                        : () => _openLayerSwitcher(
                            context,
                            authModel: authModel,
                            arbeitskontextModel: arbeitskontextModel,
                          ),
                  ),
                  if (profile != null) ...[
                    _ProfileSectionLabel(
                      label: t.t('profile_roles_title'),
                      accentColor: accentColor,
                    ),
                    _ProfileRolesCard(
                      profile: profile,
                      accentColor: accentColor,
                    ),
                  ],
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: OutlinedButton.icon(
                      onPressed: authModel.session != null
                          ? () => runLogoutFlow(context)
                          : null,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: theme.colorScheme.error,
                        side: BorderSide(
                          color: theme.colorScheme.error,
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        minimumSize: const Size.fromHeight(48),
                      ),
                      icon: const Icon(Icons.logout),
                      label: Text(t.t('logout')),
                    ),
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
    required this.accentColor,
    required this.onOpenLayerSwitcher,
  });

  final ArbeitskontextModel arbeitskontextModel;
  final Color accentColor;
  final VoidCallback? onOpenLayerSwitcher;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final arbeitskontext = arbeitskontextModel.arbeitskontext;

    return Container(
      key: const ValueKey('profile_context_card'),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accentColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.t('profile_context_title').toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.65),
              letterSpacing: 0.8,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          if (arbeitskontextModel.isLoading && arbeitskontext == null) ...[
            Text(
              t.t('profile_context_loading'),
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white),
            ),
          ] else if (arbeitskontext != null) ...[
            Text(
              arbeitskontext.aktiverLayer.name,
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (arbeitskontextModel.errorMessage != null &&
                arbeitskontextModel.errorMessage!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                arbeitskontextModel.errorMessage!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
            ],
            const SizedBox(height: 12),
            if (arbeitskontext.verfuegbareLayer.isNotEmpty)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onOpenLayerSwitcher,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.35),
                      width: 1.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.swap_horiz, size: 18),
                  label: Text(t.t('profile_context_switch_action')),
                ),
              )
            else
              Text(
                t.t('profile_context_no_other_layers'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
          ] else ...[
            Text(
              t.t('profile_context_unavailable'),
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white),
            ),
          ],
        ],
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

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.profile,
    required this.accentColor,
    this.badge,
    this.kauf,
  });

  final AuthProfile profile;
  final Color accentColor;
  final SupporterBadgeId? badge;

  /// Nur mit Store-Anbindung: Chip mit Supporter-Stand unter der Mail.
  final SupporterKaufModel? kauf;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final headline = profile.secondaryDisplayName ?? profile.primaryDisplayName;
    final avatarLabel = headline.isNotEmpty
        ? headline.characters.first.toUpperCase()
        : '?';
    final secondaryLine = (profile.email?.trim().isNotEmpty ?? false)
        ? profile.email!.trim()
        : profile.secondaryDisplayName != null
        ? profile.primaryDisplayName
        : null;

    return Container(
      key: const ValueKey('profile_header'),
      color: accentColor,
      padding: const EdgeInsets.fromLTRB(16, 32, 16, 24),
      child: Column(
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            child: Text(
              avatarLabel,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  headline,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              if (badge != null) ...[
                const SizedBox(width: 8),
                SupporterBadge(badge: badge!, size: 26),
              ],
            ],
          ),
          if (secondaryLine != null) ...[
            const SizedBox(height: 2),
            Text(
              secondaryLine,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.75),
              ),
              textAlign: TextAlign.center,
            ),
          ],
          if (kauf != null) ...[
            const SizedBox(height: 10),
            // Wie die Kaufseite: Testschalter vor Store-Stand.
            _SupporterChip(
              access: context.watch<AppearanceModel?>()?.access ?? kauf!.access,
            ),
          ],
        ],
      ),
    );
  }
}

class _SupporterChip extends StatelessWidget {
  const _SupporterChip({required this.access});

  final SupportAccess access;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final foerderer = access.foerderer;
    final label = foerderer
        ? t.t('profil_foerderer')
        : access.pakete.isNotEmpty
        ? t.t('profil_foerderer_werden')
        : t.t('profil_supporter_werden');
    final vordergrund = foerderer ? const Color(0xFF1B2A3A) : Colors.white;
    return Material(
      color: foerderer
          ? const Color(0xFFFFD678)
          : Colors.white.withValues(alpha: 0.16),
      shape: const StadiumBorder(),
      child: InkWell(
        key: const ValueKey('profile_supporter_chip'),
        customBorder: const StadiumBorder(),
        onTap: () => Navigator.pushNamed(context, AppRoutes.supporter),
        child: Padding(
          padding: EdgeInsets.fromLTRB(foerderer ? 6 : 12, 5, 12, 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (foerderer) ...[
                const SupporterBadge(
                  badge: SupporterBadgeId.foerdererPolarstern,
                  size: 18,
                ),
                const SizedBox(width: 6),
              ] else if (access.pakete.isEmpty) ...[
                Icon(Icons.favorite_border, size: 14, color: vordergrund),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: vordergrund,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
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
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _ProfileInfoRow(
            icon: Icons.badge_outlined,
            label: t.t('profile_nami_id_label'),
            value: profile.namiId.toString(),
            trailing: IconButton(
              onPressed: () {
                Clipboard.setData(
                  ClipboardData(text: profile.namiId.toString()),
                );
              },
              icon: Icon(
                Icons.content_copy,
                size: 18,
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              splashRadius: 18,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileAchievementsCard extends StatelessWidget {
  const _ProfileAchievementsCard({required this.achievements, this.onTap});

  static const _maxBadges = 3;

  final List<AchievementProgress> achievements;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final reached = achievements.fold<int>(0, (s, a) => s + a.reachedLevels);
    final total = achievements.fold<int>(
      0,
      (s, a) => s + a.definition.levelCount,
    );
    // Höchste Stufen zuerst; einmalige Erfolge zählen wie Gold.
    final best = achievements.where((a) => a.isUnlocked).toList()
      ..sort((a, b) => _rank(b).compareTo(_rank(a)));

    return Card(
      key: const Key('profile-achievements-card'),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              if (best.isEmpty)
                const AchievementBadge(
                  icon: Icons.emoji_events_rounded,
                  progress: 0,
                  size: 48,
                )
              else
                for (final a in best.take(_maxBadges))
                  AchievementBadge.fromProgress(a, size: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.t('achievements_summary', {
                        'reached': reached,
                        'total': total,
                      }),
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      t.t('achievements_profile_show_all'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outlineVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                Icon(
                  Icons.chevron_right,
                  color: theme.colorScheme.outlineVariant,
                ),
            ],
          ),
        ),
      ),
    );
  }

  static int _rank(AchievementProgress a) =>
      a.definition.isOneTime ? 2 : (a.currentTier?.index ?? -1);
}

class _ProfileSectionLabel extends StatelessWidget {
  const _ProfileSectionLabel({required this.label, required this.accentColor});

  final String label;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
      child: Text(
        label.toUpperCase(),
        style: theme.textTheme.labelMedium?.copyWith(
          color: accentColor,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _ProfileDivider extends StatelessWidget {
  const _ProfileDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      indent: 16,
      color: Theme.of(
        context,
      ).colorScheme.outlineVariant.withValues(alpha: 0.28),
    );
  }
}

class _ProfileInfoRow extends StatelessWidget {
  const _ProfileInfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final String value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(
              icon,
              size: 20,
              color: theme.colorScheme.outlineVariant,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: theme.textTheme.titleMedium),
                const SizedBox(height: 1),
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outlineVariant,
                  ),
                ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class _ProfileRolesCard extends StatelessWidget {
  const _ProfileRolesCard({required this.profile, required this.accentColor});

  final AuthProfile profile;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);

    if (profile.roles.isEmpty) {
      return Card(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 4),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            t.t('profile_roles_empty'),
            style: theme.textTheme.bodyMedium,
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var index = 0; index < profile.roles.length; index++) ...[
            _ProfileRoleTile(
              role: profile.roles[index],
              accentColor: accentColor,
            ),
            if (index < profile.roles.length - 1) const _ProfileDivider(),
          ],
        ],
      ),
    );
  }
}

class _ProfileRoleTile extends StatelessWidget {
  const _ProfileRoleTile({required this.role, required this.accentColor});

  final AuthProfileRole role;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final permissions = role.permissions.join(', ');
    final iconBackgroundColor = accentColor.withValues(
      alpha: theme.brightness == Brightness.dark ? 0.24 : 0.12,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconBackgroundColor,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(Icons.military_tech, size: 20, color: accentColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(role.roleName, style: theme.textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  role.groupName,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outlineVariant,
                  ),
                ),
                if (permissions.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${t.t('profile_permissions_label')}: $permissions',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outlineVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Color _profileAccentColor(ThemeData theme, AuthProfile? profile) {
  if (profile?.hasLeitungsRole ?? false) {
    return DPSGColors.primaryLight;
  }

  return theme.colorScheme.primary;
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
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
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

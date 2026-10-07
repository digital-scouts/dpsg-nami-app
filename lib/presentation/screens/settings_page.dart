import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nami/core/notifications/pull_notifications_repository_factory.dart';
import 'package:nami/domain/appearance/appearance_catalog.dart';
import 'package:nami/domain/arbeitskontext/arbeitskontext_read_model.dart';
import 'package:nami/domain/auth/auth_profile.dart';
import 'package:nami/domain/qualifikation/ermittle_qualifikations_uebersicht_usecase.dart';
import 'package:nami/domain/qualifikation/qualifikations_einstellungen.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/presentation/model/appearance_model.dart';
import 'package:nami/presentation/model/arbeitskontext_model.dart';
import 'package:nami/presentation/model/auth_session_model.dart';
import 'package:nami/presentation/model/member_edit_model.dart';
import 'package:nami/presentation/model/qualifikations_einstellungen_model.dart';
import 'package:nami/presentation/notifications/notifications_hub.dart';
import 'package:nami/presentation/widgets/app_page_header.dart';
import 'package:nami/presentation/widgets/confetti_overlay.dart';
import 'package:nami/presentation/widgets/demo_zugang_sheet.dart';
import 'package:nami/presentation/widgets/section_header.dart';
import 'package:nami/presentation/widgets/supporter_badge.dart';
import 'package:nami/services/app_mode_controller.dart';
import 'package:nami/services/app_update_service.dart';
import 'package:nami/services/logger_service.dart';
import 'package:nami/services/nami_ai/nami_ai_access_service.dart';
import 'package:nami/services/network_access_policy.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:nami/presentation/notifications/qualifikations_meldung.dart';
import 'package:provider/provider.dart';

class SettingsPage extends StatefulWidget {
  final VoidCallback? onStammSettings;
  final VoidCallback? onNotificationSettings;
  final VoidCallback? onAppSettings;
  final VoidCallback? onAppearanceSettings;
  final VoidCallback? onMapSettings;
  final VoidCallback? onQualifikationen;
  final FutureOr<void> Function()? onMessages;
  final VoidCallback? onRechtliches;
  final VoidCallback? onDebugTools;
  final VoidCallback? onNamiAi;
  final VoidCallback? onNamiAiPaywall;
  final VoidCallback? onProfile;

  /// Nur im Demo-Modus gesetzt: zeigt den Demo-Hinweis mit Ausstieg.
  final VoidCallback? onExitDemo;

  /// Zugang der laufenden Demo, beschreibt im Demo-Hinweis die Rolle.
  final DemoZugang? demoZugang;
  final String? appVersion;
  final Future<NamiAiAccessDecision> Function()? namiAiAccessLoader;
  final Future<List<AppHubNotification>> Function()?
  unreadExternalNotificationsLoader;

  const SettingsPage({
    super.key,
    this.onStammSettings,
    this.onNotificationSettings,
    this.onAppSettings,
    this.onAppearanceSettings,
    this.onMapSettings,
    this.onQualifikationen,
    this.onMessages,
    this.onRechtliches,
    this.onDebugTools,
    this.onNamiAi,
    this.onNamiAiPaywall,
    this.onProfile,
    this.onExitDemo,
    this.demoZugang,
    this.appVersion,
    this.namiAiAccessLoader,
    this.unreadExternalNotificationsLoader,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  int _tapCount = 0;
  DateTime? _firstTapAt;
  String? _appVersion;
  late Future<AppUpdateInfo?> _appUpdateFuture;
  late Future<List<AppHubNotification>> _unreadExternalNotificationsFuture;
  late Future<NamiAiAccessDecision> _namiAiAccessFuture;

  @override
  void initState() {
    super.initState();
    _unreadExternalNotificationsFuture = _loadUnreadExternalNotifications();
    _appUpdateFuture = _loadAppUpdateInfo();
    _namiAiAccessFuture = _loadNamiAiAccessDecision();
    _appVersion = widget.appVersion;
    if (_appVersion == null) {
      _loadAppVersion();
    }
  }

  Future<NamiAiAccessDecision> _loadNamiAiAccessDecision() async {
    final loader = widget.namiAiAccessLoader;
    if (loader != null) {
      return loader();
    }
    try {
      return await context.read<NamiAiAccessService>().evaluate();
    } catch (_) {
      return NamiAiAccessService().evaluate();
    }
  }

  Future<AppUpdateInfo?> _loadAppUpdateInfo() async {
    try {
      return await _resolveAppUpdateService().checkForUpdate();
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadAppVersion() async {
    String version = '-';
    try {
      final info = await PackageInfo.fromPlatform();
      version = info.version;
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _appVersion = version;
    });
  }

  Future<List<AppHubNotification>> _loadUnreadExternalNotifications() async {
    final loader = widget.unreadExternalNotificationsLoader;
    if (loader != null) {
      return loader();
    }
    try {
      final logger = context.read<LoggerService>();
      final repo = await createPullNotificationsRepository(
        logger: logger,
        networkAccessPolicy: _resolveNetworkAccessPolicy(),
      );
      final notifications = await repo.fetchNotifications();
      final acknowledged = await repo.getAcknowledgedIds();
      return NotificationsHub.mapUnreadExternal(
        notifications: notifications,
        acknowledged: acknowledged,
      );
    } catch (_) {
      return const <AppHubNotification>[];
    }
  }

  Future<void> _openMessages() async {
    await widget.onMessages?.call();
    if (!mounted) {
      return;
    }
    setState(() {
      _unreadExternalNotificationsFuture = _loadUnreadExternalNotifications();
    });
  }

  AppUpdateService _resolveAppUpdateService() {
    try {
      return context.read<AppUpdateService>();
    } catch (_) {
      return AppUpdateService(
        networkAccessPolicy: _resolveNetworkAccessPolicy(),
      );
    }
  }

  NetworkAccessPolicy? _resolveNetworkAccessPolicy() {
    try {
      return context.read<NetworkAccessPolicy>();
    } catch (_) {
      return null;
    }
  }

  void _handleTippleTapInTwoSeconds() {
    final now = DateTime.now();
    if (_firstTapAt == null ||
        now.difference(_firstTapAt!) > const Duration(seconds: 2)) {
      _firstTapAt = now;
      _tapCount = 1;
    } else {
      _tapCount++;
    }

    if (_tapCount >= 3) {
      _tapCount = 0;
      _firstTapAt = null;
      _showConfetti();
    }
  }

  void _showConfetti() {
    final overlay = Overlay.of(context);
    final entry = OverlayEntry(builder: (_) => const ConfettiOverlay());
    overlay.insert(entry);
    Future<void>.delayed(const Duration(seconds: 3), () {
      if (entry.mounted) {
        entry.remove();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context);

    return Consumer<AuthSessionModel>(
      builder: (context, authModel, _) {
        final unresolvedCount =
            context.watch<MemberEditModel?>()?.openResolutionCount ?? 0;

        return FutureBuilder<AppUpdateInfo?>(
          future: _appUpdateFuture,
          builder: (context, updateSnapshot) {
            return FutureBuilder<List<AppHubNotification>>(
              future: _unreadExternalNotificationsFuture,
              builder: (context, notificationSnapshot) {
                final hubMessages = NotificationsHub.mergeSorted(
                  internal: NotificationsHub.buildInternal(
                    authModel: authModel,
                    unresolvedCount: unresolvedCount,
                    updateInfo: updateSnapshot.data,
                    eigeneQualifikationsAblaeufe: eigeneQualifikationsAblaeufe(
                      context,
                    ),
                  ),
                  external:
                      notificationSnapshot.data ?? const <AppHubNotification>[],
                );
                final primaryMessage = hubMessages.isNotEmpty
                    ? hubMessages.first
                    : null;

                return FutureBuilder<NamiAiAccessDecision>(
                  future: _namiAiAccessFuture,
                  builder: (context, namiAiSnapshot) {
                    final namiAiDecision =
                        namiAiSnapshot.data ??
                        const NamiAiAccessDecision(
                          state: NamiAiAccessState.hidden,
                        );

                    final appearance = context.watch<AppearanceModel?>();
                    final readModel = context
                        .watch<ArbeitskontextModel?>()
                        ?.readModel;
                    final layer = readModel?.arbeitskontext.aktiverLayer;
                    final qualiEinstellungen = context
                        .watch<QualifikationsEinstellungenModel?>()
                        ?.einstellungen;
                    final qualiGesperrt =
                        appearance != null &&
                        !appearance.access.isTierUnlocked(
                          SupportTier.supporter,
                        );
                    return Column(
                      children: [
                        _SettingsProfileHeader(
                          background: appearance?.background,
                          profile: authModel.profile,
                          layerName: layer?.name,
                          badge: appearance?.badge,
                          onTap: widget.onProfile,
                        ),
                        Expanded(
                          child: ListView(
                            padding: const EdgeInsets.all(16),
                            children: [
                              if (widget.onExitDemo != null) ...[
                                Card(
                                  key: const Key('demo-mode-card'),
                                  margin: EdgeInsets.zero,
                                  color: theme.colorScheme.tertiaryContainer,
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          t.t('demo_banner_title'),
                                          style: theme.textTheme.titleMedium,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          [
                                            if (widget.demoZugang
                                                case final zugang?)
                                              t.t(zugang.hinweisKey),
                                            t.t('demo_banner_body'),
                                          ].join(' '),
                                        ),
                                        const SizedBox(height: 8),
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: FilledButton.tonalIcon(
                                            key: const Key('demo-exit'),
                                            onPressed: widget.onExitDemo,
                                            icon: const Icon(Icons.logout),
                                            label: Text(
                                              t.t('demo_exit_action'),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],
                              if (primaryMessage != null) ...[
                                _SettingsMessagesBanner(
                                  key: const Key('settings-messages-banner'),
                                  title: primaryMessage.title.resolve(locale),
                                  body: primaryMessage.body.resolve(locale),
                                  count: hubMessages.length,
                                  hasStack: hubMessages.length > 1,
                                  onTap: widget.onMessages == null
                                      ? null
                                      : () => unawaited(_openMessages()),
                                ),
                                const SizedBox(height: 12),
                              ],
                              const DpsgSectionHeader(label: 'Schnellzugriff'),
                              Card(
                                margin: EdgeInsets.zero,
                                child: Column(
                                  children: [
                                    _SettingsNavTile(
                                      icon: Icons.receipt_long_outlined,
                                      iconBackgroundColor: const Color(
                                        0xFF8E8E93,
                                      ),
                                      title: t.t('settings_quick_invoices'),
                                      subtitle: t.t(
                                        'settings_quick_placeholder',
                                      ),
                                    ),
                                    const _SettingsRowDivider(),
                                    _SettingsNavTile(
                                      icon: Icons.event_outlined,
                                      iconBackgroundColor: const Color(
                                        0xFF8E8E93,
                                      ),
                                      title: t.t('settings_quick_events'),
                                      subtitle: t.t(
                                        'settings_quick_placeholder',
                                      ),
                                    ),
                                    const _SettingsRowDivider(),
                                    _SettingsNavTile(
                                      icon: Icons.alternate_email,
                                      iconBackgroundColor: const Color(
                                        0xFF8E8E93,
                                      ),
                                      title: t.t(
                                        'settings_quick_subscriptions',
                                      ),
                                      subtitle: t.t(
                                        'settings_quick_placeholder',
                                      ),
                                    ),
                                    const _SettingsRowDivider(),
                                    _SettingsNavTile(
                                      icon: Icons.map,
                                      iconBackgroundColor: const Color(
                                        0xFF007AFF,
                                      ),
                                      title: t.t('settings_map'),
                                      subtitle: 'Stammes- und DV-Karte',
                                      onTap: widget.onMapSettings,
                                    ),
                                    const _SettingsRowDivider(),
                                    _SettingsNavTile(
                                      icon: Icons.verified_outlined,
                                      iconBackgroundColor: const Color(
                                        0xFF34C759,
                                      ),
                                      title: t.t('quali_titel'),
                                      subtitle: _qualiUntertitel(
                                        t,
                                        readModel,
                                        qualiEinstellungen,
                                      ),
                                      badge: qualiGesperrt
                                          ? t.t('quali_supporter_schild')
                                          : null,
                                      onTap: widget.onQualifikationen,
                                    ),
                                    if (!namiAiDecision.isHidden) ...[
                                      const _SettingsRowDivider(),
                                      _SettingsNavTile(
                                        icon: Icons.auto_awesome,
                                        iconBackgroundColor:
                                            namiAiDecision.isEnabled
                                            ? const Color(0xFF34C759)
                                            : const Color(0xFFFF9500),
                                        title: 'NaMi AI',
                                        subtitle: namiAiDecision.isEnabled
                                            ? 'AI-Chat (Test)'
                                            : 'Premium erforderlich',
                                        onTap: namiAiDecision.isEnabled
                                            ? widget.onNamiAi
                                            : widget.onNamiAiPaywall,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              const DpsgSectionHeader(label: 'Einstellungen'),
                              Card(
                                margin: EdgeInsets.zero,
                                child: Column(
                                  children: [
                                    _SettingsNavTile(
                                      icon: Icons.home,
                                      iconBackgroundColor:
                                          theme.colorScheme.primary,
                                      title: t.t('settings_stamm'),
                                      subtitle: 'Daten, Altersgrenzen',
                                      onTap: widget.onStammSettings,
                                    ),
                                    const _SettingsRowDivider(),
                                    _SettingsNavTile(
                                      icon: Icons.tune,
                                      iconBackgroundColor: const Color(
                                        0xFF34C759,
                                      ),
                                      title: t.t('settings_app'),
                                      subtitle: t.t('settings_app_hint'),
                                      onTap: widget.onAppSettings,
                                    ),
                                    const _SettingsRowDivider(),
                                    _SettingsNavTile(
                                      icon: Icons.palette_outlined,
                                      iconBackgroundColor: const Color(
                                        0xFFAF52DE,
                                      ),
                                      title: t.t('settings_appearance'),
                                      subtitle: t.t('settings_appearance_hint'),
                                      onTap: widget.onAppearanceSettings,
                                    ),
                                    const _SettingsRowDivider(),
                                    _SettingsNavTile(
                                      icon: Icons.notifications,
                                      iconBackgroundColor: const Color(
                                        0xFFFF9500,
                                      ),
                                      title: t.t('settings_notifications'),
                                      subtitle: 'Geburtstage, Erinnerungen',
                                      onTap: widget.onNotificationSettings,
                                    ),
                                  ],
                                ),
                              ),
                              if (widget.onDebugTools != null) ...[
                                const SizedBox(height: 12),
                                DpsgSectionHeader(
                                  label: t.t('settings_help_section'),
                                ),
                                Card(
                                  margin: EdgeInsets.zero,
                                  child: _SettingsNavTile(
                                    icon: Icons.help_outline,
                                    iconBackgroundColor:
                                        theme.colorScheme.tertiary,
                                    title: t.t('settings_help'),
                                    subtitle: t.t('settings_help_hint'),
                                    onTap: widget.onDebugTools,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 12),
                              const _SettingsRowDivider(indent: 16),
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: _handleTippleTapInTwoSeconds,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                    horizontal: 16,
                                  ),
                                  child: Column(
                                    children: [
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            t.t('developed_with'),
                                            style: theme.textTheme.bodySmall,
                                          ),
                                          const SizedBox(width: 4),
                                          Icon(
                                            Icons.favorite,
                                            size: 14,
                                            color: theme.colorScheme.error,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            t.t('developed_in_hamburg'),
                                            style: theme.textTheme.bodySmall,
                                          ),
                                        ],
                                      ),
                                      TextButton.icon(
                                        key: const Key('settings-legal-link'),
                                        onPressed: widget.onRechtliches,
                                        icon: const Icon(
                                          Icons.shield_outlined,
                                          size: 16,
                                        ),
                                        label: Text(t.t('legal_title')),
                                      ),
                                      Text(
                                        '${t.t('version_label')}: ${_appVersion ?? '...'}',
                                        style: theme.textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

class _SettingsMessagesBanner extends StatelessWidget {
  final String title;
  final String body;
  final int count;
  final bool hasStack;
  final VoidCallback? onTap;

  const _SettingsMessagesBanner({
    super.key,
    required this.title,
    required this.body,
    required this.count,
    required this.hasStack,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bannerBackground = isDark
        ? const Color(0xFF2A2010)
        : const Color(0xFFFFF8E1);
    final borderColor = isDark
        ? const Color(0xFF8A6A00)
        : const Color(0xFFFFB300);
    final textColor = isDark
        ? const Color(0xFFFFE7A3)
        : const Color(0xFF795B00);

    final banner = Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: bannerBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: textColor,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    key: const Key('settings-messages-badge'),
                    height: 20,
                    constraints: const BoxConstraints(minWidth: 20),
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCC1F2F),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$count',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 16,
                    color: borderColor,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      body,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: textColor,
                        height: 1.35,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    final showSecondLayer = count >= 2;
    final showFirstLayer = count >= 3;

    if (!showSecondLayer) {
      return banner;
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (showFirstLayer)
          Positioned(
            key: const Key('settings-messages-stack-back-2'),
            left: 12,
            right: 12,
            top: 8,
            bottom: -5,
            child: IgnorePointer(
              child: Opacity(
                opacity: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: bannerBackground,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                  ),
                ),
              ),
            ),
          ),
        Positioned(
          key: const Key('settings-messages-stack-back-1'),
          left: 6,
          right: 6,
          top: 4,
          bottom: 0,
          child: IgnorePointer(
            child: Opacity(
              opacity: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: bannerBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                ),
              ),
            ),
          ),
        ),

        Padding(padding: const EdgeInsets.only(bottom: 8), child: banner),
      ],
    );
  }
}

/// Profil als Seiten-Header: Avatar, Name mit Supporter-Badge, aktiver Layer
/// sowie Rechte und Rollen als Chips; oeffnet das Profil. Ohne Anmeldung ein
/// gesperrter Platzhalter.
class _SettingsProfileHeader extends StatelessWidget {
  const _SettingsProfileHeader({
    required this.background,
    required this.profile,
    required this.layerName,
    required this.badge,
    required this.onTap,
  });

  final AppearanceBackgroundId? background;
  final AuthProfile? profile;
  final String? layerName;
  final SupporterBadgeId? badge;
  final VoidCallback? onTap;

  static const double _avatarRadius = 18;
  static const double _avatarGap = 12;

  @override
  Widget build(BuildContext context) {
    final profile = this.profile;
    return AppPageHeader(
      background: background,
      card: AppPageHeaderCard(
        key: const Key('settings-profile-header'),
        onTap: onTap,
      ),
      primary: profile == null
          ? _buildLockedRow(context)
          : _buildProfileRow(context, profile),
      secondary: profile == null
          ? _buildLockedHint(context)
          : _ProfileChipRow(
              rechte: _rechte(profile),
              rollen: [for (final role in profile.roles) role.roleName],
            ),
    );
  }

  String _name(AuthProfile profile) =>
      profile.secondaryDisplayName ?? profile.primaryDisplayName;

  String? _rechte(AuthProfile profile) {
    final permissions = {for (final role in profile.roles) ...role.permissions};
    if (permissions.any((p) => p.endsWith('_full'))) {
      return 'Schreibrechte';
    }
    if (permissions.any((p) => p.endsWith('_read'))) {
      return 'Leserechte';
    }
    return null;
  }

  Widget _avatar(BuildContext context, {String? name}) {
    final theme = Theme.of(context);
    return CircleAvatar(
      radius: _avatarRadius,
      backgroundColor: theme.colorScheme.primary,
      child: name == null
          ? Icon(Icons.person, color: theme.colorScheme.onPrimary)
          : Text(
              name.isNotEmpty ? name.characters.first.toUpperCase() : '?',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
    );
  }

  Widget _chevron() =>
      Icon(onTap == null ? Icons.lock_outline : Icons.chevron_right);

  Widget _buildLockedRow(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Row(
      children: [
        _avatar(context),
        const SizedBox(width: _avatarGap),
        Expanded(
          child: Text(
            t.t('profile'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        _chevron(),
      ],
    );
  }

  Widget _buildLockedHint(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2 * _avatarRadius + _avatarGap),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'Arbeitskontext, Rollen und Konto',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    );
  }

  Widget _buildProfileRow(BuildContext context, AuthProfile profile) {
    final theme = Theme.of(context);
    final name = _name(profile);
    final badge = this.badge;
    return Row(
      children: [
        _avatar(context, name: name),
        const SizedBox(width: _avatarGap),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (badge != null) ...[
                    const SizedBox(width: 6),
                    SupporterBadge(badge: badge, size: 20),
                  ],
                ],
              ),
              Text(
                layerName ?? profile.email ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
        _chevron(),
      ],
    );
  }
}

/// Rechte und Rollen in genau einer Zeile: so viele Rollen, wie in die
/// Breite passen, der Rest als "+n". Es gibt keinen Umbruch, damit die
/// Header-Hoehe gleich bleibt.
class _ProfileChipRow extends StatelessWidget {
  const _ProfileChipRow({required this.rechte, required this.rollen});

  final String? rechte;
  final List<String> rollen;

  static const double _spacing = 6;
  static const double _hPadding = 8;
  static const double _iconSize = 14;
  static const double _iconGap = 4;

  /// Sehr lange Rollennamen werden gekuerzt statt die Zeile zu fuellen.
  static const double _maxRoleWidth = 160;

  @override
  Widget build(BuildContext context) {
    final rechte = this.rechte;
    if (rechte == null && rollen.isEmpty) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final style = theme.textTheme.labelSmall;
    final textScaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);

    double chipWidth(String label, {bool icon = false}) {
      final painter = TextPainter(
        text: TextSpan(text: label, style: style),
        maxLines: 1,
        textDirection: direction,
        textScaler: textScaler,
      )..layout();
      final width =
          2 * _hPadding + (icon ? _iconSize + _iconGap : 0) + painter.width;
      painter.dispose();
      return width;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Etwas Spielraum gegen Rundungsdifferenzen beim Layout.
        final available = constraints.maxWidth - 1;
        var used = rechte == null ? 0.0 : chipWidth(rechte, icon: true);
        var shown = 0;
        for (var i = 0; i < rollen.length; i++) {
          final width = chipWidth(rollen[i]).clamp(0.0, _maxRoleWidth);
          final rest = rollen.length - i - 1;
          final needed =
              used +
              (used > 0 ? _spacing : 0) +
              width +
              (rest > 0 ? _spacing + chipWidth('+$rest') : 0);
          if (needed > available) {
            break;
          }
          used += (used > 0 ? _spacing : 0) + width;
          shown++;
        }
        final weitere = rollen.length - shown;
        Widget limited(Widget chip, double maxWidth) => ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: chip,
        );
        final chips = <Widget>[
          if (rechte != null)
            limited(
              _chip(context, rechte, icon: Icons.key_outlined, accent: true),
              constraints.maxWidth,
            ),
          for (final rolle in rollen.take(shown))
            limited(_chip(context, rolle), _maxRoleWidth),
          if (weitere > 0)
            limited(_chip(context, '+$weitere'), constraints.maxWidth),
        ];
        // Die Chips behalten ihre gemessene Breite; nur bei extrem schmaler
        // Breite, wenn schon Rechte und "+n" nicht passen, wird abgeschnitten.
        return UnconstrainedBox(
          alignment: AlignmentDirectional.centerStart,
          constrainedAxis: Axis.vertical,
          clipBehavior: Clip.hardEdge,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < chips.length; i++) ...[
                if (i > 0) const SizedBox(width: _spacing),
                chips[i],
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _chip(
    BuildContext context,
    String label, {
    IconData? icon,
    bool accent = false,
  }) {
    final theme = Theme.of(context);
    final color = accent
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: _hPadding, vertical: 4),
      decoration: BoxDecoration(
        color: accent
            ? theme.colorScheme.primary.withValues(alpha: 0.12)
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: _iconSize, color: color),
            const SizedBox(width: _iconGap),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsRowDivider extends StatelessWidget {
  final double indent;
  const _SettingsRowDivider({this.indent = 68});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).dividerColor.withValues(alpha: 0.6);
    return Divider(height: 1, thickness: 1, indent: indent, color: color);
  }
}

/// Untertitel der Qualifikationen im Schnellzugriff: die angezeigten Arten.
String _qualiUntertitel(
  AppLocalizations t,
  ArbeitskontextReadModel? readModel,
  QualifikationsEinstellungen? einstellungen,
) {
  if (readModel == null) {
    return t.t('quali_schnellzugriff_leer');
  }
  final arten = const ErmittleQualifikationsUebersichtUseCase()
      .katalog(
        readModel: readModel,
        einstellungen: einstellungen ?? const QualifikationsEinstellungen(),
      )
      .where((eintrag) => eintrag.angezeigt)
      .map((eintrag) => eintrag.art.istEfz ? 'EFZ' : eintrag.art.label)
      .toList(growable: false);
  return arten.isEmpty ? t.t('quali_schnellzugriff_leer') : arten.join(', ');
}

class _SettingsNavTile extends StatelessWidget {
  final IconData icon;
  final Color iconBackgroundColor;
  final String title;
  final String? subtitle;
  final String? badge;
  final VoidCallback? onTap;

  const _SettingsNavTile({
    required this.icon,
    required this.iconBackgroundColor,
    required this.title,
    this.subtitle,
    this.badge,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: iconBackgroundColor.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Icon(icon, color: iconBackgroundColor, size: 20),
      ),
      title: Text(title, style: theme.textTheme.titleSmall),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (badge != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                badge!,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onTertiaryContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 6),
          ],
          Icon(
            onTap == null ? Icons.lock_outline : Icons.chevron_right,
            size: 20,
          ),
        ],
      ),
      enabled: onTap != null,
      onTap: onTap,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nami/domain/achievements/achievement_definition.dart';
import 'package:nami/domain/achievements/achievement_progress.dart';

import '../../l10n/app_localizations.dart';
import '../widgets/achievement_badge.dart';
import '../widgets/app_lesebreite.dart';
import '../widgets/achievement_tile.dart';
import '../widgets/achievement_visuals.dart';
import '../widgets/section_header.dart';

/// Übersicht aller Erfolge. Rein darstellend: bekommt die bereits gefilterten
/// Erfolge (nur verfügbare) von außen.
///
/// Offene Abzeichen mit Aktion sind antippbar und führen direkt dorthin:
/// "App bewertet" über [onRateApp] zur Bewertungsseite, "Mitgestalten" über
/// [onGiveFeedback] zum Feedback.
class AchievementsPage extends StatelessWidget {
  const AchievementsPage({
    super.key,
    required this.achievements,
    this.onRateApp,
    this.onGiveFeedback,
  });

  final List<AchievementProgress> achievements;
  final VoidCallback? onRateApp;
  final VoidCallback? onGiveFeedback;

  /// Aktion fuer ein noch offenes Abzeichen, sonst `null`.
  _OpenAction? _openActionFor(AchievementProgress achievement) {
    if (achievement.isUnlocked) {
      return null;
    }
    return switch (achievement.id) {
      AchievementIds.storeRating when onRateApp != null => _OpenAction(
        labelKey: 'achievements_store_rating_action',
        onTap: onRateApp!,
      ),
      AchievementIds.feedbackSent when onGiveFeedback != null => _OpenAction(
        labelKey: 'achievements_feedback_sent_action',
        onTap: onGiveFeedback!,
      ),
      _ => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final tiered = achievements.where((a) => !a.definition.isOneTime).toList();
    final special = achievements.where((a) => a.definition.isOneTime).toList();

    return Scaffold(
      appBar: AppBar(title: Text(t.t('achievements_title'))),
      body: SafeArea(
        child: AppLesebreite(
          builder: (context, rand) => ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24) + rand,
            children: [
              _AchievementsSummary(achievements: achievements),
              if (tiered.isNotEmpty) ...[
                const SizedBox(height: 16),
                DpsgSectionHeader(label: t.t('achievements_section_tiered')),
                Card(
                  margin: EdgeInsets.zero,
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      for (var i = 0; i < tiered.length; i++) ...[
                        if (i > 0) const Divider(height: 1, indent: 88),
                        AchievementTile(
                          key: Key('achievement-tile-${tiered[i].id}'),
                          achievement: tiered[i],
                          onTap: () =>
                              showAchievementDetailSheet(context, tiered[i]),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              if (special.isNotEmpty) ...[
                const SizedBox(height: 16),
                DpsgSectionHeader(label: t.t('achievements_section_special')),
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 8,
                    ),
                    child: Wrap(
                      alignment: WrapAlignment.spaceEvenly,
                      runSpacing: 16,
                      children: [
                        for (final a in special)
                          _SpecialAchievementCell(
                            key: Key('achievement-special-${a.id}'),
                            achievement: a,
                            openAction: _openActionFor(a),
                            onTap: () => showAchievementDetailSheet(context, a),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(
                    Icons.lock_outline,
                    size: 14,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      t.t('achievements_local_hint'),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AchievementsSummary extends StatelessWidget {
  const _AchievementsSummary({required this.achievements});

  final List<AchievementProgress> achievements;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context);
    final reached = achievements.fold<int>(0, (s, a) => s + a.reachedLevels);
    final total = achievements.fold<int>(
      0,
      (s, a) => s + a.definition.levelCount,
    );
    final highlight = _highestAchievement(achievements);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0B4A7F), Color(0xFF002544)],
        ),
      ),
      child: Row(
        children: [
          if (highlight != null)
            AchievementBadge.fromProgress(highlight, size: 76)
          else
            AchievementBadge(
              icon: Icons.emoji_events_rounded,
              size: 76,
              progress: 0,
            ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.t('achievements_summary', {
                    'reached': reached,
                    'total': total,
                  }),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  reached == 0
                      ? t.t('achievements_summary_empty')
                      : t.t('achievements_summary_hint'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: total == 0 ? 0 : reached / total,
                    minHeight: 6,
                    color: AchievementVisuals.paletteFor(
                      AchievementTier.gold,
                    ).base,
                    backgroundColor: Colors.white.withValues(alpha: 0.18),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  AchievementProgress? _highestAchievement(List<AchievementProgress> all) {
    AchievementProgress? best;
    for (final a in all.where((a) => a.isUnlocked)) {
      final tierIndex = a.currentTier?.index ?? -1;
      final bestIndex = best?.currentTier?.index ?? -1;
      if (best == null || tierIndex > bestIndex) {
        best = a;
      }
    }
    return best;
  }
}

class _OpenAction {
  const _OpenAction({required this.labelKey, required this.onTap});

  final String labelKey;
  final VoidCallback onTap;
}

class _SpecialAchievementCell extends StatelessWidget {
  const _SpecialAchievementCell({
    super.key,
    required this.achievement,
    this.openAction,
    this.onTap,
  });

  final AchievementProgress achievement;

  /// Ersetzt beim Antippen das Detail-Sheet und zeigt einen Hinweis.
  final _OpenAction? openAction;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context);
    final action = openAction;
    return InkWell(
      onTap: action?.onTap ?? onTap,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 96,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Column(
            children: [
              AchievementBadge.fromProgress(
                achievement,
                size: 72,
                showProgress: false,
              ),
              const SizedBox(height: 6),
              Text(
                AchievementVisuals.title(t, achievement.id),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: achievement.isUnlocked
                      ? null
                      : theme.colorScheme.onSurface.withValues(alpha: 0.55),
                ),
              ),
              if (action != null) ...[
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        t.t(action.labelKey),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      Icons.open_in_new,
                      size: 12,
                      color: theme.colorScheme.primary,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> showAchievementDetailSheet(
  BuildContext context,
  AchievementProgress achievement,
) {
  return showModalBottomSheet<void>(
    useRootNavigator: true,
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => AchievementDetailSheet(achievement: achievement),
  );
}

class AchievementDetailSheet extends StatelessWidget {
  const AchievementDetailSheet({super.key, required this.achievement});

  final AchievementProgress achievement;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context);
    final definition = achievement.definition;
    final dateFormat = DateFormat.yMd(
      Localizations.localeOf(context).toLanguageTag(),
    );

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AchievementBadge.fromProgress(achievement, size: 128),
            const SizedBox(height: 12),
            Text(
              AchievementVisuals.title(t, achievement.id),
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (achievement.currentTier != null) ...[
              const SizedBox(height: 6),
              AchievementTierChip(tier: achievement.currentTier!),
            ],
            const SizedBox(height: 16),
            if (definition.isOneTime)
              _DetailRow(
                badge: AchievementBadge.fromProgress(
                  achievement,
                  size: 44,
                  showProgress: false,
                ),
                title: AchievementVisuals.description(t, achievement.id, 1),
                subtitle: achievement.isUnlocked
                    ? _unlockedText(t, dateFormat, achievement.unlockedAt[0])
                    : t.t('achievements_locked'),
                reached: achievement.isUnlocked,
              )
            else
              for (final tier in AchievementTier.values)
                _DetailRow(
                  badge: AchievementBadge(
                    icon: AchievementVisuals.iconFor(achievement.id),
                    tier: tier.index < achievement.reachedLevels ? tier : null,
                    size: 44,
                  ),
                  title:
                      '${AchievementVisuals.tierLabel(t, tier)} · '
                      '${AchievementVisuals.description(t, achievement.id, definition.thresholds[tier.index])}',
                  subtitle: tier.index < achievement.reachedLevels
                      ? _unlockedText(
                          t,
                          dateFormat,
                          achievement.unlockedAt[tier.index],
                        )
                      : t.t('achievements_remaining', {
                          'count':
                              definition.thresholds[tier.index] -
                              achievement.count,
                        }),
                  reached: tier.index < achievement.reachedLevels,
                ),
          ],
        ),
      ),
    );
  }

  String _unlockedText(
    AppLocalizations t,
    DateFormat format,
    DateTime? unlockedAt,
  ) {
    if (unlockedAt == null) {
      return t.t('achievements_unlocked');
    }
    return t.t('achievements_unlocked_on', {'date': format.format(unlockedAt)});
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.badge,
    required this.title,
    required this.subtitle,
    required this.reached,
  });

  final Widget badge;
  final String title;
  final String subtitle;
  final bool reached;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.55);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          badge,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: reached ? null : muted,
                  ),
                ),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                ),
              ],
            ),
          ),
          if (reached)
            Icon(
              Icons.check_circle,
              size: 20,
              color: theme.colorScheme.primary,
            ),
        ],
      ),
    );
  }
}

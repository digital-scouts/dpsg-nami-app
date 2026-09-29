import 'package:flutter/material.dart';
import 'package:nami/domain/achievements/achievement_definition.dart';
import 'package:nami/domain/achievements/achievement_progress.dart';

import '../../l10n/app_localizations.dart';
import 'achievement_badge.dart';
import 'achievement_visuals.dart';

/// Listeneintrag für einen gestuften Erfolg mit Fortschritt zur nächsten Stufe.
class AchievementTile extends StatelessWidget {
  const AchievementTile({super.key, required this.achievement, this.onTap});

  final AchievementProgress achievement;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context);
    final current = achievement.currentTier;
    final next = achievement.nextTier;
    final nextThreshold = achievement.nextThreshold;
    final descriptionCount = achievement.isUnlocked && current != null
        ? achievement.definition.thresholds[current.index]
        : nextThreshold ?? achievement.count;
    final progressColor = next != null
        ? AchievementVisuals.paletteFor(next).base
        : theme.colorScheme.primary;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            AchievementBadge.fromProgress(achievement, size: 60),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          AchievementVisuals.title(t, achievement.id),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (current != null) ...[
                        const SizedBox(width: 8),
                        AchievementTierChip(tier: current),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    AchievementVisuals.description(
                      t,
                      achievement.id,
                      descriptionCount,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: achievement.progressToNext,
                      minHeight: 6,
                      color: progressColor,
                      backgroundColor: theme.colorScheme.onSurface.withValues(
                        alpha: 0.08,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    next != null && nextThreshold != null
                        ? t.t('achievements_progress_next', {
                            'count': achievement.count,
                            'next': nextThreshold,
                            'tier': AchievementVisuals.tierLabel(t, next),
                          })
                        : t.t('achievements_all_reached'),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 6),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class AchievementTierChip extends StatelessWidget {
  const AchievementTierChip({super.key, required this.tier});

  final AchievementTier tier;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = AchievementVisuals.paletteFor(tier);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [palette.light, palette.base]),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        AchievementVisuals.tierLabel(AppLocalizations.of(context), tier),
        style: theme.textTheme.labelSmall?.copyWith(
          color: palette.onColor,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:nami/domain/achievements/achievement_definition.dart';

import '../../l10n/app_localizations.dart';

/// Farbverlauf eines Abzeichens: hell (Glanz), Grundton, dunkel (Schatten)
/// und Vordergrundfarbe für Motiv und Stufenpunkte.
class AchievementPalette {
  const AchievementPalette({
    required this.light,
    required this.base,
    required this.dark,
    required this.onColor,
  });

  final Color light;
  final Color base;
  final Color dark;
  final Color onColor;
}

class AchievementVisuals {
  static AchievementPalette paletteFor(AchievementTier tier) => switch (tier) {
    AchievementTier.bronze => const AchievementPalette(
      light: Color(0xFFF2C08F),
      base: Color(0xFFCD7F32),
      dark: Color(0xFF7E4719),
      onColor: Colors.white,
    ),
    AchievementTier.silver => const AchievementPalette(
      light: Color(0xFFFAFAFD),
      base: Color(0xFFC0C0C8),
      dark: Color(0xFF74747F),
      onColor: Color(0xFF34343D),
    ),
    AchievementTier.gold => const AchievementPalette(
      light: Color(0xFFFFE89A),
      base: Color(0xFFE6B422),
      dark: Color(0xFF94690B),
      onColor: Color(0xFF4A3300),
    ),
    AchievementTier.platinum => const AchievementPalette(
      light: Color(0xFFEDE8FF),
      base: Color(0xFFA391E0),
      dark: Color(0xFF55449C),
      onColor: Color(0xFF221747),
    ),
    AchievementTier.diamond => const AchievementPalette(
      light: Color(0xFFF0FDFF),
      base: Color(0xFF7FD6F0),
      dark: Color(0xFF2A86AB),
      onColor: Color(0xFF07344A),
    ),
  };

  /// Einmalige Erfolge: DPSG-Blau mit goldenem Rand.
  static const specialDisc = AchievementPalette(
    light: Color(0xFF2F6FA8),
    base: Color(0xFF0B4A7F),
    dark: Color(0xFF002544),
    onColor: Colors.white,
  );

  static AchievementPalette get specialRim => paletteFor(AchievementTier.gold);

  static AchievementPalette lockedPalette(Brightness brightness) =>
      brightness == Brightness.dark
      ? const AchievementPalette(
          light: Color(0xFF2A2A34),
          base: Color(0xFF24242D),
          dark: Color(0xFF3A3A46),
          onColor: Color(0xFF5E5E6C),
        )
      : const AchievementPalette(
          light: Color(0xFFEDEDF1),
          base: Color(0xFFE8E8ED),
          dark: Color(0xFFD6D6DD),
          onColor: Color(0xFFB2B2BA),
        );

  static IconData iconFor(String id) => switch (id) {
    AchievementIds.appDays => Icons.local_fire_department_rounded,
    AchievementIds.memberEdited => Icons.edit_note_rounded,
    AchievementIds.statisticsOpened => Icons.insights_rounded,
    AchievementIds.memberCreated => Icons.person_add_alt_1_rounded,
    AchievementIds.stufenwechselDone => Icons.keyboard_double_arrow_up_rounded,
    AchievementIds.storeRating => Icons.star_rounded,
    AchievementIds.feedbackSent => Icons.forum_rounded,
    AchievementIds.supporter => Icons.volunteer_activism_rounded,
    _ => Icons.emoji_events_rounded,
  };

  static String tierLabel(AppLocalizations t, AchievementTier tier) =>
      t.t('achievements_tier_${tier.name}');

  static String title(AppLocalizations t, String id) =>
      t.t('achievements_${id}_title');

  /// Beschreibung für eine konkrete Schwelle, z. B. „An 10 Tagen …“.
  static String description(AppLocalizations t, String id, int count) {
    final oneKey = 'achievements_${id}_desc_one';
    if (count == 1 && t.t(oneKey) != oneKey) {
      return t.t(oneKey);
    }
    return t.t('achievements_${id}_desc', {'count': count});
  }
}

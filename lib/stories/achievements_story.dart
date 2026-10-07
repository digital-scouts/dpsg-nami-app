import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:nami/domain/achievements/achievement_definition.dart';
import 'package:nami/domain/achievements/achievement_progress.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/presentation/notifications/achievement_unlocked.dart';
import 'package:nami/presentation/screens/achievements_page.dart';
import 'package:nami/presentation/theme/theme.dart';
import 'package:nami/presentation/widgets/achievement_badge.dart';
import 'package:nami/presentation/widgets/achievement_visuals.dart';
// ignore: depend_on_referenced_packages
import 'package:storybook_flutter/storybook_flutter.dart';

Story achievementBadgeStory() => Story(
  name: 'Erfolge/Abzeichen/Einzeln',
  description: 'Ein Abzeichen mit allen Zuständen',
  builder: (context) {
    final knobs = context.knobs;
    final id = knobs.options<String>(
      label: 'Motiv',
      initial: AchievementIds.appDays,
      options: [
        for (final d in achievementCatalog) Option(label: d.id, value: d.id),
      ],
    );
    final state = knobs.options<String>(
      label: 'Zustand',
      initial: 'gold',
      options: const [
        Option(label: 'Gesperrt', value: 'locked'),
        Option(label: 'Bronze', value: 'bronze'),
        Option(label: 'Silber', value: 'silver'),
        Option(label: 'Gold', value: 'gold'),
        Option(label: 'Platin', value: 'platinum'),
        Option(label: 'Diamant', value: 'diamond'),
        Option(label: 'Einmalig', value: 'special'),
      ],
    );
    final progress = knobs.slider(
      label: 'Fortschritt (gesperrt)',
      initial: 0.4,
      min: 0,
      max: 1,
    );
    final size = knobs.slider(label: 'Größe', initial: 160, min: 32, max: 280);
    final dark = knobs.boolean(label: 'Dunkel', initial: false);
    final tier = AchievementTier.values
        .where((t) => t.name == state)
        .firstOrNull;

    return _AchievementStoryApp(
      dark: dark,
      home: Scaffold(
        body: Center(
          child: AchievementBadge(
            icon: AchievementVisuals.iconFor(id),
            tier: tier,
            special: state == 'special',
            progress: state == 'locked' ? progress : null,
            progressTier: AchievementTier.bronze,
            size: size,
          ),
        ),
      ),
    );
  },
);

Story achievementBadgeGalleryStory() => Story(
  name: 'Erfolge/Abzeichen/Übersicht',
  description: 'Alle Motive in allen Stufen zur Design-Freigabe',
  builder: (context) {
    final dark = context.knobs.boolean(label: 'Dunkel', initial: false);
    final size = context.knobs.slider(
      label: 'Größe',
      initial: 64,
      min: 32,
      max: 120,
    );
    return _AchievementStoryApp(
      dark: dark,
      home: Scaffold(body: _BadgeGallery(size: size)),
    );
  },
);

Story achievementsPageStory() => Story(
  name: 'Erfolge/Screens/Übersicht',
  builder: (context) {
    final knobs = context.knobs;
    final scenario = knobs.options<AchievementSampleScenario>(
      label: 'Szenario',
      initial: AchievementSampleScenario.mixed,
      options: const [
        Option(
          label: 'Neu installiert',
          value: AchievementSampleScenario.fresh,
        ),
        Option(label: 'Gemischt', value: AchievementSampleScenario.mixed),
        Option(
          label: 'Alles erreicht',
          value: AchievementSampleScenario.complete,
        ),
      ],
    );
    final includePrepared = knobs.boolean(
      label: 'Vorbereitete Erfolge zeigen',
      initial: false,
    );
    final locale = knobs.options<Locale>(
      label: 'Sprache',
      initial: const Locale('de'),
      options: const [
        Option(label: 'Deutsch', value: Locale('de')),
        Option(label: 'Englisch', value: Locale('en')),
      ],
    );
    final dark = knobs.boolean(label: 'Dunkel', initial: false);
    // iOS: "App bewertet" offen antippbar; Android: Abzeichen entfaellt.
    final platform = knobs.options<TargetPlatform>(
      label: 'Plattform',
      initial: TargetPlatform.iOS,
      options: const [
        Option(label: 'iOS', value: TargetPlatform.iOS),
        Option(label: 'Android', value: TargetPlatform.android),
      ],
    );

    return _AchievementStoryApp(
      dark: dark,
      locale: locale,
      home: AchievementsPage(
        achievements: achievementSampleProgress(
          scenario,
          includePrepared: includePrepared,
          platform: platform,
        ),
        onRateApp: platform == TargetPlatform.iOS ? () {} : null,
        onGiveFeedback: () {},
      ),
    );
  },
);

Story achievementDetailSheetStory() => Story(
  name: 'Erfolge/Screens/Detail',
  builder: (context) {
    final id = context.knobs.options<String>(
      label: 'Erfolg',
      initial: AchievementIds.appDays,
      options: [
        for (final d in achievementCatalog) Option(label: d.id, value: d.id),
      ],
    );
    final dark = context.knobs.boolean(label: 'Dunkel', initial: false);
    final achievement = achievementSampleProgress(
      AchievementSampleScenario.mixed,
      includePrepared: true,
    ).firstWhere((a) => a.id == id);

    return _AchievementStoryApp(
      dark: dark,
      home: Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: Material(
            elevation: 2,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: Padding(
              padding: const EdgeInsets.only(top: 24),
              child: AchievementDetailSheet(achievement: achievement),
            ),
          ),
        ),
      ),
    );
  },
);

Story achievementUnlockedStory() => Story(
  name: 'Erfolge/Freischaltung',
  description:
      'Konfetti immer, Bronze/Silber als Snackbar, ab Gold und einmalige '
      'Erfolge als Dialog',
  builder: (context) {
    final knobs = context.knobs;
    final id = knobs.options<String>(
      label: 'Erfolg',
      initial: AchievementIds.memberEdited,
      options: [
        for (final d in achievementCatalog) Option(label: d.id, value: d.id),
      ],
    );
    final tierName = knobs.options<String>(
      label: 'Stufe',
      initial: 'gold',
      options: const [
        Option(label: 'Bronze', value: 'bronze'),
        Option(label: 'Silber', value: 'silver'),
        Option(label: 'Gold', value: 'gold'),
        Option(label: 'Platin', value: 'platinum'),
        Option(label: 'Diamant', value: 'diamond'),
      ],
    );
    final dark = knobs.boolean(label: 'Dunkel', initial: false);
    final definition = achievementCatalog.firstWhere((d) => d.id == id);
    final tier = definition.isOneTime
        ? null
        : AchievementTier.values.firstWhere((t) => t.name == tierName);

    return _AchievementStoryApp(
      dark: dark,
      home: _UnlockedPreview(definition: definition, tier: tier),
    );
  },
);

class _AchievementStoryApp extends StatelessWidget {
  const _AchievementStoryApp({
    required this.home,
    required this.dark,
    this.locale = const Locale('de'),
  });

  final Widget home;
  final bool dark;
  final Locale locale;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: dark ? darkTheme : lightTheme,
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('de'), Locale('en')],
      locale: locale,
      home: home,
    );
  }
}

class _BadgeGallery extends StatelessWidget {
  const _BadgeGallery({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context);
    final tiered = achievementCatalog.where((d) => !d.isOneTime);
    final special = achievementCatalog.where((d) => d.isOneTime);
    final label = theme.textTheme.labelSmall;

    Widget cell(Widget child) => Padding(
      padding: const EdgeInsets.all(6),
      child: SizedBox.square(dimension: size, child: child),
    );

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        scrollDirection: Axis.vertical,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SizedBox(width: 150, child: Text('Motiv', style: label)),
                  for (final h in [
                    'Gesperrt',
                    for (final tier in AchievementTier.values)
                      AchievementVisuals.tierLabel(t, tier),
                  ])
                    SizedBox(
                      width: size + 12,
                      child: Text(h, textAlign: TextAlign.center, style: label),
                    ),
                ],
              ),
              for (final d in tiered)
                Row(
                  children: [
                    SizedBox(
                      width: 150,
                      child: Text(
                        '${AchievementVisuals.title(t, d.id)}'
                        '${d.available ? '' : ' (vorbereitet)'}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    cell(
                      AchievementBadge(
                        icon: AchievementVisuals.iconFor(d.id),
                        progress: 0.4,
                        progressTier: AchievementTier.bronze,
                        size: size,
                      ),
                    ),
                    for (final tier in AchievementTier.values)
                      cell(
                        AchievementBadge(
                          icon: AchievementVisuals.iconFor(d.id),
                          tier: tier,
                          size: size,
                        ),
                      ),
                  ],
                ),
              const SizedBox(height: 16),
              Text('Einmalige Erfolge', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (final d in special) ...[
                    Column(
                      children: [
                        Row(
                          children: [
                            cell(
                              AchievementBadge(
                                icon: AchievementVisuals.iconFor(d.id),
                                size: size,
                              ),
                            ),
                            cell(
                              AchievementBadge(
                                icon: AchievementVisuals.iconFor(d.id),
                                special: true,
                                size: size,
                              ),
                            ),
                          ],
                        ),
                        Text(AchievementVisuals.title(t, d.id), style: label),
                      ],
                    ),
                    const SizedBox(width: 16),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UnlockedPreview extends StatelessWidget {
  const _UnlockedPreview({required this.definition, required this.tier});

  final AchievementDefinition definition;
  final AchievementTier? tier;

  @override
  Widget build(BuildContext context) {
    final celebration = isAchievementCelebration(tier);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FilledButton.icon(
              onPressed: () => showAchievementUnlocked(
                context,
                definition: definition,
                tier: tier,
                onShowAll: () {},
              ),
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(
                celebration
                    ? 'Live auslösen (Dialog)'
                    : 'Live auslösen (Snackbar)',
              ),
            ),
            const SizedBox(height: 24),
            Text('Snackbar', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            AchievementUnlockedSnackbarContent(
              definition: definition,
              tier: tier,
            ),
            const SizedBox(height: 24),
            Text('Dialog', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            SizedBox(
              height: 520,
              child: AchievementUnlockedDialog(
                definition: definition,
                tier: tier,
                onShowAll: () {},
                showConfetti: false,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Beispiel-Fortschritt, auch fuer die Store-Szenen.
enum AchievementSampleScenario { fresh, mixed, complete }

/// Mit [platform] entfallen Erfolge, die dort nicht vorgesehen sind.
List<AchievementProgress> achievementSampleProgress(
  AchievementSampleScenario scenario, {
  required bool includePrepared,
  TargetPlatform? platform,
}) {
  final base = DateTime(2026, 9, 1);
  const mixedCounts = {
    AchievementIds.appDays: 27,
    AchievementIds.memberEdited: 7,
    AchievementIds.statisticsOpened: 4,
    AchievementIds.memberCreated: 0,
    AchievementIds.stufenwechselDone: 2,
    AchievementIds.storeRating: 1,
    AchievementIds.feedbackSent: 0,
    AchievementIds.supporter: 0,
  };

  return [
    for (final d in achievementCatalog)
      if ((d.available || includePrepared) &&
          (platform == null || (d.platforms?.contains(platform) ?? true)))
        () {
          final count = switch (scenario) {
            AchievementSampleScenario.fresh => 0,
            AchievementSampleScenario.mixed => mixedCounts[d.id] ?? 0,
            AchievementSampleScenario.complete =>
              d.isOneTime ? 1 : d.thresholds.last,
          };
          final probe = AchievementProgress(definition: d, count: count);
          return AchievementProgress(
            definition: d,
            count: count,
            unlockedAt: {
              for (var i = 0; i < probe.reachedLevels; i++)
                i: base.add(Duration(days: i * 9)),
            },
          );
        }(),
  ];
}

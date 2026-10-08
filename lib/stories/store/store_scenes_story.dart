import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:nami/data/appearance/in_memory_appearance_settings_repository.dart';
import 'package:nami/domain/appearance/appearance_catalog.dart';
import 'package:nami/domain/appearance/appearance_settings.dart';
import 'package:nami/domain/appearance/support_access.dart';
import 'package:nami/domain/bundesstatistik/stammes_snapshot.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/presentation/model/appearance_model.dart';
import 'package:nami/presentation/model/bundesstatistik_model.dart';
import 'package:nami/presentation/navigation/app_router.dart';
import 'package:nami/presentation/screens/achievements_page.dart';
import 'package:nami/presentation/screens/bundesvergleich_page.dart';
import 'package:nami/presentation/screens/member_detail_page.dart';
import 'package:nami/presentation/screens/settings_appearance_page.dart';
import 'package:nami/presentation/screens/settings_map_page.dart';
import 'package:nami/presentation/theme/theme.dart';
import 'package:nami/presentation/widgets/app_bottom_navigation.dart';
import 'package:nami/services/app_icon_service.dart';
import 'package:provider/provider.dart';
// ignore: depend_on_referenced_packages
import 'package:storybook_flutter/storybook_flutter.dart';

import '../achievements_story.dart';
import '../bundesstatistik_story.dart';
import '../member_people_page_story.dart';
import '../settings_stufenwechsel_story.dart';
import '../statistics_page_story.dart';
import 'store_showcase_data.dart';

/// Vollbild-Szenen fuer Store-Screenshots.
///
/// Die Namen sind stabil: `integration_test/store_screenshots_test.dart`
/// leitet daraus die Dateinamen der Rohscreens ab
/// (`Store/Erscheinungsbild/Dunkel` -> `erscheinungsbild_dunkel.png`).
List<Story> storeSceneStories() => <Story>[
  storeMitgliederStory(),
  storeMitgliedDetailStory(),
  storeStatistikStory(),
  storeBundesvergleichStory(),
  storeStufenwechselStory(),
  storeErfolgeStory(),
  storeErscheinungsbildStory(),
  storeErscheinungsbildDunkelStory(),
  storeKarteStory(),
];

/// Erscheinungsbild der Mitgliederliste: animierter Hintergrund und eigenes
/// Supporter-Badge.
const AppearanceSettings storeShowcaseAppearance = AppearanceSettings(
  background: AppearanceBackgroundId.waldsee,
  badge: SupporterBadgeId.kompassPfadfinder,
);

Story storeMitgliederStory() => Story(
  name: 'Store/Mitglieder',
  builder: (context) => MemberPeopleStoryShell(
    readModel: StoreShowcaseData.readModel(),
    appearance: storeShowcaseAppearance,
    themeMode: ThemeMode.light,
    bottomNavigationBar: const AppBottomNavigation(currentIndex: 0),
  ),
);

Story storeMitgliedDetailStory() => Story(
  name: 'Store/Mitgliedsdetail',
  builder: (context) => StoreSceneApp(
    home: MemberDetailPage(mitglied: StoreShowcaseData.featuredMitglied()),
  ),
);

Story storeStatistikStory() => Story(
  name: 'Store/Statistik',
  builder: (context) => StatisticsPageStoryScene(
    background: storeShowcaseAppearance.background,
    simulateTopInset: false,
  ),
);

Story storeBundesvergleichStory() => Story(
  name: 'Store/Bundesvergleich',
  builder: (context) => StoreSceneApp(
    home: Scaffold(
      appBar: AppBar(title: const Text('Bundesweiter Vergleich')),
      body: BundesvergleichView(
        status: BundesstatistikStatus.bereit,
        hatEinwilligung: true,
        aggregat: bundesstatistikBeispielAggregat,
        eigeneKennzahlen: bundesstatistikBeispielKennzahlen,
        einwilligungAm: DateTime(2026, 6, 1),
        zuletztGesendet: StammesSnapshot(
          stammId: '${StoreShowcaseData.layerId}',
          senderId: 'installation',
          sentAt: DateTime(2026, 6, 14, 18, 5),
          sourceDataAsOf: DateTime(2026, 6, 14, 18),
          kennzahlen: bundesstatistikBeispielKennzahlen,
        ),
        onEinwilligungAendern: (_) {},
      ),
    ),
  ),
);

Story storeStufenwechselStory() => Story(
  name: 'Store/Stufenwechsel',
  builder: (context) => StufenwechselPageStoryScene(
    background: storeShowcaseAppearance.background,
    simulateTopInset: false,
  ),
);

Story storeErfolgeStory() => Story(
  name: 'Store/Erfolge',
  builder: (context) => StoreSceneApp(
    home: AchievementsPage(
      achievements: achievementSampleProgress(
        AchievementSampleScenario.mixed,
        includePrepared: false,
      ),
    ),
  ),
);

/// Supporter-Optionen mit Schloss: zeigt, dass Kaeufe nur das Aussehen
/// betreffen und alle Funktionen frei bleiben.
Story storeErscheinungsbildStory() => Story(
  name: 'Store/Erscheinungsbild',
  builder: (context) => const _ErscheinungsbildScene(dark: false),
);

/// Gegenstueck zu [storeErscheinungsbildStory] fuer den Hell-/Dunkel-Vergleich.
Story storeErscheinungsbildDunkelStory() => Story(
  name: 'Store/Erscheinungsbild/Dunkel',
  builder: (context) => const _ErscheinungsbildScene(dark: true),
);

Story storeKarteStory() => Story(
  name: 'Store/Karte',
  builder: (context) => const StoreSceneApp(home: SettingsMapPage()),
);

class _ErscheinungsbildScene extends StatelessWidget {
  const _ErscheinungsbildScene({required this.dark});

  final bool dark;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AppearanceModel>(
      create: (_) => AppearanceModel(
        repository: InMemoryAppearanceSettingsRepository(),
        appIconService: FakeAppIconService(),
        access: const SchalterSupportAccess(SupporterTestZugang.keiner),
      )..load(),
      child: StoreSceneApp(
        dark: dark,
        home: SettingsAppearancePage(
          themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        ),
      ),
    );
  }
}

class StoreSceneApp extends StatelessWidget {
  const StoreSceneApp({super.key, required this.home, this.dark = false});

  final Widget home;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      onGenerateRoute: onGenerateRoute,
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        AppLocalizations.delegate,
      ],
      supportedLocales: const [Locale('de'), Locale('en')],
      locale: const Locale('de'),
      home: home,
    );
  }
}

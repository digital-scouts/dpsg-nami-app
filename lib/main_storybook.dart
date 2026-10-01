import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/stories/achievements_story.dart';
import 'package:nami/stories/app_bottom_navigation_story.dart';
import 'package:nami/stories/app_sidebar_story.dart';
import 'package:nami/stories/app_snackbar_story.dart';
import 'package:nami/stories/feedback_prompt_dialog_story.dart';
import 'package:nami/stories/message_of_the_day_card_story.dart';
import 'package:nami/stories/nami_ai_chat_page_story.dart';
import 'package:nami/stories/notifications_story.dart';
import 'package:nami/stories/profile_page_story.dart';
import 'package:nami/stories/settings_map_page_story.dart';
import 'package:nami/stories/settings_page_story.dart';
import 'package:nami/stories/settings_stamm_address_story.dart';
import 'package:nami/stories/settings_stufenwechsel_story.dart';
import 'package:nami/stories/stufen_choice_chips_story.dart';
import 'package:nami/stories/stufenwechsel_empfehlung_story.dart';
import 'package:nami/stories/stufenwechsel_timeline_story.dart';
// ignore: depend_on_referenced_packages
import 'package:storybook_flutter/storybook_flutter.dart';

import 'presentation/theme/theme.dart';
import 'stories/appearance_story.dart';
import 'stories/confetti_overlay_story.dart';
import 'stories/member_basis_info_card_story.dart';
import 'stories/member_basis_story.dart';
import 'stories/member_detail_page_story.dart';
import 'stories/member_edit_resolution_story.dart';
import 'stories/member_list_directory_story.dart';
import 'stories/member_list_group_filter_bar_story.dart';
import 'stories/member_list_search_bar_story.dart';
import 'stories/bundesstatistik_story.dart';
import 'stories/member_list_story.dart';
import 'stories/member_list_tile_story.dart';
import 'stories/member_people_page_story.dart';
import 'stories/member_roles_list_story.dart';
import 'stories/member_roles_list_tile_story.dart';
import 'stories/member_roles_recommendation_tile_story.dart';
import 'stories/member_roles_statistik_pie_story.dart';
import 'stories/statistics_page_story.dart';
import 'stories/statistik_age_distribution_story.dart';
import 'stories/statistik_group_distribution_story.dart';
import 'stories/statistik_bearbeiten_story.dart';
import 'stories/statistik_kacheln_story.dart';
import 'stories/store/store_scenes_story.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('de');
  runApp(const StorybookEntry());
}

List<Story> buildStorybookStories() {
  return [
    achievementBadgeStory(),
    achievementBadgeGalleryStory(),
    achievementsPageStory(),
    achievementDetailSheetStory(),
    achievementUnlockedStory(),
    appBottomNavigationStory(),
    appSidebarStory(),
    appSnackbarStory(),
    feedbackPromptDialogStory(),
    notificationsListStory(),
    storyMessageOfTheDayCard(),
    confettiOverlayStory(),
    namiAiChatPageEmptyStory(),
    namiAiChatPageWithSourcesStory(),
    namiAiChatPageUnclearStory(),
    namiAiChatPageStreamingStory(),
    namiAiChatPageErrorStory(),
    namiAiChatHistoryListEmptyStory(),
    namiAiChatHistoryListFilledStory(),
    namiAiChatHistoryDetailStory(),
    memberPeoplePageLoadedStory(),
    memberPeoplePageEmptyStory(),
    memberDetailPageStory(),
    memberEditResolutionServerConflictStory(),
    memberEditResolutionServerValidationStory(),
    memberEditResolutionMixedFieldsStory(),
    memberListStory(),
    memberListTileStory(),
    memberListSearchBarStory(),
    groupFilterStory(),
    memberDirectoryStory(),
    memberDetailsStory(),
    memberGeneralInfoCardStory(),
    memberMembershipInfoCardStory(),
    memberRolesListStory(),
    memberRolesListTileStory(),
    memberRolesRecommendationTileStory(),
    memberRolesPieNurMitgliedStory(),
    memberRolesPieNurLeitungStory(),
    memberRolesPieMitgliedUndLeitungStory(),
    memberRolesPieNurEineStufeStory(),
    memberRolesPieMaxStory(),
    memberRolesPieUeberlappStory(),
    profilePageStory(),
    profilePageWithoutNicknameStory(),
    profilePageUnknownLanguageStory(),
    settingsPageStory(),
    appSettingsPageStory(),
    appSettingsPageEnglishStory(),
    settingsAppearancePageStory(),
    supporterBackgroundStory(),
    supporterBadgeStory(),
    settingsNotificationPageStory(),
    settingsNotificationPageDisabledStory(),
    settingsMapPageStory(),
    buildSettingsStammPageStory(),
    stammAddressSettingsStory(),
    stufenwechselSettingsStory(),
    stufenwechselSettingsMinMaxStory(),
    stufenwechselPageStory(),
    statisticsPageStory(),
    statisticsGroupDetailStory(),
    statistikKachelnGalerieStory(),
    ...statistikBearbeitenStories(),
    ageDistributionStory(),
    groupDistributionStory(),
    bundesvergleichStory(),
    bundesstatistikEinwilligungStory(),
    stufenChoiceChipsStory(),
    stufenwechselTimelineStory(),
    stufenwechselEmpfehlungStory(),
    ...storeSceneStories(),
  ];
}

class StorybookEntry extends StatelessWidget {
  const StorybookEntry({super.key, this.stories});

  final List<Story>? stories;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: ThemeMode.system,
      home: Storybook(
        stories: stories ?? buildStorybookStories(),
        wrapperBuilder: _storyWrapper,
      ),
    );
  }
}

/// Wie der Standard-Wrapper von Storybook, aber mit App-Theme und
/// App-Uebersetzungen, damit Widgets mit [AppLocalizations] auch ohne eigene
/// MaterialApp in der Story funktionieren.
Widget _storyWrapper(BuildContext context, Widget? child) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: lightTheme,
  darkTheme: darkTheme,
  themeMode: ThemeMode.system,
  localizationsDelegates: [
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    AppLocalizations.delegate,
  ],
  supportedLocales: const [Locale('de'), Locale('en')],
  locale: const Locale('de'),
  home: Scaffold(body: Center(child: child)),
);

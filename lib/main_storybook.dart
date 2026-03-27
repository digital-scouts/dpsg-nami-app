import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:nami/stories/app_bottom_navigation_story.dart';
import 'package:nami/stories/app_sidebar_story.dart';
import 'package:nami/stories/message_of_the_day_card_story.dart';
import 'package:nami/stories/notifications_story.dart';
import 'package:nami/stories/profile_page_story.dart';
import 'package:nami/stories/settings_page_story.dart';
import 'package:nami/stories/settings_stamm_address_story.dart';
import 'package:nami/stories/settings_stufenwechsel_story.dart';
import 'package:nami/stories/stufen_choice_chips_story.dart';
import 'package:nami/stories/stufenwechsel_empfehlung_story.dart';
import 'package:nami/stories/stufenwechsel_timeline_story.dart';
// ignore: depend_on_referenced_packages
import 'package:storybook_flutter/storybook_flutter.dart';

import 'presentation/theme/theme.dart';
import 'stories/confetti_overlay_story.dart';
import 'stories/member_basis_info_card_story.dart';
import 'stories/member_basis_story.dart';
import 'stories/member_list_directory_story.dart';
import 'stories/member_list_group_filter_bar_story.dart';
import 'stories/member_list_search_bar_story.dart';
import 'stories/member_list_story.dart';
import 'stories/member_list_tile_story.dart';
import 'stories/member_people_page_story.dart';
import 'stories/member_roles_list_story.dart';
import 'stories/member_roles_list_tile_story.dart';
import 'stories/member_roles_recommendation_tile_story.dart';
import 'stories/member_roles_statistik_pie_story.dart';
import 'stories/statistik_age_distribution_story.dart';
import 'stories/statistik_group_distribution_story.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('de');
  runApp(const StorybookEntry());
}

class StorybookEntry extends StatelessWidget {
  const StorybookEntry({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: ThemeMode.system,
      home: Storybook(
        stories: [
          memberListTileStory(),
          memberGeneralInfoCardStory(),
          memberMembershipInfoCardStory(),
          memberDetailsStory(),
          memberPeoplePageLoadedStory(),
          memberPeoplePageEmptyStory(),
          memberListStory(),
          memberRolesListTileStory(),
          memberRolesRecommendationTileStory(),
          memberRolesListStory(),
          memberRolesPieNurMitgliedStory(),
          memberRolesPieNurLeitungStory(),
          memberRolesPieMitgliedUndLeitungStory(),
          memberRolesPieNurEineStufeStory(),
          memberRolesPieMaxStory(),
          memberRolesPieUeberlappStory(),
          ageDistributionStory(),
          groupDistributionStory(),
          groupFilterStory(),
          memberListSearchBarStory(),
          memberDirectoryStory(),
          stufenwechselEmpfehlungStory(),
          stufenChoiceChipsStory(),
          stufenwechselTimelineStory(),
          appSidebarStory(),
          appBottomNavigationStory(),
          profilePageStory(),
          profilePageWithoutNicknameStory(),
          profilePageUnknownLanguageStory(),
          settingsPageStory(),
          appSettingsPageStory(),
          appSettingsPageEnglishStory(),
          settingsNotificationPageStory(),
          settingsNotificationPageDisabledStory(),
          buildSettingsStammPageStory(),
          stammAddressSettingsStory(),
          stufenwechselSettingsStory(),
          notificationsListStory(),
          storyMessageOfTheDayCard(),
          confettiOverlayStory(),
          Story(
            name: 'App/ThemeToggleInfo',
            builder: (context) => Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Aktuelles Brightness: ${Theme.of(context).brightness.name}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Um das Theme zu wechseln, ändere den System-Dark-Mode oder erweitere Storybook mit einem eigenen Theme-Mode-Knob.',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

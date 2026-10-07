import 'package:flutter/material.dart';
import 'package:nami/presentation/widgets/hitobito_traffic_log_view.dart';
// ignore: depend_on_referenced_packages
import 'package:storybook_flutter/storybook_flutter.dart';

const String _felder =
    'fields[people]=first_name,last_name,nickname&fields[roles]=created_at,name'
    '&include=roles,phone_numbers,additional_emails,additional_addresses';

/// Synthetische Zeilen im Format von HitobitoTrafficLogService.
const String hitobitoTrafficStoryContent =
    '''
[2026-10-07 10:02:11] GET 200 groups https://hitobito.example/api/groups?page[size]=1000&sort=id&page[number]=1
[2026-10-07 10:02:13] GET 200 people https://hitobito.example/api/people?filter[primary_group_id]=12&page[size]=500&page[number]=1&$_felder
[2026-10-07 10:02:15] GET 200 roles https://hitobito.example/api/roles?filter[person_id][eq]=101,102,103&page[size]=500
[2026-10-07 10:02:16] GET 200 qualifications https://hitobito.example/api/qualifications?include=qualification_kind&page[number]=1
[2026-10-07 10:02:17] GET 500 efz_einsichtnahmen https://hitobito.example/api/efz_einsichtnahmen?sort=-issued_on&page[number]=3
[2026-10-07 10:15:40] GET 200 people https://hitobito.example/api/people/2817?$_felder
[2026-10-07 10:15:52] PATCH 422 people https://hitobito.example/api/people/2817
[2026-10-07 10:20:03] GET exception:ClientException groups https://hitobito.example/api/groups?page[size]=1000&sort=id&page[number]=1
[2026-10-07 10:20:33] GET 401 people https://hitobito.example/api/people?filter[primary_group_id]=12&page[size]=500&page[number]=1&$_felder''';

Story hitobitoTrafficLogViewStory() {
  return Story(
    name: 'Einstellungen/Screens/Hitobito-Traffic',
    builder: (context) {
      final leer = context.knobs.boolean(label: 'Leer', initial: false);
      return Scaffold(
        appBar: AppBar(title: const Text('Hitobito-Traffic')),
        body: HitobitoTrafficLogView(
          content: leer ? '' : hitobitoTrafficStoryContent,
        ),
      );
    },
  );
}

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nami/data/member_filters/shared_prefs_member_filter_repository.dart';
import 'package:nami/domain/member/member_list_preferences.dart';
import 'package:nami/domain/member_filters/member_custom_filter.dart';
import 'package:nami/domain/member_filters/member_filter_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SharedPrefsMemberFilterRepository', () {
    test('loads defaults for an empty layer', () async {
      SharedPreferences.setMockInitialValues({});
      final repository = SharedPrefsMemberFilterRepository();

      final settings = await repository.loadForLayer(11);

      expect(settings.sortKey, MemberSortKey.name);
      expect(settings.subtitleMode, MemberSubtitleMode.mitgliedsnummer);
      expect(settings.customGroups, isEmpty);
      expect(settings.defaultsInitialisiert, isFalse);
    });

    test('persists and loads layer specific settings', () async {
      SharedPreferences.setMockInitialValues({});
      final repository = SharedPrefsMemberFilterRepository();
      const settings = MemberFilterLayerSettings(
        sortKey: MemberSortKey.vorname,
        subtitleMode: MemberSubtitleMode.spitzname,
        defaultsInitialisiert: true,
        customGroups: <MemberCustomFilterGroup>[
          MemberCustomFilterGroup(
            id: 'rest',
            shortLabel: 'Rest',
            isActive: false,
            logic: MemberCustomFilterLogic.oder,
            rules: <MemberCustomFilterRule>[
              MemberCustomFilterRule(
                operator: MemberCustomFilterRuleOperator.hatNicht,
                criterion: MemberCustomFilterCriterion.stufe(),
              ),
            ],
          ),
        ],
      );

      await repository.saveForLayer(11, settings);

      final loaded = await repository.loadForLayer(11);

      expect(loaded, settings);
    });

    test('loads legacy keine-stufe rules as hat nicht stufe', () async {
      SharedPreferences.setMockInitialValues({
        'memberFilterLayerSettings:11': jsonEncode({
          'sortKey': 'name',
          'subtitleMode': 'mitgliedsnummer',
          'defaultsInitialisiert': true,
          'customGroups': [
            {
              'id': 'rest',
              'shortLabel': 'Rest',
              'isActive': true,
              'logic': 'oder',
              'rules': [
                {
                  'operator': 'hat',
                  'criterion': {'type': 'keineStufe'},
                },
              ],
            },
          ],
        }),
      });
      final repository = SharedPrefsMemberFilterRepository();

      final loaded = await repository.loadForLayer(11);

      expect(
        loaded.customGroups.single.rules.single,
        const MemberCustomFilterRule(
          operator: MemberCustomFilterRuleOperator.hatNicht,
          criterion: MemberCustomFilterCriterion.stufe(),
        ),
      );
    });
  });
}

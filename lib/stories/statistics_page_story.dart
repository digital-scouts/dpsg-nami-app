import 'package:flutter/material.dart';
import 'package:nami/domain/appearance/appearance_catalog.dart';
import 'package:nami/presentation/model/bundesstatistik_model.dart';
import 'package:nami/presentation/screens/statistics_group_detail_page.dart';
import 'package:nami/presentation/screens/statistics_page.dart';
import 'package:nami/stories/bundesstatistik_story.dart';
import 'package:nami/stories/store/store_showcase_data.dart';
import 'package:nami/stories/story_tab_shell.dart';
import 'package:provider/provider.dart';
// ignore: depend_on_referenced_packages
import 'package:storybook_flutter/storybook_flutter.dart';

Story statisticsPageStory() {
  return Story(
    name: 'Statistik/Seite/Uebersicht',
    builder: (context) {
      final background = storyHeaderBackgroundKnob(context.knobs);
      final dark = context.knobs.boolean(label: 'Dunkel', initial: false);
      final bundesweit = context.knobs.options<StoryBundesstatistikSzenario>(
        label: 'Bundesweit',
        initial: StoryBundesstatistikSzenario.optIn,
        options: [
          for (final szenario in StoryBundesstatistikSzenario.values)
            Option(label: szenario.label, value: szenario),
        ],
      );
      final loading = context.knobs.boolean(
        label: 'Mit Lade-Info',
        initial: false,
      );
      return StatisticsPageStoryScene(
        background: background,
        dark: dark,
        bundesstatistik: bundesweit,
        showLoadingInfo: loading,
      );
    },
  );
}

/// Statistik-Tab wie in der App, mit Beispieldaten und einer Bundesstatistik
/// ohne Server im gewaehlten Zustand.
class StatisticsPageStoryScene extends StatelessWidget {
  const StatisticsPageStoryScene({
    super.key,
    required this.background,
    this.dark = false,
    this.bundesstatistik = StoryBundesstatistikSzenario.optIn,
    this.showLoadingInfo = false,
    this.simulateTopInset = true,
  });

  final AppearanceBackgroundId? background;
  final bool dark;
  final StoryBundesstatistikSzenario bundesstatistik;
  final bool showLoadingInfo;
  final bool simulateTopInset;

  @override
  Widget build(BuildContext context) {
    final readModel = StoreShowcaseData.readModel();
    return StoryTabPage(
      key: ValueKey('$background-$dark-$bundesstatistik-$showLoadingInfo'),
      tabIndex: 1,
      background: background,
      dark: dark,
      showLoadingInfo: showLoadingInfo,
      simulateTopInset: simulateTopInset,
      providers: [
        ChangeNotifierProvider<BundesstatistikModel>(
          create: (_) =>
              storyBundesstatistikModel(readModel, szenario: bundesstatistik),
        ),
      ],
      child: StatisticsPage(debugReadModel: readModel),
    );
  }
}

Story statisticsGroupDetailStory() {
  return Story(
    name: 'Statistik/Seite/Gruppendetail',
    builder: (context) {
      final groupId = context.knobs.options<String>(
        label: 'Gruppe',
        initial: 'woe',
        options: const [
          Option(label: 'Woelflinge', value: 'woe'),
          Option(label: 'Jungpfadfinder', value: 'jup'),
          Option(label: 'Pfadfinder', value: 'pf'),
          Option(label: 'Rover', value: 'rov'),
        ],
      );
      return MaterialApp(home: StatisticsGroupDetailPage(groupId: groupId));
    },
  );
}

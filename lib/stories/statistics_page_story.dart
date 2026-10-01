import 'package:flutter/material.dart';
import 'package:nami/data/statistiks/shared_prefs_statistik_kachel_repository.dart';
import 'package:nami/data/statistiks/shared_prefs_statistik_verlauf_repository.dart';
import 'package:nami/domain/appearance/appearance_catalog.dart';
import 'package:nami/domain/statistiks/statistik_kachel_einstellungen.dart';
import 'package:nami/domain/statistiks/statistik_verlauf.dart';
import 'package:nami/presentation/model/bundesstatistik_model.dart';
import 'package:nami/presentation/screens/statistics_group_detail_page.dart';
import 'package:nami/presentation/screens/statistics_page.dart';
import 'package:nami/presentation/statistics/statistik_stamm_ansicht.dart';
import 'package:nami/stories/bundesstatistik_story.dart';
import 'package:nami/stories/statistik/statistik_kachel_beispiele.dart';
import 'package:nami/stories/story_tab_shell.dart';
import 'package:provider/provider.dart';
// ignore: depend_on_referenced_packages
import 'package:storybook_flutter/storybook_flutter.dart';

Story statisticsPageStory() {
  return Story(
    name: 'Statistik/Seite/Uebersicht',
    builder: (context) {
      final background = storyHeaderBackgroundKnob(context.knobs);
      final textScale = storyTextScaleKnob(context.knobs);
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
      final datensatz = context.knobs.options<StatistikBeispielDatensatz>(
        label: 'Datensatz',
        initial: StatistikBeispielDatensatz.silberfels,
        options: [
          for (final d in StatistikBeispielDatensatz.values)
            Option(label: d.label, value: d),
        ],
      );
      final thema = context.knobs.options<StatistikThema>(
        label: 'Thema',
        initial: StatistikThema.ueberblick,
        options: const [
          Option(label: 'Überblick', value: StatistikThema.ueberblick),
          Option(label: 'Stufen', value: StatistikThema.stufen),
          Option(label: 'Entwicklung', value: StatistikThema.entwicklung),
        ],
      );
      return StatisticsPageStoryScene(
        textScale: textScale,
        background: background,
        dark: dark,
        bundesstatistik: bundesweit,
        showLoadingInfo: loading,
        datensatz: datensatz,
        thema: thema,
      );
    },
  );
}

/// Statistik-Tab wie in der App, mit Beispieldaten und einer Bundesstatistik
/// ohne Server im gewaehlten Zustand. Kachel-Belegung und Verlauf kommen aus
/// dem Datensatz und liegen nur im Speicher.
class StatisticsPageStoryScene extends StatelessWidget {
  const StatisticsPageStoryScene({
    super.key,
    required this.background,
    this.dark = false,
    this.bundesstatistik = StoryBundesstatistikSzenario.optIn,
    this.showLoadingInfo = false,
    this.simulateTopInset = true,
    this.textScale = 1,
    this.datensatz = StatistikBeispielDatensatz.silberfels,
    this.thema = StatistikThema.ueberblick,
  });

  final AppearanceBackgroundId? background;
  final bool dark;
  final StoryBundesstatistikSzenario bundesstatistik;
  final bool showLoadingInfo;
  final bool simulateTopInset;
  final double textScale;
  final StatistikBeispielDatensatz datensatz;
  final StatistikThema thema;

  @override
  Widget build(BuildContext context) {
    final heute = DateTime.now();
    final readModel = datensatz.readModel(heute);
    final layerId = readModel.arbeitskontext.aktiverLayer.id;
    final kacheln = InMemoryStatistikKachelRepository()
      ..saveForLayer(layerId, datensatz.einstellungen);
    final verlauf = InMemoryStatistikVerlaufRepository()
      ..saveForLayer(layerId, datensatz.verlauf(heute));
    return StoryTabPage(
      key: ValueKey(
        '$background-$dark-$bundesstatistik-$showLoadingInfo-$textScale-'
        '$datensatz-$thema',
      ),
      tabIndex: 1,
      background: background,
      dark: dark,
      showLoadingInfo: showLoadingInfo,
      simulateTopInset: simulateTopInset,
      textScale: textScale,
      providers: [
        ChangeNotifierProvider<BundesstatistikModel>(
          create: (_) =>
              storyBundesstatistikModel(readModel, szenario: bundesstatistik),
        ),
        Provider<StatistikKachelRepository>.value(value: kacheln),
        Provider<StatistikVerlaufRepository>.value(value: verlauf),
      ],
      child: StatisticsPage(debugReadModel: readModel, debugThema: thema),
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

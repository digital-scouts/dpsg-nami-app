import 'package:flutter/material.dart';
import 'package:nami/data/statistiks/shared_prefs_statistik_kachel_repository.dart';
import 'package:nami/data/statistiks/shared_prefs_statistik_verlauf_repository.dart';
import 'package:nami/domain/statistiks/statistik_verlauf.dart';
import 'package:nami/presentation/model/statistik_kacheln_model.dart';
import 'package:nami/presentation/screens/statistics_page.dart';
import 'package:nami/presentation/screens/statistik_zielwerte_page.dart';
import 'package:nami/presentation/statistics/eigene_kachel_editor.dart';
import 'package:nami/presentation/statistics/kachel_katalog_sheet.dart';
import 'package:nami/stories/statistik/statistik_kachel_beispiele.dart';
import 'package:nami/stories/story_tab_shell.dart';
import 'package:provider/provider.dart';
// ignore: depend_on_referenced_packages
import 'package:storybook_flutter/storybook_flutter.dart';

List<Story> statistikBearbeitenStories() => [
  Story(
    name: 'Statistik/Kacheln/Bearbeiten',
    builder: (context) {
      final datensatz = _datensatzKnob(context.knobs);
      final bearbeiten = context.knobs.boolean(
        label: 'Bearbeiten',
        initial: true,
      );
      final ruhig = context.knobs.boolean(
        label: 'Bewegung reduzieren',
        initial: false,
      );
      final dark = context.knobs.boolean(label: 'Dunkel', initial: false);
      final textScale = storyTextScaleKnob(context.knobs);
      return StatistikBearbeitenSzene(
        key: ValueKey('$datensatz-$bearbeiten-$ruhig-$dark-$textScale'),
        datensatz: datensatz,
        bearbeiten: bearbeiten,
        ruhig: ruhig,
        dark: dark,
        textScale: textScale,
      );
    },
  ),
  Story(
    name: 'Statistik/Kacheln/Katalog',
    builder: (context) {
      final datensatz = _datensatzKnob(context.knobs);
      final daten = StatistikKachelBeispiele.daten(datensatz);
      return Material(
        child: KachelKatalogSheet(
          key: ValueKey(datensatz),
          daten: daten,
          readModel: datensatz.readModel(StatistikKachelBeispiele.heute),
          neueId: () => 'story',
        ),
      );
    },
  ),
  Story(
    name: 'Statistik/Kacheln/Eigene Kachel',
    builder: (context) {
      final datensatz = _datensatzKnob(context.knobs);
      final vorhandene = context.knobs.boolean(
        label: 'Bestehende Kachel',
        initial: false,
      );
      final eigene = datensatz.einstellungen.eigeneKacheln;
      return Material(
        child: EigeneKachelEditor(
          key: ValueKey('$datensatz-$vorhandene'),
          readModel: datensatz.readModel(StatistikKachelBeispiele.heute),
          kachel: vorhandene && eigene.isNotEmpty ? eigene.first : null,
          neueId: () => 'story',
          onZurueck: () {},
          onFertig: (_) {},
        ),
      );
    },
  ),
  Story(
    name: 'Statistik/Kacheln/Zielwerte',
    builder: (context) {
      final datensatz = _datensatzKnob(context.knobs);
      return StatistikZielwerteSzene(
        key: ValueKey(datensatz),
        datensatz: datensatz,
      );
    },
  ),
];

StatistikBeispielDatensatz _datensatzKnob(KnobsBuilder knobs) =>
    knobs.options<StatistikBeispielDatensatz>(
      label: 'Datensatz',
      initial: StatistikBeispielDatensatz.weitblick,
      options: [
        for (final d in StatistikBeispielDatensatz.values)
          Option(label: d.label, value: d),
      ],
    );

/// Statistikseite wie in der App, auf Wunsch gleich im Bearbeiten-Modus.
class StatistikBearbeitenSzene extends StatefulWidget {
  const StatistikBearbeitenSzene({
    super.key,
    required this.datensatz,
    required this.bearbeiten,
    required this.ruhig,
    required this.dark,
    required this.textScale,
  });

  final StatistikBeispielDatensatz datensatz;
  final bool bearbeiten;
  final bool ruhig;
  final bool dark;
  final double textScale;

  @override
  State<StatistikBearbeitenSzene> createState() =>
      _StatistikBearbeitenSzeneState();
}

class _StatistikBearbeitenSzeneState extends State<StatistikBearbeitenSzene> {
  final _heute = DateTime.now();
  late final _readModel = widget.datensatz.readModel(_heute);
  late final _verlauf = InMemoryStatistikVerlaufRepository()
    ..saveForLayer(
      _readModel.arbeitskontext.aktiverLayer.id,
      widget.datensatz.verlauf(_heute),
    );
  late final StatistikKachelnModel _model;

  @override
  void initState() {
    super.initState();
    final layerId = _readModel.arbeitskontext.aktiverLayer.id;
    final repository = InMemoryStatistikKachelRepository()
      ..saveForLayer(layerId, widget.datensatz.einstellungen);
    _model = StatistikKachelnModel(repository);
    _model.ensureLoadedForLayer(layerId).then((_) {
      if (widget.bearbeiten) _model.bearbeitenStarten();
    });
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StoryTabPage(
      tabIndex: 1,
      background: null,
      dark: widget.dark,
      textScale: widget.textScale,
      disableAnimations: widget.ruhig,
      providers: [
        ChangeNotifierProvider<StatistikKachelnModel>.value(value: _model),
        Provider<StatistikVerlaufRepository>.value(value: _verlauf),
      ],
      child: StatisticsPage(debugReadModel: _readModel),
    );
  }
}

class StatistikZielwerteSzene extends StatefulWidget {
  const StatistikZielwerteSzene({super.key, required this.datensatz});

  final StatistikBeispielDatensatz datensatz;

  @override
  State<StatistikZielwerteSzene> createState() =>
      _StatistikZielwerteSzeneState();
}

class _StatistikZielwerteSzeneState extends State<StatistikZielwerteSzene> {
  late final StatistikKachelnModel _model;
  bool _geladen = false;

  @override
  void initState() {
    super.initState();
    final layerId = widget.datensatz
        .readModel(StatistikKachelBeispiele.heute)
        .arbeitskontext
        .aktiverLayer
        .id;
    final repository = InMemoryStatistikKachelRepository()
      ..saveForLayer(layerId, widget.datensatz.einstellungen);
    _model = StatistikKachelnModel(repository);
    _model.ensureLoadedForLayer(layerId).then((_) {
      if (mounted) setState(() => _geladen = true);
    });
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_geladen) return const SizedBox.shrink();
    return StatistikZielwertePage(model: _model);
  }
}

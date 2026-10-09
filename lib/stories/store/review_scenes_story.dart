import 'package:flutter/material.dart';
import 'package:nami/data/appearance/in_memory_appearance_settings_repository.dart';
import 'package:nami/domain/appearance/appearance_catalog.dart';
import 'package:nami/domain/appearance/support_access.dart';
import 'package:nami/presentation/model/appearance_model.dart';
import 'package:nami/presentation/model/supporter_kauf_model.dart';
import 'package:nami/presentation/screens/settings_appearance_page.dart';
import 'package:nami/presentation/screens/supporter/supporter_page.dart';
import 'package:nami/presentation/screens/supporter/supporter_paket_sheet.dart';
import 'package:nami/services/app_icon_service.dart';
import 'package:provider/provider.dart';
// ignore: depend_on_referenced_packages
import 'package:storybook_flutter/storybook_flutter.dart';

import '../support/story_supporter_store.dart';
import 'store_scenes_story.dart';

/// Szenen fuer die App-Pruefung der In-App-Kaeufe (Screenshot je Produkt in
/// App Store Connect), auf Englisch und mit nichts gekauft. Erzeugen ueber
/// `tool/store_screenshots/run_store_screenshots.sh --set review`.
List<Story> reviewSceneStories() => <Story>[
  Story(
    name: 'Review/Foerderer',
    builder: (_) => const _ReviewScene(child: _KaufseiteScene()),
  ),
  for (final paket in SupporterPaket.values)
    Story(
      name: 'Review/Paket ${paket.name}',
      builder: (_) => _ReviewScene(child: _PaketSheetScene(paket: paket)),
    ),
];

/// Fester Tag im Einfuehrungszeitraum, damit die Szenen nicht von der Uhr
/// abhaengen.
DateTime _jetzt() => DateTime(2027, 2);

/// Startet das Kauf-Model mit dem Story-Store und stellt Kauf- und
/// Erscheinungsbild-Stand bereit.
class _ReviewScene extends StatelessWidget {
  const _ReviewScene({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SupporterKaufModel>(
      future: storySupporterKaufModel(),
      builder: (context, snapshot) {
        final model = snapshot.data;
        if (model == null) {
          return const SizedBox.shrink();
        }
        return MultiProvider(
          providers: [
            ChangeNotifierProvider<SupporterKaufModel>.value(value: model),
            ChangeNotifierProvider<AppearanceModel>(
              create: (_) => AppearanceModel(
                repository: InMemoryAppearanceSettingsRepository(),
                appIconService: FakeAppIconService(),
                access: const SchalterSupportAccess(SupporterTestZugang.keiner),
              )..load(),
            ),
          ],
          child: StoreSceneApp(locale: const Locale('en'), home: child),
        );
      },
    );
  }
}

class _KaufseiteScene extends StatelessWidget {
  const _KaufseiteScene();

  @override
  Widget build(BuildContext context) =>
      const SupporterPage(nowProvider: _jetzt);
}

/// Erscheinungsbild mit Schloessern, darueber das Sheet zum [paket] wie nach
/// dem Antippen einer gesperrten Option.
class _PaketSheetScene extends StatefulWidget {
  const _PaketSheetScene({required this.paket});

  final SupporterPaket paket;

  @override
  State<_PaketSheetScene> createState() => _PaketSheetSceneState();
}

class _PaketSheetSceneState extends State<_PaketSheetScene> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final model = context.read<SupporterKaufModel>();
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => ChangeNotifierProvider.value(
          value: model,
          child: SupporterPaketSheet(paket: widget.paket, nowProvider: _jetzt),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) =>
      const SettingsAppearancePage(themeMode: ThemeMode.light);
}

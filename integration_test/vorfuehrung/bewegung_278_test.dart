// Geführte Vorführung zu #278 (Bewegung und Haptik). Ablauf und Signal zum
// Weitermachen: siehe vorfuehrung.dart. Bereiche in dieser Reihenfolge:
// filter, mitglied, statistik, karte, ladeleiste, erfolge, konfetti,
// willkommen.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nami/domain/achievements/achievement_definition.dart';
import 'package:nami/main.dart' as app;
import 'package:nami/presentation/notifications/achievement_unlocked.dart';
import 'package:nami/presentation/notifications/welcome_dialog.dart';
import 'package:nami/presentation/screens/settings_page.dart';
import 'package:nami/presentation/statistics/kacheln/kachel_rahmen.dart';
import 'package:nami/presentation/statistics/kacheln/kachel_raster.dart';
import 'package:nami/presentation/statistics/statistik_bearbeiten_leiste.dart';
import 'package:nami/presentation/widgets/app_bottom_navigation.dart';
import 'package:nami/presentation/widgets/global_loading_top_bar.dart';
import 'package:nami/presentation/widgets/member_list_group_filter_bar.dart';
import 'package:nami/presentation/widgets/member_list_tile.dart';

import 'vorfuehrung.dart';

Finder _tab(IconData icon) => find.descendant(
  of: find.byType(AppBottomNavigation),
  matching: find.byIcon(icon),
);

/// Ob im Steckbrief-Kopf Text abgeschnitten ist; nur dann klappt er auf.
bool _steckbriefAbgeschnitten(WidgetTester tester) => tester
    .renderObjectList<RenderParagraph>(
      find.descendant(
        of: find.byKey(const Key('member-steckbrief-name')),
        matching: find.byType(RichText),
      ),
    )
    .any((absatz) => absatz.didExceedMaxLines);

WillkommenOptionen _willkommen() => WillkommenOptionen(
  biometrieVerfuegbar: true,
  biometrieAktiv: false,
  benachrichtigungenErlaubt: null,
  analyseAktiv: false,
  keineMobilenDaten: false,
  themeMode: ThemeMode.system,
  onBiometrieAktivieren: () async => false,
  onBenachrichtigungenAktivieren: () async => false,
  onAnalyseAendern: (_) async {},
  onKeineMobilenDatenAendern: (_) async {},
  onThemeAendern: (_) async {},
  onRechtliches: () {},
);

void main() {
  vorfuehrungBinden();

  testWidgets(
    'Vorführung #278: Bewegung und Haptik',
    (tester) async {
      app.main();
      final v = await Vorfuehrung.starte(tester);
      BuildContext kontext() => app.navigatorKey.currentContext!;

      // Ohne Anmeldung in die Demo; eine laufende Demo bleibt.
      final demoStart = find.byKey(const Key('demo-start'));
      final liste = find.byType(MemberListTile);
      await v.bisSichtbar(
        find.byWidgetPredicate(
          (w) => w.key == const Key('demo-start') || w is MemberListTile,
        ),
      );
      if (demoStart.evaluate().isNotEmpty) {
        await v.tippe(demoStart);
        await v.tippe(find.byKey(const Key('demo-zugang-stammesvorstand')));
      }
      await v.bisSichtbar(liste);

      // Ein Erfolg, den die Vorführung selbst auslöst, darf nicht im Weg
      // stehen: weder als Dialog noch als Snackbar über den Knöpfen.
      Future<void> erfolgSchliessen() async {
        ScaffoldMessenger.of(kontext()).removeCurrentSnackBar();
        final dialog = find.byType(AchievementUnlockedDialog);
        if (dialog.evaluate().isNotEmpty) {
          await v.tippe(
            find.descendant(of: dialog, matching: find.text('Weiter')),
          );
        }
        await v.warte(300);
      }

      await v.bereich(
        'filter',
        'Gruppenfilter',
        vorbereiten: () => v.tippe(_tab(Icons.groups)),
        zeigen: () async {
          final chips = find.descendant(
            of: find.byType(GroupFilterBar),
            matching: find.byType(InkWell),
          );
          await v.tippe(chips.at(0));
          await v.tippe(chips.at(1));
          await v.tippe(chips.at(0));
          await v.tippe(chips.at(1));
        },
      );

      await v.bereich(
        'mitglied',
        'Steckbrief und Kopieren',
        // Kein Demo-Name ist lang genug; mit großer Schrift (Grenze des
        // Kopfs) wird der erste abgeschnittene Steckbrief genommen.
        vorbereiten: () async {
          await v.tippe(_tab(Icons.groups));
          tester.platformDispatcher.textScaleFactorTestValue = 1.4;
          await v.warte(600);
          for (var i = 0; i < 8; i++) {
            await v.tippe(liste.at(i), danach: 1200);
            if (_steckbriefAbgeschnitten(tester)) {
              // ignore: avoid_print
              print(
                'VORFUEHRUNG · Steckbrief von Eintrag $i ist abgeschnitten',
              );
              return;
            }
            await tester.binding.handlePopRoute();
            await v.warte(600);
          }
          // ignore: avoid_print
          print('VORFUEHRUNG · kein abgeschnittener Steckbrief gefunden');
        },
        zeigen: () async {
          final name = find.byKey(const Key('member-steckbrief-name'));
          await v.tippe(name, danach: 1200);
          await v.tippe(name, danach: 1200);
          await v.tippe(find.byIcon(Icons.copy), danach: 1400);
        },
        aufraeumen: () async {
          tester.platformDispatcher.clearTextScaleFactorTestValue();
          await tester.binding.handlePopRoute();
          await v.warte();
        },
      );

      await v.bereich(
        'statistik',
        'Kacheln bearbeiten und Katalog',
        vorbereiten: () async {
          await v.tippe(_tab(Icons.insert_chart), danach: 1200);
          // Das erste Öffnen schaltet „Den Überblick behalten“ frei.
          await v.warte(1500);
          await erfolgSchliessen();
          // Der Knopf liegt unter den Kacheln und entsteht erst beim Scrollen.
          final bearbeiten = find.byKey(const Key('statistik-bearbeiten'));
          await tester.scrollUntilVisible(
            bearbeiten,
            400,
            scrollable: find
                .descendant(
                  of: find.byKey(
                    const PageStorageKey<String>('statistik-thema-ueberblick'),
                  ),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          await v.warte(500);
          await v.tippe(bearbeiten);
        },
        zeigen: () async {
          Future<void> ziehe(int von, int nach) async {
            final kacheln = find.byType(KachelRahmen);
            final start = tester.getCenter(kacheln.at(von));
            final ziel = tester.getCenter(kacheln.at(nach));
            final geste = await tester.startGesture(start);
            await tester.pump(
              KachelRaster.ziehenNach + const Duration(milliseconds: 300),
            );
            for (var i = 1; i <= 10; i++) {
              await geste.moveTo(Offset.lerp(start, ziel, i / 10)!);
              await tester.pump(const Duration(milliseconds: 40));
            }
            await v.warte(400);
            await geste.up();
            await v.warte(900);
          }

          // Hin und zurück, damit die Reihenfolge wieder stimmt.
          await ziehe(0, 1);
          await ziehe(0, 1);
          await v.tippe(
            find.descendant(
              of: find.byType(StatistikBearbeitenLeiste),
              matching: find.byTooltip('Kachel hinzufügen'),
            ),
            danach: 1200,
          );
          // Erster Katalogeintrag öffnet seine Vorschau im selben Sheet.
          await v.tippe(
            find.byWidgetPredicate(
              (w) => w.runtimeType.toString() == '_KatalogZeile',
            ),
            danach: 1400,
          );
          await tester.binding.handlePopRoute();
          await v.warte(900);
        },
        aufraeumen: () => v.tippe(
          find.descendant(
            of: find.byType(StatistikBearbeitenLeiste),
            matching: find.text('Fertig'),
          ),
        ),
      );

      await v.bereich(
        'karte',
        'Kartensuche',
        vorbereiten: () async {
          await v.tippe(_tab(Icons.settings));
          await erfolgSchliessen();
          await v.tippe(find.byIcon(Icons.map), danach: 1500, mitte: true);
        },
        zeigen: () async {
          await v.tippe(
            find.byKey(const ValueKey('settings-map-search-button')),
            danach: 1400,
          );
          // Ergebnisse verdrängen „Karte zentrieren“, leer kommt er zurück.
          final feld = find.byKey(const ValueKey('settings-map-search-field'));
          await tester.enterText(feld, 'Ham');
          await v.warte(1600);
          await tester.enterText(feld, '');
          await v.warte(1200);
          await v.tippe(
            find.byKey(const ValueKey('settings-map-search-close-button')),
            danach: 1200,
          );
        },
        aufraeumen: () async {
          await tester.binding.handlePopRoute();
          await v.warte();
        },
      );

      final ladend = ValueNotifier<bool>(false);
      await v.bereich(
        'ladeleiste',
        'Ladeleiste',
        vorbereiten: () async {
          app.navigatorKey.currentState!.push(
            MaterialPageRoute<void>(
              builder: (_) => Scaffold(
                appBar: AppBar(title: const Text('Ladeleiste')),
                body: Stack(
                  children: [
                    const Center(child: Text('Leiste oben beobachten')),
                    ValueListenableBuilder<bool>(
                      valueListenable: ladend,
                      builder: (_, aktiv, _) =>
                          GlobalLoadingTopBar(active: aktiv, immediate: true),
                    ),
                  ],
                ),
              ),
            ),
          );
          await v.warte(1000);
        },
        zeigen: () async {
          ladend.value = true;
          await v.warte(1600);
          ladend.value = false;
          await v.warte(1200);
        },
        aufraeumen: () async {
          app.navigatorKey.currentState!.pop();
          await v.warte();
        },
      );

      await v.bereich(
        'erfolge',
        'Erfolge freischalten',
        zeigen: () async {
          final definition = achievementCatalog.firstWhere((d) => !d.isOneTime);
          final einmalig = achievementCatalog.firstWhere((d) => d.isOneTime);

          showAchievementUnlocked(
            kontext(),
            definition: definition,
            tier: AchievementTier.bronze,
          );
          await v.warte(2600);
          ScaffoldMessenger.of(kontext()).hideCurrentSnackBar();
          await v.warte(600);

          showAchievementUnlocked(
            kontext(),
            definition: definition,
            tier: AchievementTier.gold,
          );
          await v.warte(2600);
          await erfolgSchliessen();

          showAchievementUnlocked(kontext(), definition: einmalig);
          await v.warte(2600);
          await erfolgSchliessen();
        },
      );

      await v.bereich(
        'konfetti',
        'Konfetti per Dreifachtipp',
        vorbereiten: () async {
          await v.tippe(_tab(Icons.settings));
          await erfolgSchliessen();
          // Der Fuß der Einstellungen entsteht erst beim Scrollen.
          await tester.scrollUntilVisible(
            find.byIcon(Icons.favorite),
            400,
            scrollable: find
                .descendant(
                  of: find.byType(SettingsPage),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          await Scrollable.ensureVisible(
            tester.element(find.byIcon(Icons.favorite)),
            alignment: 0.5,
            duration: const Duration(milliseconds: 300),
          );
          await v.warte(600);
        },
        zeigen: () async {
          for (var i = 0; i < 3; i++) {
            await tester.tap(find.byIcon(Icons.favorite));
            await v.warte(150);
          }
          await v.warte(3200);
        },
      );

      await v.bereich(
        'willkommen',
        'Willkommensdialog',
        zeigen: () async {
          showWelcomeDialog(kontext(), optionen: _willkommen());
          await v.warte(1400);
          await v.tippe(find.byKey(const Key('welcome-next')), danach: 1300);
          await v.tippe(find.byKey(const Key('welcome-next')), danach: 1300);
          await v.tippe(find.byKey(const Key('welcome-back')), danach: 1300);
          await v.tippe(find.byKey(const Key('welcome-back')), danach: 1300);
          app.navigatorKey.currentState!.pop();
          await v.warte(900);
        },
      );

      await v.ende();
      await v.tippe(_tab(Icons.groups));
    },
    skip: !vorfuehrungAktiv,
    timeout: Timeout.none,
  );
}

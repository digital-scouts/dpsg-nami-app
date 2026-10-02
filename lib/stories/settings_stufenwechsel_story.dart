import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:nami/data/settings/in_memory_stufen_settings_repository.dart';
import 'package:nami/domain/appearance/appearance_catalog.dart';
import 'package:nami/domain/settings/stufen_settings.dart';
import 'package:nami/domain/stufe/altersgrenzen.dart';
import 'package:nami/domain/stufe/usecases/update_altersgrenzen_usecase.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/presentation/notifications/app_snackbar.dart';
import 'package:nami/presentation/screens/settings_stufenwechsel_page.dart';
import 'package:nami/presentation/widgets/settings_stufenwechsel.dart';
import 'package:nami/presentation/widgets/settings_stufenwechsel_minmax.dart';
import 'package:nami/stories/store/store_showcase_data.dart';
import 'package:nami/stories/story_tab_shell.dart';
// ignore: depend_on_referenced_packages
import 'package:storybook_flutter/storybook_flutter.dart';

Story stufenwechselSettingsStory() {
  return Story(
    name: 'Einstellungen/Widgets/Stufenwechsel (Slider)',
    builder: (context) {
      var grenzen = StufenDefaults.build();
      DateTime? next;
      final repo = InMemoryStufenSettingsRepository();
      final usecase = UpdateAltersgrenzenUseCase(repo);
      return MaterialApp(
        localizationsDelegates: [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          AppLocalizations.delegate,
        ],
        supportedLocales: const [Locale('de'), Locale('en')],
        home: Scaffold(
          appBar: AppBar(title: const Text('Stufenwechsel – Slider-Variante')),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: StufenwechselSettings(
                grenzen: grenzen,
                nextStufenwechsel: next,
                onDateChanged: (d) => next = d,
                onResetDefaults: () {
                  grenzen = StufenDefaults.build();
                  return grenzen;
                },
                onSave: (g) async {
                  try {
                    await usecase.call(g);
                    AppSnackbar.show(
                      context,
                      title: AppLocalizations.of(
                        context,
                      ).t('snackbar_saved_title'),
                      message: 'Altersgrenzen gespeichert',
                      type: AppSnackbarType.success,
                    );
                    grenzen = g;
                  } on AltersgrenzenValidationError catch (e) {
                    AppSnackbar.show(
                      context,
                      title: AppLocalizations.of(
                        context,
                      ).t('snackbar_invalid_altersgrenzen_title'),
                      message: e.message,
                      type: AppSnackbarType.warning,
                    );
                  } catch (_) {
                    AppSnackbar.show(
                      context,
                      message: 'Speichern fehlgeschlagen.',
                      type: AppSnackbarType.error,
                    );
                  }
                },
              ),
            ),
          ),
        ),
      );
    },
  );
}

Story stufenwechselSettingsMinMaxStory() {
  return Story(
    name: 'Einstellungen/Widgets/Stufenwechsel (MinMax-OD)',
    builder: (context) {
      var grenzen = StufenDefaults.build();
      DateTime? next;
      final repo = InMemoryStufenSettingsRepository();
      final usecase = UpdateAltersgrenzenUseCase(repo);
      return MaterialApp(
        localizationsDelegates: [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          AppLocalizations.delegate,
        ],
        supportedLocales: const [Locale('de'), Locale('en')],
        home: Scaffold(
          appBar: AppBar(
            title: const Text('Stufenwechsel – MinMax-Variante (OD)'),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: StufenwechselSettingsMinMax(
                grenzen: grenzen,
                nextStufenwechsel: next,
                onDateChanged: (d) => next = d,
                onResetDefaults: () {
                  grenzen = StufenDefaults.build();
                  return grenzen;
                },
                onSave: (g) async {
                  try {
                    await usecase.call(g);
                    AppSnackbar.show(
                      context,
                      title: AppLocalizations.of(
                        context,
                      ).t('snackbar_saved_title'),
                      message: 'Altersgrenzen gespeichert',
                      type: AppSnackbarType.success,
                    );
                    grenzen = g;
                  } on AltersgrenzenValidationError catch (e) {
                    AppSnackbar.show(
                      context,
                      title: AppLocalizations.of(
                        context,
                      ).t('snackbar_invalid_altersgrenzen_title'),
                      message: e.message,
                      type: AppSnackbarType.warning,
                    );
                  } catch (_) {
                    AppSnackbar.show(
                      context,
                      message: 'Speichern fehlgeschlagen.',
                      type: AppSnackbarType.error,
                    );
                  }
                },
              ),
            ),
          ),
        ),
      );
    },
  );
}

Story stufenwechselPageStory() {
  return Story(
    name: 'Stufenwechsel/Seite',
    builder: (context) {
      final background = storyHeaderBackgroundKnob(context.knobs);
      final textScale = storyTextScaleKnob(context.knobs);
      final dark = context.knobs.boolean(label: 'Dunkel', initial: false);
      final mitDatum = context.knobs.boolean(
        label: 'Stichtag festgelegt',
        initial: true,
      );
      return StufenwechselPageStoryScene(
        textScale: textScale,
        background: background,
        dark: dark,
        mitDatum: mitDatum,
      );
    },
  );
}

/// Stufenwechsel-Tab wie in der App, mit Beispieldaten. Der Stichtag wird
/// nur im Speicher geaendert.
class StufenwechselPageStoryScene extends StatelessWidget {
  const StufenwechselPageStoryScene({
    super.key,
    required this.background,
    this.dark = false,
    this.mitDatum = true,
    this.simulateTopInset = true,
    this.textScale = 1,
  });

  final AppearanceBackgroundId? background;
  final bool dark;
  final bool mitDatum;
  final bool simulateTopInset;
  final double textScale;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final naechsterWechsel = today.isAfter(DateTime(today.year, 9, 1))
        ? DateTime(today.year + 1, 9, 1)
        : DateTime(today.year, 9, 1);
    return StoryTabPage(
      key: ValueKey('$background-$dark-$mitDatum-$textScale'),
      tabIndex: 2,
      background: background,
      dark: dark,
      simulateTopInset: simulateTopInset,
      textScale: textScale,
      child: SettingsStufenwechselPage(
        showAppBar: false,
        debugReadModel: StoreShowcaseData.readModel(today: today),
        stufenSettingsLoader: () async => StufenSettings(
          grenzen: StufenDefaults.build(),
          stufenwechselDatum: mitDatum ? naechsterWechsel : null,
        ),
        stufenwechselDatumSaver: (_) async {},
        todayProvider: () => today,
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:nami/data/appearance/in_memory_appearance_settings_repository.dart';
import 'package:nami/domain/appearance/appearance_catalog.dart';
import 'package:nami/domain/appearance/appearance_settings.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/presentation/model/appearance_model.dart';
import 'package:nami/presentation/screens/auth_gate_screen.dart';
import 'package:nami/presentation/theme/theme.dart';
import 'package:nami/presentation/widgets/app_sperre_flaeche.dart';
import 'package:nami/services/app_icon_service.dart';
import 'package:provider/provider.dart';
// ignore: depend_on_referenced_packages
import 'package:storybook_flutter/storybook_flutter.dart';

/// Sperre und Sichtschutz im App-Umschalter (A-16, A-17), mit und ohne
/// Supporter-Hintergrund und App-Icon.
Story appSperreStory() => Story(
  name: 'App-Sperre/Sperre und Sichtschutz',
  builder: (context) {
    final dark = context.knobs.boolean(label: 'Dunkel', initial: false);
    final sichtschutz = context.knobs.boolean(
      label: 'Sichtschutz im Umschalter',
      initial: false,
    );
    final fehler = context.knobs.boolean(
      label: 'Fehlermeldung',
      initial: false,
    );
    final background = context.knobs.options<AppearanceBackgroundId?>(
      label: 'Supporter-Hintergrund',
      initial: null,
      options: [
        const Option(label: 'ohne Paket', value: null),
        for (final id in AppearanceBackgroundId.values)
          Option(label: id.name, value: id),
      ],
    );
    final icon = context.knobs.options<AppIconPackage?>(
      label: 'App-Icon',
      initial: null,
      options: [
        const Option(label: 'Standard', value: null),
        for (final paket in AppIconPackage.values)
          Option(label: paket.name, value: paket),
      ],
    );
    final appearance = AppearanceModel(
      repository: InMemoryAppearanceSettingsRepository(),
      appIconService: FakeAppIconService(),
      initial: AppearanceSettings(
        background: background,
        appIcon: icon == null
            ? null
            : AppIconChoice(icon, AppIconVariant.abend),
      ),
    );
    return ChangeNotifierProvider<AppearanceModel>.value(
      value: appearance,
      child: MaterialApp(
        theme: buildTheme(AppPaletteId.standard, Brightness.light),
        darkTheme: buildTheme(AppPaletteId.standard, Brightness.dark),
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        localizationsDelegates: [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          AppLocalizations.delegate,
        ],
        supportedLocales: const [Locale('de'), Locale('en')],
        locale: const Locale('de'),
        home: Scaffold(
          body: sichtschutz
              ? const AppSperreFlaeche()
              : AppSperreAnsicht(
                  onEntsperren: () {},
                  errorMessage: fehler
                      ? 'Entsperren fehlgeschlagen. Bitte erneut versuchen.'
                      : null,
                ),
        ),
      ),
    );
  },
);

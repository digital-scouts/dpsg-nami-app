import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:nami/domain/supporter/supporter_produkt.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/presentation/model/supporter_kauf_model.dart';
import 'package:nami/presentation/screens/supporter/supporter_page.dart';
import 'package:nami/presentation/theme/theme.dart';
import 'package:provider/provider.dart';
// ignore: depend_on_referenced_packages
import 'package:storybook_flutter/storybook_flutter.dart';

import 'support/story_supporter_store.dart';

enum SupporterStoryZustand { neu, paketGekauft, foerderer, offline }

Story supporterPageStory() => Story(
  name: 'Supporter/Kaufseite',
  builder: (context) {
    final zustand = context.knobs.options<SupporterStoryZustand>(
      label: 'Zustand',
      initial: SupporterStoryZustand.neu,
      options: const [
        Option(label: 'Nichts gekauft', value: SupporterStoryZustand.neu),
        Option(
          label: 'Paket Wald gekauft',
          value: SupporterStoryZustand.paketGekauft,
        ),
        Option(label: 'Förderer', value: SupporterStoryZustand.foerderer),
        Option(
          label: 'Store nicht erreichbar',
          value: SupporterStoryZustand.offline,
        ),
      ],
    );
    final dark = context.knobs.boolean(label: 'Dunkel', initial: false);
    return FutureBuilder<SupporterKaufModel>(
      key: ValueKey(zustand),
      future: storySupporterKaufModel(
        erreichbar: zustand != SupporterStoryZustand.offline,
        gekauft: switch (zustand) {
          SupporterStoryZustand.paketGekauft => {SupporterProdukt.paketWald},
          SupporterStoryZustand.foerderer => {SupporterProdukt.foerderer},
          _ => const {},
        },
      ),
      builder: (context, snapshot) {
        final model = snapshot.data;
        if (model == null) {
          return const SizedBox.shrink();
        }
        return ChangeNotifierProvider.value(
          value: model,
          child: MaterialApp(
            theme: lightTheme,
            darkTheme: darkTheme,
            themeMode: dark ? ThemeMode.dark : ThemeMode.light,
            localizationsDelegates: [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
              AppLocalizations.delegate,
            ],
            supportedLocales: const [Locale('de'), Locale('en')],
            home: SupporterPage(nowProvider: () => DateTime(2027, 2)),
          ),
        );
      },
    );
  },
);

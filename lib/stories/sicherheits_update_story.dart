import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:nami/domain/app_update/sicherheits_update_regel.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/presentation/model/sicherheits_update_model.dart';
import 'package:nami/presentation/theme/theme.dart';
import 'package:nami/presentation/widgets/sicherheits_update_sperre.dart';
import 'package:nami/services/app_update_service.dart';
import 'package:provider/provider.dart';
// ignore: depend_on_referenced_packages
import 'package:storybook_flutter/storybook_flutter.dart';

Story sicherheitsUpdateStory() => Story(
  name: 'App/Sicherheitsupdate',
  builder: (context) {
    final zustand = context.knobs.options<String>(
      label: 'Zustand',
      initial: 'countdown',
      options: const [
        Option(label: 'Countdown', value: 'countdown'),
        Option(label: 'Sperre, Daten bleiben', value: 'sperre'),
        Option(label: 'Sperre, Daten gelöscht', value: 'geloescht'),
      ],
    );
    final dark = context.knobs.boolean(label: 'Dunkel', initial: false);
    final model = _StoryModel(
      lage: zustand == 'countdown'
          ? SicherheitsUpdateRegel().lage(
              SicherheitsUpdateStand(
                aufschuebe: 2,
                sperreAb: DateTime.now().add(
                  const Duration(hours: 2, minutes: 45),
                ),
              ),
              now: DateTime.now(),
            )
          : SicherheitsUpdateLage.gesperrt,
      datenGeloescht: zustand == 'geloescht',
    );
    return ChangeNotifierProvider<SicherheitsUpdateModel?>.value(
      value: model,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: lightTheme,
        darkTheme: darkTheme,
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('de'), Locale('en')],
        locale: const Locale('de'),
        builder: (context, child) => Stack(
          fit: StackFit.expand,
          children: [
            SicherheitsUpdateRahmen(child: child!),
            const SicherheitsUpdateSperre(),
          ],
        ),
        home: Scaffold(
          appBar: AppBar(title: const Text('Mitglieder')),
          body: ListView(
            children: const [
              ListTile(
                title: Text('Lena Albrecht'),
                subtitle: Text('Wölflinge'),
              ),
              ListTile(
                title: Text('Mats Brandt'),
                subtitle: Text('Jungpfadfinder'),
              ),
            ],
          ),
        ),
      ),
    );
  },
);

class _StoryModel extends SicherheitsUpdateModel {
  _StoryModel({
    required SicherheitsUpdateLage lage,
    required bool datenGeloescht,
  }) : _storyLage = lage,
       _storyGeloescht = datenGeloescht,
       super(updateService: AppUpdateService(platformOverride: 'ios'));

  final SicherheitsUpdateLage _storyLage;
  final bool _storyGeloescht;

  @override
  SicherheitsUpdateLage get lage => _storyLage;

  @override
  bool get istGesperrt => _storyLage.art == SicherheitsUpdateLageArt.gesperrt;

  @override
  bool get datenGeloescht => _storyGeloescht;

  @override
  SicherheitsUpdateInfo? get info => const SicherheitsUpdateInfo(
    vorgabe: SicherheitsUpdateVorgabe(
      minVersion: '1.0.1',
      betrifft: 'Anmeldung bei Hitobito',
    ),
    currentVersion: '1.0.0',
    storeUrl: 'https://apps.apple.com/de/app/nami/id6468066816',
  );
}

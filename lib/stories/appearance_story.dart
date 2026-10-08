import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:nami/data/appearance/in_memory_appearance_settings_repository.dart';
import 'package:nami/domain/appearance/appearance_catalog.dart';
import 'package:nami/domain/appearance/support_access.dart';
import 'package:nami/domain/member/mitglied.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/presentation/model/appearance_model.dart';
import 'package:nami/presentation/screens/settings_appearance_page.dart';
import 'package:nami/presentation/theme/theme.dart';
import 'package:nami/presentation/widgets/member_list_directory.dart';
import 'package:nami/presentation/widgets/supporter_backdrop.dart';
import 'package:nami/presentation/widgets/supporter_background.dart';
import 'package:nami/presentation/widgets/supporter_badge.dart';
import 'package:nami/services/app_icon_service.dart';
import 'package:provider/provider.dart';
// ignore: depend_on_referenced_packages
import 'package:storybook_flutter/storybook_flutter.dart';

Widget _app({
  required Widget home,
  required bool dark,
  AppPaletteId palette = AppPaletteId.standard,
}) {
  return MaterialApp(
    theme: buildTheme(palette, Brightness.light),
    darkTheme: buildTheme(palette, Brightness.dark),
    themeMode: dark ? ThemeMode.dark : ThemeMode.light,
    localizationsDelegates: [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
      AppLocalizations.delegate,
    ],
    supportedLocales: const [Locale('de'), Locale('en')],
    home: home,
  );
}

Story settingsAppearancePageStory() => Story(
  name: 'Einstellungen/Screens/Erscheinungsbild',
  builder: (context) {
    final dark = context.knobs.boolean(label: 'Dunkel', initial: false);
    final locked = context.knobs.boolean(
      label: 'Nur freie Optionen',
      initial: false,
    );
    final automatic = context.knobs.boolean(
      label: 'iOS (Automatisch-Icon)',
      initial: true,
    );
    return _AppearanceStoryHost(
      key: ValueKey('$locked-$automatic'),
      access: locked
          ? const SchalterSupportAccess(SupporterTestZugang.keiner)
          : const UnlockedSupportAccess(),
      supportsAutomatic: automatic,
      builder: (model) => _app(
        dark: dark,
        palette: model.palette,
        home: const SettingsAppearancePage(),
      ),
    );
  },
);

Story supporterBackgroundStory() => Story(
  name: 'Erscheinungsbild/Widgets/Hintergrund',
  builder: (context) {
    final background = context.knobs.options<AppearanceBackgroundId>(
      label: 'Hintergrund',
      initial: AppearanceBackgroundId.lagerfeuer,
      options: [
        for (final id in AppearanceBackgroundId.values)
          Option(label: id.name, value: id),
      ],
    );
    final dark = context.knobs.boolean(label: 'Nacht (dunkel)', initial: false);
    final withList = context.knobs.boolean(
      label: 'Mit Mitgliederliste',
      initial: true,
    );
    final withTopArea = context.knobs.boolean(
      label: 'Mit Safe Area',
      initial: true,
    );
    final mitglieder = [
      for (var i = 1; i <= 6; i++) MitgliedFactory.demo(index: i),
    ];
    final directory = MemberDirectory(
      mitglieder: mitglieder,
      headerBackground: background,
      supporterBadgeBuilder: (m) =>
          m.mitgliedsnummer == mitglieder.first.mitgliedsnummer
          ? SupporterBadgeId.kompassPfadfinder
          : null,
    );
    return _app(
      dark: dark,
      home: Scaffold(
        body: !withList
            ? SafeArea(
                child: SizedBox(
                  height: 200,
                  child: SupporterBackground(background: background),
                ),
              )
            : !withTopArea
            ? SafeArea(child: directory)
            // Wie im Tab-Rahmen: Backdrop hinter der Dynamic Island.
            : Builder(
                builder: (context) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(padding: const EdgeInsets.only(top: 59)),
                  child: SupporterBackdrop(
                    background: background,
                    child: SafeArea(bottom: false, child: directory),
                  ),
                ),
              ),
      ),
    );
  },
);

Story supporterBadgeStory() => Story(
  name: 'Erscheinungsbild/Widgets/Badges',
  builder: (context) {
    final dark = context.knobs.boolean(label: 'Dunkel', initial: false);
    final size = context.knobs.slider(
      label: 'Größe',
      initial: 44,
      min: 16,
      max: 96,
    );
    return _app(
      dark: dark,
      home: Scaffold(
        body: Center(
          child: Wrap(
            spacing: 16,
            runSpacing: 16,
            alignment: WrapAlignment.center,
            children: [
              for (final badge in AppearanceCatalog.badges)
                SupporterBadge(badge: badge.id, size: size),
            ],
          ),
        ),
      ),
    );
  },
);

/// Baut ein AppearanceModel mit Speicher im Arbeitsspeicher, damit die
/// Auswahl in Storybook direkt wirkt.
class _AppearanceStoryHost extends StatefulWidget {
  const _AppearanceStoryHost({
    super.key,
    required this.access,
    required this.supportsAutomatic,
    required this.builder,
  });

  final SupportAccess access;
  final bool supportsAutomatic;
  final Widget Function(AppearanceModel model) builder;

  @override
  State<_AppearanceStoryHost> createState() => _AppearanceStoryHostState();
}

class _AppearanceStoryHostState extends State<_AppearanceStoryHost> {
  late final AppearanceModel _model = AppearanceModel(
    repository: InMemoryAppearanceSettingsRepository(),
    appIconService: FakeAppIconService(
      supportsAutomaticVariant: widget.supportsAutomatic,
    ),
    access: widget.access,
  )..load();

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AppearanceModel>.value(
      value: _model,
      child: Consumer<AppearanceModel>(
        builder: (context, model, _) => widget.builder(model),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:nami/data/appearance/in_memory_appearance_settings_repository.dart';
import 'package:nami/domain/appearance/appearance_catalog.dart';
import 'package:nami/domain/appearance/appearance_settings.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/presentation/model/appearance_model.dart';
import 'package:nami/presentation/navigation/app_router.dart';
import 'package:nami/presentation/theme/theme.dart';
import 'package:nami/presentation/widgets/app_bottom_navigation.dart';
import 'package:nami/presentation/widgets/app_page_header.dart';
import 'package:nami/presentation/widgets/app_seitenleiste.dart';
import 'package:nami/presentation/widgets/supporter_backdrop.dart';
import 'package:nami/services/app_icon_service.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
// ignore: depend_on_referenced_packages
import 'package:storybook_flutter/storybook_flutter.dart';

/// Knob fuer den Header-Hintergrund; `null` ist der schlichte Header.
AppearanceBackgroundId? storyHeaderBackgroundKnob(
  KnobsBuilder knobs, {
  AppearanceBackgroundId? initial = AppearanceBackgroundId.lagerfeuer,
}) {
  return knobs.options<AppearanceBackgroundId?>(
    label: 'Header-Hintergrund',
    initial: initial,
    options: [
      const Option(label: 'schlicht', value: null),
      for (final id in AppearanceBackgroundId.values)
        Option(label: id.name, value: id),
    ],
  );
}

/// Knob fuer die Textskalierung, um das Header-Raster bei grossen Schriften
/// zu pruefen (der Header begrenzt auf [AppPageHeader.maxTextScaleFactor]).
double storyTextScaleKnob(KnobsBuilder knobs) {
  return knobs.options<double>(
    label: 'Textskalierung',
    initial: 1,
    options: const [
      Option(label: '1.0', value: 1),
      Option(label: '1.3', value: 1.3),
      Option(label: '1.4', value: 1.4),
      Option(label: '2.0', value: 2),
    ],
  );
}

/// Bildet den Tab-Rahmen der App nach: Header-Flaeche per [SupporterBackdrop]
/// hinter einer simulierten Dynamic Island.
class StoryTabShell extends StatelessWidget {
  const StoryTabShell({
    super.key,
    required this.background,
    required this.child,
    this.simulateTopInset = true,
  });

  final AppearanceBackgroundId? background;
  final Widget child;
  final bool simulateTopInset;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return MediaQuery(
      data: simulateTopInset
          ? mediaQuery.copyWith(
              padding: mediaQuery.padding.copyWith(top: 59),
              viewPadding: mediaQuery.viewPadding.copyWith(top: 59),
            )
          : mediaQuery,
      child: SupporterBackdrop(
        background: background,
        child: Column(
          children: [Expanded(child: SafeArea(bottom: false, child: child))],
        ),
      ),
    );
  }
}

/// Komplette Hauptseite wie in der App: Theme, [AppearanceModel] mit dem
/// Header-Hintergrund, Tab-Rahmen und Bottom-Navigation.
class StoryTabPage extends StatelessWidget {
  const StoryTabPage({
    super.key,
    required this.tabIndex,
    required this.background,
    required this.child,
    this.dark = false,
    this.simulateTopInset = true,
    this.providers = const [],
    this.badge,
    this.textScale = 1,
    this.disableAnimations = false,
  });

  final int tabIndex;
  final AppearanceBackgroundId? background;

  /// Eigenes Supporter-Badge, z. B. im Profil-Header der Einstellungen.
  final SupporterBadgeId? badge;
  final Widget child;
  final bool dark;
  final bool simulateTopInset;

  /// Zusaetzliche Provider der Seite, z. B. Bundesstatistik.
  final List<SingleChildWidget> providers;

  /// Simulierte System-Textskalierung.
  final double textScale;

  /// Simuliert „Bewegung reduzieren“.
  final bool disableAnimations;

  @override
  Widget build(BuildContext context) {
    final settings = AppearanceSettings(background: background, badge: badge);
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AppearanceModel?>(
          key: ValueKey('$background-$badge'),
          create: (_) => AppearanceModel(
            repository: InMemoryAppearanceSettingsRepository(settings),
            appIconService: FakeAppIconService(),
            initial: settings,
          ),
        ),
        ...providers,
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildTheme(AppPaletteId.standard, Brightness.light),
        darkTheme: buildTheme(AppPaletteId.standard, Brightness.dark),
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        locale: const Locale('de'),
        localizationsDelegates: [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          AppLocalizations.delegate,
        ],
        supportedLocales: const [Locale('de'), Locale('en')],
        onGenerateRoute: onGenerateRoute,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            disableAnimations: disableAnimations,
          ),
          child: child!,
        ),
        home: StoryNavigationsScaffold(
          ausgewaehlt: tabIndex,
          body: (context, _) => StoryTabShell(
            background: background,
            simulateTopInset: simulateTopInset,
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Scaffold mit unterer Leiste oder, wie in der App ab 840 pt, mit
/// Seitenleiste samt Schnellzugriff.
class StoryNavigationsScaffold extends StatelessWidget {
  const StoryNavigationsScaffold({
    super.key,
    required this.ausgewaehlt,
    required this.body,
  });

  /// 0-3 Hauptbereiche, 4 Karte, 5 Qualifikationen.
  final int ausgewaehlt;

  /// Erhaelt, ob die Seitenleiste sichtbar ist.
  final Widget Function(BuildContext context, bool seitenleiste) body;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final breite = MediaQuery.sizeOf(context).width;
    final seitenleiste = AppSeitenleiste.sichtbar(breite);
    return Scaffold(
      body: Row(
        children: [
          if (seitenleiste)
            AppSeitenleiste(
              hauptbereiche: AppBottomNavigation.hauptbereiche(t),
              schnellzugriff: [
                AppSeitenleisteEintrag(
                  icon: Icons.map_outlined,
                  label: t.t('settings_map'),
                ),
                AppSeitenleisteEintrag(
                  icon: Icons.verified_outlined,
                  label: t.t('quali_titel'),
                ),
              ],
              ausgewaehlt: ausgewaehlt,
              breit: breite >= AppSeitenleiste.breitAb,
              onAuswahl: (_) {},
            ),
          Expanded(child: body(context, seitenleiste)),
        ],
      ),
      bottomNavigationBar: seitenleiste || ausgewaehlt > 3
          ? null
          : AppBottomNavigation(currentIndex: ausgewaehlt),
    );
  }
}

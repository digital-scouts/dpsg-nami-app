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
/// hinter einer simulierten Dynamic Island und optionaler Lade-Info.
class StoryTabShell extends StatelessWidget {
  const StoryTabShell({
    super.key,
    required this.background,
    required this.child,
    this.showLoadingInfo = false,
    this.simulateTopInset = true,
  });

  final AppearanceBackgroundId? background;
  final Widget child;
  final bool showLoadingInfo;
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
          children: [
            if (showLoadingInfo)
              SafeArea(
                bottom: false,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  color: background == null
                      ? Theme.of(context).colorScheme.surfaceContainerHigh
                      : Theme.of(
                          context,
                        ).colorScheme.surface.withValues(alpha: 0.6),
                  child: const Row(
                    children: [
                      SizedBox.square(
                        dimension: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 8),
                      Text('Mitglieder laden'),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: SafeArea(
                top: !showLoadingInfo,
                bottom: false,
                child: child,
              ),
            ),
          ],
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
    this.showLoadingInfo = false,
    this.simulateTopInset = true,
    this.providers = const [],
    this.badge,
    this.textScale = 1,
  });

  final int tabIndex;
  final AppearanceBackgroundId? background;

  /// Eigenes Supporter-Badge, z. B. im Profil-Header der Einstellungen.
  final SupporterBadgeId? badge;
  final Widget child;
  final bool dark;
  final bool showLoadingInfo;
  final bool simulateTopInset;

  /// Zusaetzliche Provider der Seite, z. B. Bundesstatistik.
  final List<SingleChildWidget> providers;

  /// Simulierte System-Textskalierung.
  final double textScale;

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
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(
          body: StoryTabShell(
            background: background,
            showLoadingInfo: showLoadingInfo,
            simulateTopInset: simulateTopInset,
            child: child,
          ),
          bottomNavigationBar: AppBottomNavigation(currentIndex: tabIndex),
        ),
      ),
    );
  }
}

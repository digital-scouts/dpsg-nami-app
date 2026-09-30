import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nami/domain/appearance/appearance_catalog.dart';
import 'package:nami/domain/member/mitglied.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/presentation/widgets/app_page_header.dart';
import 'package:nami/presentation/widgets/member_list_directory.dart';
import 'package:nami/presentation/widgets/supporter_backdrop.dart';
import 'package:nami/presentation/widgets/supporter_background.dart';

void main() {
  final mitglieder = [
    for (var i = 1; i <= 3; i++) MitgliedFactory.demo(index: i),
  ];

  Widget build({
    required AppearanceBackgroundId? background,
    double bannerHeight = 0,
  }) {
    return MaterialApp(
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        AppLocalizations.delegate,
      ],
      supportedLocales: const [Locale('de'), Locale('en')],
      locale: const Locale('de'),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: child!,
      ),
      home: Scaffold(
        body: SupporterBackdrop(
          background: background,
          child: Column(
            children: [
              SizedBox(key: const ValueKey('banner'), height: bannerHeight),
              Expanded(
                child: MemberDirectory(
                  mitglieder: mitglieder,
                  headerBackground: background,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> settle(WidgetTester tester) async {
    // Messen passiert im Post-Frame-Callback, danach folgt ein Neuaufbau.
    await tester.pump();
    await tester.pump();
  }

  testWidgets('Hintergrund reicht vom oberen Rand bis unter den Header', (
    tester,
  ) async {
    await tester.pumpWidget(build(background: AppearanceBackgroundId.wald));
    await settle(tester);

    final backgrounds = find.byType(SupporterBackground);
    expect(backgrounds, findsOneWidget);
    final headerBottom = tester
        .getBottomLeft(find.byType(SupporterBackdropAnchor))
        .dy;
    expect(tester.getTopLeft(backgrounds).dy, 0);
    expect(tester.getSize(backgrounds).height, headerBottom);
  });

  testWidgets('waechst mit, wenn oberhalb ein Banner erscheint', (
    tester,
  ) async {
    await tester.pumpWidget(build(background: AppearanceBackgroundId.himmel));
    await settle(tester);
    final before = tester.getSize(find.byType(SupporterBackground)).height;

    await tester.pumpWidget(
      build(background: AppearanceBackgroundId.himmel, bannerHeight: 80),
    );
    await settle(tester);

    expect(
      tester.getSize(find.byType(SupporterBackground)).height,
      before + 80,
    );
  });

  testWidgets('ohne Hintergrund wird nichts gezeichnet', (tester) async {
    await tester.pumpWidget(build(background: null));
    await settle(tester);

    expect(find.byType(SupporterBackground), findsNothing);
    expect(find.byType(SupporterBackdropAnchor), findsNothing);
  });

  group('AppPageHeader', () {
    Widget buildPage({required AppearanceBackgroundId? background}) {
      return MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: true,
            padding: const EdgeInsets.only(top: 59),
          ),
          child: child!,
        ),
        home: Scaffold(
          body: SupporterBackdrop(
            background: background,
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  AppPageHeader(
                    background: background,
                    child: const SizedBox(height: 40),
                  ),
                  const Expanded(child: SizedBox.expand()),
                ],
              ),
            ),
          ),
        ),
      );
    }

    testWidgets(
      'schlichte Flaeche reicht vom oberen Rand bis unter den Header',
      (tester) async {
        await tester.pumpWidget(buildPage(background: null));
        await settle(tester);

        expect(find.byType(SupporterBackground), findsNothing);
        final plain = find.byKey(const ValueKey('supporter-backdrop-plain'));
        expect(plain, findsOneWidget);
        final headerBottom = tester
            .getBottomLeft(find.byType(SupporterBackdropAnchor))
            .dy;
        expect(tester.getTopLeft(plain).dy, 0);
        expect(tester.getSize(plain).height, headerBottom);
        expect(
          tester.widget<ColoredBox>(plain).color,
          Theme.of(tester.element(plain)).colorScheme.surface,
        );
      },
    );

    testWidgets('animierter Hintergrund reicht bis unter den Header', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildPage(background: AppearanceBackgroundId.wald),
      );
      await settle(tester);

      final backgrounds = find.byType(SupporterBackground);
      expect(backgrounds, findsOneWidget);
      final headerBottom = tester
          .getBottomLeft(find.byType(SupporterBackdropAnchor))
          .dy;
      expect(tester.getTopLeft(backgrounds).dy, 0);
      expect(tester.getSize(backgrounds).height, headerBottom);
    });

    testWidgets('ohne Backdrop zeichnet der Header seine Flaeche selbst', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MediaQuery(
              data: MediaQueryData(disableAnimations: true),
              child: AppPageHeader(
                background: AppearanceBackgroundId.lagerfeuer,
                child: SizedBox(height: 40),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(SupporterBackground), findsOneWidget);
      expect(find.byType(SupporterBackdropAnchor), findsNothing);
    });
  });

  group('Tab-Wechsel', () {
    Widget buildTabs({required int tab}) {
      const background = AppearanceBackgroundId.lagerfeuer;
      final Widget page = switch (tab) {
        0 => MemberDirectory(
          key: const ValueKey('tab-members'),
          mitglieder: mitglieder,
          headerBackground: background,
        ),
        1 => const Column(
          key: ValueKey('tab-statistik'),
          children: [
            AppPageHeader(background: background, child: SizedBox(height: 120)),
            Expanded(child: SizedBox.expand()),
          ],
        ),
        _ => const SizedBox.expand(key: ValueKey('tab-ohne-header')),
      };
      return MaterialApp(
        localizationsDelegates: [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          AppLocalizations.delegate,
        ],
        supportedLocales: const [Locale('de'), Locale('en')],
        locale: const Locale('de'),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: Scaffold(
          body: SupporterBackdrop(background: background, child: page),
        ),
      );
    }

    void expectBackgroundUnderAnchor(WidgetTester tester) {
      final backgrounds = find.byType(SupporterBackground);
      expect(backgrounds, findsOneWidget);
      final anchorBottom = tester
          .getBottomLeft(find.byType(SupporterBackdropAnchor))
          .dy;
      expect(tester.getSize(backgrounds).height, anchorBottom);
    }

    testWidgets('Hintergrund bleibt beim Wechsel zwischen Seiten mit Header', (
      tester,
    ) async {
      await tester.pumpWidget(buildTabs(tab: 0));
      await settle(tester);
      expectBackgroundUnderAnchor(tester);

      await tester.pumpWidget(buildTabs(tab: 1));
      await settle(tester);
      expectBackgroundUnderAnchor(tester);

      await tester.pumpWidget(buildTabs(tab: 0));
      await settle(tester);
      expectBackgroundUnderAnchor(tester);
    });

    testWidgets(
      'ohne Header auf der neuen Seite verschwindet der Hintergrund',
      (tester) async {
        await tester.pumpWidget(buildTabs(tab: 0));
        await settle(tester);
        expectBackgroundUnderAnchor(tester);

        await tester.pumpWidget(buildTabs(tab: 2));
        await settle(tester);
        expect(find.byType(SupporterBackground), findsNothing);
      },
    );
  });
}

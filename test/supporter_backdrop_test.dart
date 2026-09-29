import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nami/domain/appearance/appearance_catalog.dart';
import 'package:nami/domain/member/mitglied.dart';
import 'package:nami/l10n/app_localizations.dart';
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
}

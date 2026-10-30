import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/presentation/model/arbeitskontext_model.dart';
import 'package:nami/presentation/widgets/app_startbuehne.dart';

// Regeln der Startbühne (#279, design/entscheidung/2026-10-30-startbuehne.md).
// Die Zeiten laufen über die Testuhr von tester.pump, nicht über die Wanduhr.

const _laedt = StartbuehneLage(
  laedt: true,
  statusKey: 'nav_work_context_loading_title',
);

const _schritte = [
  ArbeitskontextLoadingStepStatus(
    labelKey: 'nav_work_context_step_login',
    state: ArbeitskontextLoadingStepState.done,
  ),
  ArbeitskontextLoadingStepStatus(
    labelKey: 'nav_work_context_step_groups',
    state: ArbeitskontextLoadingStepState.loading,
  ),
];

Widget _app(
  ValueNotifier<StartbuehneLage> lage, {
  bool reduziert = false,
  VoidCallback? onEntsperren,
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
      data: MediaQuery.of(context).copyWith(disableAnimations: reduziert),
      child: AppStartbuehne(
        lage: lage,
        onEntsperren: onEntsperren,
        child: child!,
      ),
    ),
    home: const Scaffold(body: Center(child: Text('Inhalt'))),
  );
}

final _buehne = find.byKey(const Key('startbuehne'));
final _status = find.byKey(const Key('startbuehne-status'));

void main() {
  testWidgets('übernimmt im ersten Bild und geht bei schnellem Start nur ab', (
    tester,
  ) async {
    final lage = ValueNotifier(_laedt);
    await tester.pumpWidget(_app(lage));
    expect(_buehne, findsOneWidget);
    expect(find.text('Inhalt').hitTestable(), findsNothing);

    await tester.pump(const Duration(milliseconds: 200));
    lage.value = StartbuehneLage.bereitLage;
    await tester.pump();
    // Abgang 300 ms, ohne Status und ohne Knoten davor.
    await tester.pump(const Duration(milliseconds: 150));
    expect(_buehne, findsOneWidget);
    expect(_status, findsNothing);
    await tester.pump(const Duration(milliseconds: 160));
    expect(_buehne, findsNothing);
    expect(find.text('Inhalt').hitTestable(), findsOneWidget);
  });

  testWidgets('zeigt den Status erst nach 1,5 s', (tester) async {
    final lage = ValueNotifier(_laedt);
    await tester.pumpWidget(_app(lage));

    await tester.pump(const Duration(milliseconds: 1400));
    expect(_status, findsNothing);
    await tester.pump(const Duration(milliseconds: 100));
    expect(_status, findsOneWidget);
    expect(find.text('Arbeitskontext wird geladen'), findsOneWidget);

    lage.value = StartbuehneLage.bereitLage;
    await tester.pumpAndSettle();
    expect(_buehne, findsNothing);
  });

  testWidgets('zeigt bei der Erstanmeldung die Checkliste statt des Status', (
    tester,
  ) async {
    final lage = ValueNotifier(
      const StartbuehneLage(
        laedt: true,
        statusKey: 'nav_work_context_loading_title',
        schritte: _schritte,
      ),
    );
    await tester.pumpWidget(_app(lage));
    await tester.pump(AppStartbuehne.hinweisAb);

    expect(find.byKey(const Key('startbuehne-checkliste')), findsOneWidget);
    expect(_status, findsNothing);
    lage.value = StartbuehneLage.bereitLage;
    await tester.pumpAndSettle();
  });

  testWidgets('kommt nach einer Anmeldung mit der Checkliste zurück', (
    tester,
  ) async {
    final lage = ValueNotifier(StartbuehneLage.bereitLage);
    await tester.pumpWidget(_app(lage));
    await tester.pumpAndSettle();
    expect(_buehne, findsNothing);

    // Anmeldung ohne Ladeschritte (z. B. Browser offen): keine Bühne.
    lage.value = _laedt;
    await tester.pumpAndSettle();
    expect(_buehne, findsNothing);

    lage.value = const StartbuehneLage(laedt: true, schritte: _schritte);
    await tester.pump();
    expect(_buehne, findsOneWidget);
    // Der Ladekreis dreht sich weiter, deshalb feste Zeit statt Settle.
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const Key('startbuehne-checkliste')), findsOneWidget);

    lage.value = StartbuehneLage.bereitLage;
    await tester.pumpAndSettle();
    expect(_buehne, findsNothing);
  });

  testWidgets('spielt bei Rückkehr aus dem Hintergrund nicht erneut ab', (
    tester,
  ) async {
    final lage = ValueNotifier(StartbuehneLage.bereitLage);
    await tester.pumpWidget(_app(lage));
    await tester.pumpAndSettle();
    expect(_buehne, findsNothing);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(_buehne, findsNothing);
  });

  testWidgets('zeigt die Sperre auf der Fläche, geht nach dem Entsperren', (
    tester,
  ) async {
    var entsperrt = 0;
    final lage = ValueNotifier(
      const StartbuehneLage(laedt: false, gesperrt: true),
    );
    await tester.pumpWidget(_app(lage, onEntsperren: () => entsperrt++));
    await tester.pump();

    expect(find.byKey(const Key('app_lock_unlock')), findsOneWidget);
    expect(find.text('App entsperren'), findsOneWidget);
    await tester.tap(find.byKey(const Key('app_lock_unlock')));
    expect(entsperrt, 1);

    lage.value = StartbuehneLage.bereitLage;
    await tester.pump();
    // Erst Glas und Knopf (150 ms), dann die Fläche (300 ms).
    await tester.pump(const Duration(milliseconds: 400));
    expect(_buehne, findsOneWidget);
    await tester.pump(const Duration(milliseconds: 60));
    expect(_buehne, findsNothing);
  });

  testWidgets('blendet bei reduzierter Bewegung nur in 200 ms über', (
    tester,
  ) async {
    final lage = ValueNotifier(_laedt);
    await tester.pumpWidget(_app(lage, reduziert: true));
    await tester.pump(const Duration(milliseconds: 500));

    lage.value = StartbuehneLage.bereitLage;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    // Keine Verschiebung der Fläche.
    final verschoben = find.ancestor(
      of: _buehne,
      matching: find.byWidgetPredicate(
        (w) => w is Transform && w.transform.getTranslation().y != 0,
      ),
    );
    expect(verschoben, findsNothing);
    await tester.pump(const Duration(milliseconds: 110));
    expect(_buehne, findsNothing);
  });
}

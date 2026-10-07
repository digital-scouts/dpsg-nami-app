import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/presentation/theme/status_farben.dart';
import 'package:nami/presentation/widgets/hitobito_traffic_log_view.dart';

const String _inhalt =
    '[2026-10-07 10:02:11] GET 200 groups https://hitobito.example/api/groups?page[size]=1000&page[number]=1\n'
    '[2026-10-07 10:02:13] GET 200 people https://hitobito.example/api/people?filter[primary_group_id]=12&fields[people]=first_name&include=roles\n'
    '[2026-10-07 10:15:52] PATCH 422 people https://hitobito.example/api/people/2817\n'
    '[2026-10-07 10:20:03] GET exception:ClientException groups https://hitobito.example/api/groups\n'
    '===== unbekannte Zeile =====';

Widget _app(String content) {
  return MaterialApp(
    locale: const Locale('de'),
    supportedLocales: const [Locale('de'), Locale('en')],
    localizationsDelegates: [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Scaffold(body: HitobitoTrafficLogView(content: content)),
  );
}

void main() {
  testWidgets('zeigt Status, Pfad, Parameter und Hinweise', (tester) async {
    await tester.pumpWidget(_app(_inhalt));

    expect(find.text('Alle 4'), findsOneWidget);
    expect(find.text('Fehler 2'), findsOneWidget);
    expect(find.text('/api/people'), findsOneWidget);
    expect(find.text('filter[primary_group_id]=12'), findsOneWidget);
    // Feldlisten sind eingeklappt.
    expect(find.text('+2 Felder'), findsOneWidget);
    expect(find.text('fields[people]=first_name'), findsNothing);
    expect(find.text('Von Hitobito abgelehnt'), findsOneWidget);
    expect(find.text('Verbindungsfehler (ClientException)'), findsOneWidget);
    // Unbekannte Zeilen bleiben als Klartext sichtbar.
    expect(find.text('===== unbekannte Zeile ====='), findsOneWidget);
  });

  testWidgets('faerbt Status nach Erfolg, Ablehnung und Fehler', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_inhalt));
    final context = tester.element(find.byType(HitobitoTrafficLogView));
    final farben = StatusFarben.of(context);

    Color farbeVon(String key) => tester
        .widget<Text>(
          find.descendant(
            of: find.byKey(Key(key)).first,
            matching: find.byType(Text),
          ),
        )
        .style!
        .color!;

    expect(farbeVon('traffic_status_200'), farben.gut);
    expect(farbeVon('traffic_status_422'), farben.warnung);
    expect(farbeVon('traffic_status_exc'), farben.kritisch);
  });

  testWidgets('Filter Fehler blendet erfolgreiche Anfragen aus', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_inhalt));

    await tester.tap(find.byKey(const Key('traffic_filter_errors')));
    await tester.pump();

    expect(find.byKey(const Key('traffic_status_200')), findsNothing);
    expect(find.byKey(const Key('traffic_status_422')), findsOneWidget);
    expect(find.byKey(const Key('traffic_status_exc')), findsOneWidget);
  });

  testWidgets('Antippen zeigt die vollstaendige URI mit allen Parametern', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_inhalt));

    await tester.tap(find.text('/api/people'));
    await tester.pump();

    expect(find.byKey(const Key('traffic_details')), findsOneWidget);
    expect(
      find.textContaining('fields[people]=first_name', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('URI kopieren'), findsOneWidget);
  });

  testWidgets('zeigt einen Hinweis ohne Eintraege', (tester) async {
    await tester.pumpWidget(_app(''));

    expect(find.text('Keine Anfragen protokolliert.'), findsOneWidget);
  });
}

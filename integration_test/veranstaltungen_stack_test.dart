// Geraete-Test fuer Kurse & Veranstaltungen gegen den lokalen dpsg-stack
// (github.com/mvpfad/dpsg-stack, Seed mit Veranstaltungen und Kursen). Der
// OAuth-Login im Browser wird uebersprungen: Das Token kommt per
// --dart-define. Ohne Token wird der Test uebersprungen.
//
//   flutter test integration_test/veranstaltungen_stack_test.dart \
//     -d <simulator> \
//     --dart-define=STACK_URL=http://localhost:3000 \
//     --dart-define=STACK_TOKEN=<Token fuer mitglied@example.com>
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:nami/domain/arbeitskontext/arbeitskontext.dart';
import 'package:nami/domain/arbeitskontext/arbeitskontext_read_model.dart';
import 'package:nami/domain/auth/auth_session.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/presentation/model/veranstaltungen_model.dart';
import 'package:nami/presentation/screens/veranstaltungen/veranstaltungen_page.dart';
import 'package:nami/services/hitobito_auth_env.dart';
import 'package:nami/services/hitobito_events_service.dart';
import 'package:provider/provider.dart';

const _url = String.fromEnvironment(
  'STACK_URL',
  defaultValue: 'http://localhost:3000',
);
const _token = String.fromEnvironment('STACK_TOKEN');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<List<Map<String, dynamic>>> gruppen(Map<String, String> filter) async {
    final antwort = await http.get(
      Uri.parse('$_url/api/groups').replace(
        queryParameters: {
          ...filter,
          'fields[groups]': 'name,parent_id,layer_group_id',
        },
      ),
      headers: {
        'Authorization': 'Bearer $_token',
        'Accept': 'application/vnd.api+json',
      },
    );
    expect(antwort.statusCode, 200, reason: antwort.body);
    final daten = jsonDecode(utf8.decode(antwort.bodyBytes))['data'] as List;
    return daten.cast<Map<String, dynamic>>();
  }

  Future<void> warteAuf(WidgetTester tester, Finder finder) async {
    final ende = DateTime.now().add(const Duration(seconds: 30));
    while (finder.evaluate().isEmpty && DateTime.now().isBefore(ende)) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    expect(finder, findsWidgets);
  }

  testWidgets(
    'Mitglied sucht, filtert und oeffnet Kurse aus dem Stack',
    (tester) async {
      await initializeDateFormatting('de');

      // Arbeitskontext wie nach dem Sync: Stamm Fuchsbau mit seinen Gruppen.
      final stamm = (await gruppen({
        'filter[name][eq]': 'Stamm Fuchsbau',
      })).single;
      final stammId = int.parse(stamm['id'] as String);
      final stammGruppen = await gruppen({
        'filter[layer_group_id][eq]': '$stammId',
      });
      final bezirkId = stamm['attributes']['parent_id'] as int;
      final readModel = ArbeitskontextReadModel(
        arbeitskontext: Arbeitskontext(
          aktiverLayer: ArbeitskontextLayer(
            id: stammId,
            name: 'Stamm Fuchsbau',
            parentLayerId: bezirkId,
          ),
        ),
        gruppen: [
          for (final gruppe in stammGruppen)
            ArbeitskontextGruppe(
              id: int.parse(gruppe['id'] as String),
              name: gruppe['attributes']['name'] as String? ?? '',
              layerId: stammId,
            ),
        ],
      );

      final config = HitobitoAuthConfig.fromBaseUrl(
        clientId: 'nami-app-lokal',
        clientSecret: 'nami-app-lokal-secret',
        baseUrl: _url,
        redirectUri: 'de.jlange.nami.app:/oauth/callback',
        scopeString: HitobitoAuthConfig.defaultScopeString,
      );
      final model = VeranstaltungenModel(
        service: HitobitoEventsService(config: config),
        remoteAccessExecutor: <T>({required trigger, required action}) =>
            action(
              AuthSession(accessToken: _token, receivedAt: DateTime.now()),
            ),
        readModel: () => readModel,
        webSeite: (v) =>
            config.eventWebUri(groupId: v.gruppenIds.first, eventId: v.id),
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<VeranstaltungenModel>.value(
          value: model,
          child: MaterialApp(
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('de')],
            locale: const Locale('de'),
            home: const VeranstaltungenPage(),
          ),
        ),
      );

      // Alle sichtbaren: eigene, global sichtbare fremde und alle Kurse.
      await warteAuf(tester, find.byKey(const Key('veranstaltungen-anzahl')));
      expect(find.text('8 kommende'), findsOneWidget);
      expect(find.textContaining('Leiterrunde Adlerhorst'), findsNothing);
      expect(find.textContaining('Waldputzaktion'), findsNothing);
      // Veranstaltende Gruppen ausserhalb des Arbeitskontexts nachgeladen.
      expect(find.text('Bezirk Silberbach'), findsWidgets);
      expect(find.textContaining('ausgebucht'), findsOneWidget);

      await tester.tap(find.byKey(const Key('veranstaltungen-chip-kurse')));
      await tester.pumpAndSettle();
      expect(find.text('4 kommende'), findsOneWidget);
      await tester.tap(find.byKey(const Key('veranstaltungen-chip-alle')));
      await tester.pumpAndSettle();

      // Eigene Ebene: neue Anfrage mit filter[group_id].
      await tester.ensureVisible(
        find.byKey(const Key('veranstaltungen-chip-ebene')),
      );
      await tester.tap(find.byKey(const Key('veranstaltungen-chip-ebene')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('veranstaltungen-ebene-meinStamm')),
      );
      await tester.tap(
        find.byKey(const Key('veranstaltungen-filter-anzeigen')),
      );
      await tester.pumpAndSettle();
      await warteAuf(tester, find.text('2 kommende'));
      expect(find.textContaining('Kinoabend'), findsNothing);

      // Zurueck auf alle und den Bezirkskurs oeffnen.
      await tester.ensureVisible(
        find.byKey(const Key('veranstaltungen-chip-ebene')),
      );
      await tester.tap(find.byKey(const Key('veranstaltungen-chip-ebene')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('veranstaltungen-ebene-alle')));
      await tester.tap(
        find.byKey(const Key('veranstaltungen-filter-anzeigen')),
      );
      await tester.pumpAndSettle();
      await warteAuf(tester, find.text('8 kommende'));

      // Die Kursart passt auch auf den Bundeskurs; mit Bezirk bleibt einer.
      await tester.enterText(find.byType(TextField), 'Gruppenleitungskurs');
      await tester.pumpAndSettle();
      expect(find.text('2 kommende'), findsOneWidget);
      await tester.enterText(
        find.byType(TextField),
        'Gruppenleitungskurs Silberbach',
      );
      await tester.pumpAndSettle();
      expect(find.text('1 kommende'), findsOneWidget);
      await tester.tap(
        find.textContaining('Gruppenleitungskurs Bezirk', findRichText: true),
      );
      await tester.pumpAndSettle();

      await warteAuf(tester, find.text('Finn Stammesführung'));
      expect(find.text('KURS · GLK'), findsOneWidget);
      expect(find.textContaining('8 von 12 frei'), findsOneWidget);
      expect(find.text('Wochenende 2'), findsOneWidget);
      expect(find.text('Im Web öffnen'), findsOneWidget);
      expect(
        find.textContaining('Gültige Erste-Hilfe-Ausbildung'),
        findsOneWidget,
      );

      // Bundeskurs mit externer Anmeldung.
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Bundeskurs');
      await tester.pumpAndSettle();
      await tester.tap(
        find.textContaining('Bundeskurs Gruppenleitung', findRichText: true),
      );
      await tester.pumpAndSettle();
      await warteAuf(tester, find.text('Zur Anmeldung'));
      expect(
        find.text('Anmeldung auch ohne Hitobito-Konto möglich.'),
        findsOneWidget,
      );
    },
    skip: _token.isEmpty,
  );
}

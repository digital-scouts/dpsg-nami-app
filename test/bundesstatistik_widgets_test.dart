import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nami/domain/arbeitskontext/arbeitskontext.dart';
import 'package:nami/domain/arbeitskontext/arbeitskontext_read_model.dart';
import 'package:nami/domain/bundesstatistik/bundesaggregat.dart';
import 'package:nami/domain/bundesstatistik/bundesstatistik_repository.dart';
import 'package:nami/domain/bundesstatistik/bundesstatistik_teilnahme.dart';
import 'package:nami/domain/bundesstatistik/installation_credentials.dart';
import 'package:nami/domain/bundesstatistik/stammes_snapshot.dart';
import 'package:nami/domain/member/mitglied.dart';
import 'package:nami/l10n/app_localizations.dart';
import 'package:nami/presentation/model/bundesstatistik_model.dart';
import 'package:nami/presentation/navigation/app_router.dart';
import 'package:nami/presentation/screens/bundesvergleich_page.dart';
import 'package:nami/presentation/screens/statistics_page.dart';
import 'package:nami/presentation/widgets/bundesstatistik_einwilligung_dialog.dart';
import 'package:provider/provider.dart';

Widget _app(Widget home) => MaterialApp(
  onGenerateRoute: onGenerateRoute,
  localizationsDelegates: [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: const [Locale('de'), Locale('en')],
  locale: const Locale('de'),
  home: home,
);

const _kennzahlen = StammesKennzahlen(
  aktiveMitglieder: 20,
  biber: GeschlechterVerteilung(
    gesamt: 4,
    maennlich: 2,
    weiblich: 2,
    divers: 0,
    geschlechtUnbekannt: 0,
  ),
  woelflinge: GeschlechterVerteilung(
    gesamt: 12,
    maennlich: 6,
    weiblich: 6,
    divers: 0,
    geschlechtUnbekannt: 0,
  ),
  jungpfadfinder: GeschlechterVerteilung.leer(),
  pfadfinder: GeschlechterVerteilung.leer(),
  rover: GeschlechterVerteilung.leer(),
  leitende: LeitendeAltersVerteilung(
    gesamt: 4,
    unter21: 1,
    von21Bis30: 3,
    von31Bis40: 0,
    von41Bis50: 0,
    von51Bis60: 0,
    ueber60: 0,
  ),
  leitendeBiber: GeschlechterVerteilung.leer(),
  leitendeWoelflinge: GeschlechterVerteilung(
    gesamt: 3,
    maennlich: 1,
    weiblich: 2,
    divers: 0,
    geschlechtUnbekannt: 0,
  ),
  leitendeJungpfadfinder: GeschlechterVerteilung.leer(),
  leitendePfadfinder: GeschlechterVerteilung.leer(),
  leitendeRover: GeschlechterVerteilung.leer(),
  nichtLeitendeErwachsene: 2,
);

Bundesaggregat _aggregat() => Bundesaggregat(
  status: BundesaggregatStatus.ok,
  teilnehmendeStaemme: 23,
  mindestAnzahlStaemme: 5,
  hinweis: 'Annäherung aus freiwillig geteilten Stammesdaten.',
  datenstandVon: DateTime.utc(2026, 5, 1),
  datenstandBis: DateTime.utc(2026, 6, 14),
  kennzahlen: const {
    'woelflinge.gesamt': KennzahlAggregat(
      summe: 230,
      stammAnzahl: 23,
      median: 9,
    ),
    'biber.gesamt': KennzahlAggregat(summe: 60, stammAnzahl: 12, median: 4.5),
  },
);

void main() {
  group('BundesvergleichView', () {
    testWidgets('vergleicht eigene Werte mit Median und Durchschnitt', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: BundesvergleichView(
              status: BundesstatistikStatus.bereit,
              hatEinwilligung: true,
              aggregat: _aggregat(),
              eigeneKennzahlen: _kennzahlen,
              onEinwilligungAendern: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('MITGLIEDER JE STUFE'), findsOneWidget);
      expect(find.text('12'), findsWidgets);
      expect(find.text('4,5'), findsOneWidget);
      expect(find.text('10'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('23 teilnehmende Stämme'), 200);
      expect(find.text('23 teilnehmende Stämme'), findsOneWidget);
      expect(find.text('Datenstand 01.05.2026 bis 14.06.2026'), findsOneWidget);
    });

    testWidgets('zeigt ohne Einwilligung keinen Vergleich', (tester) async {
      bool? angefragt;
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: BundesvergleichView(
              status: BundesstatistikStatus.keineEinwilligung,
              hatEinwilligung: false,
              onEinwilligungAendern: (value) => angefragt = value,
            ),
          ),
        ),
      );

      expect(find.text('MITGLIEDER JE STUFE'), findsNothing);
      expect(find.byType(Switch), findsNothing);
      await tester.tap(find.text('Jetzt teilnehmen'));
      expect(angefragt, isTrue);
    });

    testWidgets('erklaert, wenn der Vergleich nicht verfuegbar ist', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: BundesvergleichView(
              status: BundesstatistikStatus.nichtVerfuegbar,
              hatEinwilligung: false,
              onEinwilligungAendern: (_) {},
            ),
          ),
        ),
      );

      expect(
        find.text(
          'Der bundesweite Vergleich ist in dieser App-Version nicht verfügbar.',
        ),
        findsOneWidget,
      );
      expect(find.text('Jetzt teilnehmen'), findsNothing);
    });

    testWidgets('erklaert zu geringe Teilnahme', (tester) async {
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: BundesvergleichView(
              status: BundesstatistikStatus.zuWenigTeilnahme,
              hatEinwilligung: true,
              aggregat: Bundesaggregat(
                status: BundesaggregatStatus.zuWenigTeilnahme,
                teilnehmendeStaemme: 2,
                mindestAnzahlStaemme: 5,
                hinweis: '',
                kennzahlen: const {},
              ),
              onEinwilligungAendern: (_) {},
            ),
          ),
        ),
      );

      expect(find.textContaining('Bisher teilen 2 Stämme'), findsOneWidget);
    });

    testWidgets('zeigt, was zuletzt geteilt wurde', (tester) async {
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: BundesvergleichView(
              status: BundesstatistikStatus.wartetAufDaten,
              hatEinwilligung: true,
              zuletztGesendet: StammesSnapshot(
                stammId: '11',
                senderId: 'install-1',
                sentAt: DateTime(2026, 6, 15, 10, 30),
                sourceDataAsOf: DateTime(2026, 6, 15, 10),
                kennzahlen: _kennzahlen,
              ),
              onEinwilligungAendern: (_) {},
            ),
          ),
        ),
      );

      await tester.scrollUntilVisible(
        find.text('Ordentliche Mitgliedschaften'),
        200,
      );
      expect(
        find.text('Zuletzt gesendet am 15.06.2026, 10:30'),
        findsOneWidget,
      );
      expect(find.text('20'), findsOneWidget);
    });
  });

  group('Einwilligungsdialog', () {
    testWidgets('liefert nur bei Zustimmung true', (tester) async {
      final ergebnisse = <bool>[];
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) => TextButton(
              onPressed: () async => ergebnisse.add(
                await zeigeBundesstatistikEinwilligungDialog(context),
              ),
              child: const Text('öffnen'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('öffnen'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Namen, Geburtsdaten'), findsOneWidget);
      await tester.tap(find.text('Abbrechen'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('öffnen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Teilen aktivieren'));
      await tester.pumpAndSettle();

      expect(ergebnisse, [false, true]);
    });
  });

  testWidgets('Statistik-Tab Bundesweit aktiviert nach Einwilligung', (
    tester,
  ) async {
    final repository = _RecordingRepository();
    final model = BundesstatistikModel(
      featureEnabled: true,
      repository: repository,
      credentialsRepository: _StaticCredentialsRepository(),
      teilnahmeRepository: _MemoryTeilnahmeRepository(),
    );
    final readModel = _stammReadModel();
    await model.aktualisiereKontext(
      personId: '42',
      readModel: readModel,
      datenstand: null,
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<BundesstatistikModel>.value(
        value: model,
        child: _app(Scaffold(body: StatisticsPage(debugReadModel: readModel))),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Bundesweit'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Jetzt teilnehmen'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(FilledButton, 'Teilen aktivieren').last,
    );
    await tester.pumpAndSettle();

    expect(model.hatEinwilligung, isTrue);
    expect(repository.sendungen, 1);
    expect(find.text('Stammesdaten teilen'), findsOneWidget);
  });
}

ArbeitskontextReadModel _stammReadModel() => ArbeitskontextReadModel(
  arbeitskontext: Arbeitskontext(
    aktiverLayer: const ArbeitskontextLayer(
      id: 11,
      name: 'Stamm Testdorf',
      layerTyp: 'Group::Stamm',
    ),
  ),
  rolesSindGeladen: true,
  mitglieder: <Mitglied>[
    Mitglied.peopleListItem(mitgliedsnummer: '1', vorname: 'A', nachname: 'B'),
  ],
  gruppen: const <ArbeitskontextGruppe>[
    ArbeitskontextGruppe(
      id: 21,
      name: 'Meute Nord',
      layerId: 11,
      gruppenTyp: 'Group::StammGruppeWoelflinge',
    ),
  ],
  mitgliedsZuordnungen: const <ArbeitskontextMitgliedsZuordnung>[
    ArbeitskontextMitgliedsZuordnung(
      mitgliedsnummer: '1',
      gruppenId: 21,
      rollenLabel: 'Mitglied',
    ),
  ],
);

class _RecordingRepository implements BundesstatistikRepository {
  int sendungen = 0;

  @override
  Future<void> sendeSnapshot(
    StammesSnapshot snapshot,
    InstallationCredentials credentials,
  ) async {
    sendungen++;
  }

  @override
  Future<Bundesaggregat> ladeBundesaggregat(
    InstallationCredentials credentials,
  ) async => Bundesaggregat(
    status: BundesaggregatStatus.ok,
    teilnehmendeStaemme: 7,
    mindestAnzahlStaemme: 5,
    hinweis: '',
    kennzahlen: const {},
  );
}

class _StaticCredentialsRepository
    implements InstallationCredentialsRepository {
  static const _credentials = InstallationCredentials(
    id: 'install',
    secret: 'secret',
  );

  @override
  Future<InstallationCredentials> loadOrCreate() async => _credentials;

  @override
  Future<InstallationCredentials> regenerate() async => _credentials;

  @override
  Future<void> clear() async {}
}

class _MemoryTeilnahmeRepository implements BundesstatistikTeilnahmeRepository {
  BundesstatistikTeilnahme stored = BundesstatistikTeilnahme.leer;

  @override
  Future<BundesstatistikTeilnahme> load() async => stored;

  @override
  Future<void> save(BundesstatistikTeilnahme teilnahme) async =>
      stored = teilnahme;
}

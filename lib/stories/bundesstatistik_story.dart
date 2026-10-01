import 'package:flutter/material.dart';
// ignore: depend_on_referenced_packages
import 'package:storybook_flutter/storybook_flutter.dart';

import '../domain/arbeitskontext/arbeitskontext_read_model.dart';
import '../domain/bundesstatistik/bundesaggregat.dart';
import '../domain/bundesstatistik/bundesstatistik_repository.dart';
import '../domain/bundesstatistik/bundesstatistik_teilnahme.dart';
import '../domain/bundesstatistik/installation_credentials.dart';
import '../domain/bundesstatistik/stammes_snapshot.dart';
import '../presentation/model/bundesstatistik_model.dart';
import '../presentation/screens/bundesvergleich_page.dart';
import '../presentation/widgets/bundesstatistik_einwilligung_dialog.dart';
import '../domain/bundesstatistik/statistik_abdeckung.dart';

const List<Option<BundesstatistikStatus>> _statusOptionen = [
  Option(
    label: 'Keine Einwilligung',
    value: BundesstatistikStatus.keineEinwilligung,
  ),
  Option(label: 'Bereit', value: BundesstatistikStatus.bereit),
  Option(
    label: 'Zu wenig Teilnahme',
    value: BundesstatistikStatus.zuWenigTeilnahme,
  ),
  Option(
    label: 'Wartet auf Daten',
    value: BundesstatistikStatus.wartetAufDaten,
  ),
  Option(label: 'Kein Stamm', value: BundesstatistikStatus.keinStamm),
  Option(
    label: 'Keine Kennzahlen',
    value: BundesstatistikStatus.keineKennzahlen,
  ),
  Option(label: 'Abgelehnt', value: BundesstatistikStatus.abgelehnt),
  Option(label: 'Fehler', value: BundesstatistikStatus.fehler),
];

Story bundesvergleichStory() {
  return Story(
    name: 'Statistik/Bundesweit/Vergleich',
    builder: (context) {
      final status = context.knobs.options<BundesstatistikStatus>(
        label: 'Status',
        initial: BundesstatistikStatus.bereit,
        options: _statusOptionen,
      );
      final hatEinwilligung = status != BundesstatistikStatus.keineEinwilligung;
      final aggregat = switch (status) {
        BundesstatistikStatus.bereit => bundesstatistikBeispielAggregat,
        BundesstatistikStatus.zuWenigTeilnahme => _zuWenigAggregat,
        _ => null,
      };
      return MaterialApp(
        home: Scaffold(
          appBar: AppBar(title: const Text('Bundesweiter Vergleich')),
          body: BundesvergleichView(
            status: status,
            hatEinwilligung: hatEinwilligung,
            aggregat: aggregat,
            eigeneKennzahlen: bundesstatistikBeispielKennzahlen,
            einwilligungAm: hatEinwilligung ? DateTime(2026, 6, 1) : null,
            zuletztGesendet: hatEinwilligung
                ? StammesSnapshot(
                    stammId: '11',
                    senderId: 'installation',
                    sentAt: DateTime(2026, 6, 14, 18, 5),
                    sourceDataAsOf: DateTime(2026, 6, 14, 18),
                    kennzahlen: bundesstatistikBeispielKennzahlen,
                  )
                : null,
            onEinwilligungAendern: (_) {},
          ),
        ),
      );
    },
  );
}

Story bundesstatistikEinwilligungStory() {
  return Story(
    name: 'Statistik/Bundesweit/Einwilligungsdialog',
    builder: (context) => const MaterialApp(
      home: Scaffold(body: Center(child: BundesstatistikEinwilligungDialog())),
    ),
  );
}

const bundesstatistikBeispielKennzahlen = StammesKennzahlen(
  aktiveMitglieder: 58,
  biber: GeschlechterVerteilung(
    gesamt: 6,
    maennlich: 3,
    weiblich: 3,
    divers: 0,
    geschlechtUnbekannt: 0,
  ),
  woelflinge: GeschlechterVerteilung(
    gesamt: 14,
    maennlich: 8,
    weiblich: 6,
    divers: 0,
    geschlechtUnbekannt: 0,
  ),
  jungpfadfinder: GeschlechterVerteilung(
    gesamt: 11,
    maennlich: 5,
    weiblich: 5,
    divers: 1,
    geschlechtUnbekannt: 0,
  ),
  pfadfinder: GeschlechterVerteilung(
    gesamt: 9,
    maennlich: 4,
    weiblich: 5,
    divers: 0,
    geschlechtUnbekannt: 0,
  ),
  rover: GeschlechterVerteilung(
    gesamt: 5,
    maennlich: 2,
    weiblich: 2,
    divers: 0,
    geschlechtUnbekannt: 1,
  ),
  leitende: LeitendeAltersVerteilung(
    gesamt: 13,
    unter21: 2,
    von21Bis30: 7,
    von31Bis40: 2,
    von41Bis50: 1,
    von51Bis60: 1,
    ueber60: 0,
  ),
  leitendeBiber: GeschlechterVerteilung(
    gesamt: 2,
    maennlich: 1,
    weiblich: 1,
    divers: 0,
    geschlechtUnbekannt: 0,
  ),
  leitendeWoelflinge: GeschlechterVerteilung(
    gesamt: 4,
    maennlich: 2,
    weiblich: 2,
    divers: 0,
    geschlechtUnbekannt: 0,
  ),
  leitendeJungpfadfinder: GeschlechterVerteilung(
    gesamt: 3,
    maennlich: 1,
    weiblich: 2,
    divers: 0,
    geschlechtUnbekannt: 0,
  ),
  leitendePfadfinder: GeschlechterVerteilung(
    gesamt: 2,
    maennlich: 1,
    weiblich: 1,
    divers: 0,
    geschlechtUnbekannt: 0,
  ),
  leitendeRover: GeschlechterVerteilung(
    gesamt: 2,
    maennlich: 1,
    weiblich: 1,
    divers: 0,
    geschlechtUnbekannt: 0,
  ),
  nichtLeitendeErwachsene: 4,
);

KennzahlAggregat _k(num summe, int staemme, num median) =>
    KennzahlAggregat(summe: summe, stammAnzahl: staemme, median: median);

final bundesstatistikBeispielAggregat = Bundesaggregat(
  status: BundesaggregatStatus.ok,
  teilnehmendeStaemme: 42,
  mindestAnzahlStaemme: 5,
  hinweis:
      'Annäherung aus freiwillig geteilten Stammesdaten teilnehmender App-Nutzer. '
      'Keine amtliche und keine repräsentative Statistik.',
  aggregationsWoche: '2026-W24',
  datenstandVon: DateTime(2026, 4, 20),
  datenstandBis: DateTime(2026, 6, 14),
  kennzahlen: {
    'biber.gesamt': _k(180, 30, 5),
    'woelflinge.gesamt': _k(520, 42, 12),
    'jungpfadfinder.gesamt': _k(430, 41, 10),
    'pfadfinder.gesamt': _k(350, 40, 8),
    'rover.gesamt': _k(210, 36, 5.5),
    'leitende_biber.gesamt': _k(60, 30, 2),
    'leitende_woelflinge.gesamt': _k(150, 42, 3.5),
    'leitende_jungpfadfinder.gesamt': _k(120, 41, 3),
    'leitende_pfadfinder.gesamt': _k(100, 40, 2),
    'leitende_rover.gesamt': _k(70, 36, 2),
    for (final stufe in [
      'biber',
      'woelflinge',
      'jungpfadfinder',
      'pfadfinder',
      'rover',
    ]) ...{
      '$stufe.weiblich': _k(170, 40, 4),
      '$stufe.maennlich': _k(160, 40, 4),
      '$stufe.divers': _k(6, 6, 1),
      '$stufe.geschlecht_unbekannt': _k(8, 7, 1),
    },
    'leitende.unter_21': _k(80, 40, 2),
    'leitende.von_21_bis_30': _k(260, 42, 6),
    'leitende.von_31_bis_40': _k(90, 38, 2),
    'leitende.von_41_bis_50': _k(50, 30, 1),
    'leitende.von_51_bis_60': _k(30, 22, 1),
    'leitende.ueber_60': const KennzahlAggregat(
      summe: null,
      stammAnzahl: 4,
      median: null,
    ),
  },
);

final _zuWenigAggregat = Bundesaggregat(
  status: BundesaggregatStatus.zuWenigTeilnahme,
  teilnehmendeStaemme: 3,
  mindestAnzahlStaemme: 5,
  hinweis: '',
  kennzahlen: const {},
);

/// Zustaende des Bundesweit-Tabs fuer Stories.
enum StoryBundesstatistikSzenario {
  optIn('Opt-in (keine Einwilligung)'),
  daten('Vergleich mit Daten'),
  zuWenigTeilnehmende('Zu wenig Teilnehmende'),
  fehler('Technischer Fehler'),
  nichtVerfuegbar('Nicht verfügbar');

  const StoryBundesstatistikSzenario(this.label);

  final String label;
}

/// [BundesstatistikModel] ohne Server fuer Stories. Beim Opt-in liefert es
/// nach der Einwilligung [bundesstatistikBeispielAggregat].
BundesstatistikModel storyBundesstatistikModel(
  ArbeitskontextReadModel readModel, {
  StoryBundesstatistikSzenario szenario = StoryBundesstatistikSzenario.optIn,
}) {
  final model = BundesstatistikModel(
    featureEnabled: szenario != StoryBundesstatistikSzenario.nichtVerfuegbar,
    repository: _StoryBundesstatistikRepository(switch (szenario) {
      StoryBundesstatistikSzenario.zuWenigTeilnehmende => _zuWenigAggregat,
      StoryBundesstatistikSzenario.fehler => null,
      _ => bundesstatistikBeispielAggregat,
    }),
    credentialsRepository: _StoryCredentialsRepository(),
    teilnahmeRepository: _StoryTeilnahmeRepository(),
  );
  model
      .aktualisiereKontext(
        personId: 'story',
        readModel: readModel,
        datenstand: null,
        abdeckung: const StatistikAbdeckung.stamm(),
      )
      .then((_) {
        if (szenario != StoryBundesstatistikSzenario.optIn) {
          return model.setzeEinwilligung(true);
        }
      });
  return model;
}

class _StoryBundesstatistikRepository implements BundesstatistikRepository {
  _StoryBundesstatistikRepository(this._aggregat);

  /// `null`: Server nicht erreichbar.
  final Bundesaggregat? _aggregat;

  @override
  Future<void> sendeSnapshot(
    StammesSnapshot snapshot,
    InstallationCredentials credentials,
  ) async {}

  @override
  Future<Bundesaggregat> ladeBundesaggregat(
    InstallationCredentials credentials,
  ) async {
    final aggregat = _aggregat;
    if (aggregat == null) {
      throw const BundesstatistikException(BundesstatistikFehlerArt.netzwerk);
    }
    return aggregat;
  }
}

class _StoryCredentialsRepository implements InstallationCredentialsRepository {
  static const _credentials = InstallationCredentials(
    id: 'story',
    secret: 'story',
  );

  @override
  Future<InstallationCredentials> loadOrCreate() async => _credentials;

  @override
  Future<InstallationCredentials> regenerate() async => _credentials;

  @override
  Future<void> clear() async {}
}

class _StoryTeilnahmeRepository implements BundesstatistikTeilnahmeRepository {
  BundesstatistikTeilnahme _stored = BundesstatistikTeilnahme.leer;

  @override
  Future<BundesstatistikTeilnahme> load() async => _stored;

  @override
  Future<void> save(BundesstatistikTeilnahme teilnahme) async =>
      _stored = teilnahme;
}

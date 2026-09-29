import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nami/domain/arbeitskontext/arbeitskontext.dart';
import 'package:nami/domain/arbeitskontext/arbeitskontext_read_model.dart';
import 'package:nami/domain/bundesstatistik/bundesaggregat.dart';
import 'package:nami/domain/bundesstatistik/bundesstatistik_repository.dart';
import 'package:nami/domain/bundesstatistik/bundesstatistik_teilnahme.dart';
import 'package:nami/domain/bundesstatistik/installation_credentials.dart';
import 'package:nami/domain/bundesstatistik/stammes_snapshot.dart';
import 'package:nami/domain/member/mitglied.dart';
import 'package:nami/presentation/model/bundesstatistik_model.dart';
import 'package:nami/services/network_access_policy.dart';

class _FakeRepository implements BundesstatistikRepository {
  final List<(StammesSnapshot, InstallationCredentials)> sendungen = [];
  final List<InstallationCredentials> abrufe = [];
  final List<BundesstatistikException> sendeFehler = [];
  final List<BundesstatistikException> abrufFehler = [];
  Bundesaggregat aggregat = _aggregat();

  @override
  Future<void> sendeSnapshot(
    StammesSnapshot snapshot,
    InstallationCredentials credentials,
  ) async {
    if (sendeFehler.isNotEmpty) {
      throw sendeFehler.removeAt(0);
    }
    sendungen.add((snapshot, credentials));
  }

  @override
  Future<Bundesaggregat> ladeBundesaggregat(
    InstallationCredentials credentials,
  ) async {
    abrufe.add(credentials);
    if (abrufFehler.isNotEmpty) {
      throw abrufFehler.removeAt(0);
    }
    return aggregat;
  }
}

class _FakeCredentialsRepository implements InstallationCredentialsRepository {
  int generation = 1;

  InstallationCredentials get current => InstallationCredentials(
    id: 'install-$generation',
    secret: 'secret-$generation',
  );

  @override
  Future<InstallationCredentials> loadOrCreate() async => current;

  @override
  Future<InstallationCredentials> regenerate() async {
    generation++;
    return current;
  }

  @override
  Future<void> clear() async {}
}

class _MemoryTeilnahmeRepository implements BundesstatistikTeilnahmeRepository {
  BundesstatistikTeilnahme stored = BundesstatistikTeilnahme.leer;

  @override
  Future<BundesstatistikTeilnahme> load() async => stored;

  @override
  Future<void> save(BundesstatistikTeilnahme teilnahme) async {
    stored = teilnahme;
  }
}

class _BlockedNetworkAccessPolicy extends NetworkAccessPolicy {
  @override
  Future<NetworkAccessDecision> evaluateAccess({
    required String trigger,
    String feature = 'Netzwerk',
    bool allowMobileDataOverride = false,
  }) async => const NetworkAccessDecision.blocked(
    type: NetworkConnectionType.mobile,
    reason: NetworkAccessBlockedReason.noMobileDataEnabled,
    message: 'blockiert',
  );
}

Bundesaggregat _aggregat({
  BundesaggregatStatus status = BundesaggregatStatus.ok,
}) => Bundesaggregat(
  status: status,
  teilnehmendeStaemme: 8,
  mindestAnzahlStaemme: 5,
  hinweis: 'Annäherung',
  kennzahlen: const {
    'woelflinge.gesamt': KennzahlAggregat(summe: 80, stammAnzahl: 8, median: 9),
  },
);

ArbeitskontextReadModel _readModel({
  int layerId = 11,
  String layerTyp = 'Group::Stamm',
  bool rolesSindGeladen = true,
}) => ArbeitskontextReadModel(
  arbeitskontext: Arbeitskontext(
    aktiverLayer: ArbeitskontextLayer(
      id: layerId,
      name: 'Layer',
      layerTyp: layerTyp,
    ),
  ),
  rolesSindGeladen: rolesSindGeladen,
  mitglieder: <Mitglied>[
    Mitglied.peopleListItem(
      mitgliedsnummer: '1',
      vorname: 'A',
      nachname: 'B',
      gender: 'w',
    ),
  ],
  gruppen: <ArbeitskontextGruppe>[
    ArbeitskontextGruppe(
      id: layerId * 10,
      name: 'Meute',
      layerId: layerId,
      gruppenTyp: 'Group::StammGruppeWoelflinge',
    ),
  ],
  mitgliedsZuordnungen: <ArbeitskontextMitgliedsZuordnung>[
    ArbeitskontextMitgliedsZuordnung(
      mitgliedsnummer: '1',
      gruppenId: layerId * 10,
      rollenLabel: 'Mitglied',
    ),
  ],
);

void main() {
  late _FakeRepository repository;
  late _FakeCredentialsRepository credentials;
  late _MemoryTeilnahmeRepository teilnahme;
  late DateTime now;

  BundesstatistikModel buildModel({
    bool featureEnabled = true,
    NetworkAccessPolicy? networkAccessPolicy,
  }) => BundesstatistikModel(
    featureEnabled: featureEnabled,
    repository: repository,
    credentialsRepository: credentials,
    teilnahmeRepository: teilnahme,
    networkAccessPolicy: networkAccessPolicy,
    sendInterval: const Duration(days: 7),
    now: () => now,
  );

  Future<BundesstatistikModel> modelMitEinwilligung({
    ArbeitskontextReadModel? readModel,
  }) async {
    final model = buildModel();
    await model.initialize();
    await model.aktualisiereKontext(
      personId: '42',
      readModel: readModel ?? _readModel(),
      datenstand: now.subtract(const Duration(hours: 1)),
    );
    await model.setzeEinwilligung(true);
    return model;
  }

  setUp(() {
    repository = _FakeRepository();
    credentials = _FakeCredentialsRepository();
    teilnahme = _MemoryTeilnahmeRepository();
    now = DateTime.utc(2026, 6, 15, 10);
  });

  test('sendet und liest ohne Einwilligung nichts', () async {
    final model = buildModel();
    await model.initialize();
    await model.aktualisiereKontext(
      personId: '42',
      readModel: _readModel(),
      datenstand: now,
    );

    expect(model.status, BundesstatistikStatus.keineEinwilligung);
    expect(repository.sendungen, isEmpty);
    expect(repository.abrufe, isEmpty);
  });

  test('ist ohne konfigurierten Server nicht verfuegbar', () async {
    final model = buildModel(featureEnabled: false);
    await model.aktualisiereKontext(
      personId: '42',
      readModel: _readModel(),
      datenstand: now,
    );
    await model.setzeEinwilligung(true);

    expect(model.status, BundesstatistikStatus.nichtVerfuegbar);
    expect(repository.sendungen, isEmpty);
  });

  test(
    'sendet nach Einwilligung den Snapshot und laedt das Aggregat',
    () async {
      final model = await modelMitEinwilligung();

      expect(repository.sendungen, hasLength(1));
      final (snapshot, gesendetMit) = repository.sendungen.single;
      expect(snapshot.stammId, '11');
      expect(snapshot.senderId, 'install-1');
      expect(gesendetMit.secret, 'secret-1');
      expect(snapshot.kennzahlen.woelflinge.gesamt, 1);
      expect(snapshot.sourceDataAsOf, now.subtract(const Duration(hours: 1)));
      expect(model.status, BundesstatistikStatus.bereit);
      expect(model.aggregat?.teilnehmendeStaemme, 8);
      expect(model.zuletztGesendeterSnapshot?.stammId, '11');
      expect(
        jsonDecode(
          teilnahme.stored.zuletztGesendeterSnapshotJson!,
        )['sender_id'],
        'install-1',
      );
    },
  );

  test('sendet erst nach Ablauf des Intervalls erneut', () async {
    final model = await modelMitEinwilligung();

    now = now.add(const Duration(days: 3));
    await model.aktualisiereKontext(
      personId: '42',
      readModel: _readModel(),
      datenstand: now,
    );
    expect(repository.sendungen, hasLength(1));

    now = now.add(const Duration(days: 5));
    await model.aktualisiereKontext(
      personId: '42',
      readModel: _readModel(),
      datenstand: now,
    );
    expect(repository.sendungen, hasLength(2));
  });

  test('sendet sofort bei Wechsel auf einen anderen Stamm', () async {
    final model = await modelMitEinwilligung();

    await model.aktualisiereKontext(
      personId: '42',
      readModel: _readModel(layerId: 12),
      datenstand: now,
    );

    expect(repository.sendungen.map((s) => s.$1.stammId), ['11', '12']);
  });

  test('uebertraegt die Einwilligung nicht auf eine andere Person', () async {
    final model = await modelMitEinwilligung();

    await model.aktualisiereKontext(
      personId: '99',
      readModel: _readModel(),
      datenstand: now,
    );

    expect(model.hatEinwilligung, isFalse);
    expect(model.status, BundesstatistikStatus.keineEinwilligung);
    expect(model.aggregat, isNull);
  });

  test('sendet nichts ohne geladene Rollen oder fuer Nicht-Staemme', () async {
    var model = await modelMitEinwilligung(
      readModel: _readModel(rolesSindGeladen: false),
    );
    expect(model.status, BundesstatistikStatus.wartetAufDaten);
    expect(repository.sendungen, isEmpty);

    repository = _FakeRepository();
    teilnahme = _MemoryTeilnahmeRepository();
    model = await modelMitEinwilligung(
      readModel: _readModel(layerTyp: 'Group::Bezirk'),
    );
    expect(repository.sendungen, isEmpty);
  });

  test('stoppt nach Widerruf weitere Sendungen', () async {
    final model = await modelMitEinwilligung();

    await model.setzeEinwilligung(false);
    now = now.add(const Duration(days: 30));
    await model.aktualisiereKontext(
      personId: '42',
      readModel: _readModel(),
      datenstand: now,
    );

    expect(repository.sendungen, hasLength(1));
    expect(model.aggregat, isNull);
    expect(model.status, BundesstatistikStatus.keineEinwilligung);
    expect(teilnahme.stored.einwilligungFuer, isNull);
  });

  test('erzeugt bei ungueltigen Credentials neue und sendet erneut', () async {
    repository.sendeFehler.add(
      const BundesstatistikException(
        BundesstatistikFehlerArt.ungueltigeCredentials,
      ),
    );

    final model = await modelMitEinwilligung();

    expect(repository.sendungen.single.$1.senderId, 'install-2');
    expect(repository.abrufe.last.id, 'install-2');
    expect(model.status, BundesstatistikStatus.bereit);
  });

  test('sendet erneut, wenn der Server keine Teilnahme mehr kennt', () async {
    final model = await modelMitEinwilligung();
    repository.abrufFehler.add(
      const BundesstatistikException(BundesstatistikFehlerArt.nichtTeilnehmend),
    );

    await model.aktualisieren();

    expect(repository.sendungen, hasLength(2));
    expect(model.status, BundesstatistikStatus.bereit);
  });

  test('zeigt zu geringe Teilnahme an', () async {
    repository.aggregat = _aggregat(
      status: BundesaggregatStatus.zuWenigTeilnahme,
    );

    final model = await modelMitEinwilligung();

    expect(model.status, BundesstatistikStatus.zuWenigTeilnahme);
  });

  test('meldet Serverfehler, ohne die Einwilligung zu verlieren', () async {
    repository.sendeFehler.add(
      const BundesstatistikException(BundesstatistikFehlerArt.netzwerk),
    );

    final model = await modelMitEinwilligung();

    expect(model.status, BundesstatistikStatus.fehler);
    expect(model.hatEinwilligung, isTrue);
  });

  test('respektiert die Netzwerkrichtlinie', () async {
    final model = buildModel(
      networkAccessPolicy: _BlockedNetworkAccessPolicy(),
    );
    await model.aktualisiereKontext(
      personId: '42',
      readModel: _readModel(),
      datenstand: now,
    );
    await model.setzeEinwilligung(true);

    expect(repository.sendungen, isEmpty);
    expect(repository.abrufe, isEmpty);
  });

  test('verwendet nie einen Datenstand aus der Zukunft', () async {
    final model = buildModel();
    await model.aktualisiereKontext(
      personId: '42',
      readModel: _readModel(),
      datenstand: now.add(const Duration(days: 1)),
    );
    await model.setzeEinwilligung(true);

    expect(repository.sendungen.single.$1.sourceDataAsOf, now);
  });
}

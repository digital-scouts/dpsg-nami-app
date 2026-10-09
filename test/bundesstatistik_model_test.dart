import 'dart:async';

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
import 'package:nami/domain/bundesstatistik/statistik_abdeckung.dart';

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

  /// Haelt den naechsten Abruf an, bis der Future abgeschlossen ist.
  Future<void>? abrufSperre;

  @override
  Future<Bundesaggregat> ladeBundesaggregat(
    InstallationCredentials credentials,
  ) async {
    abrufe.add(credentials);
    final sperre = abrufSperre;
    abrufSperre = null;
    if (sperre != null) {
      await sperre;
    }
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

/// Gibt das Netz erst frei, wenn der Test es erlaubt; so laesst sich der
/// Kontext waehrend eines laufenden Syncs aendern.
class _GatedNetworkAccessPolicy extends NetworkAccessPolicy {
  final Completer<void> freigabe = Completer<void>();

  @override
  Future<NetworkAccessDecision> evaluateAccess({
    required String trigger,
    String feature = 'Netzwerk',
    bool allowMobileDataOverride = false,
  }) async {
    await freigabe.future;
    return const NetworkAccessDecision.allowed(
      type: NetworkConnectionType.wifi,
    );
  }
}

Bundesaggregat _aggregat({
  BundesaggregatStatus status = BundesaggregatStatus.ok,
}) => Bundesaggregat(
  status: status,
  teilnehmendeStaemmeUeber: 5,
  mindestAnzahlStaemme: 5,
  hinweis: 'Annäherung',
  kennzahlen: const {
    'woelflinge.gesamt': KennzahlAggregat(durchschnitt: 10, median: 9),
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
      abdeckung: const StatistikAbdeckung.stamm(),
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
      abdeckung: const StatistikAbdeckung.stamm(),
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
      abdeckung: const StatistikAbdeckung.stamm(),
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
      expect(model.aggregat?.teilnehmendeStaemmeUeber, 5);
      expect(model.zuletztGesendeterSnapshot?.stammId, '11');
      expect(
        jsonDecode(
          teilnahme.stored.sendestaende['11']!.snapshotJson!,
        )['sender_id'],
        'install-1',
      );
    },
  );

  test('sendet sofort neu, wenn sich die Abdeckung aendert', () async {
    final model = await modelMitEinwilligung();
    expect(repository.sendungen, hasLength(1));

    await model.aktualisiereKontext(
      personId: '42',
      readModel: _readModel(),
      datenstand: now.subtract(const Duration(hours: 1)),
      abdeckung: StatistikAbdeckung.gruppen({110}),
    );

    expect(repository.sendungen, hasLength(2));
    final snapshot = repository.sendungen.last.$1;
    expect(snapshot.kennzahlen.abdeckung, StatistikAbdeckung.gruppen({110}));
    expect(snapshot.toJson()['metrics'], isNull);
    expect(model.abdeckung, StatistikAbdeckung.gruppen({110}));

    // Gleiche Abdeckung erneut: kein weiterer Versand vor Ablauf des Intervalls.
    await model.aktualisiereKontext(
      personId: '42',
      readModel: _readModel(),
      datenstand: now,
      abdeckung: StatistikAbdeckung.gruppen({110}),
    );
    expect(repository.sendungen, hasLength(2));
  });

  test(
    'nimmt ohne lesbare Zahlen ohne Werte teil und darf trotzdem lesen',
    () async {
      // Leitung mit group_read, Hitobito liefert keine fremden Rollen.
      final ohneRollen = StatistikAbdeckung.gruppen(
        const <int>{},
        gruppenOhneRollen: {110},
      );
      final model = buildModel();
      await model.initialize();
      await model.aktualisiereKontext(
        personId: '42',
        readModel: _readModel(),
        datenstand: now.subtract(const Duration(hours: 1)),
        abdeckung: ohneRollen,
      );
      await model.setzeEinwilligung(true);

      expect(repository.sendungen, hasLength(1));
      final json = repository.sendungen.single.$1.toJson();
      expect(json['abdeckung'], 'gruppen');
      expect(json['metrics'], isNull);
      expect(json['gruppen'], [
        {'gruppe_id': '110', 'stufe': 'woelflinge', 'abgedeckt': false},
      ]);
      expect(repository.abrufe, hasLength(1));
      expect(model.status, BundesstatistikStatus.bereit);

      // Unveraenderte Rechte: kein erneuter Versand vor Ablauf des Intervalls.
      await model.aktualisiereKontext(
        personId: '42',
        readModel: _readModel(),
        datenstand: now,
        abdeckung: ohneRollen,
      );
      expect(repository.sendungen, hasLength(1));
    },
  );

  test('wartet ohne bekannte Abdeckung und sendet nichts', () async {
    final model = buildModel();
    await model.initialize();
    await model.aktualisiereKontext(
      personId: '42',
      readModel: _readModel(),
      datenstand: now,
      abdeckung: null,
    );
    await model.setzeEinwilligung(true);

    expect(model.status, BundesstatistikStatus.wartetAufDaten);
    expect(repository.sendungen, isEmpty);
  });

  test('sendet erst nach Ablauf des Intervalls erneut', () async {
    final model = await modelMitEinwilligung();

    now = now.add(const Duration(days: 3));
    await model.aktualisiereKontext(
      personId: '42',
      readModel: _readModel(),
      datenstand: now,
      abdeckung: const StatistikAbdeckung.stamm(),
    );
    expect(repository.sendungen, hasLength(1));

    now = now.add(const Duration(days: 5));
    await model.aktualisiereKontext(
      personId: '42',
      readModel: _readModel(),
      datenstand: now,
      abdeckung: const StatistikAbdeckung.stamm(),
    );
    expect(repository.sendungen, hasLength(2));
  });

  test(
    'sendet nach Wechsel sofort, sobald der neue Stamm freigegeben ist',
    () async {
      final model = await modelMitEinwilligung();

      await model.aktualisiereKontext(
        personId: '42',
        readModel: _readModel(layerId: 12),
        datenstand: now,
        abdeckung: const StatistikAbdeckung.stamm(),
      );
      expect(repository.sendungen.map((s) => s.$1.stammId), ['11']);

      await model.setzeEinwilligung(true);
      expect(repository.sendungen.map((s) => s.$1.stammId), ['11', '12']);
    },
  );

  test('uebertraegt die Einwilligung nicht auf eine andere Person', () async {
    final model = await modelMitEinwilligung();

    await model.aktualisiereKontext(
      personId: '99',
      readModel: _readModel(),
      datenstand: now,
      abdeckung: const StatistikAbdeckung.stamm(),
    );

    expect(model.hatEinwilligung, isFalse);
    expect(model.status, BundesstatistikStatus.keineEinwilligung);
    expect(model.aggregat, isNull);
  });

  test(
    'sendet nach Stammwechsel waehrend des Syncs nichts ohne Einwilligung',
    () async {
      await modelMitEinwilligung();
      repository = _FakeRepository();
      now = now.add(const Duration(days: 8));
      final netz = _GatedNetworkAccessPolicy();
      final model = buildModel(networkAccessPolicy: netz);
      await model.initialize();

      // Sync fuer Stamm 11 (mit Einwilligung) startet und wartet auf das Netz.
      final laufend = model.aktualisiereKontext(
        personId: '42',
        readModel: _readModel(),
        datenstand: now,
        abdeckung: const StatistikAbdeckung.stamm(),
      );
      await Future<void>.delayed(Duration.zero);
      // Wechsel in Stamm 12 ohne Einwilligung, bevor das Netz frei ist.
      await model.aktualisiereKontext(
        personId: '42',
        readModel: _readModel(layerId: 12),
        datenstand: now,
        abdeckung: const StatistikAbdeckung.stamm(),
      );
      netz.freigabe.complete();
      await laufend;

      expect(repository.sendungen, isEmpty);
      expect(model.hatEinwilligung, isFalse);
    },
  );

  test('verwirft ein Aggregat, das nach Widerruf eintrifft', () async {
    final model = await modelMitEinwilligung();
    final abruf = Completer<void>();
    repository.abrufSperre = abruf.future;

    final laufend = model.aktualisieren();
    await Future<void>.delayed(Duration.zero);
    await model.setzeEinwilligung(false);
    abruf.complete();
    await laufend;

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
      abdeckung: const StatistikAbdeckung.stamm(),
    );

    expect(repository.sendungen, hasLength(1));
    expect(model.aggregat, isNull);
    expect(model.status, BundesstatistikStatus.keineEinwilligung);
    expect(teilnahme.stored.einwilligungen, isEmpty);
  });

  test(
    'gilt je Stamm: ein anderer Stamm braucht eine eigene Einwilligung',
    () async {
      final model = await modelMitEinwilligung();
      expect(repository.sendungen, hasLength(1));

      await model.aktualisiereKontext(
        personId: '42',
        readModel: _readModel(layerId: 12),
        datenstand: now,
        abdeckung: const StatistikAbdeckung.stamm(),
      );
      expect(model.hatEinwilligung, isFalse);
      expect(model.status, BundesstatistikStatus.keineEinwilligung);
      expect(model.zuletztGesendeterSnapshot, isNull);
      expect(repository.sendungen, hasLength(1));

      await model.setzeEinwilligung(true);
      expect(repository.sendungen, hasLength(2));
      expect(repository.sendungen.last.$1.stammId, '12');

      // Zurueck zu Stamm 11: bereits freigegeben, innerhalb des Intervalls kein neues Senden.
      await model.aktualisiereKontext(
        personId: '42',
        readModel: _readModel(),
        datenstand: now,
        abdeckung: const StatistikAbdeckung.stamm(),
      );
      expect(model.hatEinwilligung, isTrue);
      expect(model.status, BundesstatistikStatus.bereit);
      expect(model.zuletztGesendeterSnapshot?.stammId, '11');
      expect(repository.sendungen, hasLength(2));

      // Widerruf betrifft nur den aktiven Stamm.
      await model.setzeEinwilligung(false);
      expect(teilnahme.stored.einwilligungen.keys, ['12']);
    },
  );

  test('kennt die Installations-ID erst nach dem ersten Senden', () async {
    final ohne = buildModel();
    await ohne.initialize();
    await ohne.ladeInstallationsId();
    expect(ohne.installationsId, isNull);

    final model = await modelMitEinwilligung();
    expect(model.installationsId, 'install-1');
    expect(model.stammName, isNotNull);

    final neuGestartet = buildModel();
    await neuGestartet.initialize();
    await neuGestartet.ladeInstallationsId();
    expect(neuGestartet.installationsId, 'install-1');
  });

  test('zeigt nach neuen Credentials die neue Installations-ID', () async {
    repository.sendeFehler.add(
      const BundesstatistikException(
        BundesstatistikFehlerArt.ungueltigeCredentials,
      ),
    );

    final model = await modelMitEinwilligung();

    expect(model.installationsId, 'install-2');
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

  test('unterscheidet abgelehnte Snapshots von Netzwerkfehlern', () async {
    repository.sendeFehler.add(
      const BundesstatistikException(
        BundesstatistikFehlerArt.abgelehnt,
        code: 'invalid_datetime',
      ),
    );

    final model = await modelMitEinwilligung();

    expect(model.status, BundesstatistikStatus.abgelehnt);
  });

  test('respektiert die Netzwerkrichtlinie', () async {
    final model = buildModel(
      networkAccessPolicy: _BlockedNetworkAccessPolicy(),
    );
    await model.aktualisiereKontext(
      personId: '42',
      readModel: _readModel(),
      datenstand: now,
      abdeckung: const StatistikAbdeckung.stamm(),
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
      abdeckung: const StatistikAbdeckung.stamm(),
    );
    await model.setzeEinwilligung(true);

    expect(repository.sendungen.single.$1.sourceDataAsOf, now);
  });

  test(
    'sendet nur mit einem hoechstens sieben Tage alten Datenstand',
    () async {
      Future<BundesstatistikModel> mitDatenstand(DateTime? datenstand) async {
        final model = buildModel();
        await model.aktualisiereKontext(
          personId: '42',
          readModel: _readModel(),
          datenstand: datenstand,
          abdeckung: const StatistikAbdeckung.stamm(),
        );
        await model.setzeEinwilligung(true);
        return model;
      }

      await mitDatenstand(null);
      await mitDatenstand(now.subtract(const Duration(days: 7, seconds: 1)));
      expect(repository.sendungen, isEmpty);

      await mitDatenstand(now.subtract(const Duration(days: 7)));
      expect(
        repository.sendungen.single.$1.sourceDataAsOf,
        now.subtract(const Duration(days: 7)),
      );
    },
  );
}

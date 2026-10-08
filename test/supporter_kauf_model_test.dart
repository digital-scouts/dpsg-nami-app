import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:nami/data/supporter/shared_prefs_supporter_kauf_repository.dart';
import 'package:nami/domain/appearance/appearance_catalog.dart';
import 'package:nami/domain/supporter/supporter_kauf_repository.dart';
import 'package:nami/domain/supporter/supporter_produkt.dart';
import 'package:nami/presentation/model/supporter_kauf_model.dart';
import 'package:nami/services/supporter/supporter_store_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeStoreClient implements SupporterStoreClient {
  final controller = StreamController<List<PurchaseDetails>>.broadcast();
  bool erreichbar = true;
  Set<String>? aktiv = {};
  final gekauft = <String>[];
  final abgeschlossen = <String>[];
  int wiederhergestellt = 0;

  @override
  Stream<List<PurchaseDetails>> get kaeufe => controller.stream;

  @override
  Future<bool> verfuegbar() async => erreichbar;

  @override
  Future<List<ProductDetails>> produkte(Set<String> ids) async => [
    for (final id in ids)
      ProductDetails(
        id: id,
        title: id,
        description: '',
        price: '2,99 €',
        rawPrice: 2.99,
        currencyCode: 'EUR',
      ),
  ];

  @override
  Future<void> kaufen(ProductDetails produkt) async => gekauft.add(produkt.id);

  @override
  Future<void> abschliessen(PurchaseDetails kauf) async =>
      abgeschlossen.add(kauf.productID);

  @override
  Future<void> wiederherstellen() async => wiederhergestellt++;

  @override
  Future<Set<String>?> aktiveProduktIds() async => aktiv;
}

PurchaseDetails _kauf(
  String id,
  PurchaseStatus status, {
  bool abschliessen = false,
}) => PurchaseDetails(
  productID: id,
  verificationData: PurchaseVerificationData(
    localVerificationData: '',
    serverVerificationData: '',
    source: 'test',
  ),
  transactionDate: null,
  status: status,
)..pendingCompletePurchase = abschliessen;

void main() {
  late _FakeStoreClient client;
  late InMemorySupporterKaufRepository repository;

  SupporterKaufModel buildModel() =>
      SupporterKaufModel(client: client, repository: repository);

  setUp(() {
    client = _FakeStoreClient();
    repository = InMemorySupporterKaufRepository();
  });

  test('laedt Produkte und uebernimmt laufende Kaeufe aus dem Store', () async {
    client.aktiv = {'supporter_paket_wald', 'unbekannt'};
    final model = buildModel();

    await model.start();

    expect(model.status, SupporterStoreStatus.bereit);
    expect(model.produkt(SupporterProdukt.foerderer)?.price, '2,99 €');
    expect(model.access.pakete, {SupporterPaket.wald});
    expect(model.access.foerderer, isFalse);
    expect((await repository.load()).pakete, {SupporterPaket.wald});
  });

  test('ohne Store bleibt der gespeicherte Stand erhalten', () async {
    repository = InMemorySupporterKaufRepository(
      const GekaufterSupportAccess(foerderer: true),
    );
    client.erreichbar = false;
    final model = buildModel();

    await model.start();

    expect(model.status, SupporterStoreStatus.nichtVerfuegbar);
    expect(model.access.foerderer, isTrue);
  });

  test('Store-Fehler bei der Abfrage nimmt nichts zurueck', () async {
    repository = InMemorySupporterKaufRepository(
      const GekaufterSupportAccess(foerderer: true),
    );
    client.aktiv = null;
    final model = buildModel();

    await model.start();

    expect(model.access.foerderer, isTrue);
  });

  test('abgelaufenes Abo wird beim Abgleich zurueckgenommen', () async {
    repository = InMemorySupporterKaufRepository(
      const GekaufterSupportAccess(
        foerderer: true,
        pakete: {SupporterPaket.lagerfeuer},
      ),
    );
    client.aktiv = {'supporter_paket_lagerfeuer'};
    final model = buildModel();

    await model.start();

    expect(model.access.foerderer, isFalse);
    expect(model.access.pakete, {SupporterPaket.lagerfeuer});
  });

  test('Kauf laeuft bis zur Bestaetigung und wird abgeschlossen', () async {
    final model = buildModel();
    await model.start();

    await model.kaufen(SupporterProdukt.foerderer);
    expect(client.gekauft, ['foerderer_jahr']);
    expect(model.laeuft(SupporterProdukt.foerderer), isTrue);

    client.controller.add([
      _kauf('foerderer_jahr', PurchaseStatus.purchased, abschliessen: true),
    ]);
    await pumpEventQueue();

    expect(model.laeuft(SupporterProdukt.foerderer), isFalse);
    expect(model.gekauft(SupporterProdukt.foerderer), isTrue);
    expect(model.access.qualifikationenFrei, isTrue);
    expect(client.abgeschlossen, ['foerderer_jahr']);
    expect((await repository.load()).foerderer, isTrue);
  });

  test('Abbruch und Fehler beenden den laufenden Kauf', () async {
    final model = buildModel();
    await model.start();

    await model.kaufen(SupporterProdukt.paketNachthimmel);
    client.controller.add([
      _kauf('supporter_paket_nachthimmel', PurchaseStatus.canceled),
    ]);
    await pumpEventQueue();
    expect(model.laeuft(SupporterProdukt.paketNachthimmel), isFalse);
    expect(model.fehler, isNull);

    await model.kaufen(SupporterProdukt.paketNachthimmel);
    client.controller.add([
      _kauf(
        'supporter_paket_nachthimmel',
        PurchaseStatus.error,
        abschliessen: true,
      ),
    ]);
    await pumpEventQueue();
    expect(model.laeuft(SupporterProdukt.paketNachthimmel), isFalse);
    expect(model.fehler, SupporterKaufFehler.kauf);
    expect(model.gekauft(SupporterProdukt.paketNachthimmel), isFalse);
    expect(client.abgeschlossen, ['supporter_paket_nachthimmel']);
  });

  test('Wiederherstellen uebernimmt den Store-Stand', () async {
    final model = buildModel();
    await model.start();
    client.aktiv = {'supporter_paket_wald', 'supporter_paket_nachthimmel'};

    await model.wiederherstellen();

    expect(client.wiederhergestellt, 1);
    expect(model.access.pakete, {
      SupporterPaket.wald,
      SupporterPaket.nachthimmel,
    });
    expect(model.fehler, isNull);
  });

  test('Wiederherstellen ohne Store meldet einen Fehler', () async {
    final model = buildModel();
    await model.start();
    client.aktiv = null;

    await model.wiederherstellen();

    expect(model.fehler, SupporterKaufFehler.wiederherstellen);
  });

  test('SharedPrefs-Repository speichert Pakete und Abo', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = SharedPrefsSupporterKaufRepository();
    expect((await prefs.load()).produkte, isEmpty);

    await prefs.save(
      GekaufterSupportAccess.ausProdukten({
        SupporterProdukt.foerderer,
        SupporterProdukt.paketWald,
      }),
    );

    final geladen = await prefs.load();
    expect(geladen.foerderer, isTrue);
    expect(geladen.pakete, {SupporterPaket.wald});
  });

  test('Produkt-IDs sind eindeutig und stabil', () {
    expect(SupporterProdukt.alleIds, {
      'supporter_paket_wald',
      'supporter_paket_lagerfeuer',
      'supporter_paket_nachthimmel',
      'foerderer_jahr',
    });
    for (final paket in SupporterPaket.values) {
      expect(
        SupporterProdukt.values.where((p) => p.paket == paket),
        hasLength(1),
      );
    }
  });
}

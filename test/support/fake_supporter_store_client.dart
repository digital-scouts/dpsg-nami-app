import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:nami/services/supporter/supporter_store_client.dart';

/// Store ohne Plattform: liefert Produkte zu [preise] und meldet [aktiv] als
/// laufende Kaeufe.
class FakeSupporterStoreClient implements SupporterStoreClient {
  FakeSupporterStoreClient({this.preise = const {}});

  /// Preis je Produkt-ID; fehlt sie, gilt 2,99 €.
  final Map<String, double> preise;
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
        price:
            '${(preise[id] ?? 2.99).toStringAsFixed(2).replaceAll('.', ',')} €',
        rawPrice: preise[id] ?? 2.99,
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

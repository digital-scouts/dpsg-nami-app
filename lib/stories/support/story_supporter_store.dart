import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:nami/domain/supporter/supporter_kauf_repository.dart';
import 'package:nami/domain/supporter/supporter_produkt.dart';
import 'package:nami/presentation/model/supporter_kauf_model.dart';
import 'package:nami/services/supporter/supporter_store_client.dart';

/// Store ohne Plattform fuer Stories: Pakete zum Einfuehrungspreis,
/// Förderer zum Normalpreis. Kaeufe bleiben „laufend“.
class StorySupporterStoreClient implements SupporterStoreClient {
  StorySupporterStoreClient({this.erreichbar = true, this.aktiv = const {}});

  final bool erreichbar;
  final Set<String> aktiv;

  @override
  Stream<List<PurchaseDetails>> get kaeufe => const Stream.empty();

  @override
  Future<bool> verfuegbar() async => erreichbar;

  @override
  Future<List<ProductDetails>> produkte(Set<String> ids) async => [
    for (final id in ids)
      ProductDetails(
        id: id,
        title: id,
        description: '',
        price: id == SupporterProdukt.foerderer.id ? '5,99 €' : '1,99 €',
        rawPrice: id == SupporterProdukt.foerderer.id ? 5.99 : 1.99,
        currencyCode: 'EUR',
      ),
  ];

  @override
  Future<void> kaufen(ProductDetails produkt) async {}

  @override
  Future<void> abschliessen(PurchaseDetails kauf) async {}

  @override
  Future<void> wiederherstellen() async {}

  @override
  Future<Set<String>?> aktiveProduktIds() async => aktiv;
}

/// Gestartetes Kauf-Model mit dem gegebenen Stand.
Future<SupporterKaufModel> storySupporterKaufModel({
  bool erreichbar = true,
  Set<SupporterProdukt> gekauft = const {},
}) async {
  final stand = GekaufterSupportAccess.ausProdukten(gekauft);
  final model = SupporterKaufModel(
    client: StorySupporterStoreClient(
      erreichbar: erreichbar,
      aktiv: {for (final p in gekauft) p.id},
    ),
    repository: InMemorySupporterKaufRepository(stand),
  );
  await model.start();
  return model;
}

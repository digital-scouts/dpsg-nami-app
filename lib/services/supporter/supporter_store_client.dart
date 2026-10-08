import 'dart:io';

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_storekit/store_kit_2_wrappers.dart';

/// Schmale Huelle um `in_app_purchase`, damit das Kauf-Model ohne Plattform
/// testbar bleibt.
abstract class SupporterStoreClient {
  Stream<List<PurchaseDetails>> get kaeufe;

  Future<bool> verfuegbar();

  Future<List<ProductDetails>> produkte(Set<String> ids);

  Future<void> kaufen(ProductDetails produkt);

  Future<void> abschliessen(PurchaseDetails kauf);

  /// Spielt die bestehenden Kaeufe erneut ueber [kaeufe] aus.
  Future<void> wiederherstellen();

  /// Produkt-IDs, die gerade gelten: gekaufte Pakete und laufende Abos.
  /// `null`, wenn der Store nicht erreichbar war.
  Future<Set<String>?> aktiveProduktIds();
}

class InAppPurchaseStoreClient implements SupporterStoreClient {
  InAppPurchaseStoreClient({DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final DateTime Function() _now;

  InAppPurchase get _iap => InAppPurchase.instance;

  @override
  Stream<List<PurchaseDetails>> get kaeufe => _iap.purchaseStream;

  @override
  Future<bool> verfuegbar() => _iap.isAvailable();

  @override
  Future<List<ProductDetails>> produkte(Set<String> ids) async {
    final antwort = await _iap.queryProductDetails(ids);
    if (antwort.error != null) {
      throw StateError(antwort.error!.message);
    }
    // Play liefert je Abo-Angebot einen Eintrag; der erste ist der Basisplan.
    final eindeutig = <String, ProductDetails>{};
    for (final details in antwort.productDetails) {
      eindeutig.putIfAbsent(details.id, () => details);
    }
    return eindeutig.values.toList();
  }

  @override
  Future<void> kaufen(ProductDetails produkt) async {
    // Abos laufen in in_app_purchase ebenfalls ueber buyNonConsumable.
    await _iap.buyNonConsumable(
      purchaseParam: PurchaseParam(productDetails: produkt),
    );
  }

  @override
  Future<void> abschliessen(PurchaseDetails kauf) =>
      _iap.completePurchase(kauf);

  @override
  Future<void> wiederherstellen() => _iap.restorePurchases();

  @override
  Future<Set<String>?> aktiveProduktIds() async {
    try {
      if (Platform.isAndroid) {
        return _aktiveAndroid();
      }
      if (Platform.isIOS) {
        return _aktiveIos();
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  /// Play liefert nur gekaufte Pakete und laufende Abos. Nicht bestaetigte
  /// Kaeufe erstattet Google nach drei Tagen, deshalb hier abschliessen.
  Future<Set<String>?> _aktiveAndroid() async {
    final addition = _iap
        .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
    final antwort = await addition.queryPastPurchases();
    if (antwort.error != null) {
      return null;
    }
    final ids = <String>{};
    for (final kauf in antwort.pastPurchases) {
      if (kauf.status != PurchaseStatus.purchased) {
        continue;
      }
      ids.add(kauf.productID);
      if (kauf.pendingCompletePurchase) {
        await _iap.completePurchase(kauf);
      }
    }
    return ids;
  }

  /// StoreKit 2 liefert alle verifizierten Transaktionen; Abos gelten bis
  /// zu ihrem Ablaufdatum.
  Future<Set<String>> _aktiveIos() async {
    final jetzt = _now().millisecondsSinceEpoch;
    final ids = <String>{};
    for (final transaktion in await SK2Transaction.transactions()) {
      final ablauf = int.tryParse(transaktion.expirationDate ?? '');
      if (ablauf == null || ablauf > jetzt) {
        ids.add(transaktion.productId);
      }
    }
    return ids;
  }
}

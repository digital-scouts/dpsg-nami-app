import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../domain/supporter/supporter_kauf_repository.dart';
import '../../domain/supporter/supporter_produkt.dart';
import '../../services/supporter/supporter_store_client.dart';

enum SupporterStoreStatus { laedt, bereit, nichtVerfuegbar }

enum SupporterKaufFehler { kauf, wiederherstellen }

/// Haelt Produkte, laufende Kaeufe und den Kaufstand aus dem Store. Der
/// zuletzt bestaetigte Stand liegt im [SupporterKaufRepository], damit
/// Freischaltungen offline erhalten bleiben; erst eine erfolgreiche
/// Store-Abfrage nimmt sie zurueck (z. B. abgelaufenes Abo).
class SupporterKaufModel extends ChangeNotifier {
  SupporterKaufModel({
    required SupporterStoreClient client,
    required SupporterKaufRepository repository,
    void Function(String message)? log,
  }) : _client = client,
       _repository = repository,
       _log = log;

  final SupporterStoreClient _client;
  final SupporterKaufRepository _repository;
  final void Function(String message)? _log;

  StreamSubscription<List<PurchaseDetails>>? _subscription;
  GekaufterSupportAccess _access = const GekaufterSupportAccess();
  SupporterStoreStatus _status = SupporterStoreStatus.laedt;
  Map<SupporterProdukt, ProductDetails> _produkte = const {};
  final Set<SupporterProdukt> _laufend = {};
  SupporterKaufFehler? _fehler;

  GekaufterSupportAccess get access => _access;
  SupporterStoreStatus get status => _status;
  SupporterKaufFehler? get fehler => _fehler;

  /// Store-Angaben (lokalisierter Preis, Titel) je Produkt, soweit geladen.
  ProductDetails? produkt(SupporterProdukt produkt) => _produkte[produkt];

  bool laeuft(SupporterProdukt produkt) => _laufend.contains(produkt);

  bool gekauft(SupporterProdukt produkt) => _access.produkte.contains(produkt);

  /// Hoert sofort auf den Kauf-Stream (Apple liefert offene Transaktionen
  /// direkt nach dem Start), laedt dann den gespeicherten Stand und fragt den
  /// Store ab.
  Future<void> start() async {
    _subscription ??= _client.kaeufe.listen(
      (kaeufe) => unawaited(_verarbeite(kaeufe)),
      onError: (Object error) => _log?.call('Kauf-Stream: $error'),
    );
    _access = await _repository.load();
    notifyListeners();
    await aktualisiere();
  }

  Future<void> aktualisiere() async {
    final verfuegbar = await _client.verfuegbar().catchError((Object _) {
      return false;
    });
    if (!verfuegbar) {
      _status = SupporterStoreStatus.nichtVerfuegbar;
      notifyListeners();
      return;
    }
    try {
      final details = await _client.produkte(SupporterProdukt.alleIds);
      _produkte = {for (final d in details) ?SupporterProdukt.vonId(d.id): d};
    } catch (error) {
      _log?.call('Produkte laden: $error');
    }
    await _uebernehmeAktive();
    _status = SupporterStoreStatus.bereit;
    notifyListeners();
  }

  Future<void> kaufen(SupporterProdukt produkt) async {
    final details = _produkte[produkt];
    if (details == null || _laufend.contains(produkt)) {
      return;
    }
    _laufend.add(produkt);
    _fehler = null;
    notifyListeners();
    try {
      await _client.kaufen(details);
    } catch (error) {
      _log?.call('Kauf starten: $error');
      _laufend.remove(produkt);
      _fehler = SupporterKaufFehler.kauf;
      notifyListeners();
    }
  }

  Future<void> wiederherstellen() async {
    _fehler = null;
    notifyListeners();
    try {
      await _client.wiederherstellen();
      if (!await _uebernehmeAktive()) {
        _fehler = SupporterKaufFehler.wiederherstellen;
      }
    } catch (error) {
      _log?.call('Wiederherstellen: $error');
      _fehler = SupporterKaufFehler.wiederherstellen;
    }
    notifyListeners();
  }

  Future<bool> _uebernehmeAktive() async {
    final ids = await _client.aktiveProduktIds();
    if (ids == null) {
      return false;
    }
    await _setze(
      GekaufterSupportAccess.ausProdukten(
        ids.map(SupporterProdukt.vonId).whereType<SupporterProdukt>(),
      ),
    );
    return true;
  }

  Future<void> _verarbeite(List<PurchaseDetails> kaeufe) async {
    for (final kauf in kaeufe) {
      final produkt = SupporterProdukt.vonId(kauf.productID);
      switch (kauf.status) {
        case PurchaseStatus.pending:
          if (produkt != null) {
            _laufend.add(produkt);
          }
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          if (produkt != null) {
            _laufend.remove(produkt);
            await _setze(
              GekaufterSupportAccess.ausProdukten({
                ..._access.produkte,
                produkt,
              }),
            );
          }
        case PurchaseStatus.error:
          _log?.call('Kauf fehlgeschlagen: ${kauf.error?.message}');
          _laufend.remove(produkt);
          _fehler = SupporterKaufFehler.kauf;
        case PurchaseStatus.canceled:
          _laufend.remove(produkt);
      }
      if (kauf.pendingCompletePurchase) {
        try {
          await _client.abschliessen(kauf);
        } catch (error) {
          _log?.call('Kauf abschliessen: $error');
        }
      }
    }
    notifyListeners();
  }

  Future<void> _setze(GekaufterSupportAccess access) async {
    if (setEquals(access.produkte, _access.produkte)) {
      return;
    }
    _access = access;
    await _repository.save(access);
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}

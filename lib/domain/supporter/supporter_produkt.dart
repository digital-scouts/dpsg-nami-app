import '../appearance/appearance_catalog.dart';
import '../appearance/support_access.dart';

/// Store-Produkte fuer Supporter-Kaeufe. Die IDs sind in App Store Connect
/// und der Play Console identisch angelegt und duerfen sich nie aendern:
/// Apple vergibt eine einmal genutzte Produkt-ID nicht erneut. Deshalb heisst
/// das Paket Waldsee im Store weiter `supporter_paket_wald`.
enum SupporterProdukt {
  paketWaldsee('supporter_paket_wald', paket: SupporterPaket.waldsee),
  paketLagerfeuer(
    'supporter_paket_lagerfeuer',
    paket: SupporterPaket.lagerfeuer,
  ),
  paketNachthimmel(
    'supporter_paket_nachthimmel',
    paket: SupporterPaket.nachthimmel,
  ),

  /// Auto-verlaengerndes Jahres-Abo (Apple: Abo-Gruppe „Foerderer“,
  /// Play: Basisplan `jahr`).
  foerderer('foerderer_jahr');

  const SupporterProdukt(this.id, {this.paket});

  final String id;

  /// Das freigeschaltete Paket; `null` beim Foerderer-Abo.
  final SupporterPaket? paket;

  bool get istAbo => this == SupporterProdukt.foerderer;

  static Set<String> get alleIds => {for (final p in values) p.id};

  static SupporterProdukt? vonId(String id) {
    for (final produkt in values) {
      if (produkt.id == id) {
        return produkt;
      }
    }
    return null;
  }
}

/// Zugang aus den gekauften bzw. laufenden Store-Produkten.
class GekaufterSupportAccess extends SupportAccess {
  const GekaufterSupportAccess({
    this.foerderer = false,
    this.pakete = const {},
  });

  factory GekaufterSupportAccess.ausProdukten(Iterable<SupporterProdukt> p) =>
      GekaufterSupportAccess(
        foerderer: p.contains(SupporterProdukt.foerderer),
        pakete: {
          for (final produkt in p)
            if (produkt.paket != null) produkt.paket!,
        },
      );

  @override
  final bool foerderer;

  @override
  final Set<SupporterPaket> pakete;

  Set<SupporterProdukt> get produkte => {
    if (foerderer) SupporterProdukt.foerderer,
    for (final produkt in SupporterProdukt.values)
      if (produkt.paket != null && pakete.contains(produkt.paket)) produkt,
  };
}

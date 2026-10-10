import 'veranstaltung.dart';

/// Welche Ebenen die Suche abdeckt.
enum EbenenFilter {
  /// Gruppen des aktiven Layers.
  meinStamm,

  /// Zusaetzlich die Gruppen der Layer darueber (Bezirk, Dioezese, Bund).
  meinStammUndDarueber,

  /// Alles, was Hitobito der Person zeigt, auch andere Staemme.
  alle,
}

enum ZeitraumFilter { vierWochen, dreiMonate, alleKommenden, eigener }

/// Auswahl in Chips und Filterfenster. Ebene und Zeitraum bestimmen die
/// Anfrage an Hitobito, der Rest wird lokal gefiltert.
class VeranstaltungsFilter {
  const VeranstaltungsFilter({
    this.art,
    this.nurAnmeldungOffen = false,
    this.ebene = EbenenFilter.alle,
    this.zeitraum = ZeitraumFilter.alleKommenden,
    this.eigenerVon,
    this.eigenerBis,
    this.kategorieId,
    this.suchtext = '',
  });

  /// `null` fuer alle Arten.
  final VeranstaltungsArt? art;
  final bool nurAnmeldungOffen;
  final EbenenFilter ebene;
  final ZeitraumFilter zeitraum;

  /// Nur bei [ZeitraumFilter.eigener].
  final DateTime? eigenerVon;
  final DateTime? eigenerBis;
  final int? kategorieId;
  final String suchtext;

  static const standard = VeranstaltungsFilter();

  /// Abweichungen vom Standard, die das Filterfenster setzt (ohne Art,
  /// Anmeldung und Suche, die direkt als Chip bzw. Suchfeld sichtbar sind).
  int get fensterAbweichungen =>
      (ebene != standard.ebene ? 1 : 0) +
      (zeitraum != standard.zeitraum ? 1 : 0) +
      (kategorieId != null ? 1 : 0);

  bool get istStandard =>
      art == null &&
      !nurAnmeldungOffen &&
      fensterAbweichungen == 0 &&
      suchtext.trim().isEmpty;

  /// Zeitraum der Anfrage relativ zu [heute]: `von` ist nie vor heute.
  ({DateTime von, DateTime? bis}) zeitraumAb(DateTime heute) {
    final tag = DateTime(heute.year, heute.month, heute.day);
    return switch (zeitraum) {
      ZeitraumFilter.vierWochen => (
        von: tag,
        bis: tag.add(const Duration(days: 28)),
      ),
      ZeitraumFilter.dreiMonate => (
        von: tag,
        bis: DateTime(tag.year, tag.month + 3, tag.day),
      ),
      ZeitraumFilter.alleKommenden => (von: tag, bis: null),
      ZeitraumFilter.eigener => (
        von: eigenerVon == null || eigenerVon!.isBefore(tag)
            ? tag
            : DateTime(eigenerVon!.year, eigenerVon!.month, eigenerVon!.day),
        bis: eigenerBis == null
            ? null
            : DateTime(eigenerBis!.year, eigenerBis!.month, eigenerBis!.day),
      ),
    };
  }

  VeranstaltungsFilter copyWith({
    Object? art = _unveraendert,
    bool? nurAnmeldungOffen,
    EbenenFilter? ebene,
    ZeitraumFilter? zeitraum,
    Object? eigenerVon = _unveraendert,
    Object? eigenerBis = _unveraendert,
    Object? kategorieId = _unveraendert,
    String? suchtext,
  }) {
    return VeranstaltungsFilter(
      art: identical(art, _unveraendert) ? this.art : art as VeranstaltungsArt?,
      nurAnmeldungOffen: nurAnmeldungOffen ?? this.nurAnmeldungOffen,
      ebene: ebene ?? this.ebene,
      zeitraum: zeitraum ?? this.zeitraum,
      eigenerVon: identical(eigenerVon, _unveraendert)
          ? this.eigenerVon
          : eigenerVon as DateTime?,
      eigenerBis: identical(eigenerBis, _unveraendert)
          ? this.eigenerBis
          : eigenerBis as DateTime?,
      kategorieId: identical(kategorieId, _unveraendert)
          ? this.kategorieId
          : kategorieId as int?,
      suchtext: suchtext ?? this.suchtext,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is VeranstaltungsFilter &&
      other.art == art &&
      other.nurAnmeldungOffen == nurAnmeldungOffen &&
      other.ebene == ebene &&
      other.zeitraum == zeitraum &&
      other.eigenerVon == eigenerVon &&
      other.eigenerBis == eigenerBis &&
      other.kategorieId == kategorieId &&
      other.suchtext == suchtext;

  @override
  int get hashCode => Object.hash(
    art,
    nurAnmeldungOffen,
    ebene,
    zeitraum,
    eigenerVon,
    eigenerBis,
    kategorieId,
    suchtext,
  );
}

const Object _unveraendert = Object();

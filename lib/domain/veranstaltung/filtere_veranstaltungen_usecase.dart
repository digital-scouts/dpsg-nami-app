import 'anmeldestatus.dart';
import 'veranstaltung.dart';
import 'veranstaltungs_filter.dart';

/// Filtert die geladenen Events lokal nach Art, Kategorie, Zeitraum,
/// Anmeldestatus und Suchtext und sortiert nach dem ersten Termin. Die
/// Ebene steckt bereits in der Anfrage an Hitobito.
class FiltereVeranstaltungenUseCase {
  const FiltereVeranstaltungenUseCase();

  static const _anmeldestatus = BestimmeAnmeldestatusUseCase();

  List<Veranstaltung> call(
    Iterable<Veranstaltung> veranstaltungen, {
    required VeranstaltungsFilter filter,
    required DateTime heute,
    Map<int, String> gruppenNamen = const <int, String>{},
  }) {
    final zeitraum = filter.zeitraumAb(heute);
    final bis = zeitraum.bis;
    final suchbegriffe = filter.suchtext
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((teil) => teil.isNotEmpty)
        .toList(growable: false);

    final treffer = <Veranstaltung>[];
    for (final veranstaltung in veranstaltungen) {
      final beginn = veranstaltung.beginn;
      final ende = veranstaltung.ende;
      if (beginn == null || ende == null) {
        continue;
      }
      if (ende.isBefore(zeitraum.von)) {
        continue;
      }
      if (bis != null && !beginn.isBefore(bis.add(const Duration(days: 1)))) {
        continue;
      }
      if (filter.art != null && veranstaltung.art != filter.art) {
        continue;
      }
      if (filter.kategorieId != null &&
          veranstaltung.kursart?.kategorie?.id != filter.kategorieId) {
        continue;
      }
      if (filter.nurAnmeldungOffen &&
          _anmeldestatus(veranstaltung, heute: heute).phase !=
              AnmeldePhase.offen) {
        continue;
      }
      if (suchbegriffe.isNotEmpty &&
          !_passtZuSuche(veranstaltung, suchbegriffe, gruppenNamen)) {
        continue;
      }
      treffer.add(veranstaltung);
    }

    treffer.sort((a, b) {
      final vergleich = a.beginn!.compareTo(b.beginn!);
      return vergleich != 0 ? vergleich : a.name.compareTo(b.name);
    });
    return treffer;
  }

  /// Jeder Suchbegriff muss in Name, Motto, Ort, Terminort, Gruppe oder
  /// Kursart vorkommen.
  bool _passtZuSuche(
    Veranstaltung veranstaltung,
    List<String> suchbegriffe,
    Map<int, String> gruppenNamen,
  ) {
    final kursart = veranstaltung.kursart;
    final text = <String?>[
      veranstaltung.name,
      veranstaltung.motto,
      veranstaltung.ort,
      for (final termin in veranstaltung.termine) termin.ort,
      for (final id in veranstaltung.gruppenIds) gruppenNamen[id],
      kursart?.label,
      kursart?.kurzname,
    ].whereType<String>().join(' ').toLowerCase();
    return suchbegriffe.every(text.contains);
  }
}

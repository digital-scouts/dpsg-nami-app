import 'qualifikation.dart';

/// Art einer Hitobito-Qualifikation (`qualification_kind`). Einen eigenen
/// Endpoint gibt es nicht; die Arten werden aus den Qualifikationen des
/// Arbeitskontexts abgeleitet und sind damit genau die, die jemand hat.
class HitobitoQualifikationsart {
  const HitobitoQualifikationsart({
    required this.id,
    required this.label,
    this.gueltigkeitJahre,
    this.reaktivierbar = false,
  });

  final int id;
  final String label;

  /// `null` bei Arten ohne Ablauf.
  final int? gueltigkeitJahre;
  final bool reaktivierbar;

  /// Eine Art je `artId`, nach Label sortiert. Eintraege ohne `artId` (alte
  /// Caches) bleiben aussen vor.
  static List<HitobitoQualifikationsart> ausQualifikationen(
    Iterable<Qualifikation> qualifikationen,
  ) {
    final arten = <int, HitobitoQualifikationsart>{};
    for (final qualifikation in qualifikationen) {
      final artId = qualifikation.artId;
      if (artId == null || arten.containsKey(artId)) {
        continue;
      }
      arten[artId] = HitobitoQualifikationsart(
        id: artId,
        label: qualifikation.label,
        gueltigkeitJahre: qualifikation.gueltigkeitJahre,
        reaktivierbar: qualifikation.reaktivierbar,
      );
    }
    return arten.values.toList(growable: false)
      ..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
  }

  @override
  bool operator ==(Object other) =>
      other is HitobitoQualifikationsart &&
      other.id == id &&
      other.label == label &&
      other.gueltigkeitJahre == gueltigkeitJahre &&
      other.reaktivierbar == reaktivierbar;

  @override
  int get hashCode => Object.hash(id, label, gueltigkeitJahre, reaktivierbar);

  @override
  String toString() =>
      'HitobitoQualifikationsart(id: $id, label: $label, '
      'gueltigkeitJahre: $gueltigkeitJahre)';
}

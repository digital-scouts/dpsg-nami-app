import '../stufe/arbeitskontext_stufen_mapping.dart';
import '../taetigkeit/stufe.dart';

class MemberFixedFilterGroups {
  const MemberFixedFilterGroups._();

  static const List<String> orderedGroupTypes = <String>[
    'Group::StammGruppeBiber',
    'Group::StammGruppeWoelflinge',
    'Group::StammGruppeJungpfadfinder',
    'Group::StammGruppePfadfinder',
    'Group::StammGruppeRover',
  ];

  static bool isSupportedGruppenTyp(String? gruppenTyp) {
    return stufeForGruppenTyp(gruppenTyp) != null;
  }

  static Stufe? stufeForGruppenTyp(String? gruppenTyp) {
    for (final regel in ArbeitskontextStufenMapping.regeln) {
      if (regel.passtZu(gruppenTyp: gruppenTyp)) {
        return regel.stufe;
      }
    }
    return null;
  }

  static int orderIndexForGruppenTyp(String? gruppenTyp) {
    final normalizedType = _normalize(gruppenTyp);
    for (var i = 0; i < orderedGroupTypes.length; i++) {
      if (_normalize(orderedGroupTypes[i]) == normalizedType) {
        return i;
      }
    }
    return orderedGroupTypes.length;
  }
}

String _normalize(String? value) {
  if (value == null) {
    return '';
  }

  return value
      .trim()
      .toLowerCase()
      .replaceAll('ä', 'ae')
      .replaceAll('ö', 'oe')
      .replaceAll('ü', 'ue')
      .replaceAll('ß', 'ss')
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

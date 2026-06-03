import '../taetigkeit/stufe.dart';

class ArbeitskontextStufenRegel {
  const ArbeitskontextStufenRegel({
    required this.gruppenTyp,
    required this.stufe,
  });

  final String gruppenTyp;
  final Stufe stufe;

  bool passtZu({required String? gruppenTyp}) {
    if (_normalisiereSchluessel(gruppenTyp) !=
        _normalisiereSchluessel(this.gruppenTyp)) {
      return false;
    }

    return true;
  }
}

class ArbeitskontextStufenMapping {
  const ArbeitskontextStufenMapping._();

  static const List<ArbeitskontextStufenRegel> regeln =
      <ArbeitskontextStufenRegel>[
        ArbeitskontextStufenRegel(
          gruppenTyp: 'Group::StammGruppeBiber',
          stufe: Stufe.biber,
        ),
        ArbeitskontextStufenRegel(
          gruppenTyp: 'Group::StammGruppeWoelflinge',
          stufe: Stufe.woelfling,
        ),
        ArbeitskontextStufenRegel(
          gruppenTyp: 'Group::StammGruppeJungpfadfinder',
          stufe: Stufe.jungpfadfinder,
        ),
        ArbeitskontextStufenRegel(
          gruppenTyp: 'Group::StammGruppePfadfinder',
          stufe: Stufe.pfadfinder,
        ),
        ArbeitskontextStufenRegel(
          gruppenTyp: 'Group::StammGruppeRover',
          stufe: Stufe.rover,
        ),
      ];
}

String _normalisiereSchluessel(String? value) {
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

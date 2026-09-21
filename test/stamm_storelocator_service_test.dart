import 'package:flutter_test/flutter_test.dart';
import 'package:nami/services/stamm_storelocator_service.dart';

void main() {
  test('parst Stammmarker aus XML und filtert Eintraege ohne Adressdaten', () {
    const xml = '''
<markers>
  <marker id="1" lat="51.0" lng="9.0" stammname="Echter Stamm" adresse="Musterstr. 1" ort="Kassel" plz="34117" www="https://example.org" />
  <marker id="2" lat="52.0" lng="10.0" stammname="Nur Ort" adresse="" ort="Hamburg" plz="20095" www="" />
  <marker id="3" lat="53.0" lng="11.0" stammname="Bezirk Nord" adresse="" ort="" plz="" www="" />
</markers>
''';

    final markers = StammStorelocatorService.parseMarkers(xml);

    expect(markers, hasLength(2));
    expect(markers[0].name, 'Echter Stamm');
    expect(markers[0].formattedAddress, 'Musterstr. 1, 34117 Kassel');
    expect(markers[1].name, 'Nur Ort');
    expect(markers[1].formattedAddress, '20095 Hamburg');
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:nami/domain/arbeitskontext/arbeitskontext.dart';

void main() {
  group('ArbeitskontextLayer', () {
    test('erzeugt einen gueltigen Layer mit optionalem Parent', () {
      const layer = ArbeitskontextLayer(
        id: 7,
        name: 'DPSG Stamm Musterdorf',
        parentLayerId: 3,
      );

      expect(layer.id, 7);
      expect(layer.name, 'DPSG Stamm Musterdorf');
      expect(layer.parentLayerId, 3);
      expect(layer.hatParentLayer, isTrue);
    });

    test('copyWith kann den Parent gezielt entfernen', () {
      const layer = ArbeitskontextLayer(
        id: 7,
        name: 'DPSG Stamm Musterdorf',
        parentLayerId: 3,
      );

      final copy = layer.copyWith(parentLayerLoeschen: true);

      expect(copy.parentLayerId, isNull);
      expect(copy.hatParentLayer, isFalse);
      expect(copy.id, layer.id);
      expect(copy.name, layer.name);
    });
  });

  group('Arbeitskontext', () {
    test('haelt genau einen aktiven Layer und andere verfuegbare Layer', () {
      const aktiverLayer = ArbeitskontextLayer(id: 10, name: 'Bezirk Rhein');
      const stammLayer = ArbeitskontextLayer(
        id: 11,
        name: 'Stamm Musterdorf',
        parentLayerId: 10,
      );

      final kontext = Arbeitskontext(
        aktiverLayer: aktiverLayer,
        verfuegbareLayer: const <ArbeitskontextLayer>[stammLayer],
      );

      expect(kontext.aktiverLayer, aktiverLayer);
      expect(kontext.verfuegbareLayer, const <ArbeitskontextLayer>[stammLayer]);
      expect(kontext.hatVerfuegbareLayer, isTrue);
    });

    test('entfernt den aktiven Layer aus den Wechselzielen', () {
      const aktiverLayer = ArbeitskontextLayer(id: 10, name: 'Bezirk Rhein');
      const weitererLayer = ArbeitskontextLayer(
        id: 11,
        name: 'Stamm Musterdorf',
      );

      final kontext = Arbeitskontext(
        aktiverLayer: aktiverLayer,
        verfuegbareLayer: const <ArbeitskontextLayer>[
          aktiverLayer,
          weitererLayer,
        ],
      );

      expect(kontext.verfuegbareLayer, const <ArbeitskontextLayer>[
        weitererLayer,
      ]);
    });

    test('normalisiert doppelte Layer-Ids in verfuegbaren Layern', () {
      const aktiverLayer = ArbeitskontextLayer(id: 10, name: 'Bezirk Rhein');
      const ersterStamm = ArbeitskontextLayer(id: 11, name: 'Stamm Musterdorf');
      const doppelterStamm = ArbeitskontextLayer(
        id: 11,
        name: 'Stamm Musterdorf Duplikat',
      );
      const dioezese = ArbeitskontextLayer(id: 12, name: 'Dioezese Koeln');

      final kontext = Arbeitskontext(
        aktiverLayer: aktiverLayer,
        verfuegbareLayer: const <ArbeitskontextLayer>[
          ersterStamm,
          doppelterStamm,
          dioezese,
        ],
      );

      expect(kontext.verfuegbareLayer, const <ArbeitskontextLayer>[
        ersterStamm,
        dioezese,
      ]);
    });

    test('findet aktiven und verfuegbaren Layer ueber die gemeinsame API', () {
      const aktiverLayer = ArbeitskontextLayer(id: 10, name: 'Bezirk Rhein');
      const weitererLayer = ArbeitskontextLayer(
        id: 11,
        name: 'Stamm Musterdorf',
      );

      final kontext = Arbeitskontext(
        aktiverLayer: aktiverLayer,
        verfuegbareLayer: const <ArbeitskontextLayer>[weitererLayer],
      );

      expect(kontext.enthaeltLayer(10), isTrue);
      expect(kontext.enthaeltLayer(11), isTrue);
      expect(kontext.enthaeltLayer(99), isFalse);
      expect(kontext.findeLayer(10), aktiverLayer);
      expect(kontext.findeLayer(11), weitererLayer);
      expect(kontext.findeLayer(99), isNull);
    });

    test('liefert unveraenderliche verfuegbare Layer', () {
      final kontext = Arbeitskontext(
        aktiverLayer: ArbeitskontextLayer(id: 10, name: 'Bezirk Rhein'),
        verfuegbareLayer: <ArbeitskontextLayer>[
          ArbeitskontextLayer(id: 11, name: 'Stamm Musterdorf'),
        ],
      );

      expect(
        () => kontext.verfuegbareLayer.add(
          const ArbeitskontextLayer(id: 12, name: 'Dioezese Koeln'),
        ),
        throwsUnsupportedError,
      );
    });

    test('dokumentiert die zentralen Fachregeln direkt im Domainmodell', () {
      expect(Arbeitskontext.sichtbarkeitsRegel, isNotEmpty);
      expect(Arbeitskontext.unterlayerRegel, isNotEmpty);
    });
  });
}

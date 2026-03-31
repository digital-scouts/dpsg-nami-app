import 'package:flutter_test/flutter_test.dart';
import 'package:nami/domain/arbeitskontext/arbeitskontext.dart';
import 'package:nami/domain/arbeitskontext/relevante_layer_input.dart';
import 'package:nami/domain/arbeitskontext/usecases/bestimme_relevante_layer_usecase.dart';

void main() {
  group('BestimmeRelevanteLayerUseCase', () {
    const useCase = BestimmeRelevanteLayerUseCase();

    test('layer_full macht genau einen Layer relevant', () {
      final result = useCase(
        RelevanteLayerInput(
          sichtbareLayer: const <ArbeitskontextLayer>[
            ArbeitskontextLayer(id: 10, name: 'Bezirk Rhein'),
            ArbeitskontextLayer(
              id: 11,
              name: 'Stamm Musterdorf',
              parentLayerId: 10,
            ),
          ],
          rollenRelevanzen: const <RollenRelevanzZuLayer>[
            RollenRelevanzZuLayer(
              layerId: 10,
              scope: RelevanterLayerScope.exactLayer,
            ),
          ],
        ),
      );

      expect(result, const <ArbeitskontextLayer>[
        ArbeitskontextLayer(id: 10, name: 'Bezirk Rhein'),
      ]);
    });

    test('layer_and_below_full macht Layer und Unterlayer relevant', () {
      final result = useCase(
        RelevanteLayerInput(
          sichtbareLayer: const <ArbeitskontextLayer>[
            ArbeitskontextLayer(id: 1, name: 'Bund'),
            ArbeitskontextLayer(id: 10, name: 'Bezirk Rhein', parentLayerId: 1),
            ArbeitskontextLayer(
              id: 11,
              name: 'Stamm Musterdorf',
              parentLayerId: 10,
            ),
            ArbeitskontextLayer(
              id: 12,
              name: 'Stamm Auenland',
              parentLayerId: 10,
            ),
          ],
          rollenRelevanzen: const <RollenRelevanzZuLayer>[
            RollenRelevanzZuLayer(
              layerId: 10,
              scope: RelevanterLayerScope.layerUndUnterlayer,
            ),
          ],
        ),
      );

      expect(
        result.map((layer) => layer.id).toList(growable: false),
        const <int>[10, 12, 11],
      );
    });

    test('group_and_below bleibt auf den einen Layer begrenzt', () {
      final result = useCase(
        RelevanteLayerInput(
          sichtbareLayer: const <ArbeitskontextLayer>[
            ArbeitskontextLayer(id: 10, name: 'Bezirk Rhein'),
            ArbeitskontextLayer(
              id: 11,
              name: 'Stamm Musterdorf',
              parentLayerId: 10,
            ),
          ],
          rollenRelevanzen: const <RollenRelevanzZuLayer>[
            RollenRelevanzZuLayer(
              layerId: 10,
              scope: RelevanterLayerScope.exactLayer,
            ),
          ],
        ),
      );

      expect(result, const <ArbeitskontextLayer>[
        ArbeitskontextLayer(id: 10, name: 'Bezirk Rhein'),
      ]);
    });

    test('liefert leer, wenn keine arbeitskontextrelevante Rolle vorliegt', () {
      final result = useCase(
        RelevanteLayerInput(
          sichtbareLayer: const <ArbeitskontextLayer>[
            ArbeitskontextLayer(id: 10, name: 'Bezirk Rhein'),
          ],
        ),
      );

      expect(result, isEmpty);
    });
  });
}

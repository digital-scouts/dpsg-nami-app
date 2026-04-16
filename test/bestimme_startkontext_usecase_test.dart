import 'package:flutter_test/flutter_test.dart';
import 'package:nami/domain/arbeitskontext/arbeitskontext.dart';
import 'package:nami/domain/arbeitskontext/startkontext_input.dart';
import 'package:nami/domain/arbeitskontext/usecases/bestimme_startkontext_usecase.dart';

void main() {
  group('BestimmeStartkontextUseCase', () {
    const useCase = BestimmeStartkontextUseCase();

    test(
      'verwendet primary_group direkt, wenn sie einem erreichbaren Layer entspricht',
      () {
        final input = StartkontextInput(
          primaryGroupId: 11,
          verfuegbareLayer: const <ArbeitskontextLayer>[
            ArbeitskontextLayer(id: 20, name: 'Bezirk Rhein'),
            ArbeitskontextLayer(id: 11, name: 'Stamm Musterdorf'),
          ],
        );

        final kontext = useCase(input);

        expect(
          kontext.aktiverLayer,
          const ArbeitskontextLayer(id: 11, name: 'Stamm Musterdorf'),
        );
        expect(kontext.verfuegbareLayer, const <ArbeitskontextLayer>[
          ArbeitskontextLayer(id: 20, name: 'Bezirk Rhein'),
        ]);
      },
    );

    test('loest primary_group ueber eine Gruppen-zu-Layer-Zuordnung auf', () {
      final input = StartkontextInput(
        primaryGroupId: 501,
        verfuegbareLayer: const <ArbeitskontextLayer>[
          ArbeitskontextLayer(id: 20, name: 'Bezirk Rhein'),
          ArbeitskontextLayer(id: 11, name: 'Stamm Musterdorf'),
        ],
        groupLayerZuordnungen: const <PrimaryGroupLayerZuordnung>[
          PrimaryGroupLayerZuordnung(groupId: 501, layerId: 11),
        ],
      );

      final kontext = useCase(input);

      expect(
        kontext.aktiverLayer,
        const ArbeitskontextLayer(id: 11, name: 'Stamm Musterdorf'),
      );
    });

    test(
      'faellt stabil auf den alphabetisch ersten erreichbaren Layer zurueck',
      () {
        final input = StartkontextInput(
          primaryGroupId: 999,
          verfuegbareLayer: const <ArbeitskontextLayer>[
            ArbeitskontextLayer(id: 30, name: 'Stamm Zebra'),
            ArbeitskontextLayer(id: 20, name: 'Bezirk Rhein'),
            ArbeitskontextLayer(id: 10, name: 'Dioezese Koeln'),
          ],
        );

        final kontext = useCase(input);

        expect(
          kontext.aktiverLayer,
          const ArbeitskontextLayer(id: 20, name: 'Bezirk Rhein'),
        );
        expect(kontext.verfuegbareLayer, const <ArbeitskontextLayer>[
          ArbeitskontextLayer(id: 10, name: 'Dioezese Koeln'),
          ArbeitskontextLayer(id: 30, name: 'Stamm Zebra'),
        ]);
      },
    );

    test('sortiert bei gleichem Namen stabil nach ID', () {
      final input = StartkontextInput(
        verfuegbareLayer: const <ArbeitskontextLayer>[
          ArbeitskontextLayer(id: 20, name: 'Stamm Alpha'),
          ArbeitskontextLayer(id: 10, name: 'Stamm Alpha'),
        ],
      );

      final kontext = useCase(input);

      expect(
        kontext.aktiverLayer,
        const ArbeitskontextLayer(id: 10, name: 'Stamm Alpha'),
      );
      expect(kontext.verfuegbareLayer, const <ArbeitskontextLayer>[
        ArbeitskontextLayer(id: 20, name: 'Stamm Alpha'),
      ]);
    });

    test('normalisiert doppelte Layer vor der Startkontext-Bestimmung', () {
      final input = StartkontextInput(
        verfuegbareLayer: const <ArbeitskontextLayer>[
          ArbeitskontextLayer(id: 11, name: 'Stamm Musterdorf'),
          ArbeitskontextLayer(id: 11, name: 'Stamm Musterdorf Duplikat'),
          ArbeitskontextLayer(id: 20, name: 'Bezirk Rhein'),
        ],
      );

      final kontext = useCase(input);

      expect(
        kontext.aktiverLayer,
        const ArbeitskontextLayer(id: 20, name: 'Bezirk Rhein'),
      );
      expect(kontext.verfuegbareLayer, const <ArbeitskontextLayer>[
        ArbeitskontextLayer(id: 11, name: 'Stamm Musterdorf'),
      ]);
    });

    test(
      'wirft einen klaren Fehler, wenn kein erreichbarer Layer vorhanden ist',
      () {
        expect(
          () => useCase(StartkontextInput()),
          throwsA(
            isA<StartkontextNichtBestimmbarError>().having(
              (error) => error.message,
              'message',
              'Es ist kein erreichbarer Layer fuer den Startkontext verfuegbar.',
            ),
          ),
        );
      },
    );
  });
}

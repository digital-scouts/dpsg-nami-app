import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:nami/data/arbeitskontext/secure_arbeitskontext_local_repository.dart';
import 'package:nami/domain/arbeitskontext/arbeitskontext.dart';
import 'package:nami/domain/arbeitskontext/arbeitskontext_read_model.dart';
import 'package:nami/domain/member/mitglied.dart';
import 'package:nami/services/sensitive_storage_service.dart';

void main() {
  late Directory tempDir;
  late SensitiveStorageService sensitiveStorageService;
  late SecureArbeitskontextLocalRepository repository;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
    tempDir = await Directory.systemTemp.createTemp(
      'arbeitskontext_local_repository_',
    );
    Hive.init(tempDir.path);
    sensitiveStorageService = SensitiveStorageService();
    repository = SecureArbeitskontextLocalRepository(
      sensitiveStorageService: sensitiveStorageService,
    );
  });

  tearDown(() async {
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test(
    'liefert null, wenn noch kein Arbeitskontext gespeichert wurde',
    () async {
      final cached = await repository.loadLastCached();

      expect(cached, isNull);
    },
  );

  test('speichert und laedt genau einen lokalen Arbeitskontext', () async {
    final readModel = _buildReadModel(
      aktiverLayerId: 11,
      aktiverLayerName: 'Stamm Musterdorf',
      verfuegbareLayer: const <ArbeitskontextLayer>[
        ArbeitskontextLayer(id: 20, name: 'Bezirk Rhein'),
      ],
      gruppen: const <ArbeitskontextGruppe>[
        ArbeitskontextGruppe(id: 101, name: 'Woelflinge', layerId: 11),
      ],
      mitglieder: <Mitglied>[
        Mitglied.peopleListItem(
          mitgliedsnummer: '1001',
          vorname: 'Anna',
          nachname: 'Beispiel',
        ),
      ],
    );

    await repository.saveCached(readModel);

    final cached = await repository.loadLastCached();

    expect(cached, readModel);
  });

  test('ersetzt den bisherigen lokalen Arbeitskontext vollstaendig', () async {
    final first = _buildReadModel(
      aktiverLayerId: 11,
      aktiverLayerName: 'Stamm Musterdorf',
      gruppen: const <ArbeitskontextGruppe>[
        ArbeitskontextGruppe(id: 101, name: 'Woelflinge', layerId: 11),
      ],
      mitglieder: <Mitglied>[
        Mitglied.peopleListItem(
          mitgliedsnummer: '1001',
          vorname: 'Anna',
          nachname: 'Beispiel',
        ),
      ],
    );
    final second = _buildReadModel(
      aktiverLayerId: 20,
      aktiverLayerName: 'Bezirk Rhein',
      verfuegbareLayer: const <ArbeitskontextLayer>[
        ArbeitskontextLayer(id: 11, name: 'Stamm Musterdorf'),
      ],
      gruppen: const <ArbeitskontextGruppe>[
        ArbeitskontextGruppe(id: 201, name: 'Bezirksteam', layerId: 20),
      ],
      mitglieder: <Mitglied>[
        Mitglied.peopleListItem(
          mitgliedsnummer: '2001',
          vorname: 'Ben',
          nachname: 'Beispiel',
        ),
      ],
    );

    await repository.saveCached(first);
    await repository.saveCached(second);

    final cached = await repository.loadLastCached();

    expect(cached, second);
    expect(cached, isNot(first));
    expect(cached?.findeMitglied('1001'), isNull);
    expect(cached?.findeGruppe(101), isNull);
  });

  test('kann den gespeicherten Arbeitskontext gezielt loeschen', () async {
    await repository.saveCached(
      _buildReadModel(aktiverLayerId: 11, aktiverLayerName: 'Stamm Musterdorf'),
    );

    await repository.clearCached();

    final cached = await repository.loadLastCached();
    expect(cached, isNull);
  });

  test(
    'purgeSensitiveData entfernt auch den lokalen Arbeitskontext-Cache',
    () async {
      await repository.saveCached(
        _buildReadModel(
          aktiverLayerId: 11,
          aktiverLayerName: 'Stamm Musterdorf',
        ),
      );

      await sensitiveStorageService.purgeSensitiveData();

      final cached = await repository.loadLastCached();
      expect(cached, isNull);
    },
  );
}

ArbeitskontextReadModel _buildReadModel({
  required int aktiverLayerId,
  required String aktiverLayerName,
  List<ArbeitskontextLayer> verfuegbareLayer = const <ArbeitskontextLayer>[],
  List<ArbeitskontextGruppe> gruppen = const <ArbeitskontextGruppe>[],
  List<Mitglied> mitglieder = const <Mitglied>[],
}) {
  return ArbeitskontextReadModel(
    arbeitskontext: Arbeitskontext(
      aktiverLayer: ArbeitskontextLayer(
        id: aktiverLayerId,
        name: aktiverLayerName,
      ),
      verfuegbareLayer: verfuegbareLayer,
    ),
    gruppen: gruppen,
    mitglieder: mitglieder,
  );
}

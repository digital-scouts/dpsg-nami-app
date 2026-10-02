import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:nami/data/arbeitskontext/secure_arbeitskontext_local_repository.dart';
import 'package:nami/domain/arbeitskontext/arbeitskontext.dart';
import 'package:nami/domain/arbeitskontext/arbeitskontext_read_model.dart';
import 'package:nami/domain/arbeitskontext/teildaten_stand.dart';
import 'package:nami/domain/member/efz_einsichtnahme.dart';
import 'package:nami/domain/member/mitglied.dart';
import 'package:nami/domain/qualifikation/qualifikation.dart';
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

  test('speichert EFZ und Qualifikationen fuer die Offline-Anzeige', () async {
    final readModel = ArbeitskontextReadModel(
      arbeitskontext: Arbeitskontext(
        aktiverLayer: const ArbeitskontextLayer(id: 11, name: 'Stamm'),
      ),
      efzStand: TeildatenStand.keineBerechtigung,
      efzEinsichtnahmen: <EfzEinsichtnahme>[
        EfzEinsichtnahme(
          id: 1,
          personId: 5,
          einsichtnehmerId: 9,
          einsichtOn: DateTime(2024, 3, 2),
          issuedOn: DateTime(2024, 2, 1),
        ),
      ],
      qualifikationenStand: TeildatenStand.geladen,
      qualifikationen: <Qualifikation>[
        Qualifikation(
          id: 2,
          personId: 5,
          artId: 7,
          label: 'Juleica',
          qualifiedAt: DateTime(2020, 5, 1),
          finishAt: DateTime(2023, 5, 1),
          origin: 'Kurs',
          reaktivierbar: true,
        ),
      ],
    );

    await repository.saveCached(readModel);

    expect(await repository.loadLastCached(), readModel);
  });

  test('liest aeltere Caches ohne EFZ als noch nicht synchronisiert', () async {
    await repository.saveCached(
      ArbeitskontextReadModel(
        arbeitskontext: Arbeitskontext(
          aktiverLayer: const ArbeitskontextLayer(id: 11, name: 'Stamm'),
        ),
      ),
    );

    final cached = await repository.loadLastCached();

    expect(cached?.efzStand, TeildatenStand.unbekannt);
    expect(cached?.qualifikationenStand, TeildatenStand.unbekannt);
    expect(cached?.efzEinsichtnahmen, isEmpty);
  });

  test('speichert und laedt genau einen lokalen Arbeitskontext', () async {
    final readModel = _buildReadModel(
      aktiverLayerId: 11,
      aktiverLayerName: 'Stamm Musterdorf',
      verfuegbareLayer: const <ArbeitskontextLayer>[
        ArbeitskontextLayer(
          id: 20,
          name: 'Bezirk Rhein',
          layerTyp: 'Group::Bezirk',
        ),
      ],
      gruppen: <ArbeitskontextGruppe>[
        const ArbeitskontextGruppe(
          id: 101,
          name: 'Woelflinge',
          layerId: 11,
          displayName: 'Fuechse',
          shortName: 'F',
          description: 'Wolfsstufe',
          gruppenTyp: 'Group::Meute',
          selfRegistrationUrl:
              'https://demo.hitobito.com/de/groups/101/self_registration',
        ).copyWith(
          createdAt: DateTime(2026, 4, 10, 3, 0, 29),
          updatedAt: DateTime(2026, 4, 11, 0, 45, 44),
        ),
      ],
      mitglieder: <Mitglied>[
        Mitglied(
          mitgliedsnummer: '1001',
          vorname: 'Anna',
          nachname: 'Beispiel',
          geburtsdatum: DateTime(2010, 4, 3),
          eintrittsdatum: DateTime(2021, 9, 1),
          updatedAt: DateTime(2024, 10, 11, 8, 45),
          pronoun: 'sie/ihr',
          emailAdressen: const <MitgliedKontaktEmail>[
            MitgliedKontaktEmail(
              wert: 'anna@example.org',
              label: Mitglied.primaryEmailLabel,
              istPrimaer: true,
            ),
            MitgliedKontaktEmail(
              wert: 'familie@example.org',
              label: Mitglied.secondaryEmailLabel,
            ),
          ],
          telefonnummern: const <MitgliedKontaktTelefon>[
            MitgliedKontaktTelefon(
              wert: '+49 170 1234567',
              label: Mitglied.phoneMobileLabel,
            ),
          ],
          adressen: const <MitgliedKontaktAdresse>[
            MitgliedKontaktAdresse(
              street: 'Musterweg',
              housenumber: '4',
              zipCode: '12345',
              town: 'Musterdorf',
              country: 'DE',
            ),
          ],
        ),
      ],
      mitgliedsZuordnungen: const <ArbeitskontextMitgliedsZuordnung>[
        ArbeitskontextMitgliedsZuordnung(
          mitgliedsnummer: '1001',
          gruppenId: 101,
          rollenTyp: 'Group::Leiter',
          rollenLabel: 'Leitung',
        ),
      ],
    );

    await repository.saveCached(readModel);

    final cached = await repository.loadLastCached();

    expect(cached, readModel);
  });

  test('speichert die Gruppen der uebergeordneten Layer mit', () async {
    final readModel = _buildReadModel(
      aktiverLayerId: 11,
      aktiverLayerName: 'Stamm Musterdorf',
    ).copyWith(uebergeordneteGruppenIds: const <int>[20, 201]);

    await repository.saveCached(readModel);
    final cached = await repository.loadLastCached();

    expect(cached?.uebergeordneteGruppenIds, <int>{20, 201});
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
  List<ArbeitskontextMitgliedsZuordnung> mitgliedsZuordnungen =
      const <ArbeitskontextMitgliedsZuordnung>[],
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
    mitgliedsZuordnungen: mitgliedsZuordnungen,
  );
}

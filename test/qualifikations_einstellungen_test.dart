import 'package:flutter_test/flutter_test.dart';
import 'package:nami/demo/demo_services.dart';
import 'package:nami/domain/qualifikation/personenkreis.dart';
import 'package:nami/domain/qualifikation/qualifikations_einstellungen.dart';
import 'package:nami/presentation/model/qualifikations_einstellungen_model.dart';

void main() {
  test('JSON-Rundlauf mit Arten, Reihenfolge und eigener Erinnerung', () {
    final einstellungen =
        const QualifikationsEinstellungen(
              reihenfolge: <String>['hitobito:14', 'efz'],
              eigene: EigeneQualifikationsErinnerung(
                arten: <String>{'efz'},
                tageVorher: 30,
              ),
            )
            .mitArt(
              'hitobito:14',
              const ArtEinstellung(
                angezeigt: false,
                personenkreis: Personenkreis.leitung,
                erinnerung: QualifikationsErinnerung(
                  tageVorher: 60,
                  vonWem: ErinnerungVonWem.alle,
                ),
              ),
            )
            .mitArt('efz', const ArtEinstellung(angezeigt: true));

    expect(
      QualifikationsEinstellungen.fromJson(einstellungen.toJson()),
      einstellungen,
    );
  });

  test('unbrauchbares JSON ergibt die Vorgaben', () {
    expect(
      QualifikationsEinstellungen.fromJson('kaputt'),
      const QualifikationsEinstellungen(),
    );
    expect(
      QualifikationsEinstellungen.fromJson(<String, dynamic>{
        'eigene': <String, dynamic>{'tage_vorher': 9999},
      }).eigene.tageVorher,
      QualifikationsErinnerung.maxTage,
    );
  });

  test('Vorgaben erkennen Praevention und Erste Hilfe am Namen', () {
    expect(QualifikationsVorgaben.istVorgabe('efz', 'egal'), isTrue);
    expect(
      QualifikationsVorgaben.istVorgabe('hitobito:1', 'Präventionsschulung'),
      isTrue,
    );
    expect(
      QualifikationsVorgaben.istVorgabe('hitobito:2', 'Erste-Hilfe-Kurs'),
      isTrue,
    );
    expect(
      QualifikationsVorgaben.istVorgabe('hitobito:3', 'Erste Hilfe am Kind'),
      isTrue,
    );
    expect(
      QualifikationsVorgaben.istVorgabe('hitobito:4', 'Woodbadge'),
      isFalse,
    );
    expect(
      QualifikationsVorgaben.erinnerung(
        'hitobito:1',
        'Präventionsschulung',
      ).vonWem,
      ErinnerungVonWem.alle,
    );
    expect(
      QualifikationsVorgaben.erinnerung(
        'hitobito:2',
        'Erste-Hilfe-Kurs',
      ).vonWem,
      ErinnerungVonWem.ich,
    );
  });

  test('Model speichert jede Aenderung sofort', () async {
    final repository = InMemoryQualifikationsEinstellungenRepository();
    final model = QualifikationsEinstellungenModel(repository);
    await model.load();

    await model.artAendern(
      'hitobito:3',
      (alt) => alt.copyWith(angezeigt: true),
    );

    expect((await repository.load()).art('hitobito:3').angezeigt, isTrue);
    expect(model.einstellungen.art('hitobito:3').angezeigt, isTrue);
  });
}

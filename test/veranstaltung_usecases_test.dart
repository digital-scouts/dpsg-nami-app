import 'package:flutter_test/flutter_test.dart';
import 'package:nami/domain/arbeitskontext/arbeitskontext.dart';
import 'package:nami/domain/arbeitskontext/arbeitskontext_read_model.dart';
import 'package:nami/domain/veranstaltung/anmeldestatus.dart';
import 'package:nami/domain/veranstaltung/bestimme_suchgruppen_usecase.dart';
import 'package:nami/domain/veranstaltung/filtere_veranstaltungen_usecase.dart';
import 'package:nami/domain/veranstaltung/veranstaltung.dart';
import 'package:nami/domain/veranstaltung/veranstaltungs_filter.dart';

final _heute = DateTime(2026, 10, 10, 9);

Veranstaltung _event({
  required int id,
  required DateTime beginn,
  DateTime? ende,
  VeranstaltungsArt art = VeranstaltungsArt.veranstaltung,
  String name = 'Aktion',
  DateTime? ab,
  DateTime? bis,
  int? max,
  int? belegt,
  Kursart? kursart,
  List<int> gruppen = const [12],
  String? ort,
}) => Veranstaltung(
  id: id,
  art: art,
  name: name,
  termine: [VeranstaltungsTermin(beginn: beginn, ende: ende)],
  gruppenIds: gruppen,
  anmeldungAb: ab,
  anmeldungBis: bis,
  maxTeilnehmende: max,
  teilnehmende: belegt,
  kursart: kursart,
  ort: ort,
);

void main() {
  group('BestimmeAnmeldestatusUseCase', () {
    const status = BestimmeAnmeldestatusUseCase();
    final beginn = DateTime(2026, 11, 14);

    test('offen bis einschliesslich Schlusstag', () {
      final event = _event(
        id: 1,
        beginn: beginn,
        ab: DateTime(2026, 9, 20),
        bis: DateTime(2026, 10, 10),
      );
      final ergebnis = status(event, heute: _heute);
      expect(ergebnis.phase, AnmeldePhase.offen);
      expect(ergebnis.bis, DateTime(2026, 10, 10));
    });

    test('bald offen, geschlossen und unbekannt', () {
      expect(
        status(
          _event(id: 1, beginn: beginn, ab: DateTime(2026, 10, 31)),
          heute: _heute,
        ).phase,
        AnmeldePhase.baldOffen,
      );
      expect(
        status(
          _event(id: 1, beginn: beginn, bis: DateTime(2026, 10, 9)),
          heute: _heute,
        ).phase,
        AnmeldePhase.geschlossen,
      );
      expect(
        status(_event(id: 1, beginn: beginn), heute: _heute).phase,
        AnmeldePhase.unbekannt,
      );
    });

    test('Plaetze nur mit Maximum und Belegung, nie negativ', () {
      expect(
        status(
          _event(id: 1, beginn: beginn, max: 12, belegt: 4),
          heute: _heute,
        ).freiePlaetze,
        8,
      );
      final voll = status(
        _event(id: 1, beginn: beginn, max: 10, belegt: 12),
        heute: _heute,
      );
      expect(voll.freiePlaetze, 0);
      expect(voll.ausgebucht, isTrue);
      expect(
        status(
          _event(id: 1, beginn: beginn, max: 10),
          heute: _heute,
        ).freiePlaetze,
        isNull,
      );
    });
  });

  group('FiltereVeranstaltungenUseCase', () {
    const filtere = FiltereVeranstaltungenUseCase();
    const ausbildung = KursartKategorie(id: 1, label: 'Ausbildung');
    const glk = Kursart(
      id: 1,
      label: 'Gruppenleitungskurs',
      kurzname: 'GLK',
      kategorie: ausbildung,
    );
    final events = [
      _event(
        id: 3,
        name: 'Bundeskurs',
        art: VeranstaltungsArt.kurs,
        kursart: glk,
        beginn: DateTime(2026, 12, 9),
        ab: DateTime(2026, 9, 30),
        bis: DateTime(2026, 11, 19),
        gruppen: const [1],
      ),
      _event(
        id: 1,
        name: 'Pfingstaktion',
        beginn: DateTime(2026, 10, 24, 10),
        bis: DateTime(2026, 10, 20),
        ort: 'Stammesheim',
      ),
      _event(
        id: 2,
        name: 'Kinoabend',
        beginn: DateTime(2026, 10, 30, 19),
        ab: DateTime(2026, 11, 1),
      ),
      // Begonnen, aber noch nicht vorbei: bleibt sichtbar.
      _event(
        id: 4,
        name: 'Lager',
        beginn: DateTime(2026, 10, 8),
        ende: DateTime(2026, 10, 11),
      ),
      _event(id: 5, name: 'Vorbei', beginn: DateTime(2026, 10, 1)),
    ];

    List<int> ids(VeranstaltungsFilter filter, {Map<int, String>? namen}) =>
        filtere(
          events,
          filter: filter,
          heute: _heute,
          gruppenNamen: namen ?? const {},
        ).map((v) => v.id).toList();

    test('sortiert nach erstem Termin und laesst Vergangenes weg', () {
      expect(ids(VeranstaltungsFilter.standard), [4, 1, 2, 3]);
    });

    test('Art, Kategorie und Anmeldung offen', () {
      expect(ids(const VeranstaltungsFilter(art: VeranstaltungsArt.kurs)), [3]);
      expect(
        ids(const VeranstaltungsFilter(art: VeranstaltungsArt.veranstaltung)),
        [4, 1, 2],
      );
      expect(ids(const VeranstaltungsFilter(kategorieId: 1)), [3]);
      expect(ids(const VeranstaltungsFilter(nurAnmeldungOffen: true)), [1, 3]);
    });

    test('Zeitraum begrenzt nach dem Beginn', () {
      expect(
        ids(const VeranstaltungsFilter(zeitraum: ZeitraumFilter.vierWochen)),
        [4, 1, 2],
      );
      expect(
        ids(
          VeranstaltungsFilter(
            zeitraum: ZeitraumFilter.eigener,
            eigenerVon: DateTime(2026, 10, 25),
            eigenerBis: DateTime(2026, 10, 30),
          ),
        ),
        [2],
      );
    });

    test('Suche ueber Name, Ort, Kursart und Gruppenname', () {
      expect(ids(const VeranstaltungsFilter(suchtext: 'stammes')), [1]);
      expect(ids(const VeranstaltungsFilter(suchtext: 'GLK')), [3]);
      expect(
        ids(
          const VeranstaltungsFilter(suchtext: 'bundes ebene'),
          namen: {1: 'Bundesebene'},
        ),
        [3],
      );
      expect(ids(const VeranstaltungsFilter(suchtext: 'nichts')), isEmpty);
    });
  });

  group('BestimmeSuchgruppenUseCase', () {
    const suchgruppen = BestimmeSuchgruppenUseCase();
    final readModel = ArbeitskontextReadModel(
      arbeitskontext: Arbeitskontext(
        aktiverLayer: const ArbeitskontextLayer(
          id: 12,
          name: 'Stamm Fuchsbau',
          parentLayerId: 11,
        ),
        verfuegbareLayer: const [
          ArbeitskontextLayer(
            id: 12,
            name: 'Stamm Fuchsbau',
            parentLayerId: 11,
          ),
          ArbeitskontextLayer(id: 11, name: 'Bezirk', parentLayerId: 3),
          ArbeitskontextLayer(id: 3, name: 'Diözese', parentLayerId: 1),
        ],
      ),
      gruppen: const [
        ArbeitskontextGruppe(id: 13, name: 'Mitglieder', layerId: 12),
        ArbeitskontextGruppe(id: 20, name: 'Wölflinge', layerId: 12),
      ],
      uebergeordneteGruppenIds: const [11, 40],
    );

    test('alle sichtbaren ohne Gruppenfilter', () {
      expect(suchgruppen(readModel, EbenenFilter.alle), isNull);
      expect(suchgruppen(null, EbenenFilter.meinStamm), isNull);
    });

    test('eigene Ebene mit Layer und Gruppen', () {
      expect(suchgruppen(readModel, EbenenFilter.meinStamm), {12, 13, 20});
    });

    test('und darueber mit uebergeordneten Gruppen und Layer-Kette', () {
      expect(suchgruppen(readModel, EbenenFilter.meinStammUndDarueber), {
        12,
        13,
        20,
        11,
        40,
        3,
        1,
      });
    });
  });
}

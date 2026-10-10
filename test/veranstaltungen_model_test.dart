import 'package:flutter_test/flutter_test.dart';
import 'package:nami/domain/arbeitskontext/arbeitskontext.dart';
import 'package:nami/domain/arbeitskontext/arbeitskontext_read_model.dart';
import 'package:nami/domain/auth/auth_session.dart';
import 'package:nami/domain/veranstaltung/veranstaltung.dart';
import 'package:nami/domain/veranstaltung/veranstaltungs_filter.dart';
import 'package:nami/presentation/model/veranstaltungen_model.dart';
import 'package:nami/services/hitobito_auth_env.dart';
import 'package:nami/services/hitobito_events_service.dart';
import 'package:nami/services/network_access_policy.dart';

class _FakeService extends HitobitoEventsService {
  _FakeService()
    : super(
        config: HitobitoAuthConfig.fromBaseUrl(
          clientId: 'c',
          clientSecret: 's',
          baseUrl: 'https://demo.hitobito.com',
          redirectUri: 'de.jlange.nami.app:/oauth/callback',
          scopeString: 'api',
        ),
      );

  final List<Set<int>?> listenAnfragen = [];
  final List<Set<int>> namenAnfragen = [];
  Object? fehler;
  List<Veranstaltung> antwort = const [];

  @override
  Future<List<Veranstaltung>> fetchVeranstaltungen(
    String accessToken, {
    required DateTime abTag,
    Set<int>? gruppenIds,
  }) async {
    listenAnfragen.add(gruppenIds);
    final fehler = this.fehler;
    if (fehler != null) {
      throw fehler;
    }
    return antwort;
  }

  @override
  Future<Map<int, String>> fetchGruppenNamen(
    String accessToken,
    Set<int> gruppenIds,
  ) async {
    namenAnfragen.add(gruppenIds);
    return {for (final id in gruppenIds) id: 'Gruppe $id'};
  }

  @override
  Future<Veranstaltung> fetchVeranstaltung(
    String accessToken, {
    required int id,
  }) async => antwort.firstWhere((v) => v.id == id);
}

Veranstaltung _event(int id, int gruppe, {int tage = 5}) => Veranstaltung(
  id: id,
  art: VeranstaltungsArt.veranstaltung,
  name: 'Event $id',
  gruppenIds: [gruppe],
  termine: [VeranstaltungsTermin(beginn: DateTime(2026, 10, 10 + tage))],
);

void main() {
  late _FakeService service;
  late DateTime jetzt;
  late int generation;
  late bool sitzungFehlt;
  late VeranstaltungenModel model;

  final readModel = ArbeitskontextReadModel(
    arbeitskontext: Arbeitskontext(
      aktiverLayer: const ArbeitskontextLayer(id: 12, name: 'Stamm Fuchsbau'),
      verfuegbareLayer: const [
        ArbeitskontextLayer(id: 12, name: 'Stamm Fuchsbau'),
      ],
    ),
    gruppen: const [
      ArbeitskontextGruppe(id: 13, name: 'Wölflinge', layerId: 12),
    ],
  );

  setUp(() {
    service = _FakeService()..antwort = [_event(1, 12), _event(2, 11)];
    jetzt = DateTime(2026, 10, 10, 9);
    generation = 1;
    sitzungFehlt = false;
    model = VeranstaltungenModel(
      service: service,
      remoteAccessExecutor: <T>({required trigger, required action}) async {
        if (sitzungFehlt) {
          return null;
        }
        return action(
          AuthSession(accessToken: 'token', receivedAt: DateTime(2026)),
        );
      },
      readModel: () => readModel,
      sessionGeneration: () => generation,
      jetzt: () => jetzt,
    );
  });

  test('laedt alle sichtbaren und ergaenzt fremde Gruppennamen', () async {
    await model.laden();

    expect(model.zustand, VeranstaltungenLadezustand.geladen);
    expect(service.listenAnfragen, [null]);
    expect(model.treffer.map((v) => v.id), [1, 2]);
    // Stamm Fuchsbau kennt der Arbeitskontext, Gruppe 11 wird nachgeladen.
    expect(service.namenAnfragen, [
      {11},
    ]);
    expect(model.veranstalter(model.treffer.first), 'Stamm Fuchsbau');
    expect(model.veranstalter(model.treffer.last), 'Gruppe 11');
  });

  test('nutzt den Cache und laedt nach Ablauf oder erzwungen neu', () async {
    await model.laden();
    await model.laden();
    expect(service.listenAnfragen, hasLength(1));

    await model.laden(erzwingen: true);
    expect(service.listenAnfragen, hasLength(2));

    jetzt = jetzt.add(VeranstaltungenModel.cacheDauer);
    await model.laden();
    expect(service.listenAnfragen, hasLength(3));
  });

  test('Ebenenwechsel laedt mit Gruppenfilter, lokale Filter nicht', () async {
    await model.laden();
    model.setzeFilter(model.filter.copyWith(nurAnmeldungOffen: true));
    await Future<void>.delayed(Duration.zero);
    expect(service.listenAnfragen, hasLength(1));

    model.setzeFilter(model.filter.copyWith(ebene: EbenenFilter.meinStamm));
    await Future<void>.delayed(Duration.zero);
    expect(service.listenAnfragen.last, {12, 13});
  });

  test('Trefferzahl nur fuer geladene Ebenen', () async {
    await model.laden();
    expect(
      model.trefferAnzahl(model.filter.copyWith(art: VeranstaltungsArt.kurs)),
      0,
    );
    expect(
      model.trefferAnzahl(model.filter.copyWith(ebene: EbenenFilter.meinStamm)),
      isNull,
    );
  });

  test('offline, Anmeldung noetig und Fehler', () async {
    service.fehler = const NetworkAccessBlockedException(
      reason: NetworkAccessBlockedReason.offline,
      connectionType: NetworkConnectionType.offline,
      message: 'offline',
    );
    await model.laden();
    expect(model.zustand, VeranstaltungenLadezustand.offline);

    service.fehler = const HitobitoEventsException('kaputt', statusCode: 500);
    await model.laden();
    expect(model.zustand, VeranstaltungenLadezustand.fehler);

    service.fehler = null;
    sitzungFehlt = true;
    await model.laden();
    expect(model.zustand, VeranstaltungenLadezustand.anmeldungNoetig);
  });

  test('neue Sitzung verwirft Ergebnisse und Filter', () async {
    model.setzeFilter(model.filter.copyWith(art: VeranstaltungsArt.kurs));
    await model.laden();
    expect(model.geladenAnzahl, 2);

    generation = 2;
    model.sitzungPruefen();

    expect(model.geladenAnzahl, 0);
    expect(model.filter, VeranstaltungsFilter.standard);
    expect(model.zustand, VeranstaltungenLadezustand.initial);
  });

  test('Detail wird einmal geladen', () async {
    await model.laden();
    final detail = await model.ladeDetail(2);
    expect(detail?.id, 2);
    expect(model.detail(2), same(detail));
  });
}

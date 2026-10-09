import 'package:flutter_test/flutter_test.dart';
import 'package:nami/data/statistiks/shared_prefs_statistik_verlauf_repository.dart';
import 'package:nami/domain/statistiks/berechne_stamm_statistik_usecase.dart';
import 'package:nami/domain/statistiks/statistik_verlauf.dart';
import 'package:nami/domain/arbeitskontext/arbeitskontext_read_model.dart';
import 'package:nami/domain/bundesstatistik/statistik_abdeckung.dart';
import 'package:nami/domain/taetigkeit/stufe.dart';
import 'package:nami/services/statistik_verlauf_service.dart';
import 'package:nami/stories/store/store_showcase_data.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final heute = DateTime(2026, 9, 30);
  final statistik = const BerechneStammStatistikUseCase()(
    StoreShowcaseData.readModel(today: heute),
    heute: heute,
  );

  test('zeichnet je Monat genau einmal auf', () async {
    final repo = InMemoryStatistikVerlaufRepository();
    final aufzeichnen = ZeichneStatistikVerlaufAufUseCase(repo);

    expect(
      await aufzeichnen(layerId: 1, statistik: statistik, heute: heute),
      isTrue,
    );
    expect(
      await aufzeichnen(
        layerId: 1,
        statistik: statistik,
        heute: DateTime(2026, 9, 1),
      ),
      isFalse,
    );
    expect(
      await aufzeichnen(
        layerId: 1,
        statistik: statistik,
        heute: DateTime(2026, 10, 2),
      ),
      isTrue,
    );

    final eintraege = await repo.loadForLayer(1);
    expect(eintraege.map((e) => e.monat), ['2026-09', '2026-10']);
    expect(eintraege.first.personen, 26);
    expect(eintraege.first.jeStufe[Stufe.woelfling], 6);
    expect(await repo.loadForLayer(2), isEmpty);
  });

  test('behält höchstens 24 Monate', () async {
    final repo = InMemoryStatistikVerlaufRepository();
    final aufzeichnen = ZeichneStatistikVerlaufAufUseCase(repo);
    for (var i = 0; i < 30; i++) {
      await aufzeichnen(
        layerId: 1,
        statistik: statistik,
        heute: DateTime(2024, 1 + i, 15),
      );
    }
    final eintraege = await repo.loadForLayer(1);
    expect(eintraege, hasLength(ZeichneStatistikVerlaufAufUseCase.maxMonate));
    expect(eintraege.first.monat, '2024-07');
    expect(eintraege.last.monat, '2026-06');
  });

  test('SharedPreferences: Speichern, Laden, kaputte Werte', () async {
    SharedPreferences.setMockInitialValues({'statistikVerlauf:9': 'kaputt'});
    final repo = SharedPrefsStatistikVerlaufRepository();
    expect(await repo.loadForLayer(9), isEmpty);

    final eintrag = StatistikVerlaufEintrag.aus(statistik, heute);
    await repo.saveForLayer(3, [eintrag]);
    expect(await repo.loadForLayer(3), [eintrag]);
    expect(StatistikVerlaufEintrag.fromJson({'monat': '26-9'}), isNull);
  });

  test('Service zeichnet nur vollständige Stände auf', () async {
    final repo = InMemoryStatistikVerlaufRepository();
    final service = StatistikVerlaufService(
      repository: repo,
      heute: () => heute,
    );
    final voll = StoreShowcaseData.readModel(today: heute);
    final ohneRollen = ArbeitskontextReadModel(
      arbeitskontext: voll.arbeitskontext,
      mitglieder: voll.mitglieder,
      gruppen: voll.gruppen,
      mitgliedsZuordnungen: voll.mitgliedsZuordnungen,
    );

    const stamm = StatistikAbdeckung.stamm();
    await service.aktualisiere(null, ladeLaeuft: false, abdeckung: stamm);
    await service.aktualisiere(ohneRollen, ladeLaeuft: false, abdeckung: stamm);
    await service.aktualisiere(voll, ladeLaeuft: true, abdeckung: stamm);
    // Teilsicht oder unbekannte Rechte: keine Stammeszahlen.
    await service.aktualisiere(
      voll,
      ladeLaeuft: false,
      abdeckung: StatistikAbdeckung.gruppen(const {1}),
    );
    await service.aktualisiere(voll, ladeLaeuft: false, abdeckung: null);
    expect(await repo.loadForLayer(StoreShowcaseData.layerId), isEmpty);

    await service.aktualisiere(voll, ladeLaeuft: false, abdeckung: stamm);
    final eintraege = await repo.loadForLayer(StoreShowcaseData.layerId);
    expect(eintraege.single.monat, '2026-09');
  });

  test('SharedPreferences: clearAll loescht nur den Verlauf', () async {
    SharedPreferences.setMockInitialValues({'andererWert': 'bleibt'});
    final repo = SharedPrefsStatistikVerlaufRepository();
    final eintrag = StatistikVerlaufEintrag.aus(statistik, heute);
    await repo.saveForLayer(1, [eintrag]);
    await repo.saveForLayer(2, [eintrag]);

    await repo.clearAll();

    expect(await repo.loadForLayer(1), isEmpty);
    expect(await repo.loadForLayer(2), isEmpty);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('andererWert'), 'bleibt');
  });
}

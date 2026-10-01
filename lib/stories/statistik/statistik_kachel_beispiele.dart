import 'dart:math' as math;

import 'package:latlong2/latlong.dart';
import 'package:nami/demo/demo_data.dart';
import 'package:nami/demo/demo_staemme.dart';
import 'package:nami/domain/arbeitskontext/arbeitskontext.dart';
import 'package:nami/domain/arbeitskontext/arbeitskontext_read_model.dart';
import 'package:nami/domain/statistiks/berechne_stamm_statistik_usecase.dart';
import 'package:nami/domain/statistiks/statistik_kachel_einstellungen.dart';
import 'package:nami/domain/statistiks/statistik_verlauf.dart';
import 'package:nami/domain/statistiks/zaehle_eigene_kachel_usecase.dart';
import 'package:nami/domain/stufe/altersgrenzen.dart';
import 'package:nami/presentation/statistics/kacheln/kachel_daten.dart';
import 'package:nami/presentation/statistics/kacheln/karten_vorschau.dart';
import 'package:nami/presentation/statistics/statistics_snapshot_builder.dart';
import 'package:nami/services/app_mode_controller.dart';
import 'package:nami/services/statistics_location_service.dart';
import 'package:nami/stories/statistik/statistik_beispiel_staemme.dart';
import 'package:nami/stories/store/store_showcase_data.dart';

/// Datensätze für Statistik-Stories und -Tests. [bezirk] und [leitung]
/// kommen aus dem Demo-Modus und zeigen, was die Demo-Zugänge
/// Bezirksvorstand und Leitung sehen.
enum StatistikBeispielDatensatz {
  silberfels('Silberfels'),
  weitblick('Weitblick'),
  querfeld('Querfeld (krumme Daten)'),
  bezirk('Bezirk (keine Gruppen)'),
  leitung('Leitung (eine Gruppe)');

  const StatistikBeispielDatensatz(this.label);

  final String label;

  ArbeitskontextReadModel readModel(DateTime heute) => switch (this) {
    silberfels => StoreShowcaseData.readModel(today: heute),
    weitblick => StatistikBeispielStaemme.weitblick(heute: heute),
    querfeld => StatistikBeispielStaemme.querfeld(heute: heute),
    bezirk => _demo(DemoZugang.bezirksvorstand, DemoBezirk.bezirk, heute),
    leitung => _demo(DemoZugang.leitung, DemoBezirk.silberfels, heute),
  };

  StatistikKachelEinstellungen get einstellungen => switch (this) {
    silberfels => const StatistikKachelEinstellungen(),
    weitblick => StatistikBeispielStaemme.einstellungenWeitblick(),
    querfeld => StatistikBeispielStaemme.einstellungenQuerfeld(),
    bezirk || leitung => const StatistikKachelEinstellungen(),
  };

  /// Weitblick hat einen Verlauf über acht Monate, Silberfels zwei Monate
  /// mit Lücke, Querfeld und die Demo-Zugänge noch keinen.
  List<StatistikVerlaufEintrag> verlauf(DateTime heute) => switch (this) {
    silberfels => [_eintrag(heute, -3, 24), _eintrag(heute, -1, 25)],
    weitblick => [
      for (final (i, personen) in const [
        66,
        68,
        67,
        70,
        71,
        71,
        73,
        74,
      ].indexed)
        _eintrag(heute, i - 8, personen),
    ],
    querfeld || bezirk || leitung => const [],
  };

  /// Read-Model wie im Demo-Modus, wenn [zugang] den [layer] geöffnet hat.
  static ArbeitskontextReadModel _demo(
    DemoZugang zugang,
    DemoLayer layer,
    DateTime heute,
  ) => DemoData(zugang, now: () => heute).readModel(
    arbeitskontext: Arbeitskontext(
      aktiverLayer: ArbeitskontextLayer(
        id: layer.id,
        name: layer.name,
        parentLayerId: layer.parentId,
        layerTyp: layer.typ,
      ),
    ),
  );

  static StatistikVerlaufEintrag _eintrag(
    DateTime heute,
    int monate,
    int personen,
  ) => StatistikVerlaufEintrag(
    monat: StatistikVerlaufEintrag.monatSchluessel(
      DateTime(heute.year, heute.month + monate),
    ),
    personen: personen,
    kinder: (personen * 0.76).round(),
    leitende: (personen * 0.2).round(),
  );
}

/// Kacheldaten wie auf der Statistikseite, aber mit festem Tag, erfundenen
/// Standorten und der statischen Kartenvorschau, damit Stories und Tests
/// ohne Netz und Kartenkacheln auskommen.
class StatistikKachelBeispiele {
  StatistikKachelBeispiele._();

  static final DateTime heute = DateTime(2026, 9, 30);
  static final DateTime stichtag = DateTime(2026, 11, 1);

  static StatistikKachelDaten daten(
    StatistikBeispielDatensatz datensatz, {
    DateTime? heute,
    StatistikKachelEinstellungen? einstellungen,
  }) {
    final tag = heute ?? StatistikKachelBeispiele.heute;
    final readModel = datensatz.readModel(tag);
    final grenzen = StufenDefaults.build();
    final eigene = einstellungen ?? datensatz.einstellungen;
    final snapshot = const StatisticsSnapshotBuilder().build(
      readModel,
      altersgrenzen: grenzen,
    );
    return StatistikKachelDaten(
      statistik: const BerechneStammStatistikUseCase()(
        readModel,
        heute: tag,
        altersgrenzen: grenzen,
        stichtag: stichtag,
      ),
      grenzen: grenzen,
      heute: tag,
      einstellungen: eigene,
      konfession: [for (final k in snapshot.confessions) k.value],
      eigeneZaehlungen: {
        for (final kachel in eigene.eigeneKacheln)
          kachel.id: const ZaehleEigeneKachelUseCase()(
            readModel,
            kachel.filter,
          ),
      },
      verlauf: datensatz.verlauf(tag),
      standortMitglieder: readModel.mitglieder,
      // Querfeld bleibt ohne Adressen und zeigt den Leerzustand.
      stammAdresse: datensatz == StatistikBeispielDatensatz.querfeld
          ? null
          : 'Am Stammesheim 1',
      standortAufloesung: ({required members, required stammAddress}) async =>
          _standorte(switch (datensatz) {
            StatistikBeispielDatensatz.weitblick => 71,
            StatistikBeispielDatensatz.bezirk ||
            StatistikBeispielDatensatz.leitung => readModel.mitglieder.length,
            _ => 23,
          }),
      kartenBauer: (context, wohnorte, stammesheim) =>
          StatistikKartenVorschau(wohnorte: wohnorte, stammesheim: stammesheim),
      onGruppeOeffnen: (_) {},
    );
  }

  static StatisticsResolvedLocations _standorte(int anzahl) {
    const mitte = LatLng(50.94, 6.96);
    final zufall = math.Random(7);
    return StatisticsResolvedLocations(
      memberPoints: [
        for (var i = 0; i < anzahl; i++)
          LatLng(
            mitte.latitude + (zufall.nextDouble() - 0.5) * 0.06,
            mitte.longitude + (zufall.nextDouble() - 0.5) * 0.1,
          ),
      ],
      stammPoint: mitte,
    );
  }
}

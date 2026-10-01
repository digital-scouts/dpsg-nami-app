import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:nami/domain/arbeitskontext/arbeitskontext_read_model.dart';
import 'package:nami/domain/statistiks/berechne_stamm_statistik_usecase.dart';
import 'package:nami/domain/statistiks/statistik_kachel_einstellungen.dart';
import 'package:nami/domain/statistiks/statistik_verlauf.dart';
import 'package:nami/domain/statistiks/zaehle_eigene_kachel_usecase.dart';
import 'package:nami/domain/stufe/altersgrenzen.dart';
import 'package:nami/presentation/statistics/kacheln/kachel_daten.dart';
import 'package:nami/presentation/statistics/statistics_snapshot_builder.dart';
import 'package:nami/services/statistics_location_service.dart';
import 'package:nami/stories/statistik/statistik_beispiel_staemme.dart';
import 'package:nami/stories/store/store_showcase_data.dart';

/// Datensätze für Statistik-Stories und -Tests.
enum StatistikBeispielDatensatz {
  silberfels('Silberfels'),
  weitblick('Weitblick'),
  querfeld('Querfeld (krumme Daten)');

  const StatistikBeispielDatensatz(this.label);

  final String label;

  ArbeitskontextReadModel readModel(DateTime heute) => switch (this) {
    silberfels => StoreShowcaseData.readModel(today: heute),
    weitblick => StatistikBeispielStaemme.weitblick(heute: heute),
    querfeld => StatistikBeispielStaemme.querfeld(heute: heute),
  };

  StatistikKachelEinstellungen get einstellungen => switch (this) {
    silberfels => const StatistikKachelEinstellungen(),
    weitblick => StatistikBeispielStaemme.einstellungenWeitblick(),
    querfeld => StatistikBeispielStaemme.einstellungenQuerfeld(),
  };

  /// Weitblick hat einen Verlauf über acht Monate, Silberfels zwei Monate
  /// mit Lücke, Querfeld noch keinen.
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
    querfeld => const [],
  };

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
/// Standorten und einer schlichten Kartenattrappe, damit Stories und Tests
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
          _standorte(
            datensatz == StatistikBeispielDatensatz.weitblick ? 71 : 23,
          ),
      kartenBauer: (context, wohnorte, stammesheim) =>
          StatistikKartenAttrappe(wohnorte: wohnorte, stammesheim: stammesheim),
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

/// Graue Fläche mit Punkten statt einer echten Karte.
class StatistikKartenAttrappe extends StatelessWidget {
  const StatistikKartenAttrappe({
    super.key,
    required this.wohnorte,
    this.stammesheim,
  });

  final List<LatLng> wohnorte;
  final LatLng? stammesheim;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CustomPaint(
      painter: _AttrappePainter(
        wohnorte: wohnorte,
        stammesheim: stammesheim,
        flaeche: scheme.surfaceContainerHighest,
        punkt: scheme.primary,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _AttrappePainter extends CustomPainter {
  _AttrappePainter({
    required this.wohnorte,
    required this.stammesheim,
    required this.flaeche,
    required this.punkt,
  });

  final List<LatLng> wohnorte;
  final LatLng? stammesheim;
  final Color flaeche;
  final Color punkt;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = flaeche);
    final alle = [...wohnorte, ?stammesheim];
    if (alle.isEmpty) return;
    final breiten = alle.map((p) => p.latitude);
    final laengen = alle.map((p) => p.longitude);
    final minB = breiten.reduce(math.min);
    final maxB = breiten.reduce(math.max);
    final minL = laengen.reduce(math.min);
    final maxL = laengen.reduce(math.max);
    Offset ort(LatLng p) => Offset(
      8 +
          (p.longitude - minL) /
              math.max(1e-9, maxL - minL) *
              (size.width - 16),
      8 +
          (maxB - p.latitude) /
              math.max(1e-9, maxB - minB) *
              (size.height - 16),
    );
    for (final p in wohnorte) {
      canvas.drawCircle(ort(p), 2.5, Paint()..color = punkt);
    }
    if (stammesheim case final heim?) {
      canvas.drawRect(
        Rect.fromCenter(center: ort(heim), width: 9, height: 9),
        Paint()..color = const Color(0xFF1565C0),
      );
    }
  }

  @override
  bool shouldRepaint(_AttrappePainter old) =>
      old.wohnorte != wohnorte ||
      old.stammesheim != stammesheim ||
      old.flaeche != flaeche ||
      old.punkt != punkt;
}

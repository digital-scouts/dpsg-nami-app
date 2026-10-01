import 'package:flutter/material.dart';
import 'package:nami/data/settings/shared_prefs_address_settings_repository.dart';
import 'package:nami/data/settings/shared_prefs_stufen_settings_repository.dart';
import 'package:nami/domain/stufe/altersgrenzen.dart';
import 'package:provider/provider.dart';

import '../../domain/arbeitskontext/arbeitskontext_read_model.dart';
import '../../domain/statistiks/berechne_stamm_statistik_usecase.dart';
import '../../domain/statistiks/statistik_kachel_einstellungen.dart';
import '../../l10n/app_localizations.dart';
import '../model/arbeitskontext_model.dart';
import '../statistics/kacheln/kachel_daten.dart';
import '../statistics/kacheln/kachel_raster.dart';
import '../statistics/statistics_snapshot_builder.dart';
import '../statistics/statistik_ausschnitt.dart';

/// Statistik einer einzelnen Gruppe: dieselben Kacheln wie im Stamm, in
/// fester Belegung ([StatistikKachelEinstellungen.gruppenDetail]).
class StatisticsGroupDetailPage extends StatefulWidget {
  const StatisticsGroupDetailPage({
    super.key,
    required this.groupId,
    this.debugReadModel,
    this.debugHeute,
  });

  final String groupId;
  final ArbeitskontextReadModel? debugReadModel;

  /// Fester Tag für Stories und Tests.
  final DateTime? debugHeute;

  @override
  State<StatisticsGroupDetailPage> createState() =>
      _StatisticsGroupDetailPageState();
}

class _StatisticsGroupDetailPageState extends State<StatisticsGroupDetailPage> {
  static const StatisticsSnapshotBuilder _snapshotBuilder =
      StatisticsSnapshotBuilder();
  static const BerechneStammStatistikUseCase _statistikUseCase =
      BerechneStammStatistikUseCase();

  final SharedPrefsStufenSettingsRepository _stufenSettingsRepository =
      SharedPrefsStufenSettingsRepository();
  final SharedPrefsAddressSettingsRepository _addressSettingsRepository =
      SharedPrefsAddressSettingsRepository();
  Altersgrenzen _altersgrenzen = StufenDefaults.build();
  DateTime? _stichtag;
  String? _stammAddress;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await _stufenSettingsRepository.load();
    final address = await _addressSettingsRepository.loadAddress();
    if (!mounted) {
      return;
    }
    setState(() {
      _altersgrenzen = settings.grenzen;
      _stichtag = settings.stufenwechselDatum;
      _stammAddress = address;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final readModel =
        widget.debugReadModel ?? context.watch<ArbeitskontextModel>().readModel;
    final gruppenId = int.tryParse(widget.groupId);
    final gruppe = gruppenId == null ? null : readModel?.findeGruppe(gruppenId);

    if (readModel == null || gruppe == null) {
      return Scaffold(
        appBar: AppBar(title: Text(t.t('statistics_group_detail_title'))),
        body: Center(
          child: Text(
            t.t(
              readModel == null
                  ? 'statistics_no_data'
                  : 'statistics_group_not_found',
            ),
          ),
        ),
      );
    }

    final ausschnitt = readModel.nurGruppen((id) => id == gruppe.id);
    final jetzt = widget.debugHeute ?? DateTime.now();
    final heute = DateTime(jetzt.year, jetzt.month, jetzt.day);
    final snapshot = _snapshotBuilder.build(
      ausschnitt,
      altersgrenzen: _altersgrenzen,
    );
    final daten = StatistikKachelDaten(
      statistik: _statistikUseCase(
        ausschnitt,
        heute: heute,
        altersgrenzen: _altersgrenzen,
        stichtag: _stichtag ?? heute,
      ),
      grenzen: _altersgrenzen,
      heute: heute,
      konfession: [for (final k in snapshot.confessions) k.value],
      standortMitglieder: ausschnitt.mitglieder,
      stammAdresse: _stammAddress,
    );

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(gruppe.anzeigename),
            Text(
              readModel.arbeitskontext.aktiverLayer.name,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          KachelRaster(
            eintraege: StatistikKachelEinstellungen.gruppenDetail,
            daten: daten,
          ),
        ],
      ),
    );
  }
}

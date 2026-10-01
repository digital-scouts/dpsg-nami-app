import 'package:flutter/material.dart';
import 'package:nami/data/settings/shared_prefs_address_settings_repository.dart';
import 'package:nami/data/settings/shared_prefs_stufen_settings_repository.dart';
import 'package:nami/domain/stufe/altersgrenzen.dart';
import 'package:provider/provider.dart';

import '../../domain/arbeitskontext/arbeitskontext_read_model.dart';
import '../../domain/bundesstatistik/statistik_abdeckung.dart';
import '../../domain/statistiks/berechne_stamm_statistik_usecase.dart';
import '../../domain/statistiks/statistik_kachel_einstellungen.dart';
import '../../l10n/app_localizations.dart';
import '../model/arbeitskontext_model.dart';
import '../statistics/kacheln/kachel_daten.dart';
import '../statistics/gruppen_auswahl.dart';
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
    this.debugAbdeckung,
  });

  final String groupId;
  final ArbeitskontextReadModel? debugReadModel;

  /// Feste Abdeckung für Stories und Tests; sonst aus dem Arbeitskontext.
  final StatistikAbdeckung? debugAbdeckung;

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

  /// Aktuell gezeigte Gruppe; über den Titel wechselbar.
  late String _gruppenId = widget.groupId;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _gruppeWechseln(
    ArbeitskontextReadModel lesbar,
    DateTime heute,
    int aktuell,
  ) async {
    final alle = _statistikUseCase(
      lesbar,
      heute: heute,
      altersgrenzen: _altersgrenzen,
      stichtag: _stichtag ?? heute,
    );
    final id = await zeigeGruppenAuswahl(
      context,
      stufen: alle.stufen,
      aktuell: aktuell,
    );
    if (id != null && mounted) setState(() => _gruppenId = '$id');
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
    final arbeitskontext = widget.debugReadModel == null
        ? context.watch<ArbeitskontextModel>()
        : null;
    final readModel = widget.debugReadModel ?? arbeitskontext?.readModel;
    final abdeckung =
        widget.debugAbdeckung ?? arbeitskontext?.statistikAbdeckung;
    final gruppenId = int.tryParse(_gruppenId);
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
    // Wechseln lässt sich nur zwischen lesbaren Gruppen.
    final lesbar = abdeckung == null || abdeckung.istStamm
        ? readModel
        : readModel.nurGruppen(abdeckung.deckt);
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
        title: InkWell(
          key: const Key('gruppe-wechseln'),
          onTap: () => _gruppeWechseln(lesbar, heute, gruppe.id),
          borderRadius: BorderRadius.circular(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      gruppe.anzeigename,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(
                    Icons.arrow_drop_down,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ],
              ),
              Text(
                readModel.arbeitskontext.aktiverLayer.name,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
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

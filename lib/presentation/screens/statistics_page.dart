import 'package:flutter/material.dart';
import 'package:nami/data/settings/shared_prefs_address_settings_repository.dart';
import 'package:nami/data/settings/shared_prefs_stufen_settings_repository.dart';
import 'package:nami/domain/stufe/altersgrenzen.dart';
import 'package:provider/provider.dart';

import '../../domain/arbeitskontext/arbeitskontext_read_model.dart';
import '../../domain/statistiks/berechne_stamm_statistik_usecase.dart';
import '../../domain/statistiks/statistik_kachel_einstellungen.dart';
import '../../domain/statistiks/statistik_verlauf.dart';
import '../../domain/statistiks/zaehle_eigene_kachel_usecase.dart';
import '../../l10n/app_localizations.dart';
import '../model/appearance_model.dart';
import '../model/arbeitskontext_model.dart';
import '../model/bundesstatistik_model.dart';
import '../navigation/app_router.dart';
import 'bundesvergleich_page.dart';
import '../statistics/kacheln/kachel_daten.dart';
import '../statistics/statistics_snapshot_builder.dart';
import '../statistics/statistik_kopf_zeile.dart';
import '../statistics/statistik_stamm_ansicht.dart';
import '../widgets/app_page_header.dart';

class StatisticsPage extends StatefulWidget {
  const StatisticsPage({
    super.key,
    this.debugReadModel,
    this.debugHeute,
    this.debugStichtag,
    this.debugThema = StatistikThema.ueberblick,
  });

  final ArbeitskontextReadModel? debugReadModel;

  /// Fester Tag für Stories und Tests.
  final DateTime? debugHeute;

  /// Fester Stufenwechsel-Stichtag für Stories und Tests.
  final DateTime? debugStichtag;

  /// Anfangs gezeigtes Thema im Stamm-Tab für Stories.
  final StatistikThema debugThema;

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  static const StatisticsSnapshotBuilder _snapshotBuilder =
      StatisticsSnapshotBuilder();
  final SharedPrefsStufenSettingsRepository _stufenSettingsRepository =
      SharedPrefsStufenSettingsRepository();
  final SharedPrefsAddressSettingsRepository _addressSettingsRepository =
      SharedPrefsAddressSettingsRepository();
  static const BerechneStammStatistikUseCase _statistikUseCase =
      BerechneStammStatistikUseCase();
  static const ZaehleEigeneKachelUseCase _eigeneKachelUseCase =
      ZaehleEigeneKachelUseCase();
  Altersgrenzen _altersgrenzen = StufenDefaults.build();
  DateTime? _stichtag;
  String? _stammAddress;
  StatistikKachelEinstellungen _einstellungen =
      const StatistikKachelEinstellungen();
  List<StatistikVerlaufEintrag> _verlauf = const [];
  int? _geladenFuerLayer;

  @override
  void initState() {
    super.initState();
    _loadAltersgrenzen();
    _loadStammAddress();
  }

  Future<void> _loadAltersgrenzen() async {
    final settings = await _stufenSettingsRepository.load();
    if (!mounted) {
      return;
    }
    setState(() {
      _altersgrenzen = settings.grenzen;
      _stichtag = settings.stufenwechselDatum;
    });
  }

  Future<void> _loadStammAddress() async {
    final address = await _addressSettingsRepository.loadAddress();
    if (!mounted) {
      return;
    }
    setState(() {
      _stammAddress = address;
    });
  }

  void _openGroup(String groupId) {
    final arguments = widget.debugReadModel == null
        ? groupId
        : <String, Object?>{
            'groupId': groupId,
            'readModel': widget.debugReadModel,
          };
    Navigator.of(
      context,
    ).pushNamed(AppRoutes.statisticsGroupDetail, arguments: arguments);
  }

  /// Lädt Kachel-Einstellungen und Verlauf des Stamms, sobald der Layer
  /// bekannt ist oder wechselt. Ohne Repositories (Stories, Tests) bleiben
  /// die Standardwerte.
  void _ladeFuerLayer(int layerId) {
    if (_geladenFuerLayer == layerId) return;
    _geladenFuerLayer = layerId;
    StatistikKachelRepository? kacheln;
    StatistikVerlaufRepository? verlauf;
    try {
      kacheln = context.read<StatistikKachelRepository>();
      verlauf = context.read<StatistikVerlaufRepository>();
    } on ProviderNotFoundException {
      return;
    }
    kacheln.loadForLayer(layerId).then((wert) {
      if (mounted && _geladenFuerLayer == layerId) {
        setState(() => _einstellungen = wert);
      }
    });
    verlauf.loadForLayer(layerId).then((wert) {
      if (mounted && _geladenFuerLayer == layerId) {
        setState(() => _verlauf = wert);
      }
    });
  }

  StatistikKachelDaten _kachelDaten(
    ArbeitskontextReadModel readModel,
    StatisticsSnapshot snapshot,
  ) {
    final jetzt = widget.debugHeute ?? DateTime.now();
    final heute = DateTime(jetzt.year, jetzt.month, jetzt.day);
    final statistik = _statistikUseCase(
      readModel,
      heute: heute,
      altersgrenzen: _altersgrenzen,
      stichtag: widget.debugStichtag ?? _stichtag ?? heute,
    );
    return StatistikKachelDaten(
      statistik: statistik,
      grenzen: _altersgrenzen,
      heute: heute,
      einstellungen: _einstellungen,
      konfession: [for (final k in snapshot.confessions) k.value],
      eigeneZaehlungen: {
        for (final kachel in _einstellungen.eigeneKacheln)
          kachel.id: _eigeneKachelUseCase(readModel, kachel.filter),
      },
      verlauf: _verlauf,
      standortMitglieder: readModel.mitglieder,
      stammAdresse: _stammAddress,
      onGruppeOeffnen: (id) => _openGroup('$id'),
    );
  }

  bool _hasBundesstatistik(BuildContext context) {
    try {
      context.watch<BundesstatistikModel>();
      return true;
    } on ProviderNotFoundException {
      // Stories und Tests ohne Bundesstatistik-Provider.
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final injectedReadModel = widget.debugReadModel;
    final arbeitskontextModel = injectedReadModel == null
        ? context.watch<ArbeitskontextModel>()
        : null;
    final readModel = injectedReadModel ?? arbeitskontextModel?.readModel;

    if (injectedReadModel == null &&
        (arbeitskontextModel!.isLoading ||
            arbeitskontextModel.isLoadingRoles) &&
        readModel == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (readModel == null) {
      return Center(
        child: Text(AppLocalizations.of(context).t('statistics_no_data')),
      );
    }

    _ladeFuerLayer(readModel.arbeitskontext.aktiverLayer.id);
    final snapshot = _snapshotBuilder.build(
      readModel,
      altersgrenzen: _altersgrenzen,
    );
    final daten = _kachelDaten(readModel, snapshot);

    final stammView = StatistikStammAnsicht(
      daten: daten,
      initialesThema: widget.debugThema,
    );
    final background = context.watch<AppearanceModel?>()?.background;
    final bundesweitView = _hasBundesstatistik(context)
        ? const BundesvergleichBody()
        : BundesvergleichView(
            status: BundesstatistikStatus.nichtVerfuegbar,
            hatEinwilligung: false,
            onEinwilligungAendern: (_) {},
          );

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          AppPageHeader(
            background: background,
            primary: StatistikKopfZeile(statistik: daten.statistik),
            secondary: _StatisticsTabBar(stammName: snapshot.stammName),
          ),
          Expanded(
            child: TabBarView(
              // Nur per Tab wechseln: die Karte im Stamm-Tab braucht die
              // horizontalen Gesten selbst.
              physics: const NeverScrollableScrollPhysics(),
              children: [stammView, bundesweitView],
            ),
          ),
        ],
      ),
    );
  }
}

/// Tabs mit dem Namen des Stamms und "Bundesweit" als Pille, lesbar auch
/// auf dem Supporter-Hintergrund. Fuellt die Zeilenhoehe des Headers.
class _StatisticsTabBar extends StatelessWidget {
  const _StatisticsTabBar({required this.stammName});

  final String stammName;

  static const double _inset = 3;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final tabHeight = constraints.maxHeight - 2 * _inset;
        return DecoratedBox(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(constraints.maxHeight / 2),
          ),
          child: Padding(
            padding: const EdgeInsets.all(_inset),
            child: TabBar(
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              indicator: BoxDecoration(
                color: colorScheme.primary,
                borderRadius: BorderRadius.circular(tabHeight / 2),
              ),
              labelColor: colorScheme.onPrimary,
              unselectedLabelColor: colorScheme.onSurfaceVariant,
              labelPadding: const EdgeInsets.symmetric(horizontal: 12),
              splashBorderRadius: BorderRadius.circular(tabHeight / 2),
              tabs: [
                Tab(
                  height: tabHeight,
                  child: Text(
                    stammName,
                    key: const Key('statistics-header-title'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Tab(
                  height: tabHeight,
                  child: const Text(
                    'Bundesweit',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:nami/data/settings/shared_prefs_address_settings_repository.dart';
import 'package:nami/data/settings/shared_prefs_stufen_settings_repository.dart';
import 'package:nami/data/statistiks/shared_prefs_statistik_kachel_repository.dart';
import 'package:nami/domain/stufe/altersgrenzen.dart';
import 'package:provider/provider.dart';

import '../../domain/arbeitskontext/arbeitskontext_read_model.dart';
import '../../domain/bundesstatistik/statistik_abdeckung.dart';
import '../../domain/statistiks/berechne_stamm_statistik_usecase.dart';
import '../../domain/statistiks/statistik_kachel_einstellungen.dart';
import '../../domain/statistiks/statistik_verlauf.dart';
import '../../domain/statistiks/zaehle_eigene_kachel_usecase.dart';
import '../../l10n/app_localizations.dart';
import '../model/appearance_model.dart';
import '../model/arbeitskontext_model.dart';
import '../model/bundesstatistik_model.dart';
import '../model/statistik_kacheln_model.dart';
import '../notifications/app_snackbar.dart';
import '../navigation/app_router.dart';
import 'bundesvergleich_page.dart';
import 'statistik_zielwerte_page.dart';
import '../statistics/kachel_katalog_sheet.dart';
import '../statistics/kacheln/kachel_bearbeiten.dart';
import '../statistics/statistik_bearbeiten_leiste.dart';
import '../statistics/kacheln/kachel_daten.dart';
import '../statistics/kacheln/kachel_katalog.dart';
import '../statistics/statistics_snapshot_builder.dart';
import '../statistics/statistik_ausschnitt.dart';
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
    this.debugAbdeckung,
  });

  final ArbeitskontextReadModel? debugReadModel;

  /// Fester Tag für Stories und Tests.
  final DateTime? debugHeute;

  /// Fester Stufenwechsel-Stichtag für Stories und Tests.
  final DateTime? debugStichtag;

  /// Anfangs gezeigtes Thema im Stamm-Tab für Stories.
  final StatistikThema debugThema;

  /// Feste Abdeckung für Stories und Tests; sonst aus dem Arbeitskontext.
  final StatistikAbdeckung? debugAbdeckung;

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
  List<StatistikVerlaufEintrag> _verlauf = const [];
  int? _geladenFuerLayer;
  bool? _geladenMitTeilsicht;

  /// Nur ohne app-weites Modell (Stories, Tests).
  StatistikKachelnModel? _eigenesModell;

  @override
  void initState() {
    super.initState();
    _loadAltersgrenzen();
    _loadStammAddress();
  }

  @override
  void dispose() {
    _eigenesModell?.removeListener(_modellGeaendert);
    _eigenesModell?.dispose();
    super.dispose();
  }

  void _modellGeaendert() {
    if (mounted) setState(() {});
  }

  /// App-weites Modell; ohne Provider ein eigenes mit dem bereitgestellten
  /// Repository (sonst nur im Speicher).
  StatistikKachelnModel _kachelnModell(BuildContext context) {
    try {
      return context.watch<StatistikKachelnModel>();
    } on ProviderNotFoundException {
      return _eigenesModell ??= () {
        StatistikKachelRepository repository;
        try {
          repository = context.read<StatistikKachelRepository>();
        } on ProviderNotFoundException {
          repository = InMemoryStatistikKachelRepository();
        }
        return StatistikKachelnModel(repository)..addListener(_modellGeaendert);
      }();
    }
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

  /// Lädt Kachel-Belegung und Verlauf des Stamms, sobald der Layer bekannt
  /// ist oder wechselt. Ohne Verlaufs-Repository (Stories, Tests) bleibt der
  /// Verlauf leer.
  void _ladeFuerLayer(
    int layerId,
    StatistikKachelnModel modell, {
    required bool teilsicht,
  }) {
    if (modell.layerId != layerId || _geladenMitTeilsicht != teilsicht) {
      _geladenMitTeilsicht = teilsicht;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          modell.ensureLoadedForLayer(layerId, teilsicht: teilsicht);
        }
      });
    }
    if (_geladenFuerLayer == layerId) return;
    _geladenFuerLayer = layerId;
    StatistikVerlaufRepository verlauf;
    try {
      verlauf = context.read<StatistikVerlaufRepository>();
    } on ProviderNotFoundException {
      return;
    }
    verlauf.loadForLayer(layerId).then((wert) {
      if (mounted && _geladenFuerLayer == layerId) {
        setState(() => _verlauf = wert);
      }
    });
  }

  StatistikKachelDaten _kachelDaten(
    ArbeitskontextReadModel readModel,
    StatisticsSnapshot snapshot,
    StatistikKachelEinstellungen einstellungen,
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
      einstellungen: einstellungen,
      konfession: [for (final k in snapshot.confessions) k.value],
      eigeneZaehlungen: {
        for (final kachel in einstellungen.eigeneKacheln)
          kachel.id: _eigeneKachelUseCase(readModel, kachel.filter),
      },
      verlauf: _verlauf,
      standortMitglieder: readModel.mitglieder,
      stammAdresse: _stammAddress,
      onGruppeOeffnen: (id) => _openGroup('$id'),
    );
  }

  void _entfernen(StatistikKachelnModel modell, KachelEintrag eintrag) {
    final t = AppLocalizations.of(context);
    final titel = KachelKatalog.titelFuer(t, _letzteDaten!, eintrag);
    final entfernt = modell.entfernen(eintrag.id);
    if (entfernt == null) return;
    AppSnackbar.show(
      context,
      type: AppSnackbarType.info,
      message: t.t('statistics_edit_removed', {'title': titel}),
      replaceCurrent: true,
      action: AppSnackbarAction(
        label: t.t('statistics_edit_undo'),
        onPressed: () => modell.wiederherstellen(entfernt.$1, entfernt.$2),
      ),
    );
  }

  Future<void> _katalogOeffnen(
    StatistikKachelnModel modell,
    ArbeitskontextReadModel readModel,
  ) async {
    final daten = _letzteDaten;
    if (daten == null) return;
    final auswahl = await zeigeKachelKatalog(
      context,
      daten: daten,
      readModel: readModel,
      neueId: modell.neueId,
    );
    switch (auswahl) {
      case KatalogKachel(:final typId, :final groesse):
        modell.hinzufuegen(typId, groesse);
      case KatalogEigeneKachel(:final kachel):
        modell.eigeneKachelSpeichern(kachel);
      case null:
        break;
    }
  }

  Future<void> _eigeneKachelBearbeiten(
    StatistikKachelnModel modell,
    ArbeitskontextReadModel readModel,
    KachelEintrag eintrag,
  ) async {
    final kachel = modell.einstellungen.eigeneKachel(eintrag.eigeneKachelId);
    if (kachel == null) return;
    final neu = await zeigeEigeneKachelEditor(
      context,
      readModel: readModel,
      kachel: kachel,
      neueId: modell.neueId,
    );
    if (neu != null) modell.eigeneKachelSpeichern(neu);
  }

  Future<void> _zuruecksetzen(StatistikKachelnModel modell) async {
    final t = AppLocalizations.of(context);
    final bestaetigt = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.t('statistics_reset_title')),
        content: Text(t.t('statistics_reset_message')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(t.t('statistics_reset_cancel')),
          ),
          TextButton(
            key: const Key('statistik-zuruecksetzen-bestaetigen'),
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(t.t('statistics_reset_confirm')),
          ),
        ],
      ),
    );
    if (bestaetigt == true) modell.zuruecksetzen();
  }

  void _zielwerteOeffnen(StatistikKachelnModel modell) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StatistikZielwertePage(model: modell),
      ),
    );
  }

  StatistikKachelDaten? _letzteDaten;

  bool _hasBundesstatistik(BuildContext context) {
    try {
      context.watch<BundesstatistikModel>();
      return true;
    } on ProviderNotFoundException {
      // Stories und Tests ohne Bundesstatistik-Provider.
      return false;
    }
  }

  /// Hinweis, wenn Hitobito für lesbare Gruppen keine Rollen liefert und
  /// die Zahlen dieser Gruppen deshalb unbekannt sind.
  String? _rollenHinweis(
    AppLocalizations t,
    StatistikAbdeckung? abdeckung,
    ArbeitskontextReadModel? readModel,
  ) {
    final ohneRollen = abdeckung?.gruppenOhneRollen ?? const <int>{};
    if (readModel == null || ohneRollen.isEmpty) {
      return null;
    }
    final namen = <String>[
      for (final gruppe in readModel.gruppen)
        if (ohneRollen.contains(gruppe.id)) gruppe.anzeigename,
    ];
    return t.t('leserechte_statistik_hinweis', {'gruppen': namen.join(', ')});
  }

  @override
  Widget build(BuildContext context) {
    final injectedReadModel = widget.debugReadModel;
    final arbeitskontextModel = injectedReadModel == null
        ? context.watch<ArbeitskontextModel>()
        : null;
    final vollesReadModel = injectedReadModel ?? arbeitskontextModel?.readModel;
    final abdeckung =
        widget.debugAbdeckung ?? arbeitskontextModel?.statistikAbdeckung;
    final teilsicht = abdeckung != null && !abdeckung.istStamm;
    // Bei Teilsicht zählen nur die lesbaren Gruppen, nicht die übrige
    // Gruppenstruktur des Stamms.
    final readModel = teilsicht && vollesReadModel != null
        ? vollesReadModel.nurGruppen(abdeckung.deckt)
        : vollesReadModel;

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

    final layerId = readModel.arbeitskontext.aktiverLayer.id;
    final modell = _kachelnModell(context);
    _ladeFuerLayer(layerId, modell, teilsicht: teilsicht);
    final geladen = modell.layerId == layerId && !modell.isLoading;
    final einstellungen = geladen
        ? modell.einstellungen
        : const StatistikKachelEinstellungen();
    final snapshot = _snapshotBuilder.build(
      readModel,
      altersgrenzen: _altersgrenzen,
    );
    final daten = _kachelDaten(readModel, snapshot, einstellungen);
    _letzteDaten = daten;
    final t = AppLocalizations.of(context);
    final bearbeiten = geladen && modell.bearbeiten;

    final stammView = _BeimVerlassen(
      onVerlassen: modell.bearbeitenBeenden,
      child: StatistikStammAnsicht(
        daten: daten,
        nurUeberblick: teilsicht,
        hinweis: _rollenHinweis(t, abdeckung, vollesReadModel),
        initialesThema: widget.debugThema,
        unterUeberblick: geladen
            ? Center(
                child: OutlinedButton.icon(
                  key: const Key('statistik-bearbeiten'),
                  onPressed: modell.bearbeitenStarten,
                  icon: const Icon(Icons.edit_outlined),
                  label: Text(t.t('statistics_edit')),
                ),
              )
            : null,
        bearbeitung: bearbeiten
            ? KachelRasterBearbeitung(
                onVerschieben: modell.verschieben,
                onGroesse: (eintrag, groesse) =>
                    modell.groesseSetzen(eintrag.id, groesse),
                onEntfernen: (eintrag) => _entfernen(modell, eintrag),
                onAntippen: (eintrag) =>
                    _eigeneKachelBearbeiten(modell, readModel, eintrag),
              )
            : null,
        bearbeitenLeiste: StatistikBearbeitenLeiste(
          themenAnzeigen: !teilsicht,
          stufenSichtbar: einstellungen.stufenSichtbar,
          entwicklungSichtbar: einstellungen.entwicklungSichtbar,
          onHinzufuegen: () => _katalogOeffnen(modell, readModel),
          onFertig: modell.bearbeitenBeenden,
          onThemaSichtbar: modell.themaSichtbar,
        ),
        unterBearbeiten: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ZielwerteEintrag(
              ziele: einstellungen.ziele,
              onTap: () => _zielwerteOeffnen(modell),
            ),
            const SizedBox(height: 8),
            _ZuruecksetzenEintrag(onTap: () => _zuruecksetzen(modell)),
          ],
        ),
      ),
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
            // Das Kachelraster nutzt die volle Breite, der Kopf auch.
            volleBreite: true,
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
                  child: Text(
                    AppLocalizations.of(context).t('bund_tab'),
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

/// Ruft [onVerlassen] auf, wenn der Stamm-Tab verlassen wird (Tab-Wechsel,
/// andere Seite), z. B. um das Bearbeiten zu beenden.
class _BeimVerlassen extends StatefulWidget {
  const _BeimVerlassen({required this.onVerlassen, required this.child});

  final VoidCallback onVerlassen;
  final Widget child;

  @override
  State<_BeimVerlassen> createState() => _BeimVerlassenState();
}

class _BeimVerlassenState extends State<_BeimVerlassen> {
  @override
  void dispose() {
    // Nicht mitten im Abbau benachrichtigen.
    final verlassen = widget.onVerlassen;
    WidgetsBinding.instance.addPostFrameCallback((_) => verlassen());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Eintrag „Überblick zurücksetzen“ unter dem Raster im Bearbeiten-Modus.
class _ZuruecksetzenEintrag extends StatelessWidget {
  const _ZuruecksetzenEintrag({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        key: const Key('statistik-zuruecksetzen'),
        leading: Icon(Icons.restart_alt, color: scheme.primary),
        title: Text(
          t.t('statistics_reset'),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(t.t('statistics_reset_hint')),
        onTap: onTap,
      ),
    );
  }
}

/// Eintrag „Zielwerte“ unter dem Raster im Bearbeiten-Modus.
class _ZielwerteEintrag extends StatelessWidget {
  const _ZielwerteEintrag({required this.ziele, required this.onTap});

  final StatistikZielwerte ziele;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final anzahl = ziele.gruppeMax.length + (ziele.neuProJahr == null ? 0 : 1);
    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        key: const Key('statistik-zielwerte'),
        leading: Icon(Icons.flag_outlined, color: scheme.primary),
        title: Text(
          t.t('statistics_targets'),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          anzahl == 0
              ? t.t('statistics_targets_none')
              : t.t('statistics_targets_count', {'count': anzahl}),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../domain/arbeitskontext/arbeitskontext_read_model.dart';
import '../../../domain/qualifikation/ermittle_qualifikations_uebersicht_usecase.dart';
import '../../../l10n/app_localizations.dart';
import '../../model/qualifikations_einstellungen_model.dart';
import '../../widgets/qualifikationen/qualifikation_bausteine.dart';
import '../../widgets/section_header.dart';
import 'qualifikation_einstellungen_page.dart';
import 'qualifikationen_kontext.dart';

/// Welche Arten die Uebersicht zeigt und in welcher Reihenfolge; der Pfeil
/// fuehrt zu den Einstellungen einer Art. Arten, die im Kontext niemand hat,
/// fehlen hier, ihre Einstellungen bleiben gespeichert.
class QualifikationenAuswahlPage extends StatelessWidget {
  const QualifikationenAuswahlPage({
    super.key,
    this.readModel,
    this.heuteProvider,
  });

  final ArbeitskontextReadModel? readModel;
  final DateTime Function()? heuteProvider;

  static const _useCase = ErmittleQualifikationsUebersichtUseCase();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context);
    final model = context.watch<QualifikationsEinstellungenModel>();
    final readModel = QualifikationenKontext.readModel(context, this.readModel);
    if (readModel == null) {
      return Scaffold(
        appBar: AppBar(title: Text(t.t('quali_auswahl_tooltip'))),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final katalog = _useCase.katalog(
      readModel: readModel,
      einstellungen: model.einstellungen,
    );
    final angezeigt = katalog.where((k) => k.angezeigt).toList();
    final ausgeblendet = katalog.where((k) => !k.angezeigt).toList();

    Future<void> umschalten(KatalogEintrag eintrag, bool an) async {
      final reihenfolge = <String>[
        for (final k in angezeigt)
          if (k.art.schluessel != eintrag.art.schluessel) k.art.schluessel,
        if (an) eintrag.art.schluessel,
      ];
      await model.aendern(
        (alt) => alt
            .mitArt(
              eintrag.art.schluessel,
              alt.art(eintrag.art.schluessel).copyWith(angezeigt: an),
            )
            .copyWith(reihenfolge: reihenfolge),
      );
    }

    Future<void> verschieben(int alt, int neu) async {
      final schluessel = angezeigt.map((k) => k.art.schluessel).toList();
      schluessel.insert(neu, schluessel.removeAt(alt));
      await model.aendern((e) => e.copyWith(reihenfolge: schluessel));
    }

    void oeffne(KatalogEintrag eintrag) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => QualifikationEinstellungenPage(
            schluessel: eintrag.art.schluessel,
            readModel: this.readModel,
            heuteProvider: heuteProvider,
          ),
        ),
      );
    }

    Widget karte(Widget kind) => Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      clipBehavior: Clip.antiAlias,
      child: kind,
    );

    return Scaffold(
      appBar: AppBar(title: Text(t.t('quali_auswahl_tooltip'))),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Text(
                t.t('quali_auswahl_hinweis'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: DpsgSectionHeader(
              label: t.t('quali_auswahl_angezeigt'),
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
            ),
          ),
          SliverToBoxAdapter(
            child: karte(
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                itemCount: angezeigt.length,
                onReorderItem: verschieben,
                itemBuilder: (context, index) => _AuswahlZeile(
                  key: ValueKey(angezeigt[index].art.schluessel),
                  eintrag: angezeigt[index],
                  readModel: readModel,
                  ziehIndex: index,
                  onUmschalten: (an) => umschalten(angezeigt[index], an),
                  onOeffnen: () => oeffne(angezeigt[index]),
                ),
              ),
            ),
          ),
          if (ausgeblendet.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: DpsgSectionHeader(
                label: t.t('quali_auswahl_ausgeblendet'),
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 6),
              ),
            ),
            SliverToBoxAdapter(
              child: karte(
                Column(
                  children: [
                    for (final eintrag in ausgeblendet)
                      _AuswahlZeile(
                        key: ValueKey(eintrag.art.schluessel),
                        eintrag: eintrag,
                        readModel: readModel,
                        onUmschalten: (an) => umschalten(eintrag, an),
                        onOeffnen: () => oeffne(eintrag),
                      ),
                  ],
                ),
              ),
            ),
          ],
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
              child: Text(
                t.t('quali_auswahl_fuss'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuswahlZeile extends StatelessWidget {
  const _AuswahlZeile({
    super.key,
    required this.eintrag,
    required this.readModel,
    required this.onUmschalten,
    required this.onOeffnen,
    this.ziehIndex,
  });

  final KatalogEintrag eintrag;
  final ArbeitskontextReadModel readModel;
  final ValueChanged<bool> onUmschalten;
  final VoidCallback onOeffnen;

  /// Gesetzt fuer angezeigte Arten, die sich verschieben lassen.
  final int? ziehIndex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context);
    final art = eintrag.art;
    final inhaber = art.istEfz
        ? null
        : readModel.qualifikationen
              .where((q) => q.artId == art.hitobitoId)
              .map((q) => q.personId)
              .toSet()
              .length;
    final untertitel = art.istEfz
        ? '${t.t('quali_efz_untertitel')} · ${qualiRegelmaessigkeit(t, art)}'
        : '${inhaber == 1 ? t.t('quali_personen_eins') : t.t('quali_personen_anzahl', {'n': inhaber})} · '
              '${qualiRegelmaessigkeit(t, art)}';
    final griff = Icon(Icons.drag_indicator, color: theme.colorScheme.outline);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: Key('quali-auswahl-${art.schluessel}'),
        onTap: onOeffnen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 4, 8),
          child: Row(
            children: [
              if (ziehIndex != null)
                ReorderableDragStartListener(index: ziehIndex!, child: griff)
              else
                Opacity(opacity: 0, child: griff),
              const SizedBox(width: 8),
              QualifikationArtSymbol(art: art, size: 30),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      art.label,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      untertitel,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                key: Key('quali-anzeigen-${art.schluessel}'),
                value: eintrag.angezeigt,
                onChanged: onUmschalten,
              ),
              Icon(Icons.chevron_right, color: theme.colorScheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}

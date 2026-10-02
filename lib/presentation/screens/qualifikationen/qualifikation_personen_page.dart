import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../domain/arbeitskontext/arbeitskontext_read_model.dart';
import '../../../domain/member/member_utils.dart';
import '../../../domain/member/mitglied.dart';
import '../../../domain/qualifikation/ermittle_qualifikations_uebersicht_usecase.dart';
import '../../../domain/qualifikation/plane_qualifikations_erinnerungen_usecase.dart';
import '../../../domain/qualifikation/qualifikations_status.dart';
import '../../../l10n/app_localizations.dart';
import '../../model/qualifikations_einstellungen_model.dart';
import '../../navigation/app_router.dart';
import '../../widgets/qualifikationen/qualifikation_bausteine.dart';
import '../member_detail_page.dart';
import 'qualifikation_einstellungen_page.dart';
import 'qualifikationen_kontext.dart';

/// Personen im Personenkreis einer Art, zuerst mit Handlungsbedarf
/// (Entwurf D2).
class QualifikationPersonenPage extends StatefulWidget {
  const QualifikationPersonenPage({
    super.key,
    required this.schluessel,
    this.readModel,
    this.heuteProvider,
  });

  final String schluessel;
  final ArbeitskontextReadModel? readModel;
  final DateTime Function()? heuteProvider;

  @override
  State<QualifikationPersonenPage> createState() =>
      _QualifikationPersonenPageState();
}

class _QualifikationPersonenPageState extends State<QualifikationPersonenPage> {
  static const _useCase = ErmittleQualifikationsUebersichtUseCase();

  bool _alle = false;

  void _oeffneMitglied(Mitglied mitglied) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: RouteSettings(
          name: AppRoutes.memberDetail,
          arguments: mitglied.mitgliedsnummer,
        ),
        builder: (_) => MemberDetailPage(
          mitglied: mitglied,
          heuteProvider: widget.heuteProvider,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context);
    final readModel = QualifikationenKontext.readModel(
      context,
      widget.readModel,
    );
    final einstellungen = context
        .watch<QualifikationsEinstellungenModel>()
        .einstellungen;
    final heute = QualifikationenKontext.heute(widget.heuteProvider);
    KatalogEintrag? katalog;
    if (readModel != null) {
      for (final eintrag in _useCase.katalog(
        readModel: readModel,
        einstellungen: einstellungen,
      )) {
        if (eintrag.art.schluessel == widget.schluessel) {
          katalog = eintrag;
        }
      }
    }
    if (readModel == null || katalog == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final zeile = _useCase.zeile(
      readModel: readModel,
      katalog: katalog,
      heute: heute,
    );
    final eigenePersonId = QualifikationenKontext.eigenePersonId(context);
    final liste = _alle
        ? zeile.eintraege
        : zeile.eintraege
              .where((e) => e.status != QualifikationsStatus.gueltig)
              .toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        title: Text(zeile.art.label),
        actions: [
          IconButton(
            key: const Key('quali-einstellungen-oeffnen'),
            tooltip: t.t('quali_einstellen_titel', {'art': zeile.art.label}),
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => QualifikationEinstellungenPage(
                  schluessel: widget.schluessel,
                  readModel: widget.readModel,
                  heuteProvider: widget.heuteProvider,
                ),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  QualifikationArtSymbol(art: zeile.art, size: 44),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.t('quali_erfuellt', {
                            'erfuellt': zeile.erfuellt,
                            'benoetigt': zeile.benoetigt,
                          }),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          zeile.art.istEfz
                              ? qualiRegelmaessigkeit(t, zeile.art)
                              : '${qualiRegelmaessigkeit(t, zeile.art)} · '
                                    '${t.t('quali_quelle_hitobito')}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text.rich(
                          TextSpan(
                            style: theme.textTheme.bodyMedium,
                            children: qualiStatusSpans(
                              context,
                              zeile,
                              kurz: false,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.group_outlined,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  t.t('quali_benoetigt_von', {
                    'kreis': qualiKreisBeschreibung(t, katalog.personenkreis),
                    'n': zeile.benoetigt,
                  }),
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          QualifikationStatusBalken(zeile: zeile, hoehe: 6),
          const SizedBox(height: 14),
          SegmentedButton<bool>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment<bool>(
                value: false,
                label: Text(
                  '${t.t('quali_handlungsbedarf')} ${zeile.handlungsbedarf}',
                ),
              ),
              ButtonSegment<bool>(
                value: true,
                label: Text('${t.t('quali_alle')} ${zeile.benoetigt}'),
              ),
            ],
            selected: <bool>{_alle},
            onSelectionChanged: (auswahl) =>
                setState(() => _alle = auswahl.first),
          ),
          const SizedBox(height: 12),
          if (liste.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                zeile.benoetigt == 0
                    ? t.t('quali_niemand_im_kreis')
                    : t.t('quali_kein_handlungsbedarf'),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            Card(
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (var i = 0; i < liste.length; i++) ...[
                    if (i > 0) const Divider(height: 1, indent: 58),
                    _PersonZeile(
                      eintrag: liste[i],
                      heute: heute,
                      eigene: liste[i].mitglied.personId == eigenePersonId,
                      onTap: () => _oeffneMitglied(liste[i].mitglied),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _PersonZeile extends StatelessWidget {
  const _PersonZeile({
    required this.eintrag,
    required this.heute,
    required this.eigene,
    required this.onTap,
  });

  final UebersichtEintrag eintrag;
  final DateTime heute;
  final bool eigene;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context);
    final gueltigBis = eintrag.gueltigBis;
    final datum = eintrag.ohneAblauf
        ? t.t('quali_ohne_ablauf')
        : gueltigBis == null
        ? t.t('quali_nicht_hinterlegt')
        : eintrag.status == QualifikationsStatus.abgelaufen
        ? t.t('quali_seit', {'datum': qualiDatum(gueltigBis)})
        : t.t('quali_bis', {'datum': qualiDatum(gueltigBis)});
    final zusatz = <String>[
      datum,
      if (eintrag.reaktivierbar &&
          eintrag.status == QualifikationsStatus.abgelaufen)
        t.t('quali_reaktivierbar'),
      ?_rollen(eintrag.mitglied),
    ].join(' · ');

    return InkWell(
      key: Key('quali-person-${eintrag.mitglied.mitgliedsnummer}'),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            QualifikationPersonSymbol(mitglied: eintrag.mitglied, heute: heute),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          anzeigenameFuerErinnerung(eintrag.mitglied),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (eigene) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            t.t('quali_du'),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    zusatz,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            QualifikationStatusPille(status: eintrag.status),
          ],
        ),
      ),
    );
  }

  String? _rollen(Mitglied mitglied) {
    final labels = mitglied.roles
        .where(
          (rolle) =>
              rolle.isActiveAt(heute) && !MemberUtils.istMitgliederRolle(rolle),
        )
        .map((rolle) => rolle.resolvedLabel)
        .whereType<String>()
        .toSet();
    return labels.isEmpty ? null : labels.join(', ');
  }
}

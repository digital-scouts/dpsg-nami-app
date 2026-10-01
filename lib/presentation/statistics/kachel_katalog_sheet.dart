import 'package:flutter/material.dart';

import '../../domain/arbeitskontext/arbeitskontext_read_model.dart';
import '../../domain/statistiks/statistik_kachel_einstellungen.dart';
import '../../domain/statistiks/statistik_kachel_typen.dart';
import '../../l10n/app_localizations.dart';
import '../widgets/app_page_header.dart';
import 'eigene_kachel_editor.dart';
import 'kacheln/kachel_bearbeiten.dart';
import 'kacheln/kachel_daten.dart';
import 'kacheln/kachel_katalog.dart';
import 'kacheln/kachel_raster_packer.dart';
import 'kacheln/karten_vorschau.dart';

/// Ergebnis des Katalogs.
sealed class KatalogAuswahl {
  const KatalogAuswahl();
}

class KatalogKachel extends KatalogAuswahl {
  const KatalogKachel(this.typId, this.groesse);

  final String typId;
  final KachelGroesse groesse;
}

class KatalogEigeneKachel extends KatalogAuswahl {
  const KatalogEigeneKachel(this.kachel);

  final EigeneKachel kachel;
}

/// Öffnet den Katalog als Sheet. Liefert `null`, wenn nichts gewählt wurde.
Future<KatalogAuswahl?> zeigeKachelKatalog(
  BuildContext context, {
  required StatistikKachelDaten daten,
  required ArbeitskontextReadModel readModel,
  required String Function() neueId,
}) {
  return showModalBottomSheet<KatalogAuswahl>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => FractionallySizedBox(
      heightFactor: 0.94,
      child: KachelKatalogSheet(
        daten: daten,
        readModel: readModel,
        neueId: neueId,
      ),
    ),
  );
}

/// Öffnet den Editor für eine bestehende eigene Kachel.
Future<EigeneKachel?> zeigeEigeneKachelEditor(
  BuildContext context, {
  required ArbeitskontextReadModel readModel,
  required EigeneKachel kachel,
  required String Function() neueId,
}) {
  return showModalBottomSheet<EigeneKachel>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => FractionallySizedBox(
      heightFactor: 0.94,
      child: EigeneKachelEditor(
        readModel: readModel,
        kachel: kachel,
        neueId: neueId,
        onFertig: (k) => Navigator.of(context).pop(k),
      ),
    ),
  );
}

enum _Ansicht { liste, detail, eigene }

/// Katalog aller Kacheltypen nach Bereichen, mit Größenwahl und Einstieg
/// in eigene Kacheln.
class KachelKatalogSheet extends StatefulWidget {
  const KachelKatalogSheet({
    super.key,
    required this.daten,
    required this.readModel,
    required this.neueId,
  });

  final StatistikKachelDaten daten;
  final ArbeitskontextReadModel readModel;
  final String Function() neueId;

  @override
  State<KachelKatalogSheet> createState() => _KachelKatalogSheetState();
}

class _KachelKatalogSheetState extends State<KachelKatalogSheet> {
  _Ansicht _ansicht = _Ansicht.liste;
  KachelDefinition? _gewaehlt;
  KachelGroesse _groesse = KachelGroesse.klein;

  /// Vorschauen ohne echte Karte.
  late final StatistikKachelDaten _vorschauDaten = widget.daten.copyWith(
    kartenBauer: (context, wohnorte, stammesheim) =>
        StatistikKartenVorschau(wohnorte: wohnorte, stammesheim: stammesheim),
  );

  void _oeffnen(KachelDefinition definition) => setState(() {
    _gewaehlt = definition;
    _groesse = definition.groessen.first;
    _ansicht = _Ansicht.detail;
  });

  void _zurueck() => setState(() => _ansicht = _Ansicht.liste);

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: MediaQuery.maybeDisableAnimationsOf(context) ?? false
          ? Duration.zero
          : const Duration(milliseconds: 180),
      child: switch (_ansicht) {
        _Ansicht.liste => _liste(context),
        _Ansicht.detail => _detail(context, _gewaehlt!),
        _Ansicht.eigene => EigeneKachelEditor(
          key: const ValueKey('eigene'),
          readModel: widget.readModel,
          neueId: widget.neueId,
          onZurueck: _zurueck,
          onFertig: (kachel) =>
              Navigator.of(context).pop(KatalogEigeneKachel(kachel)),
        ),
      },
    );
  }

  Widget _liste(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    const bereiche = {
      KachelBereich.mitglieder: 'statistics_catalog_members',
      KachelBereich.stufen: 'statistics_catalog_stages',
      KachelBereich.entwicklung: 'statistics_catalog_development',
      KachelBereich.zusammensetzung: 'statistics_catalog_composition',
    };
    return ListView(
      key: const ValueKey('liste'),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        Text(
          t.t('statistics_edit_add'),
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          t.t('statistics_catalog_hint'),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        Material(
          color: scheme.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            key: const Key('katalog-eigene-kachel'),
            leading: Icon(Icons.add, color: scheme.primary),
            title: Text(
              t.t('statistics_catalog_custom'),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(t.t('statistics_catalog_custom_hint')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => setState(() => _ansicht = _Ansicht.eigene),
          ),
        ),
        for (final MapEntry(key: bereich, value: titel)
            in bereiche.entries) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 22, 4, 6),
            child: Text(
              t.t(titel).toUpperCase(),
              style: theme.textTheme.labelLarge?.copyWith(
                color: scheme.primary,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
              ),
            ),
          ),
          for (final definition in KachelKatalog.definitionen)
            if (definition.bereich == bereich)
              _KatalogZeile(
                definition: definition,
                daten: _vorschauDaten,
                onTap: () => _oeffnen(definition),
              ),
        ],
      ],
    );
  }

  Widget _detail(BuildContext context, KachelDefinition definition) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final eintrag = KachelEintrag(
      id: 'katalog-vorschau',
      typId: definition.typId,
      groesse: _groesse,
    );
    return ListView(
      key: ValueKey('detail-${definition.typId}'),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        SizedBox(
          height: 48,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _zurueck,
                  icon: const Icon(Icons.chevron_left),
                  label: Text(t.t('statistics_catalog_back')),
                ),
              ),
              Text(
                definition.titel(t, _groesse),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        if (definition.groessen.length > 1) ...[
          const SizedBox(height: 12),
          Text(
            t.t('statistics_catalog_size'),
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          SegmentedButton<KachelGroesse>(
            showSelectedIcon: false,
            style: SegmentedButton.styleFrom(
              selectedBackgroundColor: Theme.of(context).colorScheme.primary,
              selectedForegroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
            segments: [
              for (final g in definition.groessen)
                ButtonSegment(value: g, label: Text(groesseText(g))),
            ],
            selected: {_groesse},
            onSelectionChanged: (auswahl) =>
                setState(() => _groesse = auswahl.first),
          ),
        ],
        const SizedBox(height: 16),
        VorschauFlaeche(
          child: _KachelVorschau(daten: _vorschauDaten, eintrag: eintrag),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: () => Navigator.of(
            context,
          ).pop(KatalogKachel(definition.typId, _groesse)),
          child: Text(t.t('statistics_catalog_add')),
        ),
      ],
    );
  }
}

class _KatalogZeile extends StatelessWidget {
  const _KatalogZeile({
    required this.definition,
    required this.daten,
    required this.onTap,
  });

  final KachelDefinition definition;
  final StatistikKachelDaten daten;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final groesse = definition.groessen.first;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            SizedBox(
              width: 116,
              child: _KachelVorschau(
                daten: daten,
                eintrag: KachelEintrag(
                  id: 'katalog-${definition.typId}',
                  typId: definition.typId,
                  groesse: groesse,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    definition.titel(t, groesse),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    definition.groessen.map(groesseText).join(' · '),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}

/// Kachel in Originalgröße gezeichnet und auf die verfügbare Breite
/// verkleinert; nimmt keine Gesten an.
class _KachelVorschau extends StatelessWidget {
  const _KachelVorschau({required this.daten, required this.eintrag});

  final StatistikKachelDaten daten;
  final KachelEintrag eintrag;

  @override
  Widget build(BuildContext context) {
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: AppPageHeader.maxTextScaleFactor,
      child: Builder(
        builder: (context) {
          final metrik = KachelRasterMetrik.aus(
            breite: MediaQuery.sizeOf(context).width - 32,
            textSkala: AppPageHeader.textScaleOf(context),
            maxTextSkala: AppPageHeader.maxTextScaleFactor,
          );
          final groesse = metrik.groesse(eintrag.groesse);
          return ExcludeSemantics(
            child: IgnorePointer(
              child: AspectRatio(
                aspectRatio: groesse.width / groesse.height,
                child: FittedBox(
                  child: SizedBox.fromSize(
                    size: groesse,
                    child: KachelKatalog.kachel(context, daten, eintrag),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

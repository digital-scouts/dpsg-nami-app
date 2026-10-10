import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../domain/veranstaltung/veranstaltung.dart';
import '../../../domain/veranstaltung/veranstaltungs_filter.dart';
import '../../../l10n/app_localizations.dart';

/// Chip-Leiste im Kopf (Entscheidung F1): Art, „Anmeldung offen“, Ebene und
/// Zeitraum. Ebene und Zeitraum oeffnen das Filterfenster. Eine Zeile,
/// waagerecht scrollbar, damit die Kopfhoehe gleich bleibt.
class VeranstaltungenFilterLeiste extends StatelessWidget {
  const VeranstaltungenFilterLeiste({
    super.key,
    required this.filter,
    required this.layerName,
    required this.kategorien,
    required this.onChanged,
    required this.onFensterOeffnen,
  });

  final VeranstaltungsFilter filter;

  /// Name des aktiven Layers fuer den Ebenen-Chip.
  final String? layerName;
  final List<KursartKategorie> kategorien;
  final ValueChanged<VeranstaltungsFilter> onChanged;
  final VoidCallback onFensterOeffnen;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final name = layerName ?? t.t('veranstaltung_ebene_stamm');
    final kategorie = kategorien
        .where((k) => k.id == filter.kategorieId)
        .firstOrNull;
    final chips = <Widget>[
      _Chip(
        key: const Key('veranstaltungen-chip-alle'),
        label: t.t('veranstaltung_chip_alle'),
        aktiv: filter.art == null,
        onTap: () => onChanged(filter.copyWith(art: null)),
      ),
      _Chip(
        key: const Key('veranstaltungen-chip-kurse'),
        label: t.t('veranstaltung_chip_kurse'),
        aktiv: filter.art == VeranstaltungsArt.kurs,
        onTap: () => onChanged(
          filter.copyWith(
            art: filter.art == VeranstaltungsArt.kurs
                ? null
                : VeranstaltungsArt.kurs,
          ),
        ),
      ),
      _Chip(
        key: const Key('veranstaltungen-chip-veranstaltungen'),
        label: t.t('veranstaltung_chip_veranstaltungen'),
        aktiv: filter.art == VeranstaltungsArt.veranstaltung,
        onTap: () => onChanged(
          filter.copyWith(
            art: filter.art == VeranstaltungsArt.veranstaltung
                ? null
                : VeranstaltungsArt.veranstaltung,
          ),
        ),
      ),
      const _Trenner(),
      _Chip(
        key: const Key('veranstaltungen-chip-offen'),
        label: t.t('veranstaltung_chip_offen'),
        aktiv: filter.nurAnmeldungOffen,
        onTap: () => onChanged(
          filter.copyWith(nurAnmeldungOffen: !filter.nurAnmeldungOffen),
        ),
      ),
      _Chip(
        key: const Key('veranstaltungen-chip-ebene'),
        label: switch (filter.ebene) {
          EbenenFilter.alle => t.t('veranstaltung_chip_ebene_alle'),
          EbenenFilter.meinStamm => t.t('veranstaltung_chip_ebene_stamm', {
            'name': name,
          }),
          EbenenFilter.meinStammUndDarueber => t.t(
            'veranstaltung_chip_ebene_darueber',
            {'name': name},
          ),
        },
        aktiv: filter.ebene != VeranstaltungsFilter.standard.ebene,
        auswahl: true,
        onTap: onFensterOeffnen,
      ),
      _Chip(
        key: const Key('veranstaltungen-chip-zeitraum'),
        label: filter.zeitraum == VeranstaltungsFilter.standard.zeitraum
            ? t.t('veranstaltung_chip_zeitraum')
            : zeitraumLabel(context, filter),
        aktiv: filter.zeitraum != VeranstaltungsFilter.standard.zeitraum,
        auswahl: true,
        onTap: onFensterOeffnen,
      ),
      if (kategorie != null)
        _Chip(
          key: const Key('veranstaltungen-chip-kategorie'),
          label: t.t('veranstaltung_chip_kategorie', {'name': kategorie.label}),
          aktiv: true,
          auswahl: true,
          onTap: onFensterOeffnen,
        ),
    ];
    // Wenige Chips: eine einfache scrollbare Zeile, alle Chips gebaut.
    return LayoutBuilder(
      builder: (context, constraints) => SizedBox(
        height: constraints.hasTightHeight ? constraints.maxHeight : 34,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 8,
            children: chips,
          ),
        ),
      ),
    );
  }
}

/// Beschriftung des gewaehlten Zeitraums, beim eigenen mit Datum.
String zeitraumLabel(BuildContext context, VeranstaltungsFilter filter) {
  final t = AppLocalizations.of(context);
  switch (filter.zeitraum) {
    case ZeitraumFilter.vierWochen:
      return t.t('veranstaltung_zeitraum_vier_wochen');
    case ZeitraumFilter.dreiMonate:
      return t.t('veranstaltung_zeitraum_drei_monate');
    case ZeitraumFilter.alleKommenden:
      return t.t('veranstaltung_zeitraum_alle');
    case ZeitraumFilter.eigener:
      final format = DateFormat('d.M.', t.locale.languageCode);
      final von = filter.eigenerVon;
      final bis = filter.eigenerBis;
      if (von == null || bis == null) {
        return t.t('veranstaltung_zeitraum_eigener');
      }
      return '${format.format(von)}–${format.format(bis)}';
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    super.key,
    required this.label,
    required this.aktiv,
    required this.onTap,
    this.auswahl = false,
  });

  final String label;
  final bool aktiv;
  final VoidCallback onTap;

  /// Oeffnet eine Auswahl statt umzuschalten (mit Pfeil).
  final bool auswahl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final akzent = theme.colorScheme.primary;
    final hintergrund = aktiv
        ? akzent.withValues(
            alpha: theme.brightness == Brightness.dark ? 0.3 : 0.12,
          )
        : theme.colorScheme.surface;
    final rand = aktiv
        ? akzent
        : theme.colorScheme.outline.withValues(alpha: 0.55);
    final text = aktiv ? akzent : theme.colorScheme.onSurface;
    return Semantics(
      button: true,
      selected: aktiv,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          height: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: hintergrund,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: rand, width: 1.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 200),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: text,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (auswahl) ...[
                const SizedBox(width: 2),
                Icon(Icons.arrow_drop_down, size: 18, color: text),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Trenner extends StatelessWidget {
  const _Trenner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      margin: const EdgeInsets.symmetric(vertical: 7),
      color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.55),
    );
  }
}

/// Filterfenster als Bottom Sheet: Kursart-Kategorie, Ebene, Zeitraum.
/// Gibt den neuen Filter zurueck, `null` bei Abbruch.
Future<VeranstaltungsFilter?> zeigeVeranstaltungenFilter(
  BuildContext context, {
  required VeranstaltungsFilter filter,
  required String? layerName,
  required List<KursartKategorie> kategorien,
  required int? Function(VeranstaltungsFilter filter) trefferFuer,
}) {
  return showModalBottomSheet<VeranstaltungsFilter>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (context) => _FilterFenster(
      start: filter,
      layerName: layerName,
      kategorien: kategorien,
      trefferFuer: trefferFuer,
    ),
  );
}

class _FilterFenster extends StatefulWidget {
  const _FilterFenster({
    required this.start,
    required this.layerName,
    required this.kategorien,
    required this.trefferFuer,
  });

  final VeranstaltungsFilter start;
  final String? layerName;
  final List<KursartKategorie> kategorien;
  final int? Function(VeranstaltungsFilter filter) trefferFuer;

  @override
  State<_FilterFenster> createState() => _FilterFensterState();
}

class _FilterFensterState extends State<_FilterFenster> {
  late VeranstaltungsFilter _filter = widget.start;

  Future<void> _eigenerZeitraum() async {
    final heute = DateUtils.dateOnly(DateTime.now());
    final von = _filter.eigenerVon;
    final bis = _filter.eigenerBis;
    final bereich = await showDateRangePicker(
      context: context,
      firstDate: heute,
      lastDate: DateTime(heute.year + 3, 12, 31),
      initialDateRange: von != null && bis != null
          ? DateTimeRange(start: von, end: bis)
          : null,
    );
    if (bereich == null || !mounted) {
      return;
    }
    setState(
      () => _filter = _filter.copyWith(
        zeitraum: ZeitraumFilter.eigener,
        eigenerVon: bereich.start,
        eigenerBis: bereich.end,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final layer = widget.layerName;

    Widget ueberschrift(String text) => Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );

    Widget ebene(EbenenFilter wert, String titel, String? text) =>
        RadioListTile<EbenenFilter>(
          key: Key('veranstaltungen-ebene-${wert.name}'),
          value: wert,
          contentPadding: EdgeInsets.zero,
          title: Text(titel),
          subtitle: text == null ? null : Text(text),
        );

    final treffer = widget.trefferFuer(_filter);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            t.t('veranstaltung_filter_titel'),
            style: theme.textTheme.titleLarge,
          ),
          if (widget.kategorien.isNotEmpty) ...[
            ueberschrift(t.t('veranstaltung_filter_kategorie')),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: Text(t.t('veranstaltung_filter_alle')),
                  selected: _filter.kategorieId == null,
                  onSelected: (_) => setState(
                    () => _filter = _filter.copyWith(kategorieId: null),
                  ),
                ),
                for (final kategorie in widget.kategorien)
                  ChoiceChip(
                    label: Text(kategorie.label),
                    selected: _filter.kategorieId == kategorie.id,
                    onSelected: (_) => setState(
                      () =>
                          _filter = _filter.copyWith(kategorieId: kategorie.id),
                    ),
                  ),
              ],
            ),
          ],
          ueberschrift(t.t('veranstaltung_filter_ebene')),
          RadioGroup<EbenenFilter>(
            groupValue: _filter.ebene,
            onChanged: (wert) {
              if (wert != null) {
                setState(() => _filter = _filter.copyWith(ebene: wert));
              }
            },
            child: Column(
              children: [
                ebene(
                  EbenenFilter.meinStamm,
                  t.t('veranstaltung_ebene_stamm'),
                  layer,
                ),
                ebene(
                  EbenenFilter.meinStammUndDarueber,
                  t.t('veranstaltung_ebene_darueber'),
                  t.t('veranstaltung_ebene_darueber_text'),
                ),
                ebene(
                  EbenenFilter.alle,
                  t.t('veranstaltung_ebene_alle'),
                  t.t('veranstaltung_ebene_alle_text'),
                ),
              ],
            ),
          ),
          ueberschrift(t.t('veranstaltung_filter_zeitraum')),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final zeitraum in [
                ZeitraumFilter.vierWochen,
                ZeitraumFilter.dreiMonate,
                ZeitraumFilter.alleKommenden,
              ])
                ChoiceChip(
                  label: Text(
                    zeitraumLabel(
                      context,
                      VeranstaltungsFilter(zeitraum: zeitraum),
                    ),
                  ),
                  selected: _filter.zeitraum == zeitraum,
                  onSelected: (_) => setState(
                    () => _filter = _filter.copyWith(zeitraum: zeitraum),
                  ),
                ),
              ChoiceChip(
                key: const Key('veranstaltungen-zeitraum-eigener'),
                label: Text(
                  _filter.zeitraum == ZeitraumFilter.eigener
                      ? zeitraumLabel(context, _filter)
                      : t.t('veranstaltung_zeitraum_eigener'),
                ),
                selected: _filter.zeitraum == ZeitraumFilter.eigener,
                onSelected: (_) => _eigenerZeitraum(),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(
                    () => _filter = VeranstaltungsFilter.standard.copyWith(
                      suchtext: _filter.suchtext,
                    ),
                  ),
                  child: Text(t.t('veranstaltung_filter_zuruecksetzen')),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  key: const Key('veranstaltungen-filter-anzeigen'),
                  onPressed: () => Navigator.of(context).pop(_filter),
                  child: Text(
                    treffer == null
                        ? t.t('veranstaltung_filter_anzeigen_ohne')
                        : t.t('veranstaltung_filter_anzeigen', {'n': treffer}),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

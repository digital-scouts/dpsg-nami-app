import 'package:flutter/material.dart';

import '../../domain/arbeitskontext/arbeitskontext_read_model.dart';
import '../../domain/member_filters/member_custom_filter.dart';
import '../../domain/statistiks/statistik_kachel_einstellungen.dart';
import '../../domain/statistiks/statistik_kachel_typen.dart';
import '../../domain/statistiks/zaehle_eigene_kachel_usecase.dart';
import '../../l10n/app_localizations.dart';
import '../widgets/app_page_header.dart';
import '../widgets/member_filter_sort_sheet.dart';
import 'kacheln/inhalte_zusammensetzung.dart';
import 'kacheln/kachel_rahmen.dart';
import 'kacheln/kachel_raster_packer.dart';

/// Formular für eine eigene Zählkachel: Name, Regeln wie bei den eigenen
/// Filtern der Mitgliederliste, Darstellung, optionaler Zielwert und eine
/// Vorschau im Endaussehen.
class EigeneKachelEditor extends StatefulWidget {
  const EigeneKachelEditor({
    super.key,
    required this.readModel,
    required this.neueId,
    required this.onFertig,
    this.kachel,
    this.onZurueck,
    this.scrollController,
  });

  final ArbeitskontextReadModel readModel;

  /// Bestehende Kachel; `null` legt eine neue an.
  final EigeneKachel? kachel;
  final String Function() neueId;
  final ValueChanged<EigeneKachel> onFertig;

  /// Zeigt „‹ Katalog“, wenn gesetzt.
  final VoidCallback? onZurueck;
  final ScrollController? scrollController;

  @override
  State<EigeneKachelEditor> createState() => _EigeneKachelEditorState();
}

class _EigeneKachelEditorState extends State<EigeneKachelEditor> {
  static const int _zielStart = 3;
  static const int _zielMax = 999;

  late final TextEditingController _name = TextEditingController(
    text: widget.kachel?.titel ?? '',
  );
  late final TextEditingController _zielText = TextEditingController(
    text: widget.kachel?.zielText ?? '',
  );
  late MemberCustomFilterLogic _logic =
      widget.kachel?.filter.logic ?? MemberCustomFilterLogic.oder;
  late List<MemberCustomFilterRule> _rules = List.of(
    widget.kachel?.filter.rules ??
        const [
          MemberCustomFilterRule(
            operator: MemberCustomFilterRuleOperator.hat,
            criterion: MemberCustomFilterCriterion.stufe(),
          ),
        ],
  );
  late EigeneKachelDarstellung _darstellung =
      widget.kachel?.darstellung ?? EigeneKachelDarstellung.zahl;
  late bool _mitZiel = widget.kachel?.ziel != null;
  late int _ziel = widget.kachel?.ziel ?? _zielStart;
  bool _nameFehlt = false;

  late final String _id = widget.kachel?.id ?? 'kachel-${widget.neueId()}';

  @override
  void initState() {
    super.initState();
    _name.addListener(_neuZeichnen);
    _zielText.addListener(_neuZeichnen);
  }

  @override
  void dispose() {
    _name.dispose();
    _zielText.dispose();
    super.dispose();
  }

  void _neuZeichnen() {
    if (_nameFehlt && _name.text.trim().isNotEmpty) _nameFehlt = false;
    setState(() {});
  }

  EigeneKachel _kachel({String? ersatzTitel}) {
    final titel = _name.text.trim().isEmpty
        ? (ersatzTitel ?? '')
        : _name.text.trim();
    final zielText = _zielText.text.trim();
    return EigeneKachel(
      id: _id,
      titel: titel,
      filter: MemberCustomFilterGroup(
        id: _id,
        shortLabel: titel.isEmpty ? '–' : titel,
        isActive: true,
        logic: _logic,
        rules: List.unmodifiable(_rules),
      ),
      darstellung: _darstellung,
      ziel: _mitZiel ? _ziel : null,
      zielText: _mitZiel && zielText.isNotEmpty ? zielText : null,
    );
  }

  void _speichern() {
    if (_name.text.trim().isEmpty) {
      setState(() => _nameFehlt = true);
      return;
    }
    widget.onFertig(_kachel());
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    Widget label(String text) => Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 8),
      child: Text(
        text,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
    );
    final vorschau = _kachel(ersatzTitel: t.t('statistics_custom_title'));
    return ListView(
      controller: widget.scrollController,
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      children: [
        SizedBox(
          height: 48,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (widget.onZurueck != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: widget.onZurueck,
                    icon: const Icon(Icons.chevron_left),
                    label: Text(t.t('statistics_catalog_back')),
                  ),
                ),
              Text(
                t.t('statistics_custom_title'),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        label(t.t('statistics_custom_name')),
        TextField(
          key: const Key('eigene-kachel-name'),
          controller: _name,
          maxLength: 40,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            errorText: _nameFehlt
                ? t.t('statistics_custom_name_missing')
                : null,
          ),
        ),
        label(t.t('statistics_custom_who')),
        MemberFilterRegelEditor(
          readModel: widget.readModel,
          logic: _logic,
          rules: _rules,
          onChanged: (logic, rules) => setState(() {
            _logic = logic;
            _rules = rules;
          }),
        ),
        label(t.t('statistics_custom_display')),
        SegmentedButton<EigeneKachelDarstellung>(
          showSelectedIcon: false,
          style: SegmentedButton.styleFrom(
            selectedBackgroundColor: Theme.of(context).colorScheme.primary,
            selectedForegroundColor: Theme.of(context).colorScheme.onPrimary,
          ),
          segments: [
            ButtonSegment(
              value: EigeneKachelDarstellung.zahl,
              label: Text(t.t('statistics_custom_display_number')),
            ),
            ButtonSegment(
              value: EigeneKachelDarstellung.nachStufe,
              label: Text(t.t('statistics_custom_display_stage')),
            ),
          ],
          selected: {_darstellung},
          onSelectionChanged: (auswahl) =>
              setState(() => _darstellung = auswahl.first),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Text(
                t.t('statistics_custom_target'),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (_mitZiel) ...[
              IconButton(
                tooltip: t.t('statistics_custom_less'),
                onPressed: _ziel > 1 ? () => setState(() => _ziel--) : null,
                icon: const Icon(Icons.remove),
              ),
              SizedBox(
                width: 40,
                child: Text(
                  '$_ziel',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                tooltip: t.t('statistics_custom_more'),
                onPressed: _ziel < _zielMax
                    ? () => setState(() => _ziel++)
                    : null,
                icon: const Icon(Icons.add),
              ),
            ],
            Switch(
              value: _mitZiel,
              onChanged: (wert) => setState(() => _mitZiel = wert),
            ),
          ],
        ),
        if (_mitZiel)
          TextField(
            controller: _zielText,
            maxLength: 20,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              labelText: t.t('statistics_custom_target_text'),
              hintText: t.t('statistics_custom_target_text_hint'),
            ),
          ),
        label(t.t('statistics_custom_preview')),
        VorschauFlaeche(
          child: _Vorschau(kachel: vorschau, readModel: widget.readModel),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _speichern,
          child: Text(
            widget.kachel == null
                ? t.t('statistics_custom_add')
                : t.t('statistics_custom_save'),
          ),
        ),
      ],
    );
  }
}

class _Vorschau extends StatelessWidget {
  const _Vorschau({required this.kachel, required this.readModel});

  final EigeneKachel kachel;
  final ArbeitskontextReadModel readModel;

  @override
  Widget build(BuildContext context) {
    final zaehlung = const ZaehleEigeneKachelUseCase()(
      readModel,
      kachel.filter,
    );
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: AppPageHeader.maxTextScaleFactor,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final metrik = KachelRasterMetrik.aus(
            breite: MediaQuery.sizeOf(context).width - 32,
            textSkala: AppPageHeader.textScaleOf(context),
            maxTextSkala: AppPageHeader.maxTextScaleFactor,
          );
          final groesse = metrik.groesse(KachelGroesse.klein);
          return Align(
            alignment: Alignment.centerLeft,
            child: SizedBox.fromSize(
              size: Size(
                groesse.width.clamp(0, constraints.maxWidth).toDouble(),
                groesse.height,
              ),
              child: IgnorePointer(
                child: KachelRahmen(
                  titel: kachel.titel,
                  child: EigeneKachelInhalt(
                    kachel: kachel,
                    zaehlung: zaehlung,
                    groesse: KachelGroesse.klein,
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

/// Hintergrund der Seite hinter Vorschauen, damit die Kachel wie auf der
/// Statistikseite wirkt.
class VorschauFlaeche extends StatelessWidget {
  const VorschauFlaeche({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(padding: const EdgeInsets.all(12), child: child),
    );
  }
}

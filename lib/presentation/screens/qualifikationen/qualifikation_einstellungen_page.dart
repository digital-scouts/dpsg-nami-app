import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../domain/arbeitskontext/arbeitskontext_read_model.dart';
import '../../../domain/member/member_utils.dart';
import '../../../domain/member/mitglied.dart';
import '../../../domain/qualifikation/ermittle_qualifikations_uebersicht_usecase.dart';
import '../../../domain/qualifikation/personenkreis.dart';
import '../../../domain/qualifikation/plane_qualifikations_erinnerungen_usecase.dart';
import '../../../domain/qualifikation/qualifikations_einstellungen.dart';
import '../../../domain/taetigkeit/stufe.dart';
import '../../../l10n/app_localizations.dart';
import '../../model/qualifikations_einstellungen_model.dart';
import '../../widgets/qualifikationen/qualifikation_bausteine.dart';
import '../../widgets/section_header.dart';
import 'qualifikationen_kontext.dart';

/// Personenkreis, Erinnerung und Gueltigkeit einer Art. Jede Aenderung wird
/// sofort gespeichert.
class QualifikationEinstellungenPage extends StatelessWidget {
  const QualifikationEinstellungenPage({
    super.key,
    required this.schluessel,
    this.readModel,
    this.heuteProvider,
  });

  final String schluessel;
  final ArbeitskontextReadModel? readModel;
  final DateTime Function()? heuteProvider;

  static const _useCase = ErmittleQualifikationsUebersichtUseCase();
  static final _alterWerte = <int>[
    for (var i = 6; i <= 30; i++) i,
    for (var i = 35; i <= 70; i += 5) i,
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context);
    final model = context.watch<QualifikationsEinstellungenModel>();
    final readModel = QualifikationenKontext.readModel(context, this.readModel);
    KatalogEintrag? katalog;
    if (readModel != null) {
      for (final eintrag in _useCase.katalog(
        readModel: readModel,
        einstellungen: model.einstellungen,
      )) {
        if (eintrag.art.schluessel == schluessel) {
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
    final eintrag = katalog;
    final heute = QualifikationenKontext.heute(heuteProvider);
    final rollentypen = _rollentypen(readModel, heute);
    final kreis = eintrag.personenkreis;
    final erinnerung = eintrag.erinnerung;
    final imKreis = readModel.mitglieder
        .where((m) => m.personId != null && kreis.enthaelt(m, heute: heute))
        .toList(growable: false);

    Future<void> kreisSpeichern(List<PersonenkreisRegel> regeln) =>
        model.artAendern(
          schluessel,
          (alt) => alt.copyWith(personenkreis: Personenkreis(regeln)),
        );
    Future<void> erinnerungSpeichern(QualifikationsErinnerung neu) =>
        model.artAendern(schluessel, (alt) => alt.copyWith(erinnerung: neu));

    final leise = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          t.t('quali_einstellen_titel', {
            'art': eintrag.art.istEfz ? 'EFZ' : eintrag.art.label,
          }),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Row(
            children: [
              QualifikationArtSymbol(art: eintrag.art, size: 36),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  eintrag.art.label,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          DpsgSectionHeader(label: t.t('quali_wer_braucht')),
          Card(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < kreis.regeln.length; i++) ...[
                  _RegelZeile(
                    index: i,
                    regel: kreis.regeln[i],
                    rollentypen: rollentypen,
                    alterWerte: _alterWerte,
                    onAendern: (neu) {
                      final regeln = [...kreis.regeln]..[i] = neu;
                      kreisSpeichern(regeln);
                    },
                    onEntfernen: () {
                      final regeln = [...kreis.regeln]..removeAt(i);
                      kreisSpeichern(regeln);
                    },
                  ),
                  const Divider(height: 1, indent: 16),
                ],
                ListTile(
                  key: const Key('quali-regel-hinzufuegen'),
                  leading: Icon(Icons.add, color: theme.colorScheme.primary),
                  title: Text(
                    t.t('quali_regel_hinzufuegen'),
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(t.t('quali_regel_hinzufuegen_hinweis')),
                  onTap: () async {
                    final typ = await _waehleTyp(context);
                    if (typ == null) {
                      return;
                    }
                    await kreisSpeichern([
                      ...kreis.regeln,
                      PersonenkreisRegel(
                        typ: typ,
                        wert: _standardWert(typ, rollentypen),
                      ),
                    ]);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          InkWell(
            key: const Key('quali-kreis-vorschau'),
            borderRadius: BorderRadius.circular(8),
            onTap: imKreis.isEmpty ? null : () => _zeigeKreis(context, imKreis),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.group_outlined, size: 18, color: theme.hintColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      kreis.regeln.isEmpty
                          ? t.t('quali_kreis_leer')
                          : imKreis.length == 1
                          ? t.t('quali_betrifft_eins')
                          : t.t('quali_betrifft', {'n': imKreis.length}),
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  if (imKreis.isNotEmpty)
                    Icon(Icons.chevron_right, color: theme.colorScheme.outline),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          DpsgSectionHeader(label: t.t('quali_erinnerung')),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SegmentedButton<bool>(
                    key: const Key('quali-erinnerung-aktiv'),
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment<bool>(
                        value: false,
                        label: Text(t.t('quali_erinnerung_aus')),
                      ),
                      ButtonSegment<bool>(
                        value: true,
                        label: Text(t.t('quali_erinnerung_vorher')),
                      ),
                    ],
                    selected: <bool>{erinnerung.aktiv},
                    onSelectionChanged: (auswahl) => erinnerungSpeichern(
                      erinnerung.copyWith(aktiv: auswahl.first),
                    ),
                  ),
                  if (erinnerung.aktiv) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            t.t('quali_erinnern'),
                            style: theme.textTheme.bodyLarge,
                          ),
                        ),
                        QualifikationTageStepper(
                          tage: erinnerung.tageVorher,
                          onAendern: (tage) => erinnerungSpeichern(
                            erinnerung.copyWith(tageVorher: tage),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      t.t('quali_von_wem'),
                      style: theme.textTheme.bodyLarge,
                    ),
                    RadioGroup<ErinnerungVonWem>(
                      groupValue: erinnerung.vonWem,
                      onChanged: (wert) {
                        if (wert != null) {
                          erinnerungSpeichern(
                            erinnerung.copyWith(vonWem: wert),
                          );
                        }
                      },
                      child: Column(
                        children: [
                          RadioListTile<ErinnerungVonWem>(
                            key: const Key('quali-von-allen'),
                            contentPadding: EdgeInsets.zero,
                            value: ErinnerungVonWem.alle,
                            title: Text(t.t('quali_von_allen')),
                            subtitle: Text(t.t('quali_von_allen_hinweis')),
                          ),
                          RadioListTile<ErinnerungVonWem>(
                            key: const Key('quali-nur-von-mir'),
                            contentPadding: EdgeInsets.zero,
                            value: ErinnerungVonWem.ich,
                            title: Text(t.t('quali_nur_von_mir')),
                            subtitle: Text(t.t('quali_nur_von_mir_hinweis')),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
            child: Text(
              t.t('quali_warnschwelle_hinweis', {
                'n': erinnerung.warnschwelleTage,
              }),
              style: leise,
            ),
          ),
          const SizedBox(height: 16),
          DpsgSectionHeader(label: t.t('quali_gueltigkeit')),
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              title: Text(qualiRegelmaessigkeit(t, eintrag.art)),
              trailing: eintrag.art.istEfz
                  ? null
                  : Text(t.t('quali_aus_hitobito'), style: leise),
            ),
          ),
          if (eintrag.art.istEfz)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
              child: Text(t.t('quali_efz_gueltigkeit_hinweis'), style: leise),
            ),
        ],
      ),
    );
  }

  /// Rollentypen der heute aktiven Rollen im Kontext, nach Label sortiert.
  static Map<String, String> _rollentypen(
    ArbeitskontextReadModel readModel,
    DateTime heute,
  ) {
    final typen = <String, String>{};
    for (final mitglied in readModel.mitglieder) {
      for (final rolle in mitglied.roles) {
        if (!rolle.isActiveAt(heute) || MemberUtils.istMitgliederRolle(rolle)) {
          continue;
        }
        final typ = rollentypVon(rolle);
        final label = rolle.resolvedLabel;
        if (typ != null && label != null) {
          typen.putIfAbsent(typ, () => label);
        }
      }
    }
    final sortiert = typen.entries.toList()
      ..sort((a, b) => a.value.toLowerCase().compareTo(b.value.toLowerCase()));
    return <String, String>{for (final e in sortiert) e.key: e.value};
  }

  static String _standardWert(
    PersonenkreisRegelTyp typ,
    Map<String, String> rollentypen,
  ) => switch (typ) {
    PersonenkreisRegelTyp.rollenart => Rollenart.leitung.name,
    PersonenkreisRegelTyp.stufe => Stufe.woelfling.name,
    PersonenkreisRegelTyp.rollentyp =>
      rollentypen.isEmpty ? '' : rollentypen.keys.first,
    PersonenkreisRegelTyp.alterAb => '16',
    PersonenkreisRegelTyp.alterBis => '20',
  };

  Future<PersonenkreisRegelTyp?> _waehleTyp(BuildContext context) {
    final t = AppLocalizations.of(context);
    return showModalBottomSheet<PersonenkreisRegelTyp>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final typ in PersonenkreisRegelTyp.values)
              ListTile(
                key: Key('quali-regeltyp-${typ.name}'),
                title: Text(qualiRegelTypLabel(t, typ)),
                onTap: () => Navigator.of(context).pop(typ),
              ),
          ],
        ),
      ),
    );
  }

  void _zeigeKreis(BuildContext context, List<Mitglied> personen) {
    final sortiert = [...personen]
      ..sort(
        (a, b) => anzeigenameFuerErinnerung(
          a,
        ).toLowerCase().compareTo(anzeigenameFuerErinnerung(b).toLowerCase()),
      );
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        builder: (context, controller) => ListView(
          controller: controller,
          children: [
            for (final person in sortiert)
              ListTile(title: Text(anzeigenameFuerErinnerung(person))),
          ],
        ),
      ),
    );
  }
}

class _RegelZeile extends StatelessWidget {
  const _RegelZeile({
    required this.index,
    required this.regel,
    required this.rollentypen,
    required this.alterWerte,
    required this.onAendern,
    required this.onEntfernen,
  });

  final int index;
  final PersonenkreisRegel regel;
  final Map<String, String> rollentypen;
  final List<int> alterWerte;
  final ValueChanged<PersonenkreisRegel> onAendern;
  final VoidCallback onEntfernen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context);
    final verknuepfung = index == 0
        ? t.t('quali_regel_wer')
        : t.t(
            regel.verknuepfung == RegelVerknuepfung.und
                ? 'quali_regel_und'
                : 'quali_regel_oder',
          );

    final werte = _werte(t);
    return Padding(
      key: Key('quali-regel-$index'),
      padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: InkWell(
              key: Key('quali-regel-verknuepfung-$index'),
              onTap: index == 0
                  ? null
                  : () => onAendern(
                      regel.copyWith(
                        verknuepfung:
                            regel.verknuepfung == RegelVerknuepfung.und
                            ? RegelVerknuepfung.oder
                            : RegelVerknuepfung.und,
                      ),
                    ),
              child: Text(
                verknuepfung.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: index == 0
                      ? theme.colorScheme.onSurfaceVariant
                      : theme.colorScheme.primary,
                ),
              ),
            ),
          ),
          _Auswahlfeld<PersonenkreisRegelTyp>(
            key: Key('quali-regel-typ-$index'),
            label: qualiRegelTypLabel(t, regel.typ),
            optionen: {
              for (final typ in PersonenkreisRegelTyp.values)
                typ: qualiRegelTypLabel(t, typ),
            },
            onGewaehlt: (typ) {
              if (typ == regel.typ) {
                return;
              }
              onAendern(
                regel.copyWith(
                  typ: typ,
                  wert: QualifikationEinstellungenPage._standardWert(
                    typ,
                    rollentypen,
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 6),
          Flexible(
            child: _Auswahlfeld<String>(
              key: Key('quali-regel-wert-$index'),
              betont: true,
              label: regel.wert.isEmpty
                  ? t.t('quali_regel_wert_waehlen')
                  : _wertLabel(t),
              optionen: werte,
              onGewaehlt: (wert) => onAendern(regel.copyWith(wert: wert)),
            ),
          ),
          IconButton(
            tooltip: t.t('quali_regel_entfernen'),
            icon: const Icon(Icons.close, size: 18),
            onPressed: onEntfernen,
          ),
        ],
      ),
    );
  }

  String _wertLabel(AppLocalizations t) => switch (regel.typ) {
    PersonenkreisRegelTyp.alterAb || PersonenkreisRegelTyp.alterBis => t.t(
      'quali_regel_alter_jahre',
      {'n': regel.wert},
    ),
    _ => qualiRegelWertLabel(t, regel, rollentypLabels: rollentypen),
  };

  Map<String, String> _werte(AppLocalizations t) => switch (regel.typ) {
    PersonenkreisRegelTyp.rollenart => {
      for (final art in Rollenart.values)
        art.name:
            '${t.t('quali_rollenart_${art.name}')} · '
            '${t.t('quali_rollenart_${art.name}_hinweis')}',
    },
    PersonenkreisRegelTyp.stufe => {
      for (final stufe in Stufe.values)
        if (stufe != Stufe.leitung) stufe.name: stufe.displayName,
    },
    PersonenkreisRegelTyp.rollentyp => rollentypen,
    PersonenkreisRegelTyp.alterAb || PersonenkreisRegelTyp.alterBis => {
      for (final alter in alterWerte)
        '$alter': t.t('quali_regel_alter_jahre', {'n': alter}),
    },
  };
}

class _Auswahlfeld<T> extends StatelessWidget {
  const _Auswahlfeld({
    super.key,
    required this.label,
    required this.optionen,
    required this.onGewaehlt,
    this.betont = false,
  });

  final String label;
  final Map<T, String> optionen;
  final ValueChanged<T> onGewaehlt;
  final bool betont;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vordergrund = betont
        ? theme.colorScheme.onPrimaryContainer
        : theme.colorScheme.onSurface;
    return PopupMenuButton<T>(
      onSelected: onGewaehlt,
      itemBuilder: (context) => [
        for (final option in optionen.entries)
          PopupMenuItem<T>(value: option.key, child: Text(option.value)),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: betont
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: vordergrund,
                  fontWeight: betont ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
            Icon(Icons.expand_more, size: 16, color: vordergrund),
          ],
        ),
      ),
    );
  }
}

/// Tage vorher, frei waehlbar: Minus und Plus, ein Tipp auf die Zahl oeffnet
/// die Eingabe.
class QualifikationTageStepper extends StatelessWidget {
  const QualifikationTageStepper({
    super.key,
    required this.tage,
    required this.onAendern,
  });

  final int tage;
  final ValueChanged<int> onAendern;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.filledTonal(
          key: const Key('quali-tage-weniger'),
          tooltip: t.t('quali_tage_weniger'),
          visualDensity: VisualDensity.compact,
          iconSize: 18,
          onPressed: tage > QualifikationsErinnerung.minTage
              ? () => onAendern(tage - 1)
              : null,
          icon: const Icon(Icons.remove),
        ),
        InkWell(
          key: const Key('quali-tage-wert'),
          borderRadius: BorderRadius.circular(8),
          onTap: () async {
            final neu = await _eingabe(context);
            if (neu != null) {
              onAendern(neu);
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Column(
              children: [
                Text(
                  '$tage',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  t.t('quali_tage_vorher'),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
        IconButton.filledTonal(
          key: const Key('quali-tage-mehr'),
          tooltip: t.t('quali_tage_mehr'),
          visualDensity: VisualDensity.compact,
          iconSize: 18,
          onPressed: tage < QualifikationsErinnerung.maxTage
              ? () => onAendern(tage + 1)
              : null,
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }

  Future<int?> _eingabe(BuildContext context) async {
    final t = AppLocalizations.of(context);
    final controller = TextEditingController(text: '$tage');
    final ergebnis = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.t('quali_tage_vorher')),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(int.tryParse(controller.text)),
            child: Text(MaterialLocalizations.of(context).okButtonLabel),
          ),
        ],
      ),
    );
    controller.dispose();
    return ergebnis?.clamp(
      QualifikationsErinnerung.minTage,
      QualifikationsErinnerung.maxTage,
    );
  }
}

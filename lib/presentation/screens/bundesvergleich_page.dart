import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../domain/bundesstatistik/bundesaggregat.dart';
import '../../domain/bundesstatistik/stammes_snapshot.dart';
import '../../domain/rechtliches/anbieter.dart';
import '../../domain/taetigkeit/stufe.dart';
import '../../l10n/app_localizations.dart';
import '../model/bundesstatistik_model.dart';
import '../statistics/statistics_ui.dart';
import '../widgets/bundesstatistik_einwilligung_dialog.dart';

/// Bundesweiter Vergleich mit Einwilligung und Transparenz ueber geteilte Daten.
class BundesvergleichPage extends StatelessWidget {
  const BundesvergleichPage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.t('bund_page_title'))),
      body: const BundesvergleichBody(),
    );
  }
}

/// Inhalt des bundesweiten Vergleichs, angebunden an [BundesstatistikModel];
/// genutzt von [BundesvergleichPage] und dem Statistik-Tab "Bundesweit".
class BundesvergleichBody extends StatefulWidget {
  const BundesvergleichBody({super.key});

  @override
  State<BundesvergleichBody> createState() => _BundesvergleichBodyState();
}

class _BundesvergleichBodyState extends State<BundesvergleichBody> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final model = context.read<BundesstatistikModel>();
      if (model.hatEinwilligung) {
        model.aktualisieren();
      }
      model.ladeInstallationsId();
    });
  }

  Future<void> _einwilligungAendern(bool erteilen) async {
    final model = context.read<BundesstatistikModel>();
    if (erteilen &&
        !await zeigeBundesstatistikEinwilligungDialog(
          context,
          stammName: model.stammName,
        )) {
      return;
    }
    await model.setzeEinwilligung(erteilen);
  }

  @override
  Widget build(BuildContext context) {
    final model = context.watch<BundesstatistikModel>();
    return RefreshIndicator(
      onRefresh: model.hatEinwilligung ? model.aktualisieren : () async {},
      child: BundesvergleichView(
        status: model.status,
        hatEinwilligung: model.hatEinwilligung,
        isBusy: model.isBusy,
        aggregat: model.aggregat,
        eigeneKennzahlen: model.eigeneKennzahlen,
        zuletztGesendet: model.zuletztGesendeterSnapshot,
        einwilligungAm: model.einwilligungAm,
        gruppenName: model.gruppenName,
        installationsId: model.installationsId,
        onEinwilligungAendern: _einwilligungAendern,
      ),
    );
  }
}

class BundesvergleichView extends StatelessWidget {
  const BundesvergleichView({
    super.key,
    required this.status,
    required this.hatEinwilligung,
    required this.onEinwilligungAendern,
    this.isBusy = false,
    this.aggregat,
    this.eigeneKennzahlen,
    this.zuletztGesendet,
    this.einwilligungAm,
    this.gruppenName,
    this.installationsId,
  });

  final BundesstatistikStatus status;
  final bool hatEinwilligung;
  final bool isBusy;
  final Bundesaggregat? aggregat;
  final StammesKennzahlen? eigeneKennzahlen;
  final StammesSnapshot? zuletztGesendet;
  final DateTime? einwilligungAm;

  /// Name einer Gruppe nach ID; ohne Namen erscheint „Gruppe 123“.
  final String? Function(int gruppenId)? gruppenName;
  final ValueChanged<bool> onEinwilligungAendern;

  /// Fuer Auskunft und Loeschung auf Anfrage; nur bekannt, wenn schon geteilt.
  final String? installationsId;

  static const List<Stufe> stufen = <Stufe>[
    Stufe.biber,
    Stufe.woelfling,
    Stufe.jungpfadfinder,
    Stufe.pfadfinder,
    Stufe.rover,
  ];

  static const List<(String, String)> _geschlechter = <(String, String)>[
    ('weiblich', 'bund_female'),
    ('maennlich', 'bund_male'),
    ('divers', 'bund_diverse'),
    ('geschlecht_unbekannt', 'bund_gender_unknown'),
  ];

  /// Nur einzelne Gruppen lesbar: Vergleich mit Gruppen derselben Stufe.
  bool get _teilsicht => !(eigeneKennzahlen?.abdeckung.istStamm ?? true);

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final aggregat = this.aggregat;
    final zeigeVergleich =
        status == BundesstatistikStatus.bereit && aggregat != null;

    if (status == BundesstatistikStatus.nichtVerfuegbar) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [_StatusHinweis(status: status, aggregat: aggregat)],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        if (hatEinwilligung)
          _EinwilligungCard(
            hatEinwilligung: hatEinwilligung,
            einwilligungAm: einwilligungAm,
            teilsicht: _teilsicht,
            onChanged: onEinwilligungAendern,
          )
        else
          _TeilnahmeCard(
            isBusy: isBusy,
            onTeilnehmen: () => onEinwilligungAendern(true),
          ),
        const SizedBox(height: 12),
        if (isBusy && aggregat == null)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (zeigeVergleich && _teilsicht)
          ..._teilsichtVergleich(context, aggregat)
        else if (zeigeVergleich) ...[
          _stufenVergleich(context, aggregat, mitglieder: true),
          const SizedBox(height: 12),
          _stufenVergleich(context, aggregat, mitglieder: false),
          const SizedBox(height: 12),
          _gruppengroesse(context, aggregat),
          const SizedBox(height: 12),
          _geschlechterVergleich(context, aggregat),
          const SizedBox(height: 12),
          _leitendeAlterVergleich(context, aggregat),
          const SizedBox(height: 12),
          _TransparenzCard(aggregat: aggregat),
        ] else if (hatEinwilligung)
          _StatusHinweis(status: status, aggregat: aggregat),
        if (hatEinwilligung || zuletztGesendet != null) ...[
          const SizedBox(height: 12),
          _GeteilteDatenCard(
            snapshot: zuletztGesendet,
            gruppenName: _name(t),
            installationsId: installationsId,
          ),
        ],
      ],
    );
  }

  String Function(int) _name(AppLocalizations t) =>
      (id) => gruppenName?.call(id) ?? t.t('bund_group_fallback', {'id': id});

  static String stufenName(AppLocalizations t, Stufe stufe) =>
      t.t('bund_stage_${stufenSchluessel[stufe]}');

  // ------------------------------------------------------------ Teilsicht

  List<Widget> _teilsichtVergleich(BuildContext context, Bundesaggregat a) {
    final t = AppLocalizations.of(context);
    final eigene = eigeneKennzahlen!;
    final gruppen = eigene.abgedeckteGruppen;
    final name = _name(t);
    final eigeneStufen = {for (final g in gruppen) g.stufe};
    // Die Stufengröße nur zeigen, wenn alle Gruppen der Stufe lesbar sind.
    final vollstaendigeStufen = [
      for (final s in stufen)
        if (eigeneStufen.contains(s) && eigene.stufe(s).gesamt != null) s,
    ];
    return [
      for (final g in gruppen) ...[
        _gruppenVergleich(context, a, g, name(g.gruppenId)),
        const SizedBox(height: 12),
        _gruppenGeschlecht(context, a, g, name(g.gruppenId)),
        const SizedBox(height: 12),
      ],
      _gruppenJeStamm(context, a, eigeneStufen),
      if (vollstaendigeStufen.isNotEmpty) ...[
        const SizedBox(height: 12),
        _stufenVergleich(
          context,
          a,
          mitglieder: true,
          nurStufen: vollstaendigeStufen,
        ),
      ],
      const SizedBox(height: 12),
      _TransparenzCard(aggregat: a),
    ];
  }

  Widget _gruppenVergleich(
    BuildContext context,
    Bundesaggregat a,
    GruppenKennzahl gruppe,
    String name,
  ) {
    final t = AppLocalizations.of(context);
    final bund = a.gruppenDerStufe(stufenSchluessel[gruppe.stufe]!);
    return StatisticsCard(
      title: t.t('bund_group_compare_title', {'group': name}),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _VergleichsTabelle(
            eigeneSpalte: t.t('bund_col_own_group'),
            zeilen: [
              _VergleichsZeile(
                label: t.t('bund_children'),
                eigenerWert: gruppe.mitglieder?.gesamt,
                bund: bund?.mitglieder['gesamt'],
              ),
              _VergleichsZeile(
                label: t.t('bund_leaders'),
                eigenerWert: gruppe.leitende?.gesamt,
                bund: bund?.leitende['gesamt'],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _gruppenGeschlecht(
    BuildContext context,
    Bundesaggregat a,
    GruppenKennzahl gruppe,
    String name,
  ) {
    final t = AppLocalizations.of(context);
    final bund = a.gruppenDerStufe(stufenSchluessel[gruppe.stufe]!);
    final eigene = gruppe.mitglieder;
    final eigeneWerte = <String, int>{
      for (final (schluessel, _) in _geschlechter)
        schluessel: eigene == null
            ? 0
            : _geschlechtWert(eigene, schluessel) ?? 0,
    };
    final bundAnteile = <String, int?>{
      for (final (schluessel, _) in _geschlechter)
        schluessel: bund?.mitglieder[schluessel]?.anteil,
    };
    return StatisticsCard(
      title: t.t('bund_group_gender_title', {'group': name}),
      child: _AnteilsTabelle(
        eigeneSpalte: t.t('bund_col_own_group'),
        zeilen: [
          for (final (schluessel, label) in _geschlechter)
            _AnteilsZeile(
              label: t.t(label),
              eigenerAnteil: _anteil(
                eigeneWerte[schluessel],
                eigeneWerte.values,
              ),
              bundAnteil: _prozent(bundAnteile[schluessel]),
            ),
        ],
      ),
    );
  }

  Widget _gruppenJeStamm(
    BuildContext context,
    Bundesaggregat a,
    Set<Stufe> eigeneStufen,
  ) {
    final t = AppLocalizations.of(context);
    return StatisticsCard(
      title: t.t('bund_groups_per_stamm_title'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final s in stufen)
            if (eigeneStufen.contains(s))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  t.t('bund_groups_per_stamm_text', {
                    'stage': stufenName(t, s),
                    'median':
                        _formatiere(
                          context,
                          a
                              .gruppenDerStufe(stufenSchluessel[s]!)
                              ?.gruppenProStamm
                              .median,
                        ) ??
                        '–',
                    'avg':
                        _formatiere(
                          context,
                          a
                              .gruppenDerStufe(stufenSchluessel[s]!)
                              ?.gruppenProStamm
                              .durchschnitt,
                        ) ??
                        '–',
                  }),
                ),
              ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------ Stamm

  Widget _stufenVergleich(
    BuildContext context,
    Bundesaggregat aggregat, {
    required bool mitglieder,
    List<Stufe>? nurStufen,
  }) {
    final t = AppLocalizations.of(context);
    final eigene = eigeneKennzahlen;
    final zeilen = <_VergleichsZeile>[
      for (final stufe in nurStufen ?? stufen)
        _VergleichsZeile(
          label: stufenName(t, stufe),
          eigenerWert: eigene == null
              ? null
              : (mitglieder
                        ? eigene.stufe(stufe)
                        : eigene.leitendeDerStufe(stufe))
                    .gesamt,
          bund: aggregat.kennzahl(
            mitglieder
                ? '${stufenSchluessel[stufe]}.gesamt'
                : 'leitende_${stufenSchluessel[stufe]}.gesamt',
          ),
        ),
    ];
    return StatisticsCard(
      title: t.t(
        mitglieder ? 'bund_members_per_stage' : 'bund_leaders_per_stage',
      ),
      child: _VergleichsTabelle(
        eigeneSpalte: t.t('bund_col_own_stamm'),
        zeilen: zeilen,
      ),
    );
  }

  /// Kinder und Jugendliche je Gruppe; mehrere Gruppen einer Stufe stehen
  /// nebeneinander in der Zeile.
  Widget _gruppengroesse(BuildContext context, Bundesaggregat aggregat) {
    final t = AppLocalizations.of(context);
    final gruppen = eigeneKennzahlen?.abgedeckteGruppen ?? const [];
    final zeilen = <_GroessenZeile>[
      for (final stufe in stufen)
        if (gruppen.any((g) => g.stufe == stufe))
          _GroessenZeile(
            label: stufenName(t, stufe),
            eigene: gruppen
                .where((g) => g.stufe == stufe)
                .map((g) => g.mitglieder?.gesamt?.toString() ?? '–')
                .join(' · '),
            median: aggregat
                .gruppenDerStufe(stufenSchluessel[stufe]!)
                ?.mitglieder['gesamt']
                ?.median,
          ),
    ];
    return StatisticsCard(
      key: const Key('bundesvergleich-gruppengroesse'),
      title: t.t('bund_group_size_title'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.t('bund_group_size_hint'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          _GroessenTabelle(zeilen: zeilen),
        ],
      ),
    );
  }

  Widget _geschlechterVergleich(BuildContext context, Bundesaggregat aggregat) {
    final t = AppLocalizations.of(context);
    final eigene = eigeneKennzahlen;
    final eigeneSummen = <String, int>{
      for (final (schluessel, _) in _geschlechter)
        schluessel: eigene == null
            ? 0
            : eigene.kernstufen.fold<int>(
                0,
                (summe, stufe) =>
                    summe + (_geschlechtWert(stufe, schluessel) ?? 0),
              ),
    };
    final bundAnteile = <String, int?>{
      for (final (schluessel, _) in _geschlechter)
        schluessel: aggregat.kennzahl('alle_stufen.$schluessel')?.anteil,
    };

    return StatisticsCard(
      title: t.t('bund_gender_in_stages'),
      child: _AnteilsTabelle(
        eigeneSpalte: t.t('bund_col_own_stamm'),
        zeilen: [
          for (final (schluessel, label) in _geschlechter)
            _AnteilsZeile(
              label: t.t(label),
              eigenerAnteil: _anteil(
                eigeneSummen[schluessel],
                eigeneSummen.values,
              ),
              bundAnteil: _prozent(bundAnteile[schluessel]),
            ),
        ],
      ),
    );
  }

  Widget _leitendeAlterVergleich(
    BuildContext context,
    Bundesaggregat aggregat,
  ) {
    final t = AppLocalizations.of(context);
    const gruppen = <(String, String)>[
      ('unter_21', 'bund_age_under_21'),
      ('von_21_bis_30', 'bund_age_21_30'),
      ('von_31_bis_40', 'bund_age_31_40'),
      ('von_41_bis_50', 'bund_age_41_50'),
      ('von_51_bis_60', 'bund_age_51_60'),
      ('ueber_60', 'bund_age_over_60'),
    ];
    final eigene = eigeneKennzahlen?.leitende;
    final eigeneWerte = <String, int>{
      for (final (schluessel, _) in gruppen)
        schluessel: eigene == null ? 0 : (_altersWert(eigene, schluessel) ?? 0),
    };
    final bundAnteile = <String, int?>{
      for (final (schluessel, _) in gruppen)
        schluessel: aggregat.kennzahl('leitende.$schluessel')?.anteil,
    };

    return StatisticsCard(
      title: t.t('bund_leaders_by_age'),
      child: _AnteilsTabelle(
        eigeneSpalte: t.t('bund_col_own_stamm'),
        zeilen: [
          for (final (schluessel, label) in gruppen)
            _AnteilsZeile(
              label: t.t(label),
              eigenerAnteil: _anteil(
                eigeneWerte[schluessel],
                eigeneWerte.values,
              ),
              bundAnteil: _prozent(bundAnteile[schluessel]),
            ),
        ],
      ),
    );
  }

  int? _geschlechtWert(GeschlechterVerteilung verteilung, String schluessel) =>
      switch (schluessel) {
        'weiblich' => verteilung.weiblich,
        'maennlich' => verteilung.maennlich,
        'divers' => verteilung.divers,
        _ => verteilung.geschlechtUnbekannt,
      };

  int? _altersWert(LeitendeAltersVerteilung verteilung, String schluessel) =>
      switch (schluessel) {
        'unter_21' => verteilung.unter21,
        'von_21_bis_30' => verteilung.von21Bis30,
        'von_31_bis_40' => verteilung.von31Bis40,
        'von_41_bis_50' => verteilung.von41Bis50,
        'von_51_bis_60' => verteilung.von51Bis60,
        _ => verteilung.ueber60,
      };

  double? _anteil(int? wert, Iterable<int> alle) {
    final summe = alle.fold<int>(0, (a, b) => a + b);
    if (wert == null || summe <= 0) {
      return null;
    }
    return wert / summe;
  }

  /// Anteile liefert der Server fertig in ganzen Prozent.
  double? _prozent(int? anteil) => anteil == null ? null : anteil / 100;
}

class _EinwilligungCard extends StatelessWidget {
  const _EinwilligungCard({
    required this.hatEinwilligung,
    required this.einwilligungAm,
    required this.teilsicht,
    required this.onChanged,
  });

  final bool hatEinwilligung;
  final DateTime? einwilligungAm;
  final bool teilsicht;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final seit = einwilligungAm;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                t.t(teilsicht ? 'bund_share_title_groups' : 'bund_share_title'),
              ),
              subtitle: Text(
                hatEinwilligung && seit != null
                    ? t.t('bund_share_since', {
                        'date': DateFormat('dd.MM.yyyy').format(seit.toLocal()),
                      })
                    : t.t('bund_share_required'),
              ),
              value: hatEinwilligung,
              onChanged: onChanged,
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                t.t('bund_share_info'),
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Einladung zum Opt-in, solange der Stamm seine Zahlen nicht teilt.
class _TeilnahmeCard extends StatelessWidget {
  const _TeilnahmeCard({required this.isBusy, required this.onTeilnehmen});

  final bool isBusy;
  final VoidCallback onTeilnehmen;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Card(
      key: const Key('bundesstatistik-teilnahme'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.public, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    t.t('bund_join_title'),
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(t.t('bund_join_text'), style: theme.textTheme.bodyMedium),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: isBusy ? null : onTeilnehmen,
                icon: const Icon(Icons.check),
                label: Text(t.t('bund_join_button')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusHinweis extends StatelessWidget {
  const _StatusHinweis({required this.status, required this.aggregat});

  final BundesstatistikStatus status;
  final Bundesaggregat? aggregat;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final aggregat = this.aggregat;
    final text = switch (status) {
      BundesstatistikStatus.zuWenigTeilnahme => t.t('bund_status_too_few', {
        'min': aggregat?.mindestAnzahlStaemme ?? 0,
      }),
      BundesstatistikStatus.keinStamm => t.t('bund_status_no_stamm'),
      BundesstatistikStatus.keineKennzahlen => t.t('bund_status_no_figures'),
      BundesstatistikStatus.abgelehnt => t.t('bund_status_rejected'),
      BundesstatistikStatus.nichtVerfuegbar => t.t('bund_status_unavailable'),
      BundesstatistikStatus.fehler => t.t('bund_status_error'),
      _ => t.t('bund_status_waiting'),
    };
    return StatisticsCard(title: t.t('bund_status_title'), child: Text(text));
  }
}

class _TransparenzCard extends StatelessWidget {
  const _TransparenzCard({required this.aggregat});

  final Bundesaggregat aggregat;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final format = DateFormat('dd.MM.yyyy');
    final von = aggregat.datenstandVon;
    final bis = aggregat.datenstandBis;
    return StatisticsCard(
      title: t.t('bund_basis_title'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.t('bund_basis_participants', {
              'count': aggregat.teilnehmendeStaemmeUeber ?? 0,
            }),
          ),
          if (von != null && bis != null)
            Text(
              t.t('bund_basis_as_of', {
                'from': format.format(von.toLocal()),
                'to': format.format(bis.toLocal()),
              }),
            ),
          const SizedBox(height: 8),
          Text(aggregat.hinweis, style: theme.textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(
            t.t('bund_basis_suppressed', {
              'min': aggregat.mindestAnzahlStaemme,
            }),
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _GeteilteDatenCard extends StatelessWidget {
  const _GeteilteDatenCard({
    required this.snapshot,
    required this.gruppenName,
    this.installationsId,
  });

  final StammesSnapshot? snapshot;
  final String Function(int gruppenId) gruppenName;
  final String? installationsId;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final snapshot = this.snapshot;
    if (snapshot == null) {
      return StatisticsCard(
        title: t.t('bund_shared_title'),
        child: Text(t.t('bund_shared_none')),
      );
    }

    final kennzahlen = snapshot.kennzahlen;
    final theme = Theme.of(context);
    final teilsicht = !kennzahlen.abdeckung.istStamm;
    final zeilen = teilsicht
        ? <(String, String)>[
            for (final g in kennzahlen.abgedeckteGruppen)
              (
                gruppenName(g.gruppenId),
                t.t('bund_shared_group_values', {
                  'children': g.mitglieder?.gesamt ?? '–',
                  'leaders': g.leitende?.gesamt ?? '–',
                }),
              ),
          ]
        : <(String, String)>[
            for (final stufe in BundesvergleichView.stufen)
              (
                BundesvergleichView.stufenName(t, stufe),
                kennzahlen.stufe(stufe).gesamt?.toString() ?? '–',
              ),
            (
              t.t('bund_leaders'),
              kennzahlen.leitende.gesamt?.toString() ?? '–',
            ),
            (
              t.t('bund_shared_regular_members'),
              kennzahlen.aktiveMitglieder?.toString() ?? '–',
            ),
            (
              t.t('bund_shared_other_members'),
              kennzahlen.nichtLeitendeErwachsene?.toString() ?? '–',
            ),
          ];

    return StatisticsCard(
      title: t.t('bund_shared_title'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.t('bund_shared_at', {
              'date': DateFormat(
                'dd.MM.yyyy, HH:mm',
              ).format(snapshot.sentAt.toLocal()),
            }),
          ),
          const SizedBox(height: 8),
          for (final (label, wert) in zeilen)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Expanded(child: Text(label)),
                  Text(wert),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Text(
            t.t(teilsicht ? 'bund_shared_footer_groups' : 'bund_shared_footer'),
            style: theme.textTheme.bodySmall,
          ),
          if (installationsId case final id?) ...[
            const SizedBox(height: 12),
            _InstallationsIdBox(id: id),
          ],
        ],
      ),
    );
  }
}

/// Installations-ID zum Kopieren; damit lassen sich Auskunft und Loeschung
/// per Mail anfragen, weil der Server nur ihr Pseudonym kennt.
class _InstallationsIdBox extends StatelessWidget {
  const _InstallationsIdBox({required this.id});

  final String id;

  /// Lang genug zum Wiedererkennen, kopiert wird immer die ganze ID.
  String get _gekuerzt => id.length <= 12
      ? id
      : '${id.substring(0, 4)}…${id.substring(id.length - 4)}';

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final klein = theme.textTheme.bodySmall;
    final hinweis = t.t('bund_installation_id_hint', {'email': Anbieter.email});
    final mailStart = hinweis.indexOf(Anbieter.email);

    return Container(
      key: const Key('bund-installations-id'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.t('bund_installation_id'),
                      style: klein?.copyWith(color: colors.onSurfaceVariant),
                    ),
                    Text(
                      _gekuerzt,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.tonalIcon(
                // Akzentflaeche wie im Entwurf; tonal waere das DPSG-Rot.
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primaryContainer,
                  foregroundColor: Theme.of(
                    context,
                  ).colorScheme.onPrimaryContainer,
                  visualDensity: VisualDensity.compact,
                ),
                key: const Key('bund-installations-id-kopieren'),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: id));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(t.t('bund_installation_id_copied')),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.copy, size: 16),
                label: Text(t.t('bund_installation_id_copy')),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text.rich(
            TextSpan(
              style: klein,
              children: [
                if (mailStart < 0)
                  TextSpan(text: hinweis)
                else ...[
                  TextSpan(text: hinweis.substring(0, mailStart)),
                  TextSpan(
                    text: Anbieter.email,
                    style: TextStyle(
                      color: colors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextSpan(
                    text: hinweis.substring(mailStart + Anbieter.email.length),
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

class _VergleichsZeile {
  const _VergleichsZeile({
    required this.label,
    required this.eigenerWert,
    required this.bund,
  });

  final String label;
  final int? eigenerWert;
  final KennzahlAggregat? bund;
}

class _VergleichsTabelle extends StatelessWidget {
  const _VergleichsTabelle({required this.zeilen, required this.eigeneSpalte});

  final List<_VergleichsZeile> zeilen;
  final String eigeneSpalte;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final kopf = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Table(
      columnWidths: const <int, TableColumnWidth>{
        0: FlexColumnWidth(2),
        1: FlexColumnWidth(),
        2: FlexColumnWidth(),
        3: FlexColumnWidth(),
      },
      children: [
        TableRow(
          children: [
            Text('', style: kopf),
            Text(eigeneSpalte, style: kopf, textAlign: TextAlign.end),
            Text(t.t('bund_col_median'), style: kopf, textAlign: TextAlign.end),
            Text(t.t('bund_col_avg'), style: kopf, textAlign: TextAlign.end),
          ],
        ),
        for (final zeile in zeilen)
          TableRow(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(zeile.label),
              ),
              _zelle(zeile.eigenerWert?.toString()),
              _zelle(_formatiere(context, zeile.bund?.median)),
              _zelle(_formatiere(context, zeile.bund?.durchschnitt)),
            ],
          ),
      ],
    );
  }

  Widget _zelle(String? text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Text(text ?? '–', textAlign: TextAlign.end),
  );
}

class _GroessenZeile {
  const _GroessenZeile({
    required this.label,
    required this.eigene,
    required this.median,
  });

  final String label;
  final String eigene;
  final num? median;
}

class _GroessenTabelle extends StatelessWidget {
  const _GroessenTabelle({required this.zeilen});

  final List<_GroessenZeile> zeilen;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final kopf = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    Widget zelle(String text) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(text, textAlign: TextAlign.end),
    );
    return Table(
      columnWidths: const <int, TableColumnWidth>{
        0: FlexColumnWidth(2),
        1: FlexColumnWidth(1.5),
        2: FlexColumnWidth(),
      },
      children: [
        TableRow(
          children: [
            Text('', style: kopf),
            Text(
              t.t('bund_col_own_groups'),
              style: kopf,
              textAlign: TextAlign.end,
            ),
            Text(t.t('bund_col_median'), style: kopf, textAlign: TextAlign.end),
          ],
        ),
        for (final zeile in zeilen)
          TableRow(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(zeile.label),
              ),
              zelle(zeile.eigene),
              zelle(_formatiere(context, zeile.median) ?? '–'),
            ],
          ),
      ],
    );
  }
}

class _AnteilsZeile {
  const _AnteilsZeile({
    required this.label,
    required this.eigenerAnteil,
    required this.bundAnteil,
  });

  final String label;
  final double? eigenerAnteil;
  final double? bundAnteil;
}

class _AnteilsTabelle extends StatelessWidget {
  const _AnteilsTabelle({required this.zeilen, required this.eigeneSpalte});

  final List<_AnteilsZeile> zeilen;
  final String eigeneSpalte;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final kopf = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Table(
      columnWidths: const <int, TableColumnWidth>{
        0: FlexColumnWidth(2),
        1: FlexColumnWidth(),
        2: FlexColumnWidth(),
      },
      children: [
        TableRow(
          children: [
            Text('', style: kopf),
            Text(eigeneSpalte, style: kopf, textAlign: TextAlign.end),
            Text(t.t('bund_col_bund'), style: kopf, textAlign: TextAlign.end),
          ],
        ),
        for (final zeile in zeilen)
          TableRow(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(zeile.label),
              ),
              _prozent(zeile.eigenerAnteil),
              _prozent(zeile.bundAnteil),
            ],
          ),
      ],
    );
  }

  Widget _prozent(double? anteil) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Text(
      anteil == null ? '–' : '${(anteil * 100).round()} %',
      textAlign: TextAlign.end,
    ),
  );
}

String? _formatiere(BuildContext context, num? wert) {
  if (wert == null) {
    return null;
  }
  if (wert == wert.roundToDouble()) {
    return wert.toInt().toString();
  }
  return NumberFormat(
    '0.0',
    Localizations.localeOf(context).toLanguageTag(),
  ).format(wert);
}

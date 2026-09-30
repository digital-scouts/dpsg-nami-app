import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../domain/bundesstatistik/bundesaggregat.dart';
import '../../domain/bundesstatistik/stammes_snapshot.dart';
import '../model/bundesstatistik_model.dart';
import '../statistics/statistics_ui.dart';
import '../widgets/bundesstatistik_einwilligung_dialog.dart';

/// Bundesweiter Vergleich mit Einwilligung und Transparenz ueber geteilte Daten.
class BundesvergleichPage extends StatelessWidget {
  const BundesvergleichPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bundesweiter Vergleich')),
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
    });
  }

  Future<void> _einwilligungAendern(bool erteilen) async {
    final model = context.read<BundesstatistikModel>();
    if (erteilen && !await zeigeBundesstatistikEinwilligungDialog(context)) {
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
  });

  final BundesstatistikStatus status;
  final bool hatEinwilligung;
  final bool isBusy;
  final Bundesaggregat? aggregat;
  final StammesKennzahlen? eigeneKennzahlen;
  final StammesSnapshot? zuletztGesendet;
  final DateTime? einwilligungAm;
  final ValueChanged<bool> onEinwilligungAendern;

  static const List<(String, String)> _stufen = <(String, String)>[
    ('biber', 'Biber'),
    ('woelflinge', 'Wölflinge'),
    ('jungpfadfinder', 'Jungpfadfinder'),
    ('pfadfinder', 'Pfadfinder'),
    ('rover', 'Rover'),
  ];

  @override
  Widget build(BuildContext context) {
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
        else if (zeigeVergleich) ...[
          _stufenVergleich(aggregat, mitglieder: true),
          const SizedBox(height: 12),
          _stufenVergleich(aggregat, mitglieder: false),
          const SizedBox(height: 12),
          _geschlechterVergleich(aggregat),
          const SizedBox(height: 12),
          _leitendeAlterVergleich(aggregat),
          const SizedBox(height: 12),
          _TransparenzCard(aggregat: aggregat),
        ] else if (hatEinwilligung)
          _StatusHinweis(status: status, aggregat: aggregat),
        if (hatEinwilligung || zuletztGesendet != null) ...[
          const SizedBox(height: 12),
          _GeteilteDatenCard(snapshot: zuletztGesendet),
        ],
      ],
    );
  }

  Widget _stufenVergleich(Bundesaggregat aggregat, {required bool mitglieder}) {
    final eigene = eigeneKennzahlen;
    final zeilen = <_VergleichsZeile>[
      for (final (schluessel, label) in _stufen)
        _VergleichsZeile(
          label: label,
          eigenerWert: _eigenerStufenWert(eigene, schluessel, mitglieder),
          bund: aggregat.kennzahl(
            mitglieder ? '$schluessel.gesamt' : 'leitende_$schluessel.gesamt',
          ),
        ),
    ];
    return StatisticsCard(
      title: mitglieder ? 'Mitglieder je Stufe' : 'Leitende je Stufe',
      child: _VergleichsTabelle(zeilen: zeilen),
    );
  }

  int? _eigenerStufenWert(
    StammesKennzahlen? kennzahlen,
    String schluessel,
    bool mitglieder,
  ) {
    if (kennzahlen == null) {
      return null;
    }
    final GeschlechterVerteilung verteilung = switch ((
      schluessel,
      mitglieder,
    )) {
      ('biber', true) => kennzahlen.biber,
      ('woelflinge', true) => kennzahlen.woelflinge,
      ('jungpfadfinder', true) => kennzahlen.jungpfadfinder,
      ('pfadfinder', true) => kennzahlen.pfadfinder,
      ('rover', true) => kennzahlen.rover,
      ('biber', false) => kennzahlen.leitendeBiber,
      ('woelflinge', false) => kennzahlen.leitendeWoelflinge,
      ('jungpfadfinder', false) => kennzahlen.leitendeJungpfadfinder,
      ('pfadfinder', false) => kennzahlen.leitendePfadfinder,
      _ => kennzahlen.leitendeRover,
    };
    return verteilung.gesamt;
  }

  Widget _geschlechterVergleich(Bundesaggregat aggregat) {
    const geschlechter = <(String, String)>[
      ('weiblich', 'Weiblich'),
      ('maennlich', 'Männlich'),
      ('divers', 'Divers'),
      ('geschlecht_unbekannt', 'Ohne Angabe'),
    ];
    final eigene = eigeneKennzahlen;
    final eigeneSummen = <String, int>{
      for (final (schluessel, _) in geschlechter)
        schluessel: eigene == null
            ? 0
            : eigene.kernstufen.fold<int>(
                0,
                (summe, stufe) =>
                    summe + (_geschlechtWert(stufe, schluessel) ?? 0),
              ),
    };
    final bundSummen = <String, num?>{
      for (final (schluessel, _) in geschlechter)
        schluessel: _summeUeberStufen(aggregat, schluessel),
    };

    return StatisticsCard(
      title: 'Geschlecht in den Stufen',
      child: _AnteilsTabelle(
        zeilen: [
          for (final (schluessel, label) in geschlechter)
            _AnteilsZeile(
              label: label,
              eigenerAnteil: _anteil(
                eigeneSummen[schluessel],
                eigeneSummen.values,
              ),
              bundAnteil: _anteilNullable(
                bundSummen[schluessel],
                bundSummen.values,
              ),
            ),
        ],
      ),
    );
  }

  Widget _leitendeAlterVergleich(Bundesaggregat aggregat) {
    const gruppen = <(String, String)>[
      ('unter_21', 'unter 21'),
      ('von_21_bis_30', '21–30'),
      ('von_31_bis_40', '31–40'),
      ('von_41_bis_50', '41–50'),
      ('von_51_bis_60', '51–60'),
      ('ueber_60', 'über 60'),
    ];
    final eigene = eigeneKennzahlen?.leitende;
    final eigeneWerte = <String, int>{
      for (final (schluessel, _) in gruppen)
        schluessel: eigene == null ? 0 : (_altersWert(eigene, schluessel) ?? 0),
    };
    final bundWerte = <String, num?>{
      for (final (schluessel, _) in gruppen)
        schluessel: aggregat.kennzahl('leitende.$schluessel')?.summe,
    };

    return StatisticsCard(
      title: 'Leitende nach Alter',
      child: _AnteilsTabelle(
        zeilen: [
          for (final (schluessel, label) in gruppen)
            _AnteilsZeile(
              label: label,
              eigenerAnteil: _anteil(
                eigeneWerte[schluessel],
                eigeneWerte.values,
              ),
              bundAnteil: _anteilNullable(
                bundWerte[schluessel],
                bundWerte.values,
              ),
            ),
        ],
      ),
    );
  }

  num? _summeUeberStufen(Bundesaggregat aggregat, String geschlecht) {
    num summe = 0;
    for (final (schluessel, _) in _stufen) {
      final wert = aggregat.kennzahl('$schluessel.$geschlecht')?.summe;
      if (wert == null) {
        return null;
      }
      summe += wert;
    }
    return summe;
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

  double? _anteilNullable(num? wert, Iterable<num?> alle) {
    if (wert == null || alle.any((value) => value == null)) {
      return null;
    }
    final summe = alle.fold<num>(0, (a, b) => a + (b ?? 0));
    if (summe <= 0) {
      return null;
    }
    return wert / summe;
  }
}

class _EinwilligungCard extends StatelessWidget {
  const _EinwilligungCard({
    required this.hatEinwilligung,
    required this.einwilligungAm,
    required this.onChanged,
  });

  final bool hatEinwilligung;
  final DateTime? einwilligungAm;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
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
              title: const Text('Stammesdaten teilen'),
              subtitle: Text(
                hatEinwilligung && seit != null
                    ? 'Aktiv seit ${DateFormat('dd.MM.yyyy').format(seit.toLocal())}'
                    : 'Voraussetzung für den bundesweiten Vergleich',
              ),
              value: hatEinwilligung,
              onChanged: onChanged,
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                'Geteilt werden nur zusammengefasste Anzahlen deines Stammes, '
                'keine Namen oder Einzeldaten. Ein Widerruf stoppt weitere '
                'Sendungen; bereits geteilte Zahlen fallen nach zwei Monaten '
                'aus der Statistik.',
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
                    'Mit Stämmen bundesweit vergleichen',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Teile die zusammengefassten Anzahlen deines Stammes und sieh im '
              'Gegenzug, wie sich Stufen, Leitende und Geschlechter bundesweit '
              'verteilen. Namen oder Einzeldaten verlassen die App nicht.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: isBusy ? null : onTeilnehmen,
                icon: const Icon(Icons.check),
                label: const Text('Jetzt teilnehmen'),
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
    final aggregat = this.aggregat;
    final text = switch (status) {
      BundesstatistikStatus.zuWenigTeilnahme =>
        'Bisher teilen ${aggregat?.teilnehmendeStaemme ?? 0} Stämme ihre Zahlen. '
            'Bundeswerte werden ab ${aggregat?.mindestAnzahlStaemme ?? 0} '
            'Stämmen angezeigt, damit einzelne Stämme nicht erkennbar sind.',
      BundesstatistikStatus.keinStamm =>
        'Der bundesweite Vergleich ist nur verfügbar, wenn ein Stamm als '
            'Arbeitskontext ausgewählt ist.',
      BundesstatistikStatus.keineKennzahlen =>
        'In deinem Stamm wurden keine Mitglieder in den Stufen gefunden. '
            'Ohne eigene Zahlen kann nichts geteilt werden.',
      BundesstatistikStatus.abgelehnt =>
        'Der Statistikserver hat die Zahlen deines Stammes abgelehnt. '
            'Vermutlich passen App und Server nicht zusammen; bitte die App '
            'aktualisieren.',
      BundesstatistikStatus.nichtVerfuegbar =>
        'Der bundesweite Vergleich ist in dieser App-Version nicht verfügbar.',
      BundesstatistikStatus.fehler =>
        'Der Statistikserver ist derzeit nicht erreichbar. Die App versucht '
            'es beim nächsten Synchronisieren erneut.',
      _ =>
        'Dein Beitrag wird vorbereitet, sobald die Mitglieder und Rollen '
            'deines Stammes geladen sind.',
    };
    return StatisticsCard(title: 'Status', child: Text(text));
  }
}

class _TransparenzCard extends StatelessWidget {
  const _TransparenzCard({required this.aggregat});

  final Bundesaggregat aggregat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final format = DateFormat('dd.MM.yyyy');
    final von = aggregat.datenstandVon;
    final bis = aggregat.datenstandBis;
    return StatisticsCard(
      title: 'Grundlage',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${aggregat.teilnehmendeStaemme} teilnehmende Stämme'),
          if (von != null && bis != null)
            Text(
              'Datenstand ${format.format(von.toLocal())} bis ${format.format(bis.toLocal())}',
            ),
          const SizedBox(height: 8),
          Text(aggregat.hinweis, style: theme.textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(
            'Werte, zu denen weniger als ${aggregat.mindestAnzahlStaemme} '
            'Stämme beitragen, werden nicht angezeigt.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _GeteilteDatenCard extends StatelessWidget {
  const _GeteilteDatenCard({required this.snapshot});

  final StammesSnapshot? snapshot;

  @override
  Widget build(BuildContext context) {
    final snapshot = this.snapshot;
    if (snapshot == null) {
      return const StatisticsCard(
        title: 'Was dein Stamm geteilt hat',
        child: Text('Bisher wurden keine Zahlen deines Stammes geteilt.'),
      );
    }

    final kennzahlen = snapshot.kennzahlen;
    final theme = Theme.of(context);
    final zeilen = <(String, int?)>[
      ('Biber', kennzahlen.biber.gesamt),
      ('Wölflinge', kennzahlen.woelflinge.gesamt),
      ('Jungpfadfinder', kennzahlen.jungpfadfinder.gesamt),
      ('Pfadfinder', kennzahlen.pfadfinder.gesamt),
      ('Rover', kennzahlen.rover.gesamt),
      ('Leitende', kennzahlen.leitende.gesamt),
      ('Ordentliche Mitgliedschaften', kennzahlen.aktiveMitglieder),
      ('Sonstige Mitglieder', kennzahlen.nichtLeitendeErwachsene),
    ];

    return StatisticsCard(
      title: 'Was dein Stamm geteilt hat',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Zuletzt gesendet am '
            '${DateFormat('dd.MM.yyyy, HH:mm').format(snapshot.sentAt.toLocal())}',
          ),
          const SizedBox(height: 8),
          for (final (label, wert) in zeilen)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Expanded(child: Text(label)),
                  Text(wert?.toString() ?? '–'),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Text(
            'Zusätzlich je Stufe die Aufteilung nach Geschlecht und bei '
            'Leitenden nach Altersgruppen. Stamm und Installation werden '
            'auf dem Server pseudonymisiert.',
            style: theme.textTheme.bodySmall,
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
  const _VergleichsTabelle({required this.zeilen});

  final List<_VergleichsZeile> zeilen;

  @override
  Widget build(BuildContext context) {
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
            Text('Dein Stamm', style: kopf, textAlign: TextAlign.end),
            Text('Median', style: kopf, textAlign: TextAlign.end),
            Text('Ø', style: kopf, textAlign: TextAlign.end),
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
              _zelle(_formatiere(zeile.bund?.median)),
              _zelle(_formatiere(zeile.bund?.durchschnitt)),
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
  const _AnteilsTabelle({required this.zeilen});

  final List<_AnteilsZeile> zeilen;

  @override
  Widget build(BuildContext context) {
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
            Text('Dein Stamm', style: kopf, textAlign: TextAlign.end),
            Text('Bund', style: kopf, textAlign: TextAlign.end),
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

String? _formatiere(num? wert) {
  if (wert == null) {
    return null;
  }
  if (wert == wert.roundToDouble()) {
    return wert.toInt().toString();
  }
  return NumberFormat('0.0', 'de_DE').format(wert);
}

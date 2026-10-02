import 'package:flutter/material.dart';

import '../../../domain/stufenwechsel/naechster_stufenwechsel.dart';
import '../../../domain/taetigkeit/pfadfinder_verlauf.dart';
import '../../../domain/taetigkeit/roles.dart';
import '../../../domain/taetigkeit/stufe.dart';
import '../../../l10n/app_localizations.dart';
import 'mitglied_dauer_text.dart';
import 'verlauf_bahnen.dart';

/// Pfadfinder-Verlauf oben im Rollen-Tab: drei Kennzahl-Kacheln und
/// darunter die Bahnen. Kinder ohne Leitung sehen statt der Leitungsjahre
/// den naechsten Stufenwechsel.
class MemberPfadfinderVerlauf extends StatelessWidget {
  const MemberPfadfinderVerlauf({
    super.key,
    required this.verlauf,
    required this.heute,
    this.stufenwechsel,
    this.roverHoechstalter = 20,
  });

  final PfadfinderVerlauf verlauf;
  final DateTime heute;
  final NaechsterStufenwechsel? stufenwechsel;
  final int roverHoechstalter;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final kacheln = <_Kennzahl>[
      _dauer(t),
      if (!verlauf.hatLeitung && stufenwechsel != null)
        _wechsel(t, stufenwechsel!)
      else
        _leitung(t),
      _stufen(t),
    ];

    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < kacheln.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(child: _KennzahlKachel(kennzahl: kacheln[i])),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
          Card(
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
              child: verlauf.istNeu || verlauf.segmente.isEmpty
                  ? Text(
                      t.t('verlauf_neu'),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.outlineVariant,
                      ),
                    )
                  : VerlaufBahnen(
                      verlauf: verlauf,
                      bahnNamen: (
                        mitglied: t.t('verlauf_bahn_mitglied'),
                        leitung: t.t('verlauf_bahn_leitung'),
                        aemter: t.t('verlauf_bahn_aemter'),
                      ),
                      unbekanntText: t.t('verlauf_frueher_unbekannt'),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  _Kennzahl _dauer(AppLocalizations t) {
    final ausgetreten = verlauf.bis.isBefore(heute);
    return _Kennzahl(
      wert: mitgliedDauerText(t, verlauf.von, verlauf.bis),
      label: t.t(ausgetreten ? 'verlauf_dabei_gewesen' : 'verlauf_dabei'),
      unterzeile: ausgetreten
          ? t.t('verlauf_von_bis', {
              'von': verlauf.von.year,
              'bis': verlauf.bis.year,
            })
          : t.t('verlauf_seit', {'jahr': verlauf.von.year}),
    );
  }

  _Kennzahl _leitung(AppLocalizations t) {
    final jahre = verlauf.leitungsJahre;
    final stufen = <Stufe>{
      for (final s in verlauf.segmente)
        if (s.art == RoleCategory.leitung && s.stufe != null) s.stufe!,
    };
    return _Kennzahl(
      wert: jahre >= 1
          ? t.t('verlauf_jahre', {'n': jahre.round()})
          : jahre > 0
          ? t.t('verlauf_unter_einem_jahr')
          : '–',
      label: t.t('verlauf_leitung'),
      unterzeile: stufen.isEmpty
          ? t.t('verlauf_leitung_noch_nicht')
          : stufen.map((s) => s.shortDisplayName).join(', '),
    );
  }

  _Kennzahl _wechsel(AppLocalizations t, NaechsterStufenwechsel wechsel) {
    final wert = switch (wechsel.zeitpunkt) {
      StufenwechselZeitpunkt.jetzt => t.t('verlauf_wechsel_jetzt'),
      StufenwechselZeitpunkt.ab => t.t('verlauf_wechsel_ab', {
        'jahr': wechsel.jahr,
      }),
      StufenwechselZeitpunkt.bis => t.t('verlauf_wechsel_bis', {
        'jahr': wechsel.jahr,
      }),
    };
    if (wechsel.istEndeRoverzeit) {
      return _Kennzahl(
        wert: wert,
        label: t.t('verlauf_ende_roverzeit'),
        unterzeile: t.t('verlauf_mit_jahren', {'n': roverHoechstalter}),
      );
    }
    return _Kennzahl(
      wert: wert,
      label: t.t('verlauf_wechsel'),
      unterzeile: switch (wechsel.zielStufe) {
        Stufe.woelfling => t.t('verlauf_zu_woelfling'),
        Stufe.jungpfadfinder => t.t('verlauf_zu_jungpfadfinder'),
        Stufe.pfadfinder => t.t('verlauf_zu_pfadfinder'),
        Stufe.rover => t.t('verlauf_zu_rover'),
        _ => '',
      },
    );
  }

  _Kennzahl _stufen(AppLocalizations t) {
    return _Kennzahl(
      wert:
          '${verlauf.stufenAlsMitglied.length}/${PfadfinderVerlauf.zaehlStufen.length}',
      label: t.t('verlauf_stufen'),
      unterzeile: verlauf.unbekanntBis != null
          ? t.t('verlauf_stufen_bekannt')
          : t.t('verlauf_stufen_durchlaufen'),
    );
  }
}

class _Kennzahl {
  const _Kennzahl({
    required this.wert,
    required this.label,
    required this.unterzeile,
  });

  final String wert;
  final String label;
  final String unterzeile;
}

class _KennzahlKachel extends StatelessWidget {
  const _KennzahlKachel({required this.kennzahl});

  final _Kennzahl kennzahl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                kennzahl.wert,
                maxLines: 1,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              kennzahl.label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            Text(
              kennzahl.unterzeile,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outlineVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

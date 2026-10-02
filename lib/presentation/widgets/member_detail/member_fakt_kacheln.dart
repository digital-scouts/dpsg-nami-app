import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../domain/member/mitglied.dart';
import '../../../domain/member/mitglied_zeitraeume.dart';
import '../../../l10n/app_localizations.dart';
import '../../format/date_formatters.dart';
import '../../theme/status_farben.dart';
import 'mitglied_dauer_text.dart';

/// Zwei Kacheln oben im Daten-Tab: naechster Geburtstag und
/// Mitgliedschaftsdauer.
class MemberFaktKacheln extends StatelessWidget {
  const MemberFaktKacheln({
    super.key,
    required this.mitglied,
    required this.heute,
  });

  final Mitglied mitglied;
  final DateTime heute;

  /// Bis zu so vielen Tagen vorher wird der Geburtstag hervorgehoben.
  static const int hervorhebungTage = 7;

  @override
  Widget build(BuildContext context) {
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.4,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _geburtstag(context)),
            const SizedBox(width: 10),
            Expanded(child: _dabei(context)),
          ],
        ),
      ),
    );
  }

  Widget _geburtstag(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final naechster = naechsterGeburtstag(mitglied, heute);
    if (naechster == null) {
      return _FaktKachel(
        key: const ValueKey('fakt-geburtstag'),
        wert: '–',
        unterzeile: t.t('member_fakt_geburtstag_unbekannt'),
      );
    }

    final sprache = Localizations.localeOf(context).languageCode;
    final wert = DateFormat('d. MMMM', sprache).format(naechster.datum);
    final tage = naechster.tage;
    final unterzeile = switch (tage) {
      0 => t.t('member_fakt_geburtstag_heute'),
      1 => t.t('member_fakt_geburtstag_morgen', {'alter': naechster.wirdAlter}),
      <= 31 => t.t('member_fakt_geburtstag_tage', {
        'n': tage,
        'alter': naechster.wirdAlter,
      }),
      _ => _monateText(t, monateZwischen(heute, naechster.datum)),
    };
    final bald = tage <= hervorhebungTage;
    return _FaktKachel(
      key: const ValueKey('fakt-geburtstag'),
      wert: wert,
      unterzeile: unterzeile,
      hervorgehoben: bald,
      hintergrund: tage == 0
          ? StatusFarben.of(context).kritisch.withValues(alpha: 0.12)
          : bald
          ? theme.colorScheme.primaryContainer
          : null,
      unterzeileFarbe: bald ? theme.colorScheme.primary : null,
      icon: tage == 0 ? Icons.cake_outlined : null,
    );
  }

  String _monateText(AppLocalizations t, int monate) {
    if (monate <= 1) {
      return t.t('member_fakt_geburtstag_monat');
    }
    return t.t('member_fakt_geburtstag_monate', {'n': monate});
  }

  Widget _dabei(BuildContext context) {
    final t = AppLocalizations.of(context);
    if (!mitglied.hatBekanntesEintrittsdatum) {
      return _FaktKachel(
        key: const ValueKey('fakt-dabei'),
        wert: '–',
        unterzeile: t.t('member_fakt_eintritt_unbekannt'),
      );
    }
    final eintritt = mitglied.eintrittsdatum;
    final austritt = mitglied.austrittsdatum;
    final ausgetreten = austritt != null && !austritt.isAfter(heute);
    final bis = ausgetreten ? austritt : heute;
    return _FaktKachel(
      key: const ValueKey('fakt-dabei'),
      wert: mitgliedDauerText(t, eintritt, bis),
      unterzeile: ausgetreten
          ? t.t('member_fakt_dabei_von_bis', {
              'von': eintritt.year,
              'bis': austritt.year,
            })
          : t.t('member_fakt_dabei_seit', {
              'datum': DateFormatter.formatGermanShortDate(eintritt),
            }),
    );
  }
}

class _FaktKachel extends StatelessWidget {
  const _FaktKachel({
    super.key,
    required this.wert,
    required this.unterzeile,
    this.hervorgehoben = false,
    this.hintergrund,
    this.unterzeileFarbe,
    this.icon,
  });

  final String wert;
  final String unterzeile;
  final bool hervorgehoben;
  final Color? hintergrund;
  final Color? unterzeileFarbe;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final farbe = unterzeileFarbe ?? theme.colorScheme.outlineVariant;
    return Card(
      margin: EdgeInsets.zero,
      color: hintergrund,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                wert,
                maxLines: 1,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 14, color: farbe),
                  const SizedBox(width: 4),
                ],
                Flexible(
                  child: Text(
                    unterzeile,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: farbe,
                      fontWeight: hervorgehoben ? FontWeight.w600 : null,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

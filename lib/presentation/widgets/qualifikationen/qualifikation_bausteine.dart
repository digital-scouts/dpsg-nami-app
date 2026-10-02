import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../domain/member/member_utils.dart';
import '../../../domain/member/mitglied.dart';
import '../../../domain/qualifikation/ermittle_qualifikations_uebersicht_usecase.dart';
import '../../../domain/qualifikation/personenkreis.dart';
import '../../../domain/qualifikation/qualifikations_einstellungen.dart';
import '../../../domain/qualifikation/qualifikations_status.dart';
import '../../../domain/taetigkeit/roles.dart';
import '../../../domain/taetigkeit/stufe.dart';
import '../../../l10n/app_localizations.dart';
import '../../statistics/statistik_farben.dart';
import '../../stufe/stufe_visuals.dart';
import '../../theme/status_farben.dart';

final _datum = DateFormat('dd.MM.yyyy');

String qualiDatum(DateTime datum) => _datum.format(datum);

/// Symbol einer Art: Schild fuer das EFZ, Hand fuer Praevention, Kreuz fuer
/// Erste Hilfe, sonst ein Abzeichen. Gruen, Orange und Rot bleiben fuer den
/// Status reserviert.
class QualifikationArtSymbol extends StatelessWidget {
  const QualifikationArtSymbol({super.key, required this.art, this.size = 34});

  final UebersichtArt art;
  final double size;

  static const _weitereFarben = <Color>[
    Color(0xFF8D6E63),
    Color(0xFF546E7A),
    Color(0xFF3D6FB6),
    Color(0xFF6D4C41),
    Color(0xFF5C6BC0),
  ];

  @override
  Widget build(BuildContext context) {
    final (icon, farbe) = art.istEfz
        ? (Icons.verified_user_outlined, const Color(0xFF2F5D8A))
        : QualifikationsVorgaben.istPraevention(art.label)
        ? (Icons.back_hand_outlined, const Color(0xFF7B4FA0))
        : QualifikationsVorgaben.istErsteHilfe(art.label)
        ? (Icons.medical_services_outlined, const Color(0xFF00838F))
        : (
            Icons.workspace_premium_outlined,
            _weitereFarben[(art.hitobitoId ?? 0) % _weitereFarben.length],
          );
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: farbe, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Icon(icon, size: size * 0.52, color: Colors.white),
    );
  }
}

/// „Alle 5 Jahre“, „Jedes Jahr“ oder „ohne Ablauf“.
String qualiRegelmaessigkeit(AppLocalizations t, UebersichtArt art) {
  final jahre = art.gueltigkeitJahre;
  if (jahre == null) {
    return t.t('quali_ohne_ablauf');
  }
  return jahre == 1
      ? t.t('quali_jedes_jahr')
      : t.t('quali_alle_jahre', {'n': jahre});
}

/// „2 fehlen · 1 bald“ bzw. „alle gueltig“, farbig nach Status.
List<InlineSpan> qualiStatusSpans(
  BuildContext context,
  UebersichtZeile zeile, {
  bool kurz = true,
}) {
  final t = AppLocalizations.of(context);
  final farben = StatusFarben.of(context);
  final fett = const TextStyle(fontWeight: FontWeight.w600);
  final teile = <InlineSpan>[];
  if (zeile.fehlt > 0) {
    teile.add(
      TextSpan(
        text: zeile.fehlt == 1
            ? t.t('quali_fehlt_eins')
            : t.t('quali_fehlen', {'n': zeile.fehlt}),
        style: fett.copyWith(color: farben.kritisch),
      ),
    );
  }
  if (zeile.bald > 0) {
    teile.add(
      TextSpan(
        text: t.t(kurz ? 'quali_bald_kurz' : 'quali_bald_lang', {
          'n': zeile.bald,
        }),
        style: fett.copyWith(color: farben.warnung),
      ),
    );
  }
  if (teile.isEmpty) {
    teile.add(
      TextSpan(
        text: t.t('quali_alle_gueltig'),
        style: fett.copyWith(color: farben.gut),
      ),
    );
  }
  return <InlineSpan>[
    for (var i = 0; i < teile.length; i++) ...[
      if (i > 0) const TextSpan(text: ' · '),
      teile[i],
    ],
  ];
}

/// Balken aus gueltig (gruen), bald (orange) und fehlt (rot).
class QualifikationStatusBalken extends StatelessWidget {
  const QualifikationStatusBalken({
    super.key,
    required this.zeile,
    this.hoehe = 4,
  });

  final UebersichtZeile zeile;
  final double hoehe;

  @override
  Widget build(BuildContext context) {
    final farben = StatusFarben.of(context);
    final segmente = <(int, Color)>[
      (zeile.gueltig, farben.gut),
      (zeile.bald, farben.warnung),
      (zeile.fehlt, farben.kritisch),
    ].where((segment) => segment.$1 > 0).toList(growable: false);
    return ClipRRect(
      borderRadius: BorderRadius.circular(hoehe),
      child: SizedBox(
        height: hoehe,
        child: segmente.isEmpty
            ? ColoredBox(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
              )
            : Row(
                children: [
                  for (var i = 0; i < segmente.length; i++) ...[
                    if (i > 0) const SizedBox(width: 2),
                    Expanded(
                      flex: segmente[i].$1,
                      child: ColoredBox(color: segmente[i].$2),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

/// Eine Zeile der Uebersicht (Entwurf U3).
class QualifikationUebersichtZeile extends StatelessWidget {
  const QualifikationUebersichtZeile({
    super.key,
    required this.zeile,
    required this.onTap,
  });

  final UebersichtZeile zeile;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context);
    final leise = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return InkWell(
      key: Key('quali-zeile-${zeile.art.schluessel}'),
      onTap: zeile.gesperrt ? null : onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            QualifikationArtSymbol(art: zeile.art),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    zeile.art.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  if (zeile.gesperrt)
                    Text(t.t('quali_keine_efz_berechtigung'), style: leise)
                  else ...[
                    Text.rich(
                      TextSpan(
                        style: leise,
                        children: [
                          TextSpan(text: qualiRegelmaessigkeit(t, zeile.art)),
                          const TextSpan(text: ' · '),
                          ...qualiStatusSpans(context, zeile),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    QualifikationStatusBalken(zeile: zeile),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (zeile.gesperrt)
              Icon(Icons.lock_outline, color: theme.colorScheme.outline)
            else ...[
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '${zeile.erfuellt}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    TextSpan(text: '/${zeile.benoetigt}', style: leise),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: theme.colorScheme.outline),
            ],
          ],
        ),
      ),
    );
  }
}

/// Status-Pille einer Person: fehlt, abgelaufen, bald faellig, gueltig.
class QualifikationStatusPille extends StatelessWidget {
  const QualifikationStatusPille({super.key, required this.status});

  final QualifikationsStatus status;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final farben = StatusFarben.of(context);
    final (label, farbe) = switch (status) {
      QualifikationsStatus.fehlt => (
        t.t('quali_status_fehlt'),
        farben.kritisch,
      ),
      QualifikationsStatus.abgelaufen => (
        t.t('quali_status_abgelaufen'),
        farben.kritisch,
      ),
      QualifikationsStatus.baldAblaufend => (
        t.t('quali_status_bald'),
        farben.warnung,
      ),
      QualifikationsStatus.gueltig => (t.t('quali_status_gueltig'), farben.gut),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: farbe.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: farbe,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Rundes Symbol einer Person nach ihrer wichtigsten aktiven Rolle.
class QualifikationPersonSymbol extends StatelessWidget {
  const QualifikationPersonSymbol({
    super.key,
    required this.mitglied,
    required this.heute,
  });

  final Mitglied mitglied;
  final DateTime heute;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rolle = MemberUtils.visualRole(mitglied, heute: heute);
    final stufe = rolle?.stufe;
    final mitStufe = stufe != null && stufe != Stufe.leitung;
    final farbe = mitStufe
        ? StatistikFarben.of(context).stufe(stufe)
        : theme.colorScheme.outlineVariant;
    final leitung = rolle?.category != RoleCategory.mitglied;
    final dunkel = theme.brightness == Brightness.dark;
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: !leitung && dunkel
            ? const Color(0xFFE9E9EE)
            : Color.alphaBlend(
                farbe.withValues(alpha: 0.16),
                theme.colorScheme.surface,
              ),
        border: Border.all(width: 1.5, color: farbe.withValues(alpha: 0.6)),
      ),
      child: leitung || !mitStufe
          ? Image.asset(
              StufeVisuals.assetFor(Stufe.leitung),
              width: 16,
              height: 16,
              color: mitStufe ? farbe : theme.colorScheme.onSurfaceVariant,
              colorBlendMode: BlendMode.srcIn,
              cacheWidth: 48,
            )
          : Image.asset(
              StufeVisuals.assetFor(stufe),
              width: 22,
              height: 22,
              cacheWidth: 64,
            ),
    );
  }
}

/// Lesbare Beschreibung eines Personenkreises, etwa „Leitung oder Amt“.
String qualiKreisBeschreibung(
  AppLocalizations t,
  Personenkreis kreis, {
  Map<String, String> rollentypLabels = const <String, String>{},
}) {
  if (kreis.regeln.isEmpty) {
    return '–';
  }
  final teile = <String>[];
  for (var i = 0; i < kreis.regeln.length; i++) {
    final regel = kreis.regeln[i];
    if (i > 0) {
      teile.add(
        t.t(
          regel.verknuepfung == RegelVerknuepfung.und
              ? 'quali_regel_und'
              : 'quali_regel_oder',
        ),
      );
    }
    teile.add(qualiRegelWertLabel(t, regel, rollentypLabels: rollentypLabels));
  }
  return teile.join(' ');
}

String qualiRegelTypLabel(AppLocalizations t, PersonenkreisRegelTyp typ) =>
    t.t(switch (typ) {
      PersonenkreisRegelTyp.rollenart => 'quali_regel_rollenart',
      PersonenkreisRegelTyp.stufe => 'quali_regel_stufe',
      PersonenkreisRegelTyp.rollentyp => 'quali_regel_rollentyp',
      PersonenkreisRegelTyp.alterAb => 'quali_regel_alter_ab',
      PersonenkreisRegelTyp.alterBis => 'quali_regel_alter_bis',
    });

String qualiRegelWertLabel(
  AppLocalizations t,
  PersonenkreisRegel regel, {
  Map<String, String> rollentypLabels = const <String, String>{},
}) {
  switch (regel.typ) {
    case PersonenkreisRegelTyp.rollenart:
      return t.t('quali_rollenart_${regel.wert}');
    case PersonenkreisRegelTyp.stufe:
      for (final stufe in Stufe.values) {
        if (stufe.name == regel.wert) {
          return stufe.displayName;
        }
      }
      return regel.wert;
    case PersonenkreisRegelTyp.rollentyp:
      return rollentypLabels[regel.wert] ??
          regel.wert.split('::').where((s) => s.isNotEmpty).last;
    case PersonenkreisRegelTyp.alterAb:
    case PersonenkreisRegelTyp.alterBis:
      return '${qualiRegelTypLabel(t, regel.typ)} ${regel.wert}';
  }
}

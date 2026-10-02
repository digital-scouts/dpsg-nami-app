import 'package:flutter/material.dart';

import '../../../domain/appearance/appearance_catalog.dart';
import '../../../domain/member/member_utils.dart';
import '../../../domain/member/mitglied.dart';
import '../../../domain/taetigkeit/role_derivation.dart';
import '../../../domain/taetigkeit/roles.dart';
import '../../../domain/taetigkeit/stufe.dart';
import '../../../l10n/app_localizations.dart';
import '../../statistics/statistik_farben.dart';
import '../../stufe/stufe_visuals.dart';
import '../member_basis_info_card.dart';
import '../supporter_badge.dart';

/// Steckbrief-Kopf der Mitgliedsdetails in einer Zeile: Zurueck, Avatar,
/// Name mit Zeile fuer Alter, Pronomen und Geschlecht, aktive Stufen als
/// Icons und die Aktionen. Ein Tipp auf den Namen klappt abgeschnittene
/// Zeilen auf und wieder zu.
class MemberSteckbriefKopf extends StatefulWidget {
  const MemberSteckbriefKopf({
    super.key,
    required this.mitglied,
    required this.heute,
    this.supporterBadge,
    this.leading,
    this.actions = const <Widget>[],
    this.onStufenTap,
  });

  final Mitglied mitglied;
  final DateTime heute;
  final SupporterBadgeId? supporterBadge;
  final Widget? leading;
  final List<Widget> actions;

  /// Tipp auf die Stufen-Icons, etwa um zum Rollen-Tab zu wechseln.
  final VoidCallback? onStufenTap;

  @override
  State<MemberSteckbriefKopf> createState() => _MemberSteckbriefKopfState();
}

class _MemberSteckbriefKopfState extends State<MemberSteckbriefKopf> {
  static const double _maxTextSkalierung = 1.4;

  bool _ausgeklappt = false;

  Mitglied get mitglied => widget.mitglied;
  DateTime get heute => widget.heute;

  @override
  Widget build(BuildContext context) {
    final leading = widget.leading;
    final supporterBadge = widget.supporterBadge;
    final zeilen = _ausgeklappt ? null : 1;
    final ueberlauf = _ausgeklappt
        ? TextOverflow.visible
        : TextOverflow.ellipsis;
    final theme = Theme.of(context);
    final fahrtenname = mitglied.fahrtenname?.trim();
    final hatFahrtenname = fahrtenname != null && fahrtenname.isNotEmpty;
    final titel = hatFahrtenname
        ? fahrtenname
        : (mitglied.fullName.isNotEmpty
              ? mitglied.fullName
              : mitglied.mitgliedsnummer);
    final fakten = _fakten(context);
    final chips = steckbriefChips(mitglied, heute: heute);

    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: _maxTextSkalierung,
      child: Padding(
        padding: EdgeInsets.fromLTRB(leading == null ? 16 : 4, 8, 4, 8),
        child: Row(
          children: [
            ?leading,
            _Avatar(mitglied: mitglied),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                key: const Key('member-steckbrief-name'),
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _ausgeklappt = !_ausgeklappt),
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 180),
                  alignment: Alignment.topLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              titel,
                              maxLines: zeilen,
                              overflow: ueberlauf,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (supporterBadge != null) ...[
                            const SizedBox(width: 6),
                            SupporterBadge(badge: supporterBadge, size: 18),
                          ],
                        ],
                      ),
                      if (hatFahrtenname && mitglied.fullName.isNotEmpty)
                        Text(
                          mitglied.fullName,
                          maxLines: zeilen,
                          overflow: ueberlauf,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      if (fakten.isNotEmpty)
                        Text(
                          fakten,
                          maxLines: zeilen,
                          overflow: ueberlauf,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outlineVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            if (chips.isNotEmpty) ...[
              const SizedBox(width: 8),
              _StufenIcons(chips: chips, onTap: widget.onStufenTap),
            ],
            ...widget.actions,
          ],
        ),
      ),
    );
  }

  String _fakten(BuildContext context) {
    final t = AppLocalizations.of(context);
    final teile = <String>[
      if (mitglied.hatBekanntesGeburtsdatum)
        t.t('member_detail_alter', {
          'n': MemberUtils.alterInJahren(mitglied, stichtag: heute),
        }),
      if (mitglied.pronoun?.trim().isNotEmpty == true) mitglied.pronoun!.trim(),
      if (mitglied.gender?.trim().isNotEmpty == true)
        memberGenderLabel(context, mitglied.gender).toLowerCase(),
      if (mitglied.austrittsdatum != null &&
          !mitglied.austrittsdatum!.isAfter(heute))
        t.t('member_detail_ausgetreten_jahr', {
          'jahr': mitglied.austrittsdatum!.year,
        }),
    ];
    return teile.join(' · ');
  }
}

/// Chip im Steckbrief: aktive Stufe als Mitglied oder Leitung, oder
/// „Sonstige“, wenn nur Aemter ohne Stufe aktiv sind.
class SteckbriefChip {
  const SteckbriefChip.stufe(this.stufe, {required this.leitung})
    : sonstige = false;
  const SteckbriefChip.sonstige()
    : stufe = null,
      leitung = false,
      sonstige = true;

  final Stufe? stufe;
  final bool leitung;
  final bool sonstige;

  @override
  bool operator ==(Object other) =>
      other is SteckbriefChip &&
      other.stufe == stufe &&
      other.leitung == leitung &&
      other.sonstige == sonstige;

  @override
  int get hashCode => Object.hash(stufe, leitung, sonstige);
}

/// Alle aktiven Stufenrollen ohne Doppelungen, Leitung zuerst, innerhalb
/// davon die aeltere Stufe zuerst.
List<SteckbriefChip> steckbriefChips(
  Mitglied mitglied, {
  required DateTime heute,
}) {
  final aktive = mitglied.roles
      .where(
        (rolle) =>
            !MemberUtils.istMitgliederRolle(rolle) && rolle.isActiveAt(heute),
      )
      .toList(growable: false);
  final chips = <SteckbriefChip>{};
  for (final rolle in aktive) {
    if (rolle.art == RoleCategory.sonstiges || rolle.stufe == Stufe.leitung) {
      continue;
    }
    chips.add(
      SteckbriefChip.stufe(
        rolle.stufe,
        leitung: rolle.art == RoleCategory.leitung,
      ),
    );
  }
  if (chips.isEmpty) {
    return aktive.isEmpty
        ? const <SteckbriefChip>[]
        : const <SteckbriefChip>[SteckbriefChip.sonstige()];
  }
  return chips.toList()..sort((a, b) {
    if (a.leitung != b.leitung) {
      return a.leitung ? -1 : 1;
    }
    return b.stufe!.index.compareTo(a.stufe!.index);
  });
}

/// Beschriftung eines Chips, etwa „Wö-Leitung“; dient als Tooltip.
String steckbriefChipLabel(SteckbriefChip chip, AppLocalizations t) {
  final stufe = chip.stufe;
  if (chip.sonstige || stufe == null) {
    return t.t('member_detail_sonstige');
  }
  return chip.leitung
      ? t.t('member_detail_stufe_leitung', {'stufe': stufe.shortDisplayName})
      : stufe.shortDisplayName;
}

/// Aktive Stufen als ueberlappende runde Icons; ab vier Stufen fasst ein
/// „+n“ den Rest zusammen.
class _StufenIcons extends StatelessWidget {
  const _StufenIcons({required this.chips, this.onTap});

  final List<SteckbriefChip> chips;
  final VoidCallback? onTap;

  static const int _maxIcons = 3;
  static const double _groesse = 26;
  static const double _versatz = 20;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final sichtbar = chips.take(_maxIcons).toList(growable: false);
    final rest = chips.skip(_maxIcons).toList(growable: false);
    final anzahl = sichtbar.length + (rest.isEmpty ? 0 : 1);
    final icons = <Widget>[
      for (final chip in sichtbar)
        Tooltip(
          message: steckbriefChipLabel(chip, t),
          child: _StufenIcon(chip: chip, groesse: _groesse),
        ),
      if (rest.isNotEmpty)
        Tooltip(
          message: rest.map((chip) => steckbriefChipLabel(chip, t)).join(', '),
          child: _RestIcon(anzahl: rest.length, groesse: _groesse),
        ),
    ];

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: _groesse + (anzahl - 1) * _versatz,
        height: _groesse,
        child: Stack(
          children: [
            for (var i = 0; i < icons.length; i++)
              Positioned(left: i * _versatz, top: 0, child: icons[i]),
          ],
        ),
      ),
    );
  }
}

class _StufenIcon extends StatelessWidget {
  const _StufenIcon({required this.chip, required this.groesse});

  final SteckbriefChip chip;
  final double groesse;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stufe = chip.stufe;
    final farbe = stufe == null
        ? theme.colorScheme.outlineVariant
        : StatistikFarben.of(context).stufe(stufe);
    final dunkel = theme.brightness == Brightness.dark;
    // Dunkle Maskottchen (Rover, Jufi) brauchen im Dunkelmodus hellen Grund.
    final hintergrund = chip.sonstige
        ? theme.colorScheme.surfaceContainerHighest
        : !chip.leitung && dunkel
        ? const Color(0xFFE9E9EE)
        : Color.alphaBlend(
            farbe.withValues(alpha: 0.18),
            theme.colorScheme.surface,
          );
    final icon = chip.sonstige || chip.leitung
        ? Image.asset(
            StufeVisuals.assetFor(Stufe.leitung),
            width: groesse * 0.55,
            height: groesse * 0.55,
            color: chip.sonstige ? theme.colorScheme.onSurface : farbe,
            colorBlendMode: BlendMode.srcIn,
            cacheWidth: 48,
            cacheHeight: 48,
          )
        : Image.asset(
            StufeVisuals.assetFor(stufe!),
            width: groesse * 0.72,
            height: groesse * 0.72,
            cacheWidth: 60,
            cacheHeight: 60,
          );

    return Container(
      width: groesse,
      height: groesse,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: hintergrund,
        border: Border.all(
          width: 1.5,
          color: chip.sonstige
              ? theme.colorScheme.outline
              : farbe.withValues(alpha: 0.7),
        ),
      ),
      child: icon,
    );
  }
}

class _RestIcon extends StatelessWidget {
  const _RestIcon({required this.anzahl, required this.groesse});

  final int anzahl;
  final double groesse;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: groesse,
      height: groesse,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: theme.colorScheme.surfaceContainerHighest,
        border: Border.all(width: 1.5, color: theme.colorScheme.outline),
      ),
      child: Text(
        '+$anzahl',
        maxLines: 1,
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.mitglied});

  final Mitglied mitglied;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initialen = [mitglied.vorname, mitglied.nachname]
        .where((value) => value.trim().isNotEmpty)
        .map((value) => value.trim().substring(0, 1).toUpperCase())
        .take(2)
        .join();

    return CircleAvatar(
      radius: 19,
      backgroundColor: theme.colorScheme.primaryContainer,
      foregroundColor: theme.colorScheme.onPrimaryContainer,
      child: Text(
        initialen.isEmpty ? '?' : initialen,
        style: theme.textTheme.labelLarge,
      ),
    );
  }
}

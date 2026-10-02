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

/// Steckbrief-Kopf der Mitgliedsdetails: Avatar, Name, Zeile mit Alter,
/// Pronomen und Geschlecht sowie Chips aller aktiven Stufenrollen.
class MemberSteckbriefKopf extends StatelessWidget {
  const MemberSteckbriefKopf({
    super.key,
    required this.mitglied,
    required this.heute,
    this.supporterBadge,
  });

  final Mitglied mitglied;
  final DateTime heute;
  final SupporterBadgeId? supporterBadge;

  static const double _maxTextSkalierung = 1.4;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context);
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
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _Avatar(mitglied: mitglied),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              titel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (supporterBadge != null) ...[
                            const SizedBox(width: 6),
                            SupporterBadge(badge: supporterBadge!, size: 20),
                          ],
                        ],
                      ),
                      if (hatFahrtenname && mitglied.fullName.isNotEmpty)
                        Text(
                          mitglied.fullName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium,
                        ),
                      if (fakten.isNotEmpty)
                        Text(
                          fakten,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outlineVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (chips.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final chip in chips) _StufenChip(chip: chip, t: t),
                ],
              ),
            ],
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

class _StufenChip extends StatelessWidget {
  const _StufenChip({required this.chip, required this.t});

  final SteckbriefChip chip;
  final AppLocalizations t;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stufe = chip.stufe;
    final farbe = stufe == null
        ? theme.colorScheme.outlineVariant
        : StatistikFarben.of(context).stufe(stufe);
    final label = chip.sonstige
        ? t.t('member_detail_sonstige')
        : chip.leitung
        ? t.t('member_detail_stufe_leitung', {'stufe': stufe!.shortDisplayName})
        : stufe!.shortDisplayName;
    final icon = chip.sonstige || chip.leitung
        ? Image.asset(
            StufeVisuals.assetFor(Stufe.leitung),
            width: 14,
            height: 14,
            color: chip.sonstige ? theme.colorScheme.onSurface : farbe,
            colorBlendMode: BlendMode.srcIn,
            cacheWidth: 40,
            cacheHeight: 40,
          )
        : Image.asset(
            StufeVisuals.assetFor(stufe!),
            width: 14,
            height: 14,
            cacheWidth: 40,
            cacheHeight: 40,
          );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: chip.sonstige
            ? theme.colorScheme.surfaceContainerHighest
            : farbe.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: chip.sonstige
              ? theme.colorScheme.outline
              : farbe.withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
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
      radius: 28,
      backgroundColor: theme.colorScheme.primaryContainer,
      foregroundColor: theme.colorScheme.onPrimaryContainer,
      child: Text(
        initialen.isEmpty ? '?' : initialen,
        style: theme.textTheme.titleMedium,
      ),
    );
  }
}

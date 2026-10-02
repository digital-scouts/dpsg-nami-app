import 'package:flutter/material.dart';

import '../../../domain/member/member_utils.dart';
import '../../../domain/member/mitglied.dart';
import '../../../domain/taetigkeit/stufe.dart';
import '../../stufe/stufe_visuals.dart';

/// Sichtbare Mitglieder desselben Hitobito-Haushalts als antippbare Chips.
class MemberFamilieChips extends StatelessWidget {
  const MemberFamilieChips({
    super.key,
    required this.haushalt,
    required this.heute,
    this.onTap,
  });

  final List<Mitglied> haushalt;
  final DateTime heute;
  final ValueChanged<Mitglied>? onTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final mitglied in haushalt)
          _FamilienChip(mitglied: mitglied, heute: heute, onTap: onTap),
      ],
    );
  }
}

class _FamilienChip extends StatelessWidget {
  const _FamilienChip({
    required this.mitglied,
    required this.heute,
    this.onTap,
  });

  final Mitglied mitglied;
  final DateTime heute;
  final ValueChanged<Mitglied>? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stufe = MemberUtils.aktiveStufe(mitglied, heute: heute);
    final details = <String>[
      if (stufe != null && stufe != Stufe.leitung) stufe.shortDisplayName,
      if (mitglied.hatBekanntesGeburtsdatum)
        '${MemberUtils.alterInJahren(mitglied, stichtag: heute)}',
    ].join(' · ');
    final vorname = mitglied.vorname.trim().isEmpty
        ? mitglied.fullName
        : mitglied.vorname.trim();

    return Material(
      color: theme.colorScheme.surface,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap == null ? null : () => onTap!(mitglied),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 5, 12, 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (stufe != null && stufe != Stufe.leitung)
                Image.asset(
                  StufeVisuals.assetFor(stufe),
                  width: 22,
                  height: 22,
                  cacheWidth: 60,
                  cacheHeight: 60,
                )
              else
                const Icon(Icons.person_outline, size: 20),
              const SizedBox(width: 7),
              Text(
                vorname,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (details.isNotEmpty) ...[
                const SizedBox(width: 6),
                Text(
                  details,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outlineVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

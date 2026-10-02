import 'package:flutter/material.dart';

import '../../../domain/taetigkeit/role_derivation.dart';
import '../../../domain/taetigkeit/roles.dart';
import '../../../domain/taetigkeit/stufe.dart';
import '../../statistics/statistik_farben.dart';
import '../../stufe/stufe_visuals.dart';

/// Symbol einer Rolle: Maskottchen fuer Mitglieder einer Stufe, Lilie in
/// Stufenfarbe fuer Leitungen, graue Lilie fuer Aemter.
class RollenSymbol extends StatelessWidget {
  const RollenSymbol({super.key, required this.rolle, this.groesse = 24});

  final Role rolle;
  final double groesse;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stufe = rolle.stufe;
    final art = rolle.art;
    final cache = (groesse * 3).round();
    if (art == RoleCategory.mitglied && stufe != Stufe.leitung) {
      return SizedBox.square(
        dimension: groesse,
        child: Image.asset(
          StufeVisuals.assetFor(stufe),
          cacheWidth: cache,
          cacheHeight: cache,
        ),
      );
    }
    final farbe = art == RoleCategory.leitung && stufe != Stufe.leitung
        ? StatistikFarben.of(context).stufe(stufe)
        : theme.colorScheme.outlineVariant;
    return Container(
      width: groesse,
      height: groesse,
      padding: EdgeInsets.all(groesse * 0.14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        shape: BoxShape.circle,
      ),
      child: Image.asset(
        StufeVisuals.assetFor(Stufe.leitung),
        color: farbe,
        colorBlendMode: BlendMode.srcIn,
        cacheWidth: cache,
        cacheHeight: cache,
      ),
    );
  }
}

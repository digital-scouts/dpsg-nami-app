import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../domain/appearance/appearance_catalog.dart';
import '../../l10n/app_localizations.dart';

/// Supporter-Badge im Aufnaeher-Stil.
class SupporterBadge extends StatelessWidget {
  const SupporterBadge({super.key, required this.badge, this.size = 20});

  final SupporterBadgeId badge;
  final double size;

  @override
  Widget build(BuildContext context) {
    final info = AppearanceCatalog.badge(badge);
    final t = AppLocalizations.maybeOf(context);
    return Semantics(
      label: t?.t(
        info.tier == SupportTier.foerderer
            ? 'appearance_badge_semantics_foerderer'
            : 'appearance_badge_semantics_supporter',
      ),
      child: SvgPicture.asset(
        info.assetPath,
        key: ValueKey('supporter-badge-${info.assetName}'),
        width: size,
        height: size,
      ),
    );
  }
}

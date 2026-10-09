import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import 'app_seitenleiste.dart';

class AppBottomNavigation extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int>? onTap;

  const AppBottomNavigation({super.key, this.currentIndex = 0, this.onTap});

  /// Die vier Hauptbereiche, gemeinsam mit der [AppSeitenleiste].
  static List<AppSeitenleisteEintrag> hauptbereiche(AppLocalizations t) => [
    AppSeitenleisteEintrag(icon: Icons.groups, label: t.t('nav_members')),
    AppSeitenleisteEintrag(
      icon: Icons.insert_chart,
      label: t.t('nav_statistics'),
    ),
    AppSeitenleisteEintrag(
      icon: Icons.swap_horiz,
      label: t.t('nav_stage_change'),
    ),
    AppSeitenleisteEintrag(icon: Icons.settings, label: t.t('nav_settings')),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context);
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: onTap,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: theme.colorScheme.primary,
      unselectedItemColor: theme.colorScheme.onSurfaceVariant,
      items: [
        for (final eintrag in hauptbereiche(t))
          BottomNavigationBarItem(
            icon: Icon(eintrag.icon),
            label: eintrag.label,
          ),
      ],
    );
  }
}

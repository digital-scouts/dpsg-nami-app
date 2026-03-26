import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

class AppBottomNavigation extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int>? onTap;

  const AppBottomNavigation({super.key, this.currentIndex = 0, this.onTap});

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
        BottomNavigationBarItem(
          icon: const Icon(Icons.people),
          label: t.t('nav_my_stage'),
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.groups),
          label: t.t('nav_members'),
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.insert_chart),
          label: t.t('nav_statistics'),
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.settings),
          label: t.t('nav_settings'),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';

class AppBottomNavigation extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int>? onTap;

  const AppBottomNavigation({super.key, this.currentIndex = 0, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: onTap,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: theme.colorScheme.primary,
      unselectedItemColor: theme.colorScheme.onSurfaceVariant,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Meine Stufe'),
        BottomNavigationBarItem(icon: Icon(Icons.groups), label: 'Mitglieder'),
        BottomNavigationBarItem(
          icon: Icon(Icons.insert_chart),
          label: 'Statistiken',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.settings),
          label: 'Einstellungen',
        ),
      ],
    );
  }
}

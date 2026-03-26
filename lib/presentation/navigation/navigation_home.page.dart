import 'package:flutter/material.dart';
import 'package:nami/presentation/navigation/app_router.dart';
import 'package:nami/presentation/screens/settings_page.dart';
import 'package:nami/presentation/widgets/app_bottom_navigation.dart';

class NavigationHomeScreen extends StatefulWidget {
  const NavigationHomeScreen({super.key});

  @override
  State<NavigationHomeScreen> createState() => _NavigationHomeScreenState();
}

class _NavigationHomeScreenState extends State<NavigationHomeScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    Widget body;
    switch (_index) {
      case 0:
        body = Scaffold(
          appBar: AppBar(title: Text('Meine Stufe')),
          body: Center(child: Text('Meine Stufe')),
        );
        break;
      case 1:
        body = Scaffold(
          appBar: AppBar(title: Text('Mitglieder')),
          body: Center(child: Text('Mitglieder')),
        );
        break;
      case 2:
        body = Scaffold(
          appBar: AppBar(title: Text('Statistiken')),
          body: Center(child: Text('Statistiken')),
        );
        break;
      case 3:
        body = SettingsPage(
          onStammSettings: () =>
              Navigator.pushNamed(context, AppRoutes.settingsStamm),
          onAppSettings: () =>
              Navigator.pushNamed(context, AppRoutes.settingsApp),
          onProfile: () => Navigator.pushNamed(context, AppRoutes.profile),
          onDebugTools: () =>
              Navigator.pushNamed(context, AppRoutes.debugTools),
          onNotifications: () =>
              Navigator.pushNamed(context, AppRoutes.pullNotifications),
          onNotificationSettings: () =>
              Navigator.pushNamed(context, AppRoutes.settingsNotification),
        );
        break;
      default:
        body = const Center(child: Text('Meine Stufe'));
    }

    return Scaffold(
      body: body,
      bottomNavigationBar: AppBottomNavigation(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
      ),
    );
  }
}

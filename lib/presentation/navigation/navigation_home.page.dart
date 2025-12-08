import 'package:flutter/material.dart';
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
          userId: "133",
          userName: "Max Mustermann",
          onLogout: () => print("Logout clicked"),
          onStammSettings: () =>
              Navigator.pushNamed(context, '/settings/stamm'),
          onAppSettings: () => Navigator.pushNamed(context, '/settings/app'),
          onProfile: () => Navigator.pushNamed(context, '/profile'),
          onDebugTools: () => Navigator.pushNamed(context, '/settings/debug'),
          onNotifications: () =>
              Navigator.pushNamed(context, '/settings/notifications'),
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

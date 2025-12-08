import 'package:flutter/material.dart';

import '../../data/settings/in_memory_address_settings_repository.dart';
import '../../domain/stufe/altersgrenzen.dart';
import '../navigation/navigation_home.page.dart';
import '../screens/settings_stamm_page.dart';

class AppRoutes {
  static const String home = '/';
  static const String settingsStamm = '/settings/stamm';
}

Route<dynamic> onGenerateRoute(RouteSettings settings) {
  switch (settings.name) {
    case AppRoutes.home:
      return MaterialPageRoute(builder: (_) => const NavigationHomeScreen());
    case AppRoutes.settingsStamm:
      return MaterialPageRoute(
        builder: (_) => SettingsStammPage(
          addressRepository: InMemoryAddressSettingsRepository(),
          initialAltersgrenzen: StufenDefaults.build(),
        ),
      );
    default:
      return MaterialPageRoute(builder: (_) => const NavigationHomeScreen());
  }
}

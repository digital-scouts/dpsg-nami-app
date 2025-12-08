import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/settings/in_memory_address_settings_repository.dart';
import '../../domain/stufe/altersgrenzen.dart';
import '../navigation/navigation_home.page.dart';
import '../screens/app_settings_page.dart';
import '../screens/settings_stamm_page.dart';
import '../theme/locale_model.dart';
import '../theme/theme.dart';
// Keine Provider/ignore_deprecated-Abhängigkeit für AppSettingsPage

class AppRoutes {
  static const String home = '/';
  static const String settingsStamm = '/settings/stamm';
  static const String settingsApp = '/settings/app';
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
    case AppRoutes.settingsApp:
      return MaterialPageRoute(
        builder: (context) => AppSettingsPage(
          notificationsEnabled: true,
          analyticsEnabled: false,
          themeMode: ThemeMode.system,
          languageCode: 'de',
          onNotificationsChanged: (v) {
            // TODO: persist/apply notifications flag
          },
          onAnalyticsChanged: (v) {
            // TODO: persist/apply analytics flag
          },
          onThemeModeChanged: (mode) {
            final themeModel = Provider.of<ThemeModel>(context, listen: false);
            themeModel.setTheme(mode);
          },
          onLanguageChanged: (code) {
            final localeModel = Provider.of<LocaleModel>(
              context,
              listen: false,
            );
            localeModel.setLocale(Locale(code));
          },
        ),
      );
    default:
      return MaterialPageRoute(builder: (_) => const NavigationHomeScreen());
  }
}

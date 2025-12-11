import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/settings/shared_prefs_address_settings_repository.dart';
import '../../data/settings/shared_prefs_stufen_settings_repository.dart';
import '../../domain/settings/stufen_settings.dart';
import '../../domain/stufe/altersgrenzen.dart';
import '../../services/logger_service.dart';
import '../navigation/navigation_home.page.dart';
import '../screens/settings_app_page.dart';
import '../screens/settings_debug_tools_page.dart';
import '../screens/settings_notification_page.dart';
import '../screens/settings_stamm_page.dart';
import '../theme/app_settings_model.dart';
import '../theme/locale_model.dart';
import '../theme/theme.dart';

class AppRoutes {
  static const String home = '/';
  static const String settingsStamm = '/settings/stamm';
  static const String settingsApp = '/settings/app';
  static const String settingsNotification = '/settings/notifications';
  static const String debugTools = '/settings/debug';
}

Route<dynamic> onGenerateRoute(RouteSettings settings) {
  switch (settings.name) {
    case AppRoutes.home:
      return MaterialPageRoute(builder: (_) => const NavigationHomeScreen());
    case AppRoutes.settingsStamm:
      return MaterialPageRoute(
        builder: (context) {
          final repo = SharedPrefsStufenSettingsRepository();
          return FutureBuilder<StufenSettings>(
            future: repo.load(),
            builder: (context, snapshot) {
              final loaded = snapshot.data;
              final initialGrenzen = loaded?.grenzen ?? StufenDefaults.build();
              final initialDate = loaded?.stufenwechselDatum;
              return SettingsStammPage(
                addressRepository: SharedPrefsAddressSettingsRepository(),
                initialAltersgrenzen: initialGrenzen,
                initialStufenwechsel: initialDate,
                onSaveAltersgrenzen: (grenzen) async {
                  final current =
                      loaded ??
                      StufenSettings(
                        grenzen: initialGrenzen,
                        stufenwechselDatum: initialDate,
                      );
                  await repo.saveAltersgrenzen(
                    current.copyWith(grenzen: grenzen),
                  );
                },
                onStufenwechselChanged: (date) async {
                  await repo.saveStufenwechselDatum(date);
                },
              );
            },
          );
        },
      );
    case AppRoutes.settingsApp:
      return MaterialPageRoute(
        builder: (context) {
          final themeModel = Provider.of<ThemeModel>(context, listen: false);
          final localeModel = Provider.of<LocaleModel>(context, listen: false);
          final appSettings = Provider.of<AppSettingsModel>(
            context,
            listen: false,
          );

          return AppSettingsPage(
            analyticsEnabled: appSettings.analyticsEnabled,
            themeMode: themeModel.currentMode,
            languageCode: localeModel.currentLocale.languageCode,
            onAnalyticsChanged: (v) async {
              final logger = Provider.of<LoggerService>(context, listen: false);
              await logger.trackAndLog('settings', 'telemetry_changed', {
                'value': v,
              });
              await appSettings.setAnalyticsEnabled(v);
            },
            onThemeModeChanged: (mode) async {
              final logger = Provider.of<LoggerService>(context, listen: false);
              themeModel.setTheme(mode);
              logger.trackAndLog('settings', 'theme_changed', {
                'mode': mode.name,
              });
              await appSettings.setThemeMode(mode);
            },
            onLanguageChanged: (code) async {
              final logger = Provider.of<LoggerService>(context, listen: false);
              localeModel.setLocale(Locale(code));
              logger.trackAndLog('settings', 'language_changed', {
                'code': code,
              });
              await appSettings.setLanguageCode(code);
            },
          );
        },
      );
    case AppRoutes.settingsNotification:
      return MaterialPageRoute(
        builder: (context) {
          return SettingsNotificationPage(
            notificationsEnabled: true,
            onNotificationsChanged: (v) async {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Benachrichtigungen geändert: $v')),
              );
              // Persist setting if AppSettingsModel later supports it
              // await appSettings.setNotificationsEnabled(v);
            },
          );
        },
      );
    case AppRoutes.debugTools:
      return MaterialPageRoute(builder: (context) => const DebugToolsPage());
    default:
      return MaterialPageRoute(builder: (_) => const NavigationHomeScreen());
  }
}

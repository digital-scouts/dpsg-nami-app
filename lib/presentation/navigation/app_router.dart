import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// import '../../data/settings/in_memory_address_settings_repository.dart';
import '../../data/settings/shared_prefs_address_settings_repository.dart';
import '../../data/settings/shared_prefs_stufen_settings_repository.dart';
import '../../domain/settings/stufen_settings.dart';
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
        builder: (context) => AppSettingsPage(
          notificationsEnabled: true,
          analyticsEnabled: false,
          themeMode: Provider.of<ThemeModel>(
            context,
            listen: false,
          ).currentMode,
          languageCode: Provider.of<LocaleModel>(
            context,
            listen: false,
          ).currentLocale.languageCode,
          onNotificationsChanged: (v) {
            // TODO: persist/apply notifications flag
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Benachrichtigungen geändert: $v')),
            );
          },
          onAnalyticsChanged: (v) {
            // TODO: persist/apply analytics flag
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Analytics geändert: $v')));
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

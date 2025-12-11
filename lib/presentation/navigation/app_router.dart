import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/settings/shared_prefs_address_settings_repository.dart';
import '../../data/settings/shared_prefs_stufen_settings_repository.dart';
import '../../data/settings/stufen_settings_repo_adapter.dart';
import '../../domain/settings/stufen_settings.dart';
import '../../domain/stufe/altersgrenzen.dart';
import '../../domain/stufe/usecases/update_altersgrenzen_usecase.dart';
import '../../l10n/app_localizations.dart';
import '../../services/logger_service.dart';
import '../model/app_settings_model.dart';
import '../model/locale_model.dart';
import '../navigation/navigation_home.page.dart';
import '../screens/settings_app_page.dart';
import '../screens/settings_debug_tools_page.dart';
import '../screens/settings_notification_page.dart';
import '../screens/settings_stamm_page.dart';
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
                  final adapter = StufenSettingsRepoAdapter(
                    prefsRepo: repo,
                    currentDateProvider: () => current.stufenwechselDatum,
                  );
                  final usecase = UpdateAltersgrenzenUseCase(adapter);
                  try {
                    await usecase.call(grenzen);
                    // ignore: use_build_context_synchronously
                    final l10n = AppLocalizations.of(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: Colors.transparent,
                        elevation: 0,
                        content: AwesomeSnackbarContent(
                          title: l10n.t('snackbar_saved_title'),
                          message: l10n.t('snackbar_saved_altersgrenzen'),
                          contentType: ContentType.success,
                        ),
                      ),
                    );
                  } on AltersgrenzenValidationError catch (e) {
                    // ignore: use_build_context_synchronously
                    final l10n = AppLocalizations.of(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: Colors.transparent,
                        elevation: 0,
                        content: AwesomeSnackbarContent(
                          title: l10n.t('snackbar_invalid_altersgrenzen_title'),
                          message: e.message,
                          contentType: ContentType.failure,
                        ),
                      ),
                    );
                  }
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
              await logger.debounceTrackAndLog(
                'settings',
                'telemetry_changed',
                {'value': v},
              );
              await appSettings.setAnalyticsEnabled(v);
            },
            onThemeModeChanged: (mode) async {
              final logger = Provider.of<LoggerService>(context, listen: false);
              themeModel.setTheme(mode);
              logger.debounceTrackAndLog('settings', 'theme_changed', {
                'mode': mode.name,
              });
              await appSettings.setThemeMode(mode);
            },
            onLanguageChanged: (code) async {
              final logger = Provider.of<LoggerService>(context, listen: false);
              localeModel.setLocale(Locale(code));
              logger.debounceTrackAndLog('settings', 'language_changed', {
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
          final logger = Provider.of<LoggerService>(context, listen: false);
          final appSettings = Provider.of<AppSettingsModel>(
            context,
            listen: false,
          );
          return SettingsNotificationPage(
            notificationsEnabled: appSettings.notificationsEnabled,
            onNotificationsChanged: (v) async {
              logger.debounceTrackAndLog('settings', 'notifications_changed', {
                'value': v,
              });
              await appSettings.setNotificationsEnabled(v);
            },
            geburstagsbenachrichtigungStufen:
                appSettings.geburstagsbenachrichtigungStufen,
            geburstagsbenachrichtigungStufenChanged: (stufen) async {
              await appSettings.setGeburstagsbenachrichtigungStufen(stufen);
              logger.debounceTrackAndLog(
                'settings',
                'birthday_notification_stages_changed',
                {'stufen': stufen.map((s) => s.name).toList()},
              );
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

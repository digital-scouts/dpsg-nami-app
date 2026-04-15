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
import '../notifications/notifications_page.dart';
import '../screens/profile_page.dart';
import '../screens/settings_app_page.dart';
import '../screens/settings_debug_tools_page.dart';
import '../screens/settings_map_page.dart';
import '../screens/settings_notification_page.dart';
import '../screens/settings_stamm_page.dart';
import '../theme/theme.dart';

class AppRoutes {
  static const String home = '/';
  static const String memberDetail = '/members/detail';
  static const String settingsStamm = '/settings/stamm';
  static const String settingsApp = '/settings/app';
  static const String settingsNotification = '/settings/notifications';
  static const String settingsMap = '/settings/map';
  static const String debugTools = '/settings/debug';
  static const String pullNotifications = '/notifications';
  static const String profile = '/profile';
}

Route<dynamic> onGenerateRoute(RouteSettings settings) {
  switch (settings.name) {
    case AppRoutes.home:
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => const NavigationHomeScreen(),
      );
    case AppRoutes.profile:
      return MaterialPageRoute(
        settings: settings,
        builder: (context) => const ProfilePage(),
      );
    case AppRoutes.settingsStamm:
      return MaterialPageRoute(
        settings: settings,
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
                    final l10n = AppLocalizations.of(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: Colors.transparent,
                        elevation: 0,
                        content: AwesomeSnackbarContent(
                          title: l10n.t('snackbar_invalid_altersgrenzen_title'),
                          message: e.message,
                          contentType: ContentType.help,
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
        settings: settings,
        builder: (context) {
          final themeModel = Provider.of<ThemeModel>(context, listen: false);
          final localeModel = Provider.of<LocaleModel>(context, listen: false);
          final appSettings = Provider.of<AppSettingsModel>(
            context,
            listen: false,
          );

          return AppSettingsPage(
            analyticsEnabled: appSettings.analyticsEnabled,
            biometricLockEnabled: appSettings.biometricLockEnabled,
            noMobileDataEnabled: appSettings.noMobileDataEnabled,
            memberListSearchResultHighlightEnabled:
                appSettings.memberListSearchResultHighlightEnabled,
            themeMode: themeModel.currentMode,
            languageCode: localeModel.currentLocale.languageCode,
            onAnalyticsChanged: (v) async {
              final logger = Provider.of<LoggerService>(context, listen: false);
              await appSettings.setAnalyticsEnabled(v);
              await logger.debounceTrackSettingsChanged('analytics', {
                'value': v,
              });
            },
            onBiometricLockChanged: (v) async {
              final logger = Provider.of<LoggerService>(context, listen: false);
              await appSettings.setBiometricLockEnabled(v);
              await logger.debounceTrackSettingsChanged('biometric_lock', {
                'value': v,
              });
            },
            onNoMobileDataChanged: (v) async {
              final logger = Provider.of<LoggerService>(context, listen: false);
              await appSettings.setNoMobileDataEnabled(v);
              await logger.debounceTrackSettingsChanged('no_mobile_data', {
                'value': v,
              });
            },
            onMemberListSearchResultHighlightChanged: (v) async {
              final logger = Provider.of<LoggerService>(context, listen: false);
              await appSettings.setMemberListSearchResultHighlightEnabled(v);
              await logger.debounceTrackSettingsChanged(
                'member_search_result_highlight',
                {'value': v},
              );
            },
            onThemeModeChanged: (mode) async {
              final logger = Provider.of<LoggerService>(context, listen: false);
              themeModel.setTheme(mode);
              await appSettings.setThemeMode(mode);
              await logger.debounceTrackSettingsChanged('theme', {
                'mode': mode.name,
              });
            },
            onLanguageChanged: (code) async {
              final logger = Provider.of<LoggerService>(context, listen: false);
              localeModel.setLocale(Locale(code));
              await appSettings.setLanguageCode(code);
              await logger.debounceTrackSettingsChanged('language', {
                'code': code,
              });
            },
          );
        },
      );
    case AppRoutes.settingsNotification:
      return MaterialPageRoute(
        settings: settings,
        builder: (context) {
          final logger = Provider.of<LoggerService>(context, listen: false);
          final appSettings = Provider.of<AppSettingsModel>(
            context,
            listen: false,
          );
          return SettingsNotificationPage(
            notificationsEnabled: appSettings.notificationsEnabled,
            onNotificationsChanged: (v) async {
              await appSettings.setNotificationsEnabled(v);
              await logger.debounceTrackSettingsChanged('notifications', {
                'value': v,
              });
            },
            geburstagsbenachrichtigungStufen:
                appSettings.geburstagsbenachrichtigungStufen,
            geburstagsbenachrichtigungStufenChanged: (stufen) async {
              await appSettings.setGeburstagsbenachrichtigungStufen(stufen);
              await logger.debounceTrackSettingsChanged('birthday_stages', {
                'stufen': stufen.map((s) => s.name).toList(),
              });
            },
          );
        },
      );
    case AppRoutes.settingsMap:
      return MaterialPageRoute(
        settings: settings,
        builder: (context) => const SettingsMapPage(),
      );
    case AppRoutes.pullNotifications:
      return MaterialPageRoute(
        settings: settings,
        builder: (context) => const NotificationsPage(),
      );
    case AppRoutes.debugTools:
      return MaterialPageRoute(
        settings: settings,
        builder: (context) => const DebugToolsPage(),
      );
    default:
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => const NavigationHomeScreen(),
      );
  }
}

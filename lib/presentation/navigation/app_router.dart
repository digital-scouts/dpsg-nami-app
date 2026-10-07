import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/settings/shared_prefs_address_settings_repository.dart';
import '../../data/settings/shared_prefs_stufen_settings_repository.dart';
import '../../data/settings/stufen_settings_repo_adapter.dart';
import '../../domain/arbeitskontext/arbeitskontext_read_model.dart';
import '../../domain/settings/stufen_settings.dart';
import '../../domain/stufe/altersgrenzen.dart';
import '../../domain/stufe/usecases/update_altersgrenzen_usecase.dart';
import '../../l10n/app_localizations.dart';
import '../../services/achievement_service.dart';
import '../../services/logger_service.dart';
import '../model/achievements_model.dart';
import '../model/app_settings_model.dart';
import '../model/bundesstatistik_model.dart';
import '../model/locale_model.dart';
import '../navigation/navigation_home.page.dart';
import '../notifications/app_snackbar.dart';
import '../notifications/feedback_prompt_dialog.dart';
import '../notifications/notifications_page.dart';
import '../screens/achievements_page.dart';
import '../screens/bundesvergleich_page.dart';
import '../screens/nami_ai/nami_ai_chat_page.dart';
import '../screens/nami_ai/nami_ai_paywall_page.dart';
import '../screens/profile_page.dart';
import '../screens/settings_app_page.dart';
import '../screens/settings_appearance_page.dart';
import '../screens/settings_datenschutz_page.dart';
import '../screens/settings_debug_tools_page.dart';
import '../screens/settings_impressum_page.dart';
import '../screens/settings_map_page.dart';
import '../screens/settings_notification_page.dart';
import '../screens/settings_qualifikationen_page.dart';
import '../screens/settings_stamm_page.dart';
import '../screens/settings_stufenwechsel_page.dart';
import '../screens/statistics_group_detail_page.dart';
import '../theme/theme.dart';
import '../widgets/bundesstatistik_einwilligung_dialog.dart';

class AppRoutes {
  static const String home = '/';
  static const String memberDetail = '/members/detail';
  static const String settingsStamm = '/settings/stamm';
  static const String settingsApp = '/settings/app';
  static const String settingsAppearance = '/settings/appearance';
  static const String settingsNotification = '/settings/notifications';
  static const String settingsMap = '/settings/map';
  static const String settingsMessages = '/settings/messages';
  static const String settingsImpressum = '/settings/impressum';
  static const String settingsDatenschutz = '/settings/datenschutz';
  static const String settingsStufenwechsel = '/settings/stufenwechsel';
  static const String settingsQualifikationen = '/settings/qualifikationen';
  static const String debugTools = '/settings/debug';
  static const String pullNotifications = '/notifications';
  static const String profile = '/profile';
  static const String statisticsGroupDetail = '/statistics/group-detail';
  static const String statisticsBundesvergleich = '/statistics/bundesvergleich';
  static const String namiAiChat = '/nami-ai/chat';
  static const String namiAiPaywall = '/nami-ai/paywall';
  static const String achievements = '/achievements';
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
        builder: (context) => ProfilePage(
          achievements: context.watch<AchievementsModel>().achievements,
          onAchievements: () =>
              Navigator.pushNamed(context, AppRoutes.achievements),
        ),
      );
    case AppRoutes.achievements:
      return MaterialPageRoute(
        settings: settings,
        builder: (context) => AchievementsPage(
          achievements: context.watch<AchievementsModel>().achievements,
          // Passiver Link zur Bewertung nur auf iOS; auf Android gibt es das
          // Abzeichen nicht.
          onRateApp: defaultTargetPlatform == TargetPlatform.iOS
              ? () => openAppStoreReviewPage(
                  logger: context.read<LoggerService>(),
                  achievements: context.read<AchievementService>(),
                )
              : null,
          onGiveFeedback: () => openFeedback(
            context,
            achievements: context.read<AchievementService>(),
          ),
        ),
      );
    case AppRoutes.namiAiChat:
      return MaterialPageRoute(
        settings: settings,
        builder: (context) => const NamiAiChatPage(),
      );
    case AppRoutes.namiAiPaywall:
      return MaterialPageRoute(
        settings: settings,
        builder: (context) => const NamiAiPaywallPage(),
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
                    AppSnackbar.show(
                      context,
                      title: l10n.t('snackbar_saved_title'),
                      message: l10n.t('snackbar_saved_altersgrenzen'),
                      type: AppSnackbarType.success,
                    );
                  } on AltersgrenzenValidationError catch (e) {
                    final l10n = AppLocalizations.of(context);
                    AppSnackbar.show(
                      context,
                      title: l10n.t('snackbar_invalid_altersgrenzen_title'),
                      message: e.message,
                      type: AppSnackbarType.warning,
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
          final localeModel = Provider.of<LocaleModel>(context, listen: false);
          final appSettings = Provider.of<AppSettingsModel>(
            context,
            listen: false,
          );
          final bundesstatistik = Provider.of<BundesstatistikModel>(
            context,
            listen: false,
          );

          return AppSettingsPage(
            bundesstatistikVerfuegbar: bundesstatistik.isAvailable,
            bundesstatistikTeilnahme: bundesstatistik.hatEinwilligung,
            onBundesstatistikChanged: (v) async {
              final logger = Provider.of<LoggerService>(context, listen: false);
              if (v && !await zeigeBundesstatistikEinwilligungDialog(context)) {
                return false;
              }
              await bundesstatistik.setzeEinwilligung(v);
              await logger.debounceTrackSettingsChanged('bundesstatistik', {
                'value': v,
              });
              return bundesstatistik.hatEinwilligung;
            },
            analyticsEnabled: appSettings.analyticsEnabled,
            biometricLockEnabled: appSettings.biometricLockEnabled,
            noMobileDataEnabled: appSettings.noMobileDataEnabled,
            memberListSearchResultHighlightEnabled:
                appSettings.memberListSearchResultHighlightEnabled,
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
    case AppRoutes.settingsAppearance:
      return MaterialPageRoute(
        settings: settings,
        builder: (context) {
          final themeModel = Provider.of<ThemeModel>(context, listen: false);
          final appSettings = Provider.of<AppSettingsModel>(
            context,
            listen: false,
          );
          return SettingsAppearancePage(
            themeMode: themeModel.currentMode,
            onThemeModeChanged: (mode) async {
              final logger = Provider.of<LoggerService>(context, listen: false);
              themeModel.setTheme(mode);
              await appSettings.setThemeMode(mode);
              await logger.debounceTrackSettingsChanged('theme', {
                'mode': mode.name,
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
    case AppRoutes.settingsMessages:
      return MaterialPageRoute(
        settings: settings,
        builder: (context) => const NotificationsPage(
          includeInternalMessages: true,
          showStatusButtons: false,
        ),
      );
    case AppRoutes.settingsImpressum:
      return MaterialPageRoute(
        settings: settings,
        builder: (context) => const SettingsImpressumPage(),
      );
    case AppRoutes.settingsDatenschutz:
      return MaterialPageRoute(
        settings: settings,
        builder: (context) => const SettingsDatenschutzPage(),
      );
    case AppRoutes.settingsStufenwechsel:
      return MaterialPageRoute(
        settings: settings,
        builder: (context) => const SettingsStufenwechselPage(),
      );
    case AppRoutes.settingsQualifikationen:
      return MaterialPageRoute(
        settings: settings,
        builder: (context) => const SettingsQualifikationenPage(),
      );
    case AppRoutes.pullNotifications:
      final arguments = settings.arguments;
      final showAllAcknowledged = arguments is Map<String, dynamic>
          ? (arguments['showAllAcknowledged'] as bool? ?? false)
          : false;
      return MaterialPageRoute(
        settings: settings,
        builder: (context) =>
            NotificationsPage(showAllAcknowledged: showAllAcknowledged),
      );
    case AppRoutes.statisticsGroupDetail:
      return MaterialPageRoute(
        settings: settings,
        builder: (context) {
          final arguments = settings.arguments;
          final groupId = arguments is Map<String, Object?>
              ? (arguments['groupId'] as String? ?? '')
              : arguments is String
              ? arguments
              : '';
          final readModel = arguments is Map<String, Object?>
              ? arguments['readModel']
              : null;
          return StatisticsGroupDetailPage(
            groupId: groupId,
            debugReadModel: readModel is ArbeitskontextReadModel
                ? readModel
                : null,
          );
        },
      );
    case AppRoutes.statisticsBundesvergleich:
      return MaterialPageRoute(
        settings: settings,
        builder: (context) => const BundesvergleichPage(),
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

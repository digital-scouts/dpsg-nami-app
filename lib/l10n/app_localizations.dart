import 'package:flutter/widgets.dart';

class AppLocalizations {
  final Locale locale;
  AppLocalizations(this.locale);

  static final LocalizationsDelegate<AppLocalizations> delegate =
      const _AppLocalizationsDelegate();

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static final Map<String, Map<String, String>> _localizedValues = {
    'de': {
      'nav_my_stage': 'Meine Stufe',
      'nav_members': 'Mitglieder',
      'nav_statistics': 'Statistiken',
      'nav_settings': 'Einstellungen',
      'snackbar_saved_title': 'Gespeichert',
      'snackbar_saved_altersgrenzen': 'Altersgrenzen erfolgreich gespeichert.',
      'snackbar_invalid_altersgrenzen_title': 'Ungültige Altersgrenzen',
      'settings_title': 'Einstellungen',
      'general': 'Allgemein',
      'settings_notifications': 'Benachrichtigungen',
      'pull_notifications_title': 'Mitteilungen',
      'settings_unread_notifications_title': 'Ungelesene Mitteilungen',
      'settings_unread_notifications_hint':
          'Du hast {count} ungelesene Mitteilungen. Vollständige Ansicht über Debug & Tools.',
      'settings_unread_notifications_urgent_hint':
          'Du hast {count} ungelesene Mitteilungen, darunter dringende Hinweise.',
      'open_notifications_in_debug': 'In Debug & Tools öffnen',
      'ignore': 'Ignorieren',
      'open_store': 'Zum Store',
      'acknowledge': 'Bestätigen',
      'update_available_title': 'Update verfügbar',
      'update_available_body': 'Es ist eine neuere Version der App verfügbar.',
      'update_required_title': 'Update erforderlich',
      'update_required_body':
          'Deine aktuelle App-Version wird nicht mehr unterstützt. Bitte aktualisiere die App.',
      'version': 'Version',
      'notifications_enable': 'Benachrichtigungen aktiviert',
      'analytics_enable': 'Analyse/Telemetry erlauben',
      'display': 'Anzeige',
      'theme': 'Theme',
      'theme_light': 'Hell',
      'theme_dark': 'Dunkel',
      'theme_system': 'Automatisch',
      'language': 'Sprache',
      'language_de': 'Deutsch',
      'language_en': 'Englisch (Beta)',
      'profile': 'Profil',
      'settings_stamm': 'Stammeseinstellungen',
      'settings_app': 'Appeinstellungen',
      'settings_debug_tools': 'Debug & Tools',
      'logout': 'Logout',
      'developed_with': 'Entwickelt mit',
      'developed_in_hamburg': 'in Hamburg',
      'version_label': 'Version',
      'changelog_title': 'Changelog',
      'changelog_installed_version': 'Installierte Version',
      'changelog_available_version': 'Verfügbare Version',
      'changelog_remote_versions': 'Remote-Versionen',
      'changelog_latest_version': 'Neueste Version',
      'changelog_min_supported': 'Mindestens unterstützt',
      'changelog_features': 'Neue Funktionen',
      'changelog_bugfixes': 'Fehlerbehebungen',
      'changelog_data_reset': 'Daten wurden zurückgesetzt',
      'changelog_load_error': 'Changelog konnte nicht geladen werden.',
      'changelog_remote_version_unavailable':
          'Remote-Versionsinformationen sind aktuell nicht verfügbar.',
      'address_section': 'Adresse',
      'address_help':
          'Die Adresse wird verwendet, um den Stamm auf der Karte zu verorten und die Entfernung von Mitgliedern zum Heim anzuzeigen.',
      'address_saved': 'Adresse gespeichert',
      'address_label': 'Heim-Adresse',
      'stufenwechsel_section': 'Stufenwechsel',
      'stufenwechsel_help':
          'Für die Empfehlung des nächsten Stufenwechsels wird das Datum und die in deinem Stamm verwendeten Altersgrenzen berücksichtigt.',
      'no_date_chosen': 'Kein Datum für den nächsten Stufenwechsel festgelegt',
      'pick_date': 'Datum wählen',
      'altersgruppen': 'Altersgruppen',
      'reset_changes': 'Änderungen zurücksetzen',
      'save': 'Speichern',
      'map_not_available': 'Karte nicht verfügbar',
    },
    'en': {
      'nav_my_stage': 'My Group',
      'nav_members': 'Members',
      'nav_statistics': 'Statistics',
      'nav_settings': 'Settings',
      'snackbar_saved_title': 'Saved',
      'snackbar_saved_altersgrenzen': 'Age limits saved successfully.',
      'snackbar_invalid_altersgrenzen_title': 'Invalid age limits',
      'settings_title': 'Settings',
      'general': 'General',
      'settings_notifications': 'Notification settings',
      'pull_notifications_title': 'Announcements',
      'settings_unread_notifications_title': 'Unread announcements',
      'settings_unread_notifications_hint':
          'You have {count} unread announcements. Open the full list in Debug & Tools.',
      'settings_unread_notifications_urgent_hint':
          'You have {count} unread announcements, including urgent ones.',
      'open_notifications_in_debug': 'Open in Debug & Tools',
      'ignore': 'Ignore',
      'open_store': 'Open store',
      'acknowledge': 'Acknowledge',
      'update_available_title': 'Update available',
      'update_available_body': 'A newer version of the app is available.',
      'update_required_title': 'Update required',
      'update_required_body':
          'Your current app version is no longer supported. Please update the app.',
      'version': 'Version',
      'notifications_enable': 'Notifications enabled',
      'analytics_enable': 'Allow analytics/telemetry',
      'display': 'Display',
      'theme': 'Theme',
      'theme_light': 'Light',
      'theme_dark': 'Dark',
      'theme_system': 'Automatic',
      'language': 'Language',
      'language_de': 'German',
      'language_en': 'English (Beta)',
      'profile': 'Profile',
      'settings_stamm': 'Troop settings',
      'settings_app': 'App settings',
      'settings_debug_tools': 'Debug & Tools',
      'logout': 'Logout',
      'developed_with': 'Built with',
      'developed_in_hamburg': 'in Hamburg',
      'version_label': 'Version',
      'changelog_title': 'Changelog',
      'changelog_installed_version': 'Installed version',
      'changelog_available_version': 'Available version',
      'changelog_remote_versions': 'Remote versions',
      'changelog_latest_version': 'Latest version',
      'changelog_min_supported': 'Minimum supported',
      'changelog_features': 'Features',
      'changelog_bugfixes': 'Bug fixes',
      'changelog_data_reset': 'Data reset required',
      'changelog_load_error': 'Could not load changelog.',
      'changelog_remote_version_unavailable':
          'Remote version information is currently unavailable.',
      'address_section': 'Address',
      'address_help':
          'The address is used to place the troop on the map and show the distance from members to the home.',
      'address_saved': 'Address saved',
      'address_label': 'Home address',
      'stufenwechsel_section': 'Stage change',
      'stufenwechsel_help':
          'To recommend the next stage change, the date and the age ranges used in your troop are considered.',
      'no_date_chosen': 'No date set for the next stage change',
      'pick_date': 'Pick date',
      'altersgruppen': 'Age groups',
      'reset_changes': 'Reset changes',
      'save': 'Save',
      'map_not_available': 'Map not available',
    },
  };

  String t(String key) {
    final lang = locale.languageCode;
    return _localizedValues[lang]?[key] ?? _localizedValues['en']![key] ?? key;
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['de', 'en'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations(locale);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

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
      'settings_title': 'App-Einstellungen',
      'general': 'Allgemein',
      'notifications_enable': 'Benachrichtigungen aktivieren',
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
      'stamm_settings': 'Stammeseinstellungen',
      'app_settings': 'Appeinstellungen',
      'debug_tools': 'Debug & Tools',
      'logout': 'Logout',
      'developed_in_hamburg': 'Entwickelt mit ❤️ in Hamburg',
      'version_label': 'Version',
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
    },
    'en': {
      'settings_title': 'App Settings',
      'general': 'General',
      'notifications_enable': 'Enable notifications',
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
      'stamm_settings': 'Troop settings',
      'app_settings': 'App settings',
      'debug_tools': 'Debug & Tools',
      'logout': 'Logout',
      'developed_in_hamburg': 'Built with ❤️ in Hamburg',
      'version_label': 'Version',
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

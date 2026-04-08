import 'package:flutter/widgets.dart';

class AppLocalizations {
  final Locale locale;
  AppLocalizations(this.locale);

  static final LocalizationsDelegate<AppLocalizations> delegate =
      const _AppLocalizationsDelegate();

  static AppLocalizations? maybeOf(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static AppLocalizations of(BuildContext context) {
    return maybeOf(context)!;
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
      'welcome_title': 'Willkommen',
      'welcome_body':
          'Willkommen in der App. Weitere Hinweise und Optionen folgen später. Vor dem breiteren Rollout der Kartenfunktion wird hier noch ein ausdrücklicher Privacy-Policy-Hinweis mit einer Bestätigung wie "Ich stimme Privacy Policy zu" ergänzt.',
      'welcome_action': 'Weiter',
      'version': 'Version',
      'notifications_enable': 'Benachrichtigungen aktiviert',
      'analytics_enable': 'Analyse/Telemetry erlauben',
      'app_lock_enable': 'App-Sperre aktivieren',
      'app_lock_enable_hint':
          'Fordert nach Rueckkehr aus dem Hintergrund die Geraeteauthentifizierung an.',
      'member_search_result_highlight_enable':
          'Suchtreffer im Untertitel hervorheben',
      'member_search_result_highlight_hint':
          'Zeigt bei aktiver Suche das passende Trefferfeld statt des Standard-Untertitels an.',
      'display': 'Anzeige',
      'theme': 'Theme',
      'theme_light': 'Hell',
      'theme_dark': 'Dunkel',
      'theme_system': 'Automatisch',
      'language': 'Sprache',
      'language_de': 'Deutsch',
      'language_en': 'Englisch (Beta)',
      'profile': 'Profil',
      'profile_loading': 'Profil wird geladen',
      'profile_last_sync_title': 'Profil zuletzt aktualisiert',
      'profile_not_loaded':
          'Das Hitobito-Profil konnte noch nicht geladen werden.',
      'profile_nami_id_label': 'nami-id',
      'profile_email_label': 'E-Mail',
      'profile_language_label': 'Sprache',
      'profile_context_title': 'Arbeitskontext',
      'profile_context_current_layer_label': 'Aktiver Layer',
      'profile_context_switch_action': 'Layer wechseln',
      'profile_context_no_other_layers':
          'Es sind aktuell keine weiteren erreichbaren Layer verfuegbar.',
      'profile_context_unavailable':
          'Der Arbeitskontext ist derzeit nicht verfuegbar.',
      'profile_context_loading': 'Arbeitskontext wird geladen',
      'profile_context_sheet_title': 'Layer wechseln',
      'profile_context_sheet_hint':
          'Waehle einen anderen erreichbaren Layer als aktiven Arbeitskontext.',
      'profile_context_current_badge': 'Aktuell aktiv',
      'profile_context_switch_loading': 'Arbeitskontext wird gewechselt',
      'profile_roles_title': 'Rollen',
      'profile_roles_empty': 'Keine Rollen im Profil vorhanden',
      'profile_permissions_label': 'Rechte',
      'members_loading': 'Mitglieder werden geladen',
      'members_empty': 'Keine Mitglieder vorhanden',
      'members_error': 'Mitglieder konnten nicht geladen werden.',
      'members_login_required':
          'Melde dich an, um Mitglieder aus Hitobito zu laden.',
      'members_sync_issue_cached':
          'Hitobito-Daten konnten nicht aktualisiert werden. Es werden lokale Daten angezeigt.',
      'members_sync_issue_relogin':
          'Hitobito-Daten konnten nicht aktualisiert werden. Bitte melde dich erneut an.',
      'settings_stamm': 'Stammeseinstellungen',
      'settings_app': 'App-Einstellungen',
      'settings_map': 'Karte',
      'settings_map_title': 'Karte',
      'settings_map_loading': 'Kartendaten werden geladen',
      'settings_map_error': 'Die Kartendaten konnten nicht geladen werden.',
      'settings_map_empty': 'Es sind keine Kartendaten vorhanden.',
      'settings_map_recenter': 'Karte zentrieren',
      'settings_map_search': 'Karte durchsuchen',
      'settings_map_search_hint': 'Stamm, Bezirk oder Diözese suchen',
      'settings_map_search_close': 'Suche schließen',
      'settings_map_search_no_results': 'Keine Treffer',
      'settings_map_search_type_stamm': 'Stamm',
      'settings_map_search_type_district': 'Bezirk',
      'settings_map_search_type_diocese': 'Diözese',
      'settings_map_search_type_dv': 'DV',
      'settings_map_search_type_federal': 'Bund',
      'settings_debug_tools': 'Debug & Tools',
      'settings_hitobito_issue_title': 'Hitobito derzeit nicht erreichbar',
      'settings_hitobito_issue_body':
          'Die App zeigt weiter lokale Daten an. Tippe hier, um die Verbindung erneut zu pruefen.',
      'settings_hitobito_issue_relogin_body':
          'Die App zeigt weiter lokale Daten an. Tippe hier, um dich erneut bei Hitobito anzumelden.',
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
      'map_address_not_found': 'Adresse nicht gefunden',
      'map_technical_error': 'Technischer Fehler',
      'map_wifi_only_refresh':
          'Kartenvorschau wird nur über WLAN aktualisiert.',
      'auth_loading_title': 'Sichere Sitzung wird vorbereitet',
      'auth_loading_body':
          'Bitte warte kurz, waehrend der geschuetzte App-Zustand geladen wird.',
      'auth_login_title': 'Anmeldung erforderlich',
      'auth_login_body':
          'Melde dich mit deinem Hitobito-Zugang an, um sensible DPSG-Daten offline verfuegbar zu machen.',
      'auth_not_configured_body':
          'OAuth ist noch nicht konfiguriert. Hinterlege die Hitobito-Zugangsdaten in der .env, um den Login zu aktivieren.',
      'auth_login_action': 'Mit Hitobito anmelden',
      'auth_relogin_title': 'Erneute Anmeldung erforderlich',
      'auth_relogin_body':
          'Die lokal gespeicherten Daten sind abgelaufen. Bitte melde dich erneut an, um den Datenbestand zu entsperren.',
      'auth_relogin_action': 'Erneut anmelden',
      'auth_unlock_title': 'App entsperren',
      'auth_unlock_body':
          'Bestaetige kurz deine Identitaet, um auf die lokal gespeicherten Daten zuzugreifen.',
      'auth_unlock_action': 'Jetzt entsperren',
      'auth_status_title': 'Anmeldestatus',
      'auth_status_initializing': 'Wird vorbereitet',
      'auth_status_signed_out': 'Abgemeldet',
      'auth_status_authenticating': 'Anmeldung laeuft',
      'auth_status_signed_in': 'Angemeldet',
      'auth_status_cached_only':
          'Lokale Daten aktiv, Aktualisierung fehlgeschlagen',
      'auth_status_update_login_required':
          'Lokale Daten aktiv, Anmeldung fuer Updates erforderlich',
      'auth_status_unlock_required': 'Lokale Entsperrung erforderlich',
      'auth_status_relogin_required': 'Neuanmeldung erforderlich',
      'auth_status_error': 'Fehler',
      'auth_status_unknown_user': 'Kein Profil geladen',
      'auth_last_data_sync_title': 'Letzte Datenbestaetigung',
      'auth_last_data_sync_unknown':
          'Noch kein bestaetigter Datenstand vorhanden',
      'auth_refresh_due_title': 'Auffrischung nach 24 Stunden faellig',
      'auth_refresh_due_yes': 'Ja',
      'auth_refresh_due_no': 'Nein',
      'auth_manual_refresh_action': 'Sitzung jetzt pruefen',
      'auth_lock_timeout_label': 'App-Sperre nach Hintergrund in Sekunden',
      'debug_reset_title': 'App zurücksetzen',
      'debug_reset_action': 'Alle Daten löschen',
      'debug_reset_confirm_title': 'Alle Daten löschen?',
      'debug_reset_confirm_body':
          'Alle lokalen Daten, Einstellungen und Caches werden gelöscht. Die App wird danach in einen Erststart-ähnlichen Zustand zurückgesetzt.',
      'debug_reset_confirm_action': 'Jetzt löschen',
      'debug_reset_done':
          'Alle Daten wurden gelöscht. Bitte jetzt App beenden und neu starten.',
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
      'welcome_title': 'Welcome',
      'welcome_body':
          'Welcome to the app. More guidance and options will be added later. Before the broader rollout of the map feature, an explicit Privacy Policy notice with a confirmation such as "I agree to the Privacy Policy" will be added here.',
      'welcome_action': 'Continue',
      'version': 'Version',
      'notifications_enable': 'Notifications enabled',
      'analytics_enable': 'Allow analytics/telemetry',
      'app_lock_enable': 'Enable app lock',
      'app_lock_enable_hint':
          'Requires device authentication after returning from the background.',
      'member_search_result_highlight_enable':
          'Highlight matching search results in subtitle',
      'member_search_result_highlight_hint':
          'Shows the matching field during search instead of the default subtitle.',
      'display': 'Display',
      'theme': 'Theme',
      'theme_light': 'Light',
      'theme_dark': 'Dark',
      'theme_system': 'Automatic',
      'language': 'Language',
      'language_de': 'German',
      'language_en': 'English (Beta)',
      'profile': 'Profile',
      'profile_loading': 'Loading profile',
      'profile_last_sync_title': 'Profile last updated',
      'profile_not_loaded': 'The Hitobito profile could not be loaded yet.',
      'profile_nami_id_label': 'nami-id',
      'profile_email_label': 'Email',
      'profile_language_label': 'Language',
      'profile_context_title': 'Work context',
      'profile_context_current_layer_label': 'Active layer',
      'profile_context_switch_action': 'Switch layer',
      'profile_context_no_other_layers':
          'There are currently no other reachable layers available.',
      'profile_context_unavailable':
          'The work context is currently unavailable.',
      'profile_context_loading': 'Loading work context',
      'profile_context_sheet_title': 'Switch layer',
      'profile_context_sheet_hint':
          'Choose another reachable layer as the active work context.',
      'profile_context_current_badge': 'Currently active',
      'profile_context_switch_loading': 'Switching work context',
      'profile_roles_title': 'Roles',
      'profile_roles_empty': 'No roles available in the profile',
      'profile_permissions_label': 'Permissions',
      'members_loading': 'Loading members',
      'members_empty': 'No members available',
      'members_error': 'Members could not be loaded.',
      'members_login_required': 'Sign in to load members from Hitobito.',
      'members_sync_issue_cached':
          'Hitobito data could not be refreshed. Showing local data instead.',
      'members_sync_issue_relogin':
          'Hitobito data could not be refreshed. Please sign in again.',
      'settings_stamm': 'Troop settings',
      'settings_app': 'App settings',
      'settings_map': 'Map',
      'settings_map_title': 'Map',
      'settings_map_loading': 'Loading map data',
      'settings_map_error': 'The map data could not be loaded.',
      'settings_map_empty': 'No map data is available.',
      'settings_map_recenter': 'Recenter map',
      'settings_map_search': 'Search map',
      'settings_map_search_hint': 'Search for groups, districts or dioceses',
      'settings_map_search_close': 'Close search',
      'settings_map_search_no_results': 'No results',
      'settings_map_search_type_stamm': 'Group',
      'settings_map_search_type_district': 'District',
      'settings_map_search_type_diocese': 'Diocese',
      'settings_map_search_type_dv': 'Diocesan association',
      'settings_map_search_type_federal': 'Federal',
      'settings_debug_tools': 'Debug & Tools',
      'settings_hitobito_issue_title': 'Hitobito currently unavailable',
      'settings_hitobito_issue_body':
          'The app continues to show local data. Tap here to try the connection again.',
      'settings_hitobito_issue_relogin_body':
          'The app continues to show local data. Tap here to sign in to Hitobito again.',
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
      'map_address_not_found': 'Address not found',
      'map_technical_error': 'Technical error',
      'map_wifi_only_refresh': 'Map preview is only refreshed over Wi-Fi.',
      'auth_loading_title': 'Preparing secure session',
      'auth_loading_body':
          'Please wait while the protected app state is being loaded.',
      'auth_login_title': 'Sign-in required',
      'auth_login_body':
          'Sign in with your Hitobito account to make sensitive DPSG data available offline.',
      'auth_not_configured_body':
          'OAuth is not configured yet. Add the Hitobito credentials to the .env file to enable sign-in.',
      'auth_login_action': 'Sign in with Hitobito',
      'auth_relogin_title': 'Sign-in required again',
      'auth_relogin_body':
          'The locally stored data has expired. Please sign in again to unlock the data set.',
      'auth_relogin_action': 'Sign in again',
      'auth_unlock_title': 'Unlock app',
      'auth_unlock_body':
          'Confirm your identity to access the locally stored data.',
      'auth_unlock_action': 'Unlock now',
      'auth_status_title': 'Sign-in status',
      'auth_status_initializing': 'Preparing',
      'auth_status_signed_out': 'Signed out',
      'auth_status_authenticating': 'Signing in',
      'auth_status_signed_in': 'Signed in',
      'auth_status_cached_only': 'Local data active, refresh failed',
      'auth_status_update_login_required':
          'Local data active, sign-in required for updates',
      'auth_status_unlock_required': 'Local unlock required',
      'auth_status_relogin_required': 'Sign-in required again',
      'auth_status_error': 'Error',
      'auth_status_unknown_user': 'No profile loaded',
      'auth_last_data_sync_title': 'Last data verification',
      'auth_last_data_sync_unknown': 'No verified data set available yet',
      'auth_refresh_due_title': '24h refresh due',
      'auth_refresh_due_yes': 'Yes',
      'auth_refresh_due_no': 'No',
      'auth_manual_refresh_action': 'Check session now',
      'auth_lock_timeout_label': 'App lock after background in seconds',
      'debug_reset_title': 'Reset app',
      'debug_reset_action': 'Delete all data',
      'debug_reset_confirm_title': 'Delete all data?',
      'debug_reset_confirm_body':
          'All local data, settings, and caches will be deleted. The app will then return to a first-start-like state.',
      'debug_reset_confirm_action': 'Delete now',
      'debug_reset_done':
          'All data was deleted. Please close and restart the app now.',
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

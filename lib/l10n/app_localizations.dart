import 'package:flutter/foundation.dart';
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
      'snackbar_success_title': 'Erfolg',
      'snackbar_warning_title': 'Hinweis',
      'snackbar_error_title': 'Fehler',
      'snackbar_info_title': 'Info',
      'snackbar_help_title': 'Hilfe',
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
      'member_list_no_results': 'Keine Mitglieder gefunden',
      'member_list_count': 'Mitglieder: {count}',
      'member_list_reset_filters': 'Filter zurücksetzen',
      'member_list_search_hint': 'Suche nach Name, Mail oder ID',
      'member_filter_open_tooltip': 'Filtern und sortieren',
      'member_filter_sheet_title': 'Filtern & Sortieren',
      'member_filter_sort_label': 'Sortiere nach',
      'member_filter_subtitle_label': 'Zusatztext',
      'member_filter_custom_groups_title': 'Filtergruppen',
      'member_filter_custom_groups_empty':
          'Es sind noch keine Filtergruppen vorhanden.',
      'member_filter_edit': 'Filtergruppe bearbeiten',
      'member_filter_delete': 'Filtergruppe löschen',
      'member_filter_create': 'Filtergruppe erstellen',
      'member_filter_sort_age': 'Alter',
      'member_filter_sort_group': 'Stufe',
      'member_filter_sort_name': 'Name',
      'member_filter_sort_vorname': 'Vorname',
      'member_filter_sort_member_time': 'Mitgliedsdauer',
      'member_filter_subtitle_member_id': 'Mitgliedsnummer',
      'member_filter_subtitle_birthday': 'Geburtstag',
      'member_filter_subtitle_nickname': 'Fahrtenname',
      'member_filter_subtitle_joined': 'Eintrittsdatum',
      'member_filter_logic_label': 'Verknüpfung',
      'member_filter_logic_and': 'UND',
      'member_filter_logic_or': 'ODER',
      'member_filter_rules_count': 'Regeln',
      'member_filter_name_label': 'Name',
      'member_filter_icon_label': 'Icon',
      'member_filter_icon_none': 'Kein Icon',
      'member_filter_rules_title': 'Regeln',
      'member_filter_rule_operator_label': 'Operator',
      'member_filter_rule_value_label': 'Bedingung',
      'member_filter_rule_group_label': 'Gruppe',
      'member_filter_rule_role_label': 'Rolle',
      'member_filter_rule_remove': 'Regel entfernen',
      'member_filter_rule_add': 'Regel hinzufügen',
      'member_filter_operator_has': 'Hat',
      'member_filter_operator_has_not': 'Hat nicht',
      'member_filter_all_roles': 'Alle Rollen',
      'member_filter_role_not_applicable': 'Nicht erforderlich',
      'member_filter_criterion_no_stage': 'Keine Stufe',
      'member_filter_criterion_stage': 'Stufe',
      'member_filter_role_unknown': 'Rolle unbekannt',
      'member_filter_group_unknown': 'Gruppe unbekannt',
      'member_filter_icon_groups': 'Gruppen',
      'member_filter_icon_diversity_1': 'Diversität',
      'member_filter_icon_group': 'Gruppe',
      'member_filter_icon_person': 'Person',
      'member_filter_icon_manage_accounts': 'Leitung',
      'member_filter_icon_star': 'Stern',
      'member_filter_icon_handyman': 'Werkzeug',
      'member_filter_icon_sos': 'Hilfe',
      'member_filter_icon_school': 'Schule',
      'member_filter_icon_home': 'Heim',
      'settings_stamm': 'Stammeseinstellungen',
      'settings_app': 'App-Einstellungen',
      'no_mobile_data_title': 'Keine Mobilen Daten',
      'no_mobile_data_hint':
          'Blockiert Netzwerkzugriffe ueber mobile Daten. Online-Funktionen laufen dann nur ueber WLAN.',
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
      'map_device_offline': 'Gerät offline',
      'map_mobile_data_blocked':
          'Keine Mobilen Daten ist aktiviert. Karte nur über WLAN verfügbar.',
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
      'common_remove': 'Entfernen',
      'common_copy': 'Kopieren',
      'common_retry': 'Erneut versuchen',
      'settings_version_details':
          '{versionLabel} {currentVersion} → {latestVersion}',
      'settings_member_resolution_title':
          'Mitglieds-Änderungen brauchen Aufmerksamkeit',
      'settings_member_resolution_body':
          'Es gibt {count} offene Problemfälle bei gespeicherten Mitglieds-Änderungen. Tippe hier, um den ersten Fall zu bearbeiten.',
      'settings_member_resolution_notice':
          'Bitte prüfe die betroffenen Felder und sende die Änderung danach erneut.',
      'member_detail_updated_success': 'Person erfolgreich aktualisiert.',
      'member_detail_resolution_required_notice':
          'Für diese Person ist eine Problemlösung nötig, bevor die Änderung gesendet werden kann.',
      'member_detail_session_missing':
          'Aktuell ist keine gültige Sitzung zum Bearbeiten verfügbar.',
      'member_detail_reload_failed':
          'Die Person konnte nicht neu geladen werden. Bitte erneut versuchen.',
      'member_detail_edit_tooltip': 'Person bearbeiten',
      'member_detail_pending_resolution_banner':
          'Für diese Person gibt es offene Problemfälle. Bitte prüfe die betroffenen Felder und sende die Änderung danach erneut.',
      'member_detail_pending_retry_banner':
          'Für diese Person liegt eine ausstehende Änderung vor. Ein Retry ist in den Debug-Tools möglich.',
      'member_detail_resolve_action': 'Problem lösen',
      'member_edit_title_resolution': 'Problemlösung Mitglied',
      'member_edit_title_edit': 'Person bearbeiten',
      'member_edit_section_general': 'Allgemein',
      'member_edit_section_email': 'E-Mail',
      'member_edit_section_phone': 'Telefon',
      'member_edit_section_address': 'Adresse',
      'member_edit_saving': 'Speichert...',
      'member_edit_resolution_title': 'Offene Probleme',
      'member_edit_resolution_intro':
          'Nur die betroffenen Felder werden gezeigt. Du kannst den Serverstand übernehmen, lokale Änderungen behalten oder die Werte direkt im Formular anpassen.',
      'member_edit_resolution_empty':
          'Alle aktuell sichtbaren Problemfälle wurden für diesen Durchgang bearbeitet.',
      'member_edit_resolution_local': 'Lokal: {value}',
      'member_edit_resolution_remote': 'Hitobito: {value}',
      'member_edit_resolution_current': 'Aktueller Wert: {value}',
      'member_edit_resolution_previous': 'Vorheriger Stand: {value}',
      'member_edit_resolution_keep_local': 'Lokal behalten',
      'member_edit_resolution_use_server': 'Serverstand verwenden',
      'member_edit_resolution_discard_local': 'Lokale Änderung verwerfen',
      'member_edit_field_first_name': 'Vorname',
      'member_edit_field_last_name': 'Nachname',
      'member_edit_field_nickname': 'Fahrtenname',
      'member_edit_field_gender': 'Geschlecht',
      'member_edit_gender_female': 'Weiblich',
      'member_edit_gender_male': 'Männlich',
      'member_edit_gender_unknown': 'Unbekannt',
      'member_edit_field_birthday': 'Geburtsdatum',
      'member_edit_field_primary_email': 'Primäre E-Mail',
      'member_edit_field_phone': 'Telefon',
      'member_edit_field_additional_email': 'Zusätzliche E-Mail',
      'member_edit_field_primary_address': 'Primäre Adresse',
      'member_edit_field_additional_address': 'Zusatzadresse',
      'member_edit_name_required':
          'Mindestens Vorname, Nachname oder Fahrtenname angeben.',
      'member_edit_add_email': 'E-Mail hinzufügen',
      'member_edit_add_phone': 'Telefon hinzufügen',
      'member_edit_add_address': 'Adresse hinzufügen',
      'member_edit_phone_empty': 'Noch keine Telefonnummer hinterlegt.',
      'member_edit_field_label': 'Bezeichnung',
      'member_edit_field_prefix': 'Vorwahl',
      'member_edit_field_phone_number': 'Telefonnummer',
      'member_edit_field_phone_with_country': 'Telefon mit +XX',
      'member_edit_field_care_of': 'c/o',
      'member_edit_field_street': 'Straße',
      'member_edit_field_house_number': 'Hausnr.',
      'member_edit_field_postbox': 'Postfach',
      'member_edit_field_zip_code': 'PLZ',
      'member_edit_field_town': 'Ort',
      'member_edit_field_country': 'Land',
      'member_edit_select_hint': 'Auswählen',
      'member_edit_value_not_set': 'Nicht gesetzt',
      'member_edit_value_not_available': 'Nicht verfügbar',
      'member_edit_value_not_present': 'Nicht vorhanden',
      'member_edit_required_field': '{field} darf nicht leer sein.',
      'member_edit_session_missing':
          'Aktuell ist keine gültige Sitzung zum Speichern verfügbar.',
      'member_edit_save_failed': 'Speichern fehlgeschlagen.',
      'member_edit_birthdate_future':
          'Geburtsdatum darf nicht in der Zukunft liegen.',
      'member_edit_birthdate_past':
          'Geburtsdatum ist zu weit in der Vergangenheit.',
      'member_edit_email_required': 'E-Mail darf nicht leer sein.',
      'member_edit_email_invalid':
          'Bitte eine gültige E-Mail-Adresse eingeben.',
      'member_edit_additional_address_empty':
          'Leere Zusatzadresse bitte entfernen oder ausfüllen.',
      'member_edit_prepare_local_pending':
          'Lokaler Bearbeitungsstand fortgesetzt. Netzabgleich erfolgt später erneut.',
      'member_edit_invalid_person_id':
          'Die Person kann ohne gültige Person-ID nicht bearbeitet werden.',
      'member_edit_prepare_auth_required':
          'Die Bearbeitung erfolgt mit lokal gespeicherten Daten. Für das Senden ist eine erneute Anmeldung erforderlich. {details}',
      'member_edit_prepare_network_blocked':
          'Bearbeitung erfolgt mit lokal gespeicherten Daten. {details}',
      'member_edit_prepare_failed':
          'Die Person konnte nicht neu geladen werden. Bitte erneut versuchen.',
      'member_edit_submit_auth_required':
          'Die Änderung wurde lokal gespeichert. Für das Senden ist eine erneute Anmeldung erforderlich. {details}',
      'member_edit_submit_network_blocked':
          'Die Änderung wurde lokal gespeichert. {details}',
      'member_edit_submit_queued':
          'Die Änderung konnte nicht direkt gesendet werden und wurde für einen späteren Retry gespeichert.',
      'member_edit_retry_failed':
          'Retry fehlgeschlagen. Der Eintrag bleibt in der Queue.',
      'notifications_refresh': 'Aktualisieren',
      'notifications_reset_read': 'Gelesen zurücksetzen',
      'notifications_reset_done': 'Mitteilungsstatus zurückgesetzt',
      'notifications_empty': 'Keine Mitteilungen',
      'notifications_error': 'Fehler: {message}',
      'member_address_open_maps_failed': 'Kann Adresse nicht in Karten öffnen',
      'member_info_default_phone': 'Telefonnummer',
      'member_info_default_email': 'E-Mail',
      'member_info_birthday': 'Geburtstag',
      'member_info_nickname': 'Fahrtenname',
      'member_info_link_open_failed': 'Kann Link nicht öffnen',
      'member_info_member_number': 'Mitgliedsnummer',
      'member_info_join_date': 'Eintrittsdatum',
      'member_info_updated_at': 'Zuletzt aktualisiert',
      'member_info_status': 'Status',
      'member_info_status_ended': 'Beendet',
      'member_info_status_active': 'Aktiv',
      'member_info_end_membership': 'Mitgliedschaft beenden',
      'member_roles_future': 'Zukünftig',
      'member_roles_active': 'Aktiv',
      'member_roles_completed': 'Abgeschlossen',
      'member_roles_stage_change_at': 'Stufenwechsel am {date}',
      'member_roles_switch': 'Wechseln',
      'stufenwechsel_age_format': '{years}J {months}M',
      'stufenwechsel_no_change': 'Kein Wechsel der {stages} zum {date}',
      'stufenwechsel_column_stage': 'Stufe',
      'stufenwechsel_column_name': 'Name',
      'stufenwechsel_column_age': 'Alter',
      'stufenwechsel_column_change': 'Wechsel',
      'nav_auth_preparing_title': 'Anmeldung wird vorbereitet',
      'nav_auth_preparing_body':
          'Die App initialisiert die Anmeldung. Einstellungen bleiben bereits erreichbar.',
      'nav_work_context_loading_title': 'Arbeitskontext wird geladen',
      'nav_work_context_loading_body':
          'Der aktive Arbeitskontext wird initialisiert. Danach stehen die kontextgebundenen Funktionen zur Verfügung.',
      'nav_work_context_unauthorized_body':
          'Melde dich mit einem Konto an, das mindestens ein relevantes Layer- oder Gruppenrecht besitzt.',
      'nav_work_context_error_title':
          'Arbeitskontext konnte nicht initialisiert werden',
      'nav_work_context_error_body':
          'Der App-Start konnte keinen gültigen Arbeitskontext herstellen. Die Einstellungen bleiben erreichbar.',
      'debug_title': 'Debug & Tools',
      'debug_logs_section_title': 'Logs & Diagnose',
      'debug_logs_section_subtitle':
          'Logdateien auswählen, prüfen, versenden oder gesammelt löschen.',
      'debug_logs_selection': 'Log-Auswahl',
      'debug_logs_available_count': '{count} Datei{suffix} verfügbar',
      'debug_logs_empty': 'Aktuell sind keine Logdateien vorhanden.',
      'debug_logs_all_files': 'Alle Dateien',
      'debug_logs_send_all': 'Logs per Mail senden',
      'debug_logs_send_selected': 'Gewähltes Log per Mail senden',
      'debug_logs_view_all': 'Logs anzeigen',
      'debug_logs_view_selected': 'Gewähltes Log anzeigen',
      'debug_logs_viewer_title_all': 'Alle Logs anzeigen',
      'debug_logs_viewer_title_selected': '{selection} anzeigen',
      'debug_logs_delete': 'Logs löschen',
      'debug_logs_deleted': 'Alle Logdateien gelöscht',
      'debug_logs_email_body':
          'Beschreibe dein Problem. Wie hat sich die App verhalten, was ist passiert? Was hättest du erwartet?',
      'debug_logs_email_subject': 'NaMi App Logs',
      'debug_pending_section_title': 'Ausstehende Personenänderungen',
      'debug_pending_section_subtitle':
          'Pending-Änderungen prüfen und bei Bedarf manuell erneut senden.',
      'debug_pending_unavailable':
          'Pending-Änderungen sind in diesem Kontext nicht verfügbar.',
      'debug_pending_empty':
          'Aktuell sind keine ausstehenden Änderungen gespeichert.',
      'debug_pending_retry_all': 'Alle erneut senden',
      'debug_pending_entry_summary':
          'Mitgliedsnr. {memberNumber}\nVorgemerkt: {queuedAt}\nVersuche: {attemptCount}',
      'debug_pending_retry_single': 'Eintrag erneut senden',
      'debug_feedback_section_title': 'Feedback & Bewertung',
      'debug_feedback_section_subtitle':
          'Öffnet direkt die bestehenden Wiredash-Abläufe für Rückmeldungen und Bewertung.',
      'debug_feedback_send': 'Feedback senden',
      'debug_feedback_rate': 'App bewerten',
      'debug_feedback_missing_root':
          'Wiredash konnte nicht gefunden werden (Root-Kontext fehlt).',
      'debug_sync_section_title': 'Daten & Synchronisation',
      'debug_sync_section_subtitle':
          'Manuelle Aktualisierung und technische Sicht auf Datenänderungen.',
      'debug_sync_now': 'Daten jetzt aktualisieren',
      'debug_sync_view_changes': 'Datenänderungen anzeigen',
      'debug_sync_changes_not_implemented':
          'Nicht implementiert: Datenänderungen angezeigt',
      'debug_sync_network_blocked':
          'Hitobito ist aktuell nur über WLAN erreichbar.',
      'debug_sync_relogin_required':
          'Neuanmeldung erforderlich, Daten konnten nicht synchronisiert werden.',
      'debug_sync_partial_failure':
          'Hitobito-Daten konnten nicht vollständig synchronisiert werden.',
      'debug_sync_success': 'Hitobito-Daten wurden synchronisiert.',
      'debug_map_section_title': 'Karten & Cache',
      'debug_map_section_subtitle':
          'Status des Karten-Caches und manuelle Aktualisierung der Stammesuche.',
      'debug_map_size_unavailable': 'Größe derzeit nicht verfügbar',
      'debug_map_size_loading': 'Größe wird geladen ...',
      'debug_map_offline_maps': 'Offline-Karten',
      'debug_map_refresh_markers_loading': 'Stammesuche wird aktualisiert ...',
      'debug_map_refresh_markers': 'Stammesuche jetzt laden',
      'debug_map_delete_cache': 'Kartendaten löschen',
      'debug_map_refresh_success':
          'Stammesuche aktualisiert: {count} Marker geladen.',
      'debug_map_refresh_failed':
          'Stammesuche konnte nicht aktualisiert werden.',
      'debug_map_deleted': 'Kartendaten gelöscht',
      'debug_map_size_empty': 'Noch keine Offline-Kartendaten gespeichert',
      'debug_map_size_kib': '{size} KB gespeichert',
      'debug_map_size_mib': '{size} MB gespeichert',
      'debug_map_size_gib': '{size} GB gespeichert',
      'debug_retry_missing_token':
          'Kein gültiger Access Token für den Retry verfügbar.',
      'debug_retry_summary':
          'Retry abgeschlossen: {successCount} erfolgreich, {discardedCount} verworfen, {retainedCount} behalten.',
      'debug_oauth_section_title': 'Hitobito OAuth',
      'debug_oauth_section_subtitle':
          'Aktuelle OAuth-Quelle prüfen und temporäre Zugangsdaten testen.',
      'debug_oauth_override_active':
          'Aktiver Override für Client ID {clientId}',
      'debug_oauth_env_active':
          'Aktuell werden die Hitobito OAuth-Werte aus der lokalen Env genutzt.',
      'debug_oauth_check': 'OAuth-Zugangsdaten prüfen',
      'debug_references_section_title': 'Referenzen',
      'debug_references_section_subtitle':
          'Schneller Zugriff auf Changelog und eingehende Mitteilungen.',
      'debug_references_show_changelog': 'Changelog anzeigen',
      'debug_references_show_notifications': 'Mitteilungen anzeigen',
      'debug_reset_subtitle':
          'Diese Aktionen greifen stark ein. Die Darstellung ist bewusst auffälliger, das Verhalten bleibt unverändert.',
      'debug_oauth_dialog_title': 'Hitobito OAuth prüfen',
      'debug_oauth_client_id': 'Client ID',
      'debug_oauth_client_id_required': 'Client ID ist erforderlich',
      'debug_oauth_client_secret': 'Client Secret',
      'debug_oauth_client_secret_required': 'Client Secret ist erforderlich',
      'debug_oauth_cancel': 'Abbrechen',
      'debug_oauth_submit': 'Prüfen',
    },
    'en': {
      'nav_my_stage': 'My Group',
      'nav_members': 'Members',
      'nav_statistics': 'Statistics',
      'nav_settings': 'Settings',
      'snackbar_success_title': 'Success',
      'snackbar_warning_title': 'Notice',
      'snackbar_error_title': 'Error',
      'snackbar_info_title': 'Info',
      'snackbar_help_title': 'Help',
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
      'member_list_no_results': 'No members found',
      'member_list_count': 'Members: {count}',
      'member_list_reset_filters': 'Reset filters',
      'member_list_search_hint': 'Search by name, mail or ID',
      'member_filter_open_tooltip': 'Filter and sort',
      'member_filter_sheet_title': 'Filter & Sort',
      'member_filter_sort_label': 'Sort by',
      'member_filter_subtitle_label': 'Additional text',
      'member_filter_custom_groups_title': 'Filter groups',
      'member_filter_custom_groups_empty': 'There are no filter groups yet.',
      'member_filter_edit': 'Edit filter group',
      'member_filter_delete': 'Delete filter group',
      'member_filter_create': 'Create filter group',
      'member_filter_sort_age': 'Age',
      'member_filter_sort_group': 'Stage',
      'member_filter_sort_name': 'Last name',
      'member_filter_sort_vorname': 'First name',
      'member_filter_sort_member_time': 'Membership duration',
      'member_filter_subtitle_member_id': 'Member ID',
      'member_filter_subtitle_birthday': 'Birthday',
      'member_filter_subtitle_nickname': 'Nickname',
      'member_filter_subtitle_joined': 'Join date',
      'member_filter_logic_label': 'Combination',
      'member_filter_logic_and': 'AND',
      'member_filter_logic_or': 'OR',
      'member_filter_rules_count': 'rules',
      'member_filter_name_label': 'Name',
      'member_filter_icon_label': 'Icon',
      'member_filter_icon_none': 'No icon',
      'member_filter_rules_title': 'Rules',
      'member_filter_rule_operator_label': 'Operator',
      'member_filter_rule_value_label': 'Condition',
      'member_filter_rule_group_label': 'Group',
      'member_filter_rule_role_label': 'Role',
      'member_filter_rule_remove': 'Remove rule',
      'member_filter_rule_add': 'Add rule',
      'member_filter_operator_has': 'Has',
      'member_filter_operator_has_not': 'Has not',
      'member_filter_all_roles': 'All roles',
      'member_filter_role_not_applicable': 'Not required',
      'member_filter_criterion_no_stage': 'No stage',
      'member_filter_criterion_stage': 'Stage',
      'member_filter_role_unknown': 'Unknown role',
      'member_filter_group_unknown': 'Unknown group',
      'member_filter_icon_groups': 'Groups',
      'member_filter_icon_diversity_1': 'Diversity',
      'member_filter_icon_group': 'Group',
      'member_filter_icon_person': 'Person',
      'member_filter_icon_manage_accounts': 'Management',
      'member_filter_icon_star': 'Star',
      'member_filter_icon_handyman': 'Tools',
      'member_filter_icon_sos': 'SOS',
      'member_filter_icon_school': 'School',
      'member_filter_icon_home': 'Home',
      'settings_stamm': 'Troop settings',
      'settings_app': 'App settings',
      'no_mobile_data_title': 'No mobile data',
      'no_mobile_data_hint':
          'Blocks network access over mobile data. Online features then only work over Wi-Fi.',
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
      'map_device_offline': 'Device offline',
      'map_mobile_data_blocked':
          'No mobile data is enabled. Map is only available over Wi-Fi.',
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
      'common_remove': 'Remove',
      'common_copy': 'Copy',
      'common_retry': 'Retry',
      'settings_version_details':
          '{versionLabel} {currentVersion} → {latestVersion}',
      'settings_member_resolution_title': 'Member changes need attention',
      'settings_member_resolution_body':
          'There are {count} open issue cases for stored member changes. Tap here to resolve the first one.',
      'settings_member_resolution_notice':
          'Please review the affected fields and send the change again afterwards.',
      'member_detail_updated_success': 'Person updated successfully.',
      'member_detail_resolution_required_notice':
          'This person requires conflict resolution before the change can be sent.',
      'member_detail_session_missing':
          'There is currently no valid session available for editing.',
      'member_detail_reload_failed':
          'The person could not be reloaded. Please try again.',
      'member_detail_edit_tooltip': 'Edit person',
      'member_detail_pending_resolution_banner':
          'There are open issue cases for this person. Please review the affected fields and send the change again afterwards.',
      'member_detail_pending_retry_banner':
          'There is a pending change for this person. A retry is available in Debug & Tools.',
      'member_detail_resolve_action': 'Resolve issue',
      'member_edit_title_resolution': 'Resolve member issue',
      'member_edit_title_edit': 'Edit person',
      'member_edit_section_general': 'General',
      'member_edit_section_email': 'Email',
      'member_edit_section_phone': 'Phone',
      'member_edit_section_address': 'Address',
      'member_edit_saving': 'Saving...',
      'member_edit_resolution_title': 'Open issues',
      'member_edit_resolution_intro':
          'Only the affected fields are shown. You can apply the server value, keep local changes, or edit the values directly in the form.',
      'member_edit_resolution_empty':
          'All currently visible issue cases have been handled for this pass.',
      'member_edit_resolution_local': 'Local: {value}',
      'member_edit_resolution_remote': 'Hitobito: {value}',
      'member_edit_resolution_current': 'Current value: {value}',
      'member_edit_resolution_previous': 'Previous value: {value}',
      'member_edit_resolution_keep_local': 'Keep local',
      'member_edit_resolution_use_server': 'Use server value',
      'member_edit_resolution_discard_local': 'Discard local change',
      'member_edit_field_first_name': 'First name',
      'member_edit_field_last_name': 'Last name',
      'member_edit_field_nickname': 'Nickname',
      'member_edit_field_gender': 'Gender',
      'member_edit_gender_female': 'Female',
      'member_edit_gender_male': 'Male',
      'member_edit_gender_unknown': 'Unknown',
      'member_edit_field_birthday': 'Birthday',
      'member_edit_field_primary_email': 'Primary email',
      'member_edit_field_phone': 'Phone',
      'member_edit_field_additional_email': 'Additional email',
      'member_edit_field_primary_address': 'Primary address',
      'member_edit_field_additional_address': 'Additional address',
      'member_edit_name_required':
          'Enter at least a first name, last name, or nickname.',
      'member_edit_add_email': 'Add email',
      'member_edit_add_phone': 'Add phone',
      'member_edit_add_address': 'Add address',
      'member_edit_phone_empty': 'No phone number stored yet.',
      'member_edit_field_label': 'Label',
      'member_edit_field_prefix': 'Prefix',
      'member_edit_field_phone_number': 'Phone number',
      'member_edit_field_phone_with_country': 'Phone with +XX',
      'member_edit_field_care_of': 'c/o',
      'member_edit_field_street': 'Street',
      'member_edit_field_house_number': 'House no.',
      'member_edit_field_postbox': 'PO box',
      'member_edit_field_zip_code': 'ZIP code',
      'member_edit_field_town': 'Town',
      'member_edit_field_country': 'Country',
      'member_edit_select_hint': 'Select',
      'member_edit_value_not_set': 'Not set',
      'member_edit_value_not_available': 'Not available',
      'member_edit_value_not_present': 'Not present',
      'member_edit_required_field': '{field} must not be empty.',
      'member_edit_session_missing':
          'There is currently no valid session available for saving.',
      'member_edit_save_failed': 'Saving failed.',
      'member_edit_birthdate_future': 'Birthday must not be in the future.',
      'member_edit_birthdate_past': 'Birthday is too far in the past.',
      'member_edit_email_required': 'Email must not be empty.',
      'member_edit_email_invalid': 'Please enter a valid email address.',
      'member_edit_additional_address_empty':
          'Please remove or complete the empty additional address.',
      'member_edit_prepare_local_pending':
          'Resumed local editing state. Network sync will be retried later.',
      'member_edit_invalid_person_id':
          'The person cannot be edited without a valid person ID.',
      'member_edit_prepare_auth_required':
          'Editing continues with locally stored data. Signing in again is required for sending. {details}',
      'member_edit_prepare_network_blocked':
          'Editing continues with locally stored data. {details}',
      'member_edit_prepare_failed':
          'The person could not be reloaded. Please try again.',
      'member_edit_submit_auth_required':
          'The change was stored locally. Signing in again is required for sending. {details}',
      'member_edit_submit_network_blocked':
          'The change was stored locally. {details}',
      'member_edit_submit_queued':
          'The change could not be sent directly and was stored for a later retry.',
      'member_edit_retry_failed':
          'Retry failed. The entry remains in the queue.',
      'notifications_refresh': 'Refresh',
      'notifications_reset_read': 'Reset read status',
      'notifications_reset_done': 'Notification status reset',
      'notifications_empty': 'No announcements',
      'notifications_error': 'Error: {message}',
      'member_address_open_maps_failed': 'Cannot open address in maps',
      'member_info_default_phone': 'Phone number',
      'member_info_default_email': 'Email',
      'member_info_birthday': 'Birthday',
      'member_info_nickname': 'Nickname',
      'member_info_link_open_failed': 'Cannot open link',
      'member_info_member_number': 'Member number',
      'member_info_join_date': 'Join date',
      'member_info_updated_at': 'Last updated',
      'member_info_status': 'Status',
      'member_info_status_ended': 'Ended',
      'member_info_status_active': 'Active',
      'member_info_end_membership': 'End membership',
      'member_roles_future': 'Upcoming',
      'member_roles_active': 'Active',
      'member_roles_completed': 'Completed',
      'member_roles_stage_change_at': 'Stage change on {date}',
      'member_roles_switch': 'Switch',
      'stufenwechsel_age_format': '{years}y {months}m',
      'stufenwechsel_no_change': 'No change of {stages} on {date}',
      'stufenwechsel_column_stage': 'Stage',
      'stufenwechsel_column_name': 'Name',
      'stufenwechsel_column_age': 'Age',
      'stufenwechsel_column_change': 'Change',
      'nav_auth_preparing_title': 'Preparing sign-in',
      'nav_auth_preparing_body':
          'The app is initializing sign-in. Settings are already available.',
      'nav_work_context_loading_title': 'Loading work context',
      'nav_work_context_loading_body':
          'The active work context is being initialized. Context-bound features will then become available.',
      'nav_work_context_unauthorized_body':
          'Sign in with an account that has at least one relevant layer or group permission.',
      'nav_work_context_error_title': 'Work context could not be initialized',
      'nav_work_context_error_body':
          'App startup could not establish a valid work context. Settings remain available.',
      'debug_title': 'Debug & Tools',
      'debug_logs_section_title': 'Logs & Diagnostics',
      'debug_logs_section_subtitle':
          'Select, inspect, send, or delete log files in bulk.',
      'debug_logs_selection': 'Log selection',
      'debug_logs_available_count': '{count} file{suffix} available',
      'debug_logs_empty': 'There are currently no log files available.',
      'debug_logs_all_files': 'All files',
      'debug_logs_send_all': 'Send logs by email',
      'debug_logs_send_selected': 'Send selected log by email',
      'debug_logs_view_all': 'View logs',
      'debug_logs_view_selected': 'View selected log',
      'debug_logs_viewer_title_all': 'View all logs',
      'debug_logs_viewer_title_selected': 'View {selection}',
      'debug_logs_delete': 'Delete logs',
      'debug_logs_deleted': 'All log files deleted',
      'debug_logs_email_body':
          'Describe your issue. How did the app behave, what happened, and what did you expect?',
      'debug_logs_email_subject': 'NaMi App Logs',
      'debug_pending_section_title': 'Pending person changes',
      'debug_pending_section_subtitle':
          'Review pending changes and resend them manually if needed.',
      'debug_pending_unavailable':
          'Pending changes are not available in this context.',
      'debug_pending_empty': 'There are currently no pending changes stored.',
      'debug_pending_retry_all': 'Resend all',
      'debug_pending_entry_summary':
          'Member no. {memberNumber}\nQueued: {queuedAt}\nAttempts: {attemptCount}',
      'debug_pending_retry_single': 'Resend entry',
      'debug_feedback_section_title': 'Feedback & Rating',
      'debug_feedback_section_subtitle':
          'Opens the existing Wiredash flows for feedback and rating.',
      'debug_feedback_send': 'Send feedback',
      'debug_feedback_rate': 'Rate app',
      'debug_feedback_missing_root':
          'Wiredash could not be found (missing root context).',
      'debug_sync_section_title': 'Data & Sync',
      'debug_sync_section_subtitle':
          'Manual refresh and a technical view of data changes.',
      'debug_sync_now': 'Refresh data now',
      'debug_sync_view_changes': 'View data changes',
      'debug_sync_changes_not_implemented':
          'Not implemented: data changes displayed',
      'debug_sync_network_blocked':
          'Hitobito is currently only reachable via Wi-Fi.',
      'debug_sync_relogin_required':
          'Sign-in required again, data could not be synchronized.',
      'debug_sync_partial_failure':
          'Hitobito data could not be fully synchronized.',
      'debug_sync_success': 'Hitobito data synchronized.',
      'debug_map_section_title': 'Maps & Cache',
      'debug_map_section_subtitle':
          'Status of the map cache and manual refresh of group search.',
      'debug_map_size_unavailable': 'Size currently unavailable',
      'debug_map_size_loading': 'Loading size ...',
      'debug_map_offline_maps': 'Offline maps',
      'debug_map_refresh_markers_loading': 'Refreshing group search ...',
      'debug_map_refresh_markers': 'Load group search now',
      'debug_map_delete_cache': 'Delete map data',
      'debug_map_refresh_success':
          'Group search refreshed: {count} markers loaded.',
      'debug_map_refresh_failed': 'Group search could not be refreshed.',
      'debug_map_deleted': 'Map data deleted',
      'debug_map_size_empty': 'No offline map data stored yet',
      'debug_map_size_kib': '{size} KB stored',
      'debug_map_size_mib': '{size} MB stored',
      'debug_map_size_gib': '{size} GB stored',
      'debug_retry_missing_token': 'No valid access token available for retry.',
      'debug_retry_summary':
          'Retry finished: {successCount} successful, {discardedCount} discarded, {retainedCount} retained.',
      'debug_oauth_section_title': 'Hitobito OAuth',
      'debug_oauth_section_subtitle':
          'Inspect the current OAuth source and test temporary credentials.',
      'debug_oauth_override_active': 'Active override for client ID {clientId}',
      'debug_oauth_env_active':
          'The Hitobito OAuth values are currently taken from the local env.',
      'debug_oauth_check': 'Check OAuth credentials',
      'debug_references_section_title': 'References',
      'debug_references_section_subtitle':
          'Quick access to the changelog and incoming announcements.',
      'debug_references_show_changelog': 'Show changelog',
      'debug_references_show_notifications': 'Show announcements',
      'debug_reset_subtitle':
          'These actions are invasive. The styling is intentionally more prominent while the behavior remains unchanged.',
      'debug_oauth_dialog_title': 'Check Hitobito OAuth',
      'debug_oauth_client_id': 'Client ID',
      'debug_oauth_client_id_required': 'Client ID is required',
      'debug_oauth_client_secret': 'Client Secret',
      'debug_oauth_client_secret_required': 'Client Secret is required',
      'debug_oauth_cancel': 'Cancel',
      'debug_oauth_submit': 'Check',
    },
  };

  String t(String key, [Map<String, Object?> placeholders = const {}]) {
    final lang = locale.languageCode;
    final template =
        _localizedValues[lang]?[key] ?? _localizedValues['en']![key] ?? key;
    if (placeholders.isEmpty) {
      return template;
    }
    return template.replaceAllMapped(RegExp(r'\{(\w+)\}'), (match) {
      final placeholderKey = match.group(1)!;
      final value = placeholders[placeholderKey];
      return value?.toString() ?? match.group(0)!;
    });
  }

  String tParams(String key, Map<String, Object> params) {
    var value = t(key);
    for (final entry in params.entries) {
      value = value.replaceAll('{${entry.key}}', entry.value.toString());
    }
    return value;
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['de', 'en'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) =>
      SynchronousFuture<AppLocalizations>(AppLocalizations(locale));

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

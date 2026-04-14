import 'package:flutter/material.dart';
import 'package:nami/l10n/app_localizations.dart';
// Keine Abhängigkeit zu ignore_deprecated, reines Input/Output-Pattern

class AppSettingsPage extends StatefulWidget {
  final bool analyticsEnabled;
  final bool biometricLockEnabled;
  final bool memberListSearchResultHighlightEnabled;
  final bool noMobileDataEnabled;
  final ThemeMode themeMode;
  final String languageCode; // e.g. 'de', 'en'
  final ValueChanged<bool>? onAnalyticsChanged;
  final ValueChanged<bool>? onBiometricLockChanged;
  final ValueChanged<bool>? onNoMobileDataChanged;
  final ValueChanged<bool>? onMemberListSearchResultHighlightChanged;
  final ValueChanged<ThemeMode>? onThemeModeChanged;
  final ValueChanged<String>? onLanguageChanged;

  const AppSettingsPage({
    super.key,
    this.analyticsEnabled = false,
    this.biometricLockEnabled = false,
    this.memberListSearchResultHighlightEnabled = false,
    this.noMobileDataEnabled = false,
    this.themeMode = ThemeMode.system,
    this.languageCode = 'de',
    this.onAnalyticsChanged,
    this.onBiometricLockChanged,
    this.onNoMobileDataChanged,
    this.onMemberListSearchResultHighlightChanged,
    this.onThemeModeChanged,
    this.onLanguageChanged,
  });

  @override
  State<AppSettingsPage> createState() => _AppSettingsPageState();
}

class _AppSettingsPageState extends State<AppSettingsPage> {
  late bool _analyticsEnabled;
  late bool _biometricLockEnabled;
  late bool _memberListSearchResultHighlightEnabled;
  late bool _noMobileDataEnabled;
  late ThemeMode _currentMode;
  late String _languageCode;

  @override
  void initState() {
    super.initState();
    _analyticsEnabled = widget.analyticsEnabled;
    _biometricLockEnabled = widget.biometricLockEnabled;
    _memberListSearchResultHighlightEnabled =
        widget.memberListSearchResultHighlightEnabled;
    _noMobileDataEnabled = widget.noMobileDataEnabled;
    _currentMode = widget.themeMode;
    _languageCode = widget.languageCode;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).t('settings_app')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Text(
            AppLocalizations.of(context).t('general'),
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          // Hinweis: Notification-Einstellungen wurden in die SettingsNotificationPage ausgelagert.
          SwitchListTile(
            title: Text(AppLocalizations.of(context).t('analytics_enable')),
            value: _analyticsEnabled,
            onChanged: (v) {
              setState(() => _analyticsEnabled = v);
              widget.onAnalyticsChanged?.call(v);
            },
          ),

          SwitchListTile(
            title: Text(AppLocalizations.of(context).t('app_lock_enable')),
            subtitle: Text(
              AppLocalizations.of(context).t('app_lock_enable_hint'),
            ),
            value: _biometricLockEnabled,
            onChanged: (v) {
              setState(() => _biometricLockEnabled = v);
              widget.onBiometricLockChanged?.call(v);
            },
          ),

          SwitchListTile(
            title: Text(AppLocalizations.of(context).t('no_mobile_data_title')),
            subtitle: Text(
              AppLocalizations.of(context).t('no_mobile_data_hint'),
            ),
            value: _noMobileDataEnabled,
            onChanged: (v) {
              setState(() => _noMobileDataEnabled = v);
              widget.onNoMobileDataChanged?.call(v);
            },
          ),

          SwitchListTile(
            title: Text(
              AppLocalizations.of(
                context,
              ).t('member_search_result_highlight_enable'),
            ),
            subtitle: Text(
              AppLocalizations.of(
                context,
              ).t('member_search_result_highlight_hint'),
            ),
            value: _memberListSearchResultHighlightEnabled,
            onChanged: (v) {
              setState(() => _memberListSearchResultHighlightEnabled = v);
              widget.onMemberListSearchResultHighlightChanged?.call(v);
            },
          ),

          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context).t('display'),
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          SegmentedButton<ThemeMode>(
            segments: <ButtonSegment<ThemeMode>>[
              ButtonSegment<ThemeMode>(
                value: ThemeMode.light,
                label: Text(AppLocalizations.of(context).t('theme_light')),
                icon: const Icon(Icons.light_mode),
              ),
              ButtonSegment<ThemeMode>(
                value: ThemeMode.dark,
                label: Text(AppLocalizations.of(context).t('theme_dark')),
                icon: const Icon(Icons.dark_mode),
              ),
              ButtonSegment<ThemeMode>(
                value: ThemeMode.system,
                label: Text(AppLocalizations.of(context).t('theme_system')),
                icon: const Icon(Icons.brightness_auto),
              ),
            ],
            selected: <ThemeMode>{_currentMode},
            onSelectionChanged: (selection) {
              final mode = selection.first;
              setState(() => _currentMode = mode);
              widget.onThemeModeChanged?.call(mode);
            },
          ),

          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context).t('language'),
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _languageCode,
            decoration: const InputDecoration(border: OutlineInputBorder()),
            items: <DropdownMenuItem<String>>[
              DropdownMenuItem<String>(
                value: 'de',
                child: Text(AppLocalizations.of(context).t('language_de')),
              ),
              DropdownMenuItem<String>(
                value: 'en',
                child: Text(AppLocalizations.of(context).t('language_en')),
              ),
            ],
            onChanged: (val) {
              if (val == null) return;
              setState(() => _languageCode = val);
              widget.onLanguageChanged?.call(val);
            },
          ),
        ],
      ),
    );
  }
}

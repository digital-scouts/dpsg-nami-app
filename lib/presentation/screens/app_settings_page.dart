import 'package:flutter/material.dart';
import 'package:nami/l10n/app_localizations.dart';
// Keine Abhängigkeit zu ignore_deprecated, reines Input/Output-Pattern

class AppSettingsPage extends StatefulWidget {
  final bool notificationsEnabled;
  final bool analyticsEnabled;
  final ThemeMode themeMode;
  final String languageCode; // e.g. 'de', 'en'
  final ValueChanged<bool>? onNotificationsChanged;
  final ValueChanged<bool>? onAnalyticsChanged;
  final ValueChanged<ThemeMode>? onThemeModeChanged;
  final ValueChanged<String>? onLanguageChanged;

  const AppSettingsPage({
    super.key,
    this.notificationsEnabled = true,
    this.analyticsEnabled = false,
    this.themeMode = ThemeMode.system,
    this.languageCode = 'de',
    this.onNotificationsChanged,
    this.onAnalyticsChanged,
    this.onThemeModeChanged,
    this.onLanguageChanged,
  });

  @override
  State<AppSettingsPage> createState() => _AppSettingsPageState();
}

class _AppSettingsPageState extends State<AppSettingsPage> {
  late bool _notificationsEnabled;
  late bool _analyticsEnabled;
  late ThemeMode _currentMode;
  late String _languageCode;

  @override
  void initState() {
    super.initState();
    _notificationsEnabled = widget.notificationsEnabled;
    _analyticsEnabled = widget.analyticsEnabled;
    _currentMode = widget.themeMode;
    _languageCode = widget.languageCode;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).t('settings_title')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Text(
            AppLocalizations.of(context).t('general'),
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            title: Text(AppLocalizations.of(context).t('notifications_enable')),
            value: _notificationsEnabled,
            onChanged: (v) {
              setState(() => _notificationsEnabled = v);
              widget.onNotificationsChanged?.call(v);
            },
          ),
          SwitchListTile(
            title: Text(AppLocalizations.of(context).t('analytics_enable')),
            value: _analyticsEnabled,
            onChanged: (v) {
              setState(() => _analyticsEnabled = v);
              widget.onAnalyticsChanged?.call(v);
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

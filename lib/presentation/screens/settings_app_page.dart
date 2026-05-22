import 'package:flutter/material.dart';
import 'package:nami/l10n/app_localizations.dart';

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
  void didUpdateWidget(covariant AppSettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.analyticsEnabled != widget.analyticsEnabled) {
      _analyticsEnabled = widget.analyticsEnabled;
    }
    if (oldWidget.biometricLockEnabled != widget.biometricLockEnabled) {
      _biometricLockEnabled = widget.biometricLockEnabled;
    }
    if (oldWidget.memberListSearchResultHighlightEnabled !=
        widget.memberListSearchResultHighlightEnabled) {
      _memberListSearchResultHighlightEnabled =
          widget.memberListSearchResultHighlightEnabled;
    }
    if (oldWidget.noMobileDataEnabled != widget.noMobileDataEnabled) {
      _noMobileDataEnabled = widget.noMobileDataEnabled;
    }
    if (oldWidget.themeMode != widget.themeMode) {
      _currentMode = widget.themeMode;
    }
    if (oldWidget.languageCode != widget.languageCode) {
      _languageCode = widget.languageCode;
    }
  }

  void _setThemeMode(ThemeMode mode) {
    if (_currentMode == mode) {
      return;
    }
    setState(() => _currentMode = mode);
    widget.onThemeModeChanged?.call(mode);
  }

  void _setLanguageCode(String code) {
    if (_languageCode == code) {
      return;
    }
    setState(() => _languageCode = code);
    widget.onLanguageChanged?.call(code);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(t.t('settings_app'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
        children: [
          _AppSettingsSectionLabel(label: t.t('settings_app_section_security')),
          _AppSettingsCard(
            children: [
              _AppSettingsSwitchRow(
                title: t.t('settings_app_lock_title'),
                subtitle: t.t('settings_app_lock_hint'),
                value: _biometricLockEnabled,
                onChanged: (value) {
                  setState(() => _biometricLockEnabled = value);
                  widget.onBiometricLockChanged?.call(value);
                },
              ),
              _AppSettingsSwitchRow(
                title: t.t('settings_app_analytics_title'),
                subtitle: t.t('settings_app_analytics_hint'),
                value: _analyticsEnabled,
                onChanged: (value) {
                  setState(() => _analyticsEnabled = value);
                  widget.onAnalyticsChanged?.call(value);
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          _AppSettingsSectionLabel(label: t.t('settings_app_section_display')),
          _AppSettingsCard(
            children: [
              _AppSettingsRadioRow(
                title: t.t('settings_app_theme_system'),
                selected: _currentMode == ThemeMode.system,
                onTap: () => _setThemeMode(ThemeMode.system),
              ),
              _AppSettingsRadioRow(
                title: t.t('theme_light'),
                selected: _currentMode == ThemeMode.light,
                onTap: () => _setThemeMode(ThemeMode.light),
              ),
              _AppSettingsRadioRow(
                title: t.t('theme_dark'),
                selected: _currentMode == ThemeMode.dark,
                onTap: () => _setThemeMode(ThemeMode.dark),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _AppSettingsSectionLabel(label: t.t('language')),
          _AppSettingsCard(
            children: [
              _AppSettingsRadioRow(
                title: t.t('language_de'),
                selected: _languageCode == 'de',
                onTap: () => _setLanguageCode('de'),
              ),
              _AppSettingsRadioRow(
                title: t.t('settings_app_language_en'),
                selected: _languageCode == 'en',
                onTap: () => _setLanguageCode('en'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _AppSettingsSectionLabel(label: t.t('settings_app_section_behavior')),
          _AppSettingsCard(
            children: [
              _AppSettingsSwitchRow(
                title: t.t('settings_app_mobile_data_title'),
                subtitle: t.t('settings_app_mobile_data_hint'),
                value: _noMobileDataEnabled,
                onChanged: (value) {
                  setState(() => _noMobileDataEnabled = value);
                  widget.onNoMobileDataChanged?.call(value);
                },
              ),
              _AppSettingsSwitchRow(
                title: t.t('settings_app_highlight_title'),
                subtitle: t.t('settings_app_highlight_hint'),
                value: _memberListSearchResultHighlightEnabled,
                onChanged: (value) {
                  setState(
                    () => _memberListSearchResultHighlightEnabled = value,
                  );
                  widget.onMemberListSearchResultHighlightChanged?.call(value);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AppSettingsSectionLabel extends StatelessWidget {
  const _AppSettingsSectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 6),
      child: Text(
        label.toUpperCase(),
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _AppSettingsCard extends StatelessWidget {
  const _AppSettingsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];
    for (var index = 0; index < children.length; index++) {
      items.add(children[index]);
      if (index < children.length - 1) {
        items.add(const Divider(height: 1, indent: 16));
      }
    }

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(children: items),
    );
  }
}

class _AppSettingsSwitchRow extends StatelessWidget {
  const _AppSettingsSwitchRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return MergeSemantics(
      child: InkWell(
        onTap: () => onChanged(!value),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(subtitle, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Switch(value: value, onChanged: onChanged),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppSettingsRadioRow extends StatelessWidget {
  const _AppSettingsRadioRow({
    required this.title,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            _AppSettingsRadioDot(selected: selected),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
          ],
        ),
      ),
    );
  }
}

class _AppSettingsRadioDot extends StatelessWidget {
  const _AppSettingsRadioDot({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected
              ? theme.colorScheme.primary
              : theme.colorScheme.outline,
          width: 2,
        ),
      ),
      child: selected
          ? Center(
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
            )
          : null,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../l10n/app_localizations.dart';

/// Optionen und Rueckmeldungen fuer den Willkommen-Stepper nach dem ersten
/// Login. Der Stepper selbst speichert nichts.
class WillkommenOptionen {
  const WillkommenOptionen({
    required this.biometrieVerfuegbar,
    required this.biometrieAktiv,
    required this.analyseAktiv,
    required this.keineMobilenDaten,
    required this.onBiometrieAendern,
    required this.onAnalyseAendern,
    required this.onKeineMobilenDatenAendern,
    required this.onRechtliches,
  });

  /// Ohne Biometrie auf dem Geraet entfaellt der Schritt „App schuetzen“.
  final bool biometrieVerfuegbar;
  final bool biometrieAktiv;
  final bool analyseAktiv;
  final bool keineMobilenDaten;
  final Future<void> Function(bool aktiv) onBiometrieAendern;
  final Future<void> Function(bool aktiv) onAnalyseAendern;
  final Future<void> Function(bool aktiv) onKeineMobilenDatenAendern;
  final VoidCallback onRechtliches;
}

/// Zeigt den Stepper als Vollbild-Dialog. Liefert, ob eine kurze Einfuehrung
/// gewuenscht ist (die Einfuehrung selbst folgt spaeter).
Future<bool> showWelcomeDialog(
  BuildContext context, {
  required WillkommenOptionen optionen,
}) async {
  final ergebnis = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    useSafeArea: false,
    builder: (_) =>
        Dialog.fullscreen(child: WillkommenStepper(optionen: optionen)),
  );
  return ergebnis ?? false;
}

enum _Schritt { schutz, daten, einfuehrung }

class WillkommenStepper extends StatefulWidget {
  const WillkommenStepper({
    super.key,
    required this.optionen,
    this.startSchritt = 0,
  });

  final WillkommenOptionen optionen;

  /// Nur fuer Storybook und Tests.
  final int startSchritt;

  @override
  State<WillkommenStepper> createState() => _WillkommenStepperState();
}

class _WillkommenStepperState extends State<WillkommenStepper> {
  late final List<_Schritt> _schritte = [
    if (widget.optionen.biometrieVerfuegbar) _Schritt.schutz,
    _Schritt.daten,
    _Schritt.einfuehrung,
  ];
  late int _index = widget.startSchritt.clamp(0, _schritte.length - 1);
  late bool _biometrie = widget.optionen.biometrieAktiv;
  late bool _analyse = widget.optionen.analyseAktiv;
  late bool _keineMobilenDaten = widget.optionen.keineMobilenDaten;

  _Schritt get _aktuell => _schritte[_index];

  void _weiter() => setState(() => _index++);
  void _zurueck() => setState(() => _index--);

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final (icon, titelKey, inhalt) = switch (_aktuell) {
      _Schritt.schutz => (null, 'welcome_lock_title', _schutzInhalt(t)),
      _Schritt.daten => (
        Icons.verified_user_outlined,
        'welcome_data_title',
        _datenInhalt(t),
      ),
      _Schritt.einfuehrung => (
        Icons.auto_awesome_outlined,
        'welcome_intro_title',
        Text(t.t('welcome_intro_body'), style: theme.textTheme.bodyLarge),
      ),
    };

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Fortschritt(anzahl: _schritte.length, aktiv: _index),
                const SizedBox(height: 8),
                Text(
                  t.t('welcome_step', {
                    'current': _index + 1,
                    'total': _schritte.length,
                  }),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 28),
                Expanded(
                  child: SingleChildScrollView(
                    key: ValueKey(_aktuell),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SchrittIcon(icon: icon),
                        const SizedBox(height: 20),
                        if (_index == 0)
                          Text(
                            t.t('welcome_title').toUpperCase(),
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: colors.primary,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                            ),
                          ),
                        Text(
                          t.t(titelKey),
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        inhalt,
                      ],
                    ),
                  ),
                ),
                ..._knoepfe(t),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _knoepfe(AppLocalizations t) {
    final zurueck = _index > 0
        ? Center(
            child: TextButton(
              key: const Key('welcome-back'),
              onPressed: _zurueck,
              child: Text(t.t('welcome_back')),
            ),
          )
        : const SizedBox(height: 48);
    if (_aktuell == _Schritt.einfuehrung) {
      return [
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            key: const Key('welcome-intro-yes'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(t.t('welcome_intro_yes')),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: FilledButton.tonal(
            key: const Key('welcome-intro-no'),
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(t.t('welcome_intro_no')),
          ),
        ),
        zurueck,
      ];
    }
    return [
      SizedBox(
        width: double.infinity,
        child: FilledButton(
          key: const Key('welcome-next'),
          onPressed: _weiter,
          child: Text(t.t('welcome_next')),
        ),
      ),
      zurueck,
    ];
  }

  Widget _schutzInhalt(AppLocalizations t) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t.t('welcome_lock_body'), style: theme.textTheme.bodyLarge),
        const SizedBox(height: 16),
        _OptionKarte(
          titel: t.t('welcome_lock_option'),
          text: t.t('welcome_lock_option_hint'),
          aktion: _biometrie
              ? TextButton.icon(
                  key: const Key('welcome-lock-off'),
                  onPressed: () async {
                    await widget.optionen.onBiometrieAendern(false);
                    setState(() => _biometrie = false);
                  },
                  icon: Icon(Icons.check_circle, color: colors.primary),
                  label: Text(t.t('welcome_lock_active')),
                )
              : FilledButton(
                  key: const Key('welcome-lock-on'),
                  onPressed: () async {
                    await widget.optionen.onBiometrieAendern(true);
                    setState(() => _biometrie = true);
                  },
                  child: Text(t.t('welcome_lock_activate')),
                ),
        ),
        const SizedBox(height: 10),
        Text(
          t.t('welcome_change_later'),
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _datenInhalt(AppLocalizations t) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t.t('welcome_data_body'), style: theme.textTheme.bodyLarge),
        const SizedBox(height: 16),
        _OptionKarte(
          titel: t.t('settings_app_analytics_title'),
          text: t.t('welcome_analytics_hint'),
          aktion: Switch(
            key: const Key('welcome-analytics'),
            value: _analyse,
            onChanged: (wert) async {
              setState(() => _analyse = wert);
              await widget.optionen.onAnalyseAendern(wert);
            },
          ),
        ),
        const SizedBox(height: 10),
        _OptionKarte(
          titel: t.t('welcome_no_mobile_data'),
          text: t.t('welcome_no_mobile_data_hint'),
          aktion: Switch(
            key: const Key('welcome-no-mobile-data'),
            value: _keineMobilenDaten,
            onChanged: (wert) async {
              setState(() => _keineMobilenDaten = wert);
              await widget.optionen.onKeineMobilenDatenAendern(wert);
            },
          ),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          key: const Key('welcome-legal'),
          style: TextButton.styleFrom(padding: EdgeInsets.zero),
          onPressed: widget.optionen.onRechtliches,
          icon: Icon(Icons.shield_outlined, size: 18, color: colors.primary),
          label: Text(t.t('legal_title')),
        ),
      ],
    );
  }
}

class _Fortschritt extends StatelessWidget {
  const _Fortschritt({required this.anzahl, required this.aktiv});

  final int anzahl;
  final int aktiv;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        for (var i = 0; i < anzahl; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 4,
              decoration: BoxDecoration(
                color: i <= aktiv
                    ? colors.primary
                    : colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _SchrittIcon extends StatelessWidget {
  const _SchrittIcon({required this.icon});

  /// Ohne Icon (erster Schritt) erscheint die Lilie.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final icon = this.icon;
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: icon == null ? colors.primary : colors.primaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Center(
        child: icon == null
            ? SvgPicture.asset(
                'assets/images/lilie.svg',
                width: 34,
                height: 34,
                colorFilter: ColorFilter.mode(
                  colors.onPrimary,
                  BlendMode.srcIn,
                ),
              )
            : Icon(icon, size: 28, color: colors.onPrimaryContainer),
      ),
    );
  }
}

class _OptionKarte extends StatelessWidget {
  const _OptionKarte({
    required this.titel,
    required this.text,
    required this.aktion,
  });

  final String titel;
  final String text;
  final Widget aktion;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titel,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  text,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          aktion,
        ],
      ),
    );
  }
}

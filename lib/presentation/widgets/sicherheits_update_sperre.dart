import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/app_update/sicherheits_update_regel.dart';
import '../../domain/member/mitglied.dart';
import '../../l10n/app_localizations.dart';
import '../model/arbeitskontext_model.dart';
import '../model/sicherheits_update_model.dart';
import '../notifications/sicherheits_update_sheet.dart';
import 'app_sperre_flaeche.dart';

/// Countdown-Streifen oben ueber jeder Seite (T1), solange nach dem letzten
/// Aufschub die Sperre naht. Die Seiten darunter bekommen den oberen
/// Abstand nicht doppelt.
class SicherheitsUpdateRahmen extends StatefulWidget {
  const SicherheitsUpdateRahmen({super.key, required this.child, this.now});

  final Widget child;
  final DateTime Function()? now;

  @override
  State<SicherheitsUpdateRahmen> createState() =>
      _SicherheitsUpdateRahmenState();
}

class _SicherheitsUpdateRahmenState extends State<SicherheitsUpdateRahmen> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // Die Restzeit steht minutengenau da.
    _ticker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final model = context.watch<SicherheitsUpdateModel?>();
    final lage = model?.lage;
    final sperreAb = lage?.ab;
    if (model == null ||
        lage?.art != SicherheitsUpdateLageArt.countdown ||
        sperreAb == null) {
      return widget.child;
    }
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final rest = sperreAb.difference((widget.now ?? DateTime.now)());
    final stunden = rest.inHours.clamp(0, 99);
    final minuten = (rest.inMinutes % 60).clamp(0, 59);
    return Column(
      children: [
        Material(
          key: const Key('security-update-countdown'),
          color: theme.colorScheme.errorContainer,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.t('security_update_countdown_title'),
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        ),
                        Text(
                          t.t('security_update_countdown_body', {
                            'hours': stunden,
                            'minutes': minuten,
                          }),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onErrorContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => oeffneStore(model.info?.storeUrl ?? ''),
                    child: Text(t.t('security_update_now')),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: widget.child,
          ),
        ),
      ],
    );
  }
}

/// Deckende Sperre nach Ablauf des Countdowns (L2). Bleiben die Daten
/// erhalten, gibt es einen Notfallzugang mit Namen und Telefonnummern.
class SicherheitsUpdateSperre extends StatefulWidget {
  const SicherheitsUpdateSperre({super.key});

  @override
  State<SicherheitsUpdateSperre> createState() =>
      _SicherheitsUpdateSperreState();
}

class _SicherheitsUpdateSperreState extends State<SicherheitsUpdateSperre> {
  bool _notfall = false;
  bool _prueft = false;

  @override
  Widget build(BuildContext context) {
    final model = context.watch<SicherheitsUpdateModel?>();
    if (model == null || !model.istGesperrt) {
      _notfall = false;
      return const SizedBox.shrink();
    }
    if (_notfall && !model.datenGeloescht) {
      return _Notfallkontakte(
        onZurueck: () => setState(() => _notfall = false),
      );
    }
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final info = model.info;
    return PopScope(
      canPop: false,
      child: Material(
        key: const Key('security-update-sperre'),
        child: AppSperreFlaeche(
          inhalt: AppSperreGlas(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  t.t('security_lock_title'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  t.t(
                    model.datenGeloescht
                        ? 'security_lock_body_deleted'
                        : 'security_lock_body',
                  ),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  key: const Key('security-lock-store'),
                  onPressed: () => oeffneStore(info?.storeUrl ?? ''),
                  child: Text(t.t('security_lock_store')),
                ),
                if (!model.datenGeloescht) ...[
                  const SizedBox(height: 8),
                  OutlinedButton(
                    key: const Key('security-lock-notfall'),
                    onPressed: () => setState(() => _notfall = true),
                    child: Text(t.t('security_lock_emergency')),
                  ),
                ],
                const SizedBox(height: 4),
                TextButton(
                  key: const Key('security-lock-recheck'),
                  onPressed: _prueft
                      ? null
                      : () async {
                          setState(() => _prueft = true);
                          await model.pruefe(forceRefresh: true);
                          if (mounted) {
                            setState(() => _prueft = false);
                          }
                        },
                  child: Text(t.t('security_lock_recheck')),
                ),
                if (info != null)
                  Text(
                    t.t('security_lock_version', {
                      'current': info.currentVersion,
                      'min': info.vorgabe.minVersion,
                    }),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Reine Leseliste: Namen und Telefonnummern, ohne Bearbeiten und Sync.
class _Notfallkontakte extends StatelessWidget {
  const _Notfallkontakte({required this.onZurueck});

  final VoidCallback onZurueck;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final mitglieder =
        (context.watch<ArbeitskontextModel?>()?.readModel?.mitglieder ??
                const <Mitglied>[])
            .where((mitglied) => mitglied.telefonnummern.isNotEmpty)
            .toList()
          ..sort((a, b) => a.nachname.compareTo(b.nachname));
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) => onZurueck(),
      child: Scaffold(
        key: const Key('security-lock-notfall-liste'),
        appBar: AppBar(
          leading: BackButton(onPressed: onZurueck),
          title: Text(t.t('security_lock_emergency')),
        ),
        body: Column(
          children: [
            Container(
              width: double.infinity,
              color: theme.colorScheme.errorContainer,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Text(
                t.t('security_lock_emergency_hint'),
                style: theme.textTheme.bodySmall,
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  for (final mitglied in mitglieder)
                    for (final telefon in mitglied.telefonnummern)
                      ListTile(
                        title: Text(mitglied.fullName),
                        subtitle: Text(
                          [
                            if ((telefon.label ?? '').isNotEmpty) telefon.label,
                            telefon.wert,
                          ].join(': '),
                        ),
                        trailing: const Icon(Icons.call_outlined),
                        onTap: () => launchUrl(
                          Uri(
                            scheme: 'tel',
                            path: telefon.wert.replaceAll(' ', ''),
                          ),
                        ),
                      ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

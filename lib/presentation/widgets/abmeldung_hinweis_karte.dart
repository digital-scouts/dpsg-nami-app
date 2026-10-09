import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// Erklaert auf dem Login-Bildschirm, warum die App ohne Zutun abgemeldet
/// hat oder warum die letzte Anmeldung nicht abgeschlossen wurde. Bleibt bis
/// zur naechsten Anmeldung sichtbar.
class AbmeldungHinweisKarte extends StatelessWidget {
  const AbmeldungHinweisKarte({super.key})
    : _titelKey = 'auth_logout_rights_changed_title',
      _textKey = 'auth_logout_rights_changed_body',
      _karteKey = const Key('abmeldung-hinweis'),
      _verloren = 0;

  /// Das System hat die App während der Anmeldung im Browser beendet.
  const AbmeldungHinweisKarte.anmeldungUnterbrochen({super.key})
    : _titelKey = 'auth_login_interrupted_title',
      _textKey = 'auth_login_interrupted_body',
      _karteKey = const Key('anmeldung-unterbrochen-hinweis'),
      _verloren = 0;

  /// Die Daten sind nach der Aufbewahrungsfrist abgelaufen. Gingen dabei
  /// vorgemerkte Aenderungen verloren, erscheint die Karte als Warnung.
  const AbmeldungHinweisKarte.datenAbgelaufen({super.key, int verloren = 0})
    : _titelKey = verloren > 0
          ? 'auth_logout_expired_lost_title'
          : 'auth_logout_expired_title',
      _textKey = verloren > 0
          ? 'auth_logout_expired_lost_body'
          : 'auth_logout_expired_body',
      _karteKey = const Key('daten-abgelaufen-hinweis'),
      _verloren = verloren;

  final String _titelKey;
  final String _textKey;
  final Key _karteKey;
  final int _verloren;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final warnung = _verloren > 0;
    final werte = <String, Object?>{'count': _verloren};
    return Semantics(
      container: true,
      liveRegion: true,
      child: Container(
        key: _karteKey,
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: warnung ? scheme.errorContainer : scheme.primaryContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              warnung ? Icons.warning_amber_rounded : Icons.info_outline,
              color: warnung ? scheme.error : scheme.primary,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.t(_titelKey, werte),
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: warnung ? scheme.onErrorContainer : null,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    t.t(_textKey, werte),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
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

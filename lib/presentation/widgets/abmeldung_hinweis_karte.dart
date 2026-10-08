import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// Erklaert auf dem Login-Bildschirm, warum die App ohne Zutun abgemeldet
/// hat oder warum die letzte Anmeldung nicht abgeschlossen wurde. Bleibt bis
/// zur naechsten Anmeldung sichtbar.
class AbmeldungHinweisKarte extends StatelessWidget {
  const AbmeldungHinweisKarte({super.key})
    : _titelKey = 'auth_logout_rights_changed_title',
      _textKey = 'auth_logout_rights_changed_body',
      _karteKey = const Key('abmeldung-hinweis');

  /// Das System hat die App während der Anmeldung im Browser beendet.
  const AbmeldungHinweisKarte.anmeldungUnterbrochen({super.key})
    : _titelKey = 'auth_login_interrupted_title',
      _textKey = 'auth_login_interrupted_body',
      _karteKey = const Key('anmeldung-unterbrochen-hinweis');

  final String _titelKey;
  final String _textKey;
  final Key _karteKey;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      container: true,
      liveRegion: true,
      child: Container(
        key: _karteKey,
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: scheme.primaryContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, color: scheme.primary, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.t(_titelKey), style: theme.textTheme.titleSmall),
                  const SizedBox(height: 3),
                  Text(
                    t.t(_textKey),
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

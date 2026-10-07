import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/rechtliches/anbieter.dart';
import '../../l10n/app_localizations.dart';
import '../widgets/section_header.dart';

/// Wann Daten an einen Empfaenger fliessen; bestimmt Text und Farbe des Chips.
enum DatenAnlass { anmeldung, nutzung, einwilligung, teilsEinwilligung, aktion }

/// Ein Empfaenger auf der Seite. Die Texte liegen unter `legal_r_<id>_*`.
class Datenempfaenger {
  const Datenempfaenger(this.id, this.icon, this.farbe, this.anlass);

  final String id;
  final IconData icon;
  final Color farbe;
  final DatenAnlass anlass;

  /// Muss zu docs/app-privacy-policy.md passen.
  static const List<Datenempfaenger> alle = [
    Datenempfaenger(
      'hitobito',
      Icons.account_balance_outlined,
      Color(0xFF003056),
      DatenAnlass.anmeldung,
    ),
    Datenempfaenger(
      'statistik',
      Icons.bar_chart,
      Color(0xFF00823C),
      DatenAnlass.einwilligung,
    ),
    Datenempfaenger(
      'wiredash',
      Icons.chat_bubble_outline,
      Color(0xFFAF52DE),
      DatenAnlass.teilsEinwilligung,
    ),
    Datenempfaenger(
      'geoapify',
      Icons.place_outlined,
      Color(0xFFFF9500),
      DatenAnlass.nutzung,
    ),
    Datenempfaenger(
      'kacheln',
      Icons.layers_outlined,
      Color(0xFF30B0C7),
      DatenAnlass.nutzung,
    ),
    Datenempfaenger(
      'github',
      Icons.download_outlined,
      Color(0xFF8E8E93),
      DatenAnlass.nutzung,
    ),
    Datenempfaenger(
      'dpsg',
      Icons.map_outlined,
      Color(0xFFCC1F2F),
      DatenAnlass.nutzung,
    ),
    Datenempfaenger(
      'logmail',
      Icons.send_outlined,
      Color(0xFF007AFF),
      DatenAnlass.aktion,
    ),
  ];
}

/// Impressum und Datenschutz auf einer Seite: Kernaussagen mit Anbieter,
/// Empfaenger als Kacheln mit Details im Sheet, dazu Geraet, Rechte, Quellen,
/// Lizenzen und der Link zur ausfuehrlichen Datenschutzerklaerung.
class SettingsRechtlichesPage extends StatelessWidget {
  const SettingsRechtlichesPage({
    super.key,
    this.installationsId,
    this.onOpenUrl,
  });

  /// Fuer „ID kopieren“ beim Statistikserver; nur bekannt, wenn schon geteilt.
  final String? installationsId;

  /// Fuer Tests; sonst url_launcher.
  final Future<void> Function(Uri uri)? onOpenUrl;

  Future<void> _oeffne(Uri uri) async {
    final handler = onOpenUrl;
    if (handler != null) {
      await handler(uri);
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Uri get _mail => Uri(scheme: 'mailto', path: Anbieter.email);

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.t('legal_title'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _KurzGesagtKarte(onMail: () => _oeffne(_mail)),
          const SizedBox(height: 20),
          DpsgSectionHeader(label: t.t('legal_recipients_title')),
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              t.t('legal_recipients_hint'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          _EmpfaengerRaster(
            onTap: (empfaenger) => _zeigeEmpfaenger(context, empfaenger),
          ),
          const SizedBox(height: 16),
          Card(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                _NavZeile(
                  key: const Key('legal-device'),
                  icon: Icons.lock_outline,
                  label: t.t('legal_device_title'),
                  onTap: () => _zeigeText(
                    context,
                    t.t('legal_device_title'),
                    Text(t.t('legal_device_body')),
                  ),
                ),
                _NavZeile(
                  key: const Key('legal-rights'),
                  icon: Icons.balance_outlined,
                  label: t.t('legal_rights_title'),
                  onTap: () => _zeigeText(
                    context,
                    t.t('legal_rights_title'),
                    _RechteInhalt(onMail: () => _oeffne(_mail)),
                  ),
                ),
                _NavZeile(
                  key: const Key('legal-sources'),
                  icon: Icons.map_outlined,
                  label: t.t('legal_sources_title'),
                  onTap: () => _zeigeText(
                    context,
                    t.t('legal_sources_title'),
                    Text(t.t('legal_sources_body')),
                  ),
                ),
                _NavZeile(
                  key: const Key('legal-licenses'),
                  icon: Icons.description_outlined,
                  label: t.t('legal_licenses'),
                  onTap: () => showLicensePage(
                    context: context,
                    applicationName: 'NaMi',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              key: const Key('legal-full-policy'),
              leading: Icon(
                Icons.article_outlined,
                color: theme.colorScheme.primary,
              ),
              title: Text(
                t.t('legal_full_policy'),
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              trailing: Icon(
                Icons.open_in_new,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              onTap: () =>
                  _oeffne(Uri.parse(Anbieter.datenschutzerklaerungUrl)),
            ),
          ),
        ],
      ),
    );
  }

  void _zeigeEmpfaenger(BuildContext context, Datenempfaenger empfaenger) {
    final id = installationsId;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => _EmpfaengerSheet(
        empfaenger: empfaenger,
        installationsId: empfaenger.id == 'statistik' ? id : null,
        onMail: empfaenger.id == 'statistik' ? () => _oeffne(_mail) : null,
      ),
    );
  }

  void _zeigeText(BuildContext context, String titel, Widget inhalt) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titel, style: Theme.of(sheetContext).textTheme.titleLarge),
              const SizedBox(height: 12),
              inhalt,
            ],
          ),
        ),
      ),
    );
  }
}

class _KurzGesagtKarte extends StatelessWidget {
  const _KurzGesagtKarte({required this.onMail});

  final VoidCallback onMail;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final punkte = <(IconData, String)>[
      (Icons.lock_outline, t.t('legal_short_local')),
      (Icons.verified_user_outlined, t.t('legal_short_consent')),
      (Icons.send_outlined, t.t('legal_short_action')),
      (Icons.public, t.t('legal_short_ip')),
    ];

    return Container(
      key: const Key('legal-short'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.t('legal_short_title'),
            style: theme.textTheme.titleMedium?.copyWith(
              color: colors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          for (final (icon, text) in punkte)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 18, color: colors.primary),
                  const SizedBox(width: 10),
                  Expanded(child: Text(text)),
                ],
              ),
            ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 19,
                backgroundColor: colors.surface,
                child: Text(
                  'JL',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      Anbieter.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    InkWell(
                      key: const Key('legal-provider-mail'),
                      onTap: onMail,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.mail_outline,
                            size: 15,
                            color: colors.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            Anbieter.email,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      t.t('legal_provider_note'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmpfaengerRaster extends StatelessWidget {
  const _EmpfaengerRaster({required this.onTap});

  final ValueChanged<Datenempfaenger> onTap;

  @override
  Widget build(BuildContext context) {
    final alle = Datenempfaenger.alle;
    return Column(
      children: [
        for (var i = 0; i < alle.length; i += 2)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _EmpfaengerKachel(
                      empfaenger: alle[i],
                      onTap: () => onTap(alle[i]),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: i + 1 < alle.length
                        ? _EmpfaengerKachel(
                            empfaenger: alle[i + 1],
                            onTap: () => onTap(alle[i + 1]),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _EmpfaengerKachel extends StatelessWidget {
  const _EmpfaengerKachel({required this.empfaenger, required this.onTap});

  final Datenempfaenger empfaenger;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final id = empfaenger.id;
    return Card(
      key: Key('legal-recipient-$id'),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _IconQuadrat(icon: empfaenger.icon, farbe: empfaenger.farbe),
              const SizedBox(height: 10),
              Text(
                t.t('legal_r_${id}_name'),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                t.t('legal_r_${id}_short'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              const SizedBox(height: 8),
              _AnlassChip(anlass: empfaenger.anlass),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconQuadrat extends StatelessWidget {
  const _IconQuadrat({required this.icon, required this.farbe, this.size = 30});

  final IconData icon;
  final Color farbe;
  final double size;

  @override
  Widget build(BuildContext context) {
    final dunkel = Theme.of(context).brightness == Brightness.dark;
    // Das DPSG-Blau ist im Dunkeln zu dunkel; dort die Primaerfarbe nehmen.
    final vordergrund = dunkel && farbe == const Color(0xFF003056)
        ? Theme.of(context).colorScheme.primary
        : farbe;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: vordergrund.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: size * 0.6, color: vordergrund),
    );
  }
}

class _AnlassChip extends StatelessWidget {
  const _AnlassChip({required this.anlass});

  final DatenAnlass anlass;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final (key, farbe) = switch (anlass) {
      DatenAnlass.anmeldung => ('legal_when_login', colors.onSurfaceVariant),
      DatenAnlass.nutzung => ('legal_when_use', colors.onSurfaceVariant),
      DatenAnlass.einwilligung => ('legal_when_consent', colors.primary),
      DatenAnlass.teilsEinwilligung => ('legal_when_partly', colors.primary),
      DatenAnlass.aktion => ('legal_when_action', Colors.green.shade700),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: farbe.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        t.t(key),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: farbe,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _EmpfaengerSheet extends StatelessWidget {
  const _EmpfaengerSheet({
    required this.empfaenger,
    this.installationsId,
    this.onMail,
  });

  final Datenempfaenger empfaenger;
  final String? installationsId;
  final VoidCallback? onMail;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final id = empfaenger.id;
    final hinweisKey = 'legal_r_${id}_note';
    final hinweis = t.t(hinweisKey, {'email': Anbieter.email});
    final idWert = installationsId;

    Widget abschnitt(String labelKey, String text) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.t(labelKey).toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: colors.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 2),
          Text(text, style: theme.textTheme.bodyLarge),
        ],
      ),
    );

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          key: Key('legal-sheet-$id'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _IconQuadrat(
                  icon: empfaenger.icon,
                  farbe: empfaenger.farbe,
                  size: 40,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.t('legal_r_${id}_name'),
                        style: theme.textTheme.titleLarge,
                      ),
                      _AnlassChip(anlass: empfaenger.anlass),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            abschnitt('legal_label_purpose', t.t('legal_r_${id}_purpose')),
            abschnitt('legal_label_data', t.t('legal_r_${id}_data')),
            abschnitt('legal_label_basis', t.t('legal_r_${id}_basis')),
            abschnitt('legal_label_retention', t.t('legal_r_${id}_retention')),
            // Ohne Uebersetzung liefert t() den Schluessel selbst.
            if (hinweis != hinweisKey)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(hinweis, style: theme.textTheme.bodySmall),
              ),
            if (onMail != null) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  if (idWert != null) ...[
                    Expanded(
                      child: FilledButton.tonalIcon(
                        key: const Key('legal-copy-id'),
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: idWert));
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  t.t('bund_installation_id_copied'),
                                ),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.copy, size: 18),
                        label: Text(t.t('legal_copy_id')),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: FilledButton.icon(
                      key: const Key('legal-write-mail'),
                      onPressed: onMail,
                      icon: const Icon(Icons.mail_outline, size: 18),
                      label: Text(t.t('legal_write_mail')),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RechteInhalt extends StatelessWidget {
  const _RechteInhalt({required this.onMail});

  final VoidCallback onMail;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final kontakt = t.t('legal_rights_contact', {'email': Anbieter.email});
    final mailStart = kontakt.indexOf(Anbieter.email);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t.t('legal_rights_intro')),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final recht in t.t('legal_rights_list').split('|'))
              Chip(label: Text(recht), visualDensity: VisualDensity.compact),
          ],
        ),
        const SizedBox(height: 10),
        if (mailStart < 0)
          Text(kontakt)
        else
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: kontakt.substring(0, mailStart)),
                WidgetSpan(
                  alignment: PlaceholderAlignment.baseline,
                  baseline: TextBaseline.alphabetic,
                  child: InkWell(
                    onTap: onMail,
                    child: Text(
                      Anbieter.email,
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                TextSpan(
                  text: kontakt.substring(mailStart + Anbieter.email.length),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _NavZeile extends StatelessWidget {
  const _NavZeile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListTile(
      leading: _IconQuadrat(icon: icon, farbe: colors.primary),
      title: Text(label),
      trailing: Icon(Icons.chevron_right, color: colors.onSurfaceVariant),
      onTap: onTap,
    );
  }
}

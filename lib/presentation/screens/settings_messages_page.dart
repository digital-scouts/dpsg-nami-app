import 'package:flutter/material.dart';

class SettingsMessagesPage extends StatelessWidget {
  const SettingsMessagesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final entries = <_MessageEntry>[
      const _MessageEntry(
        title: 'Hitobito nicht erreichbar',
        body:
            'Die Verbindung zum Server ist unterbrochen. Daten werden aus dem lokalen Cache geladen.',
        type: _MessageType.warn,
        time: 'vor 2 Stunden',
        unread: true,
      ),
      const _MessageEntry(
        title: 'Synchronisation fehlgeschlagen',
        body:
            '3 Mitgliedsdatensaetze konnten nicht synchronisiert werden. Bitte Verbindung pruefen.',
        type: _MessageType.info,
        time: 'vor 2 Stunden',
        unread: true,
      ),
      const _MessageEntry(
        title: 'Daten erfolgreich gespeichert',
        body:
            'Die Aenderungen an den Stamm-Einstellungen wurden lokal gesichert und werden beim naechsten Sync uebertragen.',
        type: _MessageType.success,
        time: 'vor 5 Stunden',
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Meldungen')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                children: [
                  for (int i = 0; i < entries.length; i++) ...[
                    _MessageTile(entry: entries[i]),
                    if (i < entries.length - 1)
                      const Divider(height: 1, indent: 16, endIndent: 16),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Aeltere Meldungen werden nach 30 Tagen automatisch geloescht.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _MessageTile extends StatelessWidget {
  const _MessageTile({required this.entry});

  final _MessageEntry entry;

  @override
  Widget build(BuildContext context) {
    final iconColor = switch (entry.type) {
      _MessageType.warn => const Color(0xFFFFB300),
      _MessageType.info => const Color(0xFF003056),
      _MessageType.success => const Color(0xFF00823C),
    };
    final iconData = switch (entry.type) {
      _MessageType.warn => Icons.wifi_off,
      _MessageType.info => Icons.sync,
      _MessageType.success => Icons.check_circle,
    };

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      leading: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(iconData, color: iconColor, size: 20),
      ),
      title: Text(entry.title),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(entry.body),
            const SizedBox(height: 4),
            Text(entry.time, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
      trailing: entry.unread
          ? Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: Color(0xFFE6007E),
                shape: BoxShape.circle,
              ),
            )
          : null,
    );
  }
}

enum _MessageType { warn, info, success }

class _MessageEntry {
  const _MessageEntry({
    required this.title,
    required this.body,
    required this.type,
    required this.time,
    this.unread = false,
  });

  final String title;
  final String body;
  final _MessageType type;
  final String time;
  final bool unread;
}

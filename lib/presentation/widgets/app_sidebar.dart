import 'package:flutter/material.dart';

import '../../domain/notifications/message_of_the_day.dart';
import '../../l10n/app_localizations.dart';
import 'message_of_the_day_card.dart';

class AppSidebar extends StatefulWidget {
  final String userName;
  final String userId;
  final VoidCallback? onMeineStufe;
  final VoidCallback? onMitglieder;
  final VoidCallback? onStatistiken;
  final VoidCallback? onSettings;
  final MessageOfTheDay? motd;
  // Sidebar zeigt nur noch eine fixe Message; keine Model-Prop nötig

  const AppSidebar({
    super.key,
    required this.userName,
    required this.userId,
    this.onMeineStufe,
    this.onMitglieder,
    this.onStatistiken,
    this.onSettings,
    this.motd,
  });

  @override
  State<AppSidebar> createState() => _AppSidebarState();
}

class _AppSidebarState extends State<AppSidebar> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context);
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Oberer Bereich
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.asset(
                      'assets/icon/icon-blank.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.userName,
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'ID: ${widget.userId}',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Nav items
            const Divider(),
            ListTile(
              leading: const Icon(Icons.people),
              title: Text(t.t('nav_my_stage')),
              onTap: widget.onMeineStufe,
            ),
            ListTile(
              leading: const Icon(Icons.groups),
              title: Text(t.t('nav_members')),
              onTap: widget.onMitglieder,
            ),
            ListTile(
              leading: const Icon(Icons.insert_chart),
              title: Text(t.t('nav_statistics')),
              onTap: widget.onStatistiken,
            ),
            const Spacer(),

            // Unterer Bereich
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  if (widget.motd != null)
                    MessageOfTheDayCard(motd: widget.motd!, maxBodyHeight: 120),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: Text(t.t('nav_settings')),
              onTap: widget.onSettings,
            ),
            const Divider(),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Entwickelt mit ❤️ in Hamburg',
                style: theme.textTheme.bodySmall,
              ),
            ),

            const SizedBox(height: 5),
          ],
        ),
      ),
    );
  }
}

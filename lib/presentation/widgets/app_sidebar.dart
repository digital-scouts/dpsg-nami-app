import 'package:flutter/material.dart';

class AppSidebar extends StatefulWidget {
  final String userName;
  final String userId;
  final VoidCallback? onMeineStufe;
  final VoidCallback? onMitglieder;
  final VoidCallback? onStatistiken;
  final VoidCallback? onSettings;
  final String messageOfTheDay;
  final String messageOfTheDayHeader;

  const AppSidebar({
    super.key,
    required this.userName,
    required this.userId,
    this.onMeineStufe,
    this.onMitglieder,
    this.onStatistiken,
    this.onSettings,
    this.messageOfTheDay = "",
    this.messageOfTheDayHeader = "",
  });

  @override
  State<AppSidebar> createState() => _AppSidebarState();
}

class _AppSidebarState extends State<AppSidebar> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                    child: _HeaderIcon(brightness: theme.brightness),
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

            const Divider(),
            // Controls
            ListTile(
              leading: const Icon(Icons.people),
              title: const Text('Meine Stufe'),
              onTap: widget.onMeineStufe,
            ),
            ListTile(
              leading: const Icon(Icons.groups),
              title: const Text('Mitglieder'),
              onTap: widget.onMitglieder,
            ),
            ListTile(
              leading: const Icon(Icons.insert_chart),
              title: const Text('Statistiken'),
              onTap: widget.onStatistiken,
            ),
            const Spacer(),

            // Platz für Benachrichtigungen
            if (widget.messageOfTheDay.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.notifications_active,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  widget.messageOfTheDayHeader.isNotEmpty
                                      ? widget.messageOfTheDayHeader
                                      : 'Hinweis',
                                  style: theme.textTheme.titleSmall,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.messageOfTheDay,
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Einstellungen'),
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

class _HeaderIcon extends StatelessWidget {
  final Brightness brightness;
  const _HeaderIcon({required this.brightness});

  @override
  Widget build(BuildContext context) {
    final path = 'assets/icon/icon-blank.png';
    return Image.asset(
      path,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stack) {
        return Center(
          child: Icon(
            Icons.apps,
            color: Theme.of(context).colorScheme.onSecondaryContainer,
          ),
        );
      },
    );
  }
}

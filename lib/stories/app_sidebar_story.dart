import 'package:flutter/material.dart';
import 'package:nami/domain/notifications/message_of_the_day.dart';
import 'package:nami/presentation/widgets/app_sidebar.dart';
// ignore: depend_on_referenced_packages
import 'package:storybook_flutter/storybook_flutter.dart';

Story appSidebarStory() {
  return Story(
    name: 'App/Navigation/Sidebar',
    builder: (context) {
      final userName = context.knobs.text(
        label: 'Benutzername',
        initial: 'Max Mustermann',
      );
      final userId = context.knobs.text(label: 'Benutzer-ID', initial: '12345');
      final showMessageOfTheDay = context.knobs.boolean(
        label: 'Show Message of the Day',
        initial: true,
      );
      final motd = showMessageOfTheDay
          ? MessageOfTheDay(
              header: 'Hinweis',
              bodyMarkdown:
                  'Willkommen zur Nami App! Diese Seitenleiste bietet schnellen Zugriff auf wichtige Bereiche der App.',
              action: CallToAction(
                label: 'Mehr erfahren',
                externalLink: Uri.parse('https://dpsg.de'),
                color: Colors.blue,
              ),
            )
          : null;

      return Scaffold(
        appBar: AppBar(title: const Text('Sidebar Preview')),
        drawer: AppSidebar(
          userName: userName,
          userId: userId,
          motd: motd,
          onMeineStufe: () => ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Meine Stufe'))),
          onMitglieder: () => ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Mitglieder'))),
          onStatistiken: () => ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Statistiken'))),
          onSettings: () => ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Einstellungen'))),
        ),
        body: const Center(child: Text('Öffne das Menü über das AppBar-Icon.')),
      );
    },
  );
}

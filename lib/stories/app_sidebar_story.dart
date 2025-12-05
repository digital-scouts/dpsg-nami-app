import 'package:flutter/material.dart';
import 'package:nami/presentation/widgets/app_sidebar.dart';
// ignore: depend_on_referenced_packages
import 'package:storybook_flutter/storybook_flutter.dart';

Story appSidebarStory() {
  return Story(
    name: 'App/Sidebar',
    builder: (context) {
      final userName = context.knobs.text(
        label: 'Benutzername',
        initial: 'Max Mustermann',
      );
      final userId = context.knobs.text(label: 'Benutzer-ID', initial: '12345');
      final showNotification = context.knobs.boolean(
        label: 'Benachrichtigung anzeigen',
        initial: false,
      );
      final notificationText = context.knobs.text(
        label: 'Benachrichtigungstext',
        initial: 'Willkommen zurück!',
      );

      final messageOfTheDayHeader = context.knobs.text(
        label: 'Benachrichtigungskopf',
        initial: 'Tagesnachricht',
      );

      return Scaffold(
        appBar: AppBar(title: const Text('Sidebar Preview')),
        drawer: AppSidebar(
          userName: userName,
          userId: userId,
          messageOfTheDay: showNotification ? notificationText : "",
          messageOfTheDayHeader: messageOfTheDayHeader,
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

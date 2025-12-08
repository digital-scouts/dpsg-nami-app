import 'package:flutter/material.dart';
// ignore: depend_on_referenced_packages
import 'package:storybook_flutter/storybook_flutter.dart';

import '../domain/notifications/message_of_the_day.dart';
import '../presentation/widgets/message_of_the_day_card.dart';

Story storyMessageOfTheDayCard() {
  return Story(
    name: 'App/MessageOfTheDayCard',
    builder: (context) {
      final k = context.knobs;

      final header = k.text(label: 'Header', initial: 'Hinweis');
      final body = k.text(
        label: 'Body (Markdown)',
        initial:
            'Willkommen in der neuen App!\n\n- Neu: Timeline\n- Verbesserte Suche',
      );
      final maxHeight = k.slider(
        label: 'Max Body Height',
        initial: 160,
        min: 80,
        max: 320,
      );

      final label = k.text(label: 'CTA Label', initial: 'Action');
      final color = k.options<Color>(
        label: 'CTA Farbe',
        initial: Colors.blue,
        options: const [
          Option(label: 'Blau', value: Colors.blue),
          Option(label: 'Grün', value: Colors.green),
          Option(label: 'Rot', value: Colors.red),
          Option(label: 'Orange', value: Colors.orange),
        ],
      );
      final url = k.text(label: 'CTA URL', initial: 'https://dpsg.de');
      final action = CallToAction(
        color: color,
        label: label,
        externalLink: Uri.parse(url),
      );

      final motd = MessageOfTheDay(
        header: header,
        bodyMarkdown: body,
        action: action,
      );

      return Card(
        child: MessageOfTheDayCard(motd: motd, maxBodyHeight: maxHeight),
      );
    },
  );
}

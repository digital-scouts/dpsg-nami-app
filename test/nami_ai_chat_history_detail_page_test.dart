import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nami/domain/nami_ai/nami_ai_chat_history_entry.dart';
import 'package:nami/presentation/screens/nami_ai/nami_ai_chat_history_detail_page.dart';

void main() {
  testWidgets('zeigt alle Nachrichten der Unterhaltung read-only an', (
    tester,
  ) async {
    final entry = NamiAiChatHistoryEntry(
      id: 'entry-1',
      startedAt: DateTime(2026, 9, 1, 10, 30),
      title: 'Wie oft tagt die SV?',
      messages: const <NamiAiChatMessage>[
        NamiAiChatMessage(text: 'Wie oft tagt die SV?', isUser: true),
        NamiAiChatMessage(
          text: 'Mindestens einmal jaehrlich.',
          isUser: false,
          sources: <NamiAiSourceRef>[
            NamiAiSourceRef(
              docTitle: 'Satzung Stamm',
              sectionNumber: '18',
              docStand: 'Mai 2024',
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(home: NamiAiChatHistoryDetailPage(entry: entry)),
    );
    await tester.pump();

    expect(find.text('Wie oft tagt die SV?'), findsWidgets);
    expect(find.text('Mindestens einmal jaehrlich.'), findsOneWidget);
    expect(find.textContaining('Satzung Stamm § 18'), findsOneWidget);
  });

  testWidgets('bietet keine Eingabe- oder Fortsetzungsmoeglichkeit', (
    tester,
  ) async {
    final entry = NamiAiChatHistoryEntry(
      id: 'entry-1',
      startedAt: DateTime(2026, 9, 1, 10, 30),
      title: 'Frage',
      messages: const <NamiAiChatMessage>[
        NamiAiChatMessage(text: 'Frage', isUser: true),
        NamiAiChatMessage(text: 'Antwort', isUser: false),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(home: NamiAiChatHistoryDetailPage(entry: entry)),
    );
    await tester.pump();

    expect(find.byType(TextField), findsNothing);
    expect(find.byIcon(Icons.send), findsNothing);
  });
}

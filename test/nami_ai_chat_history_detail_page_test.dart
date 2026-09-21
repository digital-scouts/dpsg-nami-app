import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nami/domain/nami_ai/nami_ai_chat_history_entry.dart';
import 'package:nami/presentation/screens/nami_ai/nami_ai_chat_history_detail_page.dart';
import 'package:nami/services/nami_ai/nami_ai_corpus_lookup_service.dart';
import 'package:provider/provider.dart';

Widget _wrap(Widget child) {
  return MultiProvider(
    providers: [
      Provider<NamiAiCorpusLookupService>.value(
        value: NamiAiCorpusLookupService(),
      ),
    ],
    child: MaterialApp(home: child),
  );
}

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

    await tester.pumpWidget(_wrap(NamiAiChatHistoryDetailPage(entry: entry)));
    await tester.pump();

    expect(find.text('Wie oft tagt die SV?'), findsWidgets);
    expect(find.text('Mindestens einmal jaehrlich.'), findsOneWidget);
    expect(find.textContaining('Satzung Stamm § 18'), findsOneWidget);
  });

  testWidgets('zeigt den Absatztext, wenn eine Quelle angetippt wird', (
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

    await tester.pumpWidget(_wrap(NamiAiChatHistoryDetailPage(entry: entry)));
    await tester.pump();

    // The tap triggers a real rootBundle.loadString() (NamiAiCorpusLookupService) before the
    // sheet opens - that real asset I/O never settles under AutomatedTestWidgetsFlutterBinding's
    // pump-based fake-async zone if awaited via plain tester.tap()/pump() (same class of
    // real-I/O-vs-fake-async issue as the EventChannel one documented in
    // nami_ai_chat_page_test.dart), so it needs tester.runAsync() to actually resolve.
    await tester.runAsync(() async {
      await tester.tap(find.textContaining('Satzung Stamm § 18'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Mitglieder sind verpflichtet, einen Beitrag'),
      findsOneWidget,
    );
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

    await tester.pumpWidget(_wrap(NamiAiChatHistoryDetailPage(entry: entry)));
    await tester.pump();

    expect(find.byType(TextField), findsNothing);
    expect(find.byIcon(Icons.send), findsNothing);
  });
}

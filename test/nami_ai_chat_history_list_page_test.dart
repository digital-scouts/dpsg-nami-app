import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nami/domain/nami_ai/nami_ai_chat_history_entry.dart';
import 'package:nami/domain/nami_ai/nami_ai_chat_history_repository.dart';
import 'package:nami/presentation/screens/nami_ai/nami_ai_chat_history_list_page.dart';
import 'package:provider/provider.dart';

class _FakeNamiAiChatHistoryRepository implements NamiAiChatHistoryRepository {
  _FakeNamiAiChatHistoryRepository(this._entries);

  final List<NamiAiChatHistoryEntry> _entries;
  final Completer<void> loadGate = Completer<void>();

  @override
  Future<List<NamiAiChatHistoryEntry>> loadAll() async {
    await loadGate.future;
    return _entries;
  }

  @override
  Future<void> save(NamiAiChatHistoryEntry entry) async {}
}

Widget _buildTestApp(NamiAiChatHistoryRepository repository) {
  return MultiProvider(
    providers: [Provider<NamiAiChatHistoryRepository>.value(value: repository)],
    child: const MaterialApp(home: NamiAiChatHistoryListPage()),
  );
}

void main() {
  testWidgets('zeigt einen Ladeindikator, bevor die Historie geladen ist', (
    tester,
  ) async {
    final repository = _FakeNamiAiChatHistoryRepository(
      const <NamiAiChatHistoryEntry>[],
    );

    await tester.pumpWidget(_buildTestApp(repository));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets(
    'zeigt einen Hinweistext, wenn keine Unterhaltungen gespeichert sind',
    (tester) async {
      final repository = _FakeNamiAiChatHistoryRepository(
        const <NamiAiChatHistoryEntry>[],
      );
      repository.loadGate.complete();

      await tester.pumpWidget(_buildTestApp(repository));
      await tester.pump();

      expect(
        find.text('Noch keine gespeicherten Unterhaltungen.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('zeigt Titel und Datum je gespeicherter Unterhaltung', (
    tester,
  ) async {
    final repository = _FakeNamiAiChatHistoryRepository([
      NamiAiChatHistoryEntry(
        id: 'entry-1',
        startedAt: DateTime(2026, 9, 1, 10, 30),
        title: 'Wie oft tagt die SV?',
        messages: const <NamiAiChatMessage>[],
      ),
    ]);
    repository.loadGate.complete();

    await tester.pumpWidget(_buildTestApp(repository));
    await tester.pump();

    expect(find.text('Wie oft tagt die SV?'), findsOneWidget);
    expect(find.text('01.09.2026 10:30'), findsOneWidget);
  });

  testWidgets('oeffnet die Detailansicht beim Antippen eines Eintrags', (
    tester,
  ) async {
    final repository = _FakeNamiAiChatHistoryRepository([
      NamiAiChatHistoryEntry(
        id: 'entry-1',
        startedAt: DateTime(2026, 9, 1, 10, 30),
        title: 'Wie oft tagt die SV?',
        messages: const <NamiAiChatMessage>[
          NamiAiChatMessage(text: 'Wie oft tagt die SV?', isUser: true),
          NamiAiChatMessage(
            text: 'Mindestens einmal jaehrlich.',
            isUser: false,
          ),
        ],
      ),
    ]);
    repository.loadGate.complete();

    await tester.pumpWidget(_buildTestApp(repository));
    await tester.pump();

    await tester.tap(find.text('Wie oft tagt die SV?'));
    await tester.pumpAndSettle();

    expect(find.text('Mindestens einmal jaehrlich.'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });
}

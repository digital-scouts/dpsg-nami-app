import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:nami/data/nami_ai/nami_ai_chat_history_local_repository.dart';
import 'package:nami/domain/nami_ai/nami_ai_chat_history_entry.dart';
import 'package:nami/services/sensitive_storage_service.dart';

void main() {
  late Directory tempDir;
  late SensitiveStorageService sensitiveStorageService;
  late NamiAiChatHistoryLocalRepository repository;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
    tempDir = await Directory.systemTemp.createTemp(
      'nami_ai_chat_history_local_repository_',
    );
    Hive.init(tempDir.path);
    sensitiveStorageService = SensitiveStorageService();
    repository = NamiAiChatHistoryLocalRepository(
      sensitiveStorageService: sensitiveStorageService,
    );
  });

  tearDown(() async {
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test(
    'loadAll liefert eine leere Liste ohne gespeicherte Eintraege',
    () async {
      final entries = await repository.loadAll();

      expect(entries, isEmpty);
    },
  );

  test(
    'speichert und laedt eine Unterhaltung inkl. Quellen und unclear',
    () async {
      final entry = NamiAiChatHistoryEntry(
        id: 'entry-1',
        startedAt: DateTime(2026, 9, 1, 10, 30),
        title: 'Wie oft muss die Stammesversammlung stattfinden?',
        messages: const <NamiAiChatMessage>[
          NamiAiChatMessage(
            text: 'Wie oft muss die Stammesversammlung stattfinden?',
            isUser: true,
          ),
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

      await repository.save(entry);
      final loaded = await repository.loadAll();

      expect(loaded, hasLength(1));
      final loadedEntry = loaded.single;
      expect(loadedEntry.id, 'entry-1');
      expect(loadedEntry.startedAt, DateTime(2026, 9, 1, 10, 30));
      expect(
        loadedEntry.title,
        'Wie oft muss die Stammesversammlung stattfinden?',
      );
      expect(loadedEntry.messages, hasLength(2));
      expect(loadedEntry.messages.first.isUser, isTrue);
      final answer = loadedEntry.messages.last;
      expect(answer.isUser, isFalse);
      expect(answer.unclear, isFalse);
      expect(answer.sources, hasLength(1));
      expect(answer.sources.single.docTitle, 'Satzung Stamm');
      expect(answer.sources.single.sectionNumber, '18');
    },
  );

  test('loadAll sortiert mehrere Unterhaltungen neueste zuerst', () async {
    await repository.save(
      NamiAiChatHistoryEntry(
        id: 'older',
        startedAt: DateTime(2026, 9, 1),
        title: 'Aeltere Frage',
        messages: const <NamiAiChatMessage>[],
      ),
    );
    await repository.save(
      NamiAiChatHistoryEntry(
        id: 'newer',
        startedAt: DateTime(2026, 9, 10),
        title: 'Neuere Frage',
        messages: const <NamiAiChatMessage>[],
      ),
    );

    final entries = await repository.loadAll();

    expect(entries.map((e) => e.id).toList(), <String>['newer', 'older']);
  });

  test(
    'entfernt Eintraege, die aelter als 30 Tage sind, beim Laden automatisch',
    () async {
      final now = DateTime.now();
      await repository.save(
        NamiAiChatHistoryEntry(
          id: 'expired',
          startedAt: now.subtract(const Duration(days: 31)),
          title: 'Laengst vergangene Frage',
          messages: const <NamiAiChatMessage>[],
        ),
      );
      await repository.save(
        NamiAiChatHistoryEntry(
          id: 'fresh',
          startedAt: now.subtract(const Duration(days: 1)),
          title: 'Aktuelle Frage',
          messages: const <NamiAiChatMessage>[],
        ),
      );

      final entries = await repository.loadAll();

      expect(entries.map((e) => e.id).toList(), <String>['fresh']);

      final box = await sensitiveStorageService.openEncryptedStringBox(
        NamiAiChatHistoryLocalRepository.boxName,
      );
      expect(box.get('expired'), isNull);
      expect(box.get('fresh'), isNotNull);
    },
  );

  test('purgeSensitiveData entfernt auch die gesamte Chat-Historie', () async {
    await repository.save(
      NamiAiChatHistoryEntry(
        id: 'entry-1',
        startedAt: DateTime.now(),
        title: 'Frage',
        messages: const <NamiAiChatMessage>[],
      ),
    );

    await sensitiveStorageService.purgeSensitiveData();

    final entries = await repository.loadAll();
    expect(entries, isEmpty);
  });
}

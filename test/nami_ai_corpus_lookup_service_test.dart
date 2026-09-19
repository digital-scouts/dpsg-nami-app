import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:nami/services/nami_ai/nami_ai_corpus_lookup_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'lookup finds the full paragraph text for a known (docTitle, sectionNumber)',
    () async {
      final service = NamiAiCorpusLookupService();

      final chunk = await service.lookup('Satzung Stamm', '31');

      expect(chunk, isNotNull);
      expect(chunk!.docTitle, 'Satzung Stamm');
      expect(chunk.sectionNumber, '31');
      expect(chunk.text, contains('Aufgaben'));
      expect(chunk.docStand, isNotEmpty);
    },
  );

  test(
    'lookup returns null for an unknown (docTitle, sectionNumber)',
    () async {
      final service = NamiAiCorpusLookupService();

      final chunk = await service.lookup(
        'Satzung Stamm',
        'nicht-vorhanden-999',
      );

      expect(chunk, isNull);
    },
  );

  test('the corpus has no duplicate (doc_title, section_number) keys', () async {
    // Guards the assumption NamiAiCorpusLookupService, and natively NamiAiChunkKey/the
    // grounding gate, rely on: (doc_title, section_number) uniquely identifies a chunk. Reads
    // the raw asset independently of the service under test, so this catches a future corpus
    // regression (e.g. a bad re-chunking) rather than just re-testing the service's own map.
    final raw = await rootBundle.loadString(
      'assets/ai_kontext/nami_ai_corpus_v1.json',
    );
    final chunks = (jsonDecode(raw) as Map)['chunks'] as List;
    final keys = chunks
        .cast<Map>()
        .map((c) => '${c['doc_title']}||${c['section_number']}')
        .toSet();

    expect(keys.length, chunks.length);
  });
}

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

/// One retrievable paragraph from the bundled NaMi AI corpus (see chat_ai/build_chunks.py and
/// ios/NamiAiKit/Sources/NamiAiKit/NamiAiCorpus.swift for the native counterpart of this shape).
class NamiAiCorpusChunk {
  const NamiAiCorpusChunk({
    required this.docTitle,
    required this.sectionNumber,
    required this.sectionTitle,
    required this.docStand,
    required this.text,
    required this.pageStart,
    required this.pageEnd,
  });

  final String docTitle;
  final String sectionNumber;
  final String sectionTitle;
  final String docStand;
  final String text;
  final int pageStart;
  final int pageEnd;
}

/// Looks up the full paragraph text behind a NamiAiSourceRef, so a tapped source chip can show
/// its paragraph (specs/nami-ai-roadmap.md section 3.12: "Quellenangaben ... interaktiv machen").
/// The full corpus is already a bundled Flutter asset used natively (assets/ai_kontext/
/// nami_ai_corpus_v1.json, declared wholesale under assets/ai_kontext/ in pubspec.yaml) - no new
/// pipeline or asset needed, this just reads the same file from the Dart side.
///
/// (doc_title, section_number) is the same key NamiAiChunkKey uses natively for grounding-gate
/// matching, and is verified unique across the full corpus (667/667 chunks, checked against
/// assets/ai_kontext/nami_ai_corpus_v1.json), so it's a reliable lookup key here too.
class NamiAiCorpusLookupService {
  Map<String, NamiAiCorpusChunk>? _chunksByKey;

  Future<NamiAiCorpusChunk?> lookup(
    String docTitle,
    String sectionNumber,
  ) async {
    final chunksByKey = await _index();
    return chunksByKey[_key(docTitle, sectionNumber)];
  }

  Future<Map<String, NamiAiCorpusChunk>> _index() async {
    final cached = _chunksByKey;
    if (cached != null) {
      return cached;
    }

    final raw = await rootBundle.loadString(
      'assets/ai_kontext/nami_ai_corpus_v1.json',
    );
    final decoded = jsonDecode(raw);
    final chunksJson = decoded is Map ? decoded['chunks'] : null;

    final chunksByKey = <String, NamiAiCorpusChunk>{};
    if (chunksJson is List) {
      for (final entry in chunksJson) {
        if (entry is! Map) {
          continue;
        }
        final chunk = _chunkFromJson(entry.cast<Object?, Object?>());
        if (chunk != null) {
          chunksByKey[_key(chunk.docTitle, chunk.sectionNumber)] = chunk;
        }
      }
    }

    _chunksByKey = chunksByKey;
    return chunksByKey;
  }

  NamiAiCorpusChunk? _chunkFromJson(Map<Object?, Object?> json) {
    final docTitle = json['doc_title'] as String?;
    final sectionNumber = json['section_number'] as String?;
    final text = json['text'] as String?;
    if (docTitle == null || sectionNumber == null || text == null) {
      return null;
    }
    return NamiAiCorpusChunk(
      docTitle: docTitle,
      sectionNumber: sectionNumber,
      sectionTitle: json['section_title'] as String? ?? '',
      docStand: json['doc_stand'] as String? ?? '',
      text: text,
      pageStart: json['page_start'] as int? ?? 0,
      pageEnd: json['page_end'] as int? ?? 0,
    );
  }

  String _key(String docTitle, String sectionNumber) =>
      '$docTitle||$sectionNumber';
}

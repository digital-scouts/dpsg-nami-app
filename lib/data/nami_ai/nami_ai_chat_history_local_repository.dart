import 'dart:convert';

import '../../domain/nami_ai/nami_ai_chat_history_entry.dart';
import '../../domain/nami_ai/nami_ai_chat_history_repository.dart';
import '../../services/sensitive_storage_service.dart';

/// Follows the pattern of SecureArbeitskontextLocalRepository (encrypted Hive_ce box via
/// SensitiveStorageService), but keyed per conversation (one box entry per id) instead of a
/// single cache slot, since section 3.7 persists a list of past conversations rather than just
/// the last one.
class NamiAiChatHistoryLocalRepository implements NamiAiChatHistoryRepository {
  NamiAiChatHistoryLocalRepository({
    required SensitiveStorageService sensitiveStorageService,
  }) : _sensitiveStorageService = sensitiveStorageService;

  static const String boxName = 'nami_ai_chat_history_box';

  final SensitiveStorageService _sensitiveStorageService;

  @override
  Future<List<NamiAiChatHistoryEntry>> loadAll() async {
    final box = await _sensitiveStorageService.openEncryptedStringBox(boxName);
    final now = DateTime.now();
    final entries = <NamiAiChatHistoryEntry>[];
    final expiredKeys = <dynamic>[];

    for (final key in box.keys) {
      final raw = box.get(key);
      if (raw == null || raw.isEmpty) {
        continue;
      }

      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        continue;
      }

      final entry = _entryFromJson(decoded);
      if (entry == null) {
        continue;
      }

      if (entry.isExpired(now)) {
        expiredKeys.add(key);
        continue;
      }

      entries.add(entry);
    }

    for (final key in expiredKeys) {
      await box.delete(key);
    }

    entries.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return entries;
  }

  @override
  Future<void> save(NamiAiChatHistoryEntry entry) async {
    final box = await _sensitiveStorageService.openEncryptedStringBox(boxName);
    await box.put(entry.id, jsonEncode(_entryToJson(entry)));
  }

  Map<String, dynamic> _entryToJson(NamiAiChatHistoryEntry entry) {
    return <String, dynamic>{
      'id': entry.id,
      'started_at': entry.startedAt.toIso8601String(),
      'title': entry.title,
      'messages': entry.messages.map(_messageToJson).toList(growable: false),
    };
  }

  NamiAiChatHistoryEntry? _entryFromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString() ?? '';
    final startedAt = _toDateTime(json['started_at']);
    final title = json['title']?.toString() ?? '';
    if (id.isEmpty || startedAt == null) {
      return null;
    }

    final messagesJson = json['messages'];
    final messages = messagesJson is List
        ? messagesJson
              .whereType<Map<String, dynamic>>()
              .map(_messageFromJson)
              .whereType<NamiAiChatMessage>()
              .toList(growable: false)
        : const <NamiAiChatMessage>[];

    return NamiAiChatHistoryEntry(
      id: id,
      startedAt: startedAt,
      title: title,
      messages: messages,
    );
  }

  Map<String, dynamic> _messageToJson(NamiAiChatMessage message) {
    return <String, dynamic>{
      'text': message.text,
      'is_user': message.isUser,
      'sources': message.sources.map(_sourceToJson).toList(growable: false),
      'unclear': message.unclear,
    };
  }

  NamiAiChatMessage? _messageFromJson(Map<String, dynamic> json) {
    final text = json['text']?.toString();
    if (text == null) {
      return null;
    }

    final sourcesJson = json['sources'];
    final sources = sourcesJson is List
        ? sourcesJson
              .whereType<Map<String, dynamic>>()
              .map(_sourceFromJson)
              .whereType<NamiAiSourceRef>()
              .toList(growable: false)
        : const <NamiAiSourceRef>[];

    return NamiAiChatMessage(
      text: text,
      isUser: json['is_user'] == true,
      sources: sources,
      unclear: json['unclear'] == true,
    );
  }

  Map<String, dynamic> _sourceToJson(NamiAiSourceRef source) {
    return <String, dynamic>{
      'doc_title': source.docTitle,
      'section_number': source.sectionNumber,
      'doc_stand': source.docStand,
    };
  }

  NamiAiSourceRef? _sourceFromJson(Map<String, dynamic> json) {
    final docTitle = json['doc_title']?.toString() ?? '';
    final sectionNumber = json['section_number']?.toString() ?? '';
    final docStand = json['doc_stand']?.toString() ?? '';
    if (docTitle.isEmpty || sectionNumber.isEmpty) {
      return null;
    }

    return NamiAiSourceRef(
      docTitle: docTitle,
      sectionNumber: sectionNumber,
      docStand: docStand,
    );
  }

  DateTime? _toDateTime(Object? value) {
    final raw = value?.toString().trim();
    if (raw == null || raw.isEmpty) {
      return null;
    }

    return DateTime.tryParse(raw);
  }
}

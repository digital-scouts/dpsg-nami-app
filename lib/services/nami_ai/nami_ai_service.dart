import 'package:flutter/services.dart';

import '../../domain/nami_ai/nami_ai_chat_history_entry.dart';

class NamiAiException implements Exception {
  NamiAiException({required this.code, required this.message, this.details});

  final String code;
  final String message;
  final Object? details;

  @override
  String toString() => 'NamiAiException($code): $message';
}

NamiAiSourceRef? _sourceFromMap(Object? value) {
  if (value is! Map) {
    return null;
  }
  final map = value.cast<Object?, Object?>();
  final docTitle = map['docTitle'] as String?;
  final sectionNumber = map['sectionNumber'] as String?;
  final docStand = map['docStand'] as String?;
  if (docTitle == null || sectionNumber == null || docStand == null) {
    return null;
  }
  return NamiAiSourceRef(
    docTitle: docTitle,
    sectionNumber: sectionNumber,
    docStand: docStand,
  );
}

/// A successful NamiAiService reply. contextChunks carries a compact `doc_id#section_number`
/// ref for every chunk the native side actually grounded the answer in (useful for debugging,
/// see NamiAiDebugLogService; the full paragraph text can be looked up from the bundled corpus
/// via NamiAiCorpusLookupService); sources/
/// unclear are the technically-enforced citation result from NamiAiGroundingGate (section 3.6).
/// contextTruncated is true exactly for the turn in which a held multi-turn session (section
/// 3.7) had to drop older messages after a context-overflow error.
class NamiAiReply {
  const NamiAiReply({
    required this.answer,
    required this.contextChunks,
    this.sources = const <NamiAiSourceRef>[],
    this.unclear = false,
    this.contextTruncated = false,
  });

  final String answer;
  final List<String> contextChunks;
  final List<NamiAiSourceRef> sources;
  final bool unclear;
  final bool contextTruncated;

  /// Shared parsing for the identically-shaped payload generateReply's MethodChannel result and
  /// the stream EventChannel's "done" event both carry (see NamiAiFlutterBridge/
  /// NamiAiStreamHandler on the native side).
  static NamiAiReply? tryFromMap(Object? value) {
    if (value is! Map) {
      return null;
    }
    final map = value.cast<Object?, Object?>();
    final answer = map['answer'] as String?;
    if (answer == null) {
      return null;
    }
    final contextChunks =
        (map['contextChunks'] as List?)?.cast<String>() ?? const <String>[];
    final sources =
        (map['sources'] as List?)
            ?.map(_sourceFromMap)
            .whereType<NamiAiSourceRef>()
            .toList(growable: false) ??
        const <NamiAiSourceRef>[];
    return NamiAiReply(
      answer: answer,
      contextChunks: contextChunks,
      sources: sources,
      unclear: map['unclear'] as bool? ?? false,
      contextTruncated: map['contextTruncated'] as bool? ?? false,
    );
  }
}

/// Result of the native checkAvailability call. reason is one of NamiAiError's
/// flutterErrorCode values (e.g. ai_device_not_eligible) when available is false.
class NamiAiAvailability {
  const NamiAiAvailability({required this.available, this.reason});

  final bool available;
  final String? reason;
}

class NamiAiService {
  static const String _channelName = 'com.namiapp/nami_ai';
  static const MethodChannel _channel = MethodChannel(_channelName);

  Future<NamiAiReply> generateReply(
    String prompt, {
    required String sessionId,
  }) async {
    try {
      final dynamic result = await _channel.invokeMethod<dynamic>(
        'generateReply',
        <String, dynamic>{'prompt': prompt, 'sessionId': sessionId},
      );
      final reply = NamiAiReply.tryFromMap(result);
      if (reply == null) {
        throw NamiAiException(
          code: 'empty_response',
          message: 'Die iOS-Antwort war leer.',
        );
      }
      return reply;
    } on PlatformException catch (error) {
      throw NamiAiException(
        code: error.code,
        message: error.message ?? 'Fehler beim Aufruf der iOS-AI.',
        details: error.details,
      );
    } on NamiAiException {
      rethrow;
    } catch (error) {
      throw NamiAiException(
        code: 'unknown',
        message: 'Unbekannter Fehler beim AI-Aufruf: $error',
        details: error,
      );
    }
  }

  /// Starts a new held native chat session for follow-up questions (specs/nami-ai-roadmap.md
  /// section 3.7). The returned id must be passed to generateReply/NamiAiStreamService.respond
  /// and endSession.
  Future<String> startSession() async {
    try {
      final dynamic result = await _channel.invokeMethod<dynamic>(
        'startChatSession',
      );
      if (result is! Map) {
        throw NamiAiException(
          code: 'empty_response',
          message: 'Die iOS-Antwort auf startChatSession war leer.',
        );
      }
      final sessionId = result.cast<Object?, Object?>()['sessionId'] as String?;
      if (sessionId == null) {
        throw NamiAiException(
          code: 'empty_response',
          message:
              'Die iOS-Antwort auf startChatSession enthielt keine sessionId.',
        );
      }
      return sessionId;
    } on PlatformException catch (error) {
      throw NamiAiException(
        code: error.code,
        message: error.message ?? 'Fehler beim Starten der AI-Unterhaltung.',
        details: error.details,
      );
    } on NamiAiException {
      rethrow;
    } catch (error) {
      throw NamiAiException(
        code: 'unknown',
        message: 'Unbekannter Fehler beim Starten der AI-Unterhaltung: $error',
        details: error,
      );
    }
  }

  /// Releases a held native chat session. Best-effort, fire-and-forget from the UI's
  /// perspective - errors here are logged rather than surfaced, since ending a session that's
  /// already gone (e.g. process restart) is not a failure the user needs to see.
  Future<void> endSession(String sessionId) async {
    try {
      await _channel.invokeMethod<dynamic>('endChatSession', <String, dynamic>{
        'sessionId': sessionId,
      });
    } on PlatformException {
      // Best-effort cleanup, see doc comment above.
    }
  }

  Future<NamiAiAvailability> checkAvailability() async {
    try {
      final dynamic result = await _channel.invokeMethod<dynamic>(
        'checkAvailability',
      );
      if (result is! Map) {
        throw NamiAiException(
          code: 'empty_response',
          message: 'Die iOS-Verfügbarkeitsantwort war leer.',
        );
      }
      final map = result.cast<Object?, Object?>();
      return NamiAiAvailability(
        available: map['available'] as bool? ?? false,
        reason: map['reason'] as String?,
      );
    } on PlatformException catch (error) {
      throw NamiAiException(
        code: error.code,
        message: error.message ?? 'Fehler bei der iOS-Verfügbarkeitsprüfung.',
        details: error.details,
      );
    } on NamiAiException {
      rethrow;
    } catch (error) {
      throw NamiAiException(
        code: 'unknown',
        message: 'Unbekannter Fehler bei der Verfügbarkeitsprüfung: $error',
        details: error,
      );
    }
  }
}

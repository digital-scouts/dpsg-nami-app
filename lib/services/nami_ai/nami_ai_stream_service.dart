import 'package:flutter/services.dart';

import 'nami_ai_service.dart';

/// One chunk of a streamed NaMi AI answer (specs/nami-ai-roadmap.md section 3.7): either a
/// partial (the growing answer text so far), a revising signal (section 3.12: the verifier pass
/// rejected an attempt and a retry is starting - the caller should replace the just-streamed,
/// rejected text with a brief "wird überprüft" state rather than silently overwriting it with a
/// new stream), or the final, grounding-gate-verified reply - sources/unclear/contextTruncated/
/// verificationFailed are only ever meaningful once the whole turn, including every tool call,
/// has finished, so they only ever arrive on the done chunk.
class NamiAiStreamChunk {
  const NamiAiStreamChunk.partial(this.text)
    : isDone = false,
      isRevising = false,
      reply = null;

  const NamiAiStreamChunk.revising()
    : isDone = false,
      isRevising = true,
      text = '',
      reply = null;

  NamiAiStreamChunk.done(NamiAiReply this.reply)
    : isDone = true,
      isRevising = false,
      text = reply.answer;

  final String text;
  final bool isDone;
  final bool isRevising;
  final NamiAiReply? reply;
}

/// Streaming counterpart of NamiAiService.generateReply, over the com.namiapp/nami_ai_stream
/// EventChannel (specs/nami-ai-roadmap.md section 3.7) instead of a plain MethodChannel.
class NamiAiStreamService {
  static const EventChannel _channel = EventChannel(
    'com.namiapp/nami_ai_stream',
  );

  Stream<NamiAiStreamChunk> respond({
    required String sessionId,
    required String prompt,
  }) async* {
    try {
      final events = _channel.receiveBroadcastStream(<String, dynamic>{
        'sessionId': sessionId,
        'prompt': prompt,
      });
      await for (final event in events) {
        yield _toChunk(event);
      }
    } on PlatformException catch (error) {
      throw NamiAiException(
        code: error.code,
        message: error.message ?? 'Fehler beim AI-Streaming.',
        details: error.details,
      );
    }
  }

  NamiAiStreamChunk _toChunk(Object? event) {
    if (event is! Map) {
      throw NamiAiException(
        code: 'empty_response',
        message: 'Leeres Streaming-Event von der iOS-AI.',
      );
    }
    final map = event.cast<Object?, Object?>();
    final type = map['type'] as String?;
    switch (type) {
      case 'partial':
        return NamiAiStreamChunk.partial(map['text'] as String? ?? '');
      case 'revising':
        return const NamiAiStreamChunk.revising();
      case 'done':
        final reply = NamiAiReply.tryFromMap(map);
        if (reply == null) {
          throw NamiAiException(
            code: 'empty_response',
            message: 'Leere Streaming-Endantwort von der iOS-AI.',
          );
        }
        return NamiAiStreamChunk.done(reply);
      default:
        throw NamiAiException(
          code: 'unknown',
          message: 'Unbekannter Streaming-Event-Typ: $type',
        );
    }
  }
}

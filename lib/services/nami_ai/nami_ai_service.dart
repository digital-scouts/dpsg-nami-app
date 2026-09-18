import 'package:flutter/services.dart';

class NamiAiException implements Exception {
  NamiAiException({required this.code, required this.message, this.details});

  final String code;
  final String message;
  final Object? details;

  @override
  String toString() => 'NamiAiException($code): $message';
}

/// A successful NamiAiService reply, including the context chunks the native side actually
/// grounded the answer in (useful for debugging, see NamiAiDebugLogService).
class NamiAiReply {
  const NamiAiReply({required this.answer, required this.contextChunks});

  final String answer;
  final List<String> contextChunks;
}

class NamiAiService {
  static const String _channelName = 'com.namiapp/nami_ai';
  static const MethodChannel _channel = MethodChannel(_channelName);

  Future<NamiAiReply> generateReply(String prompt) async {
    try {
      final dynamic result = await _channel.invokeMethod<dynamic>(
        'generateReply',
        <String, dynamic>{'prompt': prompt},
      );
      if (result is! Map) {
        throw NamiAiException(
          code: 'empty_response',
          message: 'Die iOS-Antwort war leer.',
        );
      }
      final map = result.cast<Object?, Object?>();
      final answer = map['answer'] as String?;
      if (answer == null) {
        throw NamiAiException(
          code: 'empty_response',
          message: 'Die iOS-Antwort war leer.',
        );
      }
      final contextChunks =
          (map['contextChunks'] as List?)?.cast<String>() ?? const <String>[];
      return NamiAiReply(answer: answer, contextChunks: contextChunks);
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
}

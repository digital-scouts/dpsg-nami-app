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

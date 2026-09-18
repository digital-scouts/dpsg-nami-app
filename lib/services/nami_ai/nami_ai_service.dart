import 'package:flutter/services.dart';

class NamiAiException implements Exception {
  NamiAiException({required this.code, required this.message, this.details});

  final String code;
  final String message;
  final Object? details;

  @override
  String toString() => 'NamiAiException($code): $message';
}

class NamiAiService {
  static const String _channelName = 'com.namiapp/nami_ai';
  static const MethodChannel _channel = MethodChannel(_channelName);

  Future<String> generateReply(String prompt) async {
    try {
      final dynamic result = await _channel.invokeMethod<String>(
        'generateReply',
        <String, dynamic>{'prompt': prompt},
      );
      if (result == null) {
        throw NamiAiException(
          code: 'empty_response',
          message: 'Die iOS-Antwort war leer.',
        );
      }
      return result;
    } on PlatformException catch (error) {
      throw NamiAiException(
        code: error.code,
        message: error.message ?? 'Fehler beim Aufruf der iOS-AI.',
        details: error.details,
      );
    } catch (error) {
      throw NamiAiException(
        code: 'unknown',
        message: 'Unbekannter Fehler beim AI-Aufruf: $error',
        details: error,
      );
    }
  }
}

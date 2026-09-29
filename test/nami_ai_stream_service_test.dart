import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nami/services/nami_ai/nami_ai_service.dart';
import 'package:nami/services/nami_ai/nami_ai_stream_service.dart';

/// Emits a fixed sequence of EventChannel events, mirroring what NamiAiStreamHandler sends on
/// the native side (see ios/Runner/NamiAiStreamHandler.swift). Note: plain (non-widget) `test()`
/// bodies can drive EventChannel.receiveBroadcastStream() via `await for` without issue - the
/// FakeAsync incompatibility documented in nami_ai_chat_page_test.dart is specific to
/// testWidgets bodies.
class _ScriptedStreamHandler extends MockStreamHandler {
  _ScriptedStreamHandler(this.events);

  final List<Map<String, Object?>> events;

  @override
  void onListen(Object? arguments, MockStreamHandlerEventSink events) {
    for (final event in this.events) {
      events.success(event);
    }
    events.endOfStream();
  }

  @override
  void onCancel(Object? arguments) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = EventChannel('com.namiapp/nami_ai_stream');
  final service = NamiAiStreamService();

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(channel, null);
  });

  test('respond maps partial events to growing-text chunks', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(
          channel,
          _ScriptedStreamHandler([
            {'type': 'partial', 'text': 'Die'},
            {'type': 'partial', 'text': 'Die Antwort'},
            {
              'type': 'done',
              'answer': 'Die Antwort',
              'contextChunks': <String>[],
            },
          ]),
        );

    final chunks = await service
        .respond(sessionId: 'session-1', prompt: 'Frage')
        .toList();

    expect(chunks, hasLength(3));
    expect(chunks[0].isDone, isFalse);
    expect(chunks[0].isRevising, isFalse);
    expect(chunks[0].text, 'Die');
    expect(chunks[1].text, 'Die Antwort');
    expect(chunks[2].isDone, isTrue);
    expect(chunks[2].reply?.answer, 'Die Antwort');
  });

  test('respond maps a revising event without text or reply', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(
          channel,
          _ScriptedStreamHandler([
            {'type': 'partial', 'text': 'Erster, verworfener Text'},
            {'type': 'revising'},
            {
              'type': 'done',
              'answer': 'Korrigierte Antwort',
              'contextChunks': <String>[],
              'verificationFailed': false,
            },
          ]),
        );

    final chunks = await service
        .respond(sessionId: 'session-1', prompt: 'Frage')
        .toList();

    expect(chunks, hasLength(3));
    expect(chunks[1].isRevising, isTrue);
    expect(chunks[1].isDone, isFalse);
    expect(chunks[1].text, isEmpty);
    expect(chunks[2].reply?.answer, 'Korrigierte Antwort');
    expect(chunks[2].reply?.verificationFailed, isFalse);
  });

  test(
    'respond surfaces verificationFailed/verificationAttempts on the done chunk',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockStreamHandler(
            channel,
            _ScriptedStreamHandler([
              {
                'type': 'done',
                'answer': 'Letzter Versuch, immer noch nicht ok',
                'contextChunks': <String>[],
                'verificationFailed': true,
                'verificationAttempts': [
                  {
                    'attemptNumber': 3,
                    'answer': 'Letzter Versuch, immer noch nicht ok',
                    'passed': false,
                    'feedback': 'enthält Zusatzinfos',
                  },
                ],
              },
            ]),
          );

      final chunks = await service
          .respond(sessionId: 'session-1', prompt: 'Frage')
          .toList();

      final reply = chunks.single.reply!;
      expect(reply.verificationFailed, isTrue);
      expect(reply.verificationAttempts, hasLength(1));
      expect(reply.verificationAttempts.single.attemptNumber, 3);
      expect(reply.verificationAttempts.single.passed, isFalse);
    },
  );

  test('respond throws NamiAiException on an unknown event type', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(
          channel,
          _ScriptedStreamHandler([
            {'type': 'unerwartet'},
          ]),
        );

    expect(
      service.respond(sessionId: 'session-1', prompt: 'Frage').toList(),
      throwsA(isA<NamiAiException>()),
    );
  });
}

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nami/services/nami_ai/nami_ai_service.dart';

void main() {
  const channel = MethodChannel('com.namiapp/nami_ai');
  final service = NamiAiService();
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
    'generateReply sends prompt and sessionId to native channel and returns answer with context',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            expect(call.method, 'generateReply');
            expect(call.arguments, isA<Map>());
            final args = call.arguments as Map<dynamic, dynamic>;
            expect(args['prompt'], 'Hallo');
            expect(args['sessionId'], 'session-1');
            return {
              'answer': 'Antwort von iOS',
              'contextChunks': ['18. Chunk eins', '19. Chunk zwei'],
              'sources': [
                {
                  'docTitle': 'Satzung Stamm',
                  'sectionNumber': '24',
                  'docStand': 'Mai 2024',
                },
              ],
              'unclear': false,
              'contextTruncated': true,
              'verificationFailed': true,
              'verificationAttempts': [
                {
                  'attemptNumber': 1,
                  'answer': 'Erster Versuch',
                  'expectedIntent': 'Liste',
                  'intentMatches': false,
                  'factsSupportedBySources': true,
                  'containsIrrelevantInformation': false,
                  'passed': false,
                  'feedback': 'sollte eine Liste sein',
                  'retryReason':
                      'Antwortform passt nicht zum erwarteten Typ (Liste)',
                },
              ],
            };
          });

      final result = await service.generateReply(
        'Hallo',
        sessionId: 'session-1',
      );

      expect(result.answer, 'Antwort von iOS');
      expect(result.contextChunks, ['18. Chunk eins', '19. Chunk zwei']);
      expect(result.sources, hasLength(1));
      expect(result.sources.single.docTitle, 'Satzung Stamm');
      expect(result.unclear, isFalse);
      expect(result.contextTruncated, isTrue);
      expect(result.verificationFailed, isTrue);
      expect(result.verificationAttempts, hasLength(1));
      expect(result.verificationAttempts.single.attemptNumber, 1);
      expect(result.verificationAttempts.single.expectedIntent, 'Liste');
      expect(result.verificationAttempts.single.intentMatches, isFalse);
      expect(
        result.verificationAttempts.single.retryReason,
        'Antwortform passt nicht zum erwarteten Typ (Liste)',
      );
    },
  );

  test(
    'generateReply defaults verificationFailed/verificationAttempts when native payload omits them',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            return {
              'answer': 'Antwort ohne Verifier-Feld (altes Payload)',
              'contextChunks': <String>[],
            };
          });

      final result = await service.generateReply(
        'Hallo',
        sessionId: 'session-1',
      );

      expect(result.verificationFailed, isFalse);
      expect(result.verificationAttempts, isEmpty);
    },
  );

  test('generateReply throws NamiAiException on platform error', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          throw PlatformException(
            code: 'ai_error',
            message: 'Native AI nicht verfügbar',
          );
        });

    expect(
      service.generateReply('Test', sessionId: 'session-1'),
      throwsA(
        isA<NamiAiException>().having(
          (error) => error.message,
          'message',
          contains('Native AI nicht verfügbar'),
        ),
      ),
    );
  });

  test(
    'startSession sends startChatSession and returns the sessionId',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            expect(call.method, 'startChatSession');
            expect(call.arguments, isA<Map>());
            final args = call.arguments as Map<dynamic, dynamic>;
            expect(args['selfCorrectionEnabled'], isA<bool>());
            return {'sessionId': 'session-42'};
          });

      final sessionId = await service.startSession();

      expect(sessionId, 'session-42');
    },
  );

  test('startSession throws NamiAiException on platform error', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          throw PlatformException(
            code: 'ai_device_not_eligible',
            message: 'Gerät nicht geeignet',
          );
        });

    expect(service.startSession(), throwsA(isA<NamiAiException>()));
  });

  test('endSession sends endChatSession with the sessionId', () async {
    String? receivedSessionId;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'endChatSession');
          final args = call.arguments as Map<dynamic, dynamic>;
          receivedSessionId = args['sessionId'] as String?;
          return null;
        });

    await service.endSession('session-42');

    expect(receivedSessionId, 'session-42');
  });

  test('endSession swallows platform errors', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          throw PlatformException(code: 'unknown', message: 'egal');
        });

    await expectLater(service.endSession('session-42'), completes);
  });

  test(
    'checkAvailability returns available true from native channel',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            expect(call.method, 'checkAvailability');
            return {'available': true};
          });

      final result = await service.checkAvailability();

      expect(result.available, isTrue);
      expect(result.reason, isNull);
    },
  );

  test(
    'checkAvailability returns available false with reason from native channel',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            return {'available': false, 'reason': 'ai_device_not_eligible'};
          });

      final result = await service.checkAvailability();

      expect(result.available, isFalse);
      expect(result.reason, 'ai_device_not_eligible');
    },
  );
}

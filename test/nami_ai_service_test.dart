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
    'generateReply sends prompt to native channel and returns answer with context',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            expect(call.method, 'generateReply');
            expect(call.arguments, isA<Map>());
            final args = call.arguments as Map<dynamic, dynamic>;
            expect(args['prompt'], 'Hallo');
            return {
              'answer': 'Antwort von iOS',
              'contextChunks': ['18. Chunk eins', '19. Chunk zwei'],
            };
          });

      final result = await service.generateReply('Hallo');

      expect(result.answer, 'Antwort von iOS');
      expect(result.contextChunks, ['18. Chunk eins', '19. Chunk zwei']);
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
      service.generateReply('Test'),
      throwsA(
        isA<NamiAiException>().having(
          (error) => error.message,
          'message',
          contains('Native AI nicht verfügbar'),
        ),
      ),
    );
  });
}

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nami/presentation/theme/app_haptik.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<Object?> gesendet;
  late List<String> beobachtet;

  setUp(() {
    gesendet = [];
    beobachtet = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            gesendet.add(call.arguments);
          }
          return null;
        });
    AppHaptik.beobachter = beobachtet.add;
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
    AppHaptik.beobachter = null;
  });

  final faelle = <String, (Future<void> Function(), String)>{
    'auswahl': (AppHaptik.auswahl, 'HapticFeedbackType.selectionClick'),
    'anheben': (AppHaptik.anheben, 'HapticFeedbackType.mediumImpact'),
    'ablegen': (AppHaptik.ablegen, 'HapticFeedbackType.lightImpact'),
    'erfolg': (AppHaptik.erfolg, 'HapticFeedbackType.successNotification'),
    'fehler': (AppHaptik.fehler, 'HapticFeedbackType.errorNotification'),
  };

  for (final MapEntry(key: bedeutung, value: (aufruf, typ)) in faelle.entries) {
    test('$bedeutung sendet $typ und meldet sich beim Beobachter', () async {
      await aufruf();
      expect(gesendet, [typ]);
      expect(beobachtet, [bedeutung]);
    });
  }
}

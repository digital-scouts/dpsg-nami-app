import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nami/services/supporter/supporter_env.dart';

void main() {
  test('Store-Anbindung ist ohne Eintrag aus', () {
    dotenv.loadFromString(envString: '', isOptional: true);
    expect(SupporterEnv.storeEnabled, isFalse);

    dotenv.loadFromString(envString: 'SUPPORTER_STORE_ENABLED=');
    expect(SupporterEnv.storeEnabled, isFalse);
  });

  test('Store-Anbindung laesst sich einschalten', () {
    dotenv.loadFromString(envString: 'SUPPORTER_STORE_ENABLED=true');
    expect(SupporterEnv.storeEnabled, isTrue);
  });
}

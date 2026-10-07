import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nami/presentation/theme/schrift_lizenzen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Lizenzseite enthält WorkSans (OFL) und Roboto (Apache-2.0)', () async {
    registriereSchriftlizenzen();

    final eintraege = await LicenseRegistry.licenses.toList();
    String text(String paket) => eintraege
        .where((e) => e.packages.contains(paket))
        .expand((e) => e.paragraphs)
        .map((p) => p.text)
        .join('\n');

    expect(text('WorkSans'), contains('SIL Open Font License'));
    expect(text('Roboto'), contains('Apache License'));
  });
}

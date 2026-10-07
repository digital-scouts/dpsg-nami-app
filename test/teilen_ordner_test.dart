import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nami/services/teilen_ordner.dart';

void main() {
  late Directory temp;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('teilen_ordner_');
  });

  tearDown(() async {
    if (await temp.exists()) {
      await temp.delete(recursive: true);
    }
  });

  test('legt den Teilen-Ordner im Temp-Verzeichnis an', () async {
    final ordner = await TeilenOrdner.verzeichnis(temp: () async => temp);

    expect(ordner.path, '${temp.path}/teilen');
    expect(await ordner.exists(), isTrue);
  });

  test('leeren entfernt Ordner und Altdateien, sonst nichts', () async {
    final ordner = await TeilenOrdner.verzeichnis(temp: () async => temp);
    await File('${ordner.path}/efz_antrag_7.pdf').writeAsString('pdf');
    final altPdf = File('${temp.path}/efz_antrag_8.pdf');
    final altLog = File('${temp.path}/nami-app-log_2026-10-07_2200.log');
    final fremd = File('${temp.path}/fremd.txt');
    for (final datei in [altPdf, altLog, fremd]) {
      await datei.writeAsString('x');
    }

    await TeilenOrdner.leeren(temp: () async => temp);

    expect(await ordner.exists(), isFalse);
    expect(await altPdf.exists(), isFalse);
    expect(await altLog.exists(), isFalse);
    expect(await fremd.exists(), isTrue);
  });

  test('leeren wirft nicht, wenn nichts da ist', () async {
    await temp.delete(recursive: true);

    await TeilenOrdner.leeren(temp: () async => temp);
  });
}

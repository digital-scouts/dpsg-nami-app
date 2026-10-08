import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nami/domain/appearance/appearance_catalog.dart';

/// `AppIconChoice.key` ist zugleich der Icon-Name auf iOS und Android. Beim
/// Umbenennen eines Pakets muessen Manifest, Icon-Kanal, Xcode-Projekt und
/// Vorschaubilder mitwandern, sonst schlaegt der Icon-Wechsel still fehl.
void main() {
  final manifest = File(
    'android/app/src/main/AndroidManifest.xml',
  ).readAsStringSync();
  final channel = File(
    'android/app/src/main/java/de/jlange/nami/app/AppIconChannel.java',
  ).readAsStringSync();
  final pbxproj = File(
    'ios/Runner.xcodeproj/project.pbxproj',
  ).readAsStringSync();
  final iosNames = RegExp(
    r'ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES = "([^"]*)"',
  ).allMatches(pbxproj).map((m) => m.group(1)!.split(' ').toSet()).toList();

  final choices = [
    for (final package in AppIconPackage.values)
      for (final variant in AppIconVariant.values)
        AppIconChoice(package, variant),
  ];

  test('Android kennt jedes Icon ausser Automatisch', () {
    for (final choice in choices) {
      if (choice.variant == AppIconVariant.automatisch) {
        continue;
      }
      final resource =
          'ic_launcher_${choice.package.name}_${choice.variant.name}';
      expect(manifest, contains('.Icon${choice.key}"'), reason: choice.key);
      expect(manifest, contains('@mipmap/$resource"'), reason: choice.key);
      expect(channel, contains('"${choice.key}"'), reason: choice.key);
      expect(
        File(
          'android/app/src/main/res/mipmap-anydpi-v26/$resource.xml',
        ).existsSync(),
        isTrue,
        reason: resource,
      );
    }
  });

  test('iOS kennt jedes Icon in allen Build-Konfigurationen', () {
    expect(iosNames, isNotEmpty);
    for (final choice in choices) {
      for (final names in iosNames) {
        expect(names, contains(choice.key));
      }
      expect(
        File('ios/Runner/${choice.key}.icon/icon.json').existsSync(),
        isTrue,
        reason: choice.key,
      );
    }
  });

  test('jedes Icon hat ein Vorschaubild', () {
    for (final choice in choices) {
      if (choice.variant == AppIconVariant.automatisch) {
        continue;
      }
      expect(
        File('assets/supporter/icons/${choice.key}.png').existsSync(),
        isTrue,
        reason: choice.key,
      );
    }
  });
}

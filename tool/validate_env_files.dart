import 'dart:io';

final _keyPattern = RegExp(r'^[A-Z][A-Z0-9_]*$');

void main(List<String> args) {
  final targetPath = args.isNotEmpty ? args[0] : '.env';
  final examplePath = args.length > 1 ? args[1] : '.env.example';

  final targetFile = File(targetPath);
  final exampleFile = File(examplePath);

  if (!targetFile.existsSync()) {
    stderr.writeln('$targetPath nicht gefunden.');
    exit(1);
  }
  if (!exampleFile.existsSync()) {
    stderr.writeln('$examplePath nicht gefunden.');
    exit(1);
  }

  final targetKeys = _readKeys(targetFile);
  final exampleKeys = _readKeys(exampleFile);

  final missingInTarget = exampleKeys.difference(targetKeys);
  final extraInTarget = targetKeys.difference(exampleKeys);

  if (missingInTarget.isNotEmpty || extraInTarget.isNotEmpty) {
    stderr.writeln('Env-Dateien sind nicht konsistent.');
    stderr.writeln('Ziel: $targetPath');
    stderr.writeln('Vorlage: $examplePath');

    if (missingInTarget.isNotEmpty) {
      stderr.writeln(
        'Fehlende Keys in $targetPath: ${missingInTarget.toList()..sort()}',
      );
    }
    if (extraInTarget.isNotEmpty) {
      stderr.writeln(
        'Ueberzaehlige Keys in $targetPath: ${extraInTarget.toList()..sort()}',
      );
    }
    exit(1);
  }

  stdout.writeln(
    'Env-Dateien sind konsistent: $targetPath entspricht den Keys aus $examplePath',
  );
}

Set<String> _readKeys(File file) {
  final keys = <String>{};

  for (final rawLine in file.readAsLinesSync()) {
    final line = rawLine.trim();
    if (line.isEmpty || line.startsWith('#')) {
      continue;
    }

    final separatorIndex = line.indexOf('=');
    if (separatorIndex <= 0) {
      stderr.writeln('Ungueltige Env-Zeile in ${file.path}: $rawLine');
      exit(1);
    }

    final key = line.substring(0, separatorIndex).trim();
    if (!_keyPattern.hasMatch(key)) {
      stderr.writeln('Ungueltiger Env-Key in ${file.path}: $key');
      exit(1);
    }

    if (!keys.add(key)) {
      stderr.writeln('Doppelter Env-Key in ${file.path}: $key');
      exit(1);
    }
  }

  return keys;
}

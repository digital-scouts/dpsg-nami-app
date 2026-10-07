import 'dart:io';

/// Pfade, die typischerweise Mitschnitte echter API-Antworten enthalten und
/// deshalb nie versioniert werden duerfen.
final forbiddenPathPatterns = <RegExp>[
  RegExp(r'\.postman_(collection|environment)\.json$', caseSensitive: false),
  RegExp(r'\.har$', caseSensitive: false),
  RegExp(r'\.xcappdata(/|$)', caseSensitive: false),
  RegExp(r'^specs/demoResponse/'),
];

List<String> findForbiddenPaths(Iterable<String> paths) {
  return paths
      .where((path) => forbiddenPathPatterns.any((p) => p.hasMatch(path)))
      .toSet()
      .toList()
    ..sort();
}

/// Prueft den Index und mit `--history` zusaetzlich alle Pfade, die jemals in
/// einem erreichbaren Commit hinzugefuegt wurden.
void main(List<String> args) {
  final checkHistory = args.contains('--history');

  final trackedHits = findForbiddenPaths(_gitPaths(['ls-files', '-z']));
  if (trackedHits.isNotEmpty) {
    stderr.writeln(
      'Fehler: Diese Dateien duerfen nicht versioniert werden, weil sie '
      'typischerweise Mitschnitte echter API-Antworten enthalten:',
    );
    trackedHits.forEach(stderr.writeln);
    stderr.writeln(
      'Entferne sie aus dem Index, zum Beispiel mit: git rm --cached -- <datei>',
    );
    stderr.writeln('Nutze fuer Tests synthetische Fixtures.');
    exit(1);
  }

  if (checkHistory) {
    final historyHits = findForbiddenPaths(
      _gitPaths([
        'log',
        '--all',
        '--diff-filter=A',
        '--name-only',
        '--format=',
        '-z',
      ]),
    );
    if (historyHits.isNotEmpty) {
      stderr.writeln(
        'Fehler: Diese gesperrten Pfade kommen in der Git-Historie vor:',
      );
      historyHits.forEach(stderr.writeln);
      stderr.writeln(
        'Vermutlich basiert ein Branch auf einem Stand vor der '
        'Historienbereinigung. Setze ihn auf den aktuellen develop-Stand neu '
        'auf, statt die alte Historie zu mergen.',
      );
      exit(1);
    }
  }

  stdout.writeln(
    checkHistory
        ? 'Keine gesperrten Pfade im Index und in der Historie.'
        : 'Keine gesperrten Pfade im Index.',
  );
}

Iterable<String> _gitPaths(List<String> args) {
  final result = Process.runSync('git', args);
  if (result.exitCode != 0) {
    stderr.writeln('git ${args.join(' ')} fehlgeschlagen: ${result.stderr}');
    exit(1);
  }

  return (result.stdout as String)
      .split(RegExp(r'[\x00\n]'))
      .where((path) => path.isNotEmpty);
}

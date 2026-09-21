import 'dart:convert';
import 'dart:io';

final _versionPattern = RegExp(r'^(\d+)\.(\d+)\.(\d+)(?:[-+].*)?$');

void main() {
  final pubspecFile = File('pubspec.yaml');
  final changelogFile = File('assets/changelog.json');

  if (!pubspecFile.existsSync()) {
    stderr.writeln('pubspec.yaml nicht gefunden.');
    exit(1);
  }
  if (!changelogFile.existsSync()) {
    stderr.writeln('assets/changelog.json nicht gefunden.');
    exit(1);
  }

  final pubspecVersion = _readPubspecVersion(pubspecFile.readAsStringSync());
  final changelogVersion = _readHighestChangelogVersion(
    changelogFile.readAsStringSync(),
  );

  if (pubspecVersion == null) {
    stderr.writeln('Konnte keine gueltige Version in pubspec.yaml lesen.');
    exit(1);
  }
  if (changelogVersion == null) {
    stderr.writeln(
      'Konnte keine gueltige Version in assets/changelog.json lesen.',
    );
    exit(1);
  }

  final pubspecReleaseVersion = _stripBuildMetadata(pubspecVersion);
  if (pubspecReleaseVersion != changelogVersion.raw) {
    stderr.writeln('Versionskonflikt erkannt.');
    stderr.writeln('pubspec.yaml: $pubspecVersion');
    stderr.writeln(
      'assets/changelog.json (hoechste Version): ${changelogVersion.raw}',
    );
    stderr.writeln(
      'Bitte gleiche pubspec.yaml und assets/changelog.json vor dem Commit an.',
    );
    exit(1);
  }

  stdout.writeln(
    'Versionen sind konsistent: pubspec=$pubspecVersion, changelog=${changelogVersion.raw}',
  );
}

String? _readPubspecVersion(String pubspecContent) {
  final match = RegExp(
    r'^version:\s*([^\s#]+)\s*$',
    multiLine: true,
  ).firstMatch(pubspecContent);
  final value = match?.group(1);
  if (value == null) {
    return null;
  }
  return _versionPattern.hasMatch(value) ? value : null;
}

_SemVer? _readHighestChangelogVersion(String changelogContent) {
  final decoded = jsonDecode(changelogContent);
  if (decoded is! Map<String, dynamic>) {
    return null;
  }
  final versions = decoded['versions'];
  if (versions is! List) {
    return null;
  }

  _SemVer? highest;
  for (final entry in versions) {
    if (entry is! Map<String, dynamic>) {
      continue;
    }
    final value = entry['version'];
    if (value is! String) {
      continue;
    }
    final parsed = _SemVer.tryParse(value);
    if (parsed == null) {
      continue;
    }
    if (highest == null || parsed.compareTo(highest) > 0) {
      highest = parsed;
    }
  }
  return highest;
}

String _stripBuildMetadata(String version) {
  return version.split('+').first;
}

class _SemVer implements Comparable<_SemVer> {
  const _SemVer(this.major, this.minor, this.patch, this.raw);

  final int major;
  final int minor;
  final int patch;
  final String raw;

  static _SemVer? tryParse(String input) {
    final match = _versionPattern.firstMatch(input);
    if (match == null) {
      return null;
    }
    return _SemVer(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
      input,
    );
  }

  @override
  int compareTo(_SemVer other) {
    final majorCompare = major.compareTo(other.major);
    if (majorCompare != 0) {
      return majorCompare;
    }
    final minorCompare = minor.compareTo(other.minor);
    if (minorCompare != 0) {
      return minorCompare;
    }
    return patch.compareTo(other.patch);
  }
}

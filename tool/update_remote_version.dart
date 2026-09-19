import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  if (args.length != 2) {
    stderr.writeln(
      'Verwendung: dart tool/update_remote_version.dart <android|ios> <version>',
    );
    exit(1);
  }

  final platform = args[0];
  final version = args[1];
  if (platform != 'android' && platform != 'ios') {
    stderr.writeln('Ungueltige Plattform: $platform');
    exit(1);
  }

  final file = File('docs/version.json');
  if (!file.existsSync()) {
    stderr.writeln('docs/version.json nicht gefunden.');
    exit(1);
  }

  final decoded = jsonDecode(file.readAsStringSync());
  if (decoded is! Map<String, dynamic>) {
    stderr.writeln('docs/version.json hat ein ungueltiges Format.');
    exit(1);
  }

  final platformEntry = decoded[platform];
  if (platformEntry is! Map<String, dynamic>) {
    stderr.writeln(
      'Eintrag fuer Plattform $platform fehlt in docs/version.json.',
    );
    exit(1);
  }

  platformEntry['latest'] = version;

  const encoder = JsonEncoder.withIndent('  ');
  file.writeAsStringSync('${encoder.convert(decoded)}\n');
  stdout.writeln('docs/version.json fuer $platform auf $version aktualisiert.');
}

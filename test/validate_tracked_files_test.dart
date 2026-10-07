import 'package:flutter_test/flutter_test.dart';

import '../tool/validate_tracked_files.dart' show findForbiddenPaths;

void main() {
  group('findForbiddenPaths', () {
    test('reports Postman, HAR and xcappdata captures', () {
      expect(
        findForbiddenPaths([
          'specs/Nami.postman_collection.json',
          'local.postman_environment.json',
          'logs/session.HAR',
          'ios/Runner.xcappdata/AppData/Documents/log.json',
        ]),
        [
          'ios/Runner.xcappdata/AppData/Documents/log.json',
          'local.postman_environment.json',
          'logs/session.HAR',
          'specs/Nami.postman_collection.json',
        ],
      );
    });

    test('reports files below specs/demoResponse', () {
      expect(findForbiddenPaths(['specs/demoResponse/people.json']), [
        'specs/demoResponse/people.json',
      ]);
    });

    test('allows regular project files and OpenAPI specs', () {
      expect(
        findForbiddenPaths([
          'lib/main.dart',
          'specs/hitobito_openapi.yaml',
          'specs/hitobito-analyse.md',
          'test/fixtures/people.json',
          'assets/changelog.json',
          'docs/harness.md',
        ]),
        isEmpty,
      );
    });

    test('returns each path once', () {
      expect(findForbiddenPaths(['a.har', 'a.har']), ['a.har']);
    });
  });
}

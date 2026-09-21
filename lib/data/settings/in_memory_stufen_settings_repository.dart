import 'dart:async';

import 'package:nami/domain/stufe/altersgrenzen.dart';
import 'package:nami/domain/stufe/stufen_settings_repository.dart';

class InMemoryStufenSettingsRepository implements StufenSettingsRepository {
  Altersgrenzen _current = StufenDefaults.build();
  final _controller = StreamController<Altersgrenzen>.broadcast();

  @override
  Future<Altersgrenzen> load() async => _current;

  @override
  Future<void> save(Altersgrenzen grenzen) async {
    _current = grenzen;
    _controller.add(_current);
  }

  @override
  Stream<Altersgrenzen> watch() => _controller.stream;
}

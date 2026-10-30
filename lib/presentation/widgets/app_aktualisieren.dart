import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_haptik.dart';

/// Ziehen zum Aktualisieren, unter iOS mit dem Cupertino-Kreisel (#281).
/// Das Auslösen ist spürbar, und der Indikator steht, bis [onRefresh] fertig
/// ist, höchstens aber [obergrenze]. Danach übernimmt die Ladeleiste oben.
class AppAktualisieren extends StatelessWidget {
  const AppAktualisieren({
    super.key,
    required this.onRefresh,
    required this.child,
    this.obergrenze,
  });

  final Future<void> Function() onRefresh;
  final Duration? obergrenze;
  final Widget child;

  Future<void> _aktualisieren() {
    unawaited(AppHaptik.auswahl());
    final laden = onRefresh();
    final grenze = obergrenze;
    if (grenze == null) {
      return laden;
    }
    final fertig = Completer<void>();
    final timer = Timer(grenze, () {
      if (!fertig.isCompleted) fertig.complete();
    });
    laden.then(
      (_) {
        timer.cancel();
        if (!fertig.isCompleted) fertig.complete();
      },
      onError: (Object fehler, StackTrace stack) {
        timer.cancel();
        if (!fertig.isCompleted) fertig.completeError(fehler, stack);
      },
    );
    return fertig.future;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator.adaptive(onRefresh: _aktualisieren, child: child);
  }
}

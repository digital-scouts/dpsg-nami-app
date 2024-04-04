import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';

/// Logger for sensitive data
///
/// Uses [consLog] for console output and a logger for file output
late final Logger sensLog;

/// Logger for console output only, may contain sensitive data
late final Logger consLog;
late final File _file;

initLogger() async {
  if (kReleaseMode) {
    _file = File('${(await getApplicationDocumentsDirectory()).path}/prod.log');
  } else {
    _file =
        File('${(await getApplicationDocumentsDirectory()).path}/p9234234.log');
  }
  sensLog = Logger(
    filter: AllFilter(),
    printer: CustomPrinter(),
    output: NoOutput(),
  );
  consLog = Logger(
    level: Level.debug,
    filter: ProductionFilter(),
    output: ConsoleOutput(),
    printer: PrettyPrinter(
      printTime: true,
      methodCount: 0,
      printEmojis: false,
      excludeBox: {
        Level.trace: true,
        Level.debug: true,
        Level.info: true,
        Level.warning: true,
      },
    ),
  );
}

class AllFilter extends LogFilter {
  @override
  bool shouldLog(LogEvent event) {
    return true;
  }
}

class CustomPrinter extends LogPrinter {
  final fileLogger = Logger(
    level: Level.all,
    filter: ProductionFilter(),
    output: FileOutput(file: _file),
    printer: LogfmtPrinter(),
  );

  @override
  Future<void> init() async {}

  @override
  List<String> log(LogEvent event) {
    fileLogger.log(
      event.level,
      {
        "msg": event.message,
        "time": event.time,
      },
      time: event.time,
      error: event.error,
      stackTrace: event.stackTrace,
    );
    consLog.log(
      event.level,
      event.message,
      time: event.time,
      error: event.error,
      stackTrace: event.stackTrace,
    );

    return [];
  }

  @override
  Future<void> destroy() async {}
}

class NoOutput extends LogOutput {
  @override
  void output(OutputEvent event) {}
}

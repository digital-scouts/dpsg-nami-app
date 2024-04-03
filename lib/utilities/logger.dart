import 'dart:io';
import 'dart:developer' as dev;
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';

late final Logger log;
late final File _logFile;
initLogger() async {
  _logFile =
      File('${(await getApplicationDocumentsDirectory()).path}/nami.log');
  await _logFile.create(recursive: true);
  log = Logger(
    filter: ProductionFilter(),
    output: CustomOutput(),
    level: Level.all,
    printer: PrettyPrinter(
      printTime: true,
      methodCount: 0,
      printEmojis: false,
      excludeBox: {
        Level.trace: true,
        Level.info: true,
        Level.warning: true,
      },
    ),
  );
}

class CustomOutput extends LogOutput {
  final fileOutput = FileOutput(file: _logFile);
  final consoleOutput = ConsoleOutput();

  @override
  Future<void> init() async {
    await fileOutput.init();
    await consoleOutput.init();
  }

  @override
  void output(OutputEvent event) {
    fileOutput.output(event);
    consoleOutput.output(event);
  }

  @override
  Future<void> destroy() async {
    await fileOutput.init();
    await consoleOutput.init();
  }
}

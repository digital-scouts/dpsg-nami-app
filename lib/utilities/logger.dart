import 'dart:io';
import 'dart:developer' as dev;
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logger/logger.dart';
import 'package:nami/utilities/helper_functions.dart';
import 'package:nami/utilities/nami/model/nami_member_details.model.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

/// Logger for sensitive data
///
/// Uses [consLog] for console output and a logger for file output
late final Logger sensLog;

/// Logger for sensitive data to file only
late final Logger fileLog;

/// Logger for console output only, may contain sensitive data
late final Logger consLog;
late final File loggingFile;
late final int salt;

Future<void> deleteOldLogs() async {
  try {
    final lines = await loggingFile.readAsLines();
    int toDelete = 0;
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final timeStart = line.indexOf(' time="20');
      final timeEnd = line.indexOf('"', timeStart + 7);
      final timestamp =
          DateTime.tryParse(line.substring(timeStart + 7, timeEnd));
      if (timestamp == null) continue;
      if (timestamp
          .isBefore(DateTime.now().subtract(const Duration(days: 30)))) {
        toDelete = i;
      } else {
        break;
      }
    }
    if (toDelete > 0) {
      lines.removeRange(0, toDelete + 1);
      await loggingFile.writeAsString(lines.join('\n'));
    }
  } catch (e) {
    debugPrint("Error in deleteOldLogs: $e");
  }
}

Future<void> initLogger() async {
  // Use a random salt to hash sensitive data to create different hashes for the same data on different devices
  const secureStorage = FlutterSecureStorage();
  final storedSalt = await secureStorage.read(key: 'salt');
  if (storedSalt == null) {
    final newSalt = Random.secure().nextInt(1 << 32);
    await secureStorage.write(key: 'salt', value: newSalt.toString());
    salt = newSalt;
  } else {
    salt = int.parse(storedSalt);
  }

  if (kReleaseMode) {
    loggingFile =
        File('${(await getApplicationDocumentsDirectory()).path}/prod.log');
  } else {
    loggingFile =
        File('${(await getApplicationDocumentsDirectory()).path}/dev.log');
  }
  await deleteOldLogs();
  sensLog = Logger(
    filter: AllFilter(),
    printer: CustomPrinter(),
    output: NoOutput(),
  );
  consLog = Logger(
    level: Level.debug,
    filter: ProductionFilter(),
    output: CustomOutput(),
    printer: PrettyPrinter(
      printTime: true,
      methodCount: 0,
      printEmojis: false,
      errorMethodCount: 10,
      excludeBox: {
        Level.trace: true,
        Level.debug: true,
        Level.info: true,
        Level.warning: true,
      },
    ),
  );
  fileLog = Logger(
    level: Level.all,
    filter: ProductionFilter(),
    output: FileOutput(file: loggingFile),
    printer: LogfmtPrinter(),
  );
  sensLog.i('Logger initialized');

  Future.wait([
    PackageInfo.fromPlatform(),
    getGitCommitId(),
  ]).then<void>(
    (value) {
      sensLog.i(
          'Version: ${(value[0] as PackageInfo).version} | Commit: ${value[1]}');
    },
    onError: (e, s) {
      sensLog.e('Error getting version and commit id', error: e, stackTrace: s);
    },
  );
}

class CustomOutput extends LogOutput {
  @override
  void output(OutputEvent event) {
    if (const bool.fromEnvironment('USE_LOGGING', defaultValue: false)) {
      final StringBuffer buffer = StringBuffer();
      event.lines.forEach(buffer.writeln);
      // They don't appear in the stdout of `flutter run`, but in the devtools logging view and IDE
      dev.log(buffer.toString());
    } else {
      // Group all lines of a single log event together
      debugPrintThrottled("LOG ${event.lines.first}");
      final restLines = event.lines.sublist(1);
      for (final line in restLines) {
        debugPrintThrottled("    $line");
      }
    }
  }
}

class AllFilter extends LogFilter {
  @override
  bool shouldLog(LogEvent event) {
    return true;
  }
}

class CustomPrinter extends LogPrinter {
  @override
  Future<void> init() async {}

  @override
  List<String> log(LogEvent event) {
    fileLog.log(event.level, {
      "msg": event.message?.toString().replaceAll('\n', '[CR]'),
      "time": event.time,
      "error": event.error?.toString().replaceAll('\n', '[CR]'),
      "stackTrace": event.stackTrace?.toString().replaceAll('\n', '[CR]'),
    });
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

String sensId(int memberId) {
  final res = md5.convert([memberId, salt]);
  return res.toString().substring(0, 6);
}

Map<String, String> sensMember(NamiMemberDetailsModel member) {
  return {
    'id': sensId(member.id),
    'type': member.mglTypeId,
    'status': member.status,
    'stufe': member.stufe ?? 'null',
  };
}

import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:nami/utilities/logger.dart';
import 'package:wiredash/wiredash.dart';

Future<bool> isWifi() async {
  final res = await Connectivity().checkConnectivity();
  return res.contains(ConnectivityResult.wifi);
}

Future<void> sendLogsEmail() async {
  FlutterEmailSender.send(
    Email(
      body:
          'Beschreibe dein Problem. Wie hat sich die App verhalten, was ist passiert? Was hättest du erwartet?',
      attachmentPaths: [loggingFile.path],
      subject: "NaMi App Logs",
      recipients: ["dev@janecklange.de"],
    ),
  );
}

void openWiredash(BuildContext context) {
  try {
    final logFile = File(loggingFile.path);
    logFile.readAsString().then((logs) {
      Wiredash.of(context).modifyMetaData(
        (metaData) => metaData..custom['logs'] = logs,
      );
      Wiredash.of(context).show(inheritMaterialTheme: true);
    });
  } catch (_) {
    Wiredash.of(context).show(inheritMaterialTheme: true);
  }
}

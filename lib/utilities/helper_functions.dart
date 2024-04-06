import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:nami/utilities/logger.dart';

Future<bool> isWifi() async {
  final res = await Connectivity().checkConnectivity();
  return res.contains(ConnectivityResult.wifi);
}

Future<void> sendLogsEmail() async {
  FlutterEmailSender.send(
    Email(
      attachmentPaths: [loggingFile.path],
      subject: "NaMi App Logs",
      recipients: ["dev@janecklange.de"],
    ),
  );
}

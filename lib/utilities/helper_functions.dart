import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:nami/utilities/hive/hive_service.dart';
import 'package:nami/utilities/hive/mitglied.dart';
import 'package:nami/utilities/hive/settings_service.dart';
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
      recipients: ["dev@jannecklange.de"],
    ),
  );
}

Future<String?> getGitCommitId() async {
  try {
    final head = await rootBundle.loadString('.gitlink/HEAD');

    if (head.startsWith('ref: ')) {
      final branchName = head.split('ref: refs/heads/').last.trim();
      return (await rootBundle.loadString(
        '.gitlink/refs/heads/$branchName',
      )).trim();
    } else {
      return head;
    }
  } catch (e) {
    return null;
  }
}

/// compare date1 with referenceDate, if referenceDate is null, use DateTime.now()
double getAlterAm({DateTime? referenceDate, required DateTime date}) {
  referenceDate ??= DateTime.now();

  // Berechne die Differenz in Tagen
  int daysDifference = referenceDate.difference(date).inDays;

  // Berechne das Alter als double
  double age = daysDifference / 365.25;

  return age;
}

Future<void> openWiredash(BuildContext context, String feedbackType) async {
  Mitglied? user;
  String gitInfo = await getGitCommitId() ?? 'unknown';
  try {
    user = hiveService.getAllMembers().firstWhere(
      (member) => member.mitgliedsNummer == settingsService.getNamiLoginId(),
    );
  } catch (_) {}

  WidgetsBinding.instance.addPostFrameCallback((_) {
    Wiredash.of(context).modifyMetaData(
      (metaData) => metaData
        ..custom['type'] = feedbackType
        ..custom['gitCommitId'] = gitInfo
        ..custom['userNamiLoginId'] = user != null
            ? sensId(getNamiLoginId()!)
            : null
        ..custom['user'] = '${user?.vorname} ${user?.nachname}'
        ..custom['userStatus'] = '${user?.status}'
        ..custom['gruppierungName'] = settingsService.getGruppierungName(),
    );

    Wiredash.of(context).show(inheritMaterialTheme: true);
  });
}

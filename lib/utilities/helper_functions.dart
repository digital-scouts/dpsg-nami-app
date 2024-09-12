import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:hive/hive.dart';
import 'package:nami/utilities/hive/mitglied.dart';
import 'package:nami/utilities/hive/settings.dart';
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
    final head = await rootBundle.loadString('.git/HEAD');

    if (head.startsWith('ref: ')) {
      final branchName = head.split('ref: refs/heads/').last.trim();
      return (await rootBundle.loadString('.git/refs/heads/$branchName'))
          .trim();
    } else {
      return head;
    }
  } catch (e) {
    return null;
  }
}

Future<void> openWiredash(BuildContext context) async {
  Box<Mitglied> memberBox = Hive.box<Mitglied>('members');
  Mitglied? user;
  String gitInfo = await getGitCommitId() ?? 'unknown';
  try {
    user = memberBox.values
        .firstWhere((member) => member.mitgliedsNummer == getNamiLoginId());
  } catch (_) {}

  WidgetsBinding.instance.addPostFrameCallback((_) {
    Wiredash.of(context).modifyMetaData((metaData) => metaData
      ..custom['gitCommitId'] = gitInfo
      ..custom['userNamiLoginId'] = sensId(getNamiLoginId()!)
      ..custom['user'] = '${user?.vorname} ${user?.nachname}'
      ..custom['userStatus'] = '${user?.status}'
      ..custom['gruppierungName'] = getGruppierungName());

    Wiredash.of(context).show(inheritMaterialTheme: true);
  });
}

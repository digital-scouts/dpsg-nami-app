import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:nami/domain/auth/auth_state.dart';
import 'package:nami/main.dart' show navigatorKey;
import 'package:nami/presentation/model/arbeitskontext_model.dart';
import 'package:nami/presentation/model/auth_session_model.dart';
import 'package:nami/presentation/screens/changelog_page.dart';
import 'package:provider/provider.dart';
import 'package:wiredash/wiredash.dart';

import '../../services/logger_service.dart';

class DebugToolsPage extends StatelessWidget {
  const DebugToolsPage({super.key});

  Future<void> sendLogsEmail(File file) async {
    final exists = await file.exists();
    if (!exists) {
      return;
    }
    try {
      FlutterEmailSender.send(
        Email(
          body:
              'Beschreibe dein Problem. Wie hat sich die App verhalten, was ist passiert? Was hättest du erwartet?',
          attachmentPaths: [file.path],
          subject: "NaMi App Logs",
          recipients: ["dev@jannecklange.de"],
        ),
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final logger = Provider.of<LoggerService>(context, listen: false);
    final authModel = context.watch<AuthSessionModel>();
    final arbeitskontextModel = context.read<ArbeitskontextModel>();
    return Scaffold(
      appBar: AppBar(title: const Text('Debug & Tools')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Log-Datei verwalten'),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () async {
                final file = await logger.getLogFile();
                await sendLogsEmail(file);
              },
              icon: const Icon(Icons.mail_outline),
              label: const Text('Log per Mail senden'),
            ),

            ElevatedButton.icon(
              onPressed: () async {
                final file = await logger.getLogFile();
                final exists = await file.exists();
                if (exists) {
                  await file.delete();
                }
                // Recreate empty file for continued logging
                await (await logger.getLogFile()).create(recursive: true);

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Logdatei gelöscht')),
                );
              },
              icon: const Icon(Icons.delete_outline),
              label: const Text('Logs löschen'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                final file = await logger.getLogFile();
                final exists = await file.exists();
                final content = exists ? await file.readAsString() : '';

                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => _LogViewerPage(content: content),
                  ),
                );
              },
              icon: const Icon(Icons.article_outlined),
              label: const Text('Log anzeigen'),
            ),

            const SizedBox(height: 20),
            const Text('Feedback senden'),
            const SizedBox(height: 8),

            ElevatedButton.icon(
              onPressed: () {
                final ctx = navigatorKey.currentContext;
                if (ctx != null) {
                  Wiredash.of(ctx).show(inheritMaterialTheme: true);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Wiredash konnte nicht gefunden werden (Root-Kontext fehlt).',
                      ),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.feedback_outlined),
              label: const Text('Feedback senden'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                final ctx = navigatorKey.currentContext;
                if (ctx != null) {
                  Wiredash.of(ctx).showPromoterSurvey(force: true);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Wiredash konnte nicht gefunden werden (Root-Kontext fehlt).',
                      ),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.star_outline),
              label: const Text('App bewerten'),
            ),

            const SizedBox(height: 20),
            const Text('Daten aktualisieren'),
            const SizedBox(height: 8),

            ElevatedButton.icon(
              onPressed: authModel.isSyncingHitobitoData
                  ? null
                  : () async {
                      await authModel.syncHitobitoData(
                        syncMembers: (accessToken) async {
                          await arbeitskontextModel.refreshFromRemote(
                            session: authModel.session,
                            profile: authModel.profile,
                          );
                        },
                        force: true,
                        trigger: 'debug_tools',
                      );

                      if (!context.mounted) {
                        return;
                      }

                      final messenger = ScaffoldMessenger.of(context);
                      final message =
                          authModel.state == AuthState.reloginRequired
                          ? 'Neuanmeldung erforderlich, Daten konnten nicht synchronisiert werden.'
                          : (authModel.errorMessage?.isNotEmpty == true
                                ? 'Hitobito-Daten konnten nicht vollständig synchronisiert werden.'
                                : 'Hitobito-Daten wurden synchronisiert.');
                      messenger.showSnackBar(SnackBar(content: Text(message)));
                    },
              icon: const Icon(Icons.refresh_outlined),
              label: const Text('Daten jetzt aktualisieren'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Nicht implementiert: Datenänderungen angezeigt',
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.visibility_outlined),
              label: const Text('Datenänderungen anzeigen'),
            ),

            const SizedBox(height: 20),
            const Text('Changelog anzeigen'),
            const SizedBox(height: 8),

            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ChangelogPage()),
                );
              },
              icon: const Icon(Icons.list_alt_outlined),
              label: const Text('Changelog anzeigen'),
            ),

            const SizedBox(height: 20),
            const Text('Mitteilungen'),
            const SizedBox(height: 8),

            ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/notifications'),
              icon: const Icon(Icons.notifications_outlined),
              label: const Text('Mitteilungen anzeigen'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LogViewerPage extends StatelessWidget {
  final String content;
  const _LogViewerPage({required this.content});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Logdatei anzeigen')),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: _ColoredLogView(content: content),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ColoredLogView extends StatelessWidget {
  final String content;
  const _ColoredLogView({required this.content});

  TextSpan _spanForLine(
    String line,
    TextStyle base, {
    required TextStyle tsStyle,
    required TextStyle catEventStyle,
    required TextStyle catWarnStyle,
    required TextStyle catErrorStyle,
    required TextStyle catServiceStyle,
    required TextStyle catDebugStyle,
    required TextStyle msgStyle,
  }) {
    final regex = RegExp(r"^\[(.*?)\]\s*(\[\w+\])?\s*(.*)$");
    final m = regex.firstMatch(line);
    if (m == null) {
      return TextSpan(text: line, style: msgStyle);
    }
    final ts = m.group(1) ?? '';
    final cat = m.group(2) ?? '';
    final msg = m.group(3) ?? '';

    TextStyle catStyle = msgStyle;
    if (cat.toLowerCase() == '[event]') {
      catStyle = catEventStyle;
    } else if (cat.toLowerCase() == '[warn]') {
      catStyle = catWarnStyle;
    } else if (cat.toLowerCase() == '[error]') {
      catStyle = catErrorStyle;
    } else if (cat.toLowerCase() == '[debug]') {
      catStyle = catDebugStyle;
    } else {
      catStyle = catServiceStyle;
    }

    return TextSpan(
      children: [
        TextSpan(text: '[$ts] ', style: tsStyle),
        if (cat.isNotEmpty) TextSpan(text: '$cat ', style: catStyle),
        TextSpan(text: msg, style: msgStyle),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final lines = content.isEmpty ? const <String>[] : content.split('\n');
    final ordered = lines.reversed.toList();
    final base = const TextStyle(fontFamily: 'monospace', fontSize: 13);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tsStyle = base.copyWith(
      color: isDark ? Colors.grey.shade400 : Colors.grey,
    );
    final catEventStyle = base.copyWith(color: Colors.green);
    final catWarnStyle = base.copyWith(color: Colors.orange);
    final catErrorStyle = base.copyWith(color: Colors.red);
    final catServiceStyle = base.copyWith(color: Colors.blue);
    final catDebugStyle = base.copyWith(color: Colors.purple);
    final msgStyle = base.copyWith(color: isDark ? Colors.white : Colors.black);

    return SelectableText.rich(
      TextSpan(
        children: lines.isEmpty
            ? const <TextSpan>[]
            : ordered
                  .expand(
                    (l) => [
                      _spanForLine(
                        l,
                        base,
                        tsStyle: tsStyle,
                        catEventStyle: catEventStyle,
                        catWarnStyle: catWarnStyle,
                        catErrorStyle: catErrorStyle,
                        catServiceStyle: catServiceStyle,
                        catDebugStyle: catDebugStyle,
                        msgStyle: msgStyle,
                      ),
                      const TextSpan(text: '\n'),
                    ],
                  )
                  .toList(),
        style: base,
      ),
    );
  }
}

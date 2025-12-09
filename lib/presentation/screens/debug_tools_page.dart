import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/logger_service.dart';

class DebugToolsPage extends StatelessWidget {
  const DebugToolsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final logger = Provider.of<LoggerService>(context, listen: false);
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
                final uri = Uri(
                  scheme: 'mailto',
                  path: '',
                  queryParameters: {
                    'subject': 'NamiApp Logdatei',
                    'body': 'Pfad zur Logdatei: ${file.path}',
                  },
                );
                await launchUrl(uri);
              },
              icon: const Icon(Icons.mail_outline),
              label: const Text('Log per Mail/Share senden'),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: () async {
                await logger.log('debug', 'Manueller Logeintrag gesendet');
                // ignore: use_build_context_synchronously
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Logeintrag geschrieben')),
                );
              },
              icon: const Icon(Icons.bug_report_outlined),
              label: const Text('Test-Log schreiben'),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: () async {
                final file = await logger.getLogFile();
                final exists = await file.exists();
                final content = exists ? await file.readAsString() : '';
                // ignore: use_build_context_synchronously
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => _LogViewerPage(content: content),
                  ),
                );
              },
              icon: const Icon(Icons.article_outlined),
              label: const Text('Log anzeigen'),
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
        padding: const EdgeInsets.all(16),
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
        children: lines
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

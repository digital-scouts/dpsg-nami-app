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

import '../../services/hitobito_auth_config_controller.dart';
import '../../services/hitobito_oauth_service.dart';
import '../../services/logger_service.dart';

class DebugToolsPage extends StatefulWidget {
  const DebugToolsPage({super.key, this.oauthServiceFactory});

  final HitobitoOauthService Function(
    HitobitoAuthConfigController controller,
    LoggerService logger,
  )?
  oauthServiceFactory;

  @override
  State<DebugToolsPage> createState() => _DebugToolsPageState();
}

class _DebugToolsPageState extends State<DebugToolsPage> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _openOauthOverrideDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          _OauthOverrideDialog(oauthServiceFactory: widget.oauthServiceFactory),
    );
  }

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
    final configController = context.watch<HitobitoAuthConfigController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Debug & Tools')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Scrollbar(
          controller: _scrollController,
          thumbVisibility: true,
          child: ListView(
            controller: _scrollController,
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
                        messenger.showSnackBar(
                          SnackBar(content: Text(message)),
                        );
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
              const Text('Hitobito OAuth'),
              const SizedBox(height: 8),
              Text(
                configController.hasOverride
                    ? 'Aktiver Override fuer Client ID ${configController.effectiveClientId}'
                    : 'Aktuell werden die Hitobito OAuth-Werte aus der lokalen Env genutzt.',
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: authModel.state == AuthState.authenticating
                    ? null
                    : () => _openOauthOverrideDialog(context),
                icon: const Icon(Icons.verified_user_outlined),
                label: const Text('OAuth-Zugangsdaten prüfen'),
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
      ),
    );
  }
}

class _OauthOverrideDialog extends StatefulWidget {
  const _OauthOverrideDialog({this.oauthServiceFactory});

  final HitobitoOauthService Function(
    HitobitoAuthConfigController controller,
    LoggerService logger,
  )?
  oauthServiceFactory;

  @override
  State<_OauthOverrideDialog> createState() => _OauthOverrideDialogState();
}

class _OauthOverrideDialogState extends State<_OauthOverrideDialog> {
  late final TextEditingController _clientIdController;
  late final TextEditingController _clientSecretController;
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final configController = context.read<HitobitoAuthConfigController>();
    _clientIdController = TextEditingController(
      text: configController.effectiveClientId,
    );
    _clientSecretController = TextEditingController();
  }

  @override
  void dispose() {
    _clientIdController.dispose();
    _clientSecretController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final configController = context.read<HitobitoAuthConfigController>();
    final authModel = context.read<AuthSessionModel>();
    final arbeitskontextModel = context.read<ArbeitskontextModel>();
    final logger = context.read<LoggerService>();
    final clientId = _clientIdController.text.trim();
    final clientSecret = _clientSecretController.text.trim();
    final previousConfig = configController.config;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    configController.applyEphemeralOverride(
      clientId: clientId,
      clientSecret: clientSecret,
    );

    try {
      final oauthService =
          widget.oauthServiceFactory?.call(configController, logger) ??
          HitobitoOauthService(config: configController.config, logger: logger);
      final authenticatedSession = await oauthService.authenticateInteractive();
      await authModel.signInWithAuthenticatedSession(authenticatedSession);
      await configController.saveOverride(
        clientId: clientId,
        clientSecret: clientSecret,
      );
      await arbeitskontextModel.syncForAuth(
        authState: authModel.state,
        session: authModel.session,
        profile: authModel.profile,
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop();
    } catch (error) {
      configController.restoreConfig(previousConfig);
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Hitobito OAuth prüfen'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _clientIdController,
              decoration: const InputDecoration(labelText: 'Client ID'),
              enabled: !_isSubmitting,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Client ID ist erforderlich';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _clientSecretController,
              decoration: const InputDecoration(labelText: 'Client Secret'),
              enabled: !_isSubmitting,
              obscureText: true,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Client Secret ist erforderlich';
                }
                return null;
              },
            ),
            if (_errorMessage != null && _errorMessage!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Prüfen'),
        ),
      ],
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

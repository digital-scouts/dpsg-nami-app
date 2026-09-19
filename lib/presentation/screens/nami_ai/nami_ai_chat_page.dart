import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nami/domain/nami_ai/nami_ai_chat_history_entry.dart';
import 'package:nami/domain/nami_ai/nami_ai_chat_history_repository.dart';
import 'package:nami/presentation/notifications/app_snackbar.dart';
import 'package:nami/presentation/screens/nami_ai/nami_ai_chat_history_list_page.dart';
import 'package:nami/presentation/screens/nami_ai/widgets/nami_ai_message_bubble.dart';
import 'package:nami/services/nami_ai/nami_ai_debug_log_service.dart';
import 'package:nami/services/nami_ai/nami_ai_service.dart';
import 'package:nami/services/nami_ai/nami_ai_stream_service.dart';
import 'package:open_file/open_file.dart';
import 'package:provider/provider.dart';

enum _ChatMenuAction { newConversation, history, shareDebugLog }

class NamiAiChatPage extends StatefulWidget {
  const NamiAiChatPage({super.key, this.debugInitialMessages});

  /// Seeds the transcript for Storybook/tests, so a story can show a specific answer state
  /// (sources, unclear, an in-progress-looking partial, ...) without scripting the send
  /// interaction - same pattern as StatisticsPage.debugReadModel.
  final List<NamiAiChatMessage>? debugInitialMessages;

  @override
  State<NamiAiChatPage> createState() => _NamiAiChatPageState();
}

class _NamiAiChatPageState extends State<NamiAiChatPage> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late final List<NamiAiChatMessage> _messages =
      widget.debugInitialMessages?.toList() ?? <NamiAiChatMessage>[];
  bool _isSending = false;
  // Started lazily on the first message rather than in initState: starting a native
  // LanguageModelSession is meaningless (and would be wasted) if the user never sends anything.
  String? _sessionId;
  // Set together on the first message of a conversation; title = that first question,
  // startedAt = its timestamp (specs/nami-ai-roadmap.md section 3.7 persistence design).
  String? _conversationId;
  DateTime? _conversationStartedAt;
  String? _conversationTitle;
  // Captured here rather than read via context in dispose(): looking up an ancestor
  // (InheritedWidget/Provider) from dispose() is unsafe once the widget tree is being torn down
  // - the ancestor's element can already be deactivated by the time dispose() runs.
  NamiAiService? _service;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _service ??= context.read<NamiAiService>();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    final sessionId = _sessionId;
    if (sessionId != null) {
      unawaited(_service?.endSession(sessionId));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('NaMi AI'),
        actions: [
          PopupMenuButton<_ChatMenuAction>(
            tooltip: 'Menü',
            onSelected: _handleMenuAction,
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: _ChatMenuAction.newConversation,
                child: Text('Neue Unterhaltung'),
              ),
              PopupMenuItem(
                value: _ChatMenuAction.history,
                child: Text('Verlauf'),
              ),
              PopupMenuItem(
                value: _ChatMenuAction.shareDebugLog,
                child: Text('Debug-Log teilen'),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _messages.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Teste den Chat. Die Apple-On-Device-AI wird über die native iOS-Brücke aufgerufen.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        return NamiAiMessageBubble(message: _messages[index]);
                      },
                    ),
            ),
            const Divider(height: 1),
            if (_isSending)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: CircularProgressIndicator(),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      decoration: const InputDecoration(
                        hintText: 'Nachricht schreiben',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      enabled: !_isSending,
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _isSending ? null : _sendMessage,
                    icon: const Icon(Icons.send),
                    label: const Text('Senden'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleMenuAction(_ChatMenuAction action) async {
    switch (action) {
      case _ChatMenuAction.newConversation:
        await _startNewConversation();
      case _ChatMenuAction.history:
        _openHistory();
      case _ChatMenuAction.shareDebugLog:
        await _shareDebugLog();
    }
  }

  void _openHistory() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const NamiAiChatHistoryListPage()),
    );
  }

  /// Manual counterpart to the automatic "new session after app restart" behaviour (specs/
  /// nami-ai-roadmap.md section 3.7): ends the current native session and clears the visible
  /// transcript so the next message starts a fresh conversation/session pair. The conversation
  /// just left is already fully saved (saved after every completed answer, not just on exit),
  /// so nothing more needs to happen with persistence here.
  Future<void> _startNewConversation() async {
    if (_isSending) {
      return;
    }
    final previousSessionId = _sessionId;
    setState(() {
      _messages.clear();
      _sessionId = null;
      _conversationId = null;
      _conversationStartedAt = null;
      _conversationTitle = null;
    });
    if (previousSessionId != null) {
      await context.read<NamiAiService>().endSession(previousSessionId);
    }
  }

  Future<void> _shareDebugLog() async {
    final logService = context.read<NamiAiDebugLogService>();
    final file = await logService.exportableLogFile();
    if (!mounted) {
      return;
    }
    final result = await OpenFile.open(file.path);
    if (!mounted || result.type == ResultType.done) {
      return;
    }
    AppSnackbar.show(
      context,
      message: 'Das Debug-Log konnte nicht geöffnet werden.',
      type: AppSnackbarType.warning,
    );
  }

  Future<void> _sendMessage() async {
    final message = _inputController.text.trim();
    if (message.isEmpty || _isSending) {
      return;
    }

    if (_conversationId == null) {
      final now = DateTime.now();
      _conversationId = now.microsecondsSinceEpoch.toString();
      _conversationStartedAt = now;
      _conversationTitle = message;
    }

    late final int placeholderIndex;
    setState(() {
      _messages.add(NamiAiChatMessage(text: message, isUser: true));
      placeholderIndex = _messages.length;
      _messages.add(const NamiAiChatMessage(text: '', isUser: false));
      _isSending = true;
      _inputController.clear();
    });
    _scrollToBottom();

    final service = context.read<NamiAiService>();
    final streamService = context.read<NamiAiStreamService>();
    final logService = context.read<NamiAiDebugLogService>();
    final historyRepository = context.read<NamiAiChatHistoryRepository>();
    final stopwatch = Stopwatch()..start();

    try {
      final sessionId = _sessionId ??= await service.startSession();

      NamiAiReply? finalReply;
      await for (final chunk in streamService.respond(
        sessionId: sessionId,
        prompt: message,
      )) {
        if (!mounted) {
          return;
        }
        if (chunk.isDone) {
          finalReply = chunk.reply;
          continue;
        }
        setState(() {
          _messages[placeholderIndex] = NamiAiChatMessage(
            text: chunk.text,
            isUser: false,
          );
        });
        _scrollToBottom();
      }
      stopwatch.stop();

      final reply = finalReply;
      if (reply == null) {
        throw NamiAiException(
          code: 'empty_response',
          message: 'Die iOS-Antwort war leer.',
        );
      }

      setState(() {
        _messages[placeholderIndex] = NamiAiChatMessage(
          text: reply.answer,
          isUser: false,
          sources: reply.sources,
          unclear: reply.unclear,
        );
      });
      unawaited(
        logService.logEntry(
          prompt: message,
          success: true,
          answer: reply.answer,
          contextChunks: reply.contextChunks,
          latencyMs: stopwatch.elapsedMilliseconds,
        ),
      );
      unawaited(_saveConversation(historyRepository));

      if (reply.contextTruncated && mounted) {
        AppSnackbar.show(
          context,
          message:
              'Ältere Nachrichten sind für neue Antworten nicht mehr sichtbar.',
          type: AppSnackbarType.info,
        );
      }
    } catch (error) {
      stopwatch.stop();
      final fallback = error is NamiAiException
          ? 'Fehler: ${error.message}'
          : 'Fehler: Die AI-Antwort konnte nicht geladen werden.';
      if (mounted) {
        setState(() {
          _messages[placeholderIndex] = NamiAiChatMessage(
            text: fallback,
            isUser: false,
          );
        });
      }
      unawaited(
        logService.logEntry(
          prompt: message,
          success: false,
          errorCode: error is NamiAiException ? error.code : 'unknown',
          errorMessage: error is NamiAiException
              ? error.message
              : error.toString(),
          latencyMs: stopwatch.elapsedMilliseconds,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
        _scrollToBottom();
      }
    }
  }

  Future<void> _saveConversation(NamiAiChatHistoryRepository repository) async {
    final conversationId = _conversationId;
    final startedAt = _conversationStartedAt;
    final title = _conversationTitle;
    if (conversationId == null || startedAt == null || title == null) {
      return;
    }
    await repository.save(
      NamiAiChatHistoryEntry(
        id: conversationId,
        startedAt: startedAt,
        title: title,
        messages: List<NamiAiChatMessage>.unmodifiable(_messages),
      ),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    });
  }
}

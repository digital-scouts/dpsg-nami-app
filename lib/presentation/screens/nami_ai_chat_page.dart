import 'package:flutter/material.dart';
import 'package:nami/services/nami_ai_service.dart';
import 'package:provider/provider.dart';

class NamiAiChatPage extends StatefulWidget {
  const NamiAiChatPage({super.key});

  @override
  State<NamiAiChatPage> createState() => _NamiAiChatPageState();
}

class _NamiAiChatPageState extends State<NamiAiChatPage> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_ChatMessage> _messages = <_ChatMessage>[];
  bool _isSending = false;

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('NaMi AI')),
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
                        final message = _messages[index];
                        return _MessageBubble(message: message);
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

  Future<void> _sendMessage() async {
    final message = _inputController.text.trim();
    if (message.isEmpty || _isSending) {
      return;
    }

    setState(() {
      _messages.add(_ChatMessage(text: message, isUser: true));
      _isSending = true;
      _inputController.clear();
    });
    _scrollToBottom();

    final service = context.read<NamiAiService>();
    try {
      final response = await service.generateReply(message);
      setState(() {
        _messages.add(_ChatMessage(text: response, isUser: false));
      });
    } catch (error) {
      final fallback = error is NamiAiException
          ? 'Fehler: ${error.message}'
          : 'Fehler: Die AI-Antwort konnte nicht geladen werden.';
      setState(() {
        _messages.add(_ChatMessage(text: fallback, isUser: false));
      });
    } finally {
      setState(() {
        _isSending = false;
      });
      _scrollToBottom();
    }
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

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final _ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUser = message.isUser;
    final alignment = isUser ? Alignment.centerRight : Alignment.centerLeft;
    final background = isUser
        ? theme.colorScheme.primaryContainer
        : theme.colorScheme.surfaceContainerHighest;

    return Align(
      alignment: alignment,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(message.text),
      ),
    );
  }
}

class _ChatMessage {
  const _ChatMessage({required this.text, required this.isUser});

  final String text;
  final bool isUser;
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nami/domain/nami_ai/nami_ai_chat_history_entry.dart';
import 'package:nami/domain/nami_ai/nami_ai_chat_history_repository.dart';
import 'package:nami/presentation/screens/nami_ai/nami_ai_chat_history_detail_page.dart';
import 'package:provider/provider.dart';

/// Lists past conversations, newest first (specs/nami-ai-roadmap.md section 3.7): title = the
/// first question, subtitle = when that conversation started. No delete UI - entries expire
/// automatically after 30 days (NamiAiChatHistoryEntry.retention), nothing here is manually
/// removable.
class NamiAiChatHistoryListPage extends StatefulWidget {
  const NamiAiChatHistoryListPage({super.key});

  @override
  State<NamiAiChatHistoryListPage> createState() =>
      _NamiAiChatHistoryListPageState();
}

class _NamiAiChatHistoryListPageState extends State<NamiAiChatHistoryListPage> {
  late final Future<List<NamiAiChatHistoryEntry>> _entriesFuture;

  @override
  void initState() {
    super.initState();
    _entriesFuture = context.read<NamiAiChatHistoryRepository>().loadAll();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verlauf')),
      body: FutureBuilder<List<NamiAiChatHistoryEntry>>(
        future: _entriesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          final entries = snapshot.data ?? const <NamiAiChatHistoryEntry>[];
          if (entries.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Noch keine gespeicherten Unterhaltungen.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return ListView.separated(
            itemCount: entries.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final entry = entries[index];
              return ListTile(
                title: Text(
                  entry.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(_formatStartedAt(entry.startedAt)),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => NamiAiChatHistoryDetailPage(entry: entry),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  String _formatStartedAt(DateTime startedAt) {
    return DateFormat('dd.MM.yyyy HH:mm').format(startedAt);
  }
}

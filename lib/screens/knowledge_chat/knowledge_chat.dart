import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:nami/utilities/chat_ai/open_ai.service.dart';
import 'package:nami/utilities/chat_ai/vector_search.dart';

class KnowledgeChat extends StatefulWidget {
  const KnowledgeChat({super.key});

  @override
  State<KnowledgeChat> createState() => _KnowledgeChat();
}

class _KnowledgeChat extends State<KnowledgeChat> {
  final TextEditingController _controller = TextEditingController();
  final VectorSearch vectorSearch = VectorSearch();
  final OpenAIService openAIService = OpenAIService();

  final List<Map<String, String>> _messages = [];
  String _tokensUsed = "";
  int _totalTokensUsed = 0;
  bool _canAskQuestion = true;
  int _secondsRemaining = 0;
  late Box<Map> _messagesBox;

  @override
  void initState() {
    super.initState();
    vectorSearch.init();
    _initHive();
  }

  void _initHive() {
    _messagesBox = Hive.box("ai_chat_messages");
    List<Map<String, String>> messages = _messagesBox.values
        .map((e) => Map<String, String>.from(e))
        .toList();
    setState(() {
      _messages.addAll(messages);
    });
  }

  Future<void> _askQuestion() async {
    if (!_canAskQuestion) return;

    String query = _controller.text;
    if (query.isEmpty) return;

    setState(() {
      _messages.add({"role": "user", "content": query});
      _controller.clear();
      _canAskQuestion = false;
      _secondsRemaining = 20;
    });

    _messagesBox.add({"role": "user", "content": query});

    List<String> relevantText = await vectorSearch.findRelevantTexts(query);
    // String prompt = "${relevantText.join('\n')}\n\nFrage: $query";

    Map<String, dynamic> result; //= await openAIService.askGPT(prompt);
    var fakeResult = {
      'choices': [
        {
          'message': {'content': relevantText.join('\n')},
        },
      ],
      'usage': {'total_tokens': 0},
    };
    result = fakeResult; // Fake-Antwort

    setState(() {
      final assistantMessage = {
        "role": "assistant",
        "content": utf8.decode(
          utf8.encode(result["choices"][0]["message"]["content"]),
        ), // UTF-8 Codierung
        "tokens": result["usage"]["total_tokens"].toString(),
      };
      _messages.add(assistantMessage);
      _totalTokensUsed += result["usage"]["total_tokens"] as int;
      _tokensUsed = "Tokens: $_totalTokensUsed";
      _messagesBox.add(assistantMessage);
    });

    Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        if (--_secondsRemaining > 0) {
          _secondsRemaining--;
        } else {
          _canAskQuestion = true;
          timer.cancel();
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("KI-Assistent")),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              reverse: true,
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[_messages.length - 1 - index];
                bool isUser = message["role"] == "user";
                return Column(
                  crossAxisAlignment: isUser
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                      padding: EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isUser ? Colors.blue[50] : Colors.grey[200],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            message["content"]!,
                            style: TextStyle(
                              color: isUser ? Colors.blue : Colors.black,
                            ),
                          ),
                          if (message.containsKey("tokens"))
                            Text(
                              "Tokens: ${message["tokens"]}",
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 10,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (!isUser) SizedBox(height: 20),
                  ],
                );
              },
            ),
          ),
          if (_tokensUsed.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  Text(_tokensUsed, style: TextStyle(color: Colors.grey)),
                  if (!_canAskQuestion)
                    Text(
                      "Bitte warte $_secondsRemaining Sekunden",
                      style: TextStyle(color: Colors.red),
                    ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(
              top: 8,
              left: 8,
              right: 8,
              bottom: 40,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    maxLength: 200,
                    decoration: InputDecoration(
                      labelText: "Stelle eine Frage zur DPSG",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _canAskQuestion ? _askQuestion : null,
                  child: Text("Fragen"),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

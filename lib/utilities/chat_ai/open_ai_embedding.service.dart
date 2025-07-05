import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:wiredash/wiredash.dart';

class OpenAIEmbeddingService {
  Future<List<double>> getEmbedding(String text) async {
    final String? apiKey = dotenv.env['OPEN_AI_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('API Key is missing');
    }

    final url = Uri.parse("https://api.openai.com/v1/embeddings");

    final response = await http.post(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $apiKey",
      },
      body: jsonEncode({"model": "text-embedding-ada-002", "input": text}),
    );

    final responseData = jsonDecode(utf8.decode(response.bodyBytes));
    Wiredash.trackEvent(
      'AI Question Embedding',
      data: {
        'tokens': responseData["usage"]["total_tokens"],
        'text': text,
        'model': 'text-embedding-ada-002',
      },
    );
    debugPrint(
      'Tokens used for embedding ${responseData["usage"]["total_tokens"]}',
    );
    return List<double>.from(responseData["data"][0]["embedding"]);
  }
}

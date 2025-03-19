import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:wiredash/wiredash.dart';

class OpenAIService {
  Future<Map<String, dynamic>> askGPT(String prompt) async {
    final String? apiKey = dotenv.env['OPEN_AI_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('API Key is missing');
    }

    final url = Uri.parse("https://api.openai.com/v1/chat/completions");

    final response = await http.post(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $apiKey",
      },
      body: jsonEncode({
        "model": "gpt-4o-mini",
        "messages": [
          {
            "role": "system",
            "content": utf8.decode(utf8.encode(
                "Du bist ein Experte für die DPSG-Satzung und beantwortest Fragen basierend auf den bereitgestellten Informationen."))
          },
          {"role": "user", "content": utf8.decode(utf8.encode(prompt))}
        ],
        "max_tokens": 100,
        "temperature": 0.7,
        "top_p": 1.0,
        "frequency_penalty": 0.0,
        "presence_penalty": 0.0
      }),
    );

    final Map<String, dynamic> responseData =
        jsonDecode(utf8.decode(response.bodyBytes));

    Wiredash.trackEvent('AI Question Chat', data: {
      'tokens': responseData["usage"]["total_tokens"],
      'prompt': prompt,
      'answer': responseData["choices"][0]["message"]["content"],
      'model': 'text-embedding-ada-002'
    });
    debugPrint(
        'Tokens used for embedding ${responseData["usage"]["total_tokens"]}');

    return responseData;
  }
}

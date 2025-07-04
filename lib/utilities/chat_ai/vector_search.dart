import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart'; // Für die Hash-Funktion
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:hive_ce/hive.dart';
import 'package:nami/utilities/chat_ai/open_ai_embedding.service.dart';

class VectorSearch {
  Box<Map> db = Hive.box<Map>("satzung_db");

  final OpenAIEmbeddingService embeddingService = OpenAIEmbeddingService();

  Future<void> init() async {
    if (db.isEmpty) {
      await _loadEmbeddings();
    }
  }

  Future<void> _loadEmbeddings() async {
    // Lade die JSON-Datei mit den Embeddings
    String jsonString = await rootBundle
        .loadString('assets/ai_kontext/satzung_stamm_2024_embeddings.json');
    List<dynamic> jsonData = jsonDecode(jsonString);

    // Speichere die Embeddings in der Hive-Datenbank
    for (var item in jsonData) {
      String text = item["text"];
      List<double> vector = List<double>.from(item["vector"]);
      String hashKey = _generateHashKey(text);
      db.put(hashKey, {"text": text, "vector": vector});
    }
  }

  Future<List<String>> findRelevantTexts(String query) async {
    List<double> queryVector = await embeddingService.getEmbedding(query);
    List<Map<String, dynamic>> similarityList = [];

    for (var key in db.keys) {
      Map storedData = db.get(key)!;
      List<double> storedVector = List<double>.from(storedData["vector"]);
      double similarity = _cosineSimilarity(queryVector, storedVector);

      if (similarity > 0.8) {
        similarityList.add({
          "text": storedData["text"],
          "similarity": similarity,
        });
        debugPrint(
            "Similarity: ${similarity.toStringAsFixed(2)}: ${storedData["text"].substring(0, 3)}");
      }
    }

    // Sortiere die Liste nach Ähnlichkeit
    similarityList.sort((a, b) => b["similarity"].compareTo(a["similarity"]));

    // Nimm die besten 3
    List<String> relevantTexts =
        similarityList.take(3).map((e) => e["text"] as String).toList();

    return relevantTexts;
  }

  double _cosineSimilarity(List<double> vec1, List<double> vec2) {
    double dotProduct = 0;
    double normA = 0;
    double normB = 0;

    for (int i = 0; i < vec1.length; i++) {
      dotProduct += vec1[i] * vec2[i];
      normA += vec1[i] * vec1[i];
      normB += vec2[i] * vec2[i];
    }

    return dotProduct / (sqrt(normA) * sqrt(normB));
  }

  String _generateHashKey(String text) {
    var bytes = utf8.encode(text);
    var digest = sha256.convert(bytes);
    return digest.toString();
  }
}

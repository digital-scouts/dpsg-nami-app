import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// Returns formatted address suggestions for a free-text query using Geoapify.
///
/// Clean Architecture: This function stays in the services/UI layer and
/// does not leak UI concerns into domain. It calls the remote API directly
/// and maps the response into simple strings for presentation widgets.
Future<List<String>> geoapifyAutocompleteProvider(String query) async {
  final q = query.trim();
  if (q.length < 3) return [];

  final apiKey = dotenv.env['GEOAPIFY_KEY'];
  if (apiKey == null || apiKey.isEmpty) {
    // Fail soft: return no suggestions when key is missing
    return [];
  }

  final uri = Uri.parse(
    'https://api.geoapify.com/v1/geocode/autocomplete?text=${Uri.encodeComponent(q)}&lang=de&limit=5&filter=countrycode:de&format=json&apiKey=$apiKey',
  );

  try {
    final resp = await http.get(uri);
    if (resp.statusCode != 200) return [];
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final results = (data['results'] as List?) ?? const [];
    return results
        .map((e) => (e as Map<String, dynamic>)['formatted'] as String?)
        .whereType<String>()
        .toList();
  } catch (_) {
    return [];
  }
}

import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class GroqTranslationService {
  static const _endpoint =
      'https://api.groq.com/openai/v1/chat/completions';
  static const _model = 'llama-3.1-8b-instant';

  final _cache = <String, String>{};

  Future<String> translate(
    String text, {
    required String from,
    required String to,
  }) async {
    if (text.trim().isEmpty) return text;

    final cacheKey = '$from:$to:$text';
    if (_cache.containsKey(cacheKey)) return _cache[cacheKey]!;

    final apiKey = dotenv.env['GROQ_API_KEY'] ?? '';
    if (apiKey.isEmpty) return text;

    try {
      final response = await http.post(
        Uri.parse(_endpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': _model,
          'messages': [
            {
              'role': 'system',
              'content':
                  'You are a translation assistant. Translate the user\'s text from $from to $to. '
                      'Return only the translated text with no explanation, no quotes, and no extra content.',
            },
            {
              'role': 'user',
              'content': text,
            },
          ],
          'temperature': 0.1,
          'max_tokens': 512,
        }),
      );

      if (response.statusCode != 200) return text;

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final choices = body['choices'] as List<dynamic>?;
      if (choices == null || choices.isEmpty) return text;

      final translated =
          (choices[0]['message']['content'] as String?)?.trim() ?? text;

      _cache[cacheKey] = translated;
      return translated;
    } catch (_) {
      return text;
    }
  }

  Future<String> translateToArabic(String text) =>
      translate(text, from: 'en', to: 'ar');

  Future<String> translateToEnglish(String text) =>
      translate(text, from: 'ar', to: 'en');
}

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class CompletionSettings {
  static const String _baseUrlKey = 'completion_base_url';
  static const String _apiTokenKey = 'completion_api_token';
  static const String _modelKey = 'completion_model';
  static const String _enabledKey = 'completion_enabled';

  static const String defaultBaseUrl = 'https://api.openai.com/v1';
  static const String defaultModel = 'gpt-4o-mini';

  String baseUrl;
  String apiToken;
  String model;
  bool enabled;

  CompletionSettings({
    this.baseUrl = defaultBaseUrl,
    this.apiToken = '',
    this.model = defaultModel,
    this.enabled = true,
  });

  bool get isConfigured => apiToken.isNotEmpty;

  static Future<CompletionSettings> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return CompletionSettings(
        baseUrl: prefs.getString(_baseUrlKey) ?? defaultBaseUrl,
        apiToken: prefs.getString(_apiTokenKey) ?? '',
        model: prefs.getString(_modelKey) ?? defaultModel,
        enabled: prefs.getBool(_enabledKey) ?? true,
      );
    } catch (e) {
      debugPrint('Failed to load completion settings: $e');
      return CompletionSettings();
    }
  }

  Future<void> save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_baseUrlKey, baseUrl);
      await prefs.setString(_apiTokenKey, apiToken);
      await prefs.setString(_modelKey, model);
      await prefs.setBool(_enabledKey, enabled);
    } catch (e) {
      debugPrint('Failed to save completion settings: $e');
      rethrow;
    }
  }
}

class CompletionService {
  final CompletionSettings settings;

  CompletionService(this.settings);

  /// 현재 context를 기반으로 자동완성 제안을 요청합니다.
  /// [textBefore]는 커서 앞에 있는 텍스트입니다.
  /// [textAfter]는 커서 뒤에 있는 텍스트입니다 (선택적).
  /// 반환값은 제안된 완성 텍스트이며, 실패 시 null을 반환합니다.
  Future<String?> getCompletion(String textBefore,
      {String textAfter = ''}) async {
    if (!settings.isConfigured || !settings.enabled) {
      return null;
    }

    // 커서 앞 텍스트가 너무 짧으면 완성 제안하지 않음
    if (textBefore.trim().length < 3) {
      return null;
    }

    try {
      final url = Uri.parse('${settings.baseUrl}/chat/completions');

      // 컨텍스트가 너무 길면 최근 부분만 사용
      const maxContextLength = 1000;
      final beforeContext = textBefore.length > maxContextLength
          ? textBefore.substring(textBefore.length - maxContextLength)
          : textBefore;
      final afterContext = textAfter.length > maxContextLength
          ? textAfter.substring(0, maxContextLength)
          : textAfter;

      debugPrint('🤖 [AI] Requesting completion...');
      debugPrint(
          '🤖 [AI] Before cursor (${beforeContext.length} chars): "...${beforeContext.substring(beforeContext.length > 50 ? beforeContext.length - 50 : 0)}"');
      if (afterContext.isNotEmpty) {
        debugPrint(
            '🤖 [AI] After cursor (${afterContext.length} chars): "${afterContext.substring(0, afterContext.length > 50 ? 50 : afterContext.length)}..."');
      }

      // 프롬프트 구성
      String userPrompt;
      if (afterContext.trim().isEmpty) {
        // 커서가 끝에 있는 경우 - 일반적인 완성
        userPrompt = 'Continue the following text naturally:\n\n$beforeContext';
      } else {
        // 커서가 중간에 있는 경우 - fill-in-the-middle
        userPrompt =
            '''Fill in text at the [CURSOR] position. Only output the text that should go at [CURSOR], nothing else.

$beforeContext[CURSOR]$afterContext''';
      }

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${settings.apiToken}',
        },
        body: jsonEncode({
          'model': settings.model,
          'messages': [
            {
              'role': 'system',
              'content':
                  '''You are an autocomplete assistant for a note-taking app. Your job is to predict what the user wants to type next at their cursor position.

Rules:
- Only output the completion text, nothing else - no explanations, no quotes
- Keep completions short and natural (a few words to 1-2 sentences)
- If the cursor is in the middle of text, suggest text that fits naturally between the before and after context
- Match the language and writing style of the surrounding text
- If unsure what to suggest, return an empty response
- Never repeat text that's already written'''
            },
            {'role': 'user', 'content': userPrompt}
          ],
          'max_tokens': 100,
          'temperature': 0.3,
        }),
      );

      debugPrint('🤖 [AI] Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final completion =
            data['choices']?[0]?['message']?['content'] as String?;

        debugPrint('🤖 [AI] Completion received: "$completion"');

        if (completion != null && completion.trim().isNotEmpty) {
          return completion.trim();
        } else {
          debugPrint('🤖 [AI] Empty or null completion');
        }
      } else {
        debugPrint(
            '🤖 [AI] API error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('🤖 [AI] Exception: $e');
    }

    return null;
  }
}

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Result of a grammar check
class GrammarCheckResult {
  /// LanguageTool matches (errors/suggestions)
  final List<GrammarMatch> matches;

  /// Words/phrases used correctly (vocabulary skill IDs)
  final List<String> vocabCorrect;

  /// Grammar patterns detected (grammar skill IDs)
  final List<String> grammarPatterns;

  /// Skills demonstrated (pragmatic skill IDs)
  final List<String> skillDemonstrations;

  /// The original text that was checked
  final String originalText;

  /// Detected language
  final String? detectedLanguage;

  GrammarCheckResult({
    required this.matches,
    required this.vocabCorrect,
    required this.grammarPatterns,
    required this.skillDemonstrations,
    required this.originalText,
    this.detectedLanguage,
  });

  factory GrammarCheckResult.fromJson(Map<String, dynamic> json) {
    return GrammarCheckResult(
      matches: (json['matches'] as List?)
              ?.map((m) => GrammarMatch.fromJson(m))
              .toList() ??
          [],
      vocabCorrect: List<String>.from(json['vocab_correct'] ?? []),
      grammarPatterns: List<String>.from(json['grammar_patterns'] ?? []),
      skillDemonstrations:
          List<String>.from(json['skill_demonstrations'] ?? []),
      originalText: json['original_text'] ?? '',
      detectedLanguage: json['detected_language'],
    );
  }

  bool get hasErrors => matches.isNotEmpty;
  int get errorCount => matches.length;
}

/// A grammar/style match from LanguageTool
class GrammarMatch {
  final String message;
  final String? shortMessage;
  final int offset;
  final int length;
  final List<Replacement> replacements;
  final MatchContext? context;
  final String? sentence;
  final GrammarRule? rule;

  GrammarMatch({
    required this.message,
    this.shortMessage,
    required this.offset,
    required this.length,
    required this.replacements,
    this.context,
    this.sentence,
    this.rule,
  });

  factory GrammarMatch.fromJson(Map<String, dynamic> json) {
    return GrammarMatch(
      message: json['message'] ?? '',
      shortMessage: json['shortMessage'],
      offset: json['offset'] ?? 0,
      length: json['length'] ?? 0,
      replacements: (json['replacements'] as List?)
              ?.map((r) => Replacement.fromJson(r))
              .toList() ??
          [],
      context: json['context'] != null
          ? MatchContext.fromJson(json['context'])
          : null,
      sentence: json['sentence'],
      rule: json['rule'] != null ? GrammarRule.fromJson(json['rule']) : null,
    );
  }
}

/// Suggested replacement
class Replacement {
  final String value;

  Replacement({required this.value});

  factory Replacement.fromJson(Map<String, dynamic> json) {
    return Replacement(value: json['value'] ?? '');
  }
}

/// Context of a match
class MatchContext {
  final String text;
  final int offset;
  final int length;

  MatchContext({
    required this.text,
    required this.offset,
    required this.length,
  });

  factory MatchContext.fromJson(Map<String, dynamic> json) {
    return MatchContext(
      text: json['text'] ?? '',
      offset: json['offset'] ?? 0,
      length: json['length'] ?? 0,
    );
  }
}

/// Grammar rule that triggered
class GrammarRule {
  final String id;
  final String? subId;
  final String? description;
  final String? issueType;
  final RuleCategory? category;

  GrammarRule({
    required this.id,
    this.subId,
    this.description,
    this.issueType,
    this.category,
  });

  factory GrammarRule.fromJson(Map<String, dynamic> json) {
    return GrammarRule(
      id: json['id'] ?? '',
      subId: json['subId'],
      description: json['description'],
      issueType: json['issueType'],
      category: json['category'] != null
          ? RuleCategory.fromJson(json['category'])
          : null,
    );
  }
}

/// Rule category
class RuleCategory {
  final String id;
  final String name;

  RuleCategory({required this.id, required this.name});

  factory RuleCategory.fromJson(Map<String, dynamic> json) {
    return RuleCategory(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
    );
  }
}

/// Grammar checking service
class GrammarCheckService extends ChangeNotifier {
  static final GrammarCheckService _instance =
      GrammarCheckService._internal();
  static GrammarCheckService get instance => _instance;

  GrammarCheckService._internal();

  // API configuration
  static const String _grammarCheckUrl = 'https://vocari-api.beebs.dev/api/grammar_check';
  bool _isEnabled = true;

  /// Enable/disable grammar checking
  void setEnabled(bool enabled) {
    _isEnabled = enabled;
    notifyListeners();
  }

  bool get isEnabled => _isEnabled;

  /// Check text for grammar/style issues and language learning progress
  Future<GrammarCheckResult?> checkText(
    String text,
    String language, {
    String? motherTongue,
    String? level,
  }) async {
    if (!_isEnabled || text.trim().isEmpty) {
      return GrammarCheckResult(
        matches: [],
        vocabCorrect: [],
        grammarPatterns: [],
        skillDemonstrations: [],
        originalText: text,
      );
    }

    try {
      final response = await http
          .post(
            Uri.parse(_grammarCheckUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'text': text,
              'language': language,
              if (motherTongue != null) 'mother_tongue': motherTongue,
              if (level != null) 'level': level,
            }),
          );

      if (response.statusCode == 200) {
        debugPrint('[GRAMMAR] grammar check successful');
        final data = jsonDecode(response.body);
        return GrammarCheckResult.fromJson(data);
      } else {
        debugPrint(
            'Grammar check API error: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('Grammar check error: $e');
      return null;
    }
  }

  /// Quick check - just returns if text has errors
  Future<bool> hasErrors(String text, String language) async {
    final result = await checkText(text, language);
    return result?.hasErrors ?? false;
  }

  /// Get error count
  Future<int> getErrorCount(String text, String language) async {
    final result = await checkText(text, language);
    return result?.errorCount ?? 0;
  }
}

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Result of checking if a word has been seen before
enum SeenStatus {
  /// Word has never been seen - should show definition popup
  neverSeen,
  /// Word has been seen before - no popup needed
  seenBefore,
}

/// Definition data returned from the API
class WordDefinition {
  final String lemma;
  final List<String> lemmaDefinitions;
  final List<String> rootWordDefinitions;

  WordDefinition({
    required this.lemma,
    required this.lemmaDefinitions,
    required this.rootWordDefinitions,
  });

  factory WordDefinition.fromJson(Map<String, dynamic> json) {
    return WordDefinition(
      lemma: json['lemma'] as String? ?? '',
      lemmaDefinitions: (json['lemma_definitions'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      rootWordDefinitions: (json['root_word_definitions'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }

  String get primaryDefinition {
    if (lemmaDefinitions.isNotEmpty) return lemmaDefinitions.first;
    if (rootWordDefinitions.isNotEmpty) return rootWordDefinitions.first;
    return 'No definition available';
  }
}

/// Result of splitting text by language
class LanguageSplitResult {
  final List<String> tlangWords;
  final List<String> otherWords;

  LanguageSplitResult({
    required this.tlangWords,
    required this.otherWords,
  });

  factory LanguageSplitResult.fromJson(Map<String, dynamic> json) {
    return LanguageSplitResult(
      tlangWords: (json['target_language_words'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      otherWords: (json['other_words'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }
}

/// Service for tracking user's word knowledge
class WordKnowledgeService extends ChangeNotifier {
  static final WordKnowledgeService _instance = WordKnowledgeService._internal();
  static WordKnowledgeService get instance => _instance;
  WordKnowledgeService._internal();

  /// Words the user has seen (from model output) with count
  final Map<String, int> _seenWords = {};

  /// Words the user has used (from user input) with count
  final Map<String, int> _usedWords = {};

  /// Cache of word definitions
  final Map<String, WordDefinition> _definitionCache = {};

  static const String _defineApiUrl = 'https://vocari-api.beebs.dev/api/spacy/define';
  static const String _splitApiUrl = 'https://vocari-api.beebs.dev/api/spacy/split_language';

  /// Get read-only view of seen words with counts
  Map<String, int> get seenWords => Map.unmodifiable(_seenWords);

  /// Get read-only view of used words with counts
  Map<String, int> get usedWords => Map.unmodifiable(_usedWords);

  /// Get how many times a word has been seen
  int getSeenCount(String word) => _seenWords[normalizeWord(word)] ?? 0;

  /// Get how many times a word has been used
  int getUsedCount(String word) => _usedWords[normalizeWord(word)] ?? 0;

  /// Normalize a word for consistent storage and lookup.
  /// Trims whitespace, lowercases, removes punctuation (keeps unicode letters).
  String normalizeWord(String word) {
    if (word.isEmpty) return '';

    String normalized = word
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[.,!?¡¿;:«»\-]'), '')  // Remove common punctuation incl. Spanish
        .trim();

    return normalized;
  }

  Future<LanguageSplitResult?> splitByLanguage(String text) async {
    try {
      final uri = Uri.parse(_splitApiUrl);
      debugPrint('[WordKnowledge] Fetching from: $uri');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'text': text, 'language': 'es'}),
      );
      debugPrint('[WordKnowledge] Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return LanguageSplitResult.fromJson(json);
      }
      debugPrint('[WordKnowledge] Non-200 response: ${response.body}');
      return null;
    } catch (e) {
      debugPrint("error hitting language split route");
      debugPrint('$e');
      return null;
    }
  }

  /// Add a word to the seen map and return whether it was never seen before.
  /// If NeverSeen is returned, caller should show definition popup.
  SeenStatus addToSeen(String word) {
    final normalized = normalizeWord(word);
    if (normalized.isEmpty) return SeenStatus.seenBefore;

    final previousCount = _seenWords[normalized] ?? 0;
    _seenWords[normalized] = previousCount + 1;
    notifyListeners();
    return previousCount == 0 ? SeenStatus.neverSeen : SeenStatus.seenBefore;
  }

  /// Add a word to the used map
  void addToUsed(String word) {
    final normalized = normalizeWord(word);
    if (normalized.isEmpty) return;

    final previousCount = _usedWords[normalized] ?? 0;
    _usedWords[normalized] = previousCount + 1;
    notifyListeners();
  }

  /// Process model output - returns list of words that are NeverSeen (need popup)
  Future<List<String>> processModelOutput(String text) async {
    LanguageSplitResult? splitResult = await splitByLanguage(text);
    if (splitResult == null) {
      return [];
    }
    final neverSeenWords = <String>[];

    for (final word in splitResult.tlangWords) {
      final status = addToSeen(word);
      if (status == SeenStatus.neverSeen) {
        neverSeenWords.add(word);
      }
    }

    return neverSeenWords;
  }

  /// Process user input - adds words to used map
  Future<void> processUserInput(String text) async {
    final splitResult = await splitByLanguage(text);
    if (splitResult == null) { return; }
    for (final word in splitResult.tlangWords) {
      addToUsed(word);
    }
  }

  /// Fetch definition for a word from the API
  Future<WordDefinition?> fetchDefinition(String word) async {
    final normalized = normalizeWord(word);
    debugPrint('[WordKnowledge] fetchDefinition called for "$word" (normalized: "$normalized")');
    if (normalized.isEmpty) {
      debugPrint('[WordKnowledge] Skipping empty word');
      return null;
    }

    if (_definitionCache.containsKey(normalized)) {
      debugPrint('[WordKnowledge] Returning cached definition for "$normalized"');
      return _definitionCache[normalized];
    }

    try {
      final uri = Uri.parse(_defineApiUrl);
      debugPrint('[WordKnowledge] Fetching from: $uri');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'word': normalized, 'language': 'es'}),
      );
      debugPrint('[WordKnowledge] Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded == null || decoded is! Map<String, dynamic>) {
          debugPrint('[WordKnowledge] Server returned null or non-map body for "$normalized"');
          return null;
        }
        final definition = WordDefinition.fromJson(decoded);
        if (definition.lemmaDefinitions.isEmpty && definition.rootWordDefinitions.isEmpty) {
          debugPrint('[WordKnowledge] No definitions found for "$normalized" (lemma: "${definition.lemma}")');
          return null;
        }
        _definitionCache[normalized] = definition;
        return definition;
      }
      debugPrint('[WordKnowledge] Non-200 response: ${response.body}');
      return null;
    } catch (e) {
      debugPrint('[WordKnowledge] Error fetching definition for "$word": $e');
      return null;
    }
  }

  void reset() {
    _seenWords.clear();
    _usedWords.clear();
    _definitionCache.clear();
    notifyListeners();
  }
}

import 'package:flutter/foundation.dart';

import 'package:shared/services/definition_service.dart';
export 'package:shared/services/definition_service.dart';


/// Result of checking if a word has been seen before
enum SeenStatus {
  /// Word has never been seen - should show definition popup
  neverSeen,
  /// Word has been seen before - no popup needed
  seenBefore,
}

/// Result of splitting text by language

/// Service for tracking user's word knowledge
class WordKnowledgeService extends ChangeNotifier {
  static final WordKnowledgeService _instance = WordKnowledgeService._internal();
  static WordKnowledgeService get instance => _instance;
  WordKnowledgeService._internal();

  /// Words the user has seen (from model output) with count
  final Map<String, int> _seenWords = {};

  /// Words the user has used (from user input) with count
  final Map<String, int> _usedWords = {};

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

    for (final word in splitResult.targetLanguageWords) {
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
    for (final word in splitResult.targetLanguageWords) {
      addToUsed(word);
    }
  }

  void reset() {
    _seenWords.clear();
    _usedWords.clear();
    notifyListeners();
  }
}

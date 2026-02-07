import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../game_models.dart';

/// Message types for narrator interventions
enum NarratorMessageType {
  vocabularyHint,    // Help with a word
  grammarTip,        // Explain grammar concept
  contextualHelp,    // Help understanding the situation
  encouragement,     // Milestone celebration
  questGuidance,     // Help with quest objectives
}

/// A message from the narrator
class NarratorMessage {
  final String id;
  final NarratorMessageType type;
  final String content;
  final String? vocabularyWord;
  final String? translation;
  final DateTime timestamp;
  bool dismissed;

  NarratorMessage({
    required this.id,
    required this.type,
    required this.content,
    this.vocabularyWord,
    this.translation,
    DateTime? timestamp,
    this.dismissed = false,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// Narrator Service - A meta-level tutor that helps players learn
/// without breaking the immersion of NPC interactions
class NarratorService extends ChangeNotifier {
  static final NarratorService _instance = NarratorService._internal();
  static NarratorService get instance => _instance;

  NarratorService._internal();

  // API configuration
  String _apiBaseUrl = 'http://localhost:8000';

  // Message queue
  final List<NarratorMessage> _messages = [];

  // Vocabulary tracking
  final Set<String> _encounteredWords = {};
  final Map<String, String> _learnedVocabulary = {}; // word -> translation

  // Settings
  bool _enabled = true;
  bool _showVocabularyHints = true;
  bool _showGrammarTips = true;

  // Getters
  List<NarratorMessage> get messages => List.unmodifiable(_messages);
  List<NarratorMessage> get activeMessages =>
      _messages.where((m) => !m.dismissed).toList();
  bool get enabled => _enabled;
  bool get showVocabularyHints => _showVocabularyHints;
  bool get showGrammarTips => _showGrammarTips;
  Map<String, String> get learnedVocabulary => Map.unmodifiable(_learnedVocabulary);

  /// Set the API base URL
  void setApiUrl(String url) {
    _apiBaseUrl = url;
  }

  /// Enable/disable narrator
  void setEnabled(bool value) {
    _enabled = value;
    notifyListeners();
  }

  /// Toggle vocabulary hints
  void setShowVocabularyHints(bool value) {
    _showVocabularyHints = value;
    notifyListeners();
  }

  /// Toggle grammar tips
  void setShowGrammarTips(bool value) {
    _showGrammarTips = value;
    notifyListeners();
  }

  /// Add a narrator message
  void _addMessage(NarratorMessage message) {
    _messages.insert(0, message);
    // Keep only last 50 messages
    if (_messages.length > 50) {
      _messages.removeLast();
    }
    notifyListeners();
  }

  /// Dismiss a narrator message
  void dismissMessage(String messageId) {
    final index = _messages.indexWhere((m) => m.id == messageId);
    if (index != -1) {
      _messages[index].dismissed = true;
      notifyListeners();
    }
  }

  /// Dismiss all active messages
  void dismissAllMessages() {
    for (final message in _messages) {
      message.dismissed = true;
    }
    notifyListeners();
  }

  /// Clear all messages
  void clearMessages() {
    _messages.clear();
    notifyListeners();
  }

  /// Provide a vocabulary hint when a new word is encountered
  void provideVocabularyHint({
    required String word,
    required String translation,
    String? context,
  }) {
    if (!_enabled || !_showVocabularyHints) return;

    // Don't repeat hints for words we've already shown
    if (_encounteredWords.contains(word.toLowerCase())) return;
    _encounteredWords.add(word.toLowerCase());
    _learnedVocabulary[word] = translation;

    final contextText = context != null
        ? '\n\n(In this context: $context)'
        : '';

    _addMessage(NarratorMessage(
      id: 'vocab_${DateTime.now().millisecondsSinceEpoch}',
      type: NarratorMessageType.vocabularyHint,
      content: '"$word" means "$translation"$contextText',
      vocabularyWord: word,
      translation: translation,
    ));
  }

  /// Provide a grammar tip
  void provideGrammarTip({
    required String tip,
    String? example,
  }) {
    if (!_enabled || !_showGrammarTips) return;

    final exampleText = example != null
        ? '\n\nExample: $example'
        : '';

    _addMessage(NarratorMessage(
      id: 'grammar_${DateTime.now().millisecondsSinceEpoch}',
      type: NarratorMessageType.grammarTip,
      content: '$tip$exampleText',
    ));
  }

  /// Provide contextual help for understanding a situation
  void provideContextualHelp(String message) {
    if (!_enabled) return;

    _addMessage(NarratorMessage(
      id: 'context_${DateTime.now().millisecondsSinceEpoch}',
      type: NarratorMessageType.contextualHelp,
      content: message,
    ));
  }

  /// Provide encouragement at milestones
  void celebrateMilestone({
    required String milestone,
    String? details,
  }) {
    if (!_enabled) return;

    final detailsText = details != null ? '\n\n$details' : '';

    _addMessage(NarratorMessage(
      id: 'milestone_${DateTime.now().millisecondsSinceEpoch}',
      type: NarratorMessageType.encouragement,
      content: '$milestone$detailsText',
    ));
  }

  /// Provide quest guidance
  void provideQuestGuidance({
    required String questName,
    required String guidance,
  }) {
    if (!_enabled) return;

    _addMessage(NarratorMessage(
      id: 'quest_${DateTime.now().millisecondsSinceEpoch}',
      type: NarratorMessageType.questGuidance,
      content: '[$questName]\n\n$guidance',
    ));
  }

  /// Process NPC dialogue for vocabulary hints
  /// Called when an NPC speaks to extract Spanish words and provide hints
  void processNPCDialogue(String dialogue, String playerLanguageLevel) {
    if (!_enabled || !_showVocabularyHints) return;

    // Simple Spanish word detection (words with accents or Spanish-specific patterns)
    final spanishWordPattern = RegExp(
      r'\b([A-Za-záéíóúüñÁÉÍÓÚÜÑ]+)\b',
      caseSensitive: false,
    );

    // Common Spanish words by level that we want to help with
    final vocabularyByLevel = _getVocabularyForLevel(playerLanguageLevel);

    final matches = spanishWordPattern.allMatches(dialogue);
    for (final match in matches) {
      final word = match.group(1)?.toLowerCase();
      if (word != null && vocabularyByLevel.containsKey(word)) {
        provideVocabularyHint(
          word: word,
          translation: vocabularyByLevel[word]!,
        );
      }
    }
  }

  /// Get vocabulary hints appropriate for a language level
  Map<String, String> _getVocabularyForLevel(String level) {
    // This could be loaded from tutor.json, but for now we'll use a basic set
    final baseVocab = <String, String>{
      'hola': 'hello',
      'adios': 'goodbye',
      'gracias': 'thank you',
      'por favor': 'please',
      'si': 'yes',
      'no': 'no',
      'buenos dias': 'good morning',
      'buenas tardes': 'good afternoon',
      'buenas noches': 'good night',
      'manzana': 'apple',
      'agua': 'water',
      'pan': 'bread',
      'amigo': 'friend',
      'casa': 'house',
      'tienda': 'shop/store',
    };

    // Add more vocabulary for higher levels
    if (level != 'A0') {
      baseVocab.addAll({
        'como estas': 'how are you',
        'muy bien': 'very well',
        'necesito': 'I need',
        'quiero': 'I want',
        'tengo': 'I have',
        'puedo': 'I can',
        'donde': 'where',
        'cuando': 'when',
        'porque': 'because/why',
      });
    }

    return baseVocab;
  }

  /// Ask the narrator a question (uses AI)
  Future<String?> askNarrator({
    required String question,
    required String playerLanguageLevel,
    List<String>? recentVocabulary,
  }) async {
    if (!_enabled) return null;

    try {
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/narrator'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'question': question,
          'player_level': playerLanguageLevel,
          'recent_vocabulary': recentVocabulary ?? [],
          'system_prompt': _buildNarratorPrompt(playerLanguageLevel),
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final answer = data['response'] as String?;

        if (answer != null) {
          _addMessage(NarratorMessage(
            id: 'answer_${DateTime.now().millisecondsSinceEpoch}',
            type: NarratorMessageType.contextualHelp,
            content: answer,
          ));
        }

        return answer;
      }
    } catch (e) {
      debugPrint('Error asking narrator: $e');
    }

    return null;
  }

  String _buildNarratorPrompt(String playerLevel) {
    return '''You are a friendly language tutor helping a player learn Spanish through an RPG game.

You exist OUTSIDE the game world - you're a helpful guide, not an in-game character.

Your role:
- Explain vocabulary and grammar when asked
- Provide translations and context
- Give hints about how to express things in Spanish
- Be encouraging but not overly effusive
- Keep explanations brief and clear

Player's current Spanish level: $playerLevel

Teaching approach:
- Use English for explanations, Spanish for examples
- Connect explanations to what happens in the game world
- Start simple, build complexity gradually
- Be patient and supportive

Remember: NPCs in the game NEVER break character or teach. YOU are the only one who provides language help.''';
  }

  /// Called when player levels up their language
  void onLanguageLevelUp(String oldLevel, String newLevel) {
    celebrateMilestone(
      milestone: 'Language Level Up!',
      details: 'Your Spanish has improved from $oldLevel to $newLevel! '
          'You can now access new areas and understand more complex conversations.',
    );
  }

  /// Called when player completes a quest
  void onQuestComplete(Quest quest) {
    if (quest.languageLearning.targetVocabulary.isNotEmpty) {
      final vocabList = quest.languageLearning.targetVocabulary
          .map((v) => '${v.target} (${v.native})')
          .join(', ');

      celebrateMilestone(
        milestone: 'Quest Complete: ${quest.displayName}',
        details: 'Vocabulary practiced: $vocabList',
      );
    }
  }

  /// Called when player seems stuck (no progress for a while)
  void onPlayerStuck(Quest? currentQuest, Location currentLocation) {
    if (currentQuest == null) {
      provideContextualHelp(
        'Looking for something to do? Try talking to the people around you. '
        'They might have tasks that need help!',
      );
    } else {
      final task = currentQuest.currentTask;
      if (task != null) {
        provideQuestGuidance(
          questName: currentQuest.displayName,
          guidance: 'Current objective: ${task.displayDescription}\n\n'
              'Hint: ${task.displayHint}',
        );
      }
    }
  }
}

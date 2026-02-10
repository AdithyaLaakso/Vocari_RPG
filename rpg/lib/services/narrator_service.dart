import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared/services/api_endpoints.dart';

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
  final bool dismissed;

  NarratorMessage({
    required this.id,
    required this.type,
    required this.content,
    this.vocabularyWord,
    this.translation,
    DateTime? timestamp,
    this.dismissed = false,
  }) : timestamp = timestamp ?? DateTime.now();

  NarratorMessage copyWith({bool? dismissed}) {
    return NarratorMessage(
      id: id,
      type: type,
      content: content,
      vocabularyWord: vocabularyWord,
      translation: translation,
      timestamp: timestamp,
      dismissed: dismissed ?? this.dismissed,
    );
  }
}

/// Immutable state for the narrator system
class NarratorState {
  final List<NarratorMessage> messages;
  final Set<String> encounteredWords;
  final Map<String, String> learnedVocabulary;
  final bool enabled;
  final bool showVocabularyHints;
  final bool showGrammarTips;

  const NarratorState({
    this.messages = const [],
    this.encounteredWords = const {},
    this.learnedVocabulary = const {},
    this.enabled = true,
    this.showVocabularyHints = true,
    this.showGrammarTips = true,
  });

  List<NarratorMessage> get activeMessages =>
      messages.where((m) => !m.dismissed).toList();

  NarratorState copyWith({
    List<NarratorMessage>? messages,
    Set<String>? encounteredWords,
    Map<String, String>? learnedVocabulary,
    bool? enabled,
    bool? showVocabularyHints,
    bool? showGrammarTips,
    String? apiBaseUrl,
  }) {
    return NarratorState(
      messages: messages ?? this.messages,
      encounteredWords: encounteredWords ?? this.encounteredWords,
      learnedVocabulary: learnedVocabulary ?? this.learnedVocabulary,
      enabled: enabled ?? this.enabled,
      showVocabularyHints: showVocabularyHints ?? this.showVocabularyHints,
      showGrammarTips: showGrammarTips ?? this.showGrammarTips,
    );
  }
}

/// Riverpod provider for the narrator system
final narratorProvider = NotifierProvider<NarratorNotifier, NarratorState>(
  NarratorNotifier.new,
);

/// Narrator Notifier - A meta-level tutor that helps players learn
/// without breaking the immersion of NPC interactions
class NarratorNotifier extends Notifier<NarratorState> {
  @override
  NarratorState build() => const NarratorState();

  /// Set the API base URL
  void setApiUrl(String url) {
    state = state.copyWith(apiBaseUrl: url);
  }

  /// Enable/disable narrator
  void setEnabled(bool value) {
    state = state.copyWith(enabled: value);
  }

  /// Toggle vocabulary hints
  void setShowVocabularyHints(bool value) {
    state = state.copyWith(showVocabularyHints: value);
  }

  /// Toggle grammar tips
  void setShowGrammarTips(bool value) {
    state = state.copyWith(showGrammarTips: value);
  }

  /// Add a narrator message
  void _addMessage(NarratorMessage message) {
    final newMessages = [message, ...state.messages];
    if (newMessages.length > 50) {
      newMessages.removeLast();
    }
    state = state.copyWith(messages: newMessages);
  }

  /// Dismiss a narrator message
  void dismissMessage(String messageId) {
    final newMessages = state.messages.map((m) {
      if (m.id == messageId) return m.copyWith(dismissed: true);
      return m;
    }).toList();
    state = state.copyWith(messages: newMessages);
  }

  /// Dismiss all active messages
  void dismissAllMessages() {
    final newMessages = state.messages
        .map((m) => m.dismissed ? m : m.copyWith(dismissed: true))
        .toList();
    state = state.copyWith(messages: newMessages);
  }

  /// Clear all messages
  void clearMessages() {
    state = state.copyWith(messages: const []);
  }

  /// Provide a vocabulary hint when a new word is encountered
  void provideVocabularyHint({
    required String word,
    required String translation,
    String? context,
  }) {
    if (!state.enabled || !state.showVocabularyHints) return;

    // Don't repeat hints for words we've already shown
    if (state.encounteredWords.contains(word.toLowerCase())) return;

    state = state.copyWith(
      encounteredWords: {...state.encounteredWords, word.toLowerCase()},
      learnedVocabulary: {...state.learnedVocabulary, word: translation},
    );

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
    if (!state.enabled || !state.showGrammarTips) return;

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
    if (!state.enabled) return;

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
    if (!state.enabled) return;

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
    if (!state.enabled) return;

    _addMessage(NarratorMessage(
      id: 'quest_${DateTime.now().millisecondsSinceEpoch}',
      type: NarratorMessageType.questGuidance,
      content: '[$questName]\n\n$guidance',
    ));
  }

  /// Process NPC dialogue for vocabulary hints
  /// Called when an NPC speaks to extract Spanish words and provide hints
  void processNPCDialogue(String dialogue, String playerLanguageLevel) {
    if (!state.enabled || !state.showVocabularyHints) return;

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
    // TODO: generalize for other languages
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
    if (!state.enabled) return null;

    try {
      final response = await http.post(
        Uri.parse(ApiEndpoints.narrator),
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

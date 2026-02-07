import 'package:flutter/foundation.dart' show debugPrint;
import 'dart:async';
import 'word_knowledge_service.dart';

/// Types of info cards that can be displayed
enum InfoCardType {
  tip,
  hint,
  reminder,
  achievement,
  cultural,
  wordDefinition,
}

/// Data model for an info card
class InfoCard {
  final String id;
  final InfoCardType type;
  final String title;
  final String content;
  final String? icon;
  final DateTime createdAt;

  InfoCard({
    required this.id,
    required this.type,
    required this.title,
    required this.content,
    this.icon,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type.name,
        'title': title,
        'content': content,
        'icon': icon,
      };
}

/// Represents a message in the conversation for analysis
class ConversationMessage {
  final String role; // 'user' or 'assistant'
  final String content;
  final DateTime timestamp;

  ConversationMessage({
    required this.role,
    required this.content,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// Service that monitors conversation history and generates contextual info cards
class InfoCardService {
  // Singleton pattern
  static final InfoCardService _instance = InfoCardService._internal();
  static InfoCardService get instance => _instance;
  InfoCardService._internal();

  // Stream controller for emitting info cards
  final StreamController<InfoCard> _cardController =
      StreamController<InfoCard>.broadcast();

  /// Stream of info cards that should be displayed
  Stream<InfoCard> get cardStream => _cardController.stream;

  // Track which cards have been shown to avoid duplicates
  final Set<String> _shownCardIds = {};

  // Track message count for certain triggers
  int _messageCount = 0;

  // Hardcoded info cards
  final List<InfoCard> _availableCards = [
    InfoCard(
      id: 'tip_greeting',
      type: InfoCardType.tip,
      title: 'Greeting Tip',
      content:
          'In Spanish, "Hola" is informal. Use "Buenos días" (good morning) or "Buenas tardes" (good afternoon) for formal settings.',
      icon: '💡',
    ),
    InfoCard(
      id: 'cultural_tipping',
      type: InfoCardType.cultural,
      title: 'Cultural Note',
      content:
          'In many Spanish-speaking countries, it\'s common to greet shopkeepers when entering a store, even if you don\'t know them.',
      icon: '🌎',
    ),
    InfoCard(
      id: 'hint_numbers',
      type: InfoCardType.hint,
      title: 'Quick Hint',
      content:
          'When counting in Spanish, remember that "uno" changes to "un" before masculine nouns (un libro = one book).',
      icon: '🔢',
    ),
    InfoCard(
      id: 'tip_questions',
      type: InfoCardType.tip,
      title: 'Question Words',
      content:
          'Spanish question words: ¿Qué? (What?), ¿Dónde? (Where?), ¿Cuándo? (When?), ¿Por qué? (Why?), ¿Cómo? (How?)',
      icon: '❓',
    ),
    InfoCard(
      id: 'cultural_politeness',
      type: InfoCardType.cultural,
      title: 'Being Polite',
      content:
          '"Por favor" (please) and "Gracias" (thank you) go a long way! Add "mucho" for emphasis: "Muchas gracias!"',
      icon: '🙏',
    ),
  ];

  /// Called when the message history changes
  /// Returns a list of info cards that should be displayed (if any)
  List<InfoCard> onMessageHistoryChanged({
    required List<ConversationMessage> messages,
    required String npcId,
  }) {
    _messageCount = messages.length;
    final cardsToShow = <InfoCard>[];

    // Check for various triggers
    for (final card in _availableCards) {
      if (_shownCardIds.contains(card.id)) continue;

      if (_shouldShowCard(card, messages, npcId)) {
        cardsToShow.add(card);
        _shownCardIds.add(card.id);
        _cardController.add(card);
      }
    }

    // Process word knowledge for the latest message
    if (messages.isNotEmpty) {
      final latestMessage = messages.last;
      _processWordKnowledge(latestMessage).catchError((e) {
        debugPrint('[InfoCard] Error in _processWordKnowledge: $e');
      });
    }

    return cardsToShow;
  }

  /// Process a message for word knowledge tracking
  Future<void> _processWordKnowledge(ConversationMessage message) async {
    debugPrint('[InfoCard] _processWordKnowledge called for role: ${message.role}');
    final wordService = WordKnowledgeService.instance;

    if (message.role == 'user') {
      // Track words the user has used
      wordService.processUserInput(message.content);
    } else if (message.role == 'assistant') {
      // Track words seen and show definitions for new ones
      final newWords = await wordService.processModelOutput(message.content);
      debugPrint('[InfoCard] New words found: $newWords');

      // Create definition cards for new words (limit to 3 per message)
      for (final word in (newWords).take(3)) {
        debugPrint('[InfoCard] Calling _createWordDefinitionCard for: "$word"');
        await _createWordDefinitionCard(word);
      }
    }
  }

  /// Create and emit a word definition card
  Future<void> _createWordDefinitionCard(String word) async {
    debugPrint('[InfoCard] _createWordDefinitionCard called for: "$word"');
    final wordService = WordKnowledgeService.instance;
    debugPrint('[InfoCard] About to call fetchDefinition...');
    final definition = await wordService.fetchDefinition(word);
    debugPrint('[InfoCard] fetchDefinition returned: ${definition?.lemma ?? "null"}');

    // Format the definition content
    String content;
    if (definition != null) {
      final defs = definition.lemmaDefinitions.isNotEmpty
          ? definition.lemmaDefinitions
          : definition.rootWordDefinitions;
      content = defs.take(2).join('\n');
    } else {
      debugPrint("[InfoCard] refusing to make an info card with a null definition");
      return;
    }

    final card = InfoCard(
      id: 'word_def_$word',
      type: InfoCardType.wordDefinition,
      title: definition.lemma,
      content: content,
      icon: '\u{1F4D6}',
    );

    debugPrint('[InfoCard] Emitting card for: "$word"');
    _cardController.add(card);
  }

  /// Determines if a specific card should be shown based on context
  bool _shouldShowCard(
    InfoCard card,
    List<ConversationMessage> messages,
    String npcId,
  ) {
    // For now, use simple heuristics for hardcoded cards
    switch (card.id) {
      case 'tip_greeting':
        // Show after first exchange (2 messages)
        return _messageCount >= 2 && _messageCount < 4;

      case 'cultural_tipping':
        // Show after 4 messages if talking to a merchant
        return _messageCount >= 4 &&
            _messageCount < 6 &&
            npcId.contains('merchant');

      case 'hint_numbers':
        // Show if any message contains a number word
        final hasNumberContent = messages.any((m) =>
            m.content.toLowerCase().contains('uno') ||
            m.content.toLowerCase().contains('dos') ||
            m.content.toLowerCase().contains('tres') ||
            m.content.toLowerCase().contains('count') ||
            m.content.toLowerCase().contains('number'));
        return hasNumberContent;

      case 'tip_questions':
        // Show if user asks a question in English that could be in Spanish
        final lastUserMessage = messages.lastWhere(
          (m) => m.role == 'user',
          orElse: () => ConversationMessage(role: 'user', content: ''),
        );
        return lastUserMessage.content.contains('?') && _messageCount >= 3;

      case 'cultural_politeness':
        // Show after 8 messages
        return _messageCount >= 8 && _messageCount < 10;

      default:
        return false;
    }
  }

  /// Manually trigger a specific info card by ID
  InfoCard? triggerCard(String cardId) {
    if (_shownCardIds.contains(cardId)) return null;

    final card = _availableCards.firstWhere(
      (c) => c.id == cardId,
      orElse: () => InfoCard(
        id: 'not_found',
        type: InfoCardType.tip,
        title: '',
        content: '',
      ),
    );

    if (card.id == 'not_found') return null;

    _shownCardIds.add(cardId);
    _cardController.add(card);
    return card;
  }

  /// Get all available card IDs
  List<String> get availableCardIds =>
      _availableCards.map((c) => c.id).toList();

  /// Check if a card has been shown
  bool hasCardBeenShown(String cardId) => _shownCardIds.contains(cardId);

  /// Reset shown cards (e.g., for a new conversation)
  void resetShownCards() {
    _shownCardIds.clear();
    _messageCount = 0;
  }

  /// Reset for a specific NPC conversation
  void resetForNpc(String npcId) {
    // Could track per-NPC state here if needed
    _messageCount = 0;
  }

  /// Clean up resources
  void dispose() {
    _cardController.close();
  }
}

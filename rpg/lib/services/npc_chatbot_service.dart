import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../game_models.dart';

/// Message in a conversation
class ChatMessage {
  final String role; // 'user', 'assistant', 'system', 'tool'
  final String content;
  final String? toolCallId;
  final List<ToolCall>? toolCalls;

  ChatMessage({
    required this.role,
    required this.content,
    this.toolCallId,
    this.toolCalls,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'role': role,
      'content': content,
    };
    if (toolCallId != null) {
      json['tool_call_id'] = toolCallId;
    }
    if (toolCalls != null && toolCalls!.isNotEmpty) {
      json['tool_calls'] = toolCalls!.map((tc) => tc.toJson()).toList();
    }
    return json;
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      role: json['role'] ?? 'assistant',
      content: json['content'] ?? '',
      toolCallId: json['tool_call_id'],
      toolCalls: json['tool_calls'] != null
          ? (json['tool_calls'] as List)
              .map((tc) => ToolCall.fromJson(tc))
              .toList()
          : null,
    );
  }
}

/// A tool call from the assistant
class ToolCall {
  final String id;
  final String name;
  final Map<String, dynamic> arguments;

  ToolCall({
    required this.id,
    required this.name,
    required this.arguments,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': 'function',
        'function': {
          'name': name,
          'arguments': jsonEncode(arguments),
        },
      };

  factory ToolCall.fromJson(Map<String, dynamic> json) {
    final function = json['function'] as Map<String, dynamic>;
    return ToolCall(
      id: json['id'] ?? '',
      name: function['name'] ?? '',
      arguments: function['arguments'] is String
          ? jsonDecode(function['arguments'])
          : function['arguments'] ?? {},
    );
  }
}

/// Result of executing a tool
class ToolResult {
  final String toolCallId;
  final String result;
  final bool success;
  final Map<String, dynamic>? data;

  ToolResult({
    required this.toolCallId,
    required this.result,
    this.success = true,
    this.data,
  });
}

/// Callback for when a tool is executed
typedef ToolExecutionCallback = void Function(String toolName, Map<String, dynamic> args, ToolResult result);

/// NPC Chatbot Service for handling NPC conversations
class NPCChatbotService extends ChangeNotifier {
  static final NPCChatbotService _instance = NPCChatbotService._internal();
  static NPCChatbotService get instance => _instance;

  NPCChatbotService._internal();

  // API configuration
  String _apiBaseUrl = 'http://localhost:8000';

  // Conversation state per NPC
  final Map<String, List<ChatMessage>> _conversations = {};

  // Loading state per NPC
  final Map<String, bool> _loadingStates = {};

  // Streaming state per NPC - accumulates streamed content
  final Map<String, String> _streamingContent = {};

  // Message count per NPC (for guardrails)
  final Map<String, int> _messageCount = {};

  // Tool execution callback
  ToolExecutionCallback? onToolExecuted;

  /// Set the API base URL
  void setApiUrl(String url) {
    _apiBaseUrl = url;
  }

  /// Check if an NPC conversation is loading
  bool isLoading(String npcId) => _loadingStates[npcId] ?? false;

  /// Get conversation history for an NPC
  List<ChatMessage> getConversation(String npcId) => _conversations[npcId] ?? [];

  /// Clear conversation for an NPC
  void clearConversation(String npcId) {
    _conversations.remove(npcId);
    _messageCount.remove(npcId);
    _streamingContent.remove(npcId);
    notifyListeners();
  }

  /// Get the streaming content for an NPC (accumulated during stream)
  String getStreamingContent(String npcId) => _streamingContent[npcId] ?? '';

  /// Get message count for an NPC (for guardrails)
  int getMessageCount(String npcId) => _messageCount[npcId] ?? 0;

  /// Get language ratio guidance based on player level
  String _getLanguageRatioGuidance(String level) {
    // Core principle that applies to ALL levels
    const coreRule = '''CRITICAL LANGUAGE RULE:
- ENGLISH parts must ALWAYS be fluent, natural, and sophisticated - speak like a normal adult
- ONLY the SPANISH parts should be simplified based on the player's level
- NEVER use baby talk, overly simple sentences, or dumbed-down English
- You are a native speaker having a real conversation, not a language teacher''';

    switch (level.toUpperCase()) {
      case 'A0':
        return '''$coreRule

LANGUAGE MIX (A0 - Absolute Beginner): 90% English, 10% Spanish
- Speak naturally in English, sprinkling in basic Spanish words
- Spanish vocabulary: greetings (hola, adiós), simple nouns (manzana, agua), numbers 1-5
- Example: "Good morning! The weather's lovely today, isn't it? I just got these fresh apples in - una manzana for you perhaps?"''';

      case 'A0+':
        return '''$coreRule

LANGUAGE MIX (A0+ - Upper Beginner): 75% English, 25% Spanish
- Natural English with more Spanish words woven in
- Spanish vocabulary: colors, numbers 1-10, common objects, basic verbs (tengo, quiero)
- Example: "Good morning! I've got some wonderful produce today. These manzanas rojas are particularly sweet - tres for the price of two if you're interested."''';

      case 'A1':
        return '''$coreRule

LANGUAGE MIX (A1 - Elementary): 60% English, 40% Spanish
- Blend both languages naturally in conversation
- Use complete Spanish phrases for common expressions
- Example: "Buenos días! I was hoping you'd stop by. Tengo manzanas frescas today - the farmer delivered them just this morning. ¿Quieres comprar some?"''';

      case 'A1+':
        return '''$coreRule

LANGUAGE MIX (A1+ - Upper Elementary): 50% English, 50% Spanish
- Equal balance, switching fluidly between languages
- Complete Spanish sentences for familiar topics
- Example: "¡Hola! ¿Cómo estás? I've been waiting for someone who appreciates good fruit. Tengo frutas muy buenas - you won't find better anywhere in the village."''';

      case 'A2':
        return '''$coreRule

LANGUAGE MIX (A2 - Pre-Intermediate): 40% English, 60% Spanish
- Favor Spanish for most communication
- English for emphasis or nuance
- Example: "Buenos días, amigo. Hoy tengo manzanas y naranjas muy frescas. You know, the ones from the orchard up the hill - absolutely divine. ¿Qué te gustaría comprar?"''';

      case 'A2+':
      case 'B1':
        return '''$coreRule

LANGUAGE MIX (A2+/B1 - Intermediate): 25% English, 75% Spanish
- Spanish for most conversation
- English sparingly for complex ideas or emphasis
- Example: "¡Buenos días! Hoy tengo frutas increíbles del mercado - honestly, the best selection I've seen all season. Manzanas, naranjas, plátanos... ¿Qué prefieres?"''';

      case 'B1+':
      case 'B2':
        return '''$coreRule

LANGUAGE MIX (B1+/B2 - Upper Intermediate): 10% English, 90% Spanish
- Almost entirely Spanish
- Rare English for cultural references or emphasis
- Example: "¡Buenos días, amigo! Hoy tengo las mejores frutas de todo el mercado. Las manzanas son perfectas - you know, the kind that remind you of autumn back home. ¿Te gustaría probar una?"''';

      case 'B2+':
      case 'C1':
      case 'C1+':
      case 'C2':
        return '''$coreRule

LANGUAGE MIX (B2+ through C2 - Advanced): 95-100% Spanish
- Speak entirely in Spanish with natural, complex expressions
- English only for specific cultural references if absolutely needed
- Example: "¡Buenos días! ¿Cómo te va hoy? Mira estas manzanas maravillosas que acabo de recibir del huerto. Son dulces, crujientes, perfectas para comer ahora mismo. ¿Te llevo algunas?"''';

      default:
        return '''$coreRule

LANGUAGE MIX (Default): 80% English, 20% Spanish
- Speak naturally in English, introducing Spanish words in context
- Never simplify the English - only the Spanish should match their level''';
    }
  }

  /// Build the system prompt for an NPC
  String buildSystemPrompt(NPC npc, Player player, {
    List<Quest>? availableQuests,
    List<Quest>? activeQuests,
  }) {
    final buffer = StringBuffer();

    // Base character info with integrated agent prompt
    buffer.writeln('=== YOUR CHARACTER ===');
    buffer.writeln('You are ${npc.name.nativeLanguage}, ${npc.title.nativeLanguage}.');

    // Agent prompt - this is the NPC's core definition
    if (npc.agentPrompt.isNotEmpty) {
      buffer.writeln();
      buffer.writeln(npc.agentPrompt);
    }

    buffer.writeln();

    // Appearance
    if (npc.appearance.isNotEmpty) {
      buffer.writeln('Appearance: ${npc.appearance.nativeLanguage}');
    }

    // Personality - expand with more detail
    if (npc.personality.traits.isNotEmpty ||
        npc.personality.speakingStyle.isNotEmpty ||
        npc.personality.quirks.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('=== YOUR PERSONALITY ===');

      if (npc.personality.traits.isNotEmpty) {
        final traits = npc.personality.traits
            .map((t) => t.nativeLanguage)
            .join(', ');
        buffer.writeln('You are: $traits');
      }

      if (npc.personality.speakingStyle.isNotEmpty) {
        buffer.writeln('Speaking style: ${npc.personality.speakingStyle.nativeLanguage}');
      }

      if (npc.personality.quirks.isNotEmpty) {
        final quirks = npc.personality.quirks
            .map((q) => q.nativeLanguage)
            .join(', ');
        buffer.writeln('Quirks: $quirks');
        buffer.writeln('Embody these quirks naturally in your behavior and speech.');
      }
    }

    // Knowledge - be specific about what you can/can't discuss
    if (npc.knowledge.knowsAbout.isNotEmpty || npc.knowledge.doesNotKnow.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('=== YOUR KNOWLEDGE ===');

      if (npc.knowledge.knowsAbout.isNotEmpty) {
        final knows = npc.knowledge.knowsAbout
            .map((k) => k.nativeLanguage)
            .join(', ');
        buffer.writeln('You are knowledgeable about: $knows');
        buffer.writeln('Feel free to discuss these topics naturally and share your expertise.');
      }

      if (npc.knowledge.doesNotKnow.isNotEmpty) {
        final doesntKnow = npc.knowledge.doesNotKnow
            .map((k) => k.nativeLanguage)
            .join(', ');
        buffer.writeln();
        buffer.writeln('You do NOT know about: $doesntKnow');
        buffer.writeln('If asked about these topics, naturally deflect or admit ignorance in character.');
        buffer.writeln('Example: "I don\'t know much about that" or "That\'s not really my area"');
      }
    }

    // Behavioral boundaries - clear guidelines for what you do/don't do
    if (npc.behavioralBoundaries.willDo.isNotEmpty ||
        npc.behavioralBoundaries.willNotDo.isNotEmpty ||
        npc.behavioralBoundaries.conditions.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('=== YOUR BOUNDARIES ===');

      if (npc.behavioralBoundaries.willDo.isNotEmpty) {
        buffer.writeln('You WILL: ${npc.behavioralBoundaries.willDo.join(', ')}');
        buffer.writeln('These are activities you\'re happy to engage in.');
      }

      if (npc.behavioralBoundaries.willNotDo.isNotEmpty) {
        buffer.writeln();
        buffer.writeln('You will NOT: ${npc.behavioralBoundaries.willNotDo.join(', ')}');
        buffer.writeln('Politely refuse or deflect if asked to do these things.');
      }

      if (npc.behavioralBoundaries.conditions.isNotEmpty) {
        buffer.writeln();
        buffer.writeln('Conditions: ${npc.behavioralBoundaries.conditions.join(', ')}');
        buffer.writeln('These are important aspects of how you always behave.');
      }
    }

    // Language and immersion context with level-based ratio
    buffer.writeln();
    buffer.writeln('=== ABSOLUTE IMMERSION RULES ===');
    buffer.writeln('You are a native Spanish speaker in this world. The player\'s Spanish proficiency: ${player.languageLevel}');
    buffer.writeln();
    buffer.writeln(_getLanguageRatioGuidance(player.languageLevel));
    buffer.writeln();
    buffer.writeln('CRITICAL - NEVER BREAK CHARACTER. YOU MUST FOLLOW THESE RULES:');
    buffer.writeln();
    buffer.writeln('1. NEVER TEACH OR TUTOR:');
    buffer.writeln('   - Do NOT explain what words mean or provide translations');
    buffer.writeln('   - Do NOT teach vocabulary or grammar rules');
    buffer.writeln('   - Do NOT say things like "that means..." or "in Spanish we say..."');
    buffer.writeln('   - Do NOT offer language lessons or practice');
    buffer.writeln();
    buffer.writeln('2. NEVER CORRECT THE PLAYER:');
    buffer.writeln('   - Do NOT correct their grammar or pronunciation');
    buffer.writeln('   - Do NOT say "you should say X instead of Y"');
    buffer.writeln('   - Do NOT point out mistakes in their Spanish');
    buffer.writeln('   - If they make errors, simply respond to their intended meaning');
    buffer.writeln();
    buffer.writeln('3. NEVER ACKNOWLEDGE THEY ARE LEARNING:');
    buffer.writeln('   - Do NOT mention that they are learning Spanish');
    buffer.writeln('   - Do NOT praise their language skills or progress');
    buffer.writeln('   - Do NOT say "good job" or "well done" about their Spanish');
    buffer.writeln('   - Do NOT reference language levels, lessons, or learning');
    buffer.writeln('   - Treat them as a fellow inhabitant of this world who naturally speaks your language');
    buffer.writeln();
    buffer.writeln('4. ALWAYS STAY IN CHARACTER:');
    buffer.writeln('   - React to WHAT the player says, not HOW they say it');
    buffer.writeln('   - If you don\'t understand them, respond naturally as your character would (confused, ask for clarification in-character)');
    buffer.writeln('   - Never use emojis. Express emotion through words and actions.');
    buffer.writeln('   - Your ONLY job is to be an authentic character in this world');
    buffer.writeln();
    buffer.writeln('5. SPEAK NATURALLY BEFORE USING TOOLS:');
    buffer.writeln('   - ALWAYS say something conversational first');
    buffer.writeln('   - NEVER use tools without speaking naturally beforehand');
    buffer.writeln('   - Example: Instead of immediately offering a quest, greet them and chat briefly first');
    buffer.writeln();
    buffer.writeln('Remember: A separate narrator/tutor exists outside the game world to help with language learning. Your role is purely immersion.');

    // Player context
    buffer.writeln('=== PLAYER CONTEXT ===');
    buffer.writeln('Player name: ${player.name}');
    buffer.writeln('Player gold: ${player.gold}');

    // Quest context - Available quests this NPC can offer
    if (availableQuests != null && availableQuests.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('=== QUESTS YOU CAN OFFER ===');
      buffer.writeln('You have ${availableQuests.length} quest(s) available to offer the player:');
      for (final quest in availableQuests) {
        buffer.writeln();
        buffer.writeln('QUEST: ${quest.displayName} (ID: ${quest.id})');
        buffer.writeln('Type: ${quest.type}, Pattern: ${quest.pattern}');
        buffer.writeln('Description: ${quest.displayDescription}');
        buffer.writeln('Language Level: ${quest.languageLevel}');
        buffer.writeln('Offer dialogue: "${quest.dialogue.questOffer.nativeLanguage}"');
        buffer.writeln('Accept dialogue: "${quest.dialogue.questAccept.nativeLanguage}"');
        if (quest.languageLearning.targetVocabulary.isNotEmpty) {
          buffer.writeln('Vocabulary to teach: ${quest.languageLearning.targetVocabulary.map((v) => "${v.nativeLanguage} (${v.targetLanguage})").join(", ")}');
        }
        buffer.writeln('XP Reward: ${quest.rewards.experience}');
      }
      buffer.writeln();
      buffer.writeln('QUEST OFFERING ETIQUETTE - IMPORTANT:');
      buffer.writeln('- DO NOT offer quests in your very first message to the player');
      buffer.writeln('- First establish rapport: greet them, make small talk, respond to what they say');
      buffer.writeln('- After you\'ve exchanged pleasantries (2-3 messages), THEN naturally mention you have work');
      buffer.writeln('- Example flow:');
      buffer.writeln('  1. You: "¡Hola! Welcome to my shop. How are you today?"');
      buffer.writeln('  2. Player: "I\'m good, thanks!"');
      buffer.writeln('  3. You: "Wonderful! Actually, I could use some help. I need someone to deliver apples..." [NOW use offer_quest tool]');
      buffer.writeln('- Use the offer_quest tool ONLY after establishing a conversational connection');
      buffer.writeln('- Be eager to help but not pushy - you\'re a real person, not a quest dispenser');
    }

    // Active quests from this NPC
    if (activeQuests != null && activeQuests.isNotEmpty) {
      final myActiveQuests = activeQuests.where((q) => q.giverNpcId == npc.id).toList();
      if (myActiveQuests.isNotEmpty) {
        buffer.writeln();
        buffer.writeln('=== ACTIVE QUESTS FROM YOU ===');
        buffer.writeln('The player has ${myActiveQuests.length} active quest(s) from you:');
        for (final quest in myActiveQuests) {
          buffer.writeln();
          buffer.writeln('QUEST: ${quest.displayName} (ID: ${quest.id})');
          buffer.writeln('Progress: ${quest.completedTaskCount}/${quest.tasks.length} tasks completed (${quest.progressPercent})');
          final currentTask = quest.currentTask;
          if (currentTask != null) {
            buffer.writeln('Current task: ${currentTask.displayDescription}');
            buffer.writeln('Hint: ${currentTask.displayHint}');
          }
          buffer.writeln('Progress dialogue: "${quest.dialogue.questProgress.nativeLanguage}"');
          if (quest.tasks.every((t) => t.completed)) {
            buffer.writeln('*** QUEST READY TO COMPLETE! Use complete_quest tool! ***');
            buffer.writeln('Completion dialogue: "${quest.dialogue.questComplete.nativeLanguage}"');
          }
        }
      }
    }

    // Example interactions
    if (npc.exampleInteractions.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('=== EXAMPLE INTERACTIONS ===');
      for (final example in npc.exampleInteractions) {
        buffer.writeln('Player: ${example.playerAction}');
        buffer.writeln('You: ${example.npcResponse.nativeLanguage}');
        buffer.writeln('(${example.npcResponse.targetLanguage})');
        buffer.writeln('Reasoning: ${example.reasoning}');
        buffer.writeln();
      }
    }

    return buffer.toString();
  }

  /// Get the tool definitions for NPCs
  /// If availableQuests is provided and not empty, quest tools will be added
  List<Map<String, dynamic>> getToolDefinitions(NPC npc, {List<Quest>? availableQuests}) {
    final tools = <Map<String, dynamic>>[];
    final hasQuestsToOffer = availableQuests != null && availableQuests.isNotEmpty;

    // End conversation tool - all NPCs
    tools.add({
      'type': 'function',
      'function': {
        'name': 'end_conversation',
        'description': 'End the conversation with the player. Use when saying goodbye or when the conversation naturally concludes.',
        'parameters': {
          'type': 'object',
          'properties': {
            'farewell_message': {
              'type': 'string',
              'description': 'Optional farewell message',
            },
          },
        },
      },
    });

    // Merchant-specific tools
    if (npc.archetype == 'merchant') {
      tools.add({
        'type': 'function',
        'function': {
          'name': 'sell_item',
          'description': 'Offer to sell an item to the player. This will show a purchase popup where the player can accept or decline. Use this when the player wants to buy something.',
          'parameters': {
            'type': 'object',
            'properties': {
              'item_id': {
                'type': 'string',
                'description': 'ID of the item (e.g., "apple", "health_potion")',
              },
              'item_name': {
                'type': 'string',
                'description': 'Display name of the item',
              },
              'price': {
                'type': 'integer',
                'description': 'Price in gold',
              },
              'reason': {
                'type': 'string',
                'description': 'Optional sales pitch or description',
              },
            },
            'required': ['item_id', 'item_name', 'price'],
          },
        },
      });
    }

    // Quest giver tools - add for any NPC with quests to offer OR marked as quest giver
    if (hasQuestsToOffer || npc.archetype == 'quest_giver' || npc.questRoles.isNotEmpty) {
      tools.add({
        'type': 'function',
        'function': {
          'name': 'offer_quest',
          'description': 'Offer a quest to the player',
          'parameters': {
            'type': 'object',
            'properties': {
              'quest_id': {
                'type': 'string',
                'description': 'ID of the quest to offer',
              },
              'quest_description': {
                'type': 'string',
                'description': 'Brief description of the quest',
              },
            },
            'required': ['quest_id'],
          },
        },
      });

      tools.add({
        'type': 'function',
        'function': {
          'name': 'check_quest_progress',
          'description': 'Check the player\'s progress on a quest',
          'parameters': {
            'type': 'object',
            'properties': {
              'quest_id': {
                'type': 'string',
                'description': 'ID of the quest to check',
              },
            },
            'required': ['quest_id'],
          },
        },
      });

      tools.add({
        'type': 'function',
        'function': {
          'name': 'complete_quest',
          'description': 'Mark a quest as complete and give rewards',
          'parameters': {
            'type': 'object',
            'properties': {
              'quest_id': {
                'type': 'string',
                'description': 'ID of the quest to complete',
              },
            },
            'required': ['quest_id'],
          },
        },
      });
    }

    // Child NPC tools (games)
    if (npc.archetype == 'child') {
      tools.add({
        'type': 'function',
        'function': {
          'name': 'start_counting_game',
          'description': 'Start a counting game with the player',
          'parameters': {
            'type': 'object',
            'properties': {
              'max_number': {
                'type': 'integer',
                'description': 'Maximum number to count to (default 10)',
              },
            },
          },
        },
      });

      tools.add({
        'type': 'function',
        'function': {
          'name': 'play_word_game',
          'description': 'Play a simple word game (colors, animals, etc.)',
          'parameters': {
            'type': 'object',
            'properties': {
              'category': {
                'type': 'string',
                'description': 'Category of words to practice',
              },
            },
            'required': ['category'],
          },
        },
      });
    }

    // Give item tool (for any NPC that might give items)
    tools.add({
      'type': 'function',
      'function': {
        'name': 'give_item',
        'description': 'Offer to give an item to the player as a gift or reward. This shows a popup where the player can accept or decline the gift.',
        'parameters': {
          'type': 'object',
          'properties': {
            'item_id': {
              'type': 'string',
              'description': 'ID of the item to give (e.g., "apple", "health_potion")',
            },
            'item_name': {
              'type': 'string',
              'description': 'Display name of the item',
            },
            'reason': {
              'type': 'string',
              'description': 'Reason for giving the item',
            },
          },
          'required': ['item_id', 'item_name'],
        },
      },
    });

    // Request item tool (for any NPC that might ask for items)
    tools.add({
      'type': 'function',
      'function': {
        'name': 'request_item',
        'description': 'Ask the player to give you an item. This shows a popup where the player can give you the item or decline. You do NOT know what items the player has - just ask for what you need and the player will be prompted accordingly.',
        'parameters': {
          'type': 'object',
          'properties': {
            'item_id': {
              'type': 'string',
              'description': 'ID of the item you are requesting (e.g., "apple", "letter")',
            },
            'item_name': {
              'type': 'string',
              'description': 'Display name of the item you are requesting',
            },
            'reason': {
              'type': 'string',
              'description': 'Why you need this item',
            },
          },
          'required': ['item_id', 'item_name'],
        },
      },
    });

    return tools;
  }

  /// Send a message with streaming response
  /// Returns a Stream that yields content as it arrives from the model
  Stream<String> sendMessageStream({
    required NPC npc,
    required Player player,
    required String userMessage,
    required Map<String, Quest> availableQuests,
    List<Quest>? npcAvailableQuests,
    List<Quest>? activeQuests,
  }) async* {
    debugPrint('[SERVICE] sendMessageStream called for NPC: ${npc.id}');
    _loadingStates[npc.id] = true;
    _streamingContent[npc.id] = '';
    notifyListeners();

    try {
      // Build fresh system prompt with current quest data
      final systemPrompt = buildSystemPrompt(
        npc,
        player,
        availableQuests: npcAvailableQuests,
        activeQuests: activeQuests,
      );

      // Initialize conversation or update system prompt
      if (!_conversations.containsKey(npc.id)) {
        _conversations[npc.id] = [
          ChatMessage(
            role: 'system',
            content: systemPrompt,
          ),
        ];
        _messageCount[npc.id] = 0;
      } else {
        // Update the system prompt with fresh quest data
        if (_conversations[npc.id]!.isNotEmpty &&
            _conversations[npc.id]![0].role == 'system') {
          _conversations[npc.id]![0] = ChatMessage(
            role: 'system',
            content: systemPrompt,
          );
        }
      }

      // Add user message
      _conversations[npc.id]!.add(ChatMessage(
        role: 'user',
        content: userMessage,
      ));

      // Increment message count
      _messageCount[npc.id] = (_messageCount[npc.id] ?? 0) + 1;

      // Call streaming API
      final tools = getToolDefinitions(npc, availableQuests: npcAvailableQuests);
      debugPrint('Streaming with ${tools.length} tools for ${npc.id}, message count: ${_messageCount[npc.id]}');

      await for (final content in _callStreamingAPI(
        npc: npc,
        messages: _conversations[npc.id]!,
        tools: tools,
        messageCount: _messageCount[npc.id] ?? 0,
        player: player,
        availableQuests: availableQuests,
      )) {
        // Accumulate content
        _streamingContent[npc.id] = (_streamingContent[npc.id] ?? '') + content;
        yield content;
        notifyListeners();
      }

      // After stream completes, add final message to conversation
      final finalContent = _streamingContent[npc.id] ?? '';
      _conversations[npc.id]!.add(ChatMessage(
        role: 'assistant',
        content: finalContent,
      ));

      _loadingStates[npc.id] = false;
      _streamingContent.remove(npc.id);
      notifyListeners();

    } catch (e) {
      debugPrint('Error in streaming NPC chat: $e');
      _loadingStates[npc.id] = false;
      _streamingContent.remove(npc.id);
      notifyListeners();

      yield npc.greeting.isNotEmpty
          ? '${npc.displayGreeting} (Sorry, I\'m having trouble thinking right now...)'
          : 'Hello! (Sorry, I\'m having trouble thinking right now...)';
    }
  }

  /// Initiate a conversation with an NPC (NPC speaks first) - streaming version
  /// This is called when the player approaches an NPC to start talking
  /// Returns a Stream that yields content as it arrives from the model
  Stream<String> initiateConversationStream({
    required NPC npc,
    required Player player,
    required Map<String, Quest> availableQuests,
    List<Quest>? npcAvailableQuests,
    List<Quest>? activeQuests,
  }) async* {
    debugPrint('[SERVICE] initiateConversationStream called for NPC: ${npc.id}');
    _loadingStates[npc.id] = true;
    _streamingContent[npc.id] = '';
    _messageCount[npc.id] = 0;  // Reset message count for new conversation
    notifyListeners();

    try {
      // Build fresh system prompt with current quest data
      final systemPrompt = buildSystemPrompt(
        npc,
        player,
        availableQuests: npcAvailableQuests,
        activeQuests: activeQuests,
      );

      // Initialize conversation with system prompt
      _conversations[npc.id] = [
        ChatMessage(
          role: 'system',
          content: systemPrompt,
        ),
        // Add a message indicating the player has approached
        ChatMessage(
          role: 'user',
          content: '[The player "${player.name}" has approached you to start a conversation. Greet them in character and initiate the conversation based on your personality, current situation, and any quests you might want to offer or discuss.]',
        ),
      ];

      // Make streaming API call to get NPC's opening
      final tools = getToolDefinitions(npc, availableQuests: npcAvailableQuests);
      debugPrint('Initiating conversation with ${npc.id}, tools: ${tools.map((t) => t['function']['name']).toList()}');

      await for (final content in _callStreamingAPI(
        npc: npc,
        messages: _conversations[npc.id]!,
        tools: tools,
        messageCount: _messageCount[npc.id] ?? 0,
        player: player,
        availableQuests: availableQuests,
      )) {
        // Accumulate content
        _streamingContent[npc.id] = (_streamingContent[npc.id] ?? '') + content;
        yield content;
        notifyListeners();
      }

      // After stream completes, add final message to conversation
      final finalContent = _streamingContent[npc.id] ?? '';
      if (finalContent.isNotEmpty) {
        _conversations[npc.id]!.add(ChatMessage(
          role: 'assistant',
          content: finalContent,
        ));
      }

      _loadingStates[npc.id] = false;
      _streamingContent.remove(npc.id);
      notifyListeners();

    } catch (e) {
      debugPrint('Error initiating NPC conversation: $e');
      _loadingStates[npc.id] = false;
      _streamingContent.remove(npc.id);
      notifyListeners();

      // Fallback to static greeting
      yield npc.greeting.isNotEmpty
          ? npc.displayGreeting
          : 'Hello, traveler!';
    }
  }

  /// Make streaming API call using SSE
  /// Uses dart:io HttpClient directly for proper streaming support
  Stream<String> _callStreamingAPI({
    required NPC npc,
    required List<ChatMessage> messages,
    required List<Map<String, dynamic>> tools,
    required int messageCount,
    required Player player,
    required Map<String, Quest> availableQuests,
  }) async* {
    debugPrint('[SERVICE] _callStreamingAPI called for NPC: ${npc.id}, URL: $_apiBaseUrl/chat/stream');
    HttpClient? httpClient;
    HttpClientRequest? request;
    HttpClientResponse? response;

    try {
      final uri = Uri.parse('$_apiBaseUrl/chat/stream');

      // Use dart:io HttpClient for true streaming support
      httpClient = HttpClient();
      request = await httpClient.postUrl(uri);

      // Set headers
      request.headers.set('Content-Type', 'application/json');
      request.headers.set('Accept', 'text/event-stream');
      request.headers.set('Cache-Control', 'no-cache');

      // Write body
      final bodyMap = {
        'messages': messages.map((m) => m.toJson()).toList(),
        'tools': tools,
        'npc_id': npc.id,
        'message_count': messageCount,
      };

      final bodyJson = jsonEncode(bodyMap);
      debugPrint('[SERVICE] Request body length: ${bodyJson.length}');
      debugPrint('[SERVICE] Request body: $bodyJson');

      // Explicitly encode as UTF-8 bytes
      final bodyBytes = utf8.encode(bodyJson);
      request.add(bodyBytes);

      // Send request and get response
      final requestStartTime = DateTime.now();
      debugPrint('[SERVICE] [$requestStartTime] Sending HTTP request...');
      response = await request.close();
      final responseTime = DateTime.now();
      final requestDuration = responseTime.difference(requestStartTime);
      debugPrint('[SERVICE] [$responseTime] Got response with status: ${response.statusCode} (took ${requestDuration.inMilliseconds}ms)');

      if (response.statusCode != 200) {
        // Read error response body
        final errorBody = await response.transform(utf8.decoder).join();
        debugPrint('[SERVICE] Error response body: $errorBody');
        return;
      }

      // Process SSE stream - use streaming UTF-8 decoder to handle multi-byte characters across chunk boundaries
      String buffer = '';
      int chunkCount = 0;
      final streamStartTime = DateTime.now();

      debugPrint('[SSE] [$streamStartTime] Starting to listen to response stream...');
      await for (final chunk in response.transform(utf8.decoder)) {
        chunkCount++;
        final chunkTime = DateTime.now();
        final elapsed = chunkTime.difference(streamStartTime);
        debugPrint('[SSE] [$chunkTime] Chunk #$chunkCount received after ${elapsed.inMilliseconds}ms (${chunk.length} chars): ${chunk.length > 100 ? "${chunk.substring(0, 100)}..." : chunk}');
        buffer += chunk;

        // Process complete SSE messages (delimited by \n\n)
        while (buffer.contains('\n\n')) {
          final endIndex = buffer.indexOf('\n\n');
          final message = buffer.substring(0, endIndex);
          buffer = buffer.substring(endIndex + 2);

          // Parse SSE data
          if (message.startsWith('data: ')) {
            final jsonStr = message.substring(6);
            debugPrint('[SSE] Parsing SSE message: ${jsonStr.length > 200 ? "${jsonStr.substring(0, 200)}..." : jsonStr}');
            try {
              final data = jsonDecode(jsonStr);
              final type = data['type'];
              debugPrint('[SSE] Message type: $type');

              if (type == 'content') {
                // Yield streaming content immediately
                final contentChunk = data['content'] as String;
                final yieldTime = DateTime.now();
                final elapsed = yieldTime.difference(streamStartTime);
                debugPrint('[SSE] [$yieldTime] >>> YIELDING to UI after ${elapsed.inMilliseconds}ms: "${contentChunk.length > 50 ? "${contentChunk.substring(0, 50)}..." : contentChunk}" (${contentChunk.length} chars)');
                yield contentChunk;
              } else if (type == 'done') {
                // Final message with potential tool calls
                final content = data['content'] as String?;
                if (content != null && content.isNotEmpty) {
                  // Any remaining content
                  yield content;
                }

                // Handle tool calls if present
                if (data['tool_calls'] != null) {
                  final toolCalls = (data['tool_calls'] as List)
                      .map((tc) => ToolCall.fromJson(tc))
                      .toList();

                  // Add assistant message with tool calls
                  _conversations[npc.id]!.add(ChatMessage(
                    role: 'assistant',
                    content: _streamingContent[npc.id] ?? '',
                    toolCalls: toolCalls,
                  ));

                  // Execute tools
                  for (final toolCall in toolCalls) {
                    final result = await _executeToolCall(
                      toolCall: toolCall,
                      npc: npc,
                      player: player,
                      availableQuests: availableQuests,
                    );

                    // Add tool result
                    _conversations[npc.id]!.add(ChatMessage(
                      role: 'tool',
                      content: result.result,
                      toolCallId: toolCall.id,
                    ));

                    // Notify callback
                    onToolExecuted?.call(toolCall.name, toolCall.arguments, result);
                  }
                }
              } else if (type == 'error') {
                debugPrint('Stream error: ${data['error']}');
              }
            } catch (e) {
              debugPrint('Error parsing SSE data: $e');
            }
          }
        }
      }
    } catch (e, stackTrace) {
      debugPrint('[SERVICE] Streaming network error: $e');
      debugPrint('[SERVICE] Stack trace: $stackTrace');
    } finally {
      debugPrint('[SERVICE] _callStreamingAPI finished');
      httpClient?.close();
    }
  }

  /// Execute a tool call
  Future<ToolResult> _executeToolCall({
    required ToolCall toolCall,
    required NPC npc,
    required Player player,
    required Map<String, Quest> availableQuests,
  }) async {
    final args = toolCall.arguments;

    switch (toolCall.name) {
      case 'end_conversation':
        return ToolResult(
          toolCallId: toolCall.id,
          result: 'Conversation ended',
          data: {
            'type': 'end_conversation',
            'farewell': args['farewell_message'],
          },
        );

      case 'sell_item':
        // NPC offers to sell an item - triggers interaction popup
        final price = args['price'] as int;
        final canAfford = player.gold >= price;
        return ToolResult(
          toolCallId: toolCall.id,
          result: canAfford
              ? 'Offering ${args['item_name']} for $price gold. The player will be prompted to accept or decline.'
              : 'Offering ${args['item_name']} for $price gold, but the player only has ${player.gold} gold.',
          data: {
            'type': 'sell_item',
            'npc_id': npc.id,
            'npc_name': npc.displayName,
            'item_id': args['item_id'],
            'item_name': args['item_name'],
            'price': price,
            'reason': args['reason'],
            'player_can_afford': canAfford,
          },
        );

      case 'offer_quest':
        final questId = args['quest_id'] as String;
        final quest = availableQuests[questId];
        if (quest != null) {
          return ToolResult(
            toolCallId: toolCall.id,
            result: 'Quest offered successfully: "${quest.displayName}". The quest offer UI will be shown to the player. Rewards: ${quest.rewards.experience} XP.',
            data: {
              'type': 'offer_quest',
              'quest_id': questId,
              'quest_name': quest.displayName,
              'quest_description': quest.displayDescription,
              'xp_reward': quest.rewards.experience,
            },
          );
        } else {
          return ToolResult(
            toolCallId: toolCall.id,
            result: 'Quest "$questId" is not available. It may have already been accepted, completed, or the player does not meet the requirements.',
            success: false,
          );
        }

      case 'check_quest_progress':
        final questId = args['quest_id'] as String;
        final isActive = player.activeQuests.contains(questId);
        final isComplete = player.completedQuests.contains(questId);
        final quest = availableQuests[questId];

        String progressInfo;
        Map<String, dynamic> data = {
          'type': 'quest_progress',
          'quest_id': questId,
          'is_active': isActive,
          'is_complete': isComplete,
        };

        if (isComplete) {
          progressInfo = 'Quest "$questId" is already completed! The player has finished this quest.';
        } else if (isActive && quest != null) {
          final completedCount = quest.completedTaskCount;
          final totalCount = quest.tasks.length;
          final currentTask = quest.currentTask;
          progressInfo = 'Quest "${quest.displayName}" is in progress. Progress: $completedCount/$totalCount tasks completed (${quest.progressPercent}).';
          if (currentTask != null) {
            progressInfo += ' Current task: "${currentTask.displayDescription}"';
          }
          if (quest.tasks.every((t) => t.completed)) {
            progressInfo += ' ALL TASKS COMPLETE - Ready to turn in!';
          }
          data['progress'] = quest.progress;
          data['completed_tasks'] = completedCount;
          data['total_tasks'] = totalCount;
          data['ready_to_complete'] = quest.tasks.every((t) => t.completed);
        } else {
          progressInfo = 'Quest "$questId" has not been started by the player.';
        }

        return ToolResult(
          toolCallId: toolCall.id,
          result: progressInfo,
          data: data,
        );

      case 'complete_quest':
        final questId = args['quest_id'] as String;
        final quest = availableQuests[questId];
        final isActive = player.activeQuests.contains(questId);

        if (!isActive) {
          return ToolResult(
            toolCallId: toolCall.id,
            result: 'Cannot complete quest "$questId" - it is not active.',
            success: false,
            data: {'type': 'complete_quest_failed', 'reason': 'not_active'},
          );
        }

        if (quest != null && !quest.tasks.every((t) => t.completed)) {
          return ToolResult(
            toolCallId: toolCall.id,
            result: 'Cannot complete quest "${quest.displayName}" yet - not all tasks are done. Progress: ${quest.completedTaskCount}/${quest.tasks.length}',
            success: false,
            data: {'type': 'complete_quest_failed', 'reason': 'tasks_incomplete'},
          );
        }

        return ToolResult(
          toolCallId: toolCall.id,
          result: 'Quest "${quest?.displayName ?? questId}" completed successfully! The completion rewards will be given to the player.',
          data: {
            'type': 'complete_quest',
            'quest_id': questId,
            'quest_name': quest?.displayName,
            'xp_reward': quest?.rewards.experience ?? 0,
          },
        );

      case 'start_counting_game':
        final maxNum = args['max_number'] ?? 10;
        return ToolResult(
          toolCallId: toolCall.id,
          result: 'Starting counting game up to $maxNum!',
          data: {
            'type': 'counting_game',
            'max_number': maxNum,
          },
        );

      case 'play_word_game':
        return ToolResult(
          toolCallId: toolCall.id,
          result: 'Starting word game with category: ${args['category']}',
          data: {
            'type': 'word_game',
            'category': args['category'],
          },
        );

      case 'give_item':
        // NPC offers to give an item to the player - triggers interaction popup
        return ToolResult(
          toolCallId: toolCall.id,
          result: 'Offering ${args['item_name']} to the player as a gift. The player will be prompted to accept or decline.',
          data: {
            'type': 'give_item',
            'npc_id': npc.id,
            'npc_name': npc.displayName,
            'item_id': args['item_id'],
            'item_name': args['item_name'],
            'reason': args['reason'],
          },
        );

      case 'request_item':
        // NPC requests an item from the player - triggers interaction popup
        // Note: We don't tell the NPC whether the player has the item
        final hasItem = player.inventory.contains(args['item_id']);
        return ToolResult(
          toolCallId: toolCall.id,
          result: 'Requesting ${args['item_name']} from the player. The player will be prompted to give you the item if they have it.',
          data: {
            'type': 'request_item',
            'npc_id': npc.id,
            'npc_name': npc.displayName,
            'item_id': args['item_id'],
            'item_name': args['item_name'],
            'reason': args['reason'],
            'player_has_item': hasItem,
          },
        );

      default:
        return ToolResult(
          toolCallId: toolCall.id,
          result: 'Unknown tool: ${toolCall.name}',
          success: false,
        );
    }
  }
}

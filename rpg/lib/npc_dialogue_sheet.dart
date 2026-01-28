import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'game_models.dart';
import 'npc_interaction.dart';
import 'providers/game_provider.dart';
import 'services/npc_chatbot_service.dart';
import 'quest_offer_sheet.dart';
import 'npc_interaction_sheet.dart';

class NPCDialogueSheet extends StatefulWidget {
  final NPC npc;

  const NPCDialogueSheet({super.key, required this.npc});

  @override
  State<NPCDialogueSheet> createState() => _NPCDialogueSheetState();
}

class _NPCDialogueSheetState extends State<NPCDialogueSheet> with SingleTickerProviderStateMixin {
  NPC get npc => widget.npc;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  final List<_ChatBubble> _chatBubbles = [];
  bool _isLoading = false;
  bool _conversationEnded = false;

  // Vocabulary learned in this conversation
  final List<Map<String, String>> _learnedVocabulary = [];

  // Animation controller for typing indicator dots
  late final AnimationController _typingDotsController;

  @override
  void initState() {
    super.initState();
    _typingDotsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _initializeConversation();
  }

  @override
  void dispose() {
    _typingDotsController.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _initializeConversation() {
    // Set up tool execution callback first
    NPCChatbotService.instance.onToolExecuted = _handleToolExecution;

    // Start loading - NPC will initiate conversation
    setState(() {
      _isLoading = true;
    });

    // Get the NPC to initiate the conversation
    _fetchNpcInitiation();
  }

  Future<void> _fetchNpcInitiation() async {
    debugPrint('[UI] _fetchNpcInitiation called');
    final gameProvider = context.read<GameProvider>();
    final player = gameProvider.player;
    final world = gameProvider.world;

    if (player == null || world == null) {
      // Fallback to static greeting if no player/world
      setState(() {
        _chatBubbles.add(_ChatBubble(
          text: npc.displayGreeting.isNotEmpty
              ? npc.displayGreeting
              : 'Hello, traveler!',
          isUser: false,
          npcName: npc.displayName,
        ));
        _isLoading = false;
      });
      return;
    }

    // Get quests this NPC can offer
    final npcAvailableQuests = world.quests.values
        .where((quest) =>
            quest.giverNpcId == npc.id &&
            !player.completedQuests.contains(quest.id) &&
            !player.activeQuests.contains(quest.id) &&
            gameProvider.canOfferQuest(quest.id))
        .toList();

    // Get player's active quests
    final activeQuests = player.activeQuests
        .map((id) => world.quests[id])
        .whereType<Quest>()
        .toList();

    // Use streaming API - update UI as content arrives
    // Don't create placeholder bubble - only add bubble when we have content
    int? streamingBubbleIndex;
    String accumulatedContent = '';
    final uiStreamStart = DateTime.now();
    debugPrint('[UI] [$uiStreamStart] Starting to consume initiation stream...');

    try {
      await for (final chunk in NPCChatbotService.instance.initiateConversationStream(
        npc: npc,
        player: player,
        availableQuests: world.quests,
        npcAvailableQuests: npcAvailableQuests,
        activeQuests: activeQuests,
      )) {
        if (!mounted) break;

        accumulatedContent += chunk;
        final chunkReceiveTime = DateTime.now();
        final elapsed = chunkReceiveTime.difference(uiStreamStart);
        debugPrint('[UI] [$chunkReceiveTime] Initiation stream chunk received after ${elapsed.inMilliseconds}ms: "$chunk" (total: ${accumulatedContent.length} chars)');

        setState(() {
          // Create bubble on first chunk, update on subsequent chunks
          if (streamingBubbleIndex == null) {
            streamingBubbleIndex = _chatBubbles.length;
            _chatBubbles.add(_ChatBubble(
              text: accumulatedContent,
              isUser: false,
              npcName: npc.displayName,
            ));
          } else {
            // Update existing bubble with accumulated content
            _chatBubbles[streamingBubbleIndex!] = _ChatBubble(
              text: accumulatedContent,
              isUser: false,
              npcName: npc.displayName,
            );
          }
        });
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint('[UI] Error in initiation stream: $e');
    }

    final streamEndTime = DateTime.now();
    final totalDuration = streamEndTime.difference(uiStreamStart);
    debugPrint('[UI] [$streamEndTime] Initiation stream completed after ${totalDuration.inMilliseconds}ms. Total content length: ${accumulatedContent.length}');

    if (mounted) {
      setState(() {
        _isLoading = false;
        // Ensure final content is set (in case stream ended without content)
        if (accumulatedContent.isEmpty) {
          // No content was received from stream - add fallback greeting
          _chatBubbles.add(_ChatBubble(
            text: npc.displayGreeting.isNotEmpty
                ? npc.displayGreeting
                : 'Hello, traveler!',
            isUser: false,
            npcName: npc.displayName,
          ));
        }
      });
      _scrollToBottom();
    }
  }

  void _handleToolExecution(String toolName, Map<String, dynamic> args, ToolResult result) {
    if (!mounted) return;

    setState(() {
      switch (toolName) {
        case 'teach_vocabulary':
          _learnedVocabulary.add({
            'native': args['native_word'] ?? '',
            'target': args['target_word'] ?? '',
            'category': args['category'] ?? '',
          });
          _chatBubbles.add(_ChatBubble(
            text: null,
            isUser: false,
            isVocabularyCard: true,
            vocabularyData: {
              'native': args['native_word'],
              'target': args['target_word'],
            },
          ));
          break;

        case 'end_conversation':
          _conversationEnded = true;
          break;

        case 'offer_quest':
          debugPrint('offer_quest tool called with data: ${result.data}');
          if (result.success && result.data != null && result.data!['quest_id'] != null) {
            final questId = result.data!['quest_id'] as String;
            debugPrint('Looking up quest: $questId');
            final gameProvider = context.read<GameProvider>();
            final quest = gameProvider.getQuest(questId);
            debugPrint('Found quest: ${quest?.displayName}');
            if (quest != null) {
              // Use a post-frame callback to ensure the UI is ready
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  _showQuestOffer(context, quest);
                }
              });
            }
          }
          break;

        case 'sell_item':
          // NPC offers to sell an item to the player
          debugPrint('sell_item tool called with data: ${result.data}');
          if (result.data != null) {
            final gameProvider = context.read<GameProvider>();
            final interaction = gameProvider.createSaleOffer(
              npcId: result.data!['npc_id'] as String,
              npcName: result.data!['npc_name'] as String,
              itemId: result.data!['item_id'] as String,
              itemName: result.data!['item_name'] as String,
              price: result.data!['price'] as int,
              reason: result.data!['reason'] as String?,
            );
            if (interaction != null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  _showInteraction(context, interaction);
                }
              });
            }
          }
          break;

        case 'give_item':
          // NPC offers to give an item to the player
          debugPrint('give_item tool called with data: ${result.data}');
          if (result.data != null) {
            final gameProvider = context.read<GameProvider>();
            final interaction = gameProvider.createGiftOffer(
              npcId: result.data!['npc_id'] as String,
              npcName: result.data!['npc_name'] as String,
              itemId: result.data!['item_id'] as String,
              itemName: result.data!['item_name'] as String,
              reason: result.data!['reason'] as String?,
            );
            if (interaction != null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  _showInteraction(context, interaction);
                }
              });
            }
          }
          break;

        case 'request_item':
          // NPC requests an item from the player
          debugPrint('request_item tool called with data: ${result.data}');
          if (result.data != null) {
            final gameProvider = context.read<GameProvider>();
            final interaction = gameProvider.createItemRequest(
              npcId: result.data!['npc_id'] as String,
              npcName: result.data!['npc_name'] as String,
              itemId: result.data!['item_id'] as String,
              itemName: result.data!['item_name'] as String,
              reason: result.data!['reason'] as String?,
            );
            if (interaction != null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  _showInteraction(context, interaction);
                }
              });
            }
          }
          break;

        case 'start_counting_game':
        case 'play_word_game':
          _chatBubbles.add(_ChatBubble(
            text: null,
            isUser: false,
            isGameCard: true,
            gameData: {
              'type': toolName,
              ...args,
            },
          ));
          break;

        case 'complete_quest':
          if (result.success && result.data != null) {
            final questId = result.data!['quest_id'] as String?;
            if (questId != null) {
              final gameProvider = context.read<GameProvider>();
              gameProvider.completeQuest(questId);
              _chatBubbles.add(_ChatBubble(
                text: null,
                isUser: false,
                isQuestComplete: true,
                questCompleteData: {
                  'quest_name': result.data!['quest_name'] ?? questId,
                  'xp_reward': result.data!['xp_reward'] ?? 0,
                },
              ));
            }
          }
          break;
      }
    });
  }

  Future<void> _sendMessage() async {
    debugPrint('[UI] _sendMessage called');
    final message = _messageController.text.trim();
    if (message.isEmpty || _isLoading || _conversationEnded) {
      debugPrint('[UI] _sendMessage early return: empty=${ message.isEmpty}, loading=$_isLoading, ended=$_conversationEnded');
      return;
    }

    final gameProvider = context.read<GameProvider>();
    final player = gameProvider.player;
    if (player == null) return;

    setState(() {
      _chatBubbles.add(_ChatBubble(
        text: message,
        isUser: true,
      ));
      _isLoading = true;
    });

    _messageController.clear();
    _scrollToBottom();

    // Process user input for language learning (grammar check + skill progression)
    await gameProvider.processUserInput(message);

    // Get quests this NPC can offer and active quests from this NPC
    final npcAvailableQuests = gameProvider.getQuestsForNPC(npc.id);
    final activeQuests = gameProvider.activeQuests;

    debugPrint('NPC ${npc.id} available quests: ${npcAvailableQuests.map((q) => q.id).toList()}');
    debugPrint('Active quests: ${activeQuests.map((q) => q.id).toList()}');

    // Use streaming API - update UI as content arrives
    // Don't create placeholder bubble - only add bubble when we have content
    int? streamingBubbleIndex;
    String accumulatedContent = '';
    final uiStreamStart = DateTime.now();
    debugPrint('[UI] [$uiStreamStart] Starting to consume stream...');
    try {
      await for (final chunk in NPCChatbotService.instance.sendMessageStream(
        npc: npc,
        player: player,
        userMessage: message,
        availableQuests: gameProvider.world?.quests ?? {},
        npcAvailableQuests: npcAvailableQuests,
        activeQuests: activeQuests,
      )) {
        if (!mounted) break;

        accumulatedContent += chunk;
        final chunkReceiveTime = DateTime.now();
        final elapsed = chunkReceiveTime.difference(uiStreamStart);
        debugPrint('[UI] [$chunkReceiveTime] Stream chunk received after ${elapsed.inMilliseconds}ms: "$chunk" (total: ${accumulatedContent.length} chars)');

        setState(() {
          // Create bubble on first chunk, update on subsequent chunks
          if (streamingBubbleIndex == null) {
            streamingBubbleIndex = _chatBubbles.length;
            _chatBubbles.add(_ChatBubble(
              text: accumulatedContent,
              isUser: false,
              npcName: npc.displayName,
            ));
          } else {
            // Update existing bubble with accumulated content
            _chatBubbles[streamingBubbleIndex!] = _ChatBubble(
              text: accumulatedContent,
              isUser: false,
              npcName: npc.displayName,
            );
          }
        });
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint('[UI] Streaming error: $e');
    }

    final streamEndTime = DateTime.now();
    final totalDuration = streamEndTime.difference(uiStreamStart);
    debugPrint('[UI] [$streamEndTime] Stream completed after ${totalDuration.inMilliseconds}ms. Total content length: ${accumulatedContent.length}');
    if (mounted) {
      setState(() {
        _isLoading = false;
        // Ensure final content is set (in case stream ended without content)
        if (accumulatedContent.isEmpty) {
          // No content was received from stream - add error message
          _chatBubbles.add(_ChatBubble(
            text: 'I seem to be having trouble responding...',
            isUser: false,
            npcName: npc.displayName,
          ));
        }
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showQuestOffer(BuildContext context, Quest quest) {
    final gameProvider = context.read<GameProvider>();
    gameProvider.offerQuest(quest.id);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => QuestOfferSheet(quest: quest),
    );
  }

  void _showInteraction(BuildContext context, NPCInteractionRequest interaction) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => NPCInteractionSheet(interaction: interaction),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GameProvider>(
      builder: (context, gameProvider, child) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A2E),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                border: Border.all(
                  color: _getNPCColor().withOpacity(0.3),
                ),
              ),
              child: Column(
                children: [
                  // Handle
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  // NPC Header
                  _buildNPCHeader(context),

                  const Divider(height: 1),

                  // Chat messages
                  Expanded(
                    child: _buildChatArea(),
                  ),

                  // Learned vocabulary summary (if any)
                  if (_learnedVocabulary.isNotEmpty)
                    _buildVocabularySummary(),

                  // Input area or farewell button
                  _conversationEnded
                      ? _buildFarewellButton(gameProvider)
                      : _buildInputArea(),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildNPCHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // NPC avatar
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _getNPCColor().withOpacity(0.2),
              border: Border.all(
                color: _getNPCColor(),
                width: 2,
              ),
            ),
            child: Center(
              child: Text(
                _getNPCEmoji(),
                style: const TextStyle(fontSize: 28),
              ),
            ),
          ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.8, 0.8)),

          const SizedBox(width: 12),

          // NPC info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  npc.displayName,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: _getNPCColor(),
                      ),
                ),
                if (npc.displayTitle.isNotEmpty)
                  Text(
                    npc.displayTitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white54,
                        ),
                  ),
              ],
            ),
          ),

          // Language level badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.green.withOpacity(0.2),
            ),
            child: Text(
              npc.languageLevel,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatArea() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _chatBubbles.length + (_isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _chatBubbles.length && _isLoading) {
          return _buildTypingIndicator();
        }

        final bubble = _chatBubbles[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildChatBubble(bubble),
        );
      },
    );
  }

  Widget _buildChatBubble(_ChatBubble bubble) {
    if (bubble.isVocabularyCard) {
      return _buildVocabularyCard(bubble.vocabularyData!);
    }

    if (bubble.isGameCard) {
      return _buildGameCard(bubble.gameData!);
    }

    if (bubble.isQuestComplete) {
      return _buildQuestCompleteCard(bubble.questCompleteData!);
    }

    final isUser = bubble.isUser;

    return Row(
      mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!isUser) ...[
          CircleAvatar(
            radius: 16,
            backgroundColor: _getNPCColor().withOpacity(0.2),
            child: Text(_getNPCEmoji(), style: const TextStyle(fontSize: 14)),
          ),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isUser
                  ? const Color(0xFFD4AF37).withOpacity(0.2)
                  : _getNPCColor().withOpacity(0.1),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isUser ? 16 : 4),
                bottomRight: Radius.circular(isUser ? 4 : 16),
              ),
              border: Border.all(
                color: isUser
                    ? const Color(0xFFD4AF37).withOpacity(0.3)
                    : _getNPCColor().withOpacity(0.2),
              ),
            ),
            child: Text(
              bubble.text ?? '',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withOpacity(0.9),
                    height: 1.4,
                  ),
            ),
          ),
        ),
        if (isUser) const SizedBox(width: 8),
      ],
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1);
  }

  Widget _buildVocabularyCard(Map<String, dynamic> data) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            Colors.purple.withOpacity(0.2),
            Colors.blue.withOpacity(0.2),
          ],
        ),
        border: Border.all(color: Colors.purple.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.school, color: Colors.purple, size: 20),
              const SizedBox(width: 8),
              Text(
                'New Vocabulary!',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Colors.purple,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Column(
                children: [
                  Text(
                    data['native'] ?? '',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                        ),
                  ),
                  Text(
                    'English',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white54,
                        ),
                  ),
                ],
              ),
              const Icon(Icons.arrow_forward, color: Colors.white54),
              Column(
                children: [
                  Text(
                    data['target'] ?? '',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: const Color(0xFFD4AF37),
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  Text(
                    'Spanish',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white54,
                        ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.9, 0.9));
  }

  Widget _buildGameCard(Map<String, dynamic> data) {
    final gameType = data['type'] as String;
    final isCountingGame = gameType == 'start_counting_game';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.green.withOpacity(0.1),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isCountingGame ? Icons.numbers : Icons.abc,
                color: Colors.green,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                isCountingGame ? 'Counting Game!' : 'Word Game!',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isCountingGame
                ? 'Let\'s count to ${data['max_number'] ?? 10}!'
                : 'Category: ${data['category'] ?? 'general'}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white70,
                ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.9, 0.9));
  }

  Widget _buildQuestCompleteCard(Map<String, dynamic> data) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            Colors.amber.withOpacity(0.3),
            const Color(0xFFD4AF37).withOpacity(0.2),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.amber.withOpacity(0.5), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withOpacity(0.2),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.emoji_events, color: Colors.amber, size: 32),
              const SizedBox(width: 12),
              Text(
                'QUEST COMPLETE!',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.amber,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            data['quest_name'] ?? 'Quest',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: Colors.purple.withOpacity(0.3),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star, color: Colors.purple, size: 20),
                const SizedBox(width: 8),
                Text(
                  '+${data['xp_reward'] ?? 0} XP',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Colors.purple,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate()
      .fadeIn(duration: 500.ms)
      .scale(begin: const Offset(0.8, 0.8))
      .then()
      .shimmer(duration: 1000.ms, color: Colors.amber.withOpacity(0.3));
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: _getNPCColor().withOpacity(0.2),
            child: Text(_getNPCEmoji(), style: const TextStyle(fontSize: 14)),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: _getNPCColor().withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDot(0, 3),
                _buildDot(1, 3),
                _buildDot(2, 3),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(int index, int totalDots) {
    // Each dot is offset by 1/3 of the animation cycle
    const phaseOffset = 1.0 / 3.0;

    return AnimatedBuilder(
      animation: _typingDotsController,
      builder: (context, child) {
        // Calculate phase for this dot (0.0 to 1.0)
        final phase = (_typingDotsController.value + (totalDots - index) * phaseOffset) % 1.0;
        // Use a sine wave for smooth pulsing (0.3 to 1.0 opacity range)
        final opacity = 0.3 + 0.7 * (0.5 + 0.5 * math.sin(phase * 2 * math.pi)).abs();

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(opacity),
          ),
        );
      },
    );
  }

  Widget _buildVocabularySummary() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.purple.withOpacity(0.1),
        border: Border.all(color: Colors.purple.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_stories, color: Colors.purple, size: 20),
          const SizedBox(width: 8),
          Text(
            'Learned ${_learnedVocabulary.length} new word${_learnedVocabulary.length == 1 ? '' : 's'}!',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.purple,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                focusNode: _focusNode,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isLoading
                    ? Colors.grey
                    : const Color(0xFFD4AF37),
              ),
              child: IconButton(
                onPressed: _isLoading ? null : _sendMessage,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send, color: Colors.black),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFarewellButton(GameProvider gameProvider) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(
            npc.displayFarewell.isNotEmpty
                ? npc.displayFarewell
                : 'Goodbye!',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white54,
                  fontStyle: FontStyle.italic,
                ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                NPCChatbotService.instance.clearConversation(npc.id);
                gameProvider.endDialogue();
                Navigator.pop(context);
              },
              child: const Text('FAREWELL'),
            ),
          ),
        ],
      ),
    );
  }

  Color _getNPCColor() {
    switch (npc.type) {
      case NPCType.merchant:
        return const Color(0xFFD4AF37);
      case NPCType.questGiver:
        return Colors.amber;
      case NPCType.trainer:
        return Colors.purple;
      case NPCType.child:
        return Colors.lightBlue;
      case NPCType.regular:
        return Colors.white70;
    }
  }

  String _getNPCEmoji() {
    switch (npc.type) {
      case NPCType.merchant:
        return '\u{1F6D2}';
      case NPCType.questGiver:
        return '\u{2757}';
      case NPCType.trainer:
        return '\u{1F4DA}';
      case NPCType.child:
        return '\u{1F467}';
      case NPCType.regular:
        return '\u{1F464}';
    }
  }
}

/// Internal chat bubble model
class _ChatBubble {
  final String? text;
  final bool isUser;
  final String? npcName;
  final bool isVocabularyCard;
  final Map<String, dynamic>? vocabularyData;
  final bool isGameCard;
  final Map<String, dynamic>? gameData;
  final bool isQuestComplete;
  final Map<String, dynamic>? questCompleteData;

  _ChatBubble({
    this.text,
    required this.isUser,
    this.npcName,
    this.isVocabularyCard = false,
    this.vocabularyData,
    this.isGameCard = false,
    this.gameData,
    this.isQuestComplete = false,
    this.questCompleteData,
  });
}

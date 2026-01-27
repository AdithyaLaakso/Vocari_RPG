import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../game_models.dart';
import '../providers/game_provider.dart';
import '../location_card.dart';
import '../npc_dialogue_sheet.dart';
import '../quest_notification.dart';
import '../widgets/narrator_panel.dart';
import '../services/bilingual_text_service.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  int _selectedNavIndex = 0;
  bool _showingLocationItems = false;  // Toggle for "Look Around" feature

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    // Set up quest progress notifications
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final gameProvider = context.read<GameProvider>();
      gameProvider.onQuestProgress = _handleQuestProgress;
      debugPrint('Quest progress callback set up!');
    });
  }

  void _handleQuestProgress(
    String questName,
    String? taskDescription,
    int completedTasks,
    int totalTasks,
    bool isQuestComplete,
    int? xpReward,
  ) {
    if (!mounted) return;

    final notification = QuestNotificationData(
      type: isQuestComplete
          ? QuestNotificationType.questCompleted
          : QuestNotificationType.taskCompleted,
      questName: questName,
      taskDescription: taskDescription,
      xpReward: xpReward,
      completedTasks: completedTasks,
      totalTasks: totalTasks,
    );

    QuestNotificationService.instance.showNotification(context, notification);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    // Clean up quest progress callback
    final gameProvider = context.read<GameProvider>();
    gameProvider.onQuestProgress = null;
    QuestNotificationService.instance.clearAll();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GameProvider>(
      builder: (context, gameProvider, child) {
        return Scaffold(
          body: SafeArea(
            child: Stack(
              children: [
                // Main game UI
                Column(
                  children: [
                    // Top bar with player info
                    _buildTopBar(gameProvider),

                    // Main content area
                    Expanded(
                      child: _buildMainContent(gameProvider),
                    ),

                    // Bottom navigation
                    _buildBottomNav(gameProvider),
                  ],
                ),

                // Narrator messages overlay
                const NarratorPanel(),
              ],
            ),
          ),
          // Narrator help button
          floatingActionButton: const AskNarratorButton(),
        );
      },
    );
  }

  Widget _buildTopBar(GameProvider gameProvider) {
    final player = gameProvider.player;
    if (player == null) return const SizedBox();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withOpacity(0.1),
          ),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Player avatar and level
              GestureDetector(
                onTap: () => _showCharacterSheet(context),
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFFD4AF37).withOpacity(0.3),
                        Colors.transparent,
                      ],
                    ),
                    border: Border.all(
                      color: const Color(0xFFD4AF37),
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      player.level.toString(),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: const Color(0xFFD4AF37),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // Player name and class
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      player.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      'LEVEL ${player.languageLevel}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFFD4AF37),
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ),

              // Gold
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: Colors.white.withOpacity(0.05),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🪙', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 6),
                    Text(
                      player.gold.toString(),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: const Color(0xFFD4AF37),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Time of day indicator
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.05),
                ),
                child: Text(
                  gameProvider.timeOfDay == 'day' ? '☀️'
                      : gameProvider.timeOfDay == 'evening' ? '🌅' : '🌙',
                  style: const TextStyle(fontSize: 18),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // HP and MP bars
          Row(
            children: [
              Expanded(
                child: _buildResourceBar(
                  icon: '❤️',
                  current: player.currentHealth,
                  max: player.maxHealth,
                  color: Colors.red,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildResourceBar(
                  icon: '💎',
                  current: player.currentMana,
                  max: player.maxMana,
                  color: Colors.blue,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // XP bar
          _buildXPBar(player),
        ],
      ),
    );
  }

  Widget _buildResourceBar({
    required String icon,
    required int current,
    required int max,
    required Color color,
  }) {
    return Row(
      children: [
        Text(icon, style: const TextStyle(fontSize: 14)),
        const SizedBox(width: 6),
        Expanded(
          child: Stack(
            children: [
              Container(
                height: 10,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              FractionallySizedBox(
                widthFactor: max > 0 ? (current / max).clamp(0, 1) : 0,
                child: Container(
                  height: 10,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color.withOpacity(0.8), color],
                    ),
                    borderRadius: BorderRadius.circular(5),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.5),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '$current/$max',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.white70,
          ),
        ),
      ],
    );
  }

  Widget _buildXPBar(Player player) {
    final xpForCurrentLevel = player.xpRequiredForLevel(player.level);
    final xpForNextLevel = player.xpRequiredForLevel(player.level + 1);
    final currentLevelXP = player.xp - xpForCurrentLevel;
    final xpNeeded = xpForNextLevel - xpForCurrentLevel;
    final progress = xpNeeded > 0 ? currentLevelXP / xpNeeded : 0.0;

    return Row(
      children: [
        const Text('⭐', style: TextStyle(fontSize: 12)),
        const SizedBox(width: 6),
        Expanded(
          child: Stack(
            children: [
              Container(
                height: 6,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              FractionallySizedBox(
                widthFactor: progress.clamp(0, 1).toDouble(),
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFD4AF37), Color(0xFFFFD700)],
                    ),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '${currentLevelXP.toInt()}/${xpNeeded.toInt()} XP',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: const Color(0xFFD4AF37),
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildMainContent(GameProvider gameProvider) {
    switch (_selectedNavIndex) {
      case 0:
        return _buildLocationView(gameProvider);
      case 1:
        return _buildMapView(gameProvider);
      case 2:
        return const GameLogWidget();
      default:
        return _buildLocationView(gameProvider);
    }
  }

  Widget _buildLocationView(GameProvider gameProvider) {
    final location = gameProvider.currentLocation;
    if (location == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Location header
          LocationCard(location: location)
              .animate()
              .fadeIn(duration: 400.ms)
              .slideY(begin: -0.1),

          const SizedBox(height: 20),

          // Look Around button and items
          _buildLookAroundSection(gameProvider),

          // NPCs at this location
          if (gameProvider.locationNPCs.isNotEmpty) ...[
            Text(
              'People Here',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: const Color(0xFFD4AF37),
              ),
            ).animate().fadeIn(delay: 400.ms),

            const SizedBox(height: 12),

            ...gameProvider.locationNPCs.asMap().entries.map((entry) {
              final index = entry.key;
              final npc = entry.value;

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildNPCCard(npc, gameProvider)
                    .animate()
                    .fadeIn(delay: Duration(milliseconds: 500 + (index * 100)))
                    .slideX(begin: 0.1),
              );
            }),

            const SizedBox(height: 16),
          ],

          // Connected locations
          Text(
            'Travel To',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: const Color(0xFFD4AF37),
            ),
          ).animate().fadeIn(delay: 600.ms),

          const SizedBox(height: 12),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: location.connections.asMap().entries.map((entry) {
              final index = entry.key;
              final connectionId = entry.value;
              final connectedLocation = gameProvider.world?.locations[connectionId];

              if (connectedLocation == null) return const SizedBox();

              return _buildTravelButton(connectedLocation, gameProvider)
                  .animate()
                  .fadeIn(delay: Duration(milliseconds: 700 + (index * 100)))
                  .scale(begin: const Offset(0.9, 0.9));
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(LocationItem locationItem, GameProvider gameProvider) {
    final item = locationItem.item;
    final canPickup = locationItem.canPickup;
    final isPurchase = locationItem.acquisitionType == 'purchase';
    final playerGold = gameProvider.player?.gold ?? 0;
    final canAfford = !isPurchase || playerGold >= locationItem.price;
    final playerLevel = gameProvider.player?.languageLevel ?? 'A0';

    // Use bilingual display: default to target language for name (with RNG)
    // For items, we want to encourage target language exposure
    // Name: Show target language first with native as hint
    // Description: Show native language first with target as hint (for comprehension)
    final bilingualService = BilingualTextService.instance;

    // Item name - favor target language (name is simpler, easier to learn)
    final showTargetName = bilingualService.shouldShowTargetLanguage(playerLevel);
    final itemName = showTargetName
        ? item.name.targetLanguage
        : item.name.nativeLanguage;
    final itemNameHint = showTargetName
        ? item.name.nativeLanguage
        : item.name.targetLanguage;

    // Description - favor native language (descriptions are more complex)
    final showTargetDesc = bilingualService.shouldShowTargetLanguage(playerLevel);
    final itemDesc = showTargetDesc
        ? item.description.targetLanguage
        : item.description.nativeLanguage;

    // Action button text
    final actionLabel = isPurchase
        ? BilingualLabel(native: 'Buy (${locationItem.price})', target: 'Comprar (${locationItem.price})')
        : UILabels.pickUp;

    return InkWell(
      onTap: canPickup && canAfford
          ? () => _handleItemPickup(locationItem, gameProvider)
          : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: const Color(0xFF4CAF50).withOpacity(0.08),
          border: Border.all(
            color: canPickup && canAfford
                ? const Color(0xFF4CAF50).withOpacity(0.3)
                : Colors.white.withOpacity(0.1),
          ),
        ),
        child: Row(
          children: [
            // Item icon
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: const Color(0xFF4CAF50).withOpacity(0.15),
              ),
              child: Center(
                child: Text(
                  item.icon.isNotEmpty ? item.icon : item.categoryEmoji,
                  style: const TextStyle(fontSize: 24),
                ),
              ),
            ),

            const SizedBox(width: 12),

            // Item info with bilingual display
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Primary name
                  Text(
                    itemName,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: canPickup ? Colors.white : Colors.white54,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  // Secondary name (hint)
                  Text(
                    '($itemNameHint)',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white38,
                      fontSize: 10,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 2),
                  // Description
                  Text(
                    itemDesc,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white54,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  // Vocabulary word highlight
                  if (item.vocabularyWord != null) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: Colors.blue.withOpacity(0.2),
                      ),
                      child: Text(
                        '"${item.vocabularyWord!.targetLanguage}" = "${item.vocabularyWord!.nativeLanguage}"',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.blue[300],
                          fontStyle: FontStyle.italic,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Action button with bilingual text
            if (canPickup)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: canAfford
                      ? const Color(0xFF4CAF50).withOpacity(0.3)
                      : Colors.red.withOpacity(0.2),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      actionLabel.primaryForLevel(playerLevel),
                      style: TextStyle(
                        color: canAfford ? const Color(0xFF4CAF50) : Colors.red[300],
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      actionLabel.secondaryForLevel(playerLevel),
                      style: TextStyle(
                        color: canAfford
                            ? const Color(0xFF4CAF50).withOpacity(0.6)
                            : Colors.red.withOpacity(0.4),
                        fontSize: 8,
                      ),
                    ),
                  ],
                ),
              )
            else
              Icon(
                Icons.check_circle,
                color: Colors.white.withOpacity(0.3),
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  void _handleItemPickup(LocationItem locationItem, GameProvider gameProvider) {
    final item = locationItem.item;

    if (locationItem.acquisitionType == 'purchase') {
      // Show purchase confirmation
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          title: Text('Buy ${item.displayName}?'),
          content: Text(
            'Purchase for ${locationItem.price} gold?',
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                gameProvider.buyItem(item.id);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
              ),
              child: const Text('Buy'),
            ),
          ],
        ),
      );
    } else {
      // Directly pick up the item
      gameProvider.pickupItem(item.id);
    }
  }

  Widget _buildNPCCard(NPC npc, GameProvider gameProvider) {
    return InkWell(
      onTap: () {
        gameProvider.talkToNPC(npc.id);
        _showDialogueSheet(context, npc);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.white.withOpacity(0.05),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
          ),
        ),
        child: Row(
          children: [
            // NPC icon
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _getNPCColor(npc.type).withOpacity(0.2),
              ),
              child: Center(
                child: Icon(
                  _getNPCIcon(npc.type),
                  size: 24,
                  color: _getNPCColor(npc.type),
                ),
              ),
            ),

            const SizedBox(width: 12),

            // NPC info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    npc.displayName,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  Text(
                    npc.type.name.toUpperCase(),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: _getNPCColor(npc.type),
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),

            Icon(
              Icons.chat_bubble_outline,
              color: Colors.white.withOpacity(0.5),
            ),
          ],
        ),
      ),
    );
  }

  Color _getNPCColor(NPCType type) {
    switch (type) {
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

  IconData _getNPCIcon(NPCType type) {
    switch (type) {
      case NPCType.merchant:
        return Icons.storefront;
      case NPCType.questGiver:
        return Icons.assignment;
      case NPCType.trainer:
        return Icons.school;
      case NPCType.child:
        return Icons.child_care;
      case NPCType.regular:
        return Icons.person;
    }
  }

  Widget _buildTravelButton(Location location, GameProvider gameProvider) {
    return ElevatedButton.icon(
      onPressed: () {
        gameProvider.moveToLocation(location.id);
      },
      icon: Text(location.emoji, style: const TextStyle(fontSize: 16)),
      label: Text(location.displayName),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white.withOpacity(0.1),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  Widget _buildMapView(GameProvider gameProvider) {
    final locations = gameProvider.world?.locations.values.toList() ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'World Map',
            style: Theme.of(context).textTheme.headlineMedium,
          ),

          const SizedBox(height: 8),

          Text(
            'Tap a location to travel (if connected)',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white54,
            ),
          ),

          const SizedBox(height: 20),

          // Group locations by type
          ..._buildLocationGroups(locations, gameProvider),
        ],
      ),
    );
  }

  List<Widget> _buildLocationGroups(List<Location> locations, GameProvider gameProvider) {
    final groups = <String, List<Location>>{};

    for (final location in locations) {
      final type = location.type.name;
      groups.putIfAbsent(type, () => []);
      groups[type]!.add(location);
    }

    return groups.entries.map((entry) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            entry.key.toUpperCase(),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: const Color(0xFFD4AF37),
              letterSpacing: 2,
            ),
          ),

          const SizedBox(height: 8),

          ...entry.value.map((location) {
            final isCurrent = location.id == gameProvider.currentLocation?.id;
            final isConnected = gameProvider.currentLocation?.connections.contains(location.id) ?? false;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: isConnected ? () => gameProvider.moveToLocation(location.id) : null,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: isCurrent
                        ? const Color(0xFFD4AF37).withOpacity(0.2)
                        : Colors.white.withOpacity(0.05),
                    border: Border.all(
                      color: isCurrent
                          ? const Color(0xFFD4AF37)
                          : isConnected
                              ? Colors.white.withOpacity(0.3)
                              : Colors.white.withOpacity(0.1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(location.emoji, style: const TextStyle(fontSize: 24)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              location.displayName,
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                color: isCurrent ? const Color(0xFFD4AF37) : null,
                              ),
                            ),
                            if (isCurrent)
                              Text(
                                'Current Location',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: const Color(0xFFD4AF37),
                                ),
                              )
                            else if (isConnected)
                              Text(
                                'Tap to travel',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.white54,
                                ),
                              )
                            else
                              Text(
                                'Not connected',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.white30,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (isConnected && !isCurrent)
                        const Icon(Icons.arrow_forward, color: Colors.white54),
                    ],
                  ),
                ),
              ),
            );
          }),

          const SizedBox(height: 16),
        ],
      );
    }).toList();
  }

  /// Build the "Look Around" section that toggles item visibility
  Widget _buildLookAroundSection(GameProvider gameProvider) {
    final playerLevel = gameProvider.player?.languageLevel ?? 'A0';
    final hasItems = gameProvider.locationItems.isNotEmpty;

    if (!hasItems) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Look Around button
        InkWell(
          onTap: () {
            setState(() {
              _showingLocationItems = !_showingLocationItems;
            });
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: const Color(0xFF4CAF50).withOpacity(0.15),
              border: Border.all(
                color: const Color(0xFF4CAF50).withOpacity(0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _showingLocationItems ? Icons.visibility_off : Icons.visibility,
                  color: const Color(0xFF4CAF50),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      UILabels.lookAround.primaryForLevel(playerLevel),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: const Color(0xFF4CAF50),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      UILabels.lookAround.secondaryForLevel(playerLevel),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF4CAF50).withOpacity(0.7),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                Icon(
                  _showingLocationItems ? Icons.expand_less : Icons.expand_more,
                  color: const Color(0xFF4CAF50).withOpacity(0.7),
                  size: 20,
                ),
              ],
            ),
          ),
        ).animate().fadeIn(delay: 200.ms).scale(begin: const Offset(0.95, 0.95)),

        // Items list (shown when expanded)
        if (_showingLocationItems) ...[
          const SizedBox(height: 16),

          Text(
            UILabels.itemsHere.primaryForLevel(playerLevel),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: const Color(0xFF4CAF50),
            ),
          ).animate().fadeIn(delay: 100.ms),

          const SizedBox(height: 12),

          ...gameProvider.locationItems.asMap().entries.map((entry) {
            final index = entry.key;
            final locationItem = entry.value;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _buildItemCard(locationItem, gameProvider)
                  .animate()
                  .fadeIn(delay: Duration(milliseconds: 150 + (index * 80)))
                  .slideX(begin: -0.1),
            );
          }),
        ],

        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildBottomNav(GameProvider gameProvider) {
    final playerLevel = gameProvider.player?.languageLevel ?? 'A0';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        border: Border(
          top: BorderSide(
            color: Colors.white.withOpacity(0.1),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildNavButton(0, Icons.location_on, 'Location', 'Lugar'),
          _buildNavButton(1, Icons.map, UILabels.map.native, UILabels.map.target),
          _buildNavButton(2, Icons.history, 'Log', 'Registro'),
          _buildActionButton(
            icon: Icons.backpack,
            label: UILabels.inventory.primaryForLevel(playerLevel),
            sublabel: UILabels.inventory.secondaryForLevel(playerLevel),
            onTap: () => _showInventorySheet(context),
          ),
          _buildActionButton(
            icon: Icons.assignment,
            label: UILabels.quests.primaryForLevel(playerLevel),
            sublabel: UILabels.quests.secondaryForLevel(playerLevel),
            badge: gameProvider.player?.activeQuests.length,
            onTap: () => _showQuestLog(context),
          ),
        ],
      ),
    );
  }

  Widget _buildNavButton(int index, IconData icon, String nativeLabel, [String? targetLabel]) {
    final isSelected = _selectedNavIndex == index;
    final gameProvider = context.read<GameProvider>();
    final playerLevel = gameProvider.player?.languageLevel ?? 'A0';

    // Get bilingual label if target provided
    String primaryLabel = nativeLabel;
    String? secondaryLabel;
    if (targetLabel != null) {
      primaryLabel = BilingualTextService.instance.getPrimaryText(
        nativeText: nativeLabel,
        targetText: targetLabel,
        level: playerLevel,
      );
      secondaryLabel = BilingualTextService.instance.getSecondaryText(
        nativeText: nativeLabel,
        targetText: targetLabel,
        level: playerLevel,
      );
    }

    return InkWell(
      onTap: () => setState(() => _selectedNavIndex = index),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: isSelected
              ? const Color(0xFFD4AF37).withOpacity(0.2)
              : Colors.transparent,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFFD4AF37) : Colors.white54,
            ),
            const SizedBox(height: 4),
            Text(
              primaryLabel,
              style: TextStyle(
                color: isSelected ? const Color(0xFFD4AF37) : Colors.white54,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (secondaryLabel != null)
              Text(
                secondaryLabel,
                style: TextStyle(
                  color: isSelected
                      ? const Color(0xFFD4AF37).withOpacity(0.6)
                      : Colors.white38,
                  fontSize: 8,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    String? sublabel,
    int? badge,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, color: Colors.white54),
                if (badge != null && badge > 0)
                  Positioned(
                    right: -6,
                    top: -6,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFD4AF37),
                      ),
                      child: Text(
                        badge.toString(),
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (sublabel != null)
              Text(
                sublabel,
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 8,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showDialogueSheet(BuildContext context, NPC npc) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => NPCDialogueSheet(npc: npc),
    );
  }

  void _showInventorySheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const InventorySheet(),
    );
  }

  void _showQuestLog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const QuestLogSheet(),
    );
  }

  void _showCharacterSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const CharacterSheet(),
    );
  }
}

// Stub widget for GameLogWidget
class GameLogWidget extends StatelessWidget {
  const GameLogWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<GameProvider>(
      builder: (context, gameProvider, child) {
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: gameProvider.gameLog.length,
          itemBuilder: (context, index) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                gameProvider.gameLog[index],
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white70,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// Stub widget for InventorySheet
class InventorySheet extends StatelessWidget {
  const InventorySheet({super.key});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1A1A2E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Consumer<GameProvider>(
            builder: (context, gameProvider, child) {
              final player = gameProvider.player;
              if (player == null) {
                return const Center(child: CircularProgressIndicator());
              }
              return Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white30,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      'Inventory',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: player.inventory.length,
                      itemBuilder: (context, index) {
                        final itemId = player.inventory[index];
                        return ListTile(
                          title: Text(itemId),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () {
                              // Remove item
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

// Quest Log Sheet with detailed progress
class QuestLogSheet extends StatefulWidget {
  const QuestLogSheet({super.key});

  @override
  State<QuestLogSheet> createState() => _QuestLogSheetState();
}

class _QuestLogSheetState extends State<QuestLogSheet> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: Colors.amber.withOpacity(0.3)),
          ),
          child: Consumer<GameProvider>(
            builder: (context, gameProvider, child) {
              final activeQuests = gameProvider.activeQuests;
              final completedQuestIds = gameProvider.player?.completedQuests ?? [];

              return Column(
                children: [
                  // Handle
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white30,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  // Header
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        const Icon(Icons.assignment, color: Colors.amber, size: 28),
                        const SizedBox(width: 12),
                        Text(
                          'Quest Log',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: Colors.amber,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Tabs
                  TabBar(
                    controller: _tabController,
                    indicatorColor: Colors.amber,
                    labelColor: Colors.amber,
                    unselectedLabelColor: Colors.white54,
                    tabs: [
                      Tab(text: 'Active (${activeQuests.length})'),
                      Tab(text: 'Completed (${completedQuestIds.length})'),
                    ],
                  ),

                  // Tab content
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        // Active quests
                        _buildActiveQuestsList(activeQuests, scrollController),
                        // Completed quests
                        _buildCompletedQuestsList(completedQuestIds, gameProvider, scrollController),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildActiveQuestsList(List<Quest> quests, ScrollController scrollController) {
    if (quests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.explore, size: 64, color: Colors.white.withOpacity(0.2)),
            const SizedBox(height: 16),
            Text(
              'No active quests',
              style: TextStyle(color: Colors.white.withOpacity(0.5)),
            ),
            const SizedBox(height: 8),
            Text(
              'Talk to NPCs to discover quests!',
              style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 12),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: quests.length,
      itemBuilder: (context, index) {
        final quest = quests[index];
        return _buildQuestCard(quest, isActive: true);
      },
    );
  }

  Widget _buildCompletedQuestsList(List<String> questIds, GameProvider gameProvider, ScrollController scrollController) {
    if (questIds.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.emoji_events, size: 64, color: Colors.white.withOpacity(0.2)),
            const SizedBox(height: 16),
            Text(
              'No completed quests yet',
              style: TextStyle(color: Colors.white.withOpacity(0.5)),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: questIds.length,
      itemBuilder: (context, index) {
        final questId = questIds[index];
        final quest = gameProvider.getQuest(questId);
        if (quest == null) {
          return ListTile(title: Text(questId));
        }
        return _buildQuestCard(quest, isActive: false);
      },
    );
  }

  Widget _buildQuestCard(Quest quest, {required bool isActive}) {
    final typeColor = _getQuestTypeColor(quest.type);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withOpacity(0.05),
        border: Border.all(
          color: isActive ? typeColor.withOpacity(0.3) : Colors.green.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quest header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              color: (isActive ? typeColor : Colors.green).withOpacity(0.1),
            ),
            child: Row(
              children: [
                // Quest type icon
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: (isActive ? typeColor : Colors.green).withOpacity(0.2),
                  ),
                  child: Center(
                    child: Text(
                      _getQuestTypeEmoji(quest.type),
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        quest.displayName,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: isActive ? typeColor : Colors.green,
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: typeColor.withOpacity(0.2),
                            ),
                            child: Text(
                              quest.type.toUpperCase(),
                              style: TextStyle(
                                color: typeColor,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.teal.withOpacity(0.2),
                            ),
                            child: Text(
                              quest.languageLevel,
                              style: const TextStyle(
                                color: Colors.teal,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (!isActive)
                  const Icon(Icons.check_circle, color: Colors.green, size: 24),
              ],
            ),
          ),

          // Quest description
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              quest.displayDescription,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white70,
              ),
            ),
          ),

          // Progress (for active quests)
          if (isActive) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Progress',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: Colors.white54,
                        ),
                      ),
                      Text(
                        '${quest.completedTaskCount}/${quest.tasks.length} tasks',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: typeColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Progress bar
                  Stack(
                    children: [
                      Container(
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: quest.progress,
                        child: Container(
                          height: 8,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [typeColor.withOpacity(0.8), typeColor],
                            ),
                            borderRadius: BorderRadius.circular(4),
                            boxShadow: [
                              BoxShadow(
                                color: typeColor.withOpacity(0.5),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Current task
            if (quest.currentTask != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.white.withOpacity(0.05),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: typeColor, width: 2),
                        ),
                        child: Center(
                          child: Text(
                            '${quest.currentTaskIndex + 1}',
                            style: TextStyle(
                              color: typeColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              quest.currentTask!.displayDescription,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.white,
                              ),
                            ),
                            if (quest.currentTask!.displayHint.isNotEmpty)
                              Text(
                                'Hint: ${quest.currentTask!.displayHint}',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.white38,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],

          // Rewards preview
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                const Icon(Icons.card_giftcard, size: 14, color: Color(0xFFD4AF37)),
                const SizedBox(width: 6),
                Text(
                  'Rewards: ',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFFD4AF37),
                  ),
                ),
                if (quest.rewards.experience > 0)
                  Text(
                    '${quest.rewards.experience} XP',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.purple,
                    ),
                  ),
                if (quest.rewards.items.isNotEmpty)
                  Text(
                    ' + ${quest.rewards.items.length} item(s)',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.blue,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getQuestTypeColor(String type) {
    switch (type) {
      case 'main':
        return Colors.amber;
      case 'side':
        return Colors.blue;
      case 'repeatable':
        return Colors.green;
      default:
        return Colors.white70;
    }
  }

  String _getQuestTypeEmoji(String type) {
    switch (type) {
      case 'main':
        return '⭐';
      case 'side':
        return '📜';
      case 'repeatable':
        return '🔄';
      default:
        return '❓';
    }
  }
}

// Stub widget for CharacterSheet
class CharacterSheet extends StatelessWidget {
  const CharacterSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1A1A2E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Consumer<GameProvider>(
            builder: (context, gameProvider, child) {
              final player = gameProvider.player;
              if (player == null) {
                return const Center(child: CircularProgressIndicator());
              }
              return SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white30,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Center(
                      child: Text(
                        player.name,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        'Level ${player.level} ${player.classId}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildStatRow('Strength', player.stats.strength),
                    _buildStatRow('Agility', player.stats.agility),
                    _buildStatRow('Intelligence', player.stats.intelligence),
                    _buildStatRow('Charisma', player.stats.charisma),
                    _buildStatRow('Luck', player.stats.luck),
                    _buildStatRow('Constitution', player.stats.constitution),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildStatRow(String name, int value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(name),
          Text(value.toString()),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'game_models.dart';
import 'providers/game_provider.dart';

class QuestOfferSheet extends ConsumerWidget {
  final Quest quest;
  final VoidCallback? onAccepted;
  final VoidCallback? onRejected;

  const QuestOfferSheet({
    super.key,
    required this.quest,
    this.onAccepted,
    this.onRejected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gp = ref.watch(gameProvider);
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
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
              color: _getQuestTypeColor().withValues(alpha: 0.3),
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
                  color: Colors.white.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Quest Header
              _buildQuestHeader(context),

              const Divider(height: 1),

              // Quest content
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDescription(context),
                      const SizedBox(height: 24),
                      _buildObjectives(context),
                      const SizedBox(height: 24),
                      _buildLanguageLearning(context),
                      const SizedBox(height: 24),
                      _buildRewards(context, gp),
                    ],
                  ),
                ),
              ),

              // Accept/Reject buttons
              _buildActionButtons(context, gp),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuestHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          // Quest icon
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _getQuestTypeColor().withValues(alpha: 0.2),
              border: Border.all(
                color: _getQuestTypeColor(),
                width: 2,
              ),
            ),
            child: Center(
              child: Text(
                _getQuestTypeEmoji(),
                style: const TextStyle(fontSize: 32),
              ),
            ),
          )
              .animate()
              .fadeIn(duration: 400.ms)
              .scale(begin: const Offset(0.8, 0.8)),

          const SizedBox(width: 16),

          // Quest info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'QUEST OFFERED',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: _getQuestTypeColor().withValues(alpha: 0.7),
                        letterSpacing: 2,
                      ),
                ).animate().fadeIn(delay: 100.ms),
                const SizedBox(height: 4),
                Text(
                  quest.displayName,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: _getQuestTypeColor(),
                      ),
                ).animate().fadeIn(delay: 200.ms),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: _getQuestTypeColor().withValues(alpha: 0.2),
                      ),
                      child: Text(
                        quest.type.toUpperCase(),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: _getQuestTypeColor(),
                            ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: Colors.teal.withValues(alpha: 0.2),
                      ),
                      child: Text(
                        quest.languageLevel,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Colors.teal,
                            ),
                      ),
                    ),
                    if (quest.pattern.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(
                        quest.pattern.toUpperCase(),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Colors.white38,
                            ),
                      ),
                    ],
                  ],
                ).animate().fadeIn(delay: 300.ms),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescription(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.description, size: 18, color: Colors.white54),
              const SizedBox(width: 8),
              Text(
                'Description',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Colors.white54,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            quest.displayDescription,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white.withValues(alpha: 0.9),
                  height: 1.5,
                ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1);
  }

  Widget _buildObjectives(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.checklist, size: 18, color: Colors.white54),
              const SizedBox(width: 8),
              Text(
                'Objectives',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Colors.white54,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Show objectives summary if available
          if (quest.objectives.displaySummary.isNotEmpty) ...[
            Text(
              quest.objectives.displaySummary,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
            ),
            const SizedBox(height: 12),
          ],
          // Show tasks
          ...quest.tasks.map((task) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white54,
                          width: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        task.displayDescription,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.1);
  }

  Widget _buildLanguageLearning(BuildContext context) {
    final learning = quest.languageLearning;

    // If no language learning content, skip
    if (learning.targetVocabulary.isEmpty &&
        learning.grammarPoints.isEmpty &&
        learning.conversationSkills.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.teal.withValues(alpha: 0.1),
        border: Border.all(
          color: Colors.teal.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.school, size: 18, color: Colors.teal),
              const SizedBox(width: 8),
              Text(
                'Language Learning',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Colors.teal,
                    ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: Colors.teal.withValues(alpha: 0.2),
                ),
                child: Text(
                  quest.languageLevel,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.teal,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Vocabulary
          if (learning.targetVocabulary.isNotEmpty) ...[
            Text(
              'New Vocabulary:',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white54,
                  ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: learning.targetVocabulary.take(4).map((vocab) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.teal.withValues(alpha: 0.15),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      vocab.native,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    Text(
                      vocab.target,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.teal,
                            fontStyle: FontStyle.italic,
                          ),
                    ),
                  ],
                ),
              )).toList(),
            ),
            if (learning.targetVocabulary.length > 4)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '+${learning.targetVocabulary.length - 4} more words',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white38,
                      ),
                ),
              ),
            const SizedBox(height: 12),
          ],

          // Grammar Points
          if (learning.grammarPoints.isNotEmpty) ...[
            Text(
              'Grammar Focus:',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white54,
                  ),
            ),
            const SizedBox(height: 4),
            ...learning.grammarPoints.map((point) => Padding(
              padding: const EdgeInsets.only(left: 8, top: 4),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline, size: 14, color: Colors.teal),
                  const SizedBox(width: 8),
                  Text(
                    point.native,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white70,
                        ),
                  ),
                ],
              ),
            )),
            const SizedBox(height: 12),
          ],

          // Conversation Skills
          if (learning.conversationSkills.isNotEmpty) ...[
            Text(
              'Conversation Skills:',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white54,
                  ),
            ),
            const SizedBox(height: 4),
            ...learning.conversationSkills.map((skill) => Padding(
              padding: const EdgeInsets.only(left: 8, top: 4),
              child: Row(
                children: [
                  const Icon(Icons.chat_bubble_outline, size: 14, color: Colors.teal),
                  const SizedBox(width: 8),
                  Text(
                    skill.native,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white70,
                        ),
                  ),
                ],
              ),
            )),
          ],
        ],
      ),
    ).animate().fadeIn(delay: 550.ms).slideY(begin: 0.1);
  }

  Widget _buildRewards(BuildContext context, GameProvider gameProvider) {
    final rewards = quest.rewards;
    final world = gameProvider.world;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: const Color(0xFFD4AF37).withValues(alpha: 0.1),
        border: Border.all(
          color: const Color(0xFFD4AF37).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.card_giftcard,
                  size: 18, color: Color(0xFFD4AF37)),
              const SizedBox(width: 8),
              Text(
                'Rewards',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: const Color(0xFFD4AF37),
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              if (rewards.experience > 0)
                _buildRewardChip(context, '${rewards.experience} XP', Icons.star,
                    Colors.purple),
              ...rewards.items.map((itemId) {
                final item = world?.items[itemId];
                return _buildRewardChip(
                  context,
                  item?.displayName ?? itemId,
                  Icons.inventory_2,
                  Colors.blue,
                );
              }),
              // Show unlocked quests
              ...rewards.unlocks.quests.map((questId) {
                final unlockedQuest = world?.quests[questId];
                return _buildRewardChip(
                  context,
                  'Unlocks: ${unlockedQuest?.displayName ?? questId}',
                  Icons.assignment,
                  Colors.amber,
                );
              }),
              // Show unlocked locations
              ...rewards.unlocks.locations.map((locationId) {
                final location = world?.locations[locationId];
                return _buildRewardChip(
                  context,
                  'Unlocks: ${location?.displayName ?? locationId}',
                  Icons.place,
                  Colors.green,
                );
              }),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.1);
  }

  Widget _buildRewardChip(
      BuildContext context, String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: color.withValues(alpha: 0.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, GameProvider gameProvider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.1),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Decline button
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  gameProvider.rejectQuest();
                  onRejected?.call();
                  Navigator.pop(context);
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(
                    color: Colors.red.withValues(alpha: 0.5),
                  ),
                ),
                child: Text(
                  'DECLINE',
                  style: TextStyle(
                    color: Colors.red.withValues(alpha: 0.8),
                  ),
                ),
              ),
            ),

            const SizedBox(width: 16),

            // Accept button
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: () {
                  gameProvider.acceptQuest();
                  onAccepted?.call();
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _getQuestTypeColor().withValues(alpha: 0.3),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check, size: 20),
                    SizedBox(width: 8),
                    Text('ACCEPT QUEST'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 700.ms).slideY(begin: 0.2);
  }

  Color _getQuestTypeColor() {
    switch (quest.type) {
      case 'main':
        return Colors.amber;
      case 'side':
        return Colors.blue;
      case 'daily':
        return Colors.green;
      case 'bounty':
        return Colors.red;
      default:
        return Colors.white70;
    }
  }

  String _getQuestTypeEmoji() {
    switch (quest.type) {
      case 'main':
        return '!';
      case 'side':
        return '?';
      case 'daily':
        return '~';
      case 'bounty':
        return '!';
      default:
        return '?';
    }
  }
}

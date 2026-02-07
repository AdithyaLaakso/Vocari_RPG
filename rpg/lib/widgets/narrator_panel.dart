import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/narrator_service.dart';

/// Riverpod provider that exposes the NarratorService singleton as a ChangeNotifier
final narratorServiceProvider = ChangeNotifierProvider<NarratorService>((ref) {
  return NarratorService.instance;
});

class NarratorPanel extends ConsumerWidget {
  const NarratorPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final narrator = ref.watch(narratorServiceProvider);
    final activeMessages = narrator.activeMessages;
    return Positioned(
      top: 100,
      right: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: activeMessages.take(3).map((message) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: NarratorMessageCard(
              message: message,
              onDismiss: () => narrator.dismissMessage(message.id),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// A card displaying a single narrator message
class NarratorMessageCard extends StatelessWidget {
  final NarratorMessage message;
  final VoidCallback onDismiss;

  const NarratorMessageCard({
    super.key,
    required this.message,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 280),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: _getBackgroundColor(),
        border: Border.all(
          color: _getBorderColor(),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onDismiss,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _getIconBackground(),
                  ),
                  child: Center(
                    child: Text(
                      _getIcon(),
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getTitle(),
                        style: TextStyle(
                          color: _getTitleColor(),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        message.content,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Tap to dismiss',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                          fontSize: 10,
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
      ),
    ).animate().fadeIn(duration: 300.ms).slideX(begin: 0.2);
  }

  Color _getBackgroundColor() {
    switch (message.type) {
      case NarratorMessageType.vocabularyHint:
        return const Color(0xFF1A2F4E);
      case NarratorMessageType.grammarTip:
        return const Color(0xFF2E1A4E);
      case NarratorMessageType.contextualHelp:
        return const Color(0xFF1A3E3E);
      case NarratorMessageType.encouragement:
        return const Color(0xFF3E3A1A);
      case NarratorMessageType.questGuidance:
        return const Color(0xFF3E1A2E);
    }
  }

  Color _getBorderColor() {
    switch (message.type) {
      case NarratorMessageType.vocabularyHint:
        return Colors.blue.withValues(alpha: 0.4);
      case NarratorMessageType.grammarTip:
        return Colors.purple.withValues(alpha: 0.4);
      case NarratorMessageType.contextualHelp:
        return Colors.teal.withValues(alpha: 0.4);
      case NarratorMessageType.encouragement:
        return Colors.amber.withValues(alpha: 0.4);
      case NarratorMessageType.questGuidance:
        return Colors.pink.withValues(alpha: 0.4);
    }
  }

  Color _getIconBackground() {
    switch (message.type) {
      case NarratorMessageType.vocabularyHint:
        return Colors.blue.withValues(alpha: 0.3);
      case NarratorMessageType.grammarTip:
        return Colors.purple.withValues(alpha: 0.3);
      case NarratorMessageType.contextualHelp:
        return Colors.teal.withValues(alpha: 0.3);
      case NarratorMessageType.encouragement:
        return Colors.amber.withValues(alpha: 0.3);
      case NarratorMessageType.questGuidance:
        return Colors.pink.withValues(alpha: 0.3);
    }
  }

  Color _getTitleColor() {
    switch (message.type) {
      case NarratorMessageType.vocabularyHint:
        return Colors.blue[300]!;
      case NarratorMessageType.grammarTip:
        return Colors.purple[300]!;
      case NarratorMessageType.contextualHelp:
        return Colors.teal[300]!;
      case NarratorMessageType.encouragement:
        return Colors.amber[300]!;
      case NarratorMessageType.questGuidance:
        return Colors.pink[300]!;
    }
  }

  String _getIcon() {
    switch (message.type) {
      case NarratorMessageType.vocabularyHint:
        return '\u{1F4D6}'; // Book
      case NarratorMessageType.grammarTip:
        return '\u{1F4DD}'; // Memo
      case NarratorMessageType.contextualHelp:
        return '\u{1F4A1}'; // Light bulb
      case NarratorMessageType.encouragement:
        return '\u{2B50}'; // Star
      case NarratorMessageType.questGuidance:
        return '\u{1F5FA}'; // Map
    }
  }

  String _getTitle() {
    switch (message.type) {
      case NarratorMessageType.vocabularyHint:
        return 'VOCABULARY';
      case NarratorMessageType.grammarTip:
        return 'GRAMMAR TIP';
      case NarratorMessageType.contextualHelp:
        return 'NARRATOR';
      case NarratorMessageType.encouragement:
        return 'ACHIEVEMENT';
      case NarratorMessageType.questGuidance:
        return 'QUEST HINT';
    }
  }
}

/// A button to ask the narrator for help
class AskNarratorButton extends StatelessWidget {
  const AskNarratorButton({super.key});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.small(
      onPressed: () => _showNarratorDialog(context),
      backgroundColor: const Color(0xFF1A3E3E),
      child: const Text('\u{1F4A1}', style: TextStyle(fontSize: 18)),
    );
  }

  void _showNarratorDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const NarratorHelpSheet(),
    );
  }
}

/// A sheet for asking the narrator questions
class NarratorHelpSheet extends StatefulWidget {
  const NarratorHelpSheet({super.key});

  @override
  State<NarratorHelpSheet> createState() => _NarratorHelpSheetState();
}

class _NarratorHelpSheetState extends State<NarratorHelpSheet> {
  final _controller = TextEditingController();
  bool _isLoading = false;
  String? _response;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.8,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: Colors.teal.withValues(alpha: 0.3)),
          ),
          child: Column(
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
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.teal.withValues(alpha: 0.2),
                      ),
                      child: const Center(
                        child: Text('\u{1F4A1}', style: TextStyle(fontSize: 20)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Narrator',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Colors.teal[300],
                            ),
                          ),
                          Text(
                            'Ask me about vocabulary, grammar, or the game!',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.white54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Quick actions
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildQuickAction('What does this word mean?', Icons.translate),
                    _buildQuickAction('Help with grammar', Icons.school),
                    _buildQuickAction('What should I do next?', Icons.help_outline),
                    _buildQuickAction('Show my vocabulary', Icons.list),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Response area
              if (_response != null)
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.white.withValues(alpha: 0.05),
                      ),
                      child: Text(
                        _response!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                )
              else
                const Expanded(child: SizedBox()),

              // Input area
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        decoration: InputDecoration(
                          hintText: 'Ask a question...',
                          hintStyle: const TextStyle(color: Colors.white38),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.05),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      onPressed: _isLoading ? null : _askQuestion,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send, color: Colors.teal),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuickAction(String label, IconData icon) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      avatar: Icon(icon, size: 16),
      backgroundColor: Colors.white.withValues(alpha: 0.05),
      onPressed: () {
        _controller.text = label;
        _askQuestion();
      },
    );
  }

  Future<void> _askQuestion() async {
    final question = _controller.text.trim();
    if (question.isEmpty) return;

    setState(() {
      _isLoading = true;
      _response = null;
    });

    // For now, provide a simple response
    // In production, this would call NarratorService.askNarrator
    await Future.delayed(const Duration(milliseconds: 500));

    setState(() {
      _isLoading = false;
      _response = _getSimpleResponse(question);
    });

    _controller.clear();
  }

  String _getSimpleResponse(String question) {
    final lower = question.toLowerCase();

    if (lower.contains('vocabulary') || lower.contains('vocab')) {
      final vocab = NarratorService.instance.learnedVocabulary;
      if (vocab.isEmpty) {
        return 'You haven\'t encountered any new vocabulary yet. Keep exploring and talking to NPCs!';
      }
      return 'Words you\'ve learned:\n\n${vocab.entries.map((e) => '${e.key} - ${e.value}').join('\n')}';
    }

    if (lower.contains('what should i do') || lower.contains('next')) {
      return 'Try talking to the people around you. They might have tasks that need help, or can point you in the right direction!';
    }

    if (lower.contains('grammar')) {
      return 'At your current level, focus on:\n\n'
          '- Basic greetings (Hola, Buenos dias)\n'
          '- Simple affirmations (Si, No)\n'
          '- Common courtesy (Gracias, Por favor)\n\n'
          'As you progress, you\'ll learn more complex grammar naturally through conversations!';
    }

    if (lower.contains('word') || lower.contains('mean')) {
      return 'I can help with vocabulary! When you encounter Spanish words in the game, '
          'I\'ll provide hints. You can also check your vocabulary list by asking "Show my vocabulary".';
    }

    return 'I\'m here to help with your Spanish learning journey! You can ask me about:\n\n'
        '- Vocabulary and word meanings\n'
        '- Grammar tips for your level\n'
        '- What to do next in the game\n'
        '- Your learned vocabulary list';
  }
}

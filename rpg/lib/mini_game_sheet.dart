import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:luavm_widget/main.dart';
import 'package:provider/provider.dart';
import 'game_models.dart';
import 'providers/game_provider.dart';

/// Sheet that displays and runs a Lua-based mini-game
class MiniGameSheet extends StatefulWidget {
  final MiniGame game;

  const MiniGameSheet({super.key, required this.game});

  @override
  State<MiniGameSheet> createState() => _MiniGameSheetState();
}

class _MiniGameSheetState extends State<MiniGameSheet> {
  bool _gameStarted = false;
  bool _gameEnded = false;
  int? _exitCode;

  void _startGame() {
    setState(() {
      _gameStarted = true;
    });
  }

  void _handleGameHalt(int exitCode) {
    if (exitCode == 0) {
      debugPrint('[MiniGame] "${widget.game.displayName}" (${widget.game.id}) '
          'entered error state (exit code 0)');
    }

    setState(() {
      _gameEnded = true;
      _exitCode = exitCode;
    });

    // Record completion in provider
    final gameProvider = context.read<GameProvider>();
    gameProvider.recordGameCompletion(widget.game.id, exitCode);
  }

  String _getResultTitle() {
    switch (_exitCode) {
      case 0:
        return 'Game Error';
      case 1:
        return 'Success!';
      case 2:
        return 'Try Again';
      default:
        return 'Game Ended';
    }
  }

  String _getResultMessage() {
    switch (_exitCode) {
      case 0:
        return 'Something went wrong with the game. Don\'t worry, you can try again!';
      case 1:
        return 'Congratulations! You completed the mini-game and earned ${widget.game.skillPoints} XP!';
      case 2:
        return 'Not quite! Give it another shot when you\'re ready.';
      default:
        return 'The game has ended.';
    }
  }

  Color _getResultColor() {
    switch (_exitCode) {
      case 0:
        return Colors.orange;
      case 1:
        return Colors.green;
      case 2:
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  IconData _getResultIcon() {
    switch (_exitCode) {
      case 0:
        return Icons.warning_amber_rounded;
      case 1:
        return Icons.emoji_events;
      case 2:
        return Icons.replay;
      default:
        return Icons.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
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
              color: Colors.purple.withOpacity(0.3),
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

              // Header
              _buildHeader(context),

              const Divider(height: 1),

              // Content area
              Expanded(
                child: _gameEnded
                    ? _buildResultScreen()
                    : _gameStarted
                        ? _buildGameCanvas()
                        : _buildStartScreen(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Game icon
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.purple.withOpacity(0.2),
              border: Border.all(
                color: Colors.purple,
                width: 2,
              ),
            ),
            child: const Center(
              child: Text(
                '\u{1F3AE}', // Game controller emoji
                style: TextStyle(fontSize: 28),
              ),
            ),
          ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.8, 0.8)),

          const SizedBox(width: 12),

          // Game info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.game.displayName,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.purple,
                      ),
                ),
                Text(
                  'Level: ${widget.game.languageLevel}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white54,
                      ),
                ),
              ],
            ),
          ),

          // XP badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.amber.withOpacity(0.2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star, color: Colors.amber, size: 16),
                const SizedBox(width: 4),
                Text(
                  '${widget.game.skillPoints} XP',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.amber,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStartScreen() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Description
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Colors.white.withOpacity(0.05),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.white54, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'About This Game',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: Colors.white70,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  widget.game.displayDescription,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withOpacity(0.85),
                        height: 1.5,
                      ),
                ),
              ],
            ),
          ).animate().fadeIn(delay: 100.ms),

          const SizedBox(height: 16),

          // Target vocabulary
          if (widget.game.targetVocabulary.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Colors.green.withOpacity(0.1),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.school, color: Colors.green, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Vocabulary Practice',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: Colors.green,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: widget.game.targetVocabulary.map((vocab) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: Colors.green.withOpacity(0.2),
                        ),
                        child: Text(
                          vocab.current,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.white70,
                              ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 200.ms),
            const SizedBox(height: 16),
          ],

          // Grammar focus
          if (widget.game.grammarFocus.isNotEmpty && widget.game.grammarFocus[0].isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Colors.blue.withValues(alpha: 0.1),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.edit_note, color: Colors.blue, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Grammar Focus',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: Colors.blue,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...widget.game.grammarFocus.map((point) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('•  ', style: TextStyle(color: Colors.blue)),
                          Expanded(
                            child: Text(
                              point.current,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.white70,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ).animate().fadeIn(delay: 300.ms),
            const SizedBox(height: 24),
          ],

          // Start button
          ElevatedButton(
            onPressed: _startGame,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.play_arrow, size: 24),
                SizedBox(width: 8),
                Text(
                  'START GAME',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2),
        ],
      ),
    );
  }

  Widget _buildGameCanvas() {
    // GestureDetector claims all drag gestures so the
    // DraggableScrollableSheet cannot intercept them.
    // LuaCanvas uses a raw Listener internally, which still
    // receives pointer events before gesture disambiguation.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragStart: (_) {},
      onVerticalDragUpdate: (_) {},
      onVerticalDragEnd: (_) {},
      onHorizontalDragStart: (_) {},
      onHorizontalDragUpdate: (_) {},
      onHorizontalDragEnd: (_) {},
      child: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.purple.withOpacity(0.3)),
        ),
        clipBehavior: Clip.antiAlias,
        child: LuaCanvas(
          luaCode: widget.game.luaCode,
          onHalt: _handleGameHalt,
        ),
      ),
    );
  }

  Widget _buildResultScreen() {
    final color = _getResultColor();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),

          // Result icon
          Center(
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withOpacity(0.2),
                border: Border.all(color: color, width: 3),
              ),
              child: Icon(
                _getResultIcon(),
                color: color,
                size: 50,
              ),
            ).animate()
              .fadeIn(duration: 400.ms)
              .scale(begin: const Offset(0.5, 0.5)),
          ),

          const SizedBox(height: 24),

          // Result title
          Text(
            _getResultTitle(),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
          ).animate().fadeIn(delay: 200.ms),

          const SizedBox(height: 16),

          // Result message
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: color.withOpacity(0.1),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Text(
              _getResultMessage(),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white.withOpacity(0.85),
                    height: 1.5,
                  ),
            ),
          ).animate().fadeIn(delay: 300.ms),

          const SizedBox(height: 32),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: BorderSide(color: Colors.white.withOpacity(0.3)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('CLOSE'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _gameStarted = false;
                      _gameEnded = false;
                      _exitCode = null;
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.replay, size: 20),
                      SizedBox(width: 8),
                      Text('PLAY AGAIN'),
                    ],
                  ),
                ),
              ),
            ],
          ).animate().fadeIn(delay: 400.ms),
        ],
      ),
    );
  }
}

/// Helper function to show the mini-game sheet
void showMiniGameSheet(BuildContext context, MiniGame game) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => MiniGameSheet(game: game),
  );
}

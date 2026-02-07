import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Types of quest notifications
enum QuestNotificationType {
  taskCompleted,
  questCompleted,
  questFailed,
  newQuestAvailable,
}

/// Data for a quest notification
class QuestNotificationData {
  final QuestNotificationType type;
  final String questName;
  final String? taskDescription;
  final int? xpReward;
  final int completedTasks;
  final int totalTasks;

  QuestNotificationData({
    required this.type,
    required this.questName,
    this.taskDescription,
    this.xpReward,
    this.completedTasks = 0,
    this.totalTasks = 1,
  });
}

/// Shows quest progress notifications as an overlay
class QuestNotificationOverlay extends StatefulWidget {
  final QuestNotificationData notification;
  final VoidCallback onDismiss;

  const QuestNotificationOverlay({
    super.key,
    required this.notification,
    required this.onDismiss,
  });

  @override
  State<QuestNotificationOverlay> createState() => _QuestNotificationOverlayState();
}

class _QuestNotificationOverlayState extends State<QuestNotificationOverlay> {
  @override
  void initState() {
    super.initState();
    // Auto-dismiss after delay
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        widget.onDismiss();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      left: 16,
      right: 16,
      child: Material(
        color: Colors.transparent,
        child: _buildNotificationCard(context),
      ),
    );
  }

  Widget _buildNotificationCard(BuildContext context) {
    final isQuestComplete = widget.notification.type == QuestNotificationType.questCompleted;
    final color = isQuestComplete ? Colors.amber : Colors.teal;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: 0.5),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header row
          Row(
            children: [
              // Icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.2),
                ),
                child: Icon(
                  isQuestComplete ? Icons.emoji_events : Icons.check_circle,
                  color: color,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              // Title and subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isQuestComplete ? 'QUEST COMPLETE!' : 'TASK COMPLETE',
                      style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.notification.questName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Close button
              GestureDetector(
                onTap: widget.onDismiss,
                child: Icon(
                  Icons.close,
                  color: Colors.white.withValues(alpha: 0.5),
                  size: 20,
                ),
              ),
            ],
          ),

          // Task description (for task complete)
          if (!isQuestComplete && widget.notification.taskDescription != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.task_alt,
                    color: Colors.green.withValues(alpha: 0.8),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.notification.taskDescription!,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Progress bar (for task complete)
          if (!isQuestComplete) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: widget.notification.completedTasks /
                          widget.notification.totalTasks,
                      backgroundColor: Colors.white.withValues(alpha: 0.1),
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                      minHeight: 6,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${widget.notification.completedTasks}/${widget.notification.totalTasks}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],

          // XP reward (for quest complete)
          if (isQuestComplete && widget.notification.xpReward != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.purple.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.star,
                    color: Colors.purple,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '+${widget.notification.xpReward} XP',
                    style: const TextStyle(
                      color: Colors.purple,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 300.ms)
        .slideY(begin: -0.5, duration: 300.ms, curve: Curves.easeOut);
  }
}

/// Service for managing quest notifications
class QuestNotificationService {
  static final QuestNotificationService _instance = QuestNotificationService._internal();
  factory QuestNotificationService() => _instance;
  QuestNotificationService._internal();

  static QuestNotificationService get instance => _instance;

  final List<QuestNotificationData> _pendingNotifications = [];
  QuestNotificationData? _currentNotification;
  OverlayEntry? _currentOverlay;

  /// Queue a notification to be shown
  void showNotification(BuildContext context, QuestNotificationData notification) {
    _pendingNotifications.add(notification);
    _processQueue(context);
  }

  void _processQueue(BuildContext context) {
    if (_currentOverlay != null || _pendingNotifications.isEmpty) return;

    _currentNotification = _pendingNotifications.removeAt(0);

    _currentOverlay = OverlayEntry(
      builder: (context) => QuestNotificationOverlay(
        notification: _currentNotification!,
        onDismiss: () => _dismissCurrent(context),
      ),
    );

    Overlay.of(context).insert(_currentOverlay!);
  }

  void _dismissCurrent(BuildContext context) {
    _currentOverlay?.remove();
    _currentOverlay = null;
    _currentNotification = null;

    // Process next notification after a short delay
      Future.delayed(const Duration(milliseconds: 300), () {
        if (_pendingNotifications.isNotEmpty && context.mounted) {
          _processQueue(context);
        }
      });
  }

  /// Clear all pending notifications
  void clearAll() {
    _pendingNotifications.clear();
    _currentOverlay?.remove();
    _currentOverlay = null;
    _currentNotification = null;
  }
}

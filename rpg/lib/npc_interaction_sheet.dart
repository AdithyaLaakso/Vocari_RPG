import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'npc_interaction.dart';
import 'providers/game_provider.dart';

/// A unified popup sheet for all NPC interactions with the player.
/// Handles: item requests, sales, gifts, and trades.
/// Modeled after QuestOfferSheet for consistency.
class NPCInteractionSheet extends ConsumerWidget {
  final NPCInteractionRequest interaction;
  final VoidCallback? onAccepted;
  final VoidCallback? onDeclined;
  final VoidCallback? onDismissed;

  const NPCInteractionSheet({
    super.key,
    required this.interaction,
    this.onAccepted,
    this.onDeclined,
    this.onDismissed,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gp = ref.watch(gameProvider);
    return DraggableScrollableSheet(
      initialChildSize: _getInitialSize(),
      minChildSize: 0.3,
      maxChildSize: 0.7,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(24),
            ),
            border: Border.all(
              color: _getInteractionColor().withValues(alpha: 0.3),
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

              // Header
              _buildHeader(context),

              const Divider(height: 1),

              // Content
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  child: _buildContent(context, gp),
                ),
              ),

              // Action buttons
              _buildActionButtons(context, gp),
            ],
          ),
        );
      },
    );
  }

  double _getInitialSize() {
    if (interaction.canAccept) {
      return interaction.reason != null ? 0.55 : 0.5;
    }
    return 0.4;
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          // Icon
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _getInteractionColor().withValues(alpha: 0.2),
              border: Border.all(
                color: _getInteractionColor(),
                width: 2,
              ),
            ),
            child: Center(
              child: Icon(
                _getInteractionIcon(),
                size: 32,
                color: _getInteractionColor(),
              ),
            ),
          )
              .animate()
              .fadeIn(duration: 400.ms)
              .scale(begin: const Offset(0.8, 0.8)),

          const SizedBox(width: 16),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  interaction.title,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: _getInteractionColor().withValues(alpha: 0.7),
                        letterSpacing: 2,
                      ),
                ).animate().fadeIn(delay: 100.ms),
                const SizedBox(height: 4),
                Text(
                  interaction.npcName,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                      ),
                ).animate().fadeIn(delay: 200.ms),
                const SizedBox(height: 4),
                _buildStatusBadge(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(BuildContext context) {
    Color badgeColor;
    String badgeText;

    if (interaction.canAccept) {
      badgeColor = Colors.green;
      badgeText = 'AVAILABLE';
    } else {
      badgeColor = Colors.red;
      switch (interaction.type) {
        case NPCInteractionType.requestItem:
          badgeText = 'ITEM NOT FOUND';
          break;
        case NPCInteractionType.offerSale:
          badgeText = 'INSUFFICIENT GOLD';
          break;
        case NPCInteractionType.offerTrade:
          badgeText = 'ITEM NOT FOUND';
          break;
        default:
          badgeText = 'UNAVAILABLE';
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: badgeColor.withValues(alpha: 0.2),
      ),
      child: Text(
        badgeText,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: badgeColor,
            ),
      ),
    ).animate().fadeIn(delay: 300.ms);
  }

  Widget _buildContent(BuildContext context, GameProvider gameProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Main message
        _buildMessageCard(context),

        // Reason/context if provided
        if (interaction.reason != null && interaction.reason!.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildReasonCard(context),
        ],

        const SizedBox(height: 16),

        // Item details
        _buildItemDetails(context, gameProvider),
      ],
    );
  }

  Widget _buildMessageCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Text(
        interaction.message,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
              height: 1.5,
            ),
        textAlign: TextAlign.center,
      ),
    ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1);
  }

  Widget _buildReasonCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: _getInteractionColor().withValues(alpha: 0.1),
        border: Border.all(
          color: _getInteractionColor().withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 18,
            color: _getInteractionColor().withValues(alpha: 0.7),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '"${interaction.reason}"',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontStyle: FontStyle.italic,
                  ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 450.ms).slideY(begin: 0.1);
  }

  Widget _buildItemDetails(BuildContext context, GameProvider gameProvider) {
    final widgets = <Widget>[];

    // Item being offered/requested
    if (interaction.itemName != null) {
      widgets.add(_buildItemChip(
        context,
        interaction.itemName!,
        _getItemIcon(),
        _getInteractionColor(),
        _getItemLabel(),
      ));
    }

    // For trades, show the requested item
    if (interaction.type == NPCInteractionType.offerTrade &&
        interaction.requestedItemName != null) {
      widgets.add(const SizedBox(height: 12));
      widgets.add(
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.swap_horiz, color: Colors.white54, size: 24),
          ],
        ),
      );
      widgets.add(const SizedBox(height: 12));
      widgets.add(_buildItemChip(
        context,
        interaction.requestedItemName!,
        Icons.inventory_2,
        Colors.orange,
        'YOUR ITEM',
      ));
    }

    // For sales, show the price
    if (interaction.type == NPCInteractionType.offerSale &&
        interaction.price != null) {
      widgets.add(const SizedBox(height: 16));
      widgets.add(_buildPriceDisplay(context, gameProvider));
    }

    return Column(
      children: widgets,
    ).animate().fadeIn(delay: 500.ms).scale(begin: const Offset(0.95, 0.95));
  }

  Widget _buildItemChip(
    BuildContext context,
    String itemName,
    IconData icon,
    Color color,
    String label,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: color.withValues(alpha: 0.1),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color.withValues(alpha: 0.7),
                  letterSpacing: 1,
                ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(width: 12),
              Text(
                itemName,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPriceDisplay(BuildContext context, GameProvider gameProvider) {
    final playerGold = gameProvider.player?.gold ?? 0;
    final price = interaction.price!;
    final canAfford = playerGold >= price;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: const Color(0xFFD4AF37).withValues(alpha: 0.1),
        border: Border.all(
          color: const Color(0xFFD4AF37).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Price
          Column(
            children: [
              Text(
                'PRICE',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: const Color(0xFFD4AF37).withValues(alpha: 0.7),
                      letterSpacing: 1,
                    ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.monetization_on,
                      color: Color(0xFFD4AF37), size: 20),
                  const SizedBox(width: 4),
                  Text(
                    '$price',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: const Color(0xFFD4AF37),
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
            ],
          ),

          Container(
            width: 1,
            height: 40,
            color: Colors.white.withValues(alpha: 0.2),
          ),

          // Your gold
          Column(
            children: [
              Text(
                'YOUR GOLD',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.white54,
                      letterSpacing: 1,
                    ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.account_balance_wallet,
                    color: canAfford ? Colors.green : Colors.red,
                    size: 20,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$playerGold',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: canAfford ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
            ],
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
        child: interaction.canAccept
            ? _buildAcceptDeclineButtons(context, gameProvider)
            : _buildDismissButton(context, gameProvider),
      ),
    ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.2);
  }

  Widget _buildAcceptDeclineButtons(
      BuildContext context, GameProvider gameProvider) {
    return Row(
      children: [
        // Decline button
        Expanded(
          child: OutlinedButton(
            onPressed: () {
              gameProvider.declineInteraction();
              onDeclined?.call();
              Navigator.pop(context);
            },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: BorderSide(
                color: Colors.red.withValues(alpha: 0.5),
              ),
            ),
            child: Text(
              interaction.declineButtonText,
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
              gameProvider.acceptInteraction();
              onAccepted?.call();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _getInteractionColor().withValues(alpha: 0.3),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(_getAcceptIcon(), size: 20),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    interaction.acceptButtonText,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDismissButton(BuildContext context, GameProvider gameProvider) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {
          gameProvider.dismissInteraction();
          onDismissed?.call();
          Navigator.pop(context);
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white.withValues(alpha: 0.1),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        child: const Text('OK'),
      ),
    );
  }

  Color _getInteractionColor() {
    switch (interaction.type) {
      case NPCInteractionType.requestItem:
        return Colors.amber;
      case NPCInteractionType.offerSale:
        return const Color(0xFFD4AF37);
      case NPCInteractionType.offerGift:
        return Colors.green;
      case NPCInteractionType.offerTrade:
        return Colors.purple;
    }
  }

  IconData _getInteractionIcon() {
    switch (interaction.type) {
      case NPCInteractionType.requestItem:
        return Icons.front_hand;
      case NPCInteractionType.offerSale:
        return Icons.shopping_cart;
      case NPCInteractionType.offerGift:
        return Icons.card_giftcard;
      case NPCInteractionType.offerTrade:
        return Icons.swap_horiz;
    }
  }

  IconData _getItemIcon() {
    switch (interaction.type) {
      case NPCInteractionType.requestItem:
        return Icons.inventory_2;
      case NPCInteractionType.offerSale:
        return Icons.shopping_bag;
      case NPCInteractionType.offerGift:
        return Icons.card_giftcard;
      case NPCInteractionType.offerTrade:
        return Icons.redeem;
    }
  }

  String _getItemLabel() {
    switch (interaction.type) {
      case NPCInteractionType.requestItem:
        return 'REQUESTED ITEM';
      case NPCInteractionType.offerSale:
        return 'FOR SALE';
      case NPCInteractionType.offerGift:
        return 'GIFT';
      case NPCInteractionType.offerTrade:
        return 'YOU RECEIVE';
    }
  }

  IconData _getAcceptIcon() {
    switch (interaction.type) {
      case NPCInteractionType.requestItem:
        return Icons.card_giftcard;
      case NPCInteractionType.offerSale:
        return Icons.shopping_cart_checkout;
      case NPCInteractionType.offerGift:
        return Icons.check;
      case NPCInteractionType.offerTrade:
        return Icons.swap_horiz;
    }
  }
}

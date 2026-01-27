// NPC Interaction System
//
// A unified system for handling all physical interactions between NPCs and players.
// Modeled after the quest offer system for consistency.
//
// Interaction types:
// - request_item: NPC asks player for an item
// - offer_sale: NPC offers to sell an item to player
// - offer_gift: NPC offers to give an item to player (free)
// - offer_trade: NPC offers to trade items with player

/// Types of physical interactions between NPCs and players
enum NPCInteractionType {
  /// NPC is requesting an item from the player
  requestItem,

  /// NPC is offering to sell an item to the player
  offerSale,

  /// NPC is offering to give an item to the player for free
  offerGift,

  /// NPC is offering to trade items with the player
  offerTrade,
}

/// Represents a pending interaction between an NPC and the player.
/// Similar to how Quest offers work, but for physical item exchanges.
class NPCInteractionRequest {
  final NPCInteractionType type;
  final String npcId;
  final String npcName;

  /// For request_item: the item the NPC wants
  /// For offer_sale/offer_gift: the item being offered
  final String? itemId;
  final String? itemName;

  /// For offer_sale: the price in gold
  final int? price;

  /// For offer_trade: what the NPC wants in exchange
  final String? requestedItemId;
  final String? requestedItemName;

  /// Optional reason/context for the interaction
  final String? reason;

  /// Whether the player has the requested item (for request_item)
  final bool? playerHasItem;

  /// Whether the player can afford the item (for offer_sale)
  final bool? playerCanAfford;

  NPCInteractionRequest({
    required this.type,
    required this.npcId,
    required this.npcName,
    this.itemId,
    this.itemName,
    this.price,
    this.requestedItemId,
    this.requestedItemName,
    this.reason,
    this.playerHasItem,
    this.playerCanAfford,
  });

  /// Create a request_item interaction
  factory NPCInteractionRequest.requestItem({
    required String npcId,
    required String npcName,
    required String itemId,
    required String itemName,
    String? reason,
    required bool playerHasItem,
  }) {
    return NPCInteractionRequest(
      type: NPCInteractionType.requestItem,
      npcId: npcId,
      npcName: npcName,
      itemId: itemId,
      itemName: itemName,
      reason: reason,
      playerHasItem: playerHasItem,
    );
  }

  /// Create an offer_sale interaction
  factory NPCInteractionRequest.offerSale({
    required String npcId,
    required String npcName,
    required String itemId,
    required String itemName,
    required int price,
    String? reason,
    required bool playerCanAfford,
  }) {
    return NPCInteractionRequest(
      type: NPCInteractionType.offerSale,
      npcId: npcId,
      npcName: npcName,
      itemId: itemId,
      itemName: itemName,
      price: price,
      reason: reason,
      playerCanAfford: playerCanAfford,
    );
  }

  /// Create an offer_gift interaction
  factory NPCInteractionRequest.offerGift({
    required String npcId,
    required String npcName,
    required String itemId,
    required String itemName,
    String? reason,
  }) {
    return NPCInteractionRequest(
      type: NPCInteractionType.offerGift,
      npcId: npcId,
      npcName: npcName,
      itemId: itemId,
      itemName: itemName,
      reason: reason,
    );
  }

  /// Create an offer_trade interaction
  factory NPCInteractionRequest.offerTrade({
    required String npcId,
    required String npcName,
    required String offeredItemId,
    required String offeredItemName,
    required String requestedItemId,
    required String requestedItemName,
    String? reason,
    required bool playerHasRequestedItem,
  }) {
    return NPCInteractionRequest(
      type: NPCInteractionType.offerTrade,
      npcId: npcId,
      npcName: npcName,
      itemId: offeredItemId,
      itemName: offeredItemName,
      requestedItemId: requestedItemId,
      requestedItemName: requestedItemName,
      reason: reason,
      playerHasItem: playerHasRequestedItem,
    );
  }

  /// Get the title for this interaction type
  String get title {
    switch (type) {
      case NPCInteractionType.requestItem:
        return 'ITEM REQUEST';
      case NPCInteractionType.offerSale:
        return 'PURCHASE OFFER';
      case NPCInteractionType.offerGift:
        return 'GIFT OFFER';
      case NPCInteractionType.offerTrade:
        return 'TRADE OFFER';
    }
  }

  /// Get the main message for this interaction
  String get message {
    switch (type) {
      case NPCInteractionType.requestItem:
        if (playerHasItem == true) {
          return 'Give $npcName $itemName?';
        } else {
          return '$npcName asked for $itemName that does not appear in your inventory.';
        }
      case NPCInteractionType.offerSale:
        if (playerCanAfford == true) {
          return 'Buy $itemName from $npcName for $price gold?';
        } else {
          return '$npcName is offering $itemName for $price gold, but you only have insufficient gold.';
        }
      case NPCInteractionType.offerGift:
        return '$npcName wants to give you $itemName.';
      case NPCInteractionType.offerTrade:
        if (playerHasItem == true) {
          return 'Trade your $requestedItemName for $itemName?';
        } else {
          return '$npcName wants to trade $itemName for $requestedItemName, but you don\'t have it.';
        }
    }
  }

  /// Whether this interaction can be accepted by the player
  bool get canAccept {
    switch (type) {
      case NPCInteractionType.requestItem:
        return playerHasItem == true;
      case NPCInteractionType.offerSale:
        return playerCanAfford == true;
      case NPCInteractionType.offerGift:
        return true;
      case NPCInteractionType.offerTrade:
        return playerHasItem == true;
    }
  }

  /// Get the accept button text
  String get acceptButtonText {
    switch (type) {
      case NPCInteractionType.requestItem:
        return 'GIVE ITEM';
      case NPCInteractionType.offerSale:
        return 'BUY FOR $price GOLD';
      case NPCInteractionType.offerGift:
        return 'ACCEPT GIFT';
      case NPCInteractionType.offerTrade:
        return 'TRADE';
    }
  }

  /// Get the decline button text
  String get declineButtonText {
    switch (type) {
      case NPCInteractionType.requestItem:
        return 'DECLINE';
      case NPCInteractionType.offerSale:
        return 'NO THANKS';
      case NPCInteractionType.offerGift:
        return 'DECLINE';
      case NPCInteractionType.offerTrade:
        return 'DECLINE';
    }
  }

  /// Convert to a map for passing through tool results
  Map<String, dynamic> toMap() {
    return {
      'type': type.name,
      'npc_id': npcId,
      'npc_name': npcName,
      'item_id': itemId,
      'item_name': itemName,
      'price': price,
      'requested_item_id': requestedItemId,
      'requested_item_name': requestedItemName,
      'reason': reason,
      'player_has_item': playerHasItem,
      'player_can_afford': playerCanAfford,
      'can_accept': canAccept,
    };
  }
}

/// Result of an NPC interaction
enum NPCInteractionResult {
  /// Player accepted the interaction
  accepted,

  /// Player declined the interaction
  declined,

  /// Interaction was dismissed (e.g., player didn't have item)
  dismissed,
}

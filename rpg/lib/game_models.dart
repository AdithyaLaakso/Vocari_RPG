import 'language_system.dart';

// Enums
enum LocationType { outdoor, building, dungeon }

enum NPCType { merchant, questGiver, trainer, regular, child }

enum ItemRarity { common, uncommon, rare, epic, legendary }

enum ItemType { weapon, armor, consumable, quest, material }

// Player Stats Model
class PlayerStats {
  int strength;
  int agility;
  int intelligence;
  int charisma;
  int luck;
  int constitution;

  PlayerStats({
    this.strength = 10,
    this.agility = 10,
    this.intelligence = 10,
    this.charisma = 10,
    this.luck = 10,
    this.constitution = 10,
  });

  factory PlayerStats.fromJson(Map<String, dynamic> json) => PlayerStats(
        strength: json['strength'] ?? 10,
        agility: json['agility'] ?? 10,
        intelligence: json['intelligence'] ?? 10,
        charisma: json['charisma'] ?? 10,
        luck: json['luck'] ?? 10,
        constitution: json['constitution'] ?? 10,
      );

  Map<String, dynamic> toJson() => {
        'strength': strength,
        'agility': agility,
        'intelligence': intelligence,
        'charisma': charisma,
        'luck': luck,
        'constitution': constitution,
      };

  int get totalStats => strength + agility + intelligence + charisma + luck + constitution;
}


// Player Model
class Player {
  String name;
  String classId;
  int level;
  int xp;
  int gold;
  int health;
  int maxHealth;
  int mana;
  int maxMana;
  PlayerStats stats;
  List<String> inventory;
  List<String> equippedItems;
  List<String> abilities;
  List<String> completedQuests;
  List<String> activeQuests;
  String currentLocationId;
  Map<String, int> reputation;
  int playtime;
  DateTime lastPlayed;
  List<Quest> _quests = [];
  String languageLevel;
  Set<String> storyFlags;
  Map<String, int> taskProgress;
  Set<String> learnedInfo;
  Set<String> talkedToNPCs;

  Player({
    required this.name,
    required this.classId,
    this.level = 1,
    this.xp = 0,
    this.gold = 100,
    this.health = 100,
    this.maxHealth = 100,
    this.mana = 50,
    this.maxMana = 50,
    PlayerStats? stats,
    List<String>? inventory,
    List<String>? equippedItems,
    List<String>? abilities,
    List<String>? completedQuests,
    List<String>? activeQuests,
    this.currentLocationId = 'town_square',
    Map<String, int>? reputation,
    this.playtime = 0,
    DateTime? lastPlayed,
    List<Quest>? quests,
    this.languageLevel = 'A0',
    Set<String>? storyFlags,
    Map<String, int>? taskProgress,
    Set<String>? learnedInfo,
    Set<String>? talkedToNPCs,
  })  : stats = stats ?? PlayerStats(),
        inventory = inventory ?? [],
        equippedItems = equippedItems ?? [],
        abilities = abilities ?? [],
        completedQuests = completedQuests ?? [],
        activeQuests = activeQuests ?? [],
        reputation = reputation ?? {},
        lastPlayed = lastPlayed ?? DateTime.now(),
        _quests = quests ?? [],
        storyFlags = storyFlags ?? {},
        taskProgress = taskProgress ?? {},
        learnedInfo = learnedInfo ?? {},
        talkedToNPCs = talkedToNPCs ?? {};

  // Aliases for health/mana
  int get currentHealth => health;
  set currentHealth(int value) => health = value;
  int get currentMana => mana;
  set currentMana(int value) => mana = value;

  // Quest list
  List<Quest> get quests => _quests;
  set quests(List<Quest> value) => _quests = value;

  // XP required for a specific level
  int xpRequiredForLevel(int lvl) => (lvl * lvl * 100) + (lvl * 50);

  factory Player.fromJson(Map<String, dynamic> json) => Player(
        name: json['name'],
        classId: json['classId'],
        level: json['level'] ?? 1,
        xp: json['xp'] ?? 0,
        gold: json['gold'] ?? 100,
        health: json['health'] ?? 100,
        maxHealth: json['maxHealth'] ?? 100,
        mana: json['mana'] ?? 50,
        maxMana: json['maxMana'] ?? 50,
        stats: PlayerStats.fromJson(json['stats'] ?? {}),
        inventory: List<String>.from(json['inventory'] ?? []),
        equippedItems: List<String>.from(json['equippedItems'] ?? []),
        abilities: List<String>.from(json['abilities'] ?? []),
        completedQuests: List<String>.from(json['completedQuests'] ?? []),
        activeQuests: List<String>.from(json['activeQuests'] ?? []),
        currentLocationId: json['currentLocationId'] ?? 'town_square',
        reputation: Map<String, int>.from(json['reputation'] ?? {}),
        playtime: json['playtime'] ?? 0,
        lastPlayed: json['lastPlayed'] != null
            ? DateTime.parse(json['lastPlayed'])
            : DateTime.now(),
        languageLevel: json['languageLevel'] ?? 'A0',
        storyFlags: Set<String>.from(json['storyFlags'] ?? []),
        taskProgress: Map<String, int>.from(json['taskProgress'] ?? {}),
        learnedInfo: Set<String>.from(json['learnedInfo'] ?? []),
        talkedToNPCs: Set<String>.from(json['talkedToNPCs'] ?? []),
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'classId': classId,
        'level': level,
        'xp': xp,
        'gold': gold,
        'health': health,
        'maxHealth': maxHealth,
        'mana': mana,
        'maxMana': maxMana,
        'stats': stats.toJson(),
        'inventory': inventory,
        'equippedItems': equippedItems,
        'abilities': abilities,
        'completedQuests': completedQuests,
        'activeQuests': activeQuests,
        'currentLocationId': currentLocationId,
        'reputation': reputation,
        'playtime': playtime,
        'lastPlayed': lastPlayed.toIso8601String(),
        'languageLevel': languageLevel,
        'storyFlags': storyFlags.toList(),
        'taskProgress': taskProgress,
        'learnedInfo': learnedInfo.toList(),
        'talkedToNPCs': talkedToNPCs.toList(),
      };

  int get xpForNextLevel => (level * level * 100) + (level * 50);
  double get xpProgress => xp / xpForNextLevel;
  bool get canLevelUp => xp >= xpForNextLevel;
  int get attackPower => stats.strength * 2 + level * 5;
  int get defense => stats.constitution + level * 2;
  int get magicPower => stats.intelligence * 2 + level * 3;
}

// Item Model
class Item {
  final String id;
  final LocalizedString name;
  final LocalizedString description;
  final String icon;
  final ItemType type;
  final ItemRarity rarity;
  final int value;
  final Map<String, int> statBoosts;
  final Map<String, dynamic> effects;
  final bool stackable;
  final int maxStack;
  final String? locationId;
  final String acquisitionType;
  final String languageLevel;
  final int quantityAvailable;
  final bool respawns;
  final LocalizedString? vocabularyWord;
  final LocalizedString? usageHint;

  Item({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.type,
    required this.rarity,
    required this.value,
    this.statBoosts = const {},
    this.effects = const {},
    this.stackable = false,
    this.maxStack = 99,
    this.locationId,
    this.acquisitionType = 'gather',
    this.languageLevel = 'A0',
    this.quantityAvailable = -1,
    this.respawns = true,
    this.vocabularyWord,
    this.usageHint,
  });

  String get emoji => icon.isNotEmpty ? icon : '\u{1F4E6}';

  String get displayName => name.current;
  String get displayDescription => description.current;

  factory Item.fromJson(Map<String, dynamic> json) => Item(
        id: json['id'],
        name: LocalizedString.fromJson(json['name']),
        description: LocalizedString.fromJson(json['description'] ?? ''),
        icon: json['icon'] ?? '',
        type: _parseItemType(json['type'] ?? json['category']),
        rarity: _parseItemRarity(json['rarity']),
        value: json['value'] ?? json['price'] ?? 0,
        statBoosts: Map<String, int>.from(json['statBoosts'] ?? {}),
        effects: Map<String, dynamic>.from(json['effects'] ?? {}),
        stackable: json['stackable'] ?? false,
        maxStack: json['maxStack'] ?? 99,
        locationId: json['location_id'],
        acquisitionType: json['acquisition_type'] ?? 'gather',
        languageLevel: json['language_level'] ?? 'A0',
        quantityAvailable: json['quantity_available'] ?? -1,
        respawns: json['respawns'] ?? true,
        vocabularyWord: json['vocabulary_word'] != null
            ? LocalizedString.fromJson(json['vocabulary_word'])
            : null,
        usageHint: json['usage_hint'] != null
            ? LocalizedString.fromJson(json['usage_hint'])
            : null,
      );

  static ItemType _parseItemType(String? type) {
    switch (type) {
      case 'weapon':
        return ItemType.weapon;
      case 'armor':
        return ItemType.armor;
      case 'consumable':
        return ItemType.consumable;
      case 'quest':
        return ItemType.quest;
      case 'material':
        return ItemType.material;
      case 'document':
      case 'tool':
      case 'gift':
      case 'valuable':
        // Map additional categories to material type for now
        return ItemType.material;
      default:
        return ItemType.material;
    }
  }

  /// Get an appropriate emoji for this item based on its type/category
  String get categoryEmoji {
    // Check if we have a custom icon
    if (icon.isNotEmpty) return icon;

    // Return type-based emoji
    switch (type) {
      case ItemType.weapon:
        return '\u{2694}'; // Crossed swords
      case ItemType.armor:
        return '\u{1F6E1}'; // Shield
      case ItemType.consumable:
        return '\u{1F34E}'; // Apple
      case ItemType.quest:
        return '\u{1F4DC}'; // Scroll
      case ItemType.material:
        return '\u{1F48E}'; // Gem
    }
  }

  static ItemRarity _parseItemRarity(String? rarity) {
    switch (rarity) {
      case 'common':
        return ItemRarity.common;
      case 'uncommon':
        return ItemRarity.uncommon;
      case 'rare':
        return ItemRarity.rare;
      case 'epic':
        return ItemRarity.epic;
      case 'legendary':
        return ItemRarity.legendary;
      default:
        return ItemRarity.common;
    }
  }
}

/// Represents an item available at a location
class LocationItem {
  final Item item;
  final bool canPickup;
  final String acquisitionType; // 'gather', 'purchase', 'find'
  final int price;

  LocationItem({
    required this.item,
    required this.canPickup,
    required this.acquisitionType,
    required this.price,
  });

  /// Get the icon for this item's acquisition type
  String get acquisitionIcon {
    switch (acquisitionType) {
      case 'gather':
        return '\u{1F331}'; // Seedling
      case 'purchase':
        return '\u{1F4B0}'; // Money bag
      case 'find':
        return '\u{1F50D}'; // Magnifying glass
      default:
        return '\u{1F4E6}'; // Package
    }
  }

  /// Get the action text for this item
  String get actionText {
    switch (acquisitionType) {
      case 'gather':
        return 'Pick up';
      case 'purchase':
        return 'Buy ($price gold)';
      case 'find':
        return 'Take';
      default:
        return 'Get';
    }
  }
}

// NPC Personality
class NPCPersonality {
  final List<LocalizedString> traits;
  final LocalizedString speakingStyle;
  final List<LocalizedString> quirks;

  NPCPersonality({
    required this.traits,
    required this.speakingStyle,
    required this.quirks,
  });

  factory NPCPersonality.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return NPCPersonality(
        traits: [],
        speakingStyle: const LocalizedString(nativeLanguage: '', targetLanguage: ''),
        quirks: [],
      );
    }
    return NPCPersonality(
      traits: (json['traits'] as List?)
              ?.map((t) => LocalizedString.fromJson(t))
              .toList() ??
          [],
      speakingStyle: LocalizedString.fromJson(json['speaking_style'] ?? ''),
      quirks: (json['quirks'] as List?)
              ?.map((q) => LocalizedString.fromJson(q))
              .toList() ??
          [],
    );
  }
}

// NPC Knowledge
class NPCKnowledge {
  final List<LocalizedString> knowsAbout;
  final List<LocalizedString> doesNotKnow;

  NPCKnowledge({
    required this.knowsAbout,
    required this.doesNotKnow,
  });

  factory NPCKnowledge.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return NPCKnowledge(knowsAbout: [], doesNotKnow: []);
    }
    return NPCKnowledge(
      knowsAbout: (json['knows_about'] as List?)
              ?.map((k) => LocalizedString.fromJson(k))
              .toList() ??
          [],
      doesNotKnow: (json['does_not_know'] as List?)
              ?.map((k) => LocalizedString.fromJson(k))
              .toList() ??
          [],
    );
  }
}

// NPC Example Interaction
class NPCExampleInteraction {
  final String playerAction;
  final LocalizedString npcResponse;
  final String reasoning;

  NPCExampleInteraction({
    required this.playerAction,
    required this.npcResponse,
    required this.reasoning,
  });

  factory NPCExampleInteraction.fromJson(Map<String, dynamic> json) {
    return NPCExampleInteraction(
      playerAction: json['player_action'] ?? '',
      npcResponse: LocalizedString.fromJson(json['npc_response'] ?? ''),
      reasoning: json['reasoning'] ?? '',
    );
  }
}

// NPC Behavioral Boundaries
class NPCBehavioralBoundaries {
  final List<String> willDo;
  final List<String> willNotDo;
  final List<String> conditions;

  NPCBehavioralBoundaries({
    required this.willDo,
    required this.willNotDo,
    required this.conditions,
  });

  factory NPCBehavioralBoundaries.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return NPCBehavioralBoundaries(willDo: [], willNotDo: [], conditions: []);
    }
    return NPCBehavioralBoundaries(
      willDo: List<String>.from(json['will_do'] ?? []),
      willNotDo: List<String>.from(json['will_not_do'] ?? []),
      conditions: List<String>.from(json['conditions'] ?? []),
    );
  }
}

class NPC {
  final String id;
  final LocalizedString name;
  final LocalizedString title;
  final String archetype;
  final String locationId;
  final String languageLevel;
  final LocalizedString description;
  final LocalizedString appearance;
  final NPCPersonality personality;
  final NPCKnowledge knowledge;
  final List<String> relationships;
  final List<String> inventory;
  final List<String> questRoles;
  final LocalizedString greeting;
  final LocalizedString farewell;
  final String agentPrompt;
  final List<NPCExampleInteraction> exampleInteractions;
  final NPCBehavioralBoundaries behavioralBoundaries;
  final List<DialogueNode> dialogues;
  final List<String> shopItems;
  final List<String> questIds;

  NPC({
    required this.id,
    required this.name,
    required this.title,
    required this.archetype,
    required this.locationId,
    required this.languageLevel,
    required this.description,
    required this.appearance,
    required this.personality,
    required this.knowledge,
    required this.relationships,
    required this.inventory,
    required this.questRoles,
    required this.greeting,
    required this.farewell,
    required this.agentPrompt,
    required this.exampleInteractions,
    required this.behavioralBoundaries,
    this.dialogues = const [],
    this.shopItems = const [],
    this.questIds = const [],
  });

  String get displayName => name.current;
  String get displayTitle => title.current;
  String get displayDescription => description.current;
  String get displayGreeting => greeting.current;
  String get displayFarewell => farewell.current;

  List<String> get shopInventory => shopItems;

  NPCType get type {
    switch (archetype) {
      case 'merchant':
        return NPCType.merchant;
      case 'quest_giver':
        return NPCType.questGiver;
      case 'trainer':
        return NPCType.trainer;
      case 'child':
        return NPCType.child;
      default:
        return NPCType.regular;
    }
  }

  factory NPC.fromJson(Map<String, dynamic> json) => NPC(
        id: json['id'] ?? '',
        name: LocalizedString.fromJson(json['name']),
        title: LocalizedString.fromJson(json['title'] ?? ''),
        archetype: json['archetype'] ?? 'regular',
        locationId: json['location_id'] ?? '',
        languageLevel: json['language_level'] ?? 'A0',
        description: LocalizedString.fromJson(json['description'] ?? ''),
        appearance: LocalizedString.fromJson(json['appearance'] ?? ''),
        personality: NPCPersonality.fromJson(json['personality']),
        knowledge: NPCKnowledge.fromJson(json['knowledge']),
        relationships: List<String>.from(json['relationships'] ?? []),
        inventory: List<String>.from(json['inventory'] ?? []),
        questRoles: List<String>.from(json['quest_roles'] ?? []),
        greeting: LocalizedString.fromJson(json['greeting'] ?? ''),
        farewell: LocalizedString.fromJson(json['farewell'] ?? ''),
        agentPrompt: json['agent_prompt'] ?? '',
        exampleInteractions: (json['example_interactions'] as List?)
                ?.map((e) => NPCExampleInteraction.fromJson(e))
                .toList() ??
            [],
        behavioralBoundaries:
            NPCBehavioralBoundaries.fromJson(json['behavioral_boundaries']),
        dialogues: (json['dialogues'] as List?)
                ?.map((d) => DialogueNode.fromJson(d))
                .toList() ??
            [],
        shopItems: List<String>.from(json['shopItems'] ?? json['shop_items'] ?? []),
        questIds: List<String>.from(json['questIds'] ?? json['quest_ids'] ?? []),
      );
}

class DialogueNode {
  final String id;
  final LocalizedString text;
  final String? speaker;
  final List<DialogueOption> options;
  final Map<String, dynamic>? requirements;
  final Map<String, dynamic>? effects;

  DialogueNode({
    required this.id,
    required this.text,
    this.speaker,
    required this.options,
    this.requirements,
    this.effects,
  });

  String get displayText => text.current;

  factory DialogueNode.fromJson(Map<String, dynamic> json) => DialogueNode(
        id: json['id'] ?? '',
        text: LocalizedString.fromJson(json['text'] ?? ''),
        speaker: json['speaker'],
        options: (json['options'] as List?)
                ?.map((o) => DialogueOption.fromJson(o))
                .toList() ??
            [],
        requirements: json['requirements'],
        effects: json['effects'],
      );
}

class DialogueOption {
  final LocalizedString text;
  final String? nextId;
  final Map<String, dynamic>? requirements;
  final Map<String, dynamic>? effects;
  final String? action;

  DialogueOption({
    required this.text,
    this.nextId,
    this.requirements,
    this.effects,
    this.action,
  });

  String get displayText => text.current;

  factory DialogueOption.fromJson(Map<String, dynamic> json) => DialogueOption(
        text: LocalizedString.fromJson(json['text'] ?? ''),
        nextId: json['nextId'],
        requirements: json['requirements'],
        effects: json['effects'],
        action: json['action'],
      );
}

class Region {
  final String id;
  final LocalizedString name;
  final LocalizedString description;
  final String unlockedAtLevel;
  final List<String> locationIds;

  Region({
    required this.id,
    required this.name,
    required this.description,
    required this.unlockedAtLevel,
    required this.locationIds,
  });

  String get displayName => name.current;
  String get displayDescription => description.current;

  factory Region.fromJson(Map<String, dynamic> json) => Region(
        id: json['id'] ?? '',
        name: LocalizedString.fromJson(json['name']),
        description: LocalizedString.fromJson(json['description'] ?? ''),
        unlockedAtLevel: json['unlocked_at_level'] ?? 'A0',
        locationIds: List<String>.from(json['locations'] ?? []),
      );
}

class Location {
  final String id;
  final String regionId;
  final LocalizedString name;
  final LocalizedString description;
  final String locationType;
  final List<String> languageTopics;
  final LocalizedString vocabularyDomain;
  final String minimumLanguageLevel;
  final LocationUnlockRequirements unlockRequirements;
  final List<String> connectedLocations;
  final List<String> npcs;
  final List<String> availableItems;
  final LocalizedString atmosphere;
  final Map<String, int> coordinates;

  Location({
    required this.id,
    required this.regionId,
    required this.name,
    required this.description,
    required this.locationType,
    required this.languageTopics,
    required this.vocabularyDomain,
    required this.minimumLanguageLevel,
    required this.unlockRequirements,
    required this.connectedLocations,
    required this.npcs,
    required this.availableItems,
    required this.atmosphere,
    required this.coordinates,
  });

  // Display helpers
  String get displayName => name.current;
  String get displayDescription => description.current;
  String get displayAtmosphere => atmosphere.current;

  // Alias for connectedLocations
  List<String> get connections => connectedLocations;

  // Get location type enum
  LocationType get type {
    switch (locationType) {
      case 'outdoor':
        return LocationType.outdoor;
      case 'building':
        return LocationType.building;
      case 'dungeon':
        return LocationType.dungeon;
      default:
        return LocationType.outdoor;
    }
  }

  // Get icon based on location type
  String get icon {
    switch (locationType) {
      case 'outdoor':
        return '\u{1F333}';
      case 'building':
        return '\u{1F3E0}';
      case 'dungeon':
        return '\u{1F5FF}';
      default:
        return '\u{1F4CD}';
    }
  }

  String get emoji => icon;

  factory Location.fromJson(Map<String, dynamic> json) => Location(
        id: json['id'] ?? '',
        regionId: json['region_id'] ?? '',
        name: LocalizedString.fromJson(json['name']),
        description: LocalizedString.fromJson(json['description'] ?? ''),
        locationType: json['type'] ?? 'outdoor',
        languageTopics: List<String>.from(json['language_topics'] ?? []),
        vocabularyDomain: LocalizedString.fromJson(json['vocabulary_domain'] ?? ''),
        minimumLanguageLevel: json['minimum_language_level'] ?? 'A0',
        unlockRequirements:
            LocationUnlockRequirements.fromJson(json['unlock_requirements']),
        connectedLocations: List<String>.from(json['connections'] ?? []),
        npcs: List<String>.from(json['npcs'] ?? []),
        availableItems: List<String>.from(json['available_items'] ?? []),
        atmosphere: LocalizedString.fromJson(json['atmosphere'] ?? ''),
        coordinates: Map<String, int>.from(json['coordinates'] ?? {'x': 0, 'y': 0}),
      );
}

// Location Unlock Requirements
class LocationUnlockRequirements {
  final String languageLevel;
  final List<String> questPrerequisites;
  final List<String> storyFlags;

  LocationUnlockRequirements({
    required this.languageLevel,
    required this.questPrerequisites,
    required this.storyFlags,
  });

  factory LocationUnlockRequirements.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return LocationUnlockRequirements(
        languageLevel: 'A0',
        questPrerequisites: [],
        storyFlags: [],
      );
    }
    return LocationUnlockRequirements(
      languageLevel: json['language_level'] ?? 'A0',
      questPrerequisites: List<String>.from(json['quest_prerequisites'] ?? []),
      storyFlags: List<String>.from(json['story_flags'] ?? []),
    );
  }
}

// Location Connection
class LocationConnection {
  final String fromLocation;
  final String toLocation;
  final LocalizedString travelDescription;
  final bool bidirectional;

  LocationConnection({
    required this.fromLocation,
    required this.toLocation,
    required this.travelDescription,
    required this.bidirectional,
  });

  String get displayTravelDescription => travelDescription.current;

  factory LocationConnection.fromJson(Map<String, dynamic> json) =>
      LocationConnection(
        fromLocation: json['from_location'] ?? '',
        toLocation: json['to_location'] ?? '',
        travelDescription:
            LocalizedString.fromJson(json['travel_description'] ?? ''),
        bidirectional: json['bidirectional'] ?? true,
      );
}

// Quest Line
class QuestLine {
  final String id;
  final LocalizedString name;
  final LocalizedString description;
  final List<String> questIds;

  QuestLine({
    required this.id,
    required this.name,
    required this.description,
    required this.questIds,
  });

  String get displayName => name.current;
  String get displayDescription => description.current;

  factory QuestLine.fromJson(Map<String, dynamic> json) => QuestLine(
        id: json['id'] ?? '',
        name: LocalizedString.fromJson(json['name']),
        description: LocalizedString.fromJson(json['description'] ?? ''),
        questIds: List<String>.from(json['quests'] ?? []),
      );
}

// Quest Task
class QuestTask {
  final String id;
  final int order;
  final LocalizedString description;
  final LocalizedString hint;
  final String completionType;
  final Map<String, dynamic> completionCriteria;
  final Map<String, dynamic> onComplete;
  bool completed;

  QuestTask({
    required this.id,
    required this.order,
    required this.description,
    required this.hint,
    required this.completionType,
    required this.completionCriteria,
    required this.onComplete,
    this.completed = false,
  });

  String get displayDescription => description.current;
  String get displayHint => hint.current;

  factory QuestTask.fromJson(Map<String, dynamic> json) => QuestTask(
        id: json['id'] ?? '',
        order: json['order'] ?? 0,
        description: LocalizedString.fromJson(json['description'] ?? ''),
        hint: LocalizedString.fromJson(json['hint'] ?? ''),
        completionType: json['completion_type'] ?? '',
        completionCriteria:
            Map<String, dynamic>.from(json['completion_criteria'] ?? {}),
        onComplete: Map<String, dynamic>.from(json['on_complete'] ?? {}),
        completed: json['completed'] ?? false,
      );
}

// Quest Dialogue
class QuestDialogue {
  final LocalizedString questOffer;
  final LocalizedString questAccept;
  final LocalizedString questDecline;
  final LocalizedString questProgress;
  final LocalizedString questComplete;

  QuestDialogue({
    required this.questOffer,
    required this.questAccept,
    required this.questDecline,
    required this.questProgress,
    required this.questComplete,
  });

  factory QuestDialogue.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return QuestDialogue(
        questOffer: const LocalizedString(nativeLanguage: '', targetLanguage: ''),
        questAccept: const LocalizedString(nativeLanguage: '', targetLanguage: ''),
        questDecline: const LocalizedString(nativeLanguage: '', targetLanguage: ''),
        questProgress: const LocalizedString(nativeLanguage: '', targetLanguage: ''),
        questComplete: const LocalizedString(nativeLanguage: '', targetLanguage: ''),
      );
    }
    return QuestDialogue(
      questOffer: LocalizedString.fromJson(json['quest_offer'] ?? ''),
      questAccept: LocalizedString.fromJson(json['quest_accept'] ?? ''),
      questDecline: LocalizedString.fromJson(json['quest_decline'] ?? ''),
      questProgress: LocalizedString.fromJson(json['quest_progress'] ?? ''),
      questComplete: LocalizedString.fromJson(json['quest_complete'] ?? ''),
    );
  }
}

// Quest Language Learning
class QuestLanguageLearning {
  final List<LocalizedString> targetVocabulary;
  final List<LocalizedString> grammarPoints;
  final List<LocalizedString> conversationSkills;

  QuestLanguageLearning({
    required this.targetVocabulary,
    required this.grammarPoints,
    required this.conversationSkills,
  });

  factory QuestLanguageLearning.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return QuestLanguageLearning(
        targetVocabulary: [],
        grammarPoints: [],
        conversationSkills: [],
      );
    }
    return QuestLanguageLearning(
      targetVocabulary: (json['target_vocabulary'] as List?)
              ?.map((v) => LocalizedString.fromJson(v))
              .toList() ??
          [],
      grammarPoints: (json['grammar_points'] as List?)
              ?.map((g) => LocalizedString.fromJson(g))
              .toList() ??
          [],
      conversationSkills: (json['conversation_skills'] as List?)
              ?.map((c) => LocalizedString.fromJson(c))
              .toList() ??
          [],
    );
  }
}

// Quest Unlock Requirements
class QuestUnlockRequirements {
  final String languageLevel;
  final List<String> completedQuests;
  final List<String> storyFlags;

  QuestUnlockRequirements({
    required this.languageLevel,
    required this.completedQuests,
    required this.storyFlags,
  });

  factory QuestUnlockRequirements.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return QuestUnlockRequirements(
        languageLevel: 'A0',
        completedQuests: [],
        storyFlags: [],
      );
    }
    return QuestUnlockRequirements(
      languageLevel: json['language_level'] ?? 'A0',
      completedQuests: List<String>.from(json['completed_quests'] ?? []),
      storyFlags: List<String>.from(json['story_flags'] ?? []),
    );
  }
}

// Quest Objectives
class QuestObjectives {
  final LocalizedString summary;
  final LocalizedString detailed;

  QuestObjectives({
    required this.summary,
    required this.detailed,
  });

  String get displaySummary => summary.current;
  String get displayDetailed => detailed.current;

  factory QuestObjectives.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return QuestObjectives(
        summary: const LocalizedString(nativeLanguage: '', targetLanguage: ''),
        detailed: const LocalizedString(nativeLanguage: '', targetLanguage: ''),
      );
    }
    return QuestObjectives(
      summary: LocalizedString.fromJson(json['summary'] ?? ''),
      detailed: LocalizedString.fromJson(json['detailed'] ?? ''),
    );
  }
}

// Quest Model - Updated for language learning
class Quest {
  final String id;
  final String? questLineId;
  final String type;
  final String pattern;
  final LocalizedString name;
  final LocalizedString description;
  final String giverNpcId;
  final String languageLevel;
  final QuestUnlockRequirements unlockRequirements;
  final QuestObjectives objectives;
  final List<QuestTask> tasks;
  final QuestRewards rewards;
  final QuestDialogue dialogue;
  final QuestLanguageLearning languageLearning;
  final String notesForAgent;
  bool _isCompleted;

  Quest({
    required this.id,
    this.questLineId,
    required this.type,
    required this.pattern,
    required this.name,
    required this.description,
    required this.giverNpcId,
    required this.languageLevel,
    required this.unlockRequirements,
    required this.objectives,
    required this.tasks,
    required this.rewards,
    required this.dialogue,
    required this.languageLearning,
    required this.notesForAgent,
    bool isCompleted = false,
  }) : _isCompleted = isCompleted;

  // Display helpers
  String get displayName => name.current;
  String get displayDescription => description.current;

  // Check if quest is completed
  bool get isCompleted => _isCompleted || tasks.every((t) => t.completed);
  set isCompleted(bool value) => _isCompleted = value;

  // For backwards compatibility
  int get recommendedLevel => 1;

  // Get the current task (first incomplete task)
  QuestTask? get currentTask {
    final sortedTasks = List<QuestTask>.from(tasks)
      ..sort((a, b) => a.order.compareTo(b.order));
    for (final task in sortedTasks) {
      if (!task.completed) return task;
    }
    return null;
  }

  // Get current task index (0-based)
  int get currentTaskIndex {
    final sortedTasks = List<QuestTask>.from(tasks)
      ..sort((a, b) => a.order.compareTo(b.order));
    for (int i = 0; i < sortedTasks.length; i++) {
      if (!sortedTasks[i].completed) return i;
    }
    return tasks.length; // All complete
  }

  // Get completed task count
  int get completedTaskCount => tasks.where((t) => t.completed).length;

  // Get progress as percentage (0.0 to 1.0)
  double get progress {
    if (tasks.isEmpty) return isCompleted ? 1.0 : 0.0;
    return completedTaskCount / tasks.length;
  }

  // Get progress as percentage string
  String get progressPercent => '${(progress * 100).round()}%';

  // Check if player meets unlock requirements
  bool canUnlock(Player player) {
    // Check language level
    if (!LanguageService.instance.meetsLanguageLevel(unlockRequirements.languageLevel)) {
      return false;
    }
    // Check completed quests
    for (final questId in unlockRequirements.completedQuests) {
      if (!player.completedQuests.contains(questId)) {
        return false;
      }
    }
    // Check story flags
    for (final flag in unlockRequirements.storyFlags) {
      if (!player.storyFlags.contains(flag)) {
        return false;
      }
    }
    return true;
  }

  factory Quest.fromJson(Map<String, dynamic> json) => Quest(
        id: json['id'] ?? '',
        questLineId: json['quest_line_id'],
        type: json['type'] ?? 'side',
        pattern: json['pattern'] ?? 'fetch',
        name: LocalizedString.fromJson(json['name']),
        description: LocalizedString.fromJson(json['description'] ?? ''),
        giverNpcId: json['giver_npc_id'] ?? '',
        languageLevel: json['language_level'] ?? 'A0',
        unlockRequirements:
            QuestUnlockRequirements.fromJson(json['unlock_requirements']),
        objectives: QuestObjectives.fromJson(json['objectives']),
        tasks: (json['tasks'] as List?)
                ?.map((t) => QuestTask.fromJson(t))
                .toList() ??
            [],
        rewards: QuestRewards.fromJson(json['rewards'] ?? {}),
        dialogue: QuestDialogue.fromJson(json['dialogue']),
        languageLearning:
            QuestLanguageLearning.fromJson(json['language_learning']),
        notesForAgent: json['notes_for_agent'] ?? '',
        isCompleted: json['isCompleted'] ?? false,
      );
}

// Quest Objective (for backwards compatibility)
class QuestObjective {
  final String id;
  final String description;
  final String type;
  final String? targetId;
  final int targetAmount;
  int currentAmount;
  bool completed;

  QuestObjective({
    required this.id,
    required this.description,
    required this.type,
    this.targetId,
    required this.targetAmount,
    this.currentAmount = 0,
    this.completed = false,
  });

  factory QuestObjective.fromJson(Map<String, dynamic> json) => QuestObjective(
        id: json['id'],
        description: json['description'],
        type: json['type'],
        targetId: json['targetId'],
        targetAmount: json['targetAmount'] ?? 1,
        currentAmount: json['currentAmount'] ?? 0,
        completed: json['completed'] ?? false,
      );
}

// Quest Rewards
class QuestRewards {
  final int experience;
  final List<String> items;
  final QuestUnlocks unlocks;
  final List<String> storyFlags;

  QuestRewards({
    required this.experience,
    required this.items,
    required this.unlocks,
    required this.storyFlags,
  });

  // Aliases for backwards compatibility
  int get xp => experience;
  int get gold => 0;
  Map<String, int> get reputation => {};

  factory QuestRewards.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return QuestRewards(
        experience: 0,
        items: [],
        unlocks: QuestUnlocks(locations: [], quests: [], npcs: []),
        storyFlags: [],
      );
    }
    return QuestRewards(
      experience: json['experience'] ?? json['xp'] ?? 0,
      items: List<String>.from(json['items'] ?? []),
      unlocks: QuestUnlocks.fromJson(json['unlocks']),
      storyFlags: List<String>.from(json['story_flags'] ?? []),
    );
  }
}

// Quest Unlocks
class QuestUnlocks {
  final List<String> locations;
  final List<String> quests;
  final List<String> npcs;

  QuestUnlocks({
    required this.locations,
    required this.quests,
    required this.npcs,
  });

  factory QuestUnlocks.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return QuestUnlocks(locations: [], quests: [], npcs: []);
    }
    return QuestUnlocks(
      locations: List<String>.from(json['locations'] ?? []),
      quests: List<String>.from(json['quests'] ?? []),
      npcs: List<String>.from(json['npcs'] ?? []),
    );
  }
}

// World Lore
class WorldLore {
  final LocalizedString worldName;
  final LocalizedString worldDescription;
  final WorldBackstory backstory;
  final WorldSetting setting;
  final List<MagicalElement> magicalElements;
  final List<Faction> factions;
  final List<LocalizedString> keyThemes;
  final LanguageIntegration languageIntegration;

  WorldLore({
    required this.worldName,
    required this.worldDescription,
    required this.backstory,
    required this.setting,
    required this.magicalElements,
    required this.factions,
    required this.keyThemes,
    required this.languageIntegration,
  });

  factory WorldLore.fromJson(Map<String, dynamic> json) => WorldLore(
        worldName: LocalizedString.fromJson(json['world_name']),
        worldDescription: LocalizedString.fromJson(json['world_description'] ?? ''),
        backstory: WorldBackstory.fromJson(json['backstory']),
        setting: WorldSetting.fromJson(json['setting']),
        magicalElements: (json['magical_elements'] as List?)
                ?.map((m) => MagicalElement.fromJson(m))
                .toList() ??
            [],
        factions: (json['factions'] as List?)
                ?.map((f) => Faction.fromJson(f))
                .toList() ??
            [],
        keyThemes: (json['key_themes'] as List?)
                ?.map((t) => LocalizedString.fromJson(t))
                .toList() ??
            [],
        languageIntegration:
            LanguageIntegration.fromJson(json['language_integration']),
      );
}

class WorldBackstory {
  final LocalizedString summary;
  final LocalizedString playerOrigin;
  final LocalizedString motivation;

  WorldBackstory({
    required this.summary,
    required this.playerOrigin,
    required this.motivation,
  });

  factory WorldBackstory.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return WorldBackstory(
        summary: const LocalizedString(nativeLanguage: '', targetLanguage: ''),
        playerOrigin: const LocalizedString(nativeLanguage: '', targetLanguage: ''),
        motivation: const LocalizedString(nativeLanguage: '', targetLanguage: ''),
      );
    }
    return WorldBackstory(
      summary: LocalizedString.fromJson(json['summary'] ?? ''),
      playerOrigin: LocalizedString.fromJson(json['player_origin'] ?? ''),
      motivation: LocalizedString.fromJson(json['motivation'] ?? ''),
    );
  }
}

class WorldSetting {
  final LocalizedString era;
  final LocalizedString atmosphere;
  final LocalizedString culture;

  WorldSetting({
    required this.era,
    required this.atmosphere,
    required this.culture,
  });

  factory WorldSetting.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return WorldSetting(
        era: const LocalizedString(nativeLanguage: '', targetLanguage: ''),
        atmosphere: const LocalizedString(nativeLanguage: '', targetLanguage: ''),
        culture: const LocalizedString(nativeLanguage: '', targetLanguage: ''),
      );
    }
    return WorldSetting(
      era: LocalizedString.fromJson(json['era'] ?? ''),
      atmosphere: LocalizedString.fromJson(json['atmosphere'] ?? ''),
      culture: LocalizedString.fromJson(json['culture'] ?? ''),
    );
  }
}

class MagicalElement {
  final LocalizedString name;
  final LocalizedString description;

  MagicalElement({
    required this.name,
    required this.description,
  });

  factory MagicalElement.fromJson(Map<String, dynamic> json) => MagicalElement(
        name: LocalizedString.fromJson(json['name']),
        description: LocalizedString.fromJson(json['description'] ?? ''),
      );
}

class Faction {
  final LocalizedString name;
  final LocalizedString description;
  final LocalizedString roleInWorld;

  Faction({
    required this.name,
    required this.description,
    required this.roleInWorld,
  });

  factory Faction.fromJson(Map<String, dynamic> json) => Faction(
        name: LocalizedString.fromJson(json['name']),
        description: LocalizedString.fromJson(json['description'] ?? ''),
        roleInWorld: LocalizedString.fromJson(json['role_in_world'] ?? ''),
      );
}

class LanguageIntegration {
  final LocalizedString whyPlayerLearns;
  final LocalizedString howLanguageFits;

  LanguageIntegration({
    required this.whyPlayerLearns,
    required this.howLanguageFits,
  });

  factory LanguageIntegration.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return LanguageIntegration(
        whyPlayerLearns: const LocalizedString(nativeLanguage: '', targetLanguage: ''),
        howLanguageFits: const LocalizedString(nativeLanguage: '', targetLanguage: ''),
      );
    }
    return LanguageIntegration(
      whyPlayerLearns: LocalizedString.fromJson(json['why_player_learns'] ?? ''),
      howLanguageFits: LocalizedString.fromJson(json['how_language_fits'] ?? ''),
    );
  }
}

// Map Metadata
class MapMetadata {
  final LocalizedString name;
  final LocalizedString description;
  final String scale;

  MapMetadata({
    required this.name,
    required this.description,
    required this.scale,
  });

  factory MapMetadata.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return MapMetadata(
        name: const LocalizedString(nativeLanguage: '', targetLanguage: ''),
        description: const LocalizedString(nativeLanguage: '', targetLanguage: ''),
        scale: 'village',
      );
    }
    return MapMetadata(
      name: LocalizedString.fromJson(json['name']),
      description: LocalizedString.fromJson(json['description'] ?? ''),
      scale: json['scale'] ?? 'village',
    );
  }
}

// Game World Data - Updated for language learning
class GameWorld {
  final WorldLore? lore;
  final MapMetadata? mapMetadata;
  final Map<String, Region> regions;
  final Map<String, Location> locations;
  final List<LocationConnection> connections;
  final String startingLocation;
  final Map<String, NPC> npcs;
  final Map<String, Item> items;
  final Map<String, QuestLine> questLines;
  final Map<String, Quest> quests;

  GameWorld({
    this.lore,
    this.mapMetadata,
    required this.regions,
    required this.locations,
    required this.connections,
    required this.startingLocation,
    required this.npcs,
    required this.items,
    required this.questLines,
    required this.quests,
  });

  factory GameWorld.fromJson(Map<String, dynamic> json) {
    // Parse regions
    final regionsMap = <String, Region>{};
    if (json['regions'] != null) {
      for (final regionJson in json['regions'] as List) {
        final region = Region.fromJson(regionJson);
        regionsMap[region.id] = region;
      }
    }

    // Parse locations
    final locationsMap = <String, Location>{};
    if (json['locations'] != null) {
      if (json['locations'] is List) {
        for (final locJson in json['locations'] as List) {
          final location = Location.fromJson(locJson);
          locationsMap[location.id] = location;
        }
      } else if (json['locations'] is Map) {
        (json['locations'] as Map<String, dynamic>).forEach((k, v) {
          locationsMap[k] = Location.fromJson(v);
        });
      }
    }

    // Parse connections
    final connectionsList = <LocationConnection>[];
    if (json['connections'] != null) {
      for (final connJson in json['connections'] as List) {
        connectionsList.add(LocationConnection.fromJson(connJson));
      }
    }

    // Parse quest lines
    final questLinesMap = <String, QuestLine>{};
    if (json['quest_lines'] != null) {
      for (final qlJson in json['quest_lines'] as List) {
        final questLine = QuestLine.fromJson(qlJson);
        questLinesMap[questLine.id] = questLine;
      }
    }

    // Parse quests
    final questsMap = <String, Quest>{};
    if (json['quests'] != null) {
      if (json['quests'] is List) {
        for (final questJson in json['quests'] as List) {
          final quest = Quest.fromJson(questJson);
          questsMap[quest.id] = quest;
        }
      } else if (json['quests'] is Map) {
        (json['quests'] as Map<String, dynamic>).forEach((k, v) {
          questsMap[k] = Quest.fromJson(v);
        });
      }
    }

    // Parse NPCs
    final npcsMap = <String, NPC>{};
    if (json['npcs'] != null) {
      if (json['npcs'] is List) {
        for (final npcJson in json['npcs'] as List) {
          final npc = NPC.fromJson(npcJson);
          npcsMap[npc.id] = npc;
        }
      } else if (json['npcs'] is Map) {
        (json['npcs'] as Map<String, dynamic>).forEach((k, v) {
          npcsMap[k] = NPC.fromJson(v);
        });
      }
    }

    return GameWorld(
      lore: json['lore'] != null ? WorldLore.fromJson(json['lore']) : null,
      mapMetadata: json['map_metadata'] != null
          ? MapMetadata.fromJson(json['map_metadata'])
          : null,
      regions: regionsMap,
      locations: locationsMap,
      connections: connectionsList,
      startingLocation: json['starting_location'] ?? 'town_square',
      npcs: npcsMap,
      items: (json['items'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, Item.fromJson(v))) ??
          {},
      questLines: questLinesMap,
      quests: questsMap,
    );
  }
}

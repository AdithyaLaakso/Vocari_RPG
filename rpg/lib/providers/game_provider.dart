import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/services/api_client.dart';
import 'package:shared/services/keycloak_service.dart';
import 'package:shared/services/grammar_service.dart';

import '../game_models.dart';
import '../npc_interaction.dart';
import '../models/skill_models.dart';
import '../models/user_skill_state.dart';
import '../services/trigger_evaluator.dart';
import '../services/level_progression_service.dart';
import '../services/narrator_service.dart';

// ============================================================================
// GAME STATE
// ============================================================================

/// Sentinel value used in copyWith to distinguish "not provided" from "set to null"
class _Sentinel {
  const _Sentinel();
}

const _sentinel = _Sentinel();

/// State container for the game.
/// Holds mutable domain objects (Player, Quest, etc.) — use bump() to trigger
/// Riverpod rebuilds after in-place mutations.
class GameState {
  final Player? player;
  final GameWorld? world;
  final Location? currentLocation;
  final NPC? currentNPC;
  final DialogueNode? currentDialogue;
  final List<String> gameLog;
  final bool isLoading;
  final String? error;
  final String timeOfDay;
  final int daysPassed;
  final Quest? pendingQuestOffer;
  final NPCInteractionRequest? pendingInteraction;

  // Skill system
  final SkillCollection? skills;
  final TriggerCollection? triggers;
  final LevelProgression? levelProgression;
  final LevelProgressionService? levelProgressionService;
  final UserSkillState? userSkillState;

  // Items & tracking
  final Map<String, dynamic> itemsByLocation;
  final Map<String, Set<String>> pickedUpItems;
  final Set<String> completedGames;
  final Set<String> givenItems;

  // Display
  final bool showTargetLanguage;

  // Internal version counter for bump()
  final int _version;

  GameState({
    this.player,
    this.world,
    this.currentLocation,
    this.currentNPC,
    this.currentDialogue,
    List<String>? gameLog,
    this.isLoading = true,
    this.error,
    this.timeOfDay = 'day',
    this.daysPassed = 0,
    this.pendingQuestOffer,
    this.pendingInteraction,
    this.skills,
    this.triggers,
    this.levelProgression,
    this.levelProgressionService,
    this.userSkillState,
    Map<String, dynamic>? itemsByLocation,
    Map<String, Set<String>>? pickedUpItems,
    Set<String>? completedGames,
    Set<String>? givenItems,
    this.showTargetLanguage = false,
    int version = 0,
  })  : gameLog = gameLog ?? [],
        itemsByLocation = itemsByLocation ?? {},
        pickedUpItems = pickedUpItems ?? {},
        completedGames = completedGames ?? {},
        givenItems = givenItems ?? {},
        _version = version;

  /// Create a new identity without changing any fields.
  /// Use after mutating mutable objects (Player, Quest, etc.) in place.
  GameState bump() => copyWith(version: _version + 1);

  GameState copyWith({
    Object? player = _sentinel,
    Object? world = _sentinel,
    Object? currentLocation = _sentinel,
    Object? currentNPC = _sentinel,
    Object? currentDialogue = _sentinel,
    List<String>? gameLog,
    bool? isLoading,
    Object? error = _sentinel,
    String? timeOfDay,
    int? daysPassed,
    Object? pendingQuestOffer = _sentinel,
    Object? pendingInteraction = _sentinel,
    Object? skills = _sentinel,
    Object? triggers = _sentinel,
    Object? levelProgression = _sentinel,
    Object? levelProgressionService = _sentinel,
    Object? userSkillState = _sentinel,
    Map<String, dynamic>? itemsByLocation,
    Map<String, Set<String>>? pickedUpItems,
    Set<String>? completedGames,
    Set<String>? givenItems,
    bool? showTargetLanguage,
    int? version,
  }) {
    return GameState(
      player: identical(player, _sentinel) ? this.player : player as Player?,
      world: identical(world, _sentinel) ? this.world : world as GameWorld?,
      currentLocation: identical(currentLocation, _sentinel)
          ? this.currentLocation
          : currentLocation as Location?,
      currentNPC: identical(currentNPC, _sentinel)
          ? this.currentNPC
          : currentNPC as NPC?,
      currentDialogue: identical(currentDialogue, _sentinel)
          ? this.currentDialogue
          : currentDialogue as DialogueNode?,
      gameLog: gameLog ?? this.gameLog,
      isLoading: isLoading ?? this.isLoading,
      error: identical(error, _sentinel) ? this.error : error as String?,
      timeOfDay: timeOfDay ?? this.timeOfDay,
      daysPassed: daysPassed ?? this.daysPassed,
      pendingQuestOffer: identical(pendingQuestOffer, _sentinel)
          ? this.pendingQuestOffer
          : pendingQuestOffer as Quest?,
      pendingInteraction: identical(pendingInteraction, _sentinel)
          ? this.pendingInteraction
          : pendingInteraction as NPCInteractionRequest?,
      skills: identical(skills, _sentinel)
          ? this.skills
          : skills as SkillCollection?,
      triggers: identical(triggers, _sentinel)
          ? this.triggers
          : triggers as TriggerCollection?,
      levelProgression: identical(levelProgression, _sentinel)
          ? this.levelProgression
          : levelProgression as LevelProgression?,
      levelProgressionService: identical(levelProgressionService, _sentinel)
          ? this.levelProgressionService
          : levelProgressionService as LevelProgressionService?,
      userSkillState: identical(userSkillState, _sentinel)
          ? this.userSkillState
          : userSkillState as UserSkillState?,
      itemsByLocation: itemsByLocation ?? this.itemsByLocation,
      pickedUpItems: pickedUpItems ?? this.pickedUpItems,
      completedGames: completedGames ?? this.completedGames,
      givenItems: givenItems ?? this.givenItems,
      showTargetLanguage: showTargetLanguage ?? this.showTargetLanguage,
      version: version ?? _version,
    );
  }

  // Computed getters accessed by consumers via ref.watch(gameProvider)

  DialogueNode? get currentDialogueNode => currentDialogue;

  Map<String, int> get skillLevels => userSkillState?.skills ?? {};
  int get totalSkillPoints => userSkillState?.totalSkillPoints ?? 0;

  bool meetsLanguageLevel(String requiredLevel) {
    if (player == null || requiredLevel.isEmpty) return true;
    const levels = ['A0', 'A1', 'A2', 'B1', 'B2', 'C1', 'C2'];
    final playerIndex = levels.indexOf(player!.languageLevel);
    final requiredIndex = levels.indexOf(requiredLevel);
    if (playerIndex == -1 || requiredIndex == -1) return true;
    return playerIndex >= requiredIndex;
  }

  List<Location> get connectedLocations {
    if (currentLocation == null || world == null) return [];
    return currentLocation!.connectedLocations
        .map((id) => world!.locations[id])
        .whereType<Location>()
        .toList();
  }

  List<NPC> get locationNPCs {
    if (currentLocation == null || world == null) return [];
    final npcIds = <String>{};
    npcIds.addAll(currentLocation!.npcs);
    for (final npc in world!.npcs.values) {
      if (npc.locationId == currentLocation!.id) {
        npcIds.add(npc.id);
      }
    }
    return npcIds
        .map((id) => world!.npcs[id])
        .whereType<NPC>()
        .toList();
  }

  List<LocationItem> get locationItems {
    if (currentLocation == null || world == null) return [];
    final locationId = currentLocation!.id;
    final itemIds = itemsByLocation[locationId] as List<dynamic>? ?? [];
    final pickedUp = pickedUpItems[locationId] ?? {};
    final items = <LocationItem>[];
    for (final itemId in itemIds) {
      final item = world!.items[itemId];
      if (item == null) continue;
      final itemData = _getItemData(itemId);
      final respawns = itemData?['respawns'] ?? true;
      final alreadyPicked = pickedUp.contains(itemId);
      if (alreadyPicked && !respawns) continue;
      final quantityAvailable = itemData?['quantity_available'] ?? -1;
      if (quantityAvailable == 0) continue;
      items.add(LocationItem(
        item: item,
        canPickup: !alreadyPicked || respawns,
        acquisitionType: itemData?['acquisition_type'] ?? 'gather',
        price: itemData?['price'] ?? 0,
      ));
    }
    return items;
  }

  Map<String, dynamic>? _getItemData(String itemId) {
    if (world?.items[itemId] != null) {
      return null;
    }
    return null;
  }

  List<Quest> get activeQuests {
    if (player == null || world == null) return [];
    return player!.activeQuests
        .map((id) => world!.quests[id])
        .whereType<Quest>()
        .toList();
  }

  List<MiniGame> get locationGames {
    if (currentLocation == null || world == null) return [];
    return world!.getGamesForLocation(currentLocation!.id);
  }

  bool isGameCompleted(String gameId) => completedGames.contains(gameId);
}

// ============================================================================
// GAME NOTIFIER
// ============================================================================

class GameNotifier extends Notifier<GameState> {
  /// Callback for quest progress notifications
  void Function(String questName, String? taskDescription, int completedTasks,
      int totalTasks, bool isQuestComplete, int? xpReward)? onQuestProgress;

  @override
  GameState build() => GameState();

  /// Toggle between native and target language display
  void toggleDisplayLanguage() {
    state = state.copyWith(showTargetLanguage: !state.showTargetLanguage);
  }

  /// Pick up an item at the current location
  void pickupItem(String itemId) {
    if (state.player == null || state.currentLocation == null || state.world == null) return;

    final item = state.world!.items[itemId];
    if (item == null) return;

    // Add to inventory
    state.player!.inventory.add(itemId);

    // Mark as picked up at this location
    final locationId = state.currentLocation!.id;
    state.pickedUpItems.putIfAbsent(locationId, () => {});
    state.pickedUpItems[locationId]!.add(itemId);

    addToLog("Picked up ${item.displayName}.");

    // Provide vocabulary hint via narrator if item has vocabulary word
    if (item.vocabularyWord != null) {
      ref.read(narratorProvider.notifier).provideVocabularyHint(
        word: item.vocabularyWord!.target,
        translation: item.vocabularyWord!.native,
        context: 'You found this item: ${item.displayName}',
      );
    }

    // Track for quest progress
    recordReceivedItem(itemId);

    state = state.bump();
    _syncProgressToServer();
  }

  Future<void> loadGameData() async {
    try {
      state = state.copyWith(isLoading: true);

      // Load core game data (required)
      const assetPrefix = 'packages/rpg_game/';
      final coreResults = await Future.wait([
        rootBundle.loadString('${assetPrefix}assets/data/map.json'),
        rootBundle.loadString('${assetPrefix}assets/data/npcs.json'),
        rootBundle.loadString('${assetPrefix}assets/data/quests.json'),
        rootBundle.loadString('${assetPrefix}assets/data/lore.json'),
        rootBundle.loadString('${assetPrefix}assets/data/items.json'),
      ]);

      final mapData = json.decode(coreResults[0]) as Map<String, dynamic>;
      final npcsData = json.decode(coreResults[1]) as Map<String, dynamic>;
      final questsData = json.decode(coreResults[2]) as Map<String, dynamic>;
      final loreData = json.decode(coreResults[3]) as Map<String, dynamic>;
      final itemsData = json.decode(coreResults[4]) as Map<String, dynamic>;

      // Load skill system data (optional - game continues without it)
      Map<String, dynamic>? skillsData;
      Map<String, dynamic>? triggersData;
      Map<String, dynamic>? levelProgressionData;
      Map<String, dynamic>? gamesData;

      try {
        final skillResults = await Future.wait([
          rootBundle.loadString('${assetPrefix}assets/data/skills.json'),
          rootBundle.loadString('${assetPrefix}assets/data/triggers.json'),
          rootBundle.loadString('${assetPrefix}assets/data/level_progression.json'),
        ]);
        skillsData = json.decode(skillResults[0]) as Map<String, dynamic>;
        triggersData = json.decode(skillResults[1]) as Map<String, dynamic>;
        levelProgressionData = json.decode(skillResults[2]) as Map<String, dynamic>;
      } catch (e) {
        debugPrint('Warning: Could not load skill system files: $e');
        debugPrint('Game will continue without skill progression system.');
      }

      // Load mini-games data (optional)
      try {
        final gamesJson = await rootBundle.loadString('${assetPrefix}assets/data/games.json');
        gamesData = json.decode(gamesJson) as Map<String, dynamic>;
      } catch (e) {
        debugPrint('Warning: Could not load games.json: $e');
        debugPrint('Game will continue without mini-games system.');
      }

      // Parse items into a map by ID
      final itemsMap = <String, dynamic>{};
      if (itemsData['items'] != null) {
        for (final itemJson in itemsData['items'] as List) {
          final itemId = itemJson['id'] as String;
          itemsMap[itemId] = itemJson;
        }
      }
      final newItemsByLocation = itemsData['_items_by_location'] as Map<String, dynamic>? ?? {};

      // Combine data into unified world structure
      final combinedData = <String, dynamic>{
        'map_metadata': mapData['map_metadata'],
        'regions': mapData['regions'],
        'locations': mapData['locations'],
        'connections': mapData['connections'],
        'starting_location': mapData['starting_location'],
        'npcs': npcsData['npcs'],
        'quest_lines': questsData['quest_lines'],
        'quests': questsData['quests'],
        'lore': loreData,
        'items': itemsMap,
        if (gamesData != null) ...{
          'games': gamesData['games'],
          '_games_by_location': gamesData['_games_by_location'],
          '_games_by_npc': gamesData['_games_by_npc'],
          '_games_by_quest': gamesData['_games_by_quest'],
        },
      };

      final world = GameWorld.fromJson(combinedData);

      // Load skill system data (with error handling so game can continue without it)
      SkillCollection? parsedSkills;
      TriggerCollection? parsedTriggers;
      LevelProgression? parsedLevelProgression;
      LevelProgressionService? parsedLevelProgressionService;

      if (skillsData != null && triggersData != null && levelProgressionData != null) {
        try {
          parsedSkills = SkillCollection.fromJson(skillsData);
          parsedTriggers = TriggerCollection.fromJson(triggersData);
          parsedLevelProgression = LevelProgression.fromJson(levelProgressionData);
          parsedLevelProgressionService = LevelProgressionService(parsedLevelProgression);
        } catch (e, stackTrace) {
          debugPrint('Warning: Failed to parse skill system data: $e');
          debugPrint('Stack trace: $stackTrace');
          debugPrint('Game will continue without skill progression system.');
          parsedSkills = null;
          parsedTriggers = null;
          parsedLevelProgression = null;
          parsedLevelProgressionService = null;
        }
      }

      state = state.copyWith(
        world: world,
        itemsByLocation: newItemsByLocation,
        skills: parsedSkills,
        triggers: parsedTriggers,
        levelProgression: parsedLevelProgression,
        levelProgressionService: parsedLevelProgressionService,
        isLoading: false,
        error: null,
      );

      // Load player progress from server (backend is source of truth)
      await _loadProgressFromServer();

      state = state.bump();
    } catch (e, stackTrace) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load game data: $e\n$stackTrace',
      );
      debugPrint(state.error);
    }
  }

  void createNewCharacter(String name) {
    if (state.world == null) return;

    final stats = PlayerStats();

    final player = Player(
      name: name,
      classId: 'learner',
      stats: stats,
      abilities: [],
      inventory: [],
      currentLocationId: state.world!.startingLocation,
      languageLevel: 'A0',
    );

    player.maxHealth = 100;
    player.health = player.maxHealth;
    player.maxMana = 50;
    player.mana = player.maxMana;

    // Initialize skill state (if skills are loaded)
    UserSkillState? newUserSkillState;
    if (state.skills != null) {
      newUserSkillState = UserSkillState.fromSkills(state.skills!);
    } else {
      debugPrint('Skills not loaded, skill system disabled');
    }

    final currentLocation = state.world!.locations[player.currentLocationId];

    final worldName = state.world!.lore?.worldName.target ?? 'the world';
    addToLog("Welcome, ${player.name}!");
    addToLog("Your language learning adventure in $worldName begins...");

    state = state.copyWith(
      player: player,
      userSkillState: newUserSkillState,
      currentLocation: currentLocation,
    );

    // Sync new character to server
    _syncProgressToServer();
  }

  // ============================================================================
  // SERVER SYNC METHODS
  // ============================================================================

  // TODO: populate KeycloakService.userName during login flow
  String get _playerName {
    try { return KeycloakService().userName; }
    catch (_) { return 'Player'; }
  }

  Future<void> _loadProgressFromServer() async {
    try {
      final response = await makeAuthenticatedRequest(
        endpoint: ApiEndpoints.getRpgProgress,
        body: {'action': 'get'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        _applyServerProgress(data);
        addToLog('Progress loaded from server.');
      } else if (response.statusCode == 404) {
        debugPrint('No server progress found, creating new character');
        createNewCharacter(_playerName);
      } else {
        debugPrint('Failed to load progress: ${response.statusCode}');
        createNewCharacter(_playerName);
      }
    } catch (e) {
      debugPrint('Error loading progress from server: $e');
      createNewCharacter(_playerName);
    }
  }

  void _applyServerProgress(Map<String, dynamic> data) {
    if (state.world == null) return;

    final stats = PlayerStats(
      strength: data['stats']?['strength'] as int? ?? 10,
      agility: data['stats']?['agility'] as int? ?? 10,
      intelligence: data['stats']?['intelligence'] as int? ?? 10,
      constitution: data['stats']?['constitution'] as int? ?? 10,
      charisma: data['stats']?['charisma'] as int? ?? 10,
      luck: data['stats']?['luck'] as int? ?? 10,
    );

    final player = Player(
      name: data['name'] as String? ?? _playerName,
      classId: data['class_id'] as String? ?? 'learner',
      stats: stats,
      abilities: List<String>.from(data['abilities'] as List? ?? []),
      inventory: List<String>.from(data['inventory'] as List? ?? []),
      currentLocationId: data['current_location_id'] as String? ?? state.world!.startingLocation,
      languageLevel: data['language_level'] as String? ?? 'A0',
    );

    player.level = data['level'] as int? ?? 1;
    player.xp = data['xp'] as int? ?? 0;
    player.gold = data['gold'] as int? ?? 0;
    player.health = data['health'] as int? ?? 100;
    player.maxHealth = data['max_health'] as int? ?? 100;
    player.mana = data['mana'] as int? ?? 50;
    player.maxMana = data['max_mana'] as int? ?? 50;
    player.equippedItems = List<String>.from(data['equipped_items'] as List? ?? []);
    player.activeQuests = List<String>.from(data['active_quests'] as List? ?? []);
    player.completedQuests = List<String>.from(data['completed_quests'] as List? ?? []);
    player.storyFlags = Set<String>.from(data['story_flags'] as List? ?? []);
    player.talkedToNPCs = Set<String>.from(data['talked_to_npcs'] as List? ?? []);
    player.learnedInfo = Set<String>.from(data['learned_info'] as List? ?? []);
    player.reputation = Map<String, int>.from(data['reputation'] as Map? ?? {});

    final newPickedUpItems = <String, Set<String>>{};
    final pickedUpData = data['picked_up_items'] as Map<String, dynamic>? ?? {};
    pickedUpData.forEach((locationId, items) {
      newPickedUpItems[locationId] = Set<String>.from(items as List);
    });

    // Initialize skill state
    UserSkillState? newUserSkillState;
    if (state.skills != null) {
      newUserSkillState = UserSkillState.fromSkills(state.skills!);
      final skillsData = data['skills'] as Map<String, dynamic>? ?? {};
      skillsData.forEach((skillId, level) {
        newUserSkillState!.skills[skillId] = level as int;
      });
    }

    final currentLocation = state.world!.locations[player.currentLocationId];

    final worldName = state.world!.lore?.worldName.target ?? 'the world';
    addToLog("Welcome back, ${player.name}!");
    addToLog("Your language learning adventure in $worldName continues...");

    state = state.copyWith(
      player: player,
      currentLocation: currentLocation,
      timeOfDay: data['time_of_day'] as String? ?? 'day',
      daysPassed: data['days_passed'] as int? ?? 0,
      pickedUpItems: newPickedUpItems,
      completedGames: Set<String>.from(data['completed_games'] as List? ?? []),
      givenItems: Set<String>.from(data['given_items'] as List? ?? []),
      userSkillState: newUserSkillState,
    );
  }

  Future<void> _syncProgressToServer() async {
    if (state.player == null) return;

    try {
      final p = state.player!;
      final data = {
        'action': 'update',
        'name': p.name,
        'class_id': p.classId,
        'level': p.level,
        'xp': p.xp,
        'gold': p.gold,
        'health': p.health,
        'max_health': p.maxHealth,
        'mana': p.mana,
        'max_mana': p.maxMana,
        'stats': {
          'strength': p.stats.strength,
          'agility': p.stats.agility,
          'intelligence': p.stats.intelligence,
          'constitution': p.stats.constitution,
          'charisma': p.stats.charisma,
          'luck': p.stats.luck,
        },
        'abilities': p.abilities,
        'inventory': p.inventory,
        'equipped_items': p.equippedItems.toList(),
        'current_location_id': p.currentLocationId,
        'language_level': p.languageLevel,
        'active_quests': p.activeQuests,
        'completed_quests': p.completedQuests,
        'story_flags': p.storyFlags.toList(),
        'talked_to_npcs': p.talkedToNPCs.toList(),
        'learned_info': p.learnedInfo.toList(),
        'reputation': p.reputation,
        'time_of_day': state.timeOfDay,
        'days_passed': state.daysPassed,
        'picked_up_items': state.pickedUpItems.map((k, v) => MapEntry(k, v.toList())),
        'completed_games': state.completedGames.toList(),
        'given_items': state.givenItems.toList(),
        'skills': state.userSkillState?.skills ?? {},
      };

      final response = await makeAuthenticatedRequest(
        endpoint: ApiEndpoints.setRpgProgress,
        body: data,
      );

      if (response.statusCode == 200) {
        debugPrint('Progress synced to server successfully');
      } else {
        debugPrint('Failed to sync progress: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error syncing progress to server: $e');
    }
  }

  void moveToLocation(String locationId) {
    if (state.world == null || state.player == null) return;

    final newLocation = state.world!.locations[locationId];
    if (newLocation == null) return;

    if (!state.meetsLanguageLevel(newLocation.minimumLanguageLevel)) {
      addToLog("You need to reach language level ${newLocation.minimumLanguageLevel} to visit ${newLocation.displayName}.");
      state = state.bump();
      return;
    }

    state.player!.currentLocationId = locationId;

    // Track location visit for quest progress
    recordAtLocation(locationId);

    // Find travel description if available
    String travelMsg = "You travel to ${newLocation.displayName}.";
    for (final conn in state.world!.connections) {
      if (conn.toLocation == state.currentLocation?.id && conn.fromLocation == locationId) {
        if (conn.travelDescription.isNotEmpty) {
          travelMsg = conn.displayTravelDescription;
        }
        break;
      }
    }
    addToLog(travelMsg);

    state = state.copyWith(
      currentLocation: newLocation,
      currentNPC: null,
      currentDialogue: null,
    );
    _syncProgressToServer();
  }

  void talkToNPC(String npcId) {
    if (state.world == null || state.player == null) return;

    final npc = state.world!.npcs[npcId];
    if (npc == null) return;

    // Record that we talked to this NPC (for quest tracking)
    recordTalkedTo(npcId);

    // Show NPC greeting
    if (npc.greeting.isNotEmpty) {
      addToLog("${npc.displayName}: \"${npc.displayGreeting}\"");
    } else {
      addToLog("You approach ${npc.displayName}.");
    }

    // Check active quests progress dialogue
    for (final questId in state.player!.activeQuests) {
      final quest = state.world!.quests[questId];
      if (quest != null && quest.giverNpcId == npcId) {
        if (quest.dialogue.questProgress.isNotEmpty && !quest.isCompleted) {
          addToLog("${npc.displayName}: \"${quest.dialogue.questProgress.native}\"");
        }
      }
    }

    state = state.copyWith(currentNPC: npc);
  }

  void selectDialogueOption(DialogueOption option) {
    if (state.currentNPC == null || state.world == null || state.player == null) return;

    // Apply effects
    if (option.effects != null) {
      _applyDialogueEffects(option.effects!);
    }

    // Handle action
    if (option.action != null) {
      switch (option.action) {
        case 'end':
          state = state.copyWith(currentDialogue: null, currentNPC: null);
          return;
        case 'shop':
          state = state.copyWith(currentDialogue: null);
          return;
        case 'quest':
          state = state.copyWith(currentDialogue: null);
          return;
      }
    } else if (option.nextId != null) {
      final nextDialogue = state.currentNPC!.dialogues
          .firstWhere((d) => d.id == option.nextId,
              orElse: () => state.currentNPC!.dialogues.first);
      state = state.copyWith(currentDialogue: nextDialogue);
    } else {
      state = state.copyWith(currentDialogue: null, currentNPC: null);
    }
  }

  void _applyDialogueEffects(Map<String, dynamic> effects) {
    if (state.player == null) return;

    if (effects.containsKey('xp')) {
      gainXP(effects['xp'] as int);
    }
    if (effects.containsKey('gold')) {
      state.player!.gold += effects['gold'] as int;
      addToLog("Gained ${effects['gold']} gold!");
    }
    if (effects.containsKey('item')) {
      state.player!.inventory.add(effects['item'] as String);
      addToLog("Received item: ${effects['item']}");
    }
    if (effects.containsKey('heal') && effects['heal'] == 'full') {
      state.player!.health = state.player!.maxHealth;
      state.player!.mana = state.player!.maxMana;
      addToLog("You have been fully healed!");
    }
    if (effects.containsKey('reputation')) {
      final repChanges = effects['reputation'] as Map<String, dynamic>;
      repChanges.forEach((faction, value) {
        state.player!.reputation[faction] =
            (state.player!.reputation[faction] ?? 0) + (value as int);
      });
    }
    if (effects.containsKey('addQuest')) {
      final questId = effects['addQuest'] as String;
      if (!state.player!.activeQuests.contains(questId)) {
        state.player!.activeQuests.add(questId);
        final quest = state.world?.quests[questId];
        if (quest != null) {
          addToLog("New Quest: ${quest.displayName}");
        }
      }
    }
    if (effects.containsKey('offerQuest')) {
      final questId = effects['offerQuest'] as String;
      if (!state.player!.activeQuests.contains(questId) &&
          !state.player!.completedQuests.contains(questId)) {
        offerQuest(questId);
      }
    }
  }

  void closeNPCInteraction() {
    if (state.currentNPC != null) {
      if (state.currentNPC!.farewell.isNotEmpty) {
        addToLog("${state.currentNPC!.displayName}: \"${state.currentNPC!.displayFarewell}\"");
      }
    }
    state = state.copyWith(currentNPC: null, currentDialogue: null);
  }

  void endDialogue() {
    closeNPCInteraction();
  }

  void buyItem(String itemId) {
    if (state.player == null || state.world == null) return;

    final item = state.world!.items[itemId];
    if (item == null) return;

    if (state.player!.gold >= item.value) {
      state.player!.gold -= item.value;
      state.player!.inventory.add(itemId);
      addToLog("Purchased ${item.displayName} for ${item.value} gold.");
      state = state.bump();
      _syncProgressToServer();
      checkAllQuestProgress();
    } else {
      addToLog("Not enough gold!");
      state = state.bump();
    }
  }

  void sellItem(String itemId) {
    if (state.player == null || state.world == null) return;

    final item = state.world!.items[itemId];
    if (item == null) return;

    final sellPrice = (item.value * 0.5).round();
    state.player!.gold += sellPrice;
    state.player!.inventory.remove(itemId);
    addToLog("Sold ${item.displayName} for $sellPrice gold.");
    state = state.bump();
    _syncProgressToServer();
  }

  void useItem(String itemId) {
    if (state.player == null || state.world == null) return;

    final item = state.world!.items[itemId];
    if (item == null) return;

    if (item.type == ItemType.consumable) {
      if (item.effects.containsKey('heal')) {
        final healAmount = item.effects['heal'] as int;
        state.player!.health = min(state.player!.health + healAmount, state.player!.maxHealth);
        addToLog("Used ${item.displayName}. Healed $healAmount HP!");
      }
      if (item.effects.containsKey('restoreMana')) {
        final manaAmount = item.effects['restoreMana'] as int;
        state.player!.mana = min(state.player!.mana + manaAmount, state.player!.maxMana);
        addToLog("Used ${item.displayName}. Restored $manaAmount MP!");
      }
      if (item.effects.containsKey('fullRest')) {
        state.player!.health = state.player!.maxHealth;
        state.player!.mana = state.player!.maxMana;
        advanceTime();
        addToLog("You rest and feel fully refreshed!");
      }
      state.player!.inventory.remove(itemId);
      state = state.bump();
      _syncProgressToServer();
    }
  }

  void equipItem(String itemId) {
    if (state.player == null) return;

    if (state.player!.equippedItems.contains(itemId)) {
      state.player!.equippedItems.remove(itemId);
      addToLog("Unequipped item.");
    } else {
      state.player!.equippedItems.add(itemId);
      addToLog("Equipped item.");
    }
    state = state.bump();
    _syncProgressToServer();
  }

  void gainXP(int amount) {
    if (state.player == null) return;

    state.player!.xp += amount;
    addToLog("Gained $amount XP!");

    while (state.player!.canLevelUp) {
      state.player!.xp -= state.player!.xpForNextLevel;
      state.player!.level++;

      state.player!.stats.strength++;
      state.player!.stats.agility++;
      state.player!.stats.intelligence++;
      state.player!.stats.constitution++;

      state.player!.maxHealth = 100 + (state.player!.stats.constitution * 5) + (state.player!.level * 10);
      state.player!.maxMana = 50 + (state.player!.stats.intelligence * 3) + (state.player!.level * 5);

      state.player!.health = state.player!.maxHealth;
      state.player!.mana = state.player!.maxMana;

      addToLog("LEVEL UP! You are now level ${state.player!.level}!");
    }

    state = state.bump();
    _syncProgressToServer();
  }

  void setLanguageLevel(String level) {
    if (state.player == null) return;
    state.player!.languageLevel = level;
    addToLog("Language proficiency updated to $level!");
    state = state.bump();
    _syncProgressToServer();
  }

  // ===========================================
  // SKILL PROGRESSION SYSTEM
  // ===========================================

  Future<void> processUserInput(String text) async {
    if (state.player == null ||
        state.userSkillState == null ||
        state.triggers == null ||
        state.levelProgressionService == null) {
      debugPrint('Skill system not initialized, skipping input processing');
      return;
    }

    if (text.trim().isEmpty) return;

    try {
      final grammarResult = await checkGrammar(text);

      TriggerEvaluator.processGrammarResult(grammarResult, state.userSkillState!);
      state.userSkillState!.incrementInteraction();

      final triggerResults = TriggerEvaluator.evaluateTriggers(
        userState: state.userSkillState!,
        triggers: state.triggers!,
        player: state.player!,
        grammarResult: grammarResult,
      );

      for (final result in triggerResults) {
        final skill = state.skills?.getById(result.skillId);
        final skillName = skill?.displayName ?? result.skillId;
        addToLog("[+${result.pointsAwarded}] $skillName");
      }

      final progressionCheck = state.levelProgressionService!.canAdvance(
        state.player!.languageLevel,
        state.userSkillState!.skills,
      );

      if (progressionCheck.canAdvance && progressionCheck.nextLevel != null) {
        final oldLevel = state.player!.languageLevel;
        state.player!.languageLevel = progressionCheck.nextLevel!;

        addToLog("=== LANGUAGE LEVEL UP! ===");
        addToLog("$oldLevel -> ${progressionCheck.nextLevel}");
        addToLog("==========================");

        ref.read(narratorProvider.notifier).onLanguageLevelUp(oldLevel, progressionCheck.nextLevel!);
      }

      state = state.bump();
    } catch (e, stackTrace) {
      debugPrint('Error processing user input: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  Skill? getSkill(String skillId) {
    return state.skills?.getById(skillId);
  }

  int getSkillLevel(String skillId) {
    return state.userSkillState?.skills[skillId] ?? 0;
  }

  Map<String, dynamic>? getLevelProgressDetails() {
    if (state.player == null ||
        state.userSkillState == null ||
        state.levelProgressionService == null) {
      return null;
    }
    return state.levelProgressionService!.getProgressDetails(
      state.player!.languageLevel,
      state.userSkillState!.skills,
    );
  }

  bool canAdvanceLevel() {
    if (state.player == null ||
        state.userSkillState == null ||
        state.levelProgressionService == null) {
      return false;
    }
    final check = state.levelProgressionService!.canAdvance(
      state.player!.languageLevel,
      state.userSkillState!.skills,
    );
    return check.canAdvance;
  }

  // ===========================================
  // QUEST PROGRESS POLLING SYSTEM
  // ===========================================

  bool _playerHasItem(String targetItemId) {
    if (state.player!.inventory.contains(targetItemId)) return true;
    for (final item in state.player!.inventory) {
      if (item == targetItemId) return true;
    }
    return false;
  }

  bool _itemWasGiven(String targetItemId) {
    if (state.givenItems.contains(targetItemId)) {
      debugPrint('    Direct match found!');
      return true;
    }
    for (final item in state.givenItems) {
      debugPrint('    Checking given item "$item" -> canonical "$item"');
      if (item == targetItemId) {
        debugPrint('    Alias match found! $item -> $targetItemId');
        return true;
      }
    }
    debugPrint('    No match found');
    return false;
  }

  void checkAllQuestProgress() {
    if (state.player == null || state.world == null) return;

    bool anyProgress = false;
    final questsToComplete = <String>[];
    final completedTasksInfo = <Map<String, dynamic>>[];

    for (final questId in List<String>.from(state.player!.activeQuests)) {
      final quest = state.world!.quests[questId];
      if (quest == null) {
        debugPrint('WARNING: Quest $questId not found in world!');
        continue;
      }

      debugPrint('Checking quest: ${quest.id} (${quest.displayName})');

      final sortedTasks = List<QuestTask>.from(quest.tasks)
        ..sort((a, b) => a.order.compareTo(b.order));

      for (final task in sortedTasks) {
        if (task.completed) continue;

        debugPrint('Checking task: ${task.id} (${task.completionType})');
        debugPrint('  Criteria: ${task.completionCriteria}');

        final isComplete = _checkTaskCompletion(task);
        debugPrint('  Result: $isComplete');

        if (isComplete) {
          task.completed = true;
          anyProgress = true;

          completedTasksInfo.add({
            'questId': questId,
            'questName': quest.displayName,
            'taskDescription': task.displayDescription,
            'completedTasks': quest.completedTaskCount,
            'totalTasks': quest.tasks.length,
          });

          addToLog("Task completed: ${task.displayDescription}");
          _applyTaskCompletionEffects(task.onComplete);

          if (quest.tasks.every((t) => t.completed)) {
            questsToComplete.add(questId);
          }
        }

        break;
      }
    }

    for (final info in completedTasksInfo) {
      final questId = info['questId'] as String;
      if (!questsToComplete.contains(questId)) {
        debugPrint('SENDING TASK NOTIFICATION: ${info['taskDescription']}');
        if (onQuestProgress != null) {
          onQuestProgress!(
            info['questName'] as String,
            info['taskDescription'] as String,
            info['completedTasks'] as int,
            info['totalTasks'] as int,
            false,
            null,
          );
        } else {
          debugPrint('WARNING: onQuestProgress callback is null!');
        }
      }
    }

    for (final questId in questsToComplete) {
      final quest = state.world!.quests[questId];
      if (quest != null) {
        final xp = quest.rewards.experience;
        completeQuest(questId);
        onQuestProgress?.call(
          quest.displayName,
          null,
          quest.tasks.length,
          quest.tasks.length,
          true,
          xp,
        );
      }
    }

    if (anyProgress) {
      state = state.bump();
    }
  }

  bool _checkTaskCompletion(QuestTask task) {
    if (state.player == null) return false;

    switch (task.completionType) {
      case 'at_location':
        final targetLocation = task.completionCriteria['target_id'] as String?;
        return targetLocation != null &&
            state.player!.currentLocationId == targetLocation;

      case 'has_item':
        final targetItem = task.completionCriteria['target_id'] as String?;
        if (targetItem == null) return false;
        return _playerHasItem(targetItem);

      case 'talked_to':
        final targetNpc = task.completionCriteria['target_id'] as String?;
        return targetNpc != null && state.player!.talkedToNPCs.contains(targetNpc);

      case 'gave_item':
        final targetItem = task.completionCriteria['target_id'] as String?;
        if (targetItem == null) return false;
        return _itemWasGiven(targetItem);

      case 'received_item':
        final targetItem = task.completionCriteria['target_id'] as String?;
        if (targetItem == null) return false;
        return _playerHasItem(targetItem) || _itemWasGiven(targetItem);

      case 'flag_set':
        final flagName = task.completionCriteria['flag_name'] as String?;
        return flagName != null && state.player!.storyFlags.contains(flagName);

      case 'learned_info':
        final targetId = task.completionCriteria['target_id'] as String?;
        final flagName = task.completionCriteria['flag_name'] as String?;
        if (targetId != null && state.player!.learnedInfo.contains(targetId)) return true;
        if (flagName != null && state.player!.storyFlags.contains(flagName)) return true;
        return false;

      case 'completed_game':
        final targetGame = task.completionCriteria['target_id'] as String?;
        return targetGame != null && state.completedGames.contains(targetGame);

      default:
        return false;
    }
  }

  void _applyTaskCompletionEffects(Map<String, dynamic> effects) {
    if (state.player == null) return;

    final flags = effects['set_flags'] as List?;
    if (flags != null) {
      for (final flag in flags) {
        state.player!.storyFlags.add(flag as String);
        addToLog("Story progress: $flag");
      }
    }

    final items = effects['give_items'] as List?;
    if (items != null) {
      for (final item in items) {
        state.player!.inventory.add(item as String);
        addToLog("Received: $item");
      }
    }

    final locations = effects['unlock_locations'] as List?;
    if (locations != null) {
      for (final loc in locations) {
        addToLog("New location unlocked: $loc");
      }
    }
  }

  // ===========================================
  // STATE CHANGE TRACKING METHODS
  // ===========================================

  void recordTalkedTo(String npcId) {
    if (state.player == null) return;
    state.player!.talkedToNPCs.add(npcId);
    checkAllQuestProgress();
  }

  void recordAtLocation(String locationId) {
    checkAllQuestProgress();
  }

  void recordReceivedItem(String itemId) {
    debugPrint('RECORDING RECEIVED ITEM: $itemId');
    debugPrint('Current inventory: ${state.player?.inventory}');
    checkAllQuestProgress();
  }

  void recordGaveItem(String itemId) {
    debugPrint('RECORDING GAVE ITEM: $itemId');
    state.givenItems.add(itemId);
    debugPrint('Given items now: ${state.givenItems}');
    checkAllQuestProgress();
  }

  void recordLearnedInfo(String infoId) {
    if (state.player == null) return;
    state.player!.learnedInfo.add(infoId);
    checkAllQuestProgress();
  }

  void setStoryFlag(String flag) {
    if (state.player == null) return;
    state.player!.storyFlags.add(flag);
    checkAllQuestProgress();
  }

  void updateQuestProgress(String completionType, String targetId) {
    checkAllQuestProgress();
  }

  void completeQuest(String questId) {
    if (state.player == null || state.world == null) return;

    final quest = state.world!.quests[questId];
    if (quest == null) return;

    if (state.player!.completedQuests.contains(questId)) return;

    state.player!.activeQuests.remove(questId);
    state.player!.completedQuests.add(questId);
    quest.isCompleted = true;

    addToLog("=== QUEST COMPLETE ===");
    addToLog(quest.displayName);

    if (quest.dialogue.questComplete.isNotEmpty) {
      addToLog("\"${quest.dialogue.questComplete.native}\"");
    }

    if (quest.rewards.experience > 0) {
      gainXP(quest.rewards.experience);
    }

    for (final itemId in quest.rewards.items) {
      state.player!.inventory.add(itemId);
      final item = state.world!.items[itemId];
      if (item != null) {
        addToLog("Received: ${item.displayName}");
      } else {
        addToLog("Received: $itemId");
      }
    }

    for (final flag in quest.rewards.storyFlags) {
      state.player!.storyFlags.add(flag);
    }

    for (final locationId in quest.rewards.unlocks.locations) {
      final location = state.world!.locations[locationId];
      if (location != null) {
        addToLog("New location unlocked: ${location.displayName}");
      }
    }

    for (final newQuestId in quest.rewards.unlocks.quests) {
      final newQuest = state.world!.quests[newQuestId];
      if (newQuest != null) {
        addToLog("New quest available: ${newQuest.displayName}");
      }
    }

    addToLog("=====================");

    ref.read(narratorProvider.notifier).onQuestComplete(quest);

    state = state.bump();
    _syncProgressToServer();
  }

  Quest? getQuest(String questId) {
    return state.world?.quests[questId];
  }

  bool canOfferQuest(String questId) {
    if (state.player == null || state.world == null) return false;

    final quest = state.world!.quests[questId];
    if (quest == null) return false;

    if (state.player!.activeQuests.contains(questId) ||
        state.player!.completedQuests.contains(questId)) {
      return false;
    }

    return quest.canUnlock(state.player!);
  }

  List<Quest> getQuestsForNPC(String npcId) {
    if (state.player == null || state.world == null) return [];

    return state.world!.quests.values
        .where((quest) =>
            quest.giverNpcId == npcId &&
            canOfferQuest(quest.id))
        .toList();
  }

  // ============================================================
  // Mini-Games System
  // ============================================================

  List<MiniGame> getGamesForNPC(String npcId) {
    if (state.world == null) return [];
    return state.world!.getGamesForNpc(npcId);
  }

  MiniGame? getGame(String gameId) {
    return state.world?.games[gameId];
  }

  void recordGameCompletion(String gameId, int exitCode) {
    if (state.player == null || state.world == null) return;

    final game = state.world!.games[gameId];
    if (game == null) return;

    state.completedGames.add(gameId);

    if (exitCode == 1 && game.skillPoints > 0) {
      state.player!.xp += game.skillPoints;
      addToLog('Earned ${game.skillPoints} XP from ${game.displayName}!');
    }

    checkAllQuestProgress();

    state = state.bump();
    _syncProgressToServer();
  }

  Map<String, dynamic>? getQuestProgress(String questId) {
    if (state.player == null || state.world == null) return null;

    final quest = state.world!.quests[questId];
    if (quest == null) return null;

    return {
      'quest': quest,
      'isActive': state.player!.activeQuests.contains(questId),
      'isCompleted': state.player!.completedQuests.contains(questId),
      'currentTaskIndex': quest.currentTaskIndex,
      'totalTasks': quest.tasks.length,
      'progress': quest.progress,
      'currentTask': quest.currentTask,
    };
  }

  void advanceTime() {
    if (state.timeOfDay == 'day') {
      state = state.copyWith(timeOfDay: 'evening');
    } else if (state.timeOfDay == 'evening') {
      state = state.copyWith(timeOfDay: 'night');
    } else {
      state = state.copyWith(timeOfDay: 'day', daysPassed: state.daysPassed + 1);
    }
    _syncProgressToServer();
  }

  void addToLog(String message) {
    state.gameLog.insert(0, message);
    if (state.gameLog.length > 100) {
      state.gameLog.removeLast();
    }
  }

  void clearLog() {
    state = state.copyWith(gameLog: []);
  }

  int getTotalEquippedStatBoost(String stat) {
    if (state.player == null || state.world == null) return 0;
    int total = 0;
    for (final itemId in state.player!.equippedItems) {
      final item = state.world!.items[itemId];
      if (item != null) {
        total += item.statBoosts[stat] ?? 0;
      }
    }
    return total;
  }

  int getEffectiveStat(String stat) {
    if (state.player == null) return 0;
    int base = 0;
    switch (stat) {
      case 'strength':
        base = state.player!.stats.strength;
        break;
      case 'agility':
        base = state.player!.stats.agility;
        break;
      case 'intelligence':
        base = state.player!.stats.intelligence;
        break;
      case 'charisma':
        base = state.player!.stats.charisma;
        break;
      case 'luck':
        base = state.player!.stats.luck;
        break;
      case 'constitution':
        base = state.player!.stats.constitution;
        break;
    }
    return base + getTotalEquippedStatBoost(stat);
  }

  List<Quest> getAvailableQuestsFromNPC(String npcId) {
    return getQuestsForNPC(npcId);
  }

  void offerQuest(String questId) {
    if (state.world == null) return;

    final quest = state.world!.quests[questId];
    if (quest == null) return;

    state = state.copyWith(pendingQuestOffer: quest);
  }

  void acceptQuest() {
    if (state.pendingQuestOffer == null || state.player == null) return;

    final quest = state.pendingQuestOffer!;
    if (!state.player!.activeQuests.contains(quest.id)) {
      state.player!.activeQuests.add(quest.id);
      addToLog("Quest Accepted: ${quest.displayName}");

      if (quest.dialogue.questAccept.isNotEmpty) {
        addToLog("\"${quest.dialogue.questAccept.native}\"");
      }
    }

    state = state.copyWith(pendingQuestOffer: null);
    _syncProgressToServer();

    checkAllQuestProgress();
  }

  void rejectQuest() {
    if (state.pendingQuestOffer == null) return;

    final quest = state.pendingQuestOffer!;
    addToLog("Quest Declined: ${quest.displayName}");

    if (quest.dialogue.questDecline.isNotEmpty) {
      addToLog("\"${quest.dialogue.questDecline.native}\"");
    }

    state = state.copyWith(pendingQuestOffer: null);
  }

  void clearQuestOffer() {
    state = state.copyWith(pendingQuestOffer: null);
  }

  // ===========================================
  // NPC INTERACTION SYSTEM
  // ===========================================

  NPCInteractionRequest? createItemRequest({
    required String npcId,
    required String npcName,
    required String itemId,
    required String itemName,
    String? reason,
  }) {
    if (state.player == null) return null;

    final hasItem = state.player!.inventory.contains(itemId);

    final interaction = NPCInteractionRequest.requestItem(
      npcId: npcId,
      npcName: npcName,
      itemId: itemId,
      itemName: itemName,
      reason: reason,
      playerHasItem: hasItem,
    );
    state = state.copyWith(pendingInteraction: interaction);
    return interaction;
  }

  NPCInteractionRequest? createSaleOffer({
    required String npcId,
    required String npcName,
    required String itemId,
    required String itemName,
    required int price,
    String? reason,
  }) {
    if (state.player == null) return null;

    final canAfford = state.player!.gold >= price;

    final interaction = NPCInteractionRequest.offerSale(
      npcId: npcId,
      npcName: npcName,
      itemId: itemId,
      itemName: itemName,
      price: price,
      reason: reason,
      playerCanAfford: canAfford,
    );
    state = state.copyWith(pendingInteraction: interaction);
    return interaction;
  }

  NPCInteractionRequest? createGiftOffer({
    required String npcId,
    required String npcName,
    required String itemId,
    required String itemName,
    String? reason,
  }) {
    if (state.player == null) return null;

    final interaction = NPCInteractionRequest.offerGift(
      npcId: npcId,
      npcName: npcName,
      itemId: itemId,
      itemName: itemName,
      reason: reason,
    );
    state = state.copyWith(pendingInteraction: interaction);
    return interaction;
  }

  NPCInteractionRequest? createTradeOffer({
    required String npcId,
    required String npcName,
    required String offeredItemId,
    required String offeredItemName,
    required String requestedItemId,
    required String requestedItemName,
    String? reason,
  }) {
    if (state.player == null) return null;

    final hasRequestedItem = state.player!.inventory.contains(requestedItemId);

    final interaction = NPCInteractionRequest.offerTrade(
      npcId: npcId,
      npcName: npcName,
      offeredItemId: offeredItemId,
      offeredItemName: offeredItemName,
      requestedItemId: requestedItemId,
      requestedItemName: requestedItemName,
      reason: reason,
      playerHasRequestedItem: hasRequestedItem,
    );
    state = state.copyWith(pendingInteraction: interaction);
    return interaction;
  }

  NPCInteractionResult acceptInteraction() {
    if (state.pendingInteraction == null || state.player == null) {
      return NPCInteractionResult.dismissed;
    }

    final interaction = state.pendingInteraction!;

    switch (interaction.type) {
      case NPCInteractionType.requestItem:
        if (interaction.playerHasItem == true && interaction.itemId != null) {
          state.player!.inventory.remove(interaction.itemId);
          addToLog("Gave ${interaction.itemName} to ${interaction.npcName}.");
          recordGaveItem(interaction.itemId!);
        }
        break;

      case NPCInteractionType.offerSale:
        if (interaction.playerCanAfford == true &&
            interaction.itemId != null &&
            interaction.price != null) {
          state.player!.gold -= interaction.price!;
          state.player!.inventory.add(interaction.itemId!);
          debugPrint('ITEM PURCHASED: ${interaction.itemId} added to inventory');
          debugPrint('Current inventory: ${state.player!.inventory}');
          addToLog(
              "Purchased ${interaction.itemName} for ${interaction.price} gold.");
          recordReceivedItem(interaction.itemId!);
        }
        break;

      case NPCInteractionType.offerGift:
        if (interaction.itemId != null) {
          state.player!.inventory.add(interaction.itemId!);
          addToLog("Received ${interaction.itemName} from ${interaction.npcName}.");
          recordReceivedItem(interaction.itemId!);
        }
        break;

      case NPCInteractionType.offerTrade:
        if (interaction.playerHasItem == true &&
            interaction.itemId != null &&
            interaction.requestedItemId != null) {
          state.player!.inventory.remove(interaction.requestedItemId);
          state.player!.inventory.add(interaction.itemId!);
          addToLog(
              "Traded ${interaction.requestedItemName} for ${interaction.itemName}.");
          recordGaveItem(interaction.requestedItemId!);
          recordReceivedItem(interaction.itemId!);
        }
        break;
    }

    state = state.copyWith(pendingInteraction: null);
    _syncProgressToServer();
    return NPCInteractionResult.accepted;
  }

  NPCInteractionResult declineInteraction() {
    if (state.pendingInteraction == null) {
      return NPCInteractionResult.dismissed;
    }

    final interaction = state.pendingInteraction!;

    switch (interaction.type) {
      case NPCInteractionType.requestItem:
        addToLog("Declined to give ${interaction.itemName} to ${interaction.npcName}.");
        break;
      case NPCInteractionType.offerSale:
        addToLog("Declined to buy ${interaction.itemName}.");
        break;
      case NPCInteractionType.offerGift:
        addToLog("Declined ${interaction.npcName}'s gift.");
        break;
      case NPCInteractionType.offerTrade:
        addToLog("Declined trade offer from ${interaction.npcName}.");
        break;
    }

    state = state.copyWith(pendingInteraction: null);
    return NPCInteractionResult.declined;
  }

  void dismissInteraction() {
    state = state.copyWith(pendingInteraction: null);
  }
}

// ============================================================================
// PROVIDER
// ============================================================================

final gameProvider = NotifierProvider<GameNotifier, GameState>(
  GameNotifier.new,
);

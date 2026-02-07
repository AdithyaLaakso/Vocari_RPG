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

class GameProvider extends ChangeNotifier {
  Player? _player;
  GameWorld? _world;
  Location? _currentLocation;
  NPC? _currentNPC;
  DialogueNode? _currentDialogue;
  final List<String> _gameLog = [];
  bool _isLoading = true;
  String? _error;
  String _timeOfDay = 'day';
  int _daysPassed = 0;
  Quest? _pendingQuestOffer;
  NPCInteractionRequest? _pendingInteraction;

  // Skill system data
  SkillCollection? _skills;
  TriggerCollection? _triggers;
  LevelProgression? _levelProgression;
  LevelProgressionService? _levelProgressionService;
  UserSkillState? _userSkillState;

  // Items by location (from items.json)
  Map<String, dynamic> _itemsByLocation = {};
  // Track picked up items per location (for respawning items, track which have been picked)
  final Map<String, Set<String>> _pickedUpItems = {};
  // Track completed mini-games
  final Set<String> _completedGames = {};

  // Display language toggle (for UI display, not stored on server)
  bool _showTargetLanguage = false; // Default to native for beginners

  // Getters
  Player? get player => _player;
  GameWorld? get world => _world;
  Location? get currentLocation => _currentLocation;
  NPC? get currentNPC => _currentNPC;
  DialogueNode? get currentDialogue => _currentDialogue;
  // Alias for currentDialogue
  DialogueNode? get currentDialogueNode => _currentDialogue;
  List<String> get gameLog => _gameLog;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get timeOfDay => _timeOfDay;
  int get daysPassed => _daysPassed;
  Quest? get pendingQuestOffer => _pendingQuestOffer;
  NPCInteractionRequest? get pendingInteraction => _pendingInteraction;

  // Skill system getters
  SkillCollection? get skills => _skills;
  TriggerCollection? get triggers => _triggers;
  LevelProgression? get levelProgression => _levelProgression;
  UserSkillState? get userSkillState => _userSkillState;
  Map<String, int> get skillLevels => _userSkillState?.skills ?? {};
  int get totalSkillPoints => _userSkillState?.totalSkillPoints ?? 0;
  bool get showTargetLanguage => _showTargetLanguage;

  /// Toggle between native and target language display
  void toggleDisplayLanguage() {
    _showTargetLanguage = !_showTargetLanguage;
    notifyListeners();
  }

  /// Check if player meets the minimum language level requirement
  bool meetsLanguageLevel(String requiredLevel) {
    if (_player == null || requiredLevel.isEmpty) return true;

    final levels = ['A0', 'A1', 'A2', 'B1', 'B2', 'C1', 'C2'];
    final playerIndex = levels.indexOf(_player!.languageLevel);
    final requiredIndex = levels.indexOf(requiredLevel);

    if (playerIndex == -1 || requiredIndex == -1) return true;

    return playerIndex >= requiredIndex;
  }

  List<Location> get connectedLocations {
    if (_currentLocation == null || _world == null) return [];
    return _currentLocation!.connectedLocations
        .map((id) => _world!.locations[id])
        .whereType<Location>()
        .toList();
  }

  List<NPC> get locationNPCs {
    if (_currentLocation == null || _world == null) return [];

    // Get NPCs assigned to this location
    final npcIds = <String>{};

    // Add NPCs from location's npc list
    npcIds.addAll(_currentLocation!.npcs);

    // Also find NPCs whose location_id matches this location
    for (final npc in _world!.npcs.values) {
      if (npc.locationId == _currentLocation!.id) {
        npcIds.add(npc.id);
      }
    }

    return npcIds
        .map((id) => _world!.npcs[id])
        .whereType<NPC>()
        .toList();
  }

  /// Get items available at the current location
  List<LocationItem> get locationItems {
    if (_currentLocation == null || _world == null) return [];

    final locationId = _currentLocation!.id;
    final itemIds = _itemsByLocation[locationId] as List<dynamic>? ?? [];
    final pickedUp = _pickedUpItems[locationId] ?? {};

    final items = <LocationItem>[];
    for (final itemId in itemIds) {
      final item = _world!.items[itemId];
      if (item == null) continue;

      // Check if item has been picked up and doesn't respawn
      final itemData = _getItemData(itemId);
      final respawns = itemData?['respawns'] ?? true;
      final alreadyPicked = pickedUp.contains(itemId);

      // Skip items that have been picked up and don't respawn
      if (alreadyPicked && !respawns) continue;

      // Check quantity available
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

  /// Get raw item data from items.json
  Map<String, dynamic>? _getItemData(String itemId) {
    // We need to find the item in the world's items
    // The item data includes location_id, acquisition_type, etc.
    if (_world?.items[itemId] != null) {
      // For now, we'll need to store this separately or access it from a different source
      // This is a simplified version - in production, you'd want to store the full item data
      return null;
    }
    return null;
  }

  /// Pick up an item at the current location
  void pickupItem(String itemId) {
    if (_player == null || _currentLocation == null || _world == null) return;

    final item = _world!.items[itemId];
    if (item == null) return;

    // Add to inventory
    _player!.inventory.add(itemId);

    // Mark as picked up at this location
    final locationId = _currentLocation!.id;
    _pickedUpItems.putIfAbsent(locationId, () => {});
    _pickedUpItems[locationId]!.add(itemId);

    addToLog("Picked up ${item.displayName}.");

    // Provide vocabulary hint via narrator if item has vocabulary word
    if (item.vocabularyWord != null) {
      NarratorService.instance.provideVocabularyHint(
        word: item.vocabularyWord!.target,
        translation: item.vocabularyWord!.native,
        context: 'You found this item: ${item.displayName}',
      );
    }

    // Track for quest progress
    recordReceivedItem(itemId);

    notifyListeners();
    _syncProgressToServer();
  }

  Future<void> loadGameData() async {
    try {
      _isLoading = true;
      notifyListeners();

      // Load core game data (required)
      final coreResults = await Future.wait([
        rootBundle.loadString('assets/data/map.json'),
        rootBundle.loadString('assets/data/npcs.json'),
        rootBundle.loadString('assets/data/quests.json'),
        rootBundle.loadString('assets/data/lore.json'),
        rootBundle.loadString('assets/data/items.json'),
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
          rootBundle.loadString('assets/data/skills.json'),
          rootBundle.loadString('assets/data/triggers.json'),
          rootBundle.loadString('assets/data/level_progression.json'),
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
        final gamesJson = await rootBundle.loadString('assets/data/games.json');
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
      _itemsByLocation = itemsData['_items_by_location'] as Map<String, dynamic>? ?? {};

      // Combine data into unified world structure
      final combinedData = <String, dynamic>{
        // Map data
        'map_metadata': mapData['map_metadata'],
        'regions': mapData['regions'],
        'locations': mapData['locations'],
        'connections': mapData['connections'],
        'starting_location': mapData['starting_location'],
        // NPCs data
        'npcs': npcsData['npcs'],
        // Quests data
        'quest_lines': questsData['quest_lines'],
        'quests': questsData['quests'],
        // Lore data
        'lore': loreData,
        // Items data
        'items': itemsMap,
        // Mini-games data (if available)
        if (gamesData != null) ...{
          'games': gamesData['games'],
          '_games_by_location': gamesData['_games_by_location'],
          '_games_by_npc': gamesData['_games_by_npc'],
          '_games_by_quest': gamesData['_games_by_quest'],
        },
      };

      _world = GameWorld.fromJson(combinedData);

      // Load skill system data (with error handling so game can continue without it)
      if (skillsData != null && triggersData != null && levelProgressionData != null) {
        try {
          _skills = SkillCollection.fromJson(skillsData);
          _triggers = TriggerCollection.fromJson(triggersData);
          _levelProgression = LevelProgression.fromJson(levelProgressionData);
          _levelProgressionService = LevelProgressionService(_levelProgression!);
        } catch (e, stackTrace) {
          debugPrint('Warning: Failed to parse skill system data: $e');
          debugPrint('Stack trace: $stackTrace');
          debugPrint('Game will continue without skill progression system.');
          // Reset to null so we know skill system is disabled
          _skills = null;
          _triggers = null;
          _levelProgression = null;
          _levelProgressionService = null;
        }
      }

      _isLoading = false;
      _error = null;

      // Load player progress from server (backend is source of truth)
      await _loadProgressFromServer();

      notifyListeners();
    } catch (e, stackTrace) {
      _isLoading = false;
      _error = 'Failed to load game data: $e\n$stackTrace';
      debugPrint(_error);
      notifyListeners();
    }
  }

  void createNewCharacter(String name) {
    if (_world == null) return;

    final stats = PlayerStats();

    _player = Player(
      name: name,
      classId: 'learner',
      stats: stats,
      abilities: [],
      inventory: [],
      currentLocationId: _world!.startingLocation,
      languageLevel: 'A0',
    );

    // Set health/mana
    _player!.maxHealth = 100;
    _player!.health = _player!.maxHealth;
    _player!.maxMana = 50;
    _player!.mana = _player!.maxMana;

    // Initialize skill state (if skills are loaded)
    if (_skills != null) {
      _userSkillState = UserSkillState.fromSkills(_skills!);
    } else {
      debugPrint('Skills not loaded, skill system disabled');
    }

    // Update language service with player's level


    _currentLocation = _world!.locations[_player!.currentLocationId];

    final worldName = _world!.lore?.worldName.target ?? 'the world';
    addToLog("Welcome, ${_player!.name}!");
    addToLog("Your language learning adventure in $worldName begins...");

    notifyListeners();

    // Sync new character to server
    _syncProgressToServer();
  }

  // ============================================================================
  // SERVER SYNC METHODS
  // ============================================================================

  /// Load player progress from server (backend is source of truth)
  Future<void> _loadProgressFromServer() async {
    try {
      final response = await makeAuthenticatedRequest(
        endpoint: ApiEndpoints.rpgProgress,
        body: {'action': 'get'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        _applyServerProgress(data);
        addToLog('Progress loaded from server.');
      } else if (response.statusCode == 404) {
        // No progress saved yet - create new character
        debugPrint('No server progress found, creating new character');
        final userName = KeycloakService().userName;
        createNewCharacter(userName);
      } else {
        debugPrint('Failed to load progress: ${response.statusCode}');
        // Fallback to new character
        final userName = KeycloakService().userName;
        createNewCharacter(userName);
      }
    } catch (e) {
      debugPrint('Error loading progress from server: $e');
      // Fallback to new character
      final userName = KeycloakService().userName;
      createNewCharacter(userName);
    }
  }

  /// Apply server progress data to current game state
  void _applyServerProgress(Map<String, dynamic> data) async {
    if (_world == null) return;

    final userName = KeycloakService().userName;

    final stats = PlayerStats(
      strength: data['stats']?['strength'] as int? ?? 10,
      agility: data['stats']?['agility'] as int? ?? 10,
      intelligence: data['stats']?['intelligence'] as int? ?? 10,
      constitution: data['stats']?['constitution'] as int? ?? 10,
      charisma: data['stats']?['charisma'] as int? ?? 10,
      luck: data['stats']?['luck'] as int? ?? 10,
    );

    _player = Player(
      name: data['name'] as String? ?? userName,
      classId: data['class_id'] as String? ?? 'learner',
      stats: stats,
      abilities: List<String>.from(data['abilities'] as List? ?? []),
      inventory: List<String>.from(data['inventory'] as List? ?? []),
      currentLocationId: data['current_location_id'] as String? ?? _world!.startingLocation,
      languageLevel: data['language_level'] as String? ?? 'A0',
    );

    _player!.level = data['level'] as int? ?? 1;
    _player!.xp = data['xp'] as int? ?? 0;
    _player!.gold = data['gold'] as int? ?? 0;
    _player!.health = data['health'] as int? ?? 100;
    _player!.maxHealth = data['max_health'] as int? ?? 100;
    _player!.mana = data['mana'] as int? ?? 50;
    _player!.maxMana = data['max_mana'] as int? ?? 50;
    _player!.equippedItems = List<String>.from(data['equipped_items'] as List? ?? []);
    _player!.activeQuests = List<String>.from(data['active_quests'] as List? ?? []);
    _player!.completedQuests = List<String>.from(data['completed_quests'] as List? ?? []);
    _player!.storyFlags = Set<String>.from(data['story_flags'] as List? ?? []);
    _player!.talkedToNPCs = Set<String>.from(data['talked_to_npcs'] as List? ?? []);
    _player!.learnedInfo = Set<String>.from(data['learned_info'] as List? ?? []);
    _player!.reputation = Map<String, int>.from(data['reputation'] as Map? ?? {});

    _timeOfDay = data['time_of_day'] as String? ?? 'day';
    _daysPassed = data['days_passed'] as int? ?? 0;
    _pickedUpItems.clear();
    final pickedUpData = data['picked_up_items'] as Map<String, dynamic>? ?? {};
    pickedUpData.forEach((locationId, items) {
      _pickedUpItems[locationId] = Set<String>.from(items as List);
    });
    _completedGames.clear();
    _completedGames.addAll(Set<String>.from(data['completed_games'] as List? ?? []));
    _givenItems.clear();
    _givenItems.addAll(Set<String>.from(data['given_items'] as List? ?? []));

    // Initialize skill state
    if (_skills != null) {
      _userSkillState = UserSkillState.fromSkills(_skills!);
      final skillsData = data['skills'] as Map<String, dynamic>? ?? {};
      skillsData.forEach((skillId, level) {
        _userSkillState!.skills[skillId] = level as int;
      });
    }

    // Update language service


    // Set current location
    _currentLocation = _world!.locations[_player!.currentLocationId];

    final worldName = _world!.lore?.worldName.target ?? 'the world';
    addToLog("Welcome back, ${_player!.name}!");
    addToLog("Your language learning adventure in $worldName continues...");
  }

  /// Sync current player progress to server
  Future<void> _syncProgressToServer() async {
    if (_player == null) return;

    try {
      final data = {
        'action': 'update',
        'name': _player!.name,
        'class_id': _player!.classId,
        'level': _player!.level,
        'xp': _player!.xp,
        'gold': _player!.gold,
        'health': _player!.health,
        'max_health': _player!.maxHealth,
        'mana': _player!.mana,
        'max_mana': _player!.maxMana,
        'stats': {
          'strength': _player!.stats.strength,
          'agility': _player!.stats.agility,
          'intelligence': _player!.stats.intelligence,
          'constitution': _player!.stats.constitution,
          'charisma': _player!.stats.charisma,
          'luck': _player!.stats.luck,
        },
        'abilities': _player!.abilities,
        'inventory': _player!.inventory,
        'equipped_items': _player!.equippedItems.toList(),
        'current_location_id': _player!.currentLocationId,
        'language_level': _player!.languageLevel,
        'active_quests': _player!.activeQuests,
        'completed_quests': _player!.completedQuests,
        'story_flags': _player!.storyFlags.toList(),
        'talked_to_npcs': _player!.talkedToNPCs.toList(),
        'learned_info': _player!.learnedInfo.toList(),
        'reputation': _player!.reputation,
        'time_of_day': _timeOfDay,
        'days_passed': _daysPassed,
        'picked_up_items': _pickedUpItems.map((k, v) => MapEntry(k, v.toList())),
        'completed_games': _completedGames.toList(),
        'given_items': _givenItems.toList(),
        'skills': _userSkillState?.skills ?? {},
      };

      final response = await makeAuthenticatedRequest(
        endpoint: ApiEndpoints.rpgProgress,
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
    if (_world == null || _player == null) return;

    final newLocation = _world!.locations[locationId];
    if (newLocation == null) return;

    // Check if player meets language level requirements
    if (!meetsLanguageLevel(newLocation.minimumLanguageLevel)) {
      addToLog("You need to reach language level ${newLocation.minimumLanguageLevel} to visit ${newLocation.displayName}.");
      return;
    }

    _player!.currentLocationId = locationId;
    _currentLocation = newLocation;
    _currentNPC = null;
    _currentDialogue = null;

    // Track location visit for quest progress
    recordAtLocation(locationId);

    // Find travel description if available
    String travelMsg = "You travel to ${newLocation.displayName}.";
    for (final conn in _world!.connections) {
      if (conn.toLocation == _currentLocation?.id && conn.fromLocation == locationId) {
        if (conn.travelDescription.isNotEmpty) {
          travelMsg = conn.displayTravelDescription;
        }
        break;
      }
    }
    addToLog(travelMsg);

    notifyListeners();
    _syncProgressToServer();
  }

  void talkToNPC(String npcId) {
    if (_world == null || _player == null) return;

    final npc = _world!.npcs[npcId];
    if (npc == null) return;

    _currentNPC = npc;

    // Record that we talked to this NPC (for quest tracking)
    recordTalkedTo(npcId);

    // Show NPC greeting
    if (npc.greeting.isNotEmpty) {
      addToLog("${npc.displayName}: \"${npc.displayGreeting}\"");
    } else {
      addToLog("You approach ${npc.displayName}.");
    }

    // Check active quests progress dialogue
    for (final questId in _player!.activeQuests) {
      final quest = _world!.quests[questId];
      if (quest != null && quest.giverNpcId == npcId) {
        if (quest.dialogue.questProgress.isNotEmpty && !quest.isCompleted) {
          addToLog("${npc.displayName}: \"${quest.dialogue.questProgress.native}\"");
        }
      }
    }

    notifyListeners();
  }

  void selectDialogueOption(DialogueOption option) {
    if (_currentNPC == null || _world == null || _player == null) return;

    // Apply effects
    if (option.effects != null) {
      _applyDialogueEffects(option.effects!);
    }

    // Handle action
    if (option.action != null) {
      switch (option.action) {
        case 'end':
          _currentDialogue = null;
          _currentNPC = null;
          break;
        case 'shop':
          // Keep NPC for shop interface
          _currentDialogue = null;
          break;
        case 'quest':
          // Quest logic handled in effects
          _currentDialogue = null;
          break;
      }
    } else if (option.nextId != null) {
      // Find next dialogue node
      final nextDialogue = _currentNPC!.dialogues
          .firstWhere((d) => d.id == option.nextId,
              orElse: () => _currentNPC!.dialogues.first);
      _currentDialogue = nextDialogue;
    } else {
      _currentDialogue = null;
      _currentNPC = null;
    }

    notifyListeners();
  }

  void _applyDialogueEffects(Map<String, dynamic> effects) {
    if (_player == null) return;

    if (effects.containsKey('xp')) {
      gainXP(effects['xp'] as int);
    }
    if (effects.containsKey('gold')) {
      _player!.gold += effects['gold'] as int;
      addToLog("Gained ${effects['gold']} gold!");
    }
    if (effects.containsKey('item')) {
      _player!.inventory.add(effects['item'] as String);
      addToLog("Received item: ${effects['item']}");
    }
    if (effects.containsKey('heal') && effects['heal'] == 'full') {
      _player!.health = _player!.maxHealth;
      _player!.mana = _player!.maxMana;
      addToLog("You have been fully healed!");
    }
    if (effects.containsKey('reputation')) {
      final repChanges = effects['reputation'] as Map<String, dynamic>;
      repChanges.forEach((faction, value) {
        _player!.reputation[faction] =
            (_player!.reputation[faction] ?? 0) + (value as int);
      });
    }
    if (effects.containsKey('addQuest')) {
      final questId = effects['addQuest'] as String;
      if (!_player!.activeQuests.contains(questId)) {
        _player!.activeQuests.add(questId);
        final quest = _world?.quests[questId];
        if (quest != null) {
          addToLog("New Quest: ${quest.displayName}");
        }
      }
    }
    if (effects.containsKey('offerQuest')) {
      final questId = effects['offerQuest'] as String;
      if (!_player!.activeQuests.contains(questId) &&
          !_player!.completedQuests.contains(questId)) {
        offerQuest(questId);
      }
    }
  }

  void closeNPCInteraction() {
    if (_currentNPC != null) {
      // Show farewell if available
      if (_currentNPC!.farewell.isNotEmpty) {
        addToLog("${_currentNPC!.displayName}: \"${_currentNPC!.displayFarewell}\"");
      }
    }
    _currentNPC = null;
    _currentDialogue = null;
    notifyListeners();
  }

  // End dialogue (alias for closeNPCInteraction)
  void endDialogue() {
    closeNPCInteraction();
  }

  void buyItem(String itemId) {
    if (_player == null || _world == null) return;

    final item = _world!.items[itemId];
    if (item == null) return;

    if (_player!.gold >= item.value) {
      _player!.gold -= item.value;
      _player!.inventory.add(itemId);
      addToLog("Purchased ${item.displayName} for ${item.value} gold.");
      notifyListeners();
      _syncProgressToServer();
      // Check quest progress after inventory change
      checkAllQuestProgress();
    } else {
      addToLog("Not enough gold!");
    }
  }

  void sellItem(String itemId) {
    if (_player == null || _world == null) return;

    final item = _world!.items[itemId];
    if (item == null) return;

    final sellPrice = (item.value * 0.5).round();
    _player!.gold += sellPrice;
    _player!.inventory.remove(itemId);
    addToLog("Sold ${item.displayName} for $sellPrice gold.");
    notifyListeners();
    _syncProgressToServer();
  }

  void useItem(String itemId) {
    if (_player == null || _world == null) return;

    final item = _world!.items[itemId];
    if (item == null) return;

    if (item.type == ItemType.consumable) {
      if (item.effects.containsKey('heal')) {
        final healAmount = item.effects['heal'] as int;
        _player!.health = min(_player!.health + healAmount, _player!.maxHealth);
        addToLog("Used ${item.displayName}. Healed $healAmount HP!");
      }
      if (item.effects.containsKey('restoreMana')) {
        final manaAmount = item.effects['restoreMana'] as int;
        _player!.mana = min(_player!.mana + manaAmount, _player!.maxMana);
        addToLog("Used ${item.displayName}. Restored $manaAmount MP!");
      }
      if (item.effects.containsKey('fullRest')) {
        _player!.health = _player!.maxHealth;
        _player!.mana = _player!.maxMana;
        advanceTime();
        addToLog("You rest and feel fully refreshed!");
      }
      _player!.inventory.remove(itemId);
      notifyListeners();
      _syncProgressToServer();
    }
  }

  void equipItem(String itemId) {
    if (_player == null) return;

    if (_player!.equippedItems.contains(itemId)) {
      _player!.equippedItems.remove(itemId);
      addToLog("Unequipped item.");
    } else {
      _player!.equippedItems.add(itemId);
      addToLog("Equipped item.");
    }
    notifyListeners();
    _syncProgressToServer();
  }

  void gainXP(int amount) {
    if (_player == null) return;

    _player!.xp += amount;
    addToLog("Gained $amount XP!");

    // Check for level up
    while (_player!.canLevelUp) {
      _player!.xp -= _player!.xpForNextLevel;
      _player!.level++;

      // Stat increases on level up
      _player!.stats.strength++;
      _player!.stats.agility++;
      _player!.stats.intelligence++;
      _player!.stats.constitution++;

      // Recalculate max health/mana
      _player!.maxHealth = 100 + (_player!.stats.constitution * 5) + (_player!.level * 10);
      _player!.maxMana = 50 + (_player!.stats.intelligence * 3) + (_player!.level * 5);

      // Heal on level up
      _player!.health = _player!.maxHealth;
      _player!.mana = _player!.maxMana;

      addToLog("LEVEL UP! You are now level ${_player!.level}!");
    }

    notifyListeners();
    _syncProgressToServer();
  }

  // Update player's language level
  void setLanguageLevel(String level) {
    if (_player == null) return;
    _player!.languageLevel = level;

    addToLog("Language proficiency updated to $level!");
    notifyListeners();
    _syncProgressToServer();
  }

  // ===========================================
  // SKILL PROGRESSION SYSTEM
  // ===========================================

  /// Process user input through grammar checker and update skill progression
  Future<void> processUserInput(String text) async {
    if (_player == null ||
        _userSkillState == null ||
        _triggers == null ||
        _levelProgressionService == null) {
      debugPrint('Skill system not initialized, skipping input processing');
      return;
    }

    if (text.trim().isEmpty) {
      return;
    }

    try {
      // 1. Check grammar and extract language learning metrics
      final grammarResult = await checkGrammar(text);

      // 2. Update usage counters from grammar result
      TriggerEvaluator.processGrammarResult(grammarResult, _userSkillState!);

      // 3. Increment interaction counter (for cooldowns)
      _userSkillState!.incrementInteraction();

      // 4. Evaluate triggers and award skill points
      final triggerResults = TriggerEvaluator.evaluateTriggers(
        userState: _userSkillState!,
        triggers: _triggers!,
        player: _player!,
        grammarResult: grammarResult,
      );

      // 5. Log skill point awards
      for (final result in triggerResults) {
        final skill = _skills?.getById(result.skillId);
        final skillName = skill?.displayName ?? result.skillId;
        addToLog("[+${result.pointsAwarded}] $skillName");
      }

      // 6. Check level progression
      final progressionCheck = _levelProgressionService!.canAdvance(
        _player!.languageLevel,
        _userSkillState!.skills,
      );

      if (progressionCheck.canAdvance && progressionCheck.nextLevel != null) {
        // Level up!
        final oldLevel = _player!.languageLevel;
        _player!.languageLevel = progressionCheck.nextLevel!;


        addToLog("=== LANGUAGE LEVEL UP! ===");
        addToLog("$oldLevel -> ${progressionCheck.nextLevel}");
        addToLog("==========================");

        // Notify narrator about language level up
        NarratorService.instance.onLanguageLevelUp(oldLevel, progressionCheck.nextLevel!);
      }

      notifyListeners();
    } catch (e, stackTrace) {
      debugPrint('Error processing user input: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  /// Get skill by ID
  Skill? getSkill(String skillId) {
    return _skills?.getById(skillId);
  }

  /// Get skill level
  int getSkillLevel(String skillId) {
    return _userSkillState?.skills[skillId] ?? 0;
  }

  /// Get progress details for current level
  Map<String, dynamic>? getLevelProgressDetails() {
    if (_player == null ||
        _userSkillState == null ||
        _levelProgressionService == null) {
      return null;
    }

    return _levelProgressionService!.getProgressDetails(
      _player!.languageLevel,
      _userSkillState!.skills,
    );
  }

  /// Check if player can advance to next level
  bool canAdvanceLevel() {
    if (_player == null ||
        _userSkillState == null ||
        _levelProgressionService == null) {
      return false;
    }

    final check = _levelProgressionService!.canAdvance(
      _player!.languageLevel,
      _userSkillState!.skills,
    );

    return check.canAdvance;
  }

  // ===========================================
  // QUEST PROGRESS POLLING SYSTEM
  // ===========================================
  // Comprehensive state-based quest tracking that polls all conditions
  // whenever game state changes.

  /// Callback for quest progress notifications
  /// Called with (questName, taskDescription, completedTasks, totalTasks, isQuestComplete, xpReward)
  void Function(String questName, String? taskDescription, int completedTasks,
      int totalTasks, bool isQuestComplete, int? xpReward)? onQuestProgress;

  /// Track items that were given to NPCs (item_id -> true)
  final Set<String> _givenItems = {};

  /// Check if player has an item (handles aliases)
  bool _playerHasItem(String targetItemId) {
    // Direct check
    if (_player!.inventory.contains(targetItemId)) {
      return true;
    }

    // Check if any inventory item maps to the target via alias
    for (final item in _player!.inventory) {
      if (item == targetItemId) {
        return true;
      }
    }

    return false;
  }

  /// Check if an item was given (handles aliases)
  bool _itemWasGiven(String targetItemId) {
    // Direct check
    if (_givenItems.contains(targetItemId)) {
      debugPrint('    Direct match found!');
      return true;
    }

    // Check if any given item maps to the target via alias
    for (final item in _givenItems) {
      debugPrint('    Checking given item "$item" -> canonical "$item"');
      if (item == targetItemId) {
        debugPrint('    Alias match found! $item -> $targetItemId');
        return true;
      }
    }

    debugPrint('    No match found');
    return false;
  }

  /// Check all quest progress by polling current state
  /// This is the main method that should be called after any state change
  void checkAllQuestProgress() {
    if (_player == null || _world == null) return;

    bool anyProgress = false;
    final questsToComplete = <String>[];
    final completedTasksInfo = <Map<String, dynamic>>[];

    for (final questId in List<String>.from(_player!.activeQuests)) {
      final quest = _world!.quests[questId];
      if (quest == null) {
        debugPrint('WARNING: Quest $questId not found in world!');
        continue;
      }

      debugPrint('Checking quest: ${quest.id} (${quest.displayName})');

      // Sort tasks by order to ensure we check them sequentially
      final sortedTasks = List<QuestTask>.from(quest.tasks)
        ..sort((a, b) => a.order.compareTo(b.order));

      for (final task in sortedTasks) {
        // Only process the current (first incomplete) task
        if (task.completed) continue;

        debugPrint('Checking task: ${task.id} (${task.completionType})');
        debugPrint('  Criteria: ${task.completionCriteria}');

        // Check if this task's condition is met
        final isComplete = _checkTaskCompletion(task);
        debugPrint('  Result: $isComplete');

        if (isComplete) {
          task.completed = true;
          anyProgress = true;

          // Store task info for notification
          completedTasksInfo.add({
            'questId': questId,
            'questName': quest.displayName,
            'taskDescription': task.displayDescription,
            'completedTasks': quest.completedTaskCount,
            'totalTasks': quest.tasks.length,
          });

          addToLog("Task completed: ${task.displayDescription}");

          // Apply on_complete effects
          _applyTaskCompletionEffects(task.onComplete);

          // Check if quest is now complete (all tasks done)
          if (quest.tasks.every((t) => t.completed)) {
            questsToComplete.add(questId);
          }
        }

        // Only process the first incomplete task per quest
        break;
      }
    }

    // Send notifications for completed tasks (that aren't part of completed quests)
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

    // Complete any finished quests
    for (final questId in questsToComplete) {
      final quest = _world!.quests[questId];
      if (quest != null) {
        final xp = quest.rewards.experience;
        completeQuest(questId);
        // Send quest complete notification
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
      notifyListeners();
    }
  }

  /// Check if a specific task's completion condition is met
  bool _checkTaskCompletion(QuestTask task) {
    if (_player == null) return false;

    switch (task.completionType) {
      case 'at_location':
        // Check if player is at the target location
        final targetLocation = task.completionCriteria['target_id'] as String?;
        final result = targetLocation != null &&
            _player!.currentLocationId == targetLocation;
        return result;

      case 'has_item':
        // Check if player has the item in inventory (with alias support)
        final targetItem = task.completionCriteria['target_id'] as String?;
        if (targetItem == null) return false;
        final result = _playerHasItem(targetItem);
        return result;

      case 'talked_to':
        // Check if player has talked to the NPC
        final targetNpc = task.completionCriteria['target_id'] as String?;
        return targetNpc != null && _player!.talkedToNPCs.contains(targetNpc);

      case 'gave_item':
        // Check if player has given the specific item (with alias support)
        final targetItem = task.completionCriteria['target_id'] as String?;
        if (targetItem == null) return false;
        final result = _itemWasGiven(targetItem);
        return result;

      case 'received_item':
        // Check if player has received the specific item (with alias support)
        final targetItem = task.completionCriteria['target_id'] as String?;
        if (targetItem == null) return false;
        final result = _playerHasItem(targetItem) || _itemWasGiven(targetItem);
        return result;

      case 'flag_set':
        // Check if a story flag is set
        final flagName = task.completionCriteria['flag_name'] as String?;
        return flagName != null && _player!.storyFlags.contains(flagName);

      case 'learned_info':
        // Check if player has learned specific info
        // Can check either target_id or flag_name
        final targetId = task.completionCriteria['target_id'] as String?;
        final flagName = task.completionCriteria['flag_name'] as String?;
        if (targetId != null && _player!.learnedInfo.contains(targetId)) {
          return true;
        }
        if (flagName != null && _player!.storyFlags.contains(flagName)) {
          return true;
        }
        return false;

      case 'completed_game':
        // Check if player has completed the specified mini-game
        final targetGame = task.completionCriteria['target_id'] as String?;
        return targetGame != null && _completedGames.contains(targetGame);

      default:
        return false;
    }
  }

  /// Apply effects when a task is completed
  void _applyTaskCompletionEffects(Map<String, dynamic> effects) {
    if (_player == null) return;

    // Set story flags
    final flags = effects['set_flags'] as List?;
    if (flags != null) {
      for (final flag in flags) {
        _player!.storyFlags.add(flag as String);
        addToLog("Story progress: $flag");
      }
    }

    // Give items
    final items = effects['give_items'] as List?;
    if (items != null) {
      for (final item in items) {
        _player!.inventory.add(item as String);
        addToLog("Received: $item");
      }
    }

    // Unlock locations
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
  // These methods record state changes and trigger quest progress polling

  /// Mark that player talked to an NPC
  void recordTalkedTo(String npcId) {
    if (_player == null) return;
    _player!.talkedToNPCs.add(npcId);
    checkAllQuestProgress();
  }

  /// Mark that player is at a location (called automatically when moving)
  void recordAtLocation(String locationId) {
    checkAllQuestProgress();
  }

  /// Mark that player received an item
  void recordReceivedItem(String itemId) {
    debugPrint('RECORDING RECEIVED ITEM: $itemId');
    debugPrint('Current inventory: ${_player?.inventory}');
    // The item should already be in inventory when this is called
    checkAllQuestProgress();
  }

  /// Mark that player gave an item to an NPC
  void recordGaveItem(String itemId) {
    debugPrint('RECORDING GAVE ITEM: $itemId');
    _givenItems.add(itemId);
    debugPrint('Given items now: $_givenItems');
    checkAllQuestProgress();
  }

  /// Mark that player learned some info
  void recordLearnedInfo(String infoId) {
    if (_player == null) return;
    _player!.learnedInfo.add(infoId);
    checkAllQuestProgress();
  }

  /// Set a story flag
  void setStoryFlag(String flag) {
    if (_player == null) return;
    _player!.storyFlags.add(flag);
    checkAllQuestProgress();
  }

  // Legacy method - now just triggers polling
  void updateQuestProgress(String completionType, String targetId) {
    checkAllQuestProgress();
  }

  void completeQuest(String questId) {
    if (_player == null || _world == null) return;

    final quest = _world!.quests[questId];
    if (quest == null) return;

    // Don't complete if already completed
    if (_player!.completedQuests.contains(questId)) return;

    _player!.activeQuests.remove(questId);
    _player!.completedQuests.add(questId);
    quest.isCompleted = true;

    addToLog("=== QUEST COMPLETE ===");
    addToLog(quest.displayName);

    // Show completion dialogue if available
    if (quest.dialogue.questComplete.isNotEmpty) {
      addToLog("\"${quest.dialogue.questComplete.native}\"");
    }

    // Award experience
    if (quest.rewards.experience > 0) {
      gainXP(quest.rewards.experience);
    }

    // Award items
    for (final itemId in quest.rewards.items) {
      _player!.inventory.add(itemId);
      final item = _world!.items[itemId];
      if (item != null) {
        addToLog("Received: ${item.displayName}");
      } else {
        addToLog("Received: $itemId");
      }
    }

    // Set story flags from rewards
    for (final flag in quest.rewards.storyFlags) {
      _player!.storyFlags.add(flag);
    }

    // Unlock new locations
    for (final locationId in quest.rewards.unlocks.locations) {
      final location = _world!.locations[locationId];
      if (location != null) {
        addToLog("New location unlocked: ${location.displayName}");
      }
    }

    // Unlock new quests
    for (final newQuestId in quest.rewards.unlocks.quests) {
      final newQuest = _world!.quests[newQuestId];
      if (newQuest != null) {
        addToLog("New quest available: ${newQuest.displayName}");
      }
    }

    addToLog("=====================");

    // Notify narrator about quest completion
    NarratorService.instance.onQuestComplete(quest);

    notifyListeners();
    _syncProgressToServer();
  }

  /// Get active quest details for display
  List<Quest> get activeQuests {
    if (_player == null || _world == null) return [];
    return _player!.activeQuests
        .map((id) => _world!.quests[id])
        .whereType<Quest>()
        .toList();
  }

  /// Get a specific quest by ID
  Quest? getQuest(String questId) {
    return _world?.quests[questId];
  }

  /// Check if a quest can be offered (meets unlock requirements)
  bool canOfferQuest(String questId) {
    if (_player == null || _world == null) return false;

    final quest = _world!.quests[questId];
    if (quest == null) return false;

    // Already active or completed
    if (_player!.activeQuests.contains(questId) ||
        _player!.completedQuests.contains(questId)) {
      return false;
    }

    return quest.canUnlock(_player!);
  }

  /// Get quests that an NPC can offer
  List<Quest> getQuestsForNPC(String npcId) {
    if (_player == null || _world == null) return [];

    return _world!.quests.values
        .where((quest) =>
            quest.giverNpcId == npcId &&
            canOfferQuest(quest.id))
        .toList();
  }

  // ============================================================
  // Mini-Games System
  // ============================================================

  /// Get set of completed game IDs
  Set<String> get completedGames => Set.unmodifiable(_completedGames);

  /// Check if a specific game has been completed
  bool isGameCompleted(String gameId) => _completedGames.contains(gameId);

  /// Get mini-games available at the current location
  List<MiniGame> get locationGames {
    if (_currentLocation == null || _world == null) return [];
    return _world!.getGamesForLocation(_currentLocation!.id);
  }

  /// Get mini-games offered by a specific NPC
  List<MiniGame> getGamesForNPC(String npcId) {
    if (_world == null) return [];
    return _world!.getGamesForNpc(npcId);
  }

  /// Get a specific mini-game by ID
  MiniGame? getGame(String gameId) {
    return _world?.games[gameId];
  }

  /// Record completion of a mini-game
  /// exitCode: 0 = error, 1 = success, 2 = unsuccessful
  void recordGameCompletion(String gameId, int exitCode) {
    if (_player == null || _world == null) return;

    final game = _world!.games[gameId];
    if (game == null) return;

    // Mark game as completed (regardless of success/failure for quest purposes)
    _completedGames.add(gameId);

    // Award skill points only on successful completion
    if (exitCode == 1 && game.skillPoints > 0) {
      _player!.xp += game.skillPoints;
      addToLog('Earned ${game.skillPoints} XP from ${game.displayName}!');
    }

    // Check if any quests need this game completion
    checkAllQuestProgress();

    notifyListeners();
    _syncProgressToServer();
  }

  /// Get quest progress information for an active quest
  Map<String, dynamic>? getQuestProgress(String questId) {
    if (_player == null || _world == null) return null;

    final quest = _world!.quests[questId];
    if (quest == null) return null;

    return {
      'quest': quest,
      'isActive': _player!.activeQuests.contains(questId),
      'isCompleted': _player!.completedQuests.contains(questId),
      'currentTaskIndex': quest.currentTaskIndex,
      'totalTasks': quest.tasks.length,
      'progress': quest.progress,
      'currentTask': quest.currentTask,
    };
  }

  void advanceTime() {
    if (_timeOfDay == 'day') {
      _timeOfDay = 'evening';
    } else if (_timeOfDay == 'evening') {
      _timeOfDay = 'night';
    } else {
      _timeOfDay = 'day';
      _daysPassed++;
    }
    notifyListeners();
    _syncProgressToServer();
  }

  void addToLog(String message) {
    _gameLog.insert(0, message);
    if (_gameLog.length > 100) {
      _gameLog.removeLast();
    }
  }

  void clearLog() {
    _gameLog.clear();
    notifyListeners();
  }

  // Stats helper methods
  int getTotalEquippedStatBoost(String stat) {
    if (_player == null || _world == null) return 0;
    int total = 0;
    for (final itemId in _player!.equippedItems) {
      final item = _world!.items[itemId];
      if (item != null) {
        total += item.statBoosts[stat] ?? 0;
      }
    }
    return total;
  }

  int getEffectiveStat(String stat) {
    if (_player == null) return 0;
    int base = 0;
    switch (stat) {
      case 'strength':
        base = _player!.stats.strength;
        break;
      case 'agility':
        base = _player!.stats.agility;
        break;
      case 'intelligence':
        base = _player!.stats.intelligence;
        break;
      case 'charisma':
        base = _player!.stats.charisma;
        break;
      case 'luck':
        base = _player!.stats.luck;
        break;
      case 'constitution':
        base = _player!.stats.constitution;
        break;
    }
    return base + getTotalEquippedStatBoost(stat);
  }

  // Quest offer methods
  List<Quest> getAvailableQuestsFromNPC(String npcId) {
    return getQuestsForNPC(npcId);
  }

  void offerQuest(String questId) {
    if (_world == null) return;

    final quest = _world!.quests[questId];
    if (quest == null) return;

    _pendingQuestOffer = quest;
    notifyListeners();
  }

  void acceptQuest() {
    if (_pendingQuestOffer == null || _player == null) return;

    final quest = _pendingQuestOffer!;
    if (!_player!.activeQuests.contains(quest.id)) {
      _player!.activeQuests.add(quest.id);
      addToLog("Quest Accepted: ${quest.displayName}");

      // Show quest accept dialogue if available
      if (quest.dialogue.questAccept.isNotEmpty) {
        addToLog("\"${quest.dialogue.questAccept.native}\"");
      }
    }

    _pendingQuestOffer = null;
    notifyListeners();
    _syncProgressToServer();

    // Check if any tasks are already complete (player may already meet conditions)
    checkAllQuestProgress();
  }

  void rejectQuest() {
    if (_pendingQuestOffer == null) return;

    final quest = _pendingQuestOffer!;
    addToLog("Quest Declined: ${quest.displayName}");

    // Show quest decline dialogue if available
    if (quest.dialogue.questDecline.isNotEmpty) {
      addToLog("\"${quest.dialogue.questDecline.native}\"");
    }

    _pendingQuestOffer = null;
    notifyListeners();
  }

  void clearQuestOffer() {
    _pendingQuestOffer = null;
    notifyListeners();
  }

  // ===========================================
  // NPC INTERACTION SYSTEM
  // ===========================================
  // Unified system for all physical interactions between NPCs and players.
  // Modeled after the quest offer system.

  /// Create an item request interaction (NPC wants item from player)
  NPCInteractionRequest? createItemRequest({
    required String npcId,
    required String npcName,
    required String itemId,
    required String itemName,
    String? reason,
  }) {
    if (_player == null) return null;

    final hasItem = _player!.inventory.contains(itemId);

    _pendingInteraction = NPCInteractionRequest.requestItem(
      npcId: npcId,
      npcName: npcName,
      itemId: itemId,
      itemName: itemName,
      reason: reason,
      playerHasItem: hasItem,
    );
    notifyListeners();

    return _pendingInteraction;
  }

  /// Create a sale offer interaction (NPC offers to sell item to player)
  NPCInteractionRequest? createSaleOffer({
    required String npcId,
    required String npcName,
    required String itemId,
    required String itemName,
    required int price,
    String? reason,
  }) {
    if (_player == null) return null;

    final canAfford = _player!.gold >= price;

    _pendingInteraction = NPCInteractionRequest.offerSale(
      npcId: npcId,
      npcName: npcName,
      itemId: itemId,
      itemName: itemName,
      price: price,
      reason: reason,
      playerCanAfford: canAfford,
    );
    notifyListeners();

    return _pendingInteraction;
  }

  /// Create a gift offer interaction (NPC offers item to player for free)
  NPCInteractionRequest? createGiftOffer({
    required String npcId,
    required String npcName,
    required String itemId,
    required String itemName,
    String? reason,
  }) {
    if (_player == null) return null;

    _pendingInteraction = NPCInteractionRequest.offerGift(
      npcId: npcId,
      npcName: npcName,
      itemId: itemId,
      itemName: itemName,
      reason: reason,
    );
    notifyListeners();

    return _pendingInteraction;
  }

  /// Create a trade offer interaction (NPC offers to trade items)
  NPCInteractionRequest? createTradeOffer({
    required String npcId,
    required String npcName,
    required String offeredItemId,
    required String offeredItemName,
    required String requestedItemId,
    required String requestedItemName,
    String? reason,
  }) {
    if (_player == null) return null;

    final hasRequestedItem = _player!.inventory.contains(requestedItemId);

    _pendingInteraction = NPCInteractionRequest.offerTrade(
      npcId: npcId,
      npcName: npcName,
      offeredItemId: offeredItemId,
      offeredItemName: offeredItemName,
      requestedItemId: requestedItemId,
      requestedItemName: requestedItemName,
      reason: reason,
      playerHasRequestedItem: hasRequestedItem,
    );
    notifyListeners();

    return _pendingInteraction;
  }

  /// Accept the current pending interaction
  /// Returns the result for the NPC to respond to
  NPCInteractionResult acceptInteraction() {
    if (_pendingInteraction == null || _player == null) {
      return NPCInteractionResult.dismissed;
    }

    final interaction = _pendingInteraction!;

    switch (interaction.type) {
      case NPCInteractionType.requestItem:
        // Player gives item to NPC
        if (interaction.playerHasItem == true && interaction.itemId != null) {
          _player!.inventory.remove(interaction.itemId);
          addToLog("Gave ${interaction.itemName} to ${interaction.npcName}.");
          // Track for quest progress - pass the item ID
          recordGaveItem(interaction.itemId!);
        }
        break;

      case NPCInteractionType.offerSale:
        // Player buys item from NPC
        if (interaction.playerCanAfford == true &&
            interaction.itemId != null &&
            interaction.price != null) {
          _player!.gold -= interaction.price!;
          _player!.inventory.add(interaction.itemId!);
          debugPrint('ITEM PURCHASED: ${interaction.itemId} added to inventory');
          debugPrint('Current inventory: ${_player!.inventory}');
          addToLog(
              "Purchased ${interaction.itemName} for ${interaction.price} gold.");
          // Track for quest progress
          recordReceivedItem(interaction.itemId!);
        }
        break;

      case NPCInteractionType.offerGift:
        // Player accepts gift from NPC
        if (interaction.itemId != null) {
          _player!.inventory.add(interaction.itemId!);
          addToLog("Received ${interaction.itemName} from ${interaction.npcName}.");
          // Track for quest progress
          recordReceivedItem(interaction.itemId!);
        }
        break;

      case NPCInteractionType.offerTrade:
        // Player trades items with NPC
        if (interaction.playerHasItem == true &&
            interaction.itemId != null &&
            interaction.requestedItemId != null) {
          _player!.inventory.remove(interaction.requestedItemId);
          _player!.inventory.add(interaction.itemId!);
          addToLog(
              "Traded ${interaction.requestedItemName} for ${interaction.itemName}.");
          recordGaveItem(interaction.requestedItemId!);
          recordReceivedItem(interaction.itemId!);
        }
        break;
    }

    _pendingInteraction = null;
    notifyListeners();
    _syncProgressToServer();
    return NPCInteractionResult.accepted;
  }

  /// Decline the current pending interaction
  NPCInteractionResult declineInteraction() {
    if (_pendingInteraction == null) {
      return NPCInteractionResult.dismissed;
    }

    final interaction = _pendingInteraction!;

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

    _pendingInteraction = null;
    notifyListeners();
    return NPCInteractionResult.declined;
  }

  /// Dismiss the current pending interaction (no action, just close)
  void dismissInteraction() {
    _pendingInteraction = null;
    notifyListeners();
  }
}

// Riverpod provider for GameProvider
final gameProvider = ChangeNotifierProvider<GameProvider>((ref) {
  return GameProvider();
});

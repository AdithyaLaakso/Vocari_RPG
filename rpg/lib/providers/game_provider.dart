import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../game_models.dart';
import '../language_system.dart';
import '../npc_interaction.dart';
import '../models/skill_models.dart';
import '../models/user_skill_state.dart';
import '../services/grammar_check_service.dart';
import '../services/trigger_evaluator.dart';
import '../services/level_progression_service.dart';
import '../services/narrator_service.dart';

class GameProvider extends ChangeNotifier {
  Player? _player;
  GameWorld? _world;
  Location? _currentLocation;
  NPC? _currentNPC;
  DialogueNode? _currentDialogue;
  List<String> _gameLog = [];
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

  // Language service access
  LanguageService get languageService => LanguageService.instance;

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
        word: item.vocabularyWord!.targetLanguage,
        translation: item.vocabularyWord!.nativeLanguage,
        context: 'You found this item: ${item.displayName}',
      );
    }

    // Track for quest progress
    recordReceivedItem(itemId);

    notifyListeners();
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
      };

      _world = GameWorld.fromJson(combinedData);

      // Load skill system data (with error handling so game can continue without it)
      if (skillsData != null && triggersData != null && levelProgressionData != null) {
        try {
          _skills = SkillCollection.fromJson(skillsData);
          _triggers = TriggerCollection.fromJson(triggersData);
          _levelProgression = LevelProgression.fromJson(levelProgressionData);
          _levelProgressionService = LevelProgressionService(_levelProgression!);

          debugPrint('Loaded ${_skills!.skills.length} skills');
          debugPrint('Loaded ${_triggers!.triggers.length} triggers');
          debugPrint('Loaded ${_levelProgression!.requirements.length} level requirements');
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

      // Auto-create character with hardcoded name
      createNewCharacter('adi');

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
      debugPrint('Initialized ${_userSkillState!.skills.length} skills at level 0');
    } else {
      debugPrint('Skills not loaded, skill system disabled');
    }

    // Update language service with player's level
    languageService.playerLanguageLevel = _player!.languageLevel;

    _currentLocation = _world!.locations[_player!.currentLocationId];

    final worldName = _world!.lore?.worldName.current ?? 'the world';
    addToLog("Welcome, ${_player!.name}!");
    addToLog("Your language learning adventure in $worldName begins...");

    notifyListeners();
  }

  void moveToLocation(String locationId) {
    if (_world == null || _player == null) return;

    final newLocation = _world!.locations[locationId];
    if (newLocation == null) return;

    // Check if player meets language level requirements
    if (!languageService.meetsLanguageLevel(newLocation.minimumLanguageLevel)) {
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
      if ((conn.fromLocation == _currentLocation?.id && conn.toLocation == locationId) ||
          (conn.bidirectional && conn.toLocation == _currentLocation?.id && conn.fromLocation == locationId)) {
        if (conn.travelDescription.isNotEmpty) {
          travelMsg = conn.displayTravelDescription;
        }
        break;
      }
    }
    addToLog(travelMsg);

    notifyListeners();
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
          addToLog("${npc.displayName}: \"${quest.dialogue.questProgress.current}\"");
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
  }

  // Update player's language level
  void setLanguageLevel(String level) {
    if (_player == null) return;
    _player!.languageLevel = level;
    languageService.playerLanguageLevel = level;
    addToLog("Language proficiency updated to $level!");
    notifyListeners();
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
      final grammarResult = await GrammarCheckService.instance.checkText(
        text,
        'es', // Spanish
        motherTongue: 'en', // English
      );

      if (grammarResult == null) {
        debugPrint('Grammar check returned null, skipping skill update');
        return;
      }

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
        languageService.playerLanguageLevel = progressionCheck.nextLevel!;

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

  /// Item alias mapping - maps common names to quest item IDs
  /// This allows NPCs to use natural item names while quests use formal IDs
  static const Map<String, String> _itemAliases = {
    'apple': 'item_001',
    'manzana': 'item_001',
    'bread': 'item_002',
    'pan': 'item_002',
    'milk': 'item_003',
    'leche': 'item_003',
    'flower': 'item_004',
    'flowers': 'item_004',
    'flor': 'item_004',
    'flores': 'item_004',
    'letter': 'item_005',
    'carta': 'item_005',
    'coin': 'item_009',
    'moneda': 'item_009',
  };

  /// Get the canonical item ID (handles aliases)
  String _getCanonicalItemId(String itemId) {
    final lowerId = itemId.toLowerCase();
    return _itemAliases[lowerId] ?? itemId;
  }

  /// Check if player has an item (handles aliases)
  bool _playerHasItem(String targetItemId) {
    debugPrint('    _playerHasItem checking for: $targetItemId');
    debugPrint('    Inventory: ${_player!.inventory}');

    // Direct check
    if (_player!.inventory.contains(targetItemId)) {
      debugPrint('    Direct match found!');
      return true;
    }

    // Check if any inventory item maps to the target via alias
    for (final item in _player!.inventory) {
      final canonicalId = _getCanonicalItemId(item);
      debugPrint('    Checking item "$item" -> canonical "$canonicalId"');
      if (canonicalId == targetItemId) {
        debugPrint('    Alias match found! $item -> $targetItemId');
        return true;
      }
    }

    // Check if target has an alias that's in inventory (reverse lookup)
    final targetLower = targetItemId.toLowerCase();
    if (_itemAliases.containsKey(targetLower)) {
      final mappedId = _itemAliases[targetLower]!;
      if (_player!.inventory.contains(mappedId)) {
        debugPrint('    Reverse alias match found!');
        return true;
      }
    }

    debugPrint('    No match found');
    return false;
  }

  /// Check if an item was given (handles aliases)
  bool _itemWasGiven(String targetItemId) {
    debugPrint('    _itemWasGiven checking for: $targetItemId');
    debugPrint('    Given items: $_givenItems');

    // Direct check
    if (_givenItems.contains(targetItemId)) {
      debugPrint('    Direct match found!');
      return true;
    }

    // Check if any given item maps to the target via alias
    for (final item in _givenItems) {
      final canonicalId = _getCanonicalItemId(item);
      debugPrint('    Checking given item "$item" -> canonical "$canonicalId"');
      if (canonicalId == targetItemId) {
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

    debugPrint('=== CHECKING QUEST PROGRESS ===');
    debugPrint('Active quests: ${_player!.activeQuests}');
    debugPrint('Player inventory: ${_player!.inventory}');
    debugPrint('Player location: ${_player!.currentLocationId}');
    debugPrint('Given items: $_givenItems');

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

    debugPrint('=== QUEST CHECK COMPLETE: anyProgress=$anyProgress ===');

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
        debugPrint('  at_location check: player at ${_player!.currentLocationId}, need $targetLocation = $result');
        return result;

      case 'has_item':
        // Check if player has the item in inventory (with alias support)
        final targetItem = task.completionCriteria['target_id'] as String?;
        if (targetItem == null) return false;
        final result = _playerHasItem(targetItem);
        debugPrint('  has_item check: looking for $targetItem in ${_player!.inventory} = $result');
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
        debugPrint('  gave_item check: looking for $targetItem in $_givenItems = $result');
        return result;

      case 'received_item':
        // Check if player has received the specific item (with alias support)
        final targetItem = task.completionCriteria['target_id'] as String?;
        if (targetItem == null) return false;
        final result = _playerHasItem(targetItem) || _itemWasGiven(targetItem);
        debugPrint('  received_item check: looking for $targetItem = $result');
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

      default:
        debugPrint('Unknown completion type: ${task.completionType}');
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
    addToLog("${quest.displayName}");

    // Show completion dialogue if available
    if (quest.dialogue.questComplete.isNotEmpty) {
      addToLog("\"${quest.dialogue.questComplete.current}\"");
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
        addToLog("\"${quest.dialogue.questAccept.current}\"");
      }
    }

    _pendingQuestOffer = null;
    notifyListeners();

    // Check if any tasks are already complete (player may already meet conditions)
    checkAllQuestProgress();
  }

  void rejectQuest() {
    if (_pendingQuestOffer == null) return;

    final quest = _pendingQuestOffer!;
    addToLog("Quest Declined: ${quest.displayName}");

    // Show quest decline dialogue if available
    if (quest.dialogue.questDecline.isNotEmpty) {
      addToLog("\"${quest.dialogue.questDecline.current}\"");
    }

    _pendingQuestOffer = null;
    notifyListeners();
  }

  void clearQuestOffer() {
    _pendingQuestOffer = null;
    notifyListeners();
  }

  // Language toggle for UI
  void toggleDisplayLanguage() {
    languageService.toggleLanguage();
    notifyListeners();
  }

  void setDisplayLanguage(DisplayLanguage language) {
    languageService.currentLanguage = language;
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

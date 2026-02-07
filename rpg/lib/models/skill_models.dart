import 'package:flutter/foundation.dart';
import 'package:shared/models/language.dart';

/// Represents a language skill that can be leveled up
class Skill {
  final String id;
  final LocalizedString name;
  final LocalizedString description;
  final String category; // vocabulary, grammar, pragmatic
  final String difficulty; // A0, A0+, A1, A1+, A2
  final int maxLevel;
  final List<String> prerequisites;
  final double weight;
  final List<String> evaluationCriteria;
  final List<LocalizedString> exampleCorrect;
  final List<LocalizedString> exampleIncorrect;

  Skill({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.difficulty,
    required this.maxLevel,
    required this.prerequisites,
    required this.weight,
    required this.evaluationCriteria,
    required this.exampleCorrect,
    required this.exampleIncorrect,
  });

  factory Skill.fromJson(Map<String, dynamic> json) {
    return Skill(
      id: json['id'] ?? '',
      name: LocalizedString.fromJson(json['name']),
      description: LocalizedString.fromJson(json['description']),
      category: json['category'] ?? '',
      difficulty: json['difficulty'] ?? 'A0',
      maxLevel: json['max_level'] ?? 100,
      prerequisites: List<String>.from(json['prerequisites'] ?? []),
      weight: (json['weight'] ?? 1.0).toDouble(),
      evaluationCriteria: List<String>.from(json['evaluation_criteria'] ?? []),
      exampleCorrect: (json['example_correct'] as List?)
              ?.map((e) => LocalizedString.fromJson(e))
              .toList() ??
          [],
      exampleIncorrect: (json['example_incorrect'] as List?)
              ?.map((e) => LocalizedString.fromJson(e))
              .toList() ??
          [],
    );
  }

  String get displayName => name.target;
  String get displayDescription => description.native;
}

/// Collection of all skills
class SkillCollection {
  final List<Skill> skills;

  SkillCollection({required this.skills});

  factory SkillCollection.fromJson(Map<String, dynamic> json) {
    return SkillCollection(
      skills: (json['skills'] as List?)
              ?.map((s) => Skill.fromJson(s))
              .toList() ??
          [],
    );
  }

  Skill? getById(String id) {
    try {
      return skills.firstWhere((s) => s.id == id);
    } catch (e) {
      return null;
    }
  }

  List<Skill> getByCategory(String category) {
    return skills.where((s) => s.category == category).toList();
  }

  List<Skill> getByDifficulty(String difficulty) {
    return skills.where((s) => s.difficulty == difficulty).toList();
  }
}

/// Trigger condition operator
enum TriggerOperator {
  greaterThanOrEqual, // >=
  greaterThan, // >
  equal, // ==
  lessThanOrEqual, // <=
  lessThan, // <
  notEqual, // !=
}

TriggerOperator parseTriggerOperator(String op) {
  switch (op) {
    case '>=':
      return TriggerOperator.greaterThanOrEqual;
    case '>':
      return TriggerOperator.greaterThan;
    case '==':
      return TriggerOperator.equal;
    case '<=':
      return TriggerOperator.lessThanOrEqual;
    case '<':
      return TriggerOperator.lessThan;
    case '!=':
      return TriggerOperator.notEqual;
    default:
      return TriggerOperator.greaterThanOrEqual;
  }
}

/// Trigger condition types
enum TriggerType {
  vocabUsedCorrectly,
  vocabRecognized,
  grammarUsedCorrectly,
  grammarPatternProduced,
  skillDemonstrated,
  questCompleted,
  npcInteraction,
  locationVisited,
  itemAcquired,
  skillLevelReached,
  totalSkillPoints,
}

TriggerType parseTriggerType(String type) {
  switch (type) {
    case 'vocab_used_correctly':
      return TriggerType.vocabUsedCorrectly;
    case 'vocab_recognized':
      return TriggerType.vocabRecognized;
    case 'grammar_used_correctly':
      return TriggerType.grammarUsedCorrectly;
    case 'grammar_pattern_produced':
      return TriggerType.grammarPatternProduced;
    case 'skill_demonstrated':
      return TriggerType.skillDemonstrated;
    case 'quest_completed':
      return TriggerType.questCompleted;
    case 'npc_interaction':
      return TriggerType.npcInteraction;
    case 'location_visited':
      return TriggerType.locationVisited;
    case 'item_acquired':
      return TriggerType.itemAcquired;
    case 'skill_level_reached':
      return TriggerType.skillLevelReached;
    case 'total_skill_points':
      return TriggerType.totalSkillPoints;
    default:
      debugPrint("[WARNING] invalid trigger type");
      return TriggerType.vocabUsedCorrectly;
  }
}

/// A condition for triggering skill progression
class TriggerCondition {
  final TriggerType triggerType;
  final String targetId;
  final TriggerOperator opCode;
  final int threshold;
  final String? logic; // AND or OR for compound triggers
  final List<TriggerCondition>? conditions; // Sub-conditions for compound triggers

  TriggerCondition({
    required this.triggerType,
    required this.targetId,
    required this.opCode,
    required this.threshold,
    this.logic,
    this.conditions,
  });

  factory TriggerCondition.fromJson(Map<String, dynamic> json) {
    // Check if this is a compound trigger
    if (json.containsKey('logic')) {
      return TriggerCondition(
        triggerType: TriggerType.vocabUsedCorrectly, // Placeholder for compound
        targetId: '',
        opCode: TriggerOperator.greaterThanOrEqual,
        threshold: 0,
        logic: json['logic'],
        conditions: (json['conditions'] as List?)
            ?.map((c) => TriggerCondition.fromJson(c))
            .toList(),
      );
    }

    // Simple trigger
    return TriggerCondition(
      triggerType: parseTriggerType(json['trigger_type'] ?? ''),
      targetId: json['target_id'] ?? '',
      opCode: parseTriggerOperator(json['operator'] ?? '>='),
      threshold: json['threshold'] ?? 0,
    );
  }

  bool get isCompound => logic != null && conditions != null;
}

/// A trigger that awards skill points when conditions are met
class Trigger {
  final String skillId;
  final int pointsAwarded;
  final bool repeatable;
  final int cooldownInteractions;
  final String description;
  final TriggerCondition trigger;

  Trigger({
    required this.skillId,
    required this.pointsAwarded,
    required this.repeatable,
    required this.cooldownInteractions,
    required this.description,
    required this.trigger,
  });

  factory Trigger.fromJson(Map<String, dynamic> json) {
    return Trigger(
      skillId: json['skill_id'] ?? '',
      pointsAwarded: json['points_awarded'] ?? 0,
      repeatable: json['repeatable'] ?? false,
      cooldownInteractions: json['cooldown_interactions'] ?? 0,
      description: json['description'] ?? '',
      trigger: TriggerCondition.fromJson(json['trigger'] ?? {}),
    );
  }
}

/// Collection of all triggers
class TriggerCollection {
  final List<Trigger> triggers;

  TriggerCollection({required this.triggers});

  factory TriggerCollection.fromJson(Map<String, dynamic> json) {
    return TriggerCollection(
      triggers: (json['triggers'] as List?)
              ?.map((t) => Trigger.fromJson(t))
              .toList() ??
          [],
    );
  }

  List<Trigger> getForSkill(String skillId) {
    return triggers.where((t) => t.skillId == skillId).toList();
  }
}

/// Skill threshold requirement for level progression
class SkillThreshold {
  final String skillId;
  final int minimumLevel;

  SkillThreshold({
    required this.skillId,
    required this.minimumLevel,
  });

  factory SkillThreshold.fromJson(Map<String, dynamic> json) {
    return SkillThreshold(
      skillId: json['skill_id'] ?? '',
      minimumLevel: json['minimum_level'] ?? 0,
    );
  }
}

/// Requirements to advance from one level to another
class LevelRequirement {
  final String fromLevel;
  final String toLevel;
  final int minimumTotalSkillPoints;
  final List<SkillThreshold> requiredSkillThresholds;
  final List<String> flexibleSkillPool;
  final int flexibleSkillCount;
  final int flexibleThreshold;
  final String description;

  LevelRequirement({
    required this.fromLevel,
    required this.toLevel,
    required this.minimumTotalSkillPoints,
    required this.requiredSkillThresholds,
    required this.flexibleSkillPool,
    required this.flexibleSkillCount,
    required this.flexibleThreshold,
    required this.description,
  });

  factory LevelRequirement.fromJson(Map<String, dynamic> json) {
    return LevelRequirement(
      fromLevel: json['from_level'] ?? '',
      toLevel: json['to_level'] ?? '',
      minimumTotalSkillPoints: json['minimum_total_skill_points'] ?? 0,
      requiredSkillThresholds: (json['required_skill_thresholds'] as List?)
              ?.map((t) => SkillThreshold.fromJson(t))
              .toList() ??
          [],
      flexibleSkillPool: List<String>.from(json['flexible_skill_pool'] ?? []),
      flexibleSkillCount: json['flexible_skill_count'] ?? 0,
      flexibleThreshold: json['flexible_threshold'] ?? 0,
      description: json['description'] ?? '',
    );
  }
}

/// Level progression configuration
class LevelProgression {
  final List<LevelRequirement> requirements;
  final int totalSkillPointCap;
  final List<String> levelOrder;
  final Map<String, dynamic> meta;

  LevelProgression({
    required this.requirements,
    required this.totalSkillPointCap,
    required this.levelOrder,
    required this.meta,
  });

  factory LevelProgression.fromJson(Map<String, dynamic> json) {
    return LevelProgression(
      requirements: (json['requirements'] as List?)
              ?.map((r) => LevelRequirement.fromJson(r))
              .toList() ??
          [],
      totalSkillPointCap: json['total_skill_point_cap'] ?? 1000,
      levelOrder: List<String>.from(json['_level_order'] ?? []),
      meta: Map<String, dynamic>.from(json['_meta'] ?? {}),
    );
  }

  LevelRequirement? getRequirement(String fromLevel, String toLevel) {
    try {
      return requirements.firstWhere(
        (r) => r.fromLevel == fromLevel && r.toLevel == toLevel,
      );
    } catch (e) {
      return null;
    }
  }

  String? getNextLevel(String currentLevel) {
    final index = levelOrder.indexOf(currentLevel);
    if (index >= 0 && index < levelOrder.length - 1) {
      return levelOrder[index + 1];
    }
    return null;
  }

  LevelRequirement? getRequirementForCurrentLevel(String currentLevel) {
    final nextLevel = getNextLevel(currentLevel);
    if (nextLevel != null) {
      return getRequirement(currentLevel, nextLevel);
    }
    return null;
  }
}

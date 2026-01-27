import 'dart:math';
import 'skill_models.dart';

/// Tracks user's skill progression state
class UserSkillState {
  /// Skill levels (skill_id -> level from 0-100)
  Map<String, int> skills;

  /// Vocabulary usage counters (word_id -> count of correct uses)
  Map<String, int> vocabUsage;

  /// Grammar pattern usage counters (pattern_id -> count of correct uses)
  Map<String, int> grammarUsage;

  /// Skill demonstration counters (skill_id -> count of demonstrations)
  Map<String, int> skillDemonstrations;

  /// Non-repeatable triggers that have already fired
  Set<String> firedTriggers;

  /// Cooldown tracking (trigger_description -> interactions_since_last_fire)
  Map<String, int> triggerCooldowns;

  /// Total interactions (for cooldown tracking)
  int totalInteractions;

  UserSkillState({
    Map<String, int>? skills,
    Map<String, int>? vocabUsage,
    Map<String, int>? grammarUsage,
    Map<String, int>? skillDemonstrations,
    Set<String>? firedTriggers,
    Map<String, int>? triggerCooldowns,
    this.totalInteractions = 0,
  })  : skills = skills ?? {},
        vocabUsage = vocabUsage ?? {},
        grammarUsage = grammarUsage ?? {},
        skillDemonstrations = skillDemonstrations ?? {},
        firedTriggers = firedTriggers ?? {},
        triggerCooldowns = triggerCooldowns ?? {};

  /// Initialize from a skill collection (sets all skills to level 0)
  factory UserSkillState.fromSkills(SkillCollection skillCollection) {
    final skills = <String, int>{};
    for (final skill in skillCollection.skills) {
      skills[skill.id] = 0;
    }
    return UserSkillState(skills: skills);
  }

  /// Get total skill points
  int get totalSkillPoints {
    return skills.values.fold(0, (sum, level) => sum + level);
  }

  /// Award points to a skill (respects max level)
  void awardSkillPoints(String skillId, int points, {int maxLevel = 100}) {
    final currentLevel = skills[skillId] ?? 0;
    skills[skillId] = min(maxLevel, currentLevel + points);
  }

  /// Increment vocabulary usage counter
  void recordVocabUsage(String wordId) {
    vocabUsage[wordId] = (vocabUsage[wordId] ?? 0) + 1;
  }

  /// Increment grammar usage counter
  void recordGrammarUsage(String patternId) {
    grammarUsage[patternId] = (grammarUsage[patternId] ?? 0) + 1;
  }

  /// Increment skill demonstration counter
  void recordSkillDemonstration(String skillId) {
    skillDemonstrations[skillId] = (skillDemonstrations[skillId] ?? 0) + 1;
  }

  /// Mark a non-repeatable trigger as fired
  void markTriggerFired(String triggerDescription) {
    firedTriggers.add(triggerDescription);
  }

  /// Check if a non-repeatable trigger has already fired
  bool hasTriggerFired(String triggerDescription) {
    return firedTriggers.contains(triggerDescription);
  }

  /// Reset cooldown for a trigger (called when trigger fires)
  void resetTriggerCooldown(String triggerDescription) {
    triggerCooldowns[triggerDescription] = 0;
  }

  /// Get interactions since last trigger fire
  int getTriggerCooldown(String triggerDescription) {
    return triggerCooldowns[triggerDescription] ?? 999999; // High number if never fired
  }

  /// Increment all trigger cooldowns (call after each interaction)
  void incrementInteraction() {
    totalInteractions++;
    final keys = List<String>.from(triggerCooldowns.keys);
    for (final key in keys) {
      triggerCooldowns[key] = (triggerCooldowns[key] ?? 0) + 1;
    }
  }

  /// Get current value for a trigger type
  int getCurrentValue(TriggerType type, String targetId) {
    switch (type) {
      case TriggerType.vocabUsedCorrectly:
      case TriggerType.vocabRecognized:
        return vocabUsage[targetId] ?? 0;
      case TriggerType.grammarUsedCorrectly:
      case TriggerType.grammarPatternProduced:
        return grammarUsage[targetId] ?? 0;
      case TriggerType.skillDemonstrated:
        return skillDemonstrations[targetId] ?? 0;
      case TriggerType.skillLevelReached:
        return skills[targetId] ?? 0;
      case TriggerType.totalSkillPoints:
        return totalSkillPoints;
      case TriggerType.questCompleted:
      case TriggerType.npcInteraction:
      case TriggerType.locationVisited:
      case TriggerType.itemAcquired:
        // These are handled by the game state, not skill state
        return 0;
    }
  }

  /// Serialize to JSON
  Map<String, dynamic> toJson() {
    return {
      'skills': skills,
      'vocab_usage': vocabUsage,
      'grammar_usage': grammarUsage,
      'skill_demonstrations': skillDemonstrations,
      'fired_triggers': firedTriggers.toList(),
      'trigger_cooldowns': triggerCooldowns,
      'total_interactions': totalInteractions,
    };
  }

  /// Deserialize from JSON
  factory UserSkillState.fromJson(Map<String, dynamic> json) {
    return UserSkillState(
      skills: Map<String, int>.from(json['skills'] ?? {}),
      vocabUsage: Map<String, int>.from(json['vocab_usage'] ?? {}),
      grammarUsage: Map<String, int>.from(json['grammar_usage'] ?? {}),
      skillDemonstrations:
          Map<String, int>.from(json['skill_demonstrations'] ?? {}),
      firedTriggers: Set<String>.from(json['fired_triggers'] ?? []),
      triggerCooldowns: Map<String, int>.from(json['trigger_cooldowns'] ?? {}),
      totalInteractions: json['total_interactions'] ?? 0,
    );
  }

  /// Reset all counters (for new session or testing)
  void resetCounters() {
    vocabUsage.clear();
    grammarUsage.clear();
    skillDemonstrations.clear();
  }

  /// Reset all progression (for testing)
  void resetAll() {
    skills.clear();
    vocabUsage.clear();
    grammarUsage.clear();
    skillDemonstrations.clear();
    firedTriggers.clear();
    triggerCooldowns.clear();
    totalInteractions = 0;
  }
}

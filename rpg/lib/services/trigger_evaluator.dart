import 'package:flutter/foundation.dart';
import 'package:shared/services/grammar_service.dart';
import '../models/skill_models.dart';
import '../models/user_skill_state.dart';
import '../game_models.dart';

/// Result of trigger evaluation
class TriggerEvaluationResult {
  final String skillId;
  final int pointsAwarded;
  final String description;
  final bool triggered;

  TriggerEvaluationResult({
    required this.skillId,
    required this.pointsAwarded,
    required this.description,
    this.triggered = true,
  });
}

/// Service for evaluating triggers and awarding skill points
class TriggerEvaluator {
  /// Evaluate all triggers against current state
  /// Returns list of triggers that fired and awarded points
  static List<TriggerEvaluationResult> evaluateTriggers({
    required UserSkillState userState,
    required TriggerCollection triggers,
    required Player player,
    GrammarCheckResult? grammarResult,
  }) {
    final results = <TriggerEvaluationResult>[];

    for (final trigger in triggers.triggers) {
      // Check if trigger should be evaluated
      if (!_shouldEvaluateTrigger(trigger, userState)) {
        continue;
      }

      // Evaluate the trigger condition
      final conditionMet = _evaluateTriggerCondition(
        trigger.trigger,
        userState,
        player,
        grammarResult,
      );

      if (conditionMet) {
        // Award points
        userState.awardSkillPoints(trigger.skillId, trigger.pointsAwarded);

        // Mark as fired if non-repeatable
        if (!trigger.repeatable) {
          userState.markTriggerFired(trigger.description);
        }

        // Reset cooldown
        userState.resetTriggerCooldown(trigger.description);

        results.add(TriggerEvaluationResult(
          skillId: trigger.skillId,
          pointsAwarded: trigger.pointsAwarded,
          description: trigger.description,
        ));

        debugPrint(
            'Trigger fired: ${trigger.description} (+${trigger.pointsAwarded} to ${trigger.skillId})');
      }
    }

    return results;
  }

  /// Check if a trigger should be evaluated (cooldown and repeatability checks)
  static bool _shouldEvaluateTrigger(
      Trigger trigger, UserSkillState userState) {
    // Check if non-repeatable trigger already fired
    if (!trigger.repeatable &&
        userState.hasTriggerFired(trigger.description)) {
      return false;
    }

    // Check cooldown
    if (trigger.cooldownInteractions > 0) {
      final interactionsSinceLast =
          userState.getTriggerCooldown(trigger.description);
      if (interactionsSinceLast < trigger.cooldownInteractions) {
        return false;
      }
    }

    return true;
  }

  /// Evaluate a trigger condition (simple or compound)
  static bool _evaluateTriggerCondition(
    TriggerCondition condition,
    UserSkillState userState,
    Player player,
    GrammarCheckResult? grammarResult,
  ) {
    // Handle compound triggers (AND/OR logic)
    if (condition.isCompound) {
      return _evaluateCompoundCondition(
        condition,
        userState,
        player,
        grammarResult,
      );
    }

    // Handle simple triggers
    return _evaluateSimpleCondition(
      condition,
      userState,
      player,
      grammarResult,
    );
  }

  /// Evaluate compound trigger with AND/OR logic
  static bool _evaluateCompoundCondition(
    TriggerCondition condition,
    UserSkillState userState,
    Player player,
    GrammarCheckResult? grammarResult,
  ) {
    if (condition.conditions == null || condition.conditions!.isEmpty) {
      return false;
    }

    if (condition.logic == 'AND') {
      // All conditions must be true
      return condition.conditions!.every(
        (c) => _evaluateTriggerCondition(c, userState, player, grammarResult),
      );
    } else if (condition.logic == 'OR') {
      // At least one condition must be true
      return condition.conditions!.any(
        (c) => _evaluateTriggerCondition(c, userState, player, grammarResult),
      );
    }

    return false;
  }

  /// Evaluate a simple trigger condition
  static bool _evaluateSimpleCondition(
    TriggerCondition condition,
    UserSkillState userState,
    Player player,
    GrammarCheckResult? grammarResult,
  ) {
    // Get current value based on trigger type
    final currentValue = _getCurrentValue(
      condition.triggerType,
      condition.targetId,
      userState,
      player,
      grammarResult,
    );

    // Compare against threshold using operator
    return _compareValue(currentValue, condition.opCode, condition.threshold);
  }

  /// Get current value for a trigger type
  static int _getCurrentValue(
    TriggerType type,
    String targetId,
    UserSkillState userState,
    Player player,
    GrammarCheckResult? grammarResult,
  ) {
    switch (type) {
      case TriggerType.vocabUsedCorrectly:
      case TriggerType.vocabRecognized:
        return userState.vocabUsage[targetId] ?? 0;

      case TriggerType.grammarUsedCorrectly:
      case TriggerType.grammarPatternProduced:
        return userState.grammarUsage[targetId] ?? 0;

      case TriggerType.skillDemonstrated:
        return userState.skillDemonstrations[targetId] ?? 0;

      case TriggerType.skillLevelReached:
        return userState.skills[targetId] ?? 0;

      case TriggerType.totalSkillPoints:
        return userState.totalSkillPoints;

      case TriggerType.questCompleted:
        return player.completedQuests.contains(targetId) ? 1 : 0;

      case TriggerType.npcInteraction:
        return player.talkedToNPCs.contains(targetId) ? 1 : 0;

      case TriggerType.locationVisited:
        // Check if player has visited the location
        // This could be tracked in player state
        return 0; // TODO: Add location visit tracking

      case TriggerType.itemAcquired:
        return player.inventory.contains(targetId) ? 1 : 0;
    }
  }

  /// Compare a value against a threshold using an operator
  static bool _compareValue(
      int value, TriggerOperator operator, int threshold) {
    switch (operator) {
      case TriggerOperator.greaterThanOrEqual:
        return value >= threshold;
      case TriggerOperator.greaterThan:
        return value > threshold;
      case TriggerOperator.equal:
        return value == threshold;
      case TriggerOperator.lessThanOrEqual:
        return value <= threshold;
      case TriggerOperator.lessThan:
        return value < threshold;
      case TriggerOperator.notEqual:
        return value != threshold;
    }
  }

  /// Process grammar check result and update user state
  static void processGrammarResult(
    GrammarCheckResult result,
    UserSkillState userState,
  ) {
    if (result.vocabCorrect != null) {
      // Update vocabulary usage
      for (final skillId in result.vocabCorrect!) {
        userState.recordVocabUsage(skillId);
      }
    }

    // Update grammar pattern usage
    if (result.grammarPatterns != null) {
      for (final skillId in result.grammarPatterns!) {
        userState.recordGrammarUsage(skillId);
      }
    }

    // Update skill demonstrations
    if (result.skillDemonstrations != null) {
      for (final skillId in result.skillDemonstrations!) {
        userState.recordSkillDemonstration(skillId);
      }
    }

    debugPrint('Processed grammar result:');
    debugPrint('  Vocab: ${result.vocabCorrect}');
    debugPrint('  Grammar: ${result.grammarPatterns}');
    debugPrint('  Skills: ${result.skillDemonstrations}');
  }
}

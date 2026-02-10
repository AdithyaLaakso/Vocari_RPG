import 'package:flutter/foundation.dart';
import '../models/skill_models.dart';

/// Result of checking level progression eligibility
class LevelProgressionCheck {
  final bool canAdvance;
  final List<String> reasons;
  final String? nextLevel;
  final LevelRequirement? requirement;

  LevelProgressionCheck({
    required this.canAdvance,
    required this.reasons,
    this.nextLevel,
    this.requirement,
  });

  LevelProgressionCheck.success(this.nextLevel, this.requirement)
      : canAdvance = true,
        reasons = ['All requirements met!'];

  LevelProgressionCheck.failure(this.reasons)
      : canAdvance = false,
        nextLevel = null,
        requirement = null;
}

/// Service for checking and managing level progression
class LevelProgressionService {
  final LevelProgression _progression;

  LevelProgressionService(this._progression);

  /// Check if player can advance from current level
  LevelProgressionCheck canAdvance(
    String currentLevel,
    Map<String, int> skillLevels,
  ) {
    final nextLevel = _progression.getNextLevel(currentLevel);

    if (nextLevel == null) {
      return LevelProgressionCheck.failure(
          ['You are already at the maximum level!']);
    }

    final requirement = _progression.getRequirement(currentLevel, nextLevel);

    if (requirement == null) {
      return LevelProgressionCheck.failure(
          ['No progression path found from $currentLevel to $nextLevel']);
    }

    // Check all requirements
    final failures = <String>[];

    // 1. Check minimum total skill points
    final totalPoints = skillLevels.values.fold(0, (sum, level) => sum + level);
    if (totalPoints < requirement.minimumTotalSkillPoints) {
      failures.add(
          'Need ${requirement.minimumTotalSkillPoints} total skill points (currently: $totalPoints)');
    }

    // 2. Check required skill thresholds
    for (final threshold in requirement.requiredSkillThresholds) {
      final currentLevel = skillLevels[threshold.skillId] ?? 0;
      if (currentLevel < threshold.minimumLevel) {
        failures.add(
            'Need ${threshold.skillId} at level ${threshold.minimumLevel} (currently: $currentLevel)');
      }
    }

    // 3. Check flexible skill pool
    if (requirement.flexibleSkillPool.isNotEmpty &&
        requirement.flexibleSkillCount > 0) {
      final qualifyingSkills = requirement.flexibleSkillPool.where((skillId) {
        final level = skillLevels[skillId] ?? 0;
        return level >= requirement.flexibleThreshold;
      }).length;

      if (qualifyingSkills < requirement.flexibleSkillCount) {
        failures.add(
            'Need ${requirement.flexibleSkillCount} skills from flexible pool at level ${requirement.flexibleThreshold} (currently have: $qualifyingSkills)');
      }
    }

    if (failures.isEmpty) {
      debugPrint(
          'Player can advance from $currentLevel to $nextLevel!');
      return LevelProgressionCheck.success(nextLevel, requirement);
    } else {
      debugPrint(
          'Player cannot advance yet. Reasons:\n  ${failures.join('\n  ')}');
      return LevelProgressionCheck.failure(failures);
    }
  }

  /// Get the next level after current level
  String? getNextLevel(String currentLevel) {
    return _progression.getNextLevel(currentLevel);
  }

  /// Get progression requirement for current level
  LevelRequirement? getRequirementForCurrentLevel(String currentLevel) {
    return _progression.getRequirementForCurrentLevel(currentLevel);
  }

  /// Get detailed progress toward next level
  Map<String, dynamic> getProgressDetails(
    String currentLevel,
    Map<String, int> skillLevels,
  ) {
    final nextLevel = _progression.getNextLevel(currentLevel);

    if (nextLevel == null) {
      return {
        'at_max_level': true,
        'current_level': currentLevel,
      };
    }

    final requirement = _progression.getRequirement(currentLevel, nextLevel);

    if (requirement == null) {
      return {
        'error': 'No progression path found',
        'current_level': currentLevel,
      };
    }

    final totalPoints = skillLevels.values.fold(0, (sum, level) => sum + level);

    // Count qualifying flexible skills
    final qualifyingFlexibleSkills = requirement.flexibleSkillPool.where((id) {
      final level = skillLevels[id] ?? 0;
      return level >= requirement.flexibleThreshold;
    }).length;

    // Check required skills
    final requiredSkillsProgress = <Map<String, dynamic>>[];
    for (final threshold in requirement.requiredSkillThresholds) {
      final currentLevel = skillLevels[threshold.skillId] ?? 0;
      requiredSkillsProgress.add({
        'skill_id': threshold.skillId,
        'current': currentLevel,
        'required': threshold.minimumLevel,
        'met': currentLevel >= threshold.minimumLevel,
      });
    }

    return {
      'current_level': currentLevel,
      'next_level': nextLevel,
      'total_skill_points': {
        'current': totalPoints,
        'required': requirement.minimumTotalSkillPoints,
        'met': totalPoints >= requirement.minimumTotalSkillPoints,
      },
      'required_skills': requiredSkillsProgress,
      'flexible_skills': {
        'current': qualifyingFlexibleSkills,
        'required': requirement.flexibleSkillCount,
        'threshold': requirement.flexibleThreshold,
        'met': qualifyingFlexibleSkills >= requirement.flexibleSkillCount,
      },
      'description': requirement.description,
    };
  }

  /// Get all level requirements
  List<LevelRequirement> getAllRequirements() {
    return _progression.requirements;
  }

  /// Get level order
  List<String> getLevelOrder() {
    return _progression.levelOrder;
  }
}

"""
Trigger Validator

Validates that triggers conform to the standard format and are semantically valid.
This ensures all triggers (skill progression, quest completion, level advancement)
can be evaluated deterministically.
"""

import re
from typing import Dict, Any, List, Set, Optional, Union
from pydantic import ValidationError

from .models import (
    TriggerCondition,
    CompoundTrigger,
    TriggerType,
    TriggerOperator,
    CompoundLogic,
    SkillProgressionTrigger,
    LevelProgressionRequirement,
    TriggerValidationError,
    TriggerValidationResult,
    LanguageLevel,
)


class TriggerValidator:
    """
    Validates triggers against the standard format and semantic rules.

    Validation includes:
    1. Format validation - correct structure and types
    2. Reference validation - IDs reference existing entities
    3. Semantic validation - logical consistency
    """

    def __init__(
        self,
        valid_skill_ids: Optional[Set[str]] = None,
        valid_vocab_ids: Optional[Set[str]] = None,
        valid_grammar_ids: Optional[Set[str]] = None,
        valid_quest_ids: Optional[Set[str]] = None,
        valid_npc_ids: Optional[Set[str]] = None,
        valid_location_ids: Optional[Set[str]] = None,
        valid_item_ids: Optional[Set[str]] = None,
    ):
        """
        Initialize validator with sets of valid IDs for reference validation.

        If a set is None, reference validation for that type is skipped.
        """
        self.valid_skill_ids = valid_skill_ids
        self.valid_vocab_ids = valid_vocab_ids
        self.valid_grammar_ids = valid_grammar_ids
        self.valid_quest_ids = valid_quest_ids
        self.valid_npc_ids = valid_npc_ids
        self.valid_location_ids = valid_location_ids
        self.valid_item_ids = valid_item_ids

    def validate_trigger_condition(
        self,
        condition: Union[TriggerCondition, Dict[str, Any]],
        path: str = "condition"
    ) -> TriggerValidationResult:
        """Validate a single trigger condition."""
        errors = []
        warnings = []

        # Parse if dict
        if isinstance(condition, dict):
            try:
                condition = TriggerCondition(**condition)
            except ValidationError as e:
                for err in e.errors():
                    errors.append(TriggerValidationError(
                        field=f"{path}.{'.'.join(str(x) for x in err['loc'])}",
                        message=err['msg'],
                        value=str(err.get('input', ''))
                    ))
                return TriggerValidationResult(is_valid=False, errors=errors)

        # Validate trigger type
        if not isinstance(condition.trigger_type, TriggerType):
            errors.append(TriggerValidationError(
                field=f"{path}.trigger_type",
                message=f"Invalid trigger type: {condition.trigger_type}",
                value=str(condition.trigger_type)
            ))

        # Validate operator
        if not isinstance(condition.operator, TriggerOperator):
            errors.append(TriggerValidationError(
                field=f"{path}.operator",
                message=f"Invalid operator: {condition.operator}",
                value=str(condition.operator)
            ))

        # Validate threshold
        if condition.threshold < 0:
            errors.append(TriggerValidationError(
                field=f"{path}.threshold",
                message="Threshold must be non-negative",
                value=str(condition.threshold)
            ))

        # Validate target_id is not empty
        if not condition.target_id or not condition.target_id.strip():
            errors.append(TriggerValidationError(
                field=f"{path}.target_id",
                message="Target ID cannot be empty",
                value=condition.target_id
            ))

        # Validate target_id format (alphanumeric, underscores, hyphens)
        if condition.target_id and not re.match(r'^[\w\-\.]+$', condition.target_id):
            errors.append(TriggerValidationError(
                field=f"{path}.target_id",
                message="Target ID contains invalid characters (use alphanumeric, underscore, hyphen, dot)",
                value=condition.target_id
            ))

        # Validate reference exists (if validation sets provided)
        ref_error = self._validate_reference(condition, path)
        if ref_error:
            errors.append(ref_error)

        # Semantic validation
        semantic_warnings = self._validate_semantics(condition, path)
        warnings.extend(semantic_warnings)

        return TriggerValidationResult(
            is_valid=len(errors) == 0,
            errors=errors,
            warnings=warnings
        )

    def validate_compound_trigger(
        self,
        trigger: Union[CompoundTrigger, Dict[str, Any]],
        path: str = "trigger",
        max_depth: int = 5
    ) -> TriggerValidationResult:
        """Validate a compound trigger with nested conditions."""
        errors = []
        warnings = []

        if max_depth <= 0:
            errors.append(TriggerValidationError(
                field=path,
                message="Compound trigger nesting exceeds maximum depth",
                value=None
            ))
            return TriggerValidationResult(is_valid=False, errors=errors)

        # Parse if dict
        if isinstance(trigger, dict):
            try:
                trigger = CompoundTrigger(**trigger)
            except ValidationError as e:
                for err in e.errors():
                    errors.append(TriggerValidationError(
                        field=f"{path}.{'.'.join(str(x) for x in err['loc'])}",
                        message=err['msg'],
                        value=str(err.get('input', ''))
                    ))
                return TriggerValidationResult(is_valid=False, errors=errors)

        # Validate logic operator
        if not isinstance(trigger.logic, CompoundLogic):
            errors.append(TriggerValidationError(
                field=f"{path}.logic",
                message=f"Invalid logic operator: {trigger.logic}",
                value=str(trigger.logic)
            ))

        # Validate conditions list is not empty
        if not trigger.conditions:
            errors.append(TriggerValidationError(
                field=f"{path}.conditions",
                message="Compound trigger must have at least one condition",
                value=None
            ))

        # Validate each condition
        for i, cond in enumerate(trigger.conditions):
            cond_path = f"{path}.conditions[{i}]"

            if isinstance(cond, CompoundTrigger) or (isinstance(cond, dict) and 'logic' in cond):
                result = self.validate_compound_trigger(cond, cond_path, max_depth - 1)
            else:
                result = self.validate_trigger_condition(cond, cond_path)

            errors.extend(result.errors)
            warnings.extend(result.warnings)

        return TriggerValidationResult(
            is_valid=len(errors) == 0,
            errors=errors,
            warnings=warnings
        )

    def validate_skill_progression_trigger(
        self,
        trigger: Union[SkillProgressionTrigger, Dict[str, Any]],
        path: str = "skill_trigger"
    ) -> TriggerValidationResult:
        """Validate a skill progression trigger."""
        errors = []
        warnings = []

        # Parse if dict
        if isinstance(trigger, dict):
            try:
                trigger = SkillProgressionTrigger(**trigger)
            except ValidationError as e:
                for err in e.errors():
                    errors.append(TriggerValidationError(
                        field=f"{path}.{'.'.join(str(x) for x in err['loc'])}",
                        message=err['msg'],
                        value=str(err.get('input', ''))
                    ))
                return TriggerValidationResult(is_valid=False, errors=errors)

        # Validate skill_id exists
        if self.valid_skill_ids is not None and trigger.skill_id not in self.valid_skill_ids:
            errors.append(TriggerValidationError(
                field=f"{path}.skill_id",
                message=f"Skill ID '{trigger.skill_id}' does not exist",
                value=trigger.skill_id
            ))

        # Validate skill_id format
        if not re.match(r'^[\w\-\.]+$', trigger.skill_id):
            errors.append(TriggerValidationError(
                field=f"{path}.skill_id",
                message="Skill ID contains invalid characters",
                value=trigger.skill_id
            ))

        # Validate points_awarded
        if trigger.points_awarded < 1 or trigger.points_awarded > 100:
            errors.append(TriggerValidationError(
                field=f"{path}.points_awarded",
                message="Points awarded must be between 1 and 100",
                value=str(trigger.points_awarded)
            ))

        # Validate cooldown makes sense for repeatable triggers
        if not trigger.repeatable and trigger.cooldown_interactions > 0:
            warnings.append(f"{path}: cooldown_interactions is set but trigger is not repeatable")

        # Validate the trigger itself
        if isinstance(trigger.trigger, CompoundTrigger):
            result = self.validate_compound_trigger(trigger.trigger, f"{path}.trigger")
        else:
            result = self.validate_trigger_condition(trigger.trigger, f"{path}.trigger")

        errors.extend(result.errors)
        warnings.extend(result.warnings)

        return TriggerValidationResult(
            is_valid=len(errors) == 0,
            errors=errors,
            warnings=warnings
        )

    def validate_level_progression_requirement(
        self,
        requirement: Union[LevelProgressionRequirement, Dict[str, Any]],
        path: str = "level_requirement"
    ) -> TriggerValidationResult:
        """Validate a level progression requirement."""
        errors = []
        warnings = []

        # Parse if dict
        if isinstance(requirement, dict):
            try:
                requirement = LevelProgressionRequirement(**requirement)
            except ValidationError as e:
                for err in e.errors():
                    errors.append(TriggerValidationError(
                        field=f"{path}.{'.'.join(str(x) for x in err['loc'])}",
                        message=err['msg'],
                        value=str(err.get('input', ''))
                    ))
                return TriggerValidationResult(is_valid=False, errors=errors)

        # Validate level progression order
        level_order = ["A0", "A0+", "A1", "A1+", "A2"]
        try:
            from_idx = level_order.index(requirement.from_level.value if isinstance(requirement.from_level, LanguageLevel) else requirement.from_level)
            to_idx = level_order.index(requirement.to_level.value if isinstance(requirement.to_level, LanguageLevel) else requirement.to_level)

            if to_idx != from_idx + 1:
                errors.append(TriggerValidationError(
                    field=f"{path}.to_level",
                    message=f"Level progression must be sequential: {requirement.from_level} -> {requirement.to_level} is not valid",
                    value=f"{requirement.from_level} -> {requirement.to_level}"
                ))
        except ValueError as e:
            errors.append(TriggerValidationError(
                field=path,
                message=f"Invalid language level: {e}",
                value=None
            ))

        # Validate total skill points is reasonable
        if requirement.minimum_total_skill_points < 0:
            errors.append(TriggerValidationError(
                field=f"{path}.minimum_total_skill_points",
                message="Minimum total skill points must be non-negative",
                value=str(requirement.minimum_total_skill_points)
            ))

        # Validate skill thresholds reference valid skills
        for i, threshold in enumerate(requirement.required_skill_thresholds):
            if self.valid_skill_ids is not None and threshold.skill_id not in self.valid_skill_ids:
                errors.append(TriggerValidationError(
                    field=f"{path}.required_skill_thresholds[{i}].skill_id",
                    message=f"Skill ID '{threshold.skill_id}' does not exist",
                    value=threshold.skill_id
                ))

            if threshold.minimum_level < 0 or threshold.minimum_level > 100:
                errors.append(TriggerValidationError(
                    field=f"{path}.required_skill_thresholds[{i}].minimum_level",
                    message="Minimum level must be between 0 and 100",
                    value=str(threshold.minimum_level)
                ))

        # Validate flexible skill pool
        if requirement.flexible_skill_count > 0:
            if not requirement.flexible_skill_pool:
                errors.append(TriggerValidationError(
                    field=f"{path}.flexible_skill_pool",
                    message="flexible_skill_pool cannot be empty when flexible_skill_count > 0",
                    value=None
                ))

            if requirement.flexible_skill_count > len(requirement.flexible_skill_pool):
                errors.append(TriggerValidationError(
                    field=f"{path}.flexible_skill_count",
                    message="flexible_skill_count cannot exceed size of flexible_skill_pool",
                    value=str(requirement.flexible_skill_count)
                ))

            # Validate skill IDs in pool
            if self.valid_skill_ids is not None:
                for skill_id in requirement.flexible_skill_pool:
                    if skill_id not in self.valid_skill_ids:
                        warnings.append(
                            f"{path}.flexible_skill_pool: Skill ID '{skill_id}' does not exist"
                        )

        return TriggerValidationResult(
            is_valid=len(errors) == 0,
            errors=errors,
            warnings=warnings
        )

    def _validate_reference(
        self,
        condition: TriggerCondition,
        path: str
    ) -> Optional[TriggerValidationError]:
        """Validate that target_id references an existing entity."""
        trigger_type = condition.trigger_type
        target_id = condition.target_id

        # Map trigger types to their valid ID sets
        type_to_ids = {
            TriggerType.VOCAB_USED_CORRECTLY: self.valid_vocab_ids,
            TriggerType.VOCAB_RECOGNIZED: self.valid_vocab_ids,
            TriggerType.GRAMMAR_USED_CORRECTLY: self.valid_grammar_ids,
            TriggerType.GRAMMAR_PATTERN_PRODUCED: self.valid_grammar_ids,
            TriggerType.SKILL_DEMONSTRATED: self.valid_skill_ids,
            TriggerType.SKILL_LEVEL_REACHED: self.valid_skill_ids,
            TriggerType.QUEST_COMPLETED: self.valid_quest_ids,
            TriggerType.NPC_INTERACTION: self.valid_npc_ids,
            TriggerType.LOCATION_VISITED: self.valid_location_ids,
            TriggerType.ITEM_ACQUIRED: self.valid_item_ids,
        }

        valid_ids = type_to_ids.get(trigger_type)

        # Skip if no validation set provided for this type
        if valid_ids is None:
            return None

        if target_id not in valid_ids:
            return TriggerValidationError(
                field=f"{path}.target_id",
                message=f"Target ID '{target_id}' not found for trigger type '{trigger_type.value}'",
                value=target_id
            )

        return None

    def _validate_semantics(
        self,
        condition: TriggerCondition,
        path: str
    ) -> List[str]:
        """Validate semantic correctness of a condition."""
        warnings = []

        # Quest completion should typically use == 1
        if condition.trigger_type == TriggerType.QUEST_COMPLETED:
            if condition.operator not in [TriggerOperator.EQUAL, TriggerOperator.GREATER_EQUAL]:
                warnings.append(
                    f"{path}: Quest completion typically uses '==' or '>=' operator"
                )
            if condition.threshold != 1 and condition.operator == TriggerOperator.EQUAL:
                warnings.append(
                    f"{path}: Quest completion threshold is typically 1"
                )

        # Skill level thresholds should be 0-100
        if condition.trigger_type == TriggerType.SKILL_LEVEL_REACHED:
            if condition.threshold > 100:
                warnings.append(
                    f"{path}: Skill level threshold exceeds maximum (100)"
                )

        # Total skill points should be 0-1000
        if condition.trigger_type == TriggerType.TOTAL_SKILL_POINTS:
            if condition.threshold > 1000:
                warnings.append(
                    f"{path}: Total skill points threshold exceeds maximum (1000)"
                )

        return warnings

    @staticmethod
    def parse_trigger_string(s: str) -> Union[TriggerCondition, None]:
        """
        Parse a trigger condition from string format.

        Format: trigger_type:target_id operator threshold
        Example: "vocab_used_correctly:hola >= 3"

        Returns None if parsing fails.
        """
        try:
            return TriggerCondition.from_string(s)
        except (ValueError, KeyError):
            return None

    @staticmethod
    def validate_trigger_string(s: str) -> TriggerValidationResult:
        """Validate a trigger condition in string format."""
        condition = TriggerValidator.parse_trigger_string(s)
        if condition is None:
            return TriggerValidationResult(
                is_valid=False,
                errors=[TriggerValidationError(
                    field="format",
                    message=f"Invalid trigger string format: {s}",
                    value=s
                )]
            )

        validator = TriggerValidator()
        return validator.validate_trigger_condition(condition)

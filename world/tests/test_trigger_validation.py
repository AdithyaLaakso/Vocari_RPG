"""
Tests for Trigger Validation System

Tests the TriggerValidator and related models to ensure:
1. Valid trigger formats are accepted (positive tests)
2. Invalid trigger formats are rejected (negative tests)
3. Semantic validation catches logical issues
"""

import pytest
from generators.trigger_validator import TriggerValidator
from generators.models import (
    TriggerCondition,
    CompoundTrigger,
    TriggerType,
    TriggerOperator,
    CompoundLogic,
    SkillProgressionTrigger,
    LevelProgressionRequirement,
    SkillThreshold,
    LanguageLevel,
)


# === Test Fixtures ===

@pytest.fixture
def valid_skill_ids():
    """Sample valid skill IDs."""
    return {
        "vocab_greetings_basic",
        "vocab_numbers_1_10",
        "grammar_present_ar",
        "grammar_articles",
        "pragmatic_greetings",
    }


@pytest.fixture
def valid_vocab_ids():
    """Sample valid vocabulary IDs."""
    return {"hola", "adios", "buenos_dias", "gracias", "por_favor"}


@pytest.fixture
def valid_grammar_ids():
    """Sample valid grammar pattern IDs."""
    return {"present_ar", "present_er", "articles", "negation", "questions"}


@pytest.fixture
def valid_quest_ids():
    """Sample valid quest IDs."""
    return {"quest_1_market_herbs", "quest_2_delivery", "quest_3_greet_villagers"}


@pytest.fixture
def validator(valid_skill_ids, valid_vocab_ids, valid_grammar_ids, valid_quest_ids):
    """Create a validator with sample data."""
    return TriggerValidator(
        valid_skill_ids=valid_skill_ids,
        valid_vocab_ids=valid_vocab_ids,
        valid_grammar_ids=valid_grammar_ids,
        valid_quest_ids=valid_quest_ids,
    )


@pytest.fixture
def validator_no_refs():
    """Create a validator without reference validation (for format-only tests)."""
    return TriggerValidator()


# =============================================================================
# POSITIVE TESTS - Valid Formats Should Be Accepted
# =============================================================================

class TestValidTriggerConditions:
    """Tests for valid trigger condition formats."""

    def test_valid_vocab_trigger(self, validator):
        """Valid vocabulary trigger should pass validation."""
        condition = TriggerCondition(
            trigger_type=TriggerType.VOCAB_USED_CORRECTLY,
            target_id="hola",
            operator=TriggerOperator.GREATER_EQUAL,
            threshold=3
        )
        result = validator.validate_trigger_condition(condition)
        assert result.is_valid, f"Expected valid, got errors: {result.errors}"

    def test_valid_grammar_trigger(self, validator):
        """Valid grammar trigger should pass validation."""
        condition = TriggerCondition(
            trigger_type=TriggerType.GRAMMAR_USED_CORRECTLY,
            target_id="present_ar",
            operator=TriggerOperator.GREATER_EQUAL,
            threshold=5
        )
        result = validator.validate_trigger_condition(condition)
        assert result.is_valid, f"Expected valid, got errors: {result.errors}"

    def test_valid_quest_completion_trigger(self, validator):
        """Valid quest completion trigger should pass validation."""
        condition = TriggerCondition(
            trigger_type=TriggerType.QUEST_COMPLETED,
            target_id="quest_1_market_herbs",
            operator=TriggerOperator.EQUAL,
            threshold=1
        )
        result = validator.validate_trigger_condition(condition)
        assert result.is_valid, f"Expected valid, got errors: {result.errors}"

    def test_valid_skill_level_trigger(self, validator):
        """Valid skill level trigger should pass validation."""
        condition = TriggerCondition(
            trigger_type=TriggerType.SKILL_LEVEL_REACHED,
            target_id="vocab_greetings_basic",
            operator=TriggerOperator.GREATER_EQUAL,
            threshold=50
        )
        result = validator.validate_trigger_condition(condition)
        assert result.is_valid, f"Expected valid, got errors: {result.errors}"

    def test_all_operators_valid(self, validator_no_refs):
        """All comparison operators should be valid."""
        for op in TriggerOperator:
            condition = TriggerCondition(
                trigger_type=TriggerType.VOCAB_USED_CORRECTLY,
                target_id="test_word",
                operator=op,
                threshold=5
            )
            result = validator_no_refs.validate_trigger_condition(condition)
            assert result.is_valid, f"Operator {op} should be valid"

    def test_all_trigger_types_valid(self, validator_no_refs):
        """All trigger types should be valid."""
        for tt in TriggerType:
            condition = TriggerCondition(
                trigger_type=tt,
                target_id="test_id",
                operator=TriggerOperator.GREATER_EQUAL,
                threshold=1
            )
            result = validator_no_refs.validate_trigger_condition(condition)
            assert result.is_valid, f"Trigger type {tt} should be valid"

    def test_zero_threshold_valid(self, validator_no_refs):
        """Zero threshold should be valid."""
        condition = TriggerCondition(
            trigger_type=TriggerType.VOCAB_USED_CORRECTLY,
            target_id="test",
            operator=TriggerOperator.GREATER_THAN,
            threshold=0
        )
        result = validator_no_refs.validate_trigger_condition(condition)
        assert result.is_valid

    def test_target_id_with_underscores(self, validator_no_refs):
        """Target ID with underscores should be valid."""
        condition = TriggerCondition(
            trigger_type=TriggerType.VOCAB_USED_CORRECTLY,
            target_id="vocab_numbers_1_to_10",
            operator=TriggerOperator.GREATER_EQUAL,
            threshold=3
        )
        result = validator_no_refs.validate_trigger_condition(condition)
        assert result.is_valid

    def test_target_id_with_hyphens(self, validator_no_refs):
        """Target ID with hyphens should be valid."""
        condition = TriggerCondition(
            trigger_type=TriggerType.VOCAB_USED_CORRECTLY,
            target_id="vocab-numbers-basic",
            operator=TriggerOperator.GREATER_EQUAL,
            threshold=3
        )
        result = validator_no_refs.validate_trigger_condition(condition)
        assert result.is_valid

    def test_target_id_with_dots(self, validator_no_refs):
        """Target ID with dots should be valid."""
        condition = TriggerCondition(
            trigger_type=TriggerType.VOCAB_USED_CORRECTLY,
            target_id="grammar.present.ar",
            operator=TriggerOperator.GREATER_EQUAL,
            threshold=3
        )
        result = validator_no_refs.validate_trigger_condition(condition)
        assert result.is_valid


class TestValidCompoundTriggers:
    """Tests for valid compound trigger formats."""

    def test_simple_and_compound(self, validator):
        """Simple AND compound trigger should pass validation."""
        compound = CompoundTrigger(
            logic=CompoundLogic.AND,
            conditions=[
                TriggerCondition(
                    trigger_type=TriggerType.VOCAB_USED_CORRECTLY,
                    target_id="hola",
                    operator=TriggerOperator.GREATER_EQUAL,
                    threshold=3
                ),
                TriggerCondition(
                    trigger_type=TriggerType.VOCAB_USED_CORRECTLY,
                    target_id="adios",
                    operator=TriggerOperator.GREATER_EQUAL,
                    threshold=2
                ),
            ]
        )
        result = validator.validate_compound_trigger(compound)
        assert result.is_valid, f"Expected valid, got errors: {result.errors}"

    def test_simple_or_compound(self, validator):
        """Simple OR compound trigger should pass validation."""
        compound = CompoundTrigger(
            logic=CompoundLogic.OR,
            conditions=[
                TriggerCondition(
                    trigger_type=TriggerType.QUEST_COMPLETED,
                    target_id="quest_1_market_herbs",
                    operator=TriggerOperator.EQUAL,
                    threshold=1
                ),
                TriggerCondition(
                    trigger_type=TriggerType.SKILL_LEVEL_REACHED,
                    target_id="vocab_greetings_basic",
                    operator=TriggerOperator.GREATER_EQUAL,
                    threshold=30
                ),
            ]
        )
        result = validator.validate_compound_trigger(compound)
        assert result.is_valid

    def test_nested_compound(self, validator_no_refs):
        """Nested compound trigger should pass validation."""
        compound = CompoundTrigger(
            logic=CompoundLogic.AND,
            conditions=[
                TriggerCondition(
                    trigger_type=TriggerType.VOCAB_USED_CORRECTLY,
                    target_id="word1",
                    operator=TriggerOperator.GREATER_EQUAL,
                    threshold=5
                ),
                CompoundTrigger(
                    logic=CompoundLogic.OR,
                    conditions=[
                        TriggerCondition(
                            trigger_type=TriggerType.GRAMMAR_USED_CORRECTLY,
                            target_id="pattern1",
                            operator=TriggerOperator.GREATER_EQUAL,
                            threshold=3
                        ),
                        TriggerCondition(
                            trigger_type=TriggerType.GRAMMAR_USED_CORRECTLY,
                            target_id="pattern2",
                            operator=TriggerOperator.GREATER_EQUAL,
                            threshold=3
                        ),
                    ]
                ),
            ]
        )
        result = validator_no_refs.validate_compound_trigger(compound)
        assert result.is_valid


class TestValidSkillProgressionTriggers:
    """Tests for valid skill progression triggers."""

    def test_valid_skill_progression_trigger(self, validator):
        """Valid skill progression trigger should pass validation."""
        trigger = SkillProgressionTrigger(
            skill_id="vocab_greetings_basic",
            points_awarded=10,
            trigger=TriggerCondition(
                trigger_type=TriggerType.VOCAB_USED_CORRECTLY,
                target_id="hola",
                operator=TriggerOperator.GREATER_EQUAL,
                threshold=3
            ),
            repeatable=True,
            cooldown_interactions=5,
            description="Use greeting words 3 times"
        )
        result = validator.validate_skill_progression_trigger(trigger)
        assert result.is_valid, f"Expected valid, got errors: {result.errors}"

    def test_valid_non_repeatable_trigger(self, validator):
        """Non-repeatable trigger without cooldown should be valid."""
        trigger = SkillProgressionTrigger(
            skill_id="grammar_present_ar",
            points_awarded=25,
            trigger=TriggerCondition(
                trigger_type=TriggerType.GRAMMAR_USED_CORRECTLY,
                target_id="present_ar",
                operator=TriggerOperator.GREATER_EQUAL,
                threshold=10
            ),
            repeatable=False,
            cooldown_interactions=0,
            description="Master present tense -ar verbs"
        )
        result = validator.validate_skill_progression_trigger(trigger)
        assert result.is_valid

    def test_valid_compound_progression_trigger(self, validator):
        """Progression trigger with compound condition should be valid."""
        trigger = SkillProgressionTrigger(
            skill_id="pragmatic_greetings",
            points_awarded=15,
            trigger=CompoundTrigger(
                logic=CompoundLogic.AND,
                conditions=[
                    TriggerCondition(
                        trigger_type=TriggerType.VOCAB_USED_CORRECTLY,
                        target_id="hola",
                        operator=TriggerOperator.GREATER_EQUAL,
                        threshold=2
                    ),
                    TriggerCondition(
                        trigger_type=TriggerType.VOCAB_USED_CORRECTLY,
                        target_id="buenos_dias",
                        operator=TriggerOperator.GREATER_EQUAL,
                        threshold=2
                    ),
                ]
            ),
            repeatable=True,
            cooldown_interactions=10,
            description="Use multiple greeting words"
        )
        result = validator.validate_skill_progression_trigger(trigger)
        assert result.is_valid


class TestValidLevelProgressionRequirements:
    """Tests for valid level progression requirements."""

    def test_valid_a0_to_a0plus(self, validator):
        """Valid A0 to A0+ requirement should pass validation."""
        requirement = LevelProgressionRequirement(
            from_level=LanguageLevel.A0,
            to_level=LanguageLevel.A0_PLUS,
            minimum_total_skill_points=50,
            required_skill_thresholds=[
                SkillThreshold(skill_id="vocab_greetings_basic", minimum_level=20),
            ],
            flexible_skill_pool=["vocab_numbers_1_10", "grammar_articles"],
            flexible_skill_count=1,
            flexible_threshold=15,
            description="Basic familiarity with greetings"
        )
        result = validator.validate_level_progression_requirement(requirement)
        assert result.is_valid, f"Expected valid, got errors: {result.errors}"

    def test_valid_empty_flexible_pool(self, validator):
        """Requirement with empty flexible pool (count 0) should be valid."""
        requirement = LevelProgressionRequirement(
            from_level=LanguageLevel.A0,
            to_level=LanguageLevel.A0_PLUS,
            minimum_total_skill_points=50,
            required_skill_thresholds=[
                SkillThreshold(skill_id="vocab_greetings_basic", minimum_level=20),
            ],
            flexible_skill_pool=[],
            flexible_skill_count=0,
            flexible_threshold=0,
            description="Simple requirement"
        )
        result = validator.validate_level_progression_requirement(requirement)
        assert result.is_valid


class TestTriggerStringParsing:
    """Tests for trigger string parsing."""

    def test_parse_valid_string(self):
        """Valid trigger string should parse correctly."""
        s = "vocab_used_correctly:hola >= 3"
        condition = TriggerValidator.parse_trigger_string(s)
        assert condition is not None
        assert condition.trigger_type == TriggerType.VOCAB_USED_CORRECTLY
        assert condition.target_id == "hola"
        assert condition.operator == TriggerOperator.GREATER_EQUAL
        assert condition.threshold == 3

    def test_parse_all_operators(self):
        """All operators should parse correctly."""
        test_cases = [
            ("vocab_used_correctly:x >= 5", TriggerOperator.GREATER_EQUAL),
            ("vocab_used_correctly:x > 5", TriggerOperator.GREATER_THAN),
            ("vocab_used_correctly:x <= 5", TriggerOperator.LESS_EQUAL),
            ("vocab_used_correctly:x < 5", TriggerOperator.LESS_THAN),
            ("vocab_used_correctly:x == 5", TriggerOperator.EQUAL),
            ("vocab_used_correctly:x != 5", TriggerOperator.NOT_EQUAL),
        ]
        for s, expected_op in test_cases:
            condition = TriggerValidator.parse_trigger_string(s)
            assert condition is not None, f"Failed to parse: {s}"
            assert condition.operator == expected_op, f"Wrong operator for: {s}"

    def test_validate_valid_string(self):
        """Valid trigger string should pass validation."""
        s = "grammar_used_correctly:present_ar >= 5"
        result = TriggerValidator.validate_trigger_string(s)
        assert result.is_valid


# =============================================================================
# NEGATIVE TESTS - Invalid Formats Should Be Rejected
# =============================================================================

class TestInvalidTriggerConditions:
    """Tests for invalid trigger condition formats."""

    def test_empty_target_id(self, validator_no_refs):
        """Empty target ID should fail validation."""
        condition = TriggerCondition(
            trigger_type=TriggerType.VOCAB_USED_CORRECTLY,
            target_id="",
            operator=TriggerOperator.GREATER_EQUAL,
            threshold=3
        )
        result = validator_no_refs.validate_trigger_condition(condition)
        assert not result.is_valid
        assert any("empty" in e.message.lower() for e in result.errors)

    def test_whitespace_only_target_id(self, validator_no_refs):
        """Whitespace-only target ID should fail validation."""
        condition = TriggerCondition(
            trigger_type=TriggerType.VOCAB_USED_CORRECTLY,
            target_id="   ",
            operator=TriggerOperator.GREATER_EQUAL,
            threshold=3
        )
        result = validator_no_refs.validate_trigger_condition(condition)
        assert not result.is_valid

    def test_invalid_characters_in_target_id(self, validator_no_refs):
        """Target ID with invalid characters should fail validation."""
        invalid_ids = ["hello world", "test@id", "id#123", "test$var"]
        for invalid_id in invalid_ids:
            condition = TriggerCondition(
                trigger_type=TriggerType.VOCAB_USED_CORRECTLY,
                target_id=invalid_id,
                operator=TriggerOperator.GREATER_EQUAL,
                threshold=3
            )
            result = validator_no_refs.validate_trigger_condition(condition)
            assert not result.is_valid, f"Should reject target_id: {invalid_id}"

    def test_negative_threshold(self, validator_no_refs):
        """Negative threshold should fail at Pydantic level."""
        with pytest.raises(Exception):  # Pydantic validation error
            TriggerCondition(
                trigger_type=TriggerType.VOCAB_USED_CORRECTLY,
                target_id="test",
                operator=TriggerOperator.GREATER_EQUAL,
                threshold=-1
            )

    def test_nonexistent_vocab_reference(self, validator):
        """Reference to non-existent vocabulary should fail validation."""
        condition = TriggerCondition(
            trigger_type=TriggerType.VOCAB_USED_CORRECTLY,
            target_id="nonexistent_word",
            operator=TriggerOperator.GREATER_EQUAL,
            threshold=3
        )
        result = validator.validate_trigger_condition(condition)
        assert not result.is_valid
        assert any("not found" in e.message.lower() for e in result.errors)

    def test_nonexistent_skill_reference(self, validator):
        """Reference to non-existent skill should fail validation."""
        condition = TriggerCondition(
            trigger_type=TriggerType.SKILL_LEVEL_REACHED,
            target_id="nonexistent_skill",
            operator=TriggerOperator.GREATER_EQUAL,
            threshold=50
        )
        result = validator.validate_trigger_condition(condition)
        assert not result.is_valid

    def test_nonexistent_quest_reference(self, validator):
        """Reference to non-existent quest should fail validation."""
        condition = TriggerCondition(
            trigger_type=TriggerType.QUEST_COMPLETED,
            target_id="quest_nonexistent",
            operator=TriggerOperator.EQUAL,
            threshold=1
        )
        result = validator.validate_trigger_condition(condition)
        assert not result.is_valid


class TestInvalidCompoundTriggers:
    """Tests for invalid compound trigger formats."""

    def test_empty_conditions(self, validator_no_refs):
        """Compound trigger with empty conditions should fail."""
        with pytest.raises(Exception):  # Pydantic validation requires min 1 condition
            CompoundTrigger(
                logic=CompoundLogic.AND,
                conditions=[]
            )

    def test_deeply_nested_exceeds_max_depth(self, validator_no_refs):
        """Deeply nested compound trigger should fail max depth check."""
        # Create a deeply nested structure (6 levels)
        def make_nested(depth):
            if depth == 0:
                return TriggerCondition(
                    trigger_type=TriggerType.VOCAB_USED_CORRECTLY,
                    target_id="word",
                    operator=TriggerOperator.GREATER_EQUAL,
                    threshold=1
                )
            return CompoundTrigger(
                logic=CompoundLogic.AND,
                conditions=[make_nested(depth - 1)]
            )

        deeply_nested = make_nested(6)
        result = validator_no_refs.validate_compound_trigger(deeply_nested, max_depth=5)
        assert not result.is_valid
        assert any("depth" in e.message.lower() for e in result.errors)

    def test_invalid_condition_in_compound(self, validator):
        """Compound with invalid condition should fail validation."""
        compound = CompoundTrigger(
            logic=CompoundLogic.AND,
            conditions=[
                TriggerCondition(
                    trigger_type=TriggerType.VOCAB_USED_CORRECTLY,
                    target_id="hola",  # Valid
                    operator=TriggerOperator.GREATER_EQUAL,
                    threshold=3
                ),
                TriggerCondition(
                    trigger_type=TriggerType.VOCAB_USED_CORRECTLY,
                    target_id="nonexistent",  # Invalid
                    operator=TriggerOperator.GREATER_EQUAL,
                    threshold=3
                ),
            ]
        )
        result = validator.validate_compound_trigger(compound)
        assert not result.is_valid


class TestInvalidSkillProgressionTriggers:
    """Tests for invalid skill progression triggers."""

    def test_invalid_skill_id(self, validator):
        """Progression trigger with invalid skill ID should fail."""
        trigger = SkillProgressionTrigger(
            skill_id="nonexistent_skill",
            points_awarded=10,
            trigger=TriggerCondition(
                trigger_type=TriggerType.VOCAB_USED_CORRECTLY,
                target_id="hola",
                operator=TriggerOperator.GREATER_EQUAL,
                threshold=3
            ),
            repeatable=True,
            cooldown_interactions=5,
            description="Test"
        )
        result = validator.validate_skill_progression_trigger(trigger)
        assert not result.is_valid
        assert any("does not exist" in e.message.lower() for e in result.errors)

    def test_invalid_skill_id_format(self, validator_no_refs):
        """Progression trigger with invalid skill ID format should fail."""
        trigger = SkillProgressionTrigger(
            skill_id="invalid skill id",  # Contains space
            points_awarded=10,
            trigger=TriggerCondition(
                trigger_type=TriggerType.VOCAB_USED_CORRECTLY,
                target_id="test",
                operator=TriggerOperator.GREATER_EQUAL,
                threshold=3
            ),
            repeatable=True,
            cooldown_interactions=5,
            description="Test"
        )
        result = validator_no_refs.validate_skill_progression_trigger(trigger)
        assert not result.is_valid

    def test_points_awarded_too_high(self, validator_no_refs):
        """Points awarded > 100 should fail at Pydantic level."""
        with pytest.raises(Exception):
            SkillProgressionTrigger(
                skill_id="test_skill",
                points_awarded=101,
                trigger=TriggerCondition(
                    trigger_type=TriggerType.VOCAB_USED_CORRECTLY,
                    target_id="test",
                    operator=TriggerOperator.GREATER_EQUAL,
                    threshold=3
                ),
                repeatable=True,
                cooldown_interactions=5,
                description="Test"
            )

    def test_points_awarded_zero(self, validator_no_refs):
        """Points awarded = 0 should fail at Pydantic level."""
        with pytest.raises(Exception):
            SkillProgressionTrigger(
                skill_id="test_skill",
                points_awarded=0,
                trigger=TriggerCondition(
                    trigger_type=TriggerType.VOCAB_USED_CORRECTLY,
                    target_id="test",
                    operator=TriggerOperator.GREATER_EQUAL,
                    threshold=3
                ),
                repeatable=True,
                cooldown_interactions=5,
                description="Test"
            )


class TestInvalidLevelProgressionRequirements:
    """Tests for invalid level progression requirements."""

    def test_non_sequential_levels(self, validator):
        """Skipping levels (A0 -> A1) should fail validation."""
        requirement = LevelProgressionRequirement(
            from_level=LanguageLevel.A0,
            to_level=LanguageLevel.A1,  # Should be A0+
            minimum_total_skill_points=100,
            required_skill_thresholds=[],
            description="Invalid progression"
        )
        result = validator.validate_level_progression_requirement(requirement)
        assert not result.is_valid
        assert any("sequential" in e.message.lower() for e in result.errors)

    def test_backward_progression(self, validator):
        """Backward progression (A1 -> A0) should fail validation."""
        requirement = LevelProgressionRequirement(
            from_level=LanguageLevel.A1,
            to_level=LanguageLevel.A0,  # Backward!
            minimum_total_skill_points=50,
            required_skill_thresholds=[],
            description="Invalid backward progression"
        )
        result = validator.validate_level_progression_requirement(requirement)
        assert not result.is_valid

    def test_flexible_count_exceeds_pool(self, validator):
        """Flexible count > pool size should fail validation."""
        requirement = LevelProgressionRequirement(
            from_level=LanguageLevel.A0,
            to_level=LanguageLevel.A0_PLUS,
            minimum_total_skill_points=50,
            required_skill_thresholds=[],
            flexible_skill_pool=["skill1", "skill2"],
            flexible_skill_count=5,  # Exceeds pool size of 2!
            flexible_threshold=20,
            description="Invalid flexible config"
        )
        result = validator.validate_level_progression_requirement(requirement)
        assert not result.is_valid
        assert any("exceed" in e.message.lower() for e in result.errors)

    def test_flexible_count_without_pool(self, validator):
        """Flexible count > 0 but empty pool should fail validation."""
        requirement = LevelProgressionRequirement(
            from_level=LanguageLevel.A0,
            to_level=LanguageLevel.A0_PLUS,
            minimum_total_skill_points=50,
            required_skill_thresholds=[],
            flexible_skill_pool=[],
            flexible_skill_count=2,  # > 0 but pool is empty!
            flexible_threshold=20,
            description="Invalid flexible config"
        )
        result = validator.validate_level_progression_requirement(requirement)
        assert not result.is_valid
        assert any("empty" in e.message.lower() for e in result.errors)

    def test_invalid_skill_threshold_level(self, validator):
        """Skill threshold level > 100 should fail at Pydantic level."""
        with pytest.raises(Exception):
            SkillThreshold(skill_id="test", minimum_level=150)


class TestInvalidTriggerStrings:
    """Tests for invalid trigger string parsing."""

    def test_missing_colon(self):
        """String without colon should fail parsing."""
        s = "vocab_used_correctly_hola >= 3"
        condition = TriggerValidator.parse_trigger_string(s)
        assert condition is None

    def test_missing_operator(self):
        """String without operator should fail parsing."""
        s = "vocab_used_correctly:hola 3"
        condition = TriggerValidator.parse_trigger_string(s)
        assert condition is None

    def test_missing_threshold(self):
        """String without threshold should fail parsing."""
        s = "vocab_used_correctly:hola >="
        condition = TriggerValidator.parse_trigger_string(s)
        assert condition is None

    def test_invalid_trigger_type(self):
        """String with invalid trigger type should fail parsing."""
        s = "invalid_type:hola >= 3"
        condition = TriggerValidator.parse_trigger_string(s)
        assert condition is None

    def test_invalid_operator(self):
        """String with invalid operator should fail parsing."""
        s = "vocab_used_correctly:hola =~ 3"
        condition = TriggerValidator.parse_trigger_string(s)
        assert condition is None

    def test_non_numeric_threshold(self):
        """String with non-numeric threshold should fail parsing."""
        s = "vocab_used_correctly:hola >= abc"
        condition = TriggerValidator.parse_trigger_string(s)
        assert condition is None

    def test_empty_string(self):
        """Empty string should fail parsing."""
        condition = TriggerValidator.parse_trigger_string("")
        assert condition is None

    def test_whitespace_string(self):
        """Whitespace-only string should fail parsing."""
        condition = TriggerValidator.parse_trigger_string("   ")
        assert condition is None


# =============================================================================
# SEMANTIC VALIDATION TESTS
# =============================================================================

class TestSemanticValidation:
    """Tests for semantic validation (warnings)."""

    def test_quest_completion_unusual_operator_warning(self, validator):
        """Quest completion with < operator should generate warning."""
        condition = TriggerCondition(
            trigger_type=TriggerType.QUEST_COMPLETED,
            target_id="quest_1_market_herbs",
            operator=TriggerOperator.LESS_THAN,  # Unusual for quest completion
            threshold=1
        )
        result = validator.validate_trigger_condition(condition)
        # Should be valid but with warnings
        assert result.is_valid
        assert len(result.warnings) > 0

    def test_skill_level_exceeds_max_warning(self, validator_no_refs):
        """Skill level threshold > 100 should generate warning."""
        condition = TriggerCondition(
            trigger_type=TriggerType.SKILL_LEVEL_REACHED,
            target_id="test_skill",
            operator=TriggerOperator.GREATER_EQUAL,
            threshold=150  # Exceeds max skill level
        )
        result = validator_no_refs.validate_trigger_condition(condition)
        assert result.is_valid  # Format is valid
        assert len(result.warnings) > 0  # But has semantic warning

    def test_total_skill_points_exceeds_cap_warning(self, validator_no_refs):
        """Total skill points > 1000 should generate warning."""
        condition = TriggerCondition(
            trigger_type=TriggerType.TOTAL_SKILL_POINTS,
            target_id="total",
            operator=TriggerOperator.GREATER_EQUAL,
            threshold=1500  # Exceeds max total
        )
        result = validator_no_refs.validate_trigger_condition(condition)
        assert result.is_valid
        assert len(result.warnings) > 0

    def test_cooldown_on_non_repeatable_warning(self, validator):
        """Cooldown on non-repeatable trigger should generate warning."""
        trigger = SkillProgressionTrigger(
            skill_id="vocab_greetings_basic",
            points_awarded=10,
            trigger=TriggerCondition(
                trigger_type=TriggerType.VOCAB_USED_CORRECTLY,
                target_id="hola",
                operator=TriggerOperator.GREATER_EQUAL,
                threshold=3
            ),
            repeatable=False,  # Not repeatable
            cooldown_interactions=5,  # But has cooldown
            description="Test"
        )
        result = validator.validate_skill_progression_trigger(trigger)
        assert result.is_valid  # Valid format
        assert len(result.warnings) > 0  # But has warning


# =============================================================================
# DICT INPUT TESTS
# =============================================================================

class TestDictInput:
    """Tests for validation with dict input (as would come from JSON)."""

    def test_valid_condition_from_dict(self, validator_no_refs):
        """Valid condition as dict should pass validation."""
        condition_dict = {
            "trigger_type": "vocab_used_correctly",
            "target_id": "test_word",
            "operator": ">=",
            "threshold": 3
        }
        result = validator_no_refs.validate_trigger_condition(condition_dict)
        assert result.is_valid

    def test_invalid_condition_from_dict(self, validator_no_refs):
        """Invalid condition as dict should fail validation."""
        condition_dict = {
            "trigger_type": "invalid_type",
            "target_id": "test",
            "operator": ">=",
            "threshold": 3
        }
        result = validator_no_refs.validate_trigger_condition(condition_dict)
        assert not result.is_valid

    def test_missing_required_field_dict(self, validator_no_refs):
        """Dict missing required field should fail validation."""
        condition_dict = {
            "trigger_type": "vocab_used_correctly",
            # Missing target_id
            "operator": ">=",
            "threshold": 3
        }
        result = validator_no_refs.validate_trigger_condition(condition_dict)
        assert not result.is_valid

    def test_compound_trigger_from_dict(self, validator_no_refs):
        """Compound trigger as dict should pass validation."""
        compound_dict = {
            "logic": "AND",
            "conditions": [
                {
                    "trigger_type": "vocab_used_correctly",
                    "target_id": "word1",
                    "operator": ">=",
                    "threshold": 3
                },
                {
                    "trigger_type": "vocab_used_correctly",
                    "target_id": "word2",
                    "operator": ">=",
                    "threshold": 2
                }
            ]
        }
        result = validator_no_refs.validate_compound_trigger(compound_dict)
        assert result.is_valid

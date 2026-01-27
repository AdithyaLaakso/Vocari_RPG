"""
Tests for QuestValidator

Each test creates a specific scenario that should trigger a validation rule.
"""

import pytest
from generators.quest_validator import (
    QuestValidator,
    ValidationSeverity,
    ValidationIssue
)


# === Test Fixtures ===

@pytest.fixture
def sample_locations():
    """Sample locations for testing."""
    return {
        "locations": [
            {"id": "market", "name": {"native_language": "Market", "target_language": "Mercado"}, "minimum_language_level": "A0", "connections": ["plaza", "forest"]},
            {"id": "forest", "name": {"native_language": "Forest", "target_language": "Bosque"}, "minimum_language_level": "A0", "connections": ["market", "garden"]},
            {"id": "garden", "name": {"native_language": "Garden", "target_language": "Jardín"}, "minimum_language_level": "A0+", "connections": ["forest", "bakery"]},
            {"id": "bakery", "name": {"native_language": "Bakery", "target_language": "Panadería"}, "minimum_language_level": "A1", "connections": ["garden", "plaza"]},
            {"id": "plaza", "name": {"native_language": "Plaza", "target_language": "Plaza"}, "minimum_language_level": "A0", "connections": ["market", "bakery"]},
        ]
    }


@pytest.fixture
def sample_npcs():
    """Sample NPCs for testing."""
    return {
        "npcs": [
            {"id": "maria", "name": {"native_language": "Maria", "target_language": "María"}, "location_id": "market", "language_level": "A0"},
            {"id": "juan", "name": {"native_language": "Juan", "target_language": "Juan"}, "location_id": "bakery", "language_level": "A1"},
            {"id": "rosa", "name": {"native_language": "Rosa", "target_language": "Rosa"}, "location_id": "garden", "language_level": "A0+"},
            {"id": "pedro", "name": {"native_language": "Pedro", "target_language": "Pedro"}, "location_id": "forest", "language_level": "A0"},
        ]
    }


@pytest.fixture
def sample_items():
    """Sample items for testing."""
    return {
        "items": [
            {"id": "apple", "name": {"native_language": "Apple", "target_language": "Manzana"}, "location_id": "market", "acquisition_type": "purchase"},
            {"id": "bread", "name": {"native_language": "Bread", "target_language": "Pan"}, "location_id": "bakery", "acquisition_type": "purchase"},
            {"id": "herbs", "name": {"native_language": "Herbs", "target_language": "Hierbas"}, "location_id": "forest", "acquisition_type": "gather"},
            {"id": "flowers", "name": {"native_language": "Flowers", "target_language": "Flores"}, "location_id": "garden", "acquisition_type": "gather"},
            {"id": "letter", "name": {"native_language": "Letter", "target_language": "Carta"}, "location_id": "plaza", "acquisition_type": "receive"},
        ]
    }


@pytest.fixture
def sample_world_map(sample_locations):
    """Sample world map with connections and starting location."""
    return {
        "starting_location": "market",
        "locations": sample_locations["locations"],
        "connections": [
            {"from_location": "market", "to_location": "plaza", "bidirectional": True},
            {"from_location": "market", "to_location": "forest", "bidirectional": True},
            {"from_location": "forest", "to_location": "garden", "bidirectional": True},
            {"from_location": "garden", "to_location": "bakery", "bidirectional": True},
            {"from_location": "plaza", "to_location": "bakery", "bidirectional": True},
        ]
    }


@pytest.fixture
def validator(sample_locations, sample_npcs, sample_items, sample_world_map):
    """Create a validator with sample data."""
    return QuestValidator(sample_locations, sample_npcs, sample_items, sample_world_map)


@pytest.fixture
def validator_no_map(sample_locations, sample_npcs, sample_items):
    """Create a validator without world map (tests backwards compatibility)."""
    return QuestValidator(sample_locations, sample_npcs, sample_items)


# === Rule 1: No Auto-Complete First Task ===

class TestNoAutoCompleteFirstTask:
    """Tests for the no_auto_complete_first_task rule."""

    def test_first_task_at_quest_giver_location_is_error(self, validator):
        """First task being at_location where quest giver is should be ERROR."""
        quest = {
            "id": "test_quest",
            "giver_npc_id": "maria",  # Maria is at market
            "tasks": [
                {
                    "id": "task1",
                    "order": 1,
                    "completion_type": "at_location",
                    "completion_criteria": {"target_id": "market"}  # Same as Maria's location!
                }
            ]
        }
        issues = validator._rule_no_auto_complete_first_task(quest)
        assert len(issues) >= 1
        assert any(i.severity == ValidationSeverity.ERROR for i in issues)
        assert any("auto-completes" in i.message.lower() for i in issues)

    def test_first_task_at_different_location_is_ok(self, validator):
        """First task being at_location different from quest giver should be OK."""
        quest = {
            "id": "test_quest",
            "giver_npc_id": "maria",  # Maria is at market
            "tasks": [
                {
                    "id": "task1",
                    "order": 1,
                    "completion_type": "at_location",
                    "completion_criteria": {"target_id": "forest"}  # Different location
                }
            ]
        }
        issues = validator._rule_no_auto_complete_first_task(quest)
        errors = [i for i in issues if i.severity == ValidationSeverity.ERROR]
        assert len(errors) == 0

    def test_first_task_talk_to_quest_giver_is_warning(self, validator):
        """First task being talk to quest giver should be WARNING."""
        quest = {
            "id": "test_quest",
            "giver_npc_id": "maria",
            "tasks": [
                {
                    "id": "task1",
                    "order": 1,
                    "completion_type": "talked_to",
                    "completion_criteria": {"target_id": "maria"}  # Same as quest giver
                }
            ]
        }
        issues = validator._rule_no_auto_complete_first_task(quest)
        assert len(issues) >= 1
        assert any(i.severity == ValidationSeverity.WARNING for i in issues)


# === Rule 2: NPC Diversity ===

class TestNPCDiversity:
    """Tests for the npc_diversity rule."""

    def test_all_interactions_same_npc_is_error(self, validator):
        """All NPC interactions with same NPC should be ERROR."""
        quest = {
            "id": "test_quest",
            "giver_npc_id": "maria",
            "tasks": [
                {"id": "task1", "order": 1, "completion_type": "talked_to", "completion_criteria": {"target_id": "maria"}},
                {"id": "task2", "order": 2, "completion_type": "gave_item", "completion_criteria": {"target_id": "apple"}},
                {"id": "task3", "order": 3, "completion_type": "talked_to", "completion_criteria": {"target_id": "maria"}},
                {"id": "task4", "order": 4, "completion_type": "received_item", "completion_criteria": {"target_id": "bread"}},
            ]
        }
        issues = validator._rule_npc_diversity(quest)
        errors = [i for i in issues if i.severity == ValidationSeverity.ERROR]
        assert len(errors) >= 1
        assert any("all" in i.message.lower() and "interactions" in i.message.lower() for i in issues)

    def test_three_consecutive_same_npc_is_warning(self, validator):
        """3+ consecutive interactions with same NPC should be WARNING."""
        quest = {
            "id": "test_quest",
            "giver_npc_id": "juan",
            "tasks": [
                {"id": "task1", "order": 1, "completion_type": "talked_to", "completion_criteria": {"target_id": "maria"}},
                {"id": "task2", "order": 2, "completion_type": "talked_to", "completion_criteria": {"target_id": "maria"}},
                {"id": "task3", "order": 3, "completion_type": "talked_to", "completion_criteria": {"target_id": "maria"}},
                {"id": "task4", "order": 4, "completion_type": "talked_to", "completion_criteria": {"target_id": "juan"}},
            ]
        }
        issues = validator._rule_npc_diversity(quest)
        warnings = [i for i in issues if i.severity == ValidationSeverity.WARNING]
        assert len(warnings) >= 1

    def test_diverse_npcs_is_ok(self, validator):
        """Interactions with different NPCs should be OK."""
        quest = {
            "id": "test_quest",
            "giver_npc_id": "maria",
            "tasks": [
                {"id": "task1", "order": 1, "completion_type": "talked_to", "completion_criteria": {"target_id": "maria"}},
                {"id": "task2", "order": 2, "completion_type": "talked_to", "completion_criteria": {"target_id": "juan"}},
                {"id": "task3", "order": 3, "completion_type": "talked_to", "completion_criteria": {"target_id": "rosa"}},
            ]
        }
        issues = validator._rule_npc_diversity(quest)
        errors = [i for i in issues if i.severity == ValidationSeverity.ERROR]
        assert len(errors) == 0


# === Rule 3: Item Location Consistency ===

class TestItemLocationConsistency:
    """Tests for the item_location_consistency rule."""

    def test_nonexistent_item_is_error(self, validator):
        """Referencing non-existent item should be ERROR."""
        quest = {
            "id": "test_quest",
            "giver_npc_id": "maria",
            "tasks": [
                {
                    "id": "task1",
                    "order": 1,
                    "completion_type": "has_item",
                    "completion_criteria": {"target_id": "magic_sword"}  # Doesn't exist
                }
            ]
        }
        issues = validator._rule_item_location_consistency(quest)
        errors = [i for i in issues if i.severity == ValidationSeverity.ERROR]
        assert len(errors) >= 1
        assert any("does not exist" in i.message for i in errors)

    def test_valid_item_is_ok(self, validator):
        """Referencing valid item should be OK."""
        quest = {
            "id": "test_quest",
            "giver_npc_id": "maria",
            "tasks": [
                {
                    "id": "task1",
                    "order": 1,
                    "completion_type": "has_item",
                    "completion_criteria": {"target_id": "apple"}  # Exists at market
                }
            ]
        }
        issues = validator._rule_item_location_consistency(quest)
        errors = [i for i in issues if i.severity == ValidationSeverity.ERROR]
        assert len(errors) == 0


# === Rule 3b: Item at Wrong Location (THE BUG) ===

class TestItemAtWrongLocation:
    """Tests for item being at wrong location in quest flow."""

    def test_go_to_location_then_get_item_not_there_is_error(self, validator):
        """Going to location X then getting item Y (which is at Z) should be ERROR."""
        quest = {
            "id": "test_quest",
            "giver_npc_id": "maria",
            "tasks": [
                {
                    "id": "task1",
                    "order": 1,
                    "completion_type": "at_location",
                    "completion_criteria": {"target_id": "garden"}  # Go to garden
                },
                {
                    "id": "task2",
                    "order": 2,
                    "completion_type": "has_item",
                    "completion_criteria": {"target_id": "apple"}  # Get apple - but apple is at MARKET, not garden!
                }
            ]
        }
        issues = validator._rule_item_at_correct_location(quest)
        errors = [i for i in issues if i.severity == ValidationSeverity.ERROR]
        assert len(errors) >= 1
        # Check that error message indicates location mismatch
        assert any("implies" in i.message.lower() or "actually at" in i.message.lower() for i in errors)

    def test_go_to_location_then_get_item_there_is_ok(self, validator):
        """Going to location X then getting item Y (which is at X) should be OK."""
        quest = {
            "id": "test_quest",
            "giver_npc_id": "maria",
            "tasks": [
                {
                    "id": "task1",
                    "order": 1,
                    "completion_type": "at_location",
                    "completion_criteria": {"target_id": "garden"}  # Go to garden
                },
                {
                    "id": "task2",
                    "order": 2,
                    "completion_type": "has_item",
                    "completion_criteria": {"target_id": "flowers"}  # Get flowers - flowers ARE at garden
                }
            ]
        }
        issues = validator._rule_item_at_correct_location(quest)
        errors = [i for i in issues if i.severity == ValidationSeverity.ERROR]
        assert len(errors) == 0

    def test_get_item_with_no_prior_location_task_checks_item_exists(self, validator):
        """Getting item without going anywhere should at least verify item exists."""
        quest = {
            "id": "test_quest",
            "giver_npc_id": "maria",
            "tasks": [
                {
                    "id": "task1",
                    "order": 1,
                    "completion_type": "has_item",
                    "completion_criteria": {"target_id": "apple"}  # Valid item
                }
            ]
        }
        issues = validator._rule_item_at_correct_location(quest)
        # Should have INFO or WARNING that there's no location task, but not ERROR
        errors = [i for i in issues if i.severity == ValidationSeverity.ERROR]
        assert len(errors) == 0


# === Rule 4: Logical Item Flow ===

class TestLogicalItemFlow:
    """Tests for the logical_item_flow rule."""

    def test_give_item_before_getting_it_is_error(self, validator):
        """Giving item before obtaining it should be ERROR (if not gatherable)."""
        quest = {
            "id": "test_quest",
            "giver_npc_id": "maria",
            "tasks": [
                {
                    "id": "task1",
                    "order": 1,
                    "completion_type": "gave_item",
                    "completion_criteria": {"target_id": "letter"}  # Letter is "receive" type, can't just get it
                }
            ]
        }
        issues = validator._rule_logical_item_flow(quest)
        errors = [i for i in issues if i.severity == ValidationSeverity.ERROR]
        assert len(errors) >= 1

    def test_give_item_after_getting_it_is_ok(self, validator):
        """Giving item after obtaining it should be OK."""
        quest = {
            "id": "test_quest",
            "giver_npc_id": "maria",
            "tasks": [
                {
                    "id": "task1",
                    "order": 1,
                    "completion_type": "has_item",
                    "completion_criteria": {"target_id": "apple"}
                },
                {
                    "id": "task2",
                    "order": 2,
                    "completion_type": "gave_item",
                    "completion_criteria": {"target_id": "apple"}
                }
            ]
        }
        issues = validator._rule_logical_item_flow(quest)
        errors = [i for i in issues if i.severity == ValidationSeverity.ERROR]
        assert len(errors) == 0


# === Rule 5: No Immediate Item Return ===

class TestNoImmediateItemReturn:
    """Tests for the no_immediate_item_return rule."""

    def test_receive_then_give_back_same_is_error(self, validator):
        """Receiving item then immediately giving it back should be ERROR."""
        quest = {
            "id": "test_quest",
            "giver_npc_id": "maria",
            "tasks": [
                {"id": "task1", "order": 1, "completion_type": "talked_to", "completion_criteria": {"target_id": "maria"}},
                {"id": "task2", "order": 2, "completion_type": "received_item", "completion_criteria": {"target_id": "apple"}},
                {"id": "task3", "order": 3, "completion_type": "gave_item", "completion_criteria": {"target_id": "apple"}},
            ]
        }
        issues = validator._rule_no_immediate_item_return(quest)
        errors = [i for i in issues if i.severity == ValidationSeverity.ERROR]
        assert len(errors) >= 1

    def test_receive_then_give_different_item_is_ok(self, validator):
        """Receiving one item and giving a different one should be OK."""
        quest = {
            "id": "test_quest",
            "giver_npc_id": "maria",
            "tasks": [
                {"id": "task1", "order": 1, "completion_type": "received_item", "completion_criteria": {"target_id": "apple"}},
                {"id": "task2", "order": 2, "completion_type": "gave_item", "completion_criteria": {"target_id": "bread"}},
            ]
        }
        issues = validator._rule_no_immediate_item_return(quest)
        errors = [i for i in issues if i.severity == ValidationSeverity.ERROR]
        assert len(errors) == 0


# === Rule 6: Valid References ===

class TestValidReferences:
    """Tests for the valid_references rule."""

    def test_invalid_location_is_error(self, validator):
        """Referencing non-existent location should be ERROR."""
        quest = {
            "id": "test_quest",
            "giver_npc_id": "maria",
            "tasks": [
                {
                    "id": "task1",
                    "order": 1,
                    "completion_type": "at_location",
                    "completion_criteria": {"target_id": "castle"}  # Doesn't exist
                }
            ]
        }
        issues = validator._rule_valid_references(quest)
        errors = [i for i in issues if i.severity == ValidationSeverity.ERROR]
        assert len(errors) >= 1
        assert any("does not exist" in i.message for i in errors)

    def test_invalid_npc_is_error(self, validator):
        """Referencing non-existent NPC should be ERROR."""
        quest = {
            "id": "test_quest",
            "giver_npc_id": "maria",
            "tasks": [
                {
                    "id": "task1",
                    "order": 1,
                    "completion_type": "talked_to",
                    "completion_criteria": {"target_id": "king"}  # Doesn't exist
                }
            ]
        }
        issues = validator._rule_valid_references(quest)
        errors = [i for i in issues if i.severity == ValidationSeverity.ERROR]
        assert len(errors) >= 1

    def test_invalid_item_is_error(self, validator):
        """Referencing non-existent item should be ERROR."""
        quest = {
            "id": "test_quest",
            "giver_npc_id": "maria",
            "tasks": [
                {
                    "id": "task1",
                    "order": 1,
                    "completion_type": "has_item",
                    "completion_criteria": {"target_id": "diamond"}  # Doesn't exist
                }
            ]
        }
        issues = validator._rule_valid_references(quest)
        errors = [i for i in issues if i.severity == ValidationSeverity.ERROR]
        assert len(errors) >= 1

    def test_all_valid_references_is_ok(self, validator):
        """All valid references should be OK."""
        quest = {
            "id": "test_quest",
            "giver_npc_id": "maria",
            "tasks": [
                {"id": "task1", "order": 1, "completion_type": "at_location", "completion_criteria": {"target_id": "market"}},
                {"id": "task2", "order": 2, "completion_type": "talked_to", "completion_criteria": {"target_id": "maria"}},
                {"id": "task3", "order": 3, "completion_type": "has_item", "completion_criteria": {"target_id": "apple"}},
            ]
        }
        issues = validator._rule_valid_references(quest)
        errors = [i for i in issues if i.severity == ValidationSeverity.ERROR]
        assert len(errors) == 0


# === Rule 7: Valid Quest Giver ===

class TestValidQuestGiver:
    """Tests for the valid_quest_giver rule."""

    def test_invalid_quest_giver_is_error(self, validator):
        """Non-existent quest giver should be ERROR."""
        quest = {
            "id": "test_quest",
            "giver_npc_id": "ghost",  # Doesn't exist
            "tasks": []
        }
        issues = validator._rule_valid_quest_giver(quest)
        errors = [i for i in issues if i.severity == ValidationSeverity.ERROR]
        assert len(errors) >= 1

    def test_valid_quest_giver_is_ok(self, validator):
        """Existing quest giver should be OK."""
        quest = {
            "id": "test_quest",
            "giver_npc_id": "maria",
            "tasks": []
        }
        issues = validator._rule_valid_quest_giver(quest)
        errors = [i for i in issues if i.severity == ValidationSeverity.ERROR]
        assert len(errors) == 0


# === Rule 8: Logical Task Order ===

class TestLogicalTaskOrder:
    """Tests for the logical_task_order rule."""

    def test_talk_to_npc_without_going_to_location_is_info(self, validator):
        """Talking to NPC without prior location task should be INFO."""
        quest = {
            "id": "test_quest",
            "giver_npc_id": "maria",  # At market
            "tasks": [
                {
                    "id": "task1",
                    "order": 1,
                    "completion_type": "talked_to",
                    "completion_criteria": {"target_id": "juan"}  # Juan is at bakery, not market
                }
            ]
        }
        issues = validator._rule_logical_task_order(quest)
        infos = [i for i in issues if i.severity == ValidationSeverity.INFO]
        assert len(infos) >= 1


# === Integration Tests ===

class TestValidateAll:
    """Integration tests for validate_all."""

    def test_completely_valid_quest(self, validator):
        """A well-formed quest should have no errors."""
        quest = {
            "id": "valid_quest",
            "giver_npc_id": "maria",  # At market
            "tasks": [
                {"id": "task1", "order": 1, "completion_type": "at_location", "completion_criteria": {"target_id": "forest"}},
                {"id": "task2", "order": 2, "completion_type": "has_item", "completion_criteria": {"target_id": "herbs"}},  # herbs at forest
                {"id": "task3", "order": 3, "completion_type": "at_location", "completion_criteria": {"target_id": "market"}},
                {"id": "task4", "order": 4, "completion_type": "gave_item", "completion_criteria": {"target_id": "herbs"}},
            ]
        }
        quests_data = {"quests": [quest]}
        issues = validator.validate_all(quests_data)
        errors = [i for i in issues if i.severity == ValidationSeverity.ERROR]
        assert len(errors) == 0

    def test_multiple_invalid_quests(self, validator):
        """Multiple quests with issues should all be flagged."""
        quests_data = {
            "quests": [
                {
                    "id": "bad_quest_1",
                    "giver_npc_id": "ghost",  # Invalid
                    "tasks": []
                },
                {
                    "id": "bad_quest_2",
                    "giver_npc_id": "maria",
                    "tasks": [
                        {"id": "task1", "order": 1, "completion_type": "at_location", "completion_criteria": {"target_id": "market"}}  # Auto-complete
                    ]
                }
            ]
        }
        issues = validator.validate_all(quests_data)
        invalid_ids = validator.get_invalid_quest_ids(issues)
        assert "bad_quest_1" in invalid_ids
        assert "bad_quest_2" in invalid_ids


# === Real Bug Case: Flowers at Garden ===

class TestRealBugCase:
    """Test the actual bug reported by user."""

    def test_flowers_at_wrong_location_detected(self, validator):
        """
        Bug: Quest says 'get flowers at garden' but flowers aren't at garden.
        In our test data, flowers ARE at garden, so let's test the inverse.
        """
        # Let's say quest tells you to go to MARKET to get flowers, but flowers are at GARDEN
        quest = {
            "id": "flower_quest",
            "giver_npc_id": "maria",
            "tasks": [
                {
                    "id": "task1",
                    "order": 1,
                    "completion_type": "at_location",
                    "completion_criteria": {"target_id": "market"}  # Go to market
                },
                {
                    "id": "task2",
                    "order": 2,
                    "completion_type": "has_item",
                    "completion_criteria": {"target_id": "flowers"}  # Get flowers - but flowers are at GARDEN!
                }
            ]
        }
        issues = validator._rule_item_at_correct_location(quest)
        errors = [i for i in issues if i.severity == ValidationSeverity.ERROR]
        assert len(errors) >= 1, "Should detect that flowers are not at market"


# === Rule 12: Location Path Accessibility ===

class TestLocationPathAccessibility:
    """Tests for the location_path_accessibility rule (Rule 12)."""

    def test_a0_quest_to_a0_location_via_a0_path_is_ok(self, validator):
        """A0 quest targeting A0 location reachable via A0 path should be OK."""
        # market (A0) -> forest (A0): direct connection, all A0
        quest = {
            "id": "test_quest",
            "language_level": "A0",
            "giver_npc_id": "maria",  # At market (A0)
            "tasks": [
                {
                    "id": "task1",
                    "order": 1,
                    "completion_type": "at_location",
                    "completion_criteria": {"target_id": "forest"}  # A0 location, directly connected
                }
            ]
        }
        issues = validator._rule_location_path_accessibility(quest)
        errors = [i for i in issues if i.severity == ValidationSeverity.ERROR]
        assert len(errors) == 0

    def test_a0_quest_to_a0plus_location_is_error(self, validator):
        """A0 quest targeting A0+ location should be ERROR (location too high level)."""
        # garden is A0+, which is > A0
        quest = {
            "id": "test_quest",
            "language_level": "A0",
            "giver_npc_id": "maria",  # At market (A0)
            "tasks": [
                {
                    "id": "task1",
                    "order": 1,
                    "completion_type": "at_location",
                    "completion_criteria": {"target_id": "garden"}  # A0+ location
                }
            ]
        }
        issues = validator._rule_location_path_accessibility(quest)
        errors = [i for i in issues if i.severity == ValidationSeverity.ERROR]
        assert len(errors) >= 1
        assert any("not reachable" in i.message for i in errors)

    def test_a0_quest_to_a1_location_is_error(self, validator):
        """A0 quest targeting A1 location should be ERROR."""
        # bakery is A1
        quest = {
            "id": "test_quest",
            "language_level": "A0",
            "giver_npc_id": "maria",
            "tasks": [
                {
                    "id": "task1",
                    "order": 1,
                    "completion_type": "at_location",
                    "completion_criteria": {"target_id": "bakery"}  # A1 location
                }
            ]
        }
        issues = validator._rule_location_path_accessibility(quest)
        errors = [i for i in issues if i.severity == ValidationSeverity.ERROR]
        assert len(errors) >= 1

    def test_a0plus_quest_can_reach_a0plus_location(self, validator):
        """A0+ quest can reach A0+ locations."""
        # garden is A0+, reachable via forest (A0) from market (A0)
        quest = {
            "id": "test_quest",
            "language_level": "A0+",
            "giver_npc_id": "maria",  # At market
            "tasks": [
                {
                    "id": "task1",
                    "order": 1,
                    "completion_type": "at_location",
                    "completion_criteria": {"target_id": "garden"}  # A0+ location
                }
            ]
        }
        issues = validator._rule_location_path_accessibility(quest)
        errors = [i for i in issues if i.severity == ValidationSeverity.ERROR]
        assert len(errors) == 0

    def test_a1_quest_can_reach_a1_location(self, validator):
        """A1 quest can reach A1 locations via appropriate paths."""
        # bakery is A1, reachable via multiple paths
        quest = {
            "id": "test_quest",
            "language_level": "A1",
            "giver_npc_id": "maria",
            "tasks": [
                {
                    "id": "task1",
                    "order": 1,
                    "completion_type": "at_location",
                    "completion_criteria": {"target_id": "bakery"}  # A1 location
                }
            ]
        }
        issues = validator._rule_location_path_accessibility(quest)
        errors = [i for i in issues if i.severity == ValidationSeverity.ERROR]
        assert len(errors) == 0

    def test_quest_npc_location_must_be_accessible(self, validator):
        """NPC locations required by quest must also be accessible."""
        # Juan is at bakery (A1)
        quest = {
            "id": "test_quest",
            "language_level": "A0",
            "giver_npc_id": "maria",
            "tasks": [
                {
                    "id": "task1",
                    "order": 1,
                    "completion_type": "talked_to",
                    "completion_criteria": {"target_id": "juan"}  # Juan at bakery (A1)
                }
            ]
        }
        issues = validator._rule_location_path_accessibility(quest)
        errors = [i for i in issues if i.severity == ValidationSeverity.ERROR]
        assert len(errors) >= 1
        assert any("juan" in i.message.lower() or "bakery" in i.message.lower() for i in errors)

    def test_quest_item_location_must_be_accessible(self, validator):
        """Item locations required by quest must be accessible."""
        # Bread is at bakery (A1)
        quest = {
            "id": "test_quest",
            "language_level": "A0",
            "giver_npc_id": "maria",
            "tasks": [
                {
                    "id": "task1",
                    "order": 1,
                    "completion_type": "has_item",
                    "completion_criteria": {"target_id": "bread"}  # At bakery (A1)
                }
            ]
        }
        issues = validator._rule_location_path_accessibility(quest)
        errors = [i for i in issues if i.severity == ValidationSeverity.ERROR]
        assert len(errors) >= 1

    def test_quest_giver_location_must_be_accessible(self, validator):
        """Quest giver's location must be accessible at quest level."""
        # This tests if quest giver at high-level location is flagged
        quest = {
            "id": "test_quest",
            "language_level": "A0",
            "giver_npc_id": "juan",  # Juan is at bakery (A1) - inaccessible at A0!
            "tasks": [
                {
                    "id": "task1",
                    "order": 1,
                    "completion_type": "at_location",
                    "completion_criteria": {"target_id": "market"}
                }
            ]
        }
        issues = validator._rule_location_path_accessibility(quest)
        errors = [i for i in issues if i.severity == ValidationSeverity.ERROR]
        assert len(errors) >= 1
        assert any("quest giver" in i.message.lower() for i in errors)


# === Rule 13: Item Actually At Location ===

class TestItemActuallyAtLocation:
    """Tests for the item_actually_at_location rule (Rule 13)."""

    def test_item_with_valid_location_is_ok(self, validator):
        """Item with valid location_id at existing location should be OK."""
        quest = {
            "id": "test_quest",
            "giver_npc_id": "maria",
            "tasks": [
                {
                    "id": "task1",
                    "order": 1,
                    "completion_type": "has_item",
                    "completion_criteria": {"target_id": "apple"}  # At market, which exists
                }
            ]
        }
        issues = validator._rule_item_actually_at_location(quest)
        errors = [i for i in issues if i.severity == ValidationSeverity.ERROR]
        assert len(errors) == 0

    def test_item_at_nonexistent_location_is_error(self, sample_locations, sample_npcs, sample_world_map):
        """Item placed at non-existent location should be ERROR."""
        # Create items with one at invalid location
        bad_items = {
            "items": [
                {"id": "magic_sword", "name": {"native_language": "Sword", "target_language": "Espada"}, "location_id": "castle", "acquisition_type": "find"},
            ]
        }
        validator = QuestValidator(sample_locations, sample_npcs, bad_items, sample_world_map)

        quest = {
            "id": "test_quest",
            "giver_npc_id": "maria",
            "tasks": [
                {
                    "id": "task1",
                    "order": 1,
                    "completion_type": "has_item",
                    "completion_criteria": {"target_id": "magic_sword"}  # At "castle" which doesn't exist
                }
            ]
        }
        issues = validator._rule_item_actually_at_location(quest)
        errors = [i for i in issues if i.severity == ValidationSeverity.ERROR]
        assert len(errors) >= 1
        assert any("non-existent location" in i.message for i in errors)

    def test_item_with_no_location_is_error(self, sample_locations, sample_npcs, sample_world_map):
        """Item with no location_id should be ERROR."""
        # Create item without location
        bad_items = {
            "items": [
                {"id": "floating_item", "name": {"native_language": "Float", "target_language": "Flotar"}, "acquisition_type": "find"},
            ]
        }
        validator = QuestValidator(sample_locations, sample_npcs, bad_items, sample_world_map)

        quest = {
            "id": "test_quest",
            "giver_npc_id": "maria",
            "tasks": [
                {
                    "id": "task1",
                    "order": 1,
                    "completion_type": "has_item",
                    "completion_criteria": {"target_id": "floating_item"}
                }
            ]
        }
        issues = validator._rule_item_actually_at_location(quest)
        errors = [i for i in issues if i.severity == ValidationSeverity.ERROR]
        assert len(errors) >= 1
        assert any("no location_id" in i.message for i in errors)

    def test_gave_item_also_validated(self, validator):
        """gave_item tasks should also validate item location."""
        quest = {
            "id": "test_quest",
            "giver_npc_id": "maria",
            "tasks": [
                {
                    "id": "task1",
                    "order": 1,
                    "completion_type": "gave_item",
                    "completion_criteria": {"target_id": "apple"}
                }
            ]
        }
        # Should not error - apple has valid location
        issues = validator._rule_item_actually_at_location(quest)
        errors = [i for i in issues if i.severity == ValidationSeverity.ERROR]
        assert len(errors) == 0

    def test_received_item_also_validated(self, validator):
        """received_item tasks should also validate item location."""
        quest = {
            "id": "test_quest",
            "giver_npc_id": "maria",
            "tasks": [
                {
                    "id": "task1",
                    "order": 1,
                    "completion_type": "received_item",
                    "completion_criteria": {"target_id": "letter"}  # At plaza
                }
            ]
        }
        issues = validator._rule_item_actually_at_location(quest)
        errors = [i for i in issues if i.severity == ValidationSeverity.ERROR]
        assert len(errors) == 0


# === Path Accessibility - Isolated Location Tests ===

class TestIsolatedLocationAccessibility:
    """Tests for locations that are completely isolated or behind high-level barriers."""

    def test_isolated_location_is_unreachable(self, sample_npcs):
        """A location with no connections is unreachable."""
        # Create a location graph with an isolated location
        locations_with_isolated = {
            "locations": [
                {"id": "market", "name": {"native_language": "Market", "target_language": "Mercado"}, "minimum_language_level": "A0", "connections": ["forest"]},
                {"id": "forest", "name": {"native_language": "Forest", "target_language": "Bosque"}, "minimum_language_level": "A0", "connections": ["market"]},
                {"id": "island", "name": {"native_language": "Island", "target_language": "Isla"}, "minimum_language_level": "A0", "connections": []},  # Isolated!
            ]
        }
        items = {
            "items": [
                {"id": "treasure", "name": {"native_language": "Treasure", "target_language": "Tesoro"}, "location_id": "island", "acquisition_type": "find"},
            ]
        }
        world_map = {
            "starting_location": "market",
            "locations": locations_with_isolated["locations"],
            "connections": [
                {"from_location": "market", "to_location": "forest", "bidirectional": True},
            ]
        }

        validator = QuestValidator(locations_with_isolated, sample_npcs, items, world_map)

        quest = {
            "id": "test_quest",
            "language_level": "A0",
            "giver_npc_id": "maria",
            "tasks": [
                {
                    "id": "task1",
                    "order": 1,
                    "completion_type": "at_location",
                    "completion_criteria": {"target_id": "island"}  # Isolated location
                }
            ]
        }
        issues = validator._rule_location_path_accessibility(quest)
        errors = [i for i in issues if i.severity == ValidationSeverity.ERROR]
        assert len(errors) >= 1
        assert any("not reachable" in i.message for i in errors)

    def test_location_behind_high_level_barrier_is_unreachable(self, sample_npcs):
        """A0 location behind A1+ locations is unreachable at A0."""
        # Create: market (A0) -> barrier (A1+) -> target (A0)
        # At A0, you can't pass through barrier, so target is unreachable
        locations = {
            "locations": [
                {"id": "market", "name": {"native_language": "Market", "target_language": "Mercado"}, "minimum_language_level": "A0", "connections": ["barrier"]},
                {"id": "barrier", "name": {"native_language": "Barrier", "target_language": "Barrera"}, "minimum_language_level": "A1+", "connections": ["market", "target"]},
                {"id": "target", "name": {"native_language": "Target", "target_language": "Destino"}, "minimum_language_level": "A0", "connections": ["barrier"]},
            ]
        }
        items = {"items": []}
        world_map = {
            "starting_location": "market",
            "locations": locations["locations"],
            "connections": [
                {"from_location": "market", "to_location": "barrier", "bidirectional": True},
                {"from_location": "barrier", "to_location": "target", "bidirectional": True},
            ]
        }

        validator = QuestValidator(locations, sample_npcs, items, world_map)

        quest = {
            "id": "test_quest",
            "language_level": "A0",
            "giver_npc_id": "maria",
            "tasks": [
                {
                    "id": "task1",
                    "order": 1,
                    "completion_type": "at_location",
                    "completion_criteria": {"target_id": "target"}  # Behind barrier
                }
            ]
        }
        issues = validator._rule_location_path_accessibility(quest)
        errors = [i for i in issues if i.severity == ValidationSeverity.ERROR]
        assert len(errors) >= 1

    def test_same_location_behind_barrier_reachable_at_higher_level(self, sample_npcs):
        """Same location becomes reachable at appropriate level."""
        locations = {
            "locations": [
                {"id": "market", "name": {"native_language": "Market", "target_language": "Mercado"}, "minimum_language_level": "A0", "connections": ["barrier"]},
                {"id": "barrier", "name": {"native_language": "Barrier", "target_language": "Barrera"}, "minimum_language_level": "A1+", "connections": ["market", "target"]},
                {"id": "target", "name": {"native_language": "Target", "target_language": "Destino"}, "minimum_language_level": "A0", "connections": ["barrier"]},
            ]
        }
        items = {"items": []}
        world_map = {
            "starting_location": "market",
            "locations": locations["locations"],
            "connections": [
                {"from_location": "market", "to_location": "barrier", "bidirectional": True},
                {"from_location": "barrier", "to_location": "target", "bidirectional": True},
            ]
        }

        validator = QuestValidator(locations, sample_npcs, items, world_map)

        # At A1+ level, we can pass through the barrier
        quest = {
            "id": "test_quest",
            "language_level": "A1+",
            "giver_npc_id": "maria",
            "tasks": [
                {
                    "id": "task1",
                    "order": 1,
                    "completion_type": "at_location",
                    "completion_criteria": {"target_id": "target"}
                }
            ]
        }
        issues = validator._rule_location_path_accessibility(quest)
        errors = [i for i in issues if i.severity == ValidationSeverity.ERROR]
        assert len(errors) == 0


# === Backwards Compatibility Tests ===

class TestBackwardsCompatibility:
    """Test that validator works without world_map parameter."""

    def test_validator_works_without_world_map(self, validator_no_map):
        """Validator should work (with limited path checking) without world_map."""
        quest = {
            "id": "test_quest",
            "giver_npc_id": "maria",
            "tasks": [
                {
                    "id": "task1",
                    "order": 1,
                    "completion_type": "at_location",
                    "completion_criteria": {"target_id": "market"}
                }
            ]
        }
        # Should not crash
        issues = validator_no_map.validate_quest(quest)
        # Basic validation should still work
        errors = [i for i in issues if i.severity == ValidationSeverity.ERROR]
        # No errors expected for basic valid quest
        assert not any("market" in i.message and "not reachable" in i.message for i in errors)

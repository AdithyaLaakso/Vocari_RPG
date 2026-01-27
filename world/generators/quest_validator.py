"""
Quest Validator

Provides deterministic validation rules to ensure quests are completable
and logically consistent. Validates against the actual game world data.
"""

from typing import Dict, Any, List, Set, Tuple, Optional
from dataclasses import dataclass
from enum import Enum


class ValidationSeverity(Enum):
    ERROR = "error"      # Quest is impossible to complete
    WARNING = "warning"  # Quest has issues but might be completable
    INFO = "info"        # Suggestion for improvement


@dataclass
class ValidationIssue:
    severity: ValidationSeverity
    quest_id: str
    task_id: Optional[str]
    rule: str
    message: str

    def __str__(self):
        if self.task_id:
            return f"[{self.severity.value}] Quest '{self.quest_id}' task '{self.task_id}': {self.message}"
        return f"[{self.severity.value}] Quest '{self.quest_id}': {self.message}"


class QuestValidator:
    """
    Validates quests against deterministic rules to ensure they are
    completable and logically consistent.
    """

    # Language level ordering for comparison
    LEVEL_ORDER = {"A0": 0, "A0+": 1, "A1": 2, "A1+": 3, "A2": 4}

    # Expected vocabulary count by level
    VOCAB_RANGES = {
        "A0": (1, 4),    # 1-4 words
        "A0+": (2, 5),   # 2-5 words
        "A1": (3, 6),    # 3-6 words
        "A1+": (3, 7),   # 3-7 words
        "A2": (4, 8)     # 4-8 words
    }

    def __init__(
        self,
        locations: Dict[str, Any],
        npcs: Dict[str, Any],
        items: Dict[str, Any],
        world_map: Optional[Dict[str, Any]] = None
    ):
        # Build lookup structures
        self.locations = {loc['id']: loc for loc in locations.get('locations', [])}
        self.npcs = {npc['id']: npc for npc in npcs.get('npcs', [])}
        self.items = {item['id']: item for item in items.get('items', [])}

        # Build reverse lookups
        self.npc_locations = {npc['id']: npc.get('location_id') for npc in npcs.get('npcs', [])}
        self.item_locations = {item['id']: item.get('location_id') for item in items.get('items', [])}
        self.items_at_location = {}
        for item in items.get('items', []):
            loc_id = item.get('location_id')
            if loc_id not in self.items_at_location:
                self.items_at_location[loc_id] = []
            self.items_at_location[loc_id].append(item['id'])

        # Build level lookups
        self.npc_levels = {npc['id']: npc.get('language_level', 'A0') for npc in npcs.get('npcs', [])}
        self.location_levels = {loc['id']: loc.get('minimum_language_level', 'A0') for loc in locations.get('locations', [])}

        # Build location connection graph for path accessibility checks
        self.location_connections: Dict[str, Set[str]] = {}
        self._build_location_graph(locations, world_map)

        # Get starting location from world_map or default to first A0 location
        self.starting_location = None
        if world_map:
            self.starting_location = world_map.get('starting_location')
        if not self.starting_location:
            # Fall back to first A0 location
            for loc_id, level in self.location_levels.items():
                if level == 'A0':
                    self.starting_location = loc_id
                    break

        # Track seen task patterns for duplicate detection
        self.seen_task_patterns = set()

    def _build_location_graph(self, locations: Dict[str, Any], world_map: Optional[Dict[str, Any]]) -> None:
        """Build a graph of location connections for path accessibility validation."""
        # Initialize empty adjacency sets
        for loc in locations.get('locations', []):
            self.location_connections[loc['id']] = set()

        # Add connections from locations' 'connections' field
        for loc in locations.get('locations', []):
            loc_id = loc['id']
            connections = loc.get('connections', [])
            for conn in connections:
                # connections can be a list of IDs or list of dicts with 'to_location_id'
                if isinstance(conn, str):
                    conn_id = conn
                elif isinstance(conn, dict):
                    conn_id = conn.get('to_location_id')
                else:
                    continue
                if conn_id and conn_id in self.location_connections:
                    # Add bidirectional connection
                    self.location_connections[loc_id].add(conn_id)
                    self.location_connections[conn_id].add(loc_id)

        # Also add connections from world_map 'connections' list if provided
        if world_map:
            for conn in world_map.get('connections', []):
                from_loc = conn.get('from_location')
                to_loc = conn.get('to_location')
                if from_loc and to_loc:
                    if from_loc in self.location_connections:
                        self.location_connections[from_loc].add(to_loc)
                    if conn.get('bidirectional', True) and to_loc in self.location_connections:
                        self.location_connections[to_loc].add(from_loc)

    def validate_all(self, quests_data: Dict[str, Any]) -> List[ValidationIssue]:
        """Run all validation rules on all quests."""
        issues = []

        for quest in quests_data.get('quests', []):
            issues.extend(self.validate_quest(quest))

        return issues

    def validate_quest(self, quest: Dict[str, Any]) -> List[ValidationIssue]:
        """Validate a single quest against all rules."""
        issues = []

        # Rule 1: First task should not auto-complete
        issues.extend(self._rule_no_auto_complete_first_task(quest))

        # Rule 2: NPC diversity - don't talk to same NPC for every task
        issues.extend(self._rule_npc_diversity(quest))

        # Rule 3: Item location consistency (item exists)
        issues.extend(self._rule_item_location_consistency(quest))

        # Rule 3b: Item at correct location (critical bug fix)
        issues.extend(self._rule_item_at_correct_location(quest))

        # Rule 4: Logical item flow (must get item before giving it)
        issues.extend(self._rule_logical_item_flow(quest))

        # Rule 5: No immediate item return (give back what you just received)
        issues.extend(self._rule_no_immediate_item_return(quest))

        # Rule 6: Valid references (items, locations, NPCs exist)
        issues.extend(self._rule_valid_references(quest))

        # Rule 7: Quest giver must exist
        issues.extend(self._rule_valid_quest_giver(quest))

        # Rule 8: Tasks have logical ordering
        issues.extend(self._rule_logical_task_order(quest))

        # Rule 9: Language level consistency
        issues.extend(self._rule_language_level_consistency(quest))

        # Rule 10: Vocabulary progression
        issues.extend(self._rule_vocabulary_progression(quest))

        # Rule 11: No duplicate task structures
        issues.extend(self._rule_no_duplicate_structures(quest))

        # Rule 12: Location path accessibility (locations must be reachable via appropriate level paths)
        issues.extend(self._rule_location_path_accessibility(quest))

        # Rule 13: Item actually at location (items must exist at their stated locations)
        issues.extend(self._rule_item_actually_at_location(quest))

        return issues

    def _rule_no_auto_complete_first_task(self, quest: Dict[str, Any]) -> List[ValidationIssue]:
        """
        RULE 1: First task should not auto-complete when quest is accepted.
        If quest giver is at location X, first task shouldn't be 'at_location X'.
        """
        issues = []
        quest_id = quest.get('id', 'unknown')
        tasks = quest.get('tasks', [])
        giver_npc_id = quest.get('giver_npc_id')

        if not tasks or not giver_npc_id:
            return issues

        # Sort tasks by order
        sorted_tasks = sorted(tasks, key=lambda t: t.get('order', 0))
        first_task = sorted_tasks[0]

        if first_task.get('completion_type') == 'at_location':
            target_location = first_task.get('completion_criteria', {}).get('target_id')
            giver_location = self.npc_locations.get(giver_npc_id)

            if target_location and target_location == giver_location:
                issues.append(ValidationIssue(
                    severity=ValidationSeverity.ERROR,
                    quest_id=quest_id,
                    task_id=first_task.get('id'),
                    rule="no_auto_complete_first_task",
                    message=f"First task requires being at '{target_location}' but quest giver is already there - task auto-completes"
                ))

        # Also check if first task is talking to the quest giver
        if first_task.get('completion_type') == 'talked_to':
            target_npc = first_task.get('completion_criteria', {}).get('target_id')
            if target_npc == giver_npc_id:
                issues.append(ValidationIssue(
                    severity=ValidationSeverity.WARNING,
                    quest_id=quest_id,
                    task_id=first_task.get('id'),
                    rule="no_auto_complete_first_task",
                    message=f"First task is to talk to quest giver - may auto-complete when accepting quest"
                ))

        return issues

    def _rule_npc_diversity(self, quest: Dict[str, Any]) -> List[ValidationIssue]:
        """
        RULE 2: Quests with multiple NPC interactions should involve different NPCs.
        Talking to the same NPC 3+ times in a row is unrealistic.
        """
        issues = []
        quest_id = quest.get('id', 'unknown')
        tasks = quest.get('tasks', [])

        # Get all talked_to tasks (actual NPC interactions)
        # Note: gave_item/received_item target_id is an item_id, not npc_id
        npc_interactions = []
        last_talked_to_npc = None
        for task in sorted(tasks, key=lambda t: t.get('order', 0)):
            comp_type = task.get('completion_type')
            if comp_type == 'talked_to':
                target = task.get('completion_criteria', {}).get('target_id')
                npc_interactions.append((task.get('id'), target))
                last_talked_to_npc = target
            elif comp_type in ('gave_item', 'received_item'):
                # These happen with the last NPC we talked to
                if last_talked_to_npc:
                    npc_interactions.append((task.get('id'), last_talked_to_npc))

        if len(npc_interactions) < 3:
            return issues

        # Check for same NPC appearing 3+ times consecutively
        consecutive_count = 1
        last_npc = None
        for task_id, npc_id in npc_interactions:
            if npc_id == last_npc:
                consecutive_count += 1
                if consecutive_count >= 3:
                    issues.append(ValidationIssue(
                        severity=ValidationSeverity.WARNING,
                        quest_id=quest_id,
                        task_id=task_id,
                        rule="npc_diversity",
                        message=f"NPC '{npc_id}' is involved in {consecutive_count}+ consecutive interactions - lacks variety"
                    ))
            else:
                consecutive_count = 1
            last_npc = npc_id

        # Check if ALL interactions are with the same NPC
        unique_npcs = set(npc for _, npc in npc_interactions if npc)
        if len(unique_npcs) == 1 and len(npc_interactions) >= 3:
            issues.append(ValidationIssue(
                severity=ValidationSeverity.ERROR,
                quest_id=quest_id,
                task_id=None,
                rule="npc_diversity",
                message=f"All {len(npc_interactions)} NPC interactions are with '{list(unique_npcs)[0]}' - quest is unrealistic"
            ))

        return issues

    def _rule_item_location_consistency(self, quest: Dict[str, Any]) -> List[ValidationIssue]:
        issues = []
        quest_id = quest.get('id', 'unknown')
        tasks = quest.get('tasks', [])

        for task in tasks:
            comp_type = task.get('completion_type')
            if comp_type == 'has_item':
                item_id = task.get('completion_criteria', {}).get('target_id')
                if not item_id:
                    continue

                # Check if item exists
                if item_id not in self.items:
                    issues.append(ValidationIssue(
                        severity=ValidationSeverity.ERROR,
                        quest_id=quest_id,
                        task_id=task.get('id'),
                        rule="item_location_consistency",
                        message=f"Item '{item_id}' does not exist in the game world"
                    ))
                    continue

                # Check if item is at a valid location
                item = self.items[item_id]
                item_location = item.get('location_id')
                if item_location not in self.locations:
                    issues.append(ValidationIssue(
                        severity=ValidationSeverity.ERROR,
                        quest_id=quest_id,
                        task_id=task.get('id'),
                        rule="item_location_consistency",
                        message=f"Item '{item_id}' is at invalid location '{item_location}'"
                    ))

        return issues

    def _rule_item_at_correct_location(self, quest: Dict[str, Any]) -> List[ValidationIssue]:
        """
        RULE 3b: When quest has 'go to location X' then 'get item Y', item Y must be at location X.
        This catches the bug where quest says 'get flowers at garden' but flowers are elsewhere.
        """
        issues = []
        quest_id = quest.get('id', 'unknown')
        tasks = sorted(quest.get('tasks', []), key=lambda t: t.get('order', 0))

        # Track the most recent location the player is directed to
        current_implied_location = None

        # Also track quest giver's location as starting point
        giver = quest.get('giver_npc_id')
        if giver and giver in self.npc_locations:
            current_implied_location = self.npc_locations[giver]

        for task in tasks:
            comp_type = task.get('completion_type')
            target_id = task.get('completion_criteria', {}).get('target_id')

            if comp_type == 'at_location':
                # Update current location
                current_implied_location = target_id

            elif comp_type == 'has_item':
                if not target_id or target_id not in self.items:
                    continue  # Handled by other rules

                item = self.items[target_id]
                actual_item_location = item.get('location_id')

                # If we have an implied location from a previous at_location task,
                # check that the item is actually there
                if current_implied_location and actual_item_location:
                    if actual_item_location != current_implied_location:
                        item_name = item.get('name', {}).get('target_language', target_id)
                        issues.append(ValidationIssue(
                            severity=ValidationSeverity.ERROR,
                            quest_id=quest_id,
                            task_id=task.get('id'),
                            rule="item_at_correct_location",
                            message=f"Quest implies getting '{item_name}' at '{current_implied_location}' but item is actually at '{actual_item_location}'"
                        ))

            elif comp_type == 'talked_to':
                # Talking to NPC updates implied location to NPC's location
                if target_id and target_id in self.npc_locations:
                    npc_loc = self.npc_locations[target_id]
                    if npc_loc:
                        current_implied_location = npc_loc

        return issues

    def _rule_logical_item_flow(self, quest: Dict[str, Any]) -> List[ValidationIssue]:
        """
        RULE 4: Must obtain an item before giving it away.
        If task N is 'gave_item X', there must be a prior task that obtains item X.
        """
        issues = []
        quest_id = quest.get('id', 'unknown')
        tasks = sorted(quest.get('tasks', []), key=lambda t: t.get('order', 0))

        items_obtained = set()

        for task in tasks:
            comp_type = task.get('completion_type')
            target_id = task.get('completion_criteria', {}).get('target_id')

            if comp_type in ('has_item', 'received_item'):
                if target_id:
                    items_obtained.add(target_id)

            elif comp_type == 'gave_item':
                if target_id and target_id not in items_obtained:
                    # Check if item can be gathered from world
                    if target_id in self.items:
                        item = self.items[target_id]
                        if item.get('acquisition_type') in ('gather', 'purchase', 'find'):
                            # Item can be obtained from world, but should have explicit task
                            issues.append(ValidationIssue(
                                severity=ValidationSeverity.WARNING,
                                quest_id=quest_id,
                                task_id=task.get('id'),
                                rule="logical_item_flow",
                                message=f"Task requires giving '{target_id}' but no prior task explicitly obtains it"
                            ))
                        else:
                            issues.append(ValidationIssue(
                                severity=ValidationSeverity.ERROR,
                                quest_id=quest_id,
                                task_id=task.get('id'),
                                rule="logical_item_flow",
                                message=f"Task requires giving '{target_id}' which cannot be obtained (no prior task and not gatherable)"
                            ))
                    else:
                        issues.append(ValidationIssue(
                            severity=ValidationSeverity.ERROR,
                            quest_id=quest_id,
                            task_id=task.get('id'),
                            rule="logical_item_flow",
                            message=f"Task requires giving non-existent item '{target_id}'"
                        ))

        return issues

    def _rule_no_immediate_item_return(self, quest: Dict[str, Any]) -> List[ValidationIssue]:
        """
        RULE 5: Don't receive an item and immediately give it back to the same NPC.
        This makes no sense narratively.
        """
        issues = []
        quest_id = quest.get('id', 'unknown')
        tasks = sorted(quest.get('tasks', []), key=lambda t: t.get('order', 0))

        last_received_item = None
        last_received_from = None
        last_received_task_order = -1

        for task in tasks:
            comp_type = task.get('completion_type')
            target_id = task.get('completion_criteria', {}).get('target_id')
            task_order = task.get('order', 0)

            if comp_type == 'received_item':
                last_received_item = target_id
                # Try to determine who gave the item (previous talked_to task)
                for prev_task in tasks:
                    if prev_task.get('order', 0) < task_order:
                        if prev_task.get('completion_type') == 'talked_to':
                            last_received_from = prev_task.get('completion_criteria', {}).get('target_id')
                last_received_task_order = task_order

            elif comp_type == 'gave_item':
                # Check if we're giving back what we just received
                if target_id == last_received_item and task_order == last_received_task_order + 1:
                    # Find who we're giving to
                    give_to_npc = None
                    for check_task in tasks:
                        if check_task.get('order', 0) <= task_order:
                            if check_task.get('completion_type') == 'talked_to':
                                give_to_npc = check_task.get('completion_criteria', {}).get('target_id')

                    if give_to_npc == last_received_from:
                        issues.append(ValidationIssue(
                            severity=ValidationSeverity.ERROR,
                            quest_id=quest_id,
                            task_id=task.get('id'),
                            rule="no_immediate_item_return",
                            message=f"Received item '{target_id}' and immediately returning it to same NPC - illogical"
                        ))

        return issues

    def _rule_valid_references(self, quest: Dict[str, Any]) -> List[ValidationIssue]:
        """
        RULE 6: All referenced IDs must exist in the game world.
        """
        issues = []
        quest_id = quest.get('id', 'unknown')

        for task in quest.get('tasks', []):
            comp_type = task.get('completion_type')
            target_id = task.get('completion_criteria', {}).get('target_id')

            if not target_id:
                continue

            if comp_type == 'at_location':
                if target_id not in self.locations:
                    issues.append(ValidationIssue(
                        severity=ValidationSeverity.ERROR,
                        quest_id=quest_id,
                        task_id=task.get('id'),
                        rule="valid_references",
                        message=f"Location '{target_id}' does not exist"
                    ))

            elif comp_type == 'talked_to':
                if target_id not in self.npcs:
                    issues.append(ValidationIssue(
                        severity=ValidationSeverity.ERROR,
                        quest_id=quest_id,
                        task_id=task.get('id'),
                        rule="valid_references",
                        message=f"NPC '{target_id}' does not exist"
                    ))

            elif comp_type in ('has_item', 'gave_item', 'received_item'):
                if target_id not in self.items:
                    issues.append(ValidationIssue(
                        severity=ValidationSeverity.ERROR,
                        quest_id=quest_id,
                        task_id=task.get('id'),
                        rule="valid_references",
                        message=f"Item '{target_id}' does not exist"
                    ))

        return issues

    def _rule_valid_quest_giver(self, quest: Dict[str, Any]) -> List[ValidationIssue]:
        """
        RULE 7: Quest giver NPC must exist.
        """
        issues = []
        quest_id = quest.get('id', 'unknown')
        giver = quest.get('giver_npc_id')

        if giver and giver not in self.npcs:
            issues.append(ValidationIssue(
                severity=ValidationSeverity.ERROR,
                quest_id=quest_id,
                task_id=None,
                rule="valid_quest_giver",
                message=f"Quest giver NPC '{giver}' does not exist"
            ))

        return issues

    def _rule_logical_task_order(self, quest: Dict[str, Any]) -> List[ValidationIssue]:
        """
        RULE 8: Tasks should have logical ordering.
        - Should go to a location before interacting with NPCs/items there
        - Should talk to NPC before receiving items from them
        """
        issues = []
        quest_id = quest.get('id', 'unknown')
        tasks = sorted(quest.get('tasks', []), key=lambda t: t.get('order', 0))

        visited_locations = set()
        talked_to_npcs = set()

        # Add quest giver's location as initially visited
        giver = quest.get('giver_npc_id')
        if giver and giver in self.npc_locations:
            giver_loc = self.npc_locations[giver]
            if giver_loc:
                visited_locations.add(giver_loc)
                talked_to_npcs.add(giver)  # We talked to them to get the quest

        for task in tasks:
            comp_type = task.get('completion_type')
            target_id = task.get('completion_criteria', {}).get('target_id')

            if comp_type == 'at_location':
                if target_id:
                    visited_locations.add(target_id)

            elif comp_type == 'talked_to':
                if target_id:
                    # Check if we've been to this NPC's location
                    npc_location = self.npc_locations.get(target_id)
                    if npc_location and npc_location not in visited_locations:
                        # This is a soft warning - player might go there naturally
                        issues.append(ValidationIssue(
                            severity=ValidationSeverity.INFO,
                            quest_id=quest_id,
                            task_id=task.get('id'),
                            rule="logical_task_order",
                            message=f"Talk to NPC at '{npc_location}' but no prior task to go there"
                        ))
                    talked_to_npcs.add(target_id)

            elif comp_type == 'has_item':
                if target_id and target_id in self.items:
                    item = self.items[target_id]
                    item_location = item.get('location_id')
                    if item_location and item_location not in visited_locations:
                        issues.append(ValidationIssue(
                            severity=ValidationSeverity.INFO,
                            quest_id=quest_id,
                            task_id=task.get('id'),
                            rule="logical_task_order",
                            message=f"Get item from '{item_location}' but no prior task to go there"
                        ))

        return issues

    def _rule_language_level_consistency(self, quest: Dict[str, Any]) -> List[ValidationIssue]:
        """
        RULE 9: Quest language level should be consistent with NPC/location levels.
        A quest shouldn't require visiting A2 locations if it's labeled A0.
        """
        issues = []
        quest_id = quest.get('id', 'unknown')
        quest_level = quest.get('language_level', 'A0')
        quest_level_num = self.LEVEL_ORDER.get(quest_level, 0)

        # Check quest giver level
        giver_id = quest.get('giver_npc_id')
        if giver_id and giver_id in self.npc_levels:
            giver_level = self.npc_levels[giver_id]
            giver_level_num = self.LEVEL_ORDER.get(giver_level, 0)
            if giver_level_num > quest_level_num + 1:  # Allow 1 level difference
                issues.append(ValidationIssue(
                    severity=ValidationSeverity.WARNING,
                    quest_id=quest_id,
                    task_id=None,
                    rule="language_level_consistency",
                    message=f"Quest is level {quest_level} but quest giver NPC is level {giver_level}"
                ))

        # Check locations visited in tasks
        for task in quest.get('tasks', []):
            comp_type = task.get('completion_type')
            target_id = task.get('completion_criteria', {}).get('target_id')

            if comp_type == 'at_location' and target_id and target_id in self.location_levels:
                loc_level = self.location_levels[target_id]
                loc_level_num = self.LEVEL_ORDER.get(loc_level, 0)
                if loc_level_num > quest_level_num + 1:
                    issues.append(ValidationIssue(
                        severity=ValidationSeverity.WARNING,
                        quest_id=quest_id,
                        task_id=task.get('id'),
                        rule="language_level_consistency",
                        message=f"Quest is level {quest_level} but requires visiting {loc_level} location '{target_id}'"
                    ))

            elif comp_type == 'talked_to' and target_id and target_id in self.npc_levels:
                npc_level = self.npc_levels[target_id]
                npc_level_num = self.LEVEL_ORDER.get(npc_level, 0)
                if npc_level_num > quest_level_num + 1:
                    issues.append(ValidationIssue(
                        severity=ValidationSeverity.WARNING,
                        quest_id=quest_id,
                        task_id=task.get('id'),
                        rule="language_level_consistency",
                        message=f"Quest is level {quest_level} but requires talking to {npc_level} NPC '{target_id}'"
                    ))

        return issues

    def _rule_vocabulary_progression(self, quest: Dict[str, Any]) -> List[ValidationIssue]:
        """
        RULE 10: Vocabulary count should be appropriate for the quest level.
        A0 quests should have fewer vocabulary words than A2 quests.
        """
        issues = []
        quest_id = quest.get('id', 'unknown')
        quest_level = quest.get('language_level', 'A0')

        # Get target vocabulary count
        target_vocab = quest.get('target_vocabulary', [])
        vocab_count = len(target_vocab)

        # Get expected range for this level
        min_vocab, max_vocab = self.VOCAB_RANGES.get(quest_level, (1, 10))

        if vocab_count > 0:  # Only validate if vocabulary is present
            if vocab_count < min_vocab:
                issues.append(ValidationIssue(
                    severity=ValidationSeverity.INFO,
                    quest_id=quest_id,
                    task_id=None,
                    rule="vocabulary_progression",
                    message=f"Quest has {vocab_count} vocabulary words, expected at least {min_vocab} for level {quest_level}"
                ))
            elif vocab_count > max_vocab:
                issues.append(ValidationIssue(
                    severity=ValidationSeverity.WARNING,
                    quest_id=quest_id,
                    task_id=None,
                    rule="vocabulary_progression",
                    message=f"Quest has {vocab_count} vocabulary words, expected at most {max_vocab} for level {quest_level}"
                ))

        return issues

    def _rule_no_duplicate_structures(self, quest: Dict[str, Any]) -> List[ValidationIssue]:
        """
        RULE 11: Quests should have unique task patterns.
        Detects if multiple quests have identical task structure.
        """
        issues = []
        quest_id = quest.get('id', 'unknown')
        tasks = quest.get('tasks', [])

        # Build a pattern signature from task types and order
        pattern_parts = []
        for task in sorted(tasks, key=lambda t: t.get('order', 0)):
            comp_type = task.get('completion_type', 'unknown')
            pattern_parts.append(comp_type)

        pattern = '-'.join(pattern_parts)

        if pattern in self.seen_task_patterns:
            issues.append(ValidationIssue(
                severity=ValidationSeverity.INFO,
                quest_id=quest_id,
                task_id=None,
                rule="no_duplicate_structures",
                message=f"Quest has same task pattern as another quest: {pattern}"
            ))
        else:
            self.seen_task_patterns.add(pattern)

        return issues

    def _get_reachable_locations_at_level(self, max_level: str, start_location: Optional[str] = None) -> Set[str]:
        """
        Get all locations reachable from start via paths where all intermediate
        locations have level <= max_level.

        Uses BFS to find all reachable locations.
        """
        max_level_num = self.LEVEL_ORDER.get(max_level, 0)
        start = start_location or self.starting_location

        if not start:
            return set()

        reachable = set()
        to_visit = [start]
        visited = set()

        while to_visit:
            current = to_visit.pop(0)
            if current in visited:
                continue
            visited.add(current)

            # Check if current location is accessible at this level
            current_level = self.location_levels.get(current, 'A0')
            current_level_num = self.LEVEL_ORDER.get(current_level, 0)

            if current_level_num <= max_level_num:
                reachable.add(current)
                # Add connected locations to visit
                for neighbor in self.location_connections.get(current, []):
                    if neighbor not in visited:
                        to_visit.append(neighbor)

        return reachable

    def _rule_location_path_accessibility(self, quest: Dict[str, Any]) -> List[ValidationIssue]:
        """
        RULE 12: All locations required by quest tasks must be reachable via paths
        where intermediate locations have levels <= quest level.

        A quest at level A0 should not require visiting a location that can only
        be reached by passing through an A1+ location.
        """
        issues = []
        quest_id = quest.get('id', 'unknown')
        quest_level = quest.get('language_level', 'A0')
        tasks = quest.get('tasks', [])

        # Get all locations reachable at the quest's level
        reachable = self._get_reachable_locations_at_level(quest_level)

        # Check quest giver location first
        giver_id = quest.get('giver_npc_id')
        if giver_id and giver_id in self.npc_locations:
            giver_loc = self.npc_locations[giver_id]
            if giver_loc and giver_loc not in reachable:
                issues.append(ValidationIssue(
                    severity=ValidationSeverity.ERROR,
                    quest_id=quest_id,
                    task_id=None,
                    rule="location_path_accessibility",
                    message=f"Quest giver at '{giver_loc}' is not reachable via {quest_level}-accessible paths from starting location"
                ))

        # Check each task's required locations
        for task in tasks:
            comp_type = task.get('completion_type')
            target_id = task.get('completion_criteria', {}).get('target_id')

            if comp_type == 'at_location' and target_id:
                if target_id not in reachable:
                    loc_level = self.location_levels.get(target_id, 'unknown')
                    issues.append(ValidationIssue(
                        severity=ValidationSeverity.ERROR,
                        quest_id=quest_id,
                        task_id=task.get('id'),
                        rule="location_path_accessibility",
                        message=f"Location '{target_id}' (level {loc_level}) is not reachable via {quest_level}-accessible paths"
                    ))

            elif comp_type == 'talked_to' and target_id:
                npc_loc = self.npc_locations.get(target_id)
                if npc_loc and npc_loc not in reachable:
                    issues.append(ValidationIssue(
                        severity=ValidationSeverity.ERROR,
                        quest_id=quest_id,
                        task_id=task.get('id'),
                        rule="location_path_accessibility",
                        message=f"NPC '{target_id}' at location '{npc_loc}' is not reachable via {quest_level}-accessible paths"
                    ))

            elif comp_type == 'has_item' and target_id:
                item_loc = self.item_locations.get(target_id)
                if item_loc and item_loc not in reachable:
                    issues.append(ValidationIssue(
                        severity=ValidationSeverity.ERROR,
                        quest_id=quest_id,
                        task_id=task.get('id'),
                        rule="location_path_accessibility",
                        message=f"Item '{target_id}' at location '{item_loc}' is not reachable via {quest_level}-accessible paths"
                    ))

        return issues

    def _rule_item_actually_at_location(self, quest: Dict[str, Any]) -> List[ValidationIssue]:
        """
        RULE 13: When a quest requires obtaining an item, that item must actually
        be present at its stated location in the items data.

        This validates that:
        1. The item exists
        2. The item has a valid location_id
        3. The location exists in the world
        4. The item is listed in that location's available items (if tracked)
        """
        issues = []
        quest_id = quest.get('id', 'unknown')
        tasks = quest.get('tasks', [])

        for task in tasks:
            comp_type = task.get('completion_type')
            if comp_type not in ('has_item', 'gave_item', 'received_item'):
                continue

            target_id = task.get('completion_criteria', {}).get('target_id')
            if not target_id:
                continue

            # Check if item exists
            if target_id not in self.items:
                # Already handled by rule 6
                continue

            item = self.items[target_id]
            item_location = item.get('location_id')

            # Check if item has a location
            if not item_location:
                issues.append(ValidationIssue(
                    severity=ValidationSeverity.ERROR,
                    quest_id=quest_id,
                    task_id=task.get('id'),
                    rule="item_actually_at_location",
                    message=f"Item '{target_id}' has no location_id - it cannot be obtained"
                ))
                continue

            # Check if the location exists
            if item_location not in self.locations:
                issues.append(ValidationIssue(
                    severity=ValidationSeverity.ERROR,
                    quest_id=quest_id,
                    task_id=task.get('id'),
                    rule="item_actually_at_location",
                    message=f"Item '{target_id}' is placed at non-existent location '{item_location}'"
                ))
                continue

            # Check if item is in items_at_location index (validates the reverse lookup)
            items_at_loc = self.items_at_location.get(item_location, [])
            if target_id not in items_at_loc:
                issues.append(ValidationIssue(
                    severity=ValidationSeverity.WARNING,
                    quest_id=quest_id,
                    task_id=task.get('id'),
                    rule="item_actually_at_location",
                    message=f"Item '{target_id}' claims to be at '{item_location}' but is not in items_at_location index"
                ))

        return issues

    def reset_pattern_tracking(self):
        """Reset the seen task patterns. Call before validating a new batch."""
        self.seen_task_patterns = set()

    def get_error_count(self, issues: List[ValidationIssue]) -> int:
        """Count issues by severity."""
        return sum(1 for i in issues if i.severity == ValidationSeverity.ERROR)

    def get_warning_count(self, issues: List[ValidationIssue]) -> int:
        """Count warnings."""
        return sum(1 for i in issues if i.severity == ValidationSeverity.WARNING)

    def filter_by_severity(
        self,
        issues: List[ValidationIssue],
        severity: ValidationSeverity
    ) -> List[ValidationIssue]:
        """Filter issues by severity level."""
        return [i for i in issues if i.severity == severity]

    def get_invalid_quest_ids(self, issues: List[ValidationIssue]) -> Set[str]:
        """Get IDs of quests that have ERROR-level issues."""
        return {i.quest_id for i in issues if i.severity == ValidationSeverity.ERROR}

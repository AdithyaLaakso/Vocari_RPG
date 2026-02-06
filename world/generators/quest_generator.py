"""
Quest Generator

Generates quests with subdivided tasks for language learning progression.
Quests are non-linear but gated by progression level.
All quests MUST only reference items, locations, and NPCs that actually exist.
Uses INDEX-BASED references (not IDs) to avoid ID generation issues.
Includes deterministic validation to ensure quests are completable.
Retries generation until enough valid quests are produced.

Educational enhancements:
- target_vocabulary: Key vocabulary words for this quest
- grammar_points: Grammar structures practiced in this quest
"""

from typing import Dict, Any, List, Set, Optional
from .base_generator import BaseGenerator
from .quest_validator import QuestValidator, ValidationSeverity
from .models import QuestList, LanguageLevel


class QuestGenerator(BaseGenerator):
    """Generates quests with deterministic task completion."""

    # Configuration
    MIN_VALID_QUESTS = 20  # Minimum number of valid quests required
    MAX_RETRIES = 5        # Maximum number of generation attempts
    QUESTS_PER_BATCH = 10  # How many quests to request per batch (kept small to avoid truncation)

    # Quest types with task patterns
    QUEST_PATTERNS = {
        "fetch": {
            "description": "Gather items and bring them somewhere",
            "typical_tasks": [
                "Learn item names",
                "Ask NPC about item location",
                "Travel to location",
                "Find/purchase item",
                "Return item to quest giver"
            ],
            "language_focus": ["nouns", "directions", "transactions"],
            "typical_vocabulary": ["object names", "location words", "action verbs"],
            "typical_grammar": ["imperative", "questions", "possession"]
        },
        "delivery": {
            "description": "Take something from A to B",
            "typical_tasks": [
                "Receive item from NPC",
                "Get directions to destination",
                "Travel to destination",
                "Deliver item and confirm"
            ],
            "language_focus": ["directions", "polite requests", "confirmations"],
            "typical_vocabulary": ["direction words", "greetings", "polite phrases"],
            "typical_grammar": ["giving/receiving", "location prepositions", "future intent"]
        },
        "information": {
            "description": "Gather information from NPCs",
            "typical_tasks": [
                "Learn what information is needed",
                "Identify who might know",
                "Ask questions to NPCs",
                "Piece together information",
                "Report findings"
            ],
            "language_focus": ["questions", "descriptions", "reporting"],
            "typical_vocabulary": ["question words", "descriptive adjectives", "reporting verbs"],
            "typical_grammar": ["question formation", "relative clauses", "indirect speech"]
        },
        "persuasion": {
            "description": "Convince NPCs to do something",
            "typical_tasks": [
                "Understand what's needed",
                "Find the right NPC",
                "Build rapport",
                "Make request",
                "Handle objections",
                "Reach agreement"
            ],
            "language_focus": ["persuasion", "politeness", "opinions"],
            "typical_vocabulary": ["opinion words", "polite phrases", "conditional words"],
            "typical_grammar": ["conditional", "subjunctive basics", "polite requests"]
        },
        "exploration": {
            "description": "Discover new areas or things",
            "typical_tasks": [
                "Get hints about location",
                "Travel and explore",
                "Interact with environment",
                "Report discovery"
            ],
            "language_focus": ["descriptions", "directions", "observations"],
            "typical_vocabulary": ["nature words", "spatial terms", "descriptive words"],
            "typical_grammar": ["existential statements", "location descriptions", "comparisons"]
        },
        "social": {
            "description": "Build relationships with NPCs",
            "typical_tasks": [
                "Meet NPC",
                "Learn about them",
                "Help with their problem",
                "Establish friendship"
            ],
            "language_focus": ["introductions", "personal topics", "emotions"],
            "typical_vocabulary": ["personal info words", "emotion words", "relationship terms"],
            "typical_grammar": ["self-introduction", "questions about others", "expressing feelings"]
        }
    }

    def generate(
        self,
        lore: Dict[str, Any],
        world_map: Dict[str, Any],
        npcs: Dict[str, Any],
        items: Dict[str, Any],
        games: Optional[Dict[str, Any]] = None
    ) -> Dict[str, Any]:
        """Generate quests for all language levels with retry logic."""
        print("  Generating quests...")

        # Store games data for use in _generate_batch
        self._games_data = games

        # Build lookup tables for index->ID conversion
        self.location_ids = [loc['id'] for loc in world_map.get('locations', [])]
        self.npc_ids = [npc['id'] for npc in npcs.get('npcs', [])]
        self.item_ids = [item['id'] for item in items.get('items', [])]
        self.game_ids = [game['id'] for game in (games or {}).get('games', [])] if games else []

        # Build item->location mapping for validation
        self.item_locations = {}
        for item in items.get('items', []):
            self.item_locations[item['id']] = item.get('location_id')

        # Build NPC->location mapping
        self.npc_locations = {}
        for npc in npcs.get('npcs', []):
            self.npc_locations[npc['id']] = npc.get('location_id')

        # Create validator (pass world_map twice: once for locations, once for path accessibility)
        # Also pass games data for minigame validation
        validator = QuestValidator(world_map, npcs, items, world_map, games)

        # Build context for prompts - using indexed format
        locations_info = self._format_locations_indexed(world_map)
        npcs_info = self._format_npcs_indexed(npcs)
        items_info = self._format_items_indexed(items)
        quest_content = self.get_relevant_content(
            "vocabulary grammar lessons activities exercises",
            top_k=5
        )

        # Collect valid quests across retries
        all_valid_quests = []
        total_generated = 0
        total_invalid = 0
        quest_counter = 1

        for attempt in range(self.MAX_RETRIES):
            remaining_needed = self.MIN_VALID_QUESTS - len(all_valid_quests)
            if remaining_needed <= 0:
                break

            print(f"    Attempt {attempt + 1}/{self.MAX_RETRIES}: Need {remaining_needed} more valid quests...")

            # Generate a batch using structured output
            raw_quests = self._generate_batch(
                lore, locations_info, npcs_info, items_info, quest_content,
                batch_size=self.QUESTS_PER_BATCH
            )

            if not raw_quests.get('quests'):
                print("      No quests generated in this batch")
                continue

            # Convert indices to IDs and assign sequential IDs
            converted_quests = []
            for quest in raw_quests.get('quests', []):
                converted = self._convert_indices_to_ids(quest, quest_counter)
                if converted:
                    converted_quests.append(converted)
                    quest_counter += 1

            # Create temp data for validation
            temp_data = {"quests": converted_quests}

            # Validate the batch
            validation_issues = validator.validate_all(temp_data)
            invalid_quest_ids = validator.get_invalid_quest_ids(validation_issues)

            # Separate valid and invalid quests
            batch_valid = []
            batch_invalid = []
            for quest in converted_quests:
                quest_id = quest.get('id')
                if quest_id in invalid_quest_ids:
                    batch_invalid.append(quest)
                else:
                    batch_valid.append(quest)

            all_valid_quests.extend(batch_valid)
            total_generated += len(converted_quests)
            total_invalid += len(batch_invalid)

            print(f"      Generated {len(converted_quests)} quests: {len(batch_valid)} valid, {len(batch_invalid)} invalid")

            if batch_invalid:
                errors = validator.filter_by_severity(validation_issues, ValidationSeverity.ERROR)
                for err in errors[:3]:
                    print(f"        - {err.message}")

        # Build final output with only valid quests
        final_data = {
            "quest_lines": [],
            "quests": all_valid_quests,
            "_generation_summary": {
                "total_attempts": min(attempt + 1, self.MAX_RETRIES),
                "total_generated": total_generated,
                "total_valid": len(all_valid_quests),
                "total_invalid": total_invalid,
                "target_minimum": self.MIN_VALID_QUESTS,
                "target_met": len(all_valid_quests) >= self.MIN_VALID_QUESTS
            }
        }

        # Validate bilingual text
        bilingual_errors = self.validate_bilingual_text(final_data)
        if bilingual_errors:
            print(f"  Warning: Bilingual format issues found: {bilingual_errors[:3]}...")

        self.save_json(final_data, "quests.json")

        if len(all_valid_quests) >= self.MIN_VALID_QUESTS:
            print(f"  Success: Generated {len(all_valid_quests)} valid quests")
        else:
            print(f"  Warning: Only generated {len(all_valid_quests)}/{self.MIN_VALID_QUESTS} valid quests after {self.MAX_RETRIES} attempts")

        return final_data

    def _convert_indices_to_ids(self, quest: Dict[str, Any], quest_number: int) -> Optional[Dict[str, Any]]:
        """Convert index-based references in a quest to actual IDs."""
        try:
            # Generate deterministic quest ID
            quest_name = quest.get('name', {})
            slug = self.slugify(quest_name)
            quest['id'] = f"quest_{quest_number}_{slug}" if slug else f"quest_{quest_number}"

            # Convert giver_npc_index to giver_npc_id
            giver_idx = quest.pop('giver_npc_index', None)
            if giver_idx is not None and 0 <= giver_idx < len(self.npc_ids):
                quest['giver_npc_id'] = self.npc_ids[giver_idx]
            elif 'giver_npc_id' not in quest and self.npc_ids:
                quest['giver_npc_id'] = self.npc_ids[0]

            # Convert tasks
            task_counter = 1
            for task in quest.get('tasks', []):
                task['id'] = f"{quest['id']}_task_{task_counter}"
                task_counter += 1

                criteria = task.get('completion_criteria', {})

                # Convert location_index
                if 'location_index' in criteria:
                    loc_idx = criteria.pop('location_index')
                    if loc_idx is not None and 0 <= loc_idx < len(self.location_ids):
                        criteria['target_id'] = self.location_ids[loc_idx]

                # Convert npc_index
                if 'npc_index' in criteria:
                    npc_idx = criteria.pop('npc_index')
                    if npc_idx is not None and 0 <= npc_idx < len(self.npc_ids):
                        criteria['target_id'] = self.npc_ids[npc_idx]

                # Convert item_index
                if 'item_index' in criteria:
                    item_idx = criteria.pop('item_index')
                    if item_idx is not None and 0 <= item_idx < len(self.item_ids):
                        criteria['target_id'] = self.item_ids[item_idx]

                # Convert game_index
                if 'game_index' in criteria:
                    game_idx = criteria.pop('game_index')
                    if game_idx is not None and 0 <= game_idx < len(self.game_ids):
                        criteria['target_id'] = self.game_ids[game_idx]

            return quest
        except Exception as e:
            print(f"      Warning: Failed to convert quest: {e}")
            return None

    def _generate_batch(
        self,
        lore: Dict[str, Any],
        locations_info: str,
        npcs_info: str,
        items_info: str,
        quest_content: str,
        batch_size: int
    ) -> Dict[str, Any]:
        """Generate a batch of quests using structured output with INDEX-BASED references."""
        system_prompt = f"""{self.get_base_system_prompt()}

You are generating QUESTS for this language learning RPG.

CRITICAL RULES:
1. Use INDEX NUMBERS (0-based) to reference locations, NPCs, and items
2. When referencing a location, use location_index: N
3. When referencing an NPC, use npc_index: N
4. When referencing an item, use item_index: N
5. When referencing a game, use game_index: N
6. IMPORTANT: Items can only be obtained at their listed location!

MINIGAME REQUIREMENT (CRITICAL):
- EVERY quest MUST include at least one minigame task
- Use completion_type: "completed_game" with game_index to reference a minigame
- Minigames reinforce vocabulary and grammar through interactive gameplay
- If no games are listed, still include a completed_game task - games will be generated to match
- Place the minigame task at a natural point in the quest (e.g., after learning new vocabulary)

EDUCATIONAL VALUE:
- target_vocabulary: List 3-6 key vocabulary words this quest reinforces
- grammar_points: List 1-3 grammar structures practiced (e.g., "present tense", "questions")

ANTI-PATTERNS TO AVOID:
1. First task same location as quest giver -> auto-completes
2. Telling player to get item X but sending them to wrong location
3. Giving item before player acquires it
4. Quest without a minigame -> rejected!

TASK COMPLETION TYPES:
- "at_location": player at location (use location_index)
- "talked_to": player talked to NPC (use npc_index)
- "has_item": player has item (use item_index)
- "gave_item": player gave item to NPC (use item_index + npc_index for the NPC talked to before)
- "received_item": player received item from NPC
- "completed_game": player completed a mini-game (use game_index) - REQUIRED IN EVERY QUEST"""

        # Format games info
        games_info = self._format_games_indexed(getattr(self, '_games_data', None))

        user_prompt = f"""Generate {batch_size} quests. Use INDICES (0-based numbers) to reference entities.

=== LOCATIONS (use index 0, 1, 2, etc.) ===
{locations_info}

=== NPCs (use index 0, 1, 2, etc.) ===
{npcs_info}

=== ITEMS WITH LOCATIONS (use index 0, 1, 2, etc.) ===
{items_info}

=== MINIGAMES (use index 0, 1, 2, etc.) ===
{games_info}

QUEST PATTERNS AND EDUCATIONAL FOCUS:
{self._format_quest_patterns()}

REQUIREMENTS:
1. Create {batch_size} quests across all levels (A0 to A2)
2. Each quest: 2-4 tasks with logical progression
3. Use ONLY indices from the lists above
4. IMPORTANT: If quest needs item X, send player to item X's location first!
5. Vary NPCs - don't use same NPC for all tasks
6. Include target_vocabulary (3-6 bilingual words per quest)
7. Include grammar_points (1-3 grammar structures per quest)
8. CRITICAL: Every quest MUST have at least one "completed_game" task with a game_index!

Target: {self.target_language}, Native: {self.native_language}"""

        try:
            # Use structured output
            quest_result = self.call_openai_structured(
                system_prompt=system_prompt,
                user_prompt=user_prompt,
                response_model=QuestList
            )

            # Convert Pydantic models to dicts
            return {"quests": [q.model_dump() for q in quest_result.quests]}
        except Exception as e:
            print(f"      Warning: Structured output failed, falling back to JSON: {e}")
            # Fall back to JSON mode
            return self.call_openai_json(
                system_prompt=system_prompt,
                user_prompt=user_prompt,
            )

    def _filter_quest_lines(
        self,
        quest_lines: List[Dict[str, Any]],
        valid_quests: List[Dict[str, Any]]
    ) -> List[Dict[str, Any]]:
        """Filter quest lines to only include references to valid quests."""
        valid_quest_ids = {q.get('id') for q in valid_quests}
        filtered_lines = []

        for ql in quest_lines:
            filtered_quest_ids = [
                qid for qid in ql.get('quests', [])
                if qid in valid_quest_ids
            ]
            if filtered_quest_ids:
                ql_copy = ql.copy()
                ql_copy['quests'] = filtered_quest_ids
                filtered_lines.append(ql_copy)

        return filtered_lines

    def _format_locations_indexed(self, world_map: Dict[str, Any]) -> str:
        """Format locations with indices for the prompt."""
        lines = []
        for i, loc in enumerate(world_map.get('locations', [])):
            name = loc.get('name', {})
            name_str = name.get('native_language', loc['id'])
            level = loc.get('minimum_language_level', 'A0')
            lines.append(f"[{i}] {name_str} (level: {level})")
        return "\n".join(lines)

    def _format_npcs_indexed(self, npcs: Dict[str, Any]) -> str:
        """Format NPCs with indices and their location indices."""
        lines = []
        for i, npc in enumerate(npcs.get('npcs', [])):
            name = npc.get('name', {})
            name_str = name.get('native_language', npc['id'])
            loc_id = npc.get('location_id', '')
            loc_idx = "?"
            for j, loc in enumerate(self.location_ids):
                if loc == loc_id:
                    loc_idx = j
                    break
            lines.append(f"[{i}] {name_str} @ location[{loc_idx}]")
        return "\n".join(lines)

    def _format_items_indexed(self, items: Dict[str, Any]) -> str:
        """Format items with indices and their location indices."""
        lines = []
        for i, item in enumerate(items.get('items', [])):
            name = item.get('name', {})
            name_str = name.get('native_language', item['id'])
            loc_id = item.get('location_id', '')
            loc_idx = "?"
            for j, loc in enumerate(self.location_ids):
                if loc == loc_id:
                    loc_idx = j
                    break
            acq = item.get('acquisition_type', 'gather')
            lines.append(f"[{i}] {name_str} @ location[{loc_idx}] ({acq})")
        return "\n".join(lines)

    def _format_quest_patterns(self) -> str:
        """Format quest patterns with educational focus for the prompt."""
        lines = []
        for pattern, info in self.QUEST_PATTERNS.items():
            lines.append(f"\n{pattern.upper()}: {info['description']}")
            lines.append("  Typical tasks:")
            for task in info['typical_tasks']:
                lines.append(f"    - {task}")
            lines.append(f"  Language focus: {', '.join(info['language_focus'])}")
            lines.append(f"  Typical vocabulary: {', '.join(info.get('typical_vocabulary', []))}")
            lines.append(f"  Typical grammar: {', '.join(info.get('typical_grammar', []))}")
        return "\n".join(lines)

    def _format_games_indexed(self, games: Dict[str, Any]) -> str:
        """Format games with indices for the prompt."""
        game_list = games.get('games', []) if games else []
        if not game_list:
            return "(No games available yet - will be generated based on quests)"
        lines = []
        for i, game in enumerate(game_list):
            name = game.get('name', {})
            name_str = name.get('native_language', game.get('id', f'game_{i}'))
            level = game.get('language_level', 'A0')
            lines.append(f"[{i}] {name_str} (level: {level})")
        return "\n".join(lines)
